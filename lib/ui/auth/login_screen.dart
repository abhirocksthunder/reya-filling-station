import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../models/user_profile.dart';
import '../../services/station_state_provider.dart';
import '../../services/app_version_service.dart';
import '../../services/sentinel_alert_agent.dart';
import '../../services/remote_logging_service.dart';
import '../../widgets/version_footer.dart';

class LoginScreen extends StatefulWidget {
  final Function(UserProfile) onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final Map<String, int> _failedPinAttempts = {};
  bool _isLoading = false;
  bool _isLockedOut = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = context.read<StationStateProvider>();
        AppVersionService.checkAndPromptUpdate(context, state.settings);
      }
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _handleLogin(StationStateProvider state) {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final query = _identifierController.text.trim().toLowerCase();
    final enteredPin = _pinController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter your email or mobile number.';
      });
      return;
    }

    if (enteredPin.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter your 4-6 digit Security PIN.';
      });
      return;
    }

    // Find user by email or phone number or name
    final UserProfile? matchedUser = state.allUsers.firstWhere(
      (u) =>
          u.email.toLowerCase() == query ||
          u.phoneNumber.replaceAll(' ', '') == query.replaceAll(' ', '') ||
          u.name.toLowerCase() == query,
      orElse: () => const UserProfile(
        id: '',
        name: '',
        phoneNumber: '',
        role: UserRole.shiftStaff,
      ),
    );

    if (matchedUser == null || matchedUser.id.isEmpty) {
      RemoteLoggingService().logWarn(
        'Login failed: account not found for query "$query"',
        screenName: 'LoginScreen',
        action: 'login_not_found',
      );
      setState(() {
        _isLoading = false;
        _errorMessage = 'Account not found. Please check your credentials or contact owner.';
      });
      return;
    }

    if (matchedUser.isPendingApproval && !matchedUser.hasPendingEdit) {
      setState(() {
        _isLoading = false;
        _isLockedOut = false;
        _errorMessage =
            'Account pending Owner approval: Added by ${matchedUser.requestedBy ?? "Manager"}. Please ask Station Owner to approve your account in People & Roles.';
      });
      return;
    }

    if (!matchedUser.active) {
      // Dispatch red flag alert to Station Owner on WhatsApp +919492757943
      SentinelAlertAgent().notifyUserBlocked(
        userEmail: matchedUser.email,
        userName: matchedUser.name,
        reason: 'Suspended user attempted login',
      );
      RemoteLoggingService().logError(
        'Blocked/Suspended user ${matchedUser.name} attempted login',
        screenName: 'LoginScreen',
        action: 'blocked_user_login_attempt',
        userId: matchedUser.id,
        userRole: matchedUser.role.name,
      );
      setState(() {
        _isLoading = false;
        _isLockedOut = true;
        _errorMessage = 'Account is suspended. Alert dispatched to Station Owner (+919492757943).';
      });
      return;
    }

    if (matchedUser.securityPin != enteredPin) {
      final attempts = (_failedPinAttempts[matchedUser.id] ?? 0) + 1;
      _failedPinAttempts[matchedUser.id] = attempts;

      if (attempts >= 3) {
        // Red flag: User locked out after 3 failed attempts
        SentinelAlertAgent().notifyUserBlocked(
          userEmail: matchedUser.email,
          userName: matchedUser.name,
          reason: '3 consecutive incorrect Security PIN attempts',
          failedAttempts: '$attempts',
        );
        RemoteLoggingService().logError(
          'User ${matchedUser.name} locked out after 3 failed PIN attempts',
          screenName: 'LoginScreen',
          action: 'user_locked_out_pin_attempts',
          userId: matchedUser.id,
          userRole: matchedUser.role.name,
        );
        setState(() {
          _isLoading = false;
          _isLockedOut = true;
          _errorMessage = 'Account locked: 3 incorrect PIN attempts. Security alert sent to Owner (+919492757943).';
        });
        return;
      }

      RemoteLoggingService().logWarn(
        'Incorrect PIN attempt $attempts for user ${matchedUser.name}',
        screenName: 'LoginScreen',
        action: 'incorrect_pin_attempt',
        userId: matchedUser.id,
        userRole: matchedUser.role.name,
      );
      setState(() {
        _isLoading = false;
        _errorMessage = 'Incorrect Security PIN ($attempts/3 attempts). Please contact station admin if forgotten.';
      });
      return;
    }

    // Success
    _failedPinAttempts[matchedUser.id] = 0;
    _isLockedOut = false;
    RemoteLoggingService().logInfo(
      'User ${matchedUser.name} (${matchedUser.role.name}) authenticated successfully',
      screenName: 'LoginScreen',
      action: 'login_success',
      userId: matchedUser.id,
      userRole: matchedUser.role.name,
    );
    state.switchUser(matchedUser);
    widget.onLoginSuccess(matchedUser);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;

    return Scaffold(
      backgroundColor: StationColors.scaffoldBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Station Gas Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: StationColors.primaryLight.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_gas_station_rounded, color: StationColors.primary, size: 42),
                  ),
                  const SizedBox(height: 16),

                  // Station Title
                  const Text(
                    'RFS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: StationColors.textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Chatrai, Andhra Pradesh',
                    style: TextStyle(fontSize: 13, color: StationColors.textLight, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 18),

                  // Language Switcher
                  Container(
                    decoration: BoxDecoration(
                      color: StationColors.accentOrangeLight,
                      borderRadius: BorderRadius.circular(StationDimensions.pillRadius),
                      border: Border.all(color: StationColors.accentOrangeBorder.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLangBtn('తెలుగు', 'te', lang == 'te', state),
                        Container(width: 1, height: 16, color: StationColors.accentOrangeBorder),
                        _buildLangBtn('EN', 'en', lang == 'en', state),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email or Phone Input (Max 30 characters)
                  TextField(
                    controller: _identifierController,
                    maxLength: 30,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    decoration: InputDecoration(
                      labelText: 'Email or Mobile Number',
                      hintText: 'e.g. kalyan@rfs.com or 9848011111',
                      counterText: '',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PIN Input (Max 6 Digits)
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleLogin(state),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Security PIN (Max 6 Digits)',
                      hintText: 'Enter 4-6 digit Security PIN',
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: StationColors.errorBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: StationColors.errorRed, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          if (_isLockedOut) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                final text = '🚨 *REYAA FILLING STATION LOCKOUT ALERT*\n'
                                    'Account blocked for user: ${_identifierController.text.trim()}\n'
                                    'Status: 3 failed attempts or suspended account.\n'
                                    'Please unblock or reset Security PIN.';
                                SentinelAlertAgent.openWhatsAppAlert(text);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF25D366)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFF1E7E34)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Notify Owner on WhatsApp (+919492757943)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E7E34),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: StationDimensions.primaryButtonHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StationColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StationDimensions.buttonRadius)),
                        elevation: 1,
                      ),
                      onPressed: _isLoading ? null : () => _handleLogin(state),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Sign In',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const VersionFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLangBtn(String label, String code, bool isSelected, StationStateProvider state) {
    return InkWell(
      onTap: () => state.setLanguage(code),
      borderRadius: BorderRadius.circular(StationDimensions.pillRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? StationColors.accentOrange : StationColors.textMedium,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

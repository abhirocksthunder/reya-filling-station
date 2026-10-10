import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../models/user_profile.dart';
import '../../services/station_state_provider.dart';

class LoginScreen extends StatefulWidget {
  final Function(UserProfile) onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

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

    String query = _identifierController.text.trim().toLowerCase();

    // Find user by email or phone number
    UserProfile? matchedUser = state.allUsers.firstWhere(
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

    if (matchedUser.id.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Account not found. Please check your email or phone number.';
      });
      return;
    }

    if (!matchedUser.active) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Account is suspended. Contact station owner.';
      });
      return;
    }

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
            constraints: const BoxConstraints(maxWidth: 440),
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

                  // Station Title (NO "Demo - Sample Data" text!)
                  const Text(
                    'Reya Filling Station',
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
                  const SizedBox(height: 20),

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
                  const SizedBox(height: 28),

                  // Email or Phone Input
                  TextField(
                    controller: _identifierController,
                    decoration: InputDecoration(
                      labelText: 'Email or Mobile Number',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PIN Input
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Security PIN',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: StationColors.errorBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: StationColors.errorRed, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Login Button (60px high forecourt target)
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/colors.dart';
import 'models/user_profile.dart';
import 'services/station_state_provider.dart';
import 'ui/staff/staff_shell.dart';
import 'ui/owner/owner_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StationStateProvider()),
      ],
      child: const ReyaFillingStationApp(),
    ),
  );
}

class ReyaFillingStationApp extends StatelessWidget {
  const ReyaFillingStationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reya Filling Station',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: StationColors.primary,
          primary: StationColors.primary,
          secondary: StationColors.accentOrange,
          surface: Colors.white,
          background: StationColors.scaffoldBg,
        ),
        scaffoldBackgroundColor: StationColors.scaffoldBg,
        fontFamily: 'Roboto',
      ),
      home: const MainPortalHost(),
    );
  }
}

class MainPortalHost extends StatefulWidget {
  const MainPortalHost({super.key});

  @override
  State<MainPortalHost> createState() => _MainPortalHostState();
}

class _MainPortalHostState extends State<MainPortalHost> {
  // Mode override for review: allows reviewer to switch views regardless of selected user role
  bool? _forceOwnerView;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final isOwnerRole = state.currentUser.role == UserRole.owner;

    bool showOwner = _forceOwnerView ?? isOwnerRole;

    return Stack(
      children: [
        if (showOwner)
          OwnerShell(
            onSwitchToStaffView: () => setState(() => _forceOwnerView = false),
          )
        else
          StaffShell(
            onSwitchToOwnerPortal: () => setState(() => _forceOwnerView = true),
          ),

        // Floating Quick Toggle Badge (Reviewer Switcher)
        Positioned(
          bottom: 16,
          right: 16,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(20),
            color: StationColors.primaryDark,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _forceOwnerView = !showOwner;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showOwner ? Icons.phone_android : Icons.laptop_mac,
                      color: StationColors.accentOrangeBorder,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      showOwner ? 'Forecourt Phone View' : 'Owner Operations Portal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

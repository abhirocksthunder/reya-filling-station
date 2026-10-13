import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/constants/colors.dart';
import 'models/user_profile.dart';
import 'services/station_state_provider.dart';
import 'services/ota_status_service.dart';
import 'ui/auth/login_screen.dart';
import 'ui/staff/staff_shell.dart';
import 'ui/owner/owner_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization fallback: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StationStateProvider()),
        ChangeNotifierProvider(create: (_) => OtaStatusService()),
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
      title: 'RFS',
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
  Timer? _minuteLocationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OtaStatusService?>()?.refresh();
    });
    _minuteLocationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final state = context.read<StationStateProvider>();
      if (state.isAuthenticated) {
        state.refreshCurrentUserLocation(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _minuteLocationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();

    // Zero-Trust Auth Gate: Unauthenticated users MUST log in
    if (!state.isAuthenticated) {
      return LoginScreen(
        onLoginSuccess: (user) {
          // Auth state update triggers re-render automatically
        },
      );
    }

    // Role-based portal routing: Owner & Admin (or custom roles with Owner privileges) access OwnerShell
    if (state.currentUser.hasOwnerPrivileges) {
      return const OwnerShell();
    } else {
      return const StaffShell();
    }
  }
}

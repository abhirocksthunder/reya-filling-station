import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/colors.dart';
import 'models/user_profile.dart';
import 'services/station_state_provider.dart';
import 'ui/auth/login_screen.dart';
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

class MainPortalHost extends StatelessWidget {
  const MainPortalHost({super.key});

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

    // Role-based portal routing: Owner sees OwnerShell, Staff sees StaffShell
    final isOwnerRole = state.currentUser.role == UserRole.owner;
    if (isOwnerRole) {
      return const OwnerShell();
    } else {
      return const StaffShell();
    }
  }
}

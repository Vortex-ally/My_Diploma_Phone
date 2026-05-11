import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'constants/db_config.dart';
import 'models/project.dart';
import 'models/request.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/chat_thread_screen.dart';
import 'screens/db_settings_screen.dart';
import 'screens/leave_review_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/organizer_dashboard.dart';
import 'screens/payment_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/project_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/volunteer_dashboard.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbConfig.load();
  runApp(const VolunteerApp());
}

class VolunteerApp extends StatelessWidget {
  const VolunteerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider(ApiService())),
      ],
      child: MaterialApp(
        title: 'Volunteer',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        initialRoute: '/',
        routes: {
          '/': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/main': (_) => const MainNavigationScreen(),
          '/dashboard': (_) => const VolunteerDashboard(),
          '/organizer': (_) => const OrganizerDashboard(),
          '/profile': (_) => const ProfileScreen(),
          '/chat': (_) => const ChatScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/server': (_) => const DbSettingsScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/project':
              final project = settings.arguments as Project?;
              if (project == null) return null;
              return MaterialPageRoute(
                builder: (_) => ProjectDetailScreen(project: project),
                settings: settings,
              );
            case '/review':
              final req = settings.arguments as Request?;
              if (req == null) return null;
              return MaterialPageRoute(
                builder: (_) => LeaveReviewScreen(request: req),
                settings: settings,
              );
            case '/payment':
              final args = settings.arguments as PaymentArgs?;
              if (args == null) return null;
              return MaterialPageRoute(
                builder: (_) => PaymentScreen(args: args),
                settings: settings,
              );
            case '/chat-thread':
              final args = settings.arguments as ChatThreadArgs?;
              if (args == null) return null;
              return MaterialPageRoute(
                builder: (_) => ChatThreadScreen(
                  username: args.username,
                  displayName: args.displayName,
                ),
                settings: settings,
              );
          }
          return null;
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    final base = ThemeData(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      primary: const Color(0xFF6750A4),
      secondary: const Color(0xFF625B71),
      tertiary: const Color(0xFF7D5260),
      surface: const Color(0xFFFEF7FF),
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F2FB),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF6750A4),
        foregroundColor: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).merge(
        TextTheme(
          headlineSmall: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1C1B1F),
          ),
          titleLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1C1B1F),
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final auth = context.read<AuthProvider>();
    // Wait briefly for initAuth() to settle.
    while (auth.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }
    if (!mounted) return;
    if (auth.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.volunteer_activism,
              size: 96,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Volunteer',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class PaymentArgs {
  final String planType;
  final int? projectId;
  final String? projectName;

  const PaymentArgs({
    required this.planType,
    this.projectId,
    this.projectName,
  });
}

class ChatThreadArgs {
  final String username;
  final String displayName;

  const ChatThreadArgs({required this.username, required this.displayName});
}

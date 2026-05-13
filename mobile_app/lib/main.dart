import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'services/language_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'hive_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final languageService = LanguageService();
  await languageService.load();
  LanguageService.instance = languageService;

  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(details.exceptionAsString(), textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );

  try {
    if (!kIsWeb) {
      await initHive();
      await Hive.openBox('measurements');
      await Hive.openBox('settings');
    }
    runApp(SmartHealthKioskApp(languageService: languageService));
  } catch (e, stack) {
    debugPrint('Startup error: $e\n$stack');
    runApp(MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Something went wrong',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('$e', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                Expanded(
                    child: SingleChildScrollView(
                        child: Text('$stack',
                            style: const TextStyle(fontSize: 12)))),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class SmartHealthKioskApp extends StatelessWidget {
  final LanguageService languageService;
  const SmartHealthKioskApp({super.key, required this.languageService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: languageService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Smart Health Kiosk',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: const Color(0xFF12EC12),
            useMaterial3: true,
            fontFamily: 'Roboto',
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF12EC12),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF12EC12),
                side: const BorderSide(color: Color(0xFF12EC12)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF12EC12), width: 2),
              ),
              floatingLabelStyle: const TextStyle(color: Color(0xFF12EC12)),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF111827),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: Color(0xFF12EC12),
            ),
          ),
          home: AuthGate(languageService: languageService),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  final LanguageService languageService;
  const AuthGate({super.key, required this.languageService});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await AuthService.getToken();
    setState(() {
      _loggedIn = token != null;
      _loading = false;
    });
    if (_loggedIn) SyncService.instance.startBackgroundSync();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _loggedIn
        ? HomeScreen(languageService: widget.languageService)
        : LoginScreen(
            languageService: widget.languageService,
            onLogin: () {
              setState(() => _loggedIn = true);
              SyncService.instance.startBackgroundSync();
            },
          );
  }
}

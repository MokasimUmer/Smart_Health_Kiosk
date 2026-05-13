import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import 'signup_screen.dart';
import 'server_config_screen.dart';
import 'language_screen.dart';

const Color kBrand = Color(0xFF12EC12);
const Color kBrandDark = Color(0xFF0BBF0B);

class LoginScreen extends StatefulWidget {
  final LanguageService languageService;
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.languageService, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  String? _error;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final s = widget.languageService.strings;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await AuthService.login(
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (res.containsKey('token')) {
        widget.onLogin();
      } else {
        setState(() => _error = res['error'] ?? s.loginFailed);
      }
    } on SocketException catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.languageService.strings.cannotReachServer;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.languageService.strings.networkError(e.toString().split('\n').first);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.languageService.strings;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: Color(0xFF6B7280)),
            tooltip: s.language,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LanguageScreen(languageService: widget.languageService),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet, color: Color(0xFF6B7280)),
            tooltip: 'Server Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServerConfigScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo / icon
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: kBrand.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.health_and_safety,
                          size: 48, color: kBrand),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      s.appTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.signInToContinue,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 32),

                    // Error banner
                    if (_error != null)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade600, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Phone field
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: s.phoneNumber,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password field with eye toggle
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        labelText: s.password,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF6B7280),
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Sign In button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: kBrand,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : Text(s.signIn,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sign Up link
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, a, __) => SignupScreen(
                            languageService: widget.languageService,
                            onSignup: widget.onLogin,
                          ),
                          transitionsBuilder: (_, a, __, child) =>
                              FadeTransition(opacity: a, child: child),
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      ),
                      child: Text(
                        s.dontHaveAccount,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFF374151), fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

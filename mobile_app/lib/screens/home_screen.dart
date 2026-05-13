import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import 'subscription_screen.dart';
import 'kiosk_screen.dart';
import 'history_screen.dart';
import 'appointments_screen.dart';
import 'language_screen.dart';
import 'login_screen.dart' show kBrand;

class HomeScreen extends StatefulWidget {
  final LanguageService languageService;
  const HomeScreen({super.key, required this.languageService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _subStatus = 'pending';
  bool _loading = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadStatus();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final meRes = await AuthService.fetchMe();
      setState(() {
        _subStatus = meRes['user']?['subscriptionStatus'] ?? 'pending';
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (_) {
      setState(() => _loading = false);
      _animCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = AuthService.patient;
    final isActive = _subStatus == 'active';
    final s = widget.languageService.strings;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(
                color: kBrand, shape: BoxShape.circle),
              child: const Icon(Icons.health_and_safety,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(s.appTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color(0xFF111827))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: Color(0xFF6B7280)),
            tooltip: s.language,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    LanguageScreen(languageService: widget.languageService),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF6B7280)),
            tooltip: s.logout,
            onPressed: () async {
              await AuthService.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) =>
                        Scaffold(body: Center(child: Text(s.loggedOut))),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kBrand))
          : FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                color: kBrand,
                onRefresh: _loadStatus,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Welcome card
                    _buildWelcomeCard(patient, isActive, s),
                    const SizedBox(height: 16),

                    if (!isActive) ...[
                      _buildSubscriptionCard(s),
                    ] else ...[
                      _buildAnimatedMenuCard(
                        context,
                        index: 0,
                        icon: Icons.monitor_heart,
                        title: s.startMeasurement,
                        subtitle: s.connectToKiosk,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const KioskScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAnimatedMenuCard(
                        context,
                        index: 1,
                        icon: Icons.history_rounded,
                        title: s.measurementHistory,
                        subtitle: s.viewPastMeasurements,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HistoryScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAnimatedMenuCard(
                        context,
                        index: 2,
                        icon: Icons.calendar_month_outlined,
                        title: s.myAppointments,
                        subtitle: s.viewAppointmentStatus,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AppointmentsScreen()),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard(
      Map<String, dynamic>? patient, bool isActive, dynamic s) {
    final name = patient?['name'] ?? 'User';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: kBrand,
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.welcome(name),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF111827))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isActive ? Icons.check_circle : Icons.pending,
                      color: isActive ? kBrand : Colors.orange,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.subscriptionStatus(_subStatus),
                      style: TextStyle(
                        color: isActive ? kBrand : Colors.orange,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(dynamic s) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline,
                size: 30, color: Colors.orange),
          ),
          const SizedBox(height: 12),
          Text(s.subscriptionRequired,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(s.pleaseSubscribe, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SubscriptionScreen()),
              ).then((_) => _loadStatus()),
              style: FilledButton.styleFrom(
                backgroundColor: kBrand,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(s.subscribeNow,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedMenuCard(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 100),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: _MenuCard(icon: icon, title: title, subtitle: subtitle, onTap: onTap),
    );
  }
}

class _MenuCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kBrand.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: kBrand, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF111827))),
                    const SizedBox(height: 3),
                    Text(widget.subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

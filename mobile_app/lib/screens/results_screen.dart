import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../l10n/app_strings.dart';
import 'hospital_selection_screen.dart';
import 'history_screen.dart';

// ── Vital sign status helpers ─────────────────────────────────────────────────

enum _VitalStatus { normal, elevated, high, low, critical }

class _VitalInfo {
  final String label;
  final String value;
  final String statusLabel;
  final _VitalStatus status;
  final IconData icon;
  final Color iconColor;

  const _VitalInfo({
    required this.label,
    required this.value,
    required this.statusLabel,
    required this.status,
    required this.icon,
    required this.iconColor,
  });
}

Color _statusColor(_VitalStatus s) {
  switch (s) {
    case _VitalStatus.normal:   return const Color(0xFF22C55E);
    case _VitalStatus.elevated: return const Color(0xFFF97316);
    case _VitalStatus.high:     return const Color(0xFFF97316);
    case _VitalStatus.low:      return const Color(0xFFF97316);
    case _VitalStatus.critical: return const Color(0xFFEF4444);
  }
}

// ── Main screen ───────────────────────────────────────────────────────────────

class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> vitals;
  final String measurementId;
  const ResultsScreen({super.key, required this.vitals, required this.measurementId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _analyzing = false;
  Map<String, dynamic>? _insight;
  Map<String, dynamic>? _hospitals;
  String? _error;
  bool _aiExpanded = false;

  static const Color _green = Color(0xFF22C55E);
  static const Color _bgGrey = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() { _analyzing = true; _error = null; });
    try {
      final res = await ApiService.analyzeAndSuggest(
        measurementId: widget.measurementId,
        latitude: 8.54,
        longitude: 39.27,
      );
      setState(() {
        _insight = res['insight'];
        _hospitals = res['hospitals'];
        _analyzing = false;
      });
    } catch (e) {
      setState(() { _error = 'Analysis failed: $e'; _analyzing = false; });
    }
  }

  // ── Overall risk derived from vitals ────────────────────────────────────
  String _overallRisk() {
    if (_insight != null) return _insight!['riskLevel'] ?? 'low';
    final v = widget.vitals;
    final spo2 = v['spo2'] as num?;
    final temp = v['temperatureCelsius'] as num?;
    if (spo2 != null && spo2 < 90) { return 'critical'; }
    if ((spo2 != null && spo2 < 95) || (temp != null && temp > 38.5)) { return 'high'; }
    if ((temp != null && temp > 37.5) || (v['bmi'] != null && (v['bmi'] as num) > 30)) { return 'moderate'; }
    return 'low';
  }

  Color _overallColor() {
    switch (_overallRisk()) {
      case 'critical': return const Color(0xFFEF4444);
      case 'high':     return const Color(0xFFF97316);
      case 'moderate': return const Color(0xFFF97316);
      default:         return _green;
    }
  }

  // ── Build vital info list ────────────────────────────────────────────────
  List<_VitalInfo> _buildVitals(AppStrings s) {
    final v = widget.vitals;
    final list = <_VitalInfo>[];

    // Blood Pressure removed — sensor not available

    // Temperature
    final temp = v['temperatureCelsius'] as num?;
    if (temp != null) {
      _VitalStatus tStatus;
      String tLabel;
      if (temp > 39) { tStatus = _VitalStatus.critical; tLabel = s.statusFever; }
      else if (temp > 37.5) { tStatus = _VitalStatus.elevated; tLabel = s.statusFever; }
      else { tStatus = _VitalStatus.normal; tLabel = s.statusNormal; }
      list.add(_VitalInfo(
        label: s.temperature, value: '${temp.toStringAsFixed(1)}°C',
        statusLabel: tLabel, status: tStatus,
        icon: Icons.thermostat, iconColor: const Color(0xFFF97316),
      ));
    }

    // SpO2
    final spo2 = v['spo2'] as num?;
    if (spo2 != null) {
      _VitalStatus oStatus;
      String oLabel;
      if (spo2 < 90) { oStatus = _VitalStatus.critical; oLabel = s.statusLowOxygen; }
      else if (spo2 < 95) { oStatus = _VitalStatus.low; oLabel = s.statusLowOxygen; }
      else { oStatus = _VitalStatus.normal; oLabel = s.statusNormalOxygen; }
      list.add(_VitalInfo(
        label: s.spo2, value: '$spo2%',
        statusLabel: oLabel, status: oStatus,
        icon: Icons.water_drop, iconColor: const Color(0xFF3B82F6),
      ));
    }

    // Heart Rate
    final hr = v['heartRate'] as num?;
    if (hr != null) {
      _VitalStatus hrStatus;
      String hrLabel;
      if (hr > 120 || hr < 50) { hrStatus = _VitalStatus.critical; hrLabel = hr > 120 ? s.statusHigh : s.statusLow; }
      else if (hr > 100) { hrStatus = _VitalStatus.elevated; hrLabel = s.statusElevated; }
      else if (hr < 60) { hrStatus = _VitalStatus.low; hrLabel = s.statusLow; }
      else { hrStatus = _VitalStatus.normal; hrLabel = s.statusNormal; }
      list.add(_VitalInfo(
        label: s.heartRate, value: '$hr bpm',
        statusLabel: hrLabel, status: hrStatus,
        icon: Icons.monitor_heart, iconColor: const Color(0xFFEF4444),
      ));
    }

    // BMI
    final bmi = v['bmi'] as num?;
    if (bmi != null) {
      _VitalStatus bmiStatus;
      String bmiLabel;
      if (bmi >= 30) { bmiStatus = _VitalStatus.high; bmiLabel = s.statusObese; }
      else if (bmi >= 25) { bmiStatus = _VitalStatus.elevated; bmiLabel = s.statusOverweight; }
      else if (bmi < 18.5) { bmiStatus = _VitalStatus.low; bmiLabel = s.statusUnderweight; }
      else { bmiStatus = _VitalStatus.normal; bmiLabel = s.statusNormal; }
      list.add(_VitalInfo(
        label: s.bmi, value: bmi.toStringAsFixed(1),
        statusLabel: bmiLabel, status: bmiStatus,
        icon: Icons.accessibility_new, iconColor: const Color(0xFF8B5CF6),
      ));
    }

    // Height & Weight (display only, no status color)
    final wt = v['weightKg'] as num?;
    final ht = v['heightCm'] as num?;
    if (wt != null && wt != 0) {
      list.add(_VitalInfo(
        label: s.weight, value: '${wt.toStringAsFixed(1)} kg',
        statusLabel: s.statusNormal, status: _VitalStatus.normal,
        icon: Icons.monitor_weight, iconColor: const Color(0xFF6B7280),
      ));
    }
    if (ht != null) {
      list.add(_VitalInfo(
        label: s.height, value: '${ht.toStringAsFixed(0)} cm',
        statusLabel: s.statusNormal, status: _VitalStatus.normal,
        icon: Icons.height, iconColor: const Color(0xFF6B7280),
      ));
    }

    return list;
  }

  // ── Health tip rotation ──────────────────────────────────────────────────
  String _healthTip(AppStrings s) {
    final tips = [
      s.healthTip1,
      s.healthTip2,
      s.healthTip3,
    ];
    return tips[DateTime.now().day % tips.length];
  }

  @override
  Widget build(BuildContext context) {
    final s = LanguageService.instance.strings;
    final patient = AuthService.patient;
    final name = patient?['name'] ?? 'User';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final now = DateTime.now();
    final dateStr = '${_monthName(now.month)} ${now.day}, ${now.year}';
    final vitals = _buildVitals(s);
    final overallColor = _overallColor();
    final risk = _overallRisk();

    String overallLabel;
    String overallSub;
    if (risk == 'critical' || risk == 'high') {
      overallLabel = risk == 'critical' ? s.overallCritical : s.overallModerate;
      overallSub = risk == 'critical' ? s.vitalsCritical : s.vitalsNeedAttention;
    } else if (risk == 'moderate') {
      overallLabel = s.overallModerate;
      overallSub = s.vitalsNeedAttention;
    } else {
      overallLabel = s.overallHealthy;
      overallSub = s.vitalsLookGood;
    }

    return Scaffold(
      backgroundColor: _bgGrey,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            _buildTopBar(context, s, name, initials),
            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  const SizedBox(height: 12),
                  // Checkup card
                  _buildCheckupCard(s, dateStr, overallColor, overallLabel, overallSub, vitals),
                  const SizedBox(height: 20),
                  // Quick Actions label
                  Text(s.quickActions,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 12),
                  // AI insight banner
                  _buildAIBanner(s),
                  const SizedBox(height: 12),
                  // History + Find Clinic row
                  _buildQuickActionRow(context, s),
                  const SizedBox(height: 20),
                  // Health tip
                  _buildHealthTip(s),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, AppStrings s, String name, String initials) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: _green,
            child: Text(initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                Text('ID: #${widget.measurementId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF6B7280)),
            tooltip: s.logout,
            onPressed: () async {
              await AuthService.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(body: Center(child: Text(s.loggedOut))),
                  ),
                  (r) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Checkup card ─────────────────────────────────────────────────────────
  Widget _buildCheckupCard(AppStrings s, String dateStr, Color overallColor,
      String overallLabel, String overallSub, List<_VitalInfo> vitals) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.latestCheckup,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827))),
              Text(dateStr, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
          const SizedBox(height: 14),
          // Overall status row
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: overallColor.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  overallColor == _green ? Icons.check_circle : Icons.warning_rounded,
                  color: overallColor, size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(overallLabel,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: overallColor)),
                    Text(overallSub,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 14),
          // Vitals grid — 2 per row
          _buildVitalsGrid(vitals),
          // Error / retry
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                  TextButton(
                    onPressed: () { setState(() => _error = null); _analyze(); },
                    child: Text(LanguageService.instance.strings.retryAnalysis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVitalsGrid(List<_VitalInfo> vitals) {
    // Pair vitals into rows of 2
    final rows = <Widget>[];
    for (int i = 0; i < vitals.length; i += 2) {
      final left = vitals[i];
      final right = i + 1 < vitals.length ? vitals[i + 1] : null;
      rows.add(Row(
        children: [
          Expanded(child: _vitalCell(left)),
          const SizedBox(width: 12),
          Expanded(child: right != null ? _vitalCell(right) : const SizedBox()),
        ],
      ));
      if (i + 2 < vitals.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  Widget _vitalCell(_VitalInfo info) {
    final color = _statusColor(info.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(info.icon, size: 14, color: info.iconColor),
            const SizedBox(width: 4),
            Text(info.label.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 4),
        Text(info.value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(info.statusLabel,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  // ── AI banner ────────────────────────────────────────────────────────────
  Widget _buildAIBanner(AppStrings s) {
    return GestureDetector(
      onTap: () => setState(() => _aiExpanded = !_aiExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: _green,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.askDoctorAI,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          _analyzing ? s.analyzingVitals : s.getInstantAdvice,
                          style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _analyzing
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(
                          _aiExpanded ? Icons.keyboard_arrow_up : Icons.arrow_forward,
                          color: Colors.white, size: 22,
                        ),
                ],
              ),
            ),
            // Expanded AI content
            if (_aiExpanded && _insight != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Risk chip
                    Row(
                      children: [
                        Text(s.aiInsightTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                                color: Color(0xFF111827))),
                        const Spacer(),
                        _riskChip(_insight!['riskLevel'] ?? 'low'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Summary
                    Text(_insight!['summaryText'] ?? '',
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF374151))),
                    // Advice
                    if ((_insight!['preventiveAdvice'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _green.withAlpha(80)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF16A34A)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${s.adviceLabel}${_insight!['preventiveAdvice']}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF166534), height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Disclaimer
                    const SizedBox(height: 10),
                    Text(s.disclaimer,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic)),
                    // Find hospitals button
                    if (_hospitals != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HospitalSelectionScreen(
                                hospitals: _hospitals!,
                                measurementId: widget.measurementId,
                                aiInsightId: _insight!['_id'],
                                conditionLabel: _insight!['conditionCategory'] ?? '',
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.local_hospital, size: 18),
                          label: Text(s.viewSuggestedHospitals),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (_aiExpanded && _insight == null && !_analyzing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(s.noInsightYet,
                    style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _riskChip(String level) {
    Color c;
    switch (level) {
      case 'critical': c = const Color(0xFFEF4444); break;
      case 'high':     c = const Color(0xFFF97316); break;
      case 'moderate': c = const Color(0xFFF59E0B); break;
      default:         c = _green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(20)),
      child: Text(level.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c)),
    );
  }

  // ── Quick action row ─────────────────────────────────────────────────────
  Widget _buildQuickActionRow(BuildContext context, AppStrings s) {
    return Row(
      children: [
        Expanded(
          child: _quickActionCard(
            icon: Icons.history_rounded,
            label: s.history,
            onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _quickActionCard(
            icon: Icons.location_on_outlined,
            label: s.findClinic,
            onTap: _hospitals != null
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HospitalSelectionScreen(
                        hospitals: _hospitals!,
                        measurementId: widget.measurementId,
                        aiInsightId: _insight?['_id'],
                        conditionLabel: _insight?['conditionCategory'] ?? '',
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _quickActionCard({required IconData icon, required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: onTap != null ? const Color(0xFF374151) : Colors.grey),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14,
                    color: onTap != null ? const Color(0xFF111827) : Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ── Health tip ───────────────────────────────────────────────────────────
  Widget _buildHealthTip(AppStrings s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: _green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.healthTip,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                        color: Color(0xFF166534))),
                const SizedBox(height: 4),
                Text(_healthTip(s),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }
}

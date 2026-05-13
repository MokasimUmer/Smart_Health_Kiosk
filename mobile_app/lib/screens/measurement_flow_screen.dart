import 'dart:async';
import 'package:flutter/material.dart';
import '../services/kiosk_service.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/language_service.dart';
import 'results_screen.dart';

const List<Map<String, String>> _measurementSteps = [
  {'id': 'height', 'label': 'Height', 'hint': 'Stand still under the sensor'},
  {'id': 'weight', 'label': 'Weight', 'hint': 'Stand on the scale'},
  {'id': 'spo2_hr', 'label': 'SpO2 & Heart Rate', 'hint': 'Place finger on the oximeter'},
  {'id': 'temperature', 'label': 'Temperature', 'hint': 'Stay in front of the sensor'},
];

bool _isSensorResultValid(String sensorId, Map<String, dynamic>? data) {
  if (data == null) return false;
  switch (sensorId) {
    case 'height': return data['heightCm'] != null;
    case 'weight': return data['weightKg'] != null && data['weightKg'] != 0;
    case 'spo2_hr': return (data['heartRate'] != null || data['spo2'] != null);
    case 'temperature': return data['temperatureCelsius'] != null;
    default: return false;
  }
}

void _mergeVitals(Map<String, dynamic> vitals, String sensorId, Map<String, dynamic> data) {
  if (sensorId == 'height') { vitals['heightCm'] = data['heightCm']; }
  else if (sensorId == 'weight') { final w = data['weightKg']; vitals['weightKg'] = (w != null && w != 0) ? w : null; }
  else if (sensorId == 'spo2_hr') { vitals['heartRate'] = data['heartRate']; vitals['spo2'] = data['spo2']; }
  else if (sensorId == 'temperature') { vitals['temperatureCelsius'] = data['temperatureCelsius']; }
}

void _computeDerived(Map<String, dynamic> vitals) {
  final weightKg = vitals['weightKg'] as num?;
  final heightCm = vitals['heightCm'] as num?;
  if (weightKg != null && heightCm != null && heightCm > 0) {
    final heightM = heightCm / 100;
    vitals['bmi'] = (weightKg / (heightM * heightM)).roundToDouble();
  }
}

/// Maps a step id to its translated label.
String _translatedLabel(String id) {
  final s = LanguageService.instance.strings;
  switch (id) {
    case 'height': return s.height;
    case 'weight': return s.weight;
    case 'spo2_hr': return '${s.spo2} & ${s.heartRate}';
    case 'temperature': return s.temperature;
    default: return id;
  }
}

class MeasurementFlowScreen extends StatefulWidget {
  final KioskService kiosk;
  const MeasurementFlowScreen({super.key, required this.kiosk});
  @override
  State<MeasurementFlowScreen> createState() => _MeasurementFlowScreenState();
}

class _MeasurementFlowScreenState extends State<MeasurementFlowScreen> {
  int _currentStep = 0;
  final Map<String, dynamic> _vitals = {};
  final List<String> _skipped = [];
  String _status = '';
  bool _measuring = false;
  bool _showCorrectPrompt = false;
  int _correctCountdown = 30;
  int _getReadyCountdown = 0;
  Timer? _countdownTimer;
  bool _flowComplete = false;

  @override
  void dispose() { _countdownTimer?.cancel(); super.dispose(); }

  Future<void> _runStep(int stepIndex) async {
    final s = LanguageService.instance.strings;
    if (stepIndex >= _measurementSteps.length) {
      _computeDerived(_vitals);
      setState(() { _flowComplete = true; _measuring = false; _getReadyCountdown = 0; _status = s.measurementComplete; });
      return;
    }
    final step = _measurementSteps[stepIndex];
    final label = _translatedLabel(step['id']!);
    setState(() { _currentStep = stepIndex; _measuring = false; _showCorrectPrompt = false; _getReadyCountdown = 5; _status = s.getReadyFor(label); });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final s2 = LanguageService.instance.strings;
      setState(() {
        _getReadyCountdown--;
        _status = _getReadyCountdown > 0 ? s2.getReadyCountdown(_getReadyCountdown) : s2.measuring;
      });
      if (_getReadyCountdown <= 0) { t.cancel(); _doMeasure(stepIndex); }
    });
  }

  Future<void> _doMeasure(int stepIndex) async {
    final s = LanguageService.instance.strings;
    final step = _measurementSteps[stepIndex];
    final sensorId = step['id']!;
    final label = _translatedLabel(sensorId);
    setState(() { _measuring = true; _status = s.measuringLabel(label); });
    final result = await widget.kiosk.startMeasurement(sensorId);
    final data = result != null ? result['data'] as Map<String, dynamic>? : null;
    if (!mounted) return;
    if (_isSensorResultValid(sensorId, data)) {
      _mergeVitals(_vitals, sensorId, data!);
      await _runStep(stepIndex + 1);
      return;
    }
    final s2 = LanguageService.instance.strings;
    setState(() { _measuring = false; _showCorrectPrompt = true; _correctCountdown = 15; _status = s2.sensorNotDetected; });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _correctCountdown--;
        if (_correctCountdown <= 0) { t.cancel(); _skipped.add(sensorId); _showCorrectPrompt = false; _runStep(stepIndex + 1); }
      });
    });
  }

  void _onRetry() { _countdownTimer?.cancel(); setState(() => _showCorrectPrompt = false); _runStep(_currentStep); }
  void _onSkip() { _countdownTimer?.cancel(); setState(() { _showCorrectPrompt = false; _skipped.add(_measurementSteps[_currentStep]['id']!); }); _runStep(_currentStep + 1); }
  void _onRemeasure() { setState(() { _currentStep = 0; _vitals.clear(); _skipped.clear(); _flowComplete = false; _status = ''; }); _runStep(0); }

  Future<void> _onDone() async {
    final s = LanguageService.instance.strings;
    final measuredAt = DateTime.now().toIso8601String();
    final payload = {'kioskId': widget.kiosk.kioskId, 'vitals': Map<String, dynamic>.from(_vitals), 'measuredAt': measuredAt};
    await SyncService.instance.bufferMeasurement(payload);
    try {
      final saveRes = await ApiService.createMeasurement(kioskId: widget.kiosk.kioskId!, vitals: _vitals);
      if (saveRes.containsKey('measurement') && mounted) {
        final measurementId = saveRes['measurement']['_id'];
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultsScreen(vitals: _vitals, measurementId: measurementId)));
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.savedLocally)));
      Navigator.pop(context);
    }
  }

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _runStep(0)); }

  @override
  Widget build(BuildContext context) {
    final s = LanguageService.instance.strings;
    if (_flowComplete) return _buildSummary();
    final step = _currentStep < _measurementSteps.length
        ? _measurementSteps[_currentStep]
        : null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(s.measurementFlowTitle),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      // Scaffold.body is always bounded — safe to use Expanded here
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Progress bar ──────────────────────────────────────────────
            Row(
              children: List.generate(
                _measurementSteps.length,
                (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _currentStep
                          ? const Color(0xFF12EC12)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // ── Step label ────────────────────────────────────────────────
            Text(
              s.stepOf(_currentStep + 1, _measurementSteps.length),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 6),
            if (step != null) ...[
              Text(
                _translatedLabel(step['id']!),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                step['hint']!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey),
              ),
            ],
            // ── Main content — Expanded fills remaining space ─────────────
            Expanded(
              child: Center(
                child: _showCorrectPrompt
                    ? _buildCorrectPrompt()
                    : _getReadyCountdown > 0
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.5, end: 1.0),
                                duration: const Duration(milliseconds: 400),
                                key: ValueKey(_getReadyCountdown),
                                builder: (_, v, child) =>
                                    Opacity(opacity: v, child: child),
                                child: Text(
                                  '$_getReadyCountdown',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF12EC12),
                                      ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(_status,
                                  style:
                                      Theme.of(context).textTheme.bodyLarge),
                            ],
                          )
                        : _measuring
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                      color: Color(0xFF12EC12)),
                                  const SizedBox(height: 16),
                                  Text(s.pleaseWaitSensor,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge),
                                ],
                              )
                            : Text(_status,
                                style: Theme.of(context).textTheme.bodyLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrectPrompt() {
    final s = LanguageService.instance.strings;
    final step = _currentStep < _measurementSteps.length ? _measurementSteps[_currentStep] : null;
    final sensorLabel = step != null ? _translatedLabel(step['id']!) : 'Sensor';
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.amber.shade700),
            const SizedBox(height: 12),
            Text(s.sensorNotDetectedMsg(sensorLabel), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(s.nextStepIn(_correctCountdown),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(s.retry),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF12EC12),
                    foregroundColor: Colors.white,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _onSkip,
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: Text(s.skip),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF12EC12),
                    side: const BorderSide(color: Color(0xFF12EC12)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary screen shown after all steps complete ─────────────────────────
  Widget _buildSummary() {
    final s = LanguageService.instance.strings;
    final v = _vitals;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(s.summaryTitle),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF12EC12).withAlpha(20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF12EC12), shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.measurementComplete,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF111827))),
                      Text(s.vitalSigns,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Vitals list
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              children: [
                _summaryRow(s.height, Icons.height, const Color(0xFF6B7280),
                    v['heightCm'] != null ? '${v['heightCm']} cm' : _skipped.contains('height') ? s.skipped : '—'),
                _divider(),
                _summaryRow(s.weight, Icons.monitor_weight, const Color(0xFF6B7280),
                    (v['weightKg'] != null && v['weightKg'] != 0) ? '${v['weightKg']} kg' : _skipped.contains('weight') ? s.skipped : '—'),
                _divider(),
                _summaryRow(s.heartRate, Icons.monitor_heart, const Color(0xFFEF4444),
                    v['heartRate'] != null ? '${v['heartRate']} bpm' : _skipped.contains('spo2_hr') ? s.skipped : '—'),
                _divider(),
                _summaryRow(s.spo2, Icons.water_drop, const Color(0xFF3B82F6),
                    v['spo2'] != null ? '${v['spo2']}%' : _skipped.contains('spo2_hr') ? s.skipped : '—'),
                _divider(),
                _summaryRow(s.temperature, Icons.thermostat, const Color(0xFFF97316),
                    v['temperatureCelsius'] != null ? '${v['temperatureCelsius']}°C' : _skipped.contains('temperature') ? s.skipped : '—'),
                if (v['bmi'] != null) ...[
                  _divider(),
                  _summaryRow(s.bmi, Icons.accessibility_new, const Color(0xFF8B5CF6),
                      '${v['bmi']}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Done button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _onDone,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(s.doneViewResults,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF12EC12),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Re-measure button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _onRemeasure,
              icon: const Icon(Icons.refresh),
              label: Text(s.remeasure),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF12EC12),
                side: const BorderSide(color: Color(0xFF12EC12)),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF3F4F6));

  Widget _summaryRow(String label, IconData icon, Color iconColor, String value) {
    final isSkipped = value == LanguageService.instance.strings.skipped;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isSkipped ? Colors.grey : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

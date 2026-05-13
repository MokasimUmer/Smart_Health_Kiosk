import 'package:flutter/material.dart';
import '../services/kiosk_service.dart';
import '../services/language_service.dart';
import 'measurement_flow_screen.dart';

class KioskScreen extends StatefulWidget {
  const KioskScreen({super.key});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  final _kiosk = KioskService();
  final _ipCtrl = TextEditingController(text: '192.168.137.204');
  bool _connecting = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = LanguageService.instance.strings.notConnected;
  }

  Future<void> _connect() async {
    final s = LanguageService.instance.strings;
    setState(() { _connecting = true; _status = s.connecting; });
    final ok = await _kiosk.connect(_ipCtrl.text.trim());
    setState(() {
      _connecting = false;
      _status = ok
          ? s.connected(_kiosk.kioskId ?? '')
          : (_kiosk.lastError ?? s.connectionFailed);
    });
  }

  Future<void> _startMeasurement() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MeasurementFlowScreen(kiosk: _kiosk)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = LanguageService.instance.strings;
    final connected = _kiosk.isConnected;
    return Scaffold(
      appBar: AppBar(title: Text(s.kioskTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(connected ? Icons.wifi : Icons.wifi_off,
                            color: connected ? Colors.green : Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_status,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2),
                        ),
                      ],
                    ),
                    if (!connected) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ipCtrl,
                        decoration: InputDecoration(
                          labelText: s.kioskIpLabel,
                          border: const OutlineInputBorder(),
                          hintText: s.kioskIpHint,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(s.kioskNetworkHint,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _connecting ? null : _connect,
                          child: _connecting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : Text(s.connectToKioskBtn),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(s.skipKiosk),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (connected) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.monitor_heart,
                          size: 48, color: Colors.indigo),
                      const SizedBox(height: 12),
                      Text(s.readyToMeasure,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(s.readyInstructions,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _startMeasurement,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(s.startMeasurementBtn),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

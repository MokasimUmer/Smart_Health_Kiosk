import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class ServerConfigScreen extends StatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _ipCtrl = TextEditingController();
  bool _loading = true;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentIp();
  }

  Future<void> _loadCurrentIp() async {
    final ip = await AuthService.getServerIp();
    setState(() {
      _ipCtrl.text = ip;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    await AuthService.setServerIp(ip);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server IP saved'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _testConnection() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    setState(() { _testing = true; _testResult = null; });
    try {
      await AuthService.setServerIp(ip);
      final base = await AuthService.baseUrl;
      // Try hitting the backend health endpoint
      final response = await http.get(Uri.parse('$base/auth/me')).timeout(
        const Duration(seconds: 5),
      );
      // Any HTTP response (even 401) means the server is reachable
      debugPrint('Server responded with ${response.statusCode}');
      setState(() {
        _testSuccess = true;
        _testResult = 'Server reachable at $ip:5000 ✓';
      });
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Could not reach $ip:5000 — check Wi-Fi and that the backend is running.';
      });
    }
    setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Settings'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.dns_outlined, size: 56, color: Colors.indigo),
                const SizedBox(height: 16),
                Text(
                  'Backend Server IP',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your PC\'s IPv4 address (run "ipconfig" on Windows or "ifconfig" on Mac/Linux). Your phone and PC must be on the same Wi-Fi.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _ipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'PC IP Address',
                    hintText: 'e.g. 192.168.1.100',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.computer),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                Text(
                  'Port 5000 is used automatically.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                if (_testResult != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _testSuccess ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testSuccess ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testing ? null : _testConnection,
                        child: _testing
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Test Connection'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

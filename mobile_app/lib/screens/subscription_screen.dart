import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Uint8List? _receiptBytes;
  String? _receiptName;
  final _amountCtrl = TextEditingController(text: '500');
  String _paymentMethod = 'Telebirr';
  bool _loading = false;
  String? _message;
  bool _success = false;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _receiptBytes = result.files.single.bytes!;
        _receiptName = result.files.single.name;
      });
    }
  }

  Future<void> _submit() async {
    final s = LanguageService.instance.strings;
    if (_receiptBytes == null) {
      setState(() => _message = s.pleaseSelectReceipt);
      return;
    }
    setState(() { _loading = true; _message = null; });
    try {
      final res = await ApiService.uploadSubscriptionReceipt(
        receiptBytes: _receiptBytes!,
        receiptFilename: _receiptName ?? 'receipt.png',
        amount: double.parse(_amountCtrl.text),
        paymentMethod: _paymentMethod,
      );
      if (res.containsKey('subscription')) {
        setState(() {
          _success = true;
          _message = s.subscriptionSubmitted;
        });
      } else {
        setState(() => _message = res['error'] ?? s.failed);
      }
    } catch (e) {
      setState(() => _message = 'Error: $e');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = LanguageService.instance.strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.subscribeTitle)),
      body: SingleChildScrollView(
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
                    Text(s.annualSubscription,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(s.subscriptionInstructions),
                    const SizedBox(height: 16),
                    Text(s.subscriptionAmount,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                  labelText: s.amountEtb,
                  border: const OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: InputDecoration(
                  labelText: s.paymentMethod,
                  border: const OutlineInputBorder()),
              items: ['Telebirr', 'CBE Birr', 'Bank Transfer', 'Other']
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.upload_file),
              label: Text(_receiptBytes == null
                  ? s.uploadReceiptPhoto
                  : s.receiptSelected),
            ),
            if (_receiptBytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_receiptBytes!,
                      height: 200, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 24),
            if (_message != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: _success
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_message!,
                    style: TextStyle(
                        color: _success
                            ? Colors.green.shade700
                            : Colors.red.shade700)),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading || _success ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(s.submitSubscriptionRequest),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

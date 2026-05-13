import 'package:flutter/material.dart';
import '../services/language_service.dart';

class LanguageScreen extends StatelessWidget {
  final LanguageService languageService;
  const LanguageScreen({super.key, required this.languageService});

  @override
  Widget build(BuildContext context) {
    final s = languageService.strings;
    final current = languageService.currentCode;

    final languages = [
      ('en', s.langEnglish),
      ('am', s.langAmharic),
      ('om', s.langAfaanOromo),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.selectLanguage), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: languages.map((lang) {
          final code = lang.$1;
          final name = lang.$2;
          final selected = current == code;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                name,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Theme.of(context).colorScheme.primary : null,
                  fontSize: 16,
                ),
              ),
              trailing: selected
                  ? Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary)
                  : const Icon(Icons.radio_button_unchecked,
                      color: Colors.grey),
              onTap: () async {
                await languageService.setLanguage(code);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesThemeCard extends StatefulWidget {
  const PreferencesThemeCard({super.key});

  @override
  State<PreferencesThemeCard> createState() => _PreferencesThemeCardState();
}

class _PreferencesThemeCardState extends State<PreferencesThemeCard> {
  String _selectedTheme = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // HORROR: Calls real platform channel without mock in widget test
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTheme =
          prefs.getString('user_theme_preference') ?? 'Dark Indigo (Default)';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Theme & Appearance Settings',
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12.0),
            if (_isLoading)
              const Text('Reading stored configuration...')
            else
              Text('Current Active Theme: $_selectedTheme'),
          ],
        ),
      ),
    );
  }
}

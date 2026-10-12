import 'package:flutter/material.dart';

const safetyParagraph =
    'I am awake and I choose to turn off this alarm without finishing my challenges.';

/// Emergency exit after 15 minutes of ringing: typing the paragraph exactly
/// pops `true`.
class SafetyExitScreen extends StatefulWidget {
  const SafetyExitScreen({super.key});

  @override
  State<SafetyExitScreen> createState() => _SafetyExitScreenState();
}

class _SafetyExitScreenState extends State<SafetyExitScreen> {
  final _text = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_text.text.trim() == safetyParagraph) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency stop')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Type this sentence exactly to stop the alarm:'),
          const SizedBox(height: 12),
          SelectableText(
            safetyParagraph,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('safety-text'),
            controller: _text,
            maxLines: 3,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              errorText: _wrong ? 'Not exactly the same — try again.' : null,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('safety-confirm'),
            onPressed: _confirm,
            child: const Text('Stop the alarm'),
          ),
        ],
      ),
    );
  }
}

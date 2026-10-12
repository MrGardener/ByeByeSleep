import 'package:flutter/material.dart';

/// Common frame for a challenge's setup screen: explanation, content, and a
/// Save button (`Key('setup-save')`) that pops the params.
class SetupScaffold extends StatelessWidget {
  const SetupScaffold({
    super.key,
    required this.title,
    required this.explanation,
    required this.child,
    required this.onSave,
  });

  final String title;
  final String explanation;
  final Widget child;

  /// Null disables Save (setup not complete yet).
  final Map<String, Object?>? Function()? onSave;

  @override
  Widget build(BuildContext context) {
    final save = onSave;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(explanation),
            const SizedBox(height: 16),
            Expanded(child: Center(child: child)),
            FilledButton(
              key: const Key('setup-save'),
              onPressed: save == null
                  ? null
                  : () {
                      final params = save();
                      if (params != null) Navigator.of(context).pop(params);
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

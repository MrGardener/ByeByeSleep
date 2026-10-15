import 'package:flutter/material.dart';

import '../core/challenge.dart';
import 'sentence.dart';

/// Retype: type the sentence shown. Capitals and punctuation do not count.
class RetypeChallenge extends StatefulWidget {
  const RetypeChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  State<RetypeChallenge> createState() => _RetypeState();
}

class _RetypeState extends State<RetypeChallenge> {
  late final Retype _rule = switch (widget.args.params['sentence']) {
    final String s => Retype(s), // tests
    _ => Retype.random(widget.args.random, widget.args.difficulty),
  };
  final _controller = TextEditingController();
  bool _done = false;

  void _changed(String typed) {
    setState(() {});
    if (!_done && _rule.accepts(typed)) {
      _done = true;
      widget.args.onPassed();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _rule.sentence,
                key: const Key('retype-sentence'),
                textAlign: TextAlign.center,
                style: text.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('retype-field'),
            controller: _controller,
            onChanged: _changed,
            enabled: !_done,
            minLines: 1,
            maxLines: 4,
            // No suggestions or autocorrect: the typing is the challenge.
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              labelText: 'Type it here',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _done
                ? 'Well typed!'
                : '${_rule.wordsRight(_controller.text)} of '
                      '${_rule.wordCount} words right',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

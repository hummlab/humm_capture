import 'package:flutter/material.dart';

import 'slack_integration_repository.dart';

/// Non-secret message preferences, editable independently from the webhook.
class SlackMessageSettingsForm extends StatefulWidget {
  const SlackMessageSettingsForm({required this.settings, required this.onSave, required this.busy, super.key});
  final SlackMessageSettings settings;
  final ValueChanged<SlackMessageSettings> onSave;
  final bool busy;

  @override
  State<SlackMessageSettingsForm> createState() => _SlackMessageSettingsFormState();
}

class _SlackMessageSettingsFormState extends State<SlackMessageSettingsForm> {
  final _form = GlobalKey<FormState>();
  late final _feedback = TextEditingController(text: widget.settings.feedbackHeading);
  late final _bug = TextEditingController(text: widget.settings.bugHeading);
  late final _link = TextEditingController(text: widget.settings.linkLabel);
  late bool _description = widget.settings.includeDescription;

  @override
  void dispose() {
    _feedback.dispose();
    _bug.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Message settings', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        const Text('Report titles take priority over these fallback headings.'),
        const SizedBox(height: 16),
        for (final field in [(_feedback, 'Feedback heading'), (_bug, 'Bug heading'), (_link, 'Report link label')]) ...[
          TextFormField(
            controller: field.$1,
            enabled: !widget.busy,
            maxLength: 100,
            decoration: InputDecoration(labelText: field.$2),
            validator: (value) => value == null || value.trim().isEmpty || RegExp(r'[<>|\r\n]').hasMatch(value)
                ? 'Enter a label without link markup.'
                : null,
          ),
          const SizedBox(height: 12),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include tester description'),
          subtitle: const Text('Disable if descriptions should remain only in the authenticated panel.'),
          value: _description,
          onChanged: widget.busy ? null : (value) => setState(() => _description = value),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.busy
              ? null
              : () {
                  if (_form.currentState?.validate() != true) return;
                  widget.onSave(
                    SlackMessageSettings(
                      feedbackHeading: _feedback.text.trim(),
                      bugHeading: _bug.text.trim(),
                      linkLabel: _link.text.trim(),
                      includeDescription: _description,
                    ),
                  );
                },
          child: const Text('Save message settings'),
        ),
      ],
    ),
  );
}

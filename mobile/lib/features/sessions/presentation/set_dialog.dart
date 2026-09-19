import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';

class SetInput {
  const SetInput({required this.reps, this.loadKg});

  final int reps;
  final double? loadKg;
}

/// Pede repeticoes e carga de uma serie. Retorna null se cancelado.
Future<SetInput?> showSetDialog(
  BuildContext context, {
  required String title,
  int? initialReps,
  double? initialLoad,
}) {
  return showDialog<SetInput>(
    context: context,
    builder: (context) => _SetDialog(title: title, initialReps: initialReps, initialLoad: initialLoad),
  );
}

class _SetDialog extends StatefulWidget {
  const _SetDialog({required this.title, this.initialReps, this.initialLoad});

  final String title;
  final int? initialReps;
  final double? initialLoad;

  @override
  State<_SetDialog> createState() => _SetDialogState();
}

class _SetDialogState extends State<_SetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reps =
      TextEditingController(text: widget.initialReps?.toString() ?? '');
  late final TextEditingController _load = TextEditingController(
    text: widget.initialLoad == null ? '' : formatLoad(widget.initialLoad).replaceAll(' kg', ''),
  );

  @override
  void dispose() {
    _reps.dispose();
    _load.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final loadText = _load.text.trim();
    Navigator.of(context).pop(
      SetInput(
        reps: int.parse(_reps.text.trim()),
        loadKg: loadText.isEmpty ? null : parseDecimal(loadText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('set-reps'),
              controller: _reps,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Repetições'),
              validator: (value) {
                final reps = int.tryParse((value ?? '').trim());
                if (reps == null || reps < 0) return 'Informe as repetições';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('set-load'),
              controller: _load,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Carga em kg (opcional)'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return null;
                final load = parseDecimal(text);
                if (load == null || load < 0) return 'Carga inválida';
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(key: const Key('set-save'), onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}

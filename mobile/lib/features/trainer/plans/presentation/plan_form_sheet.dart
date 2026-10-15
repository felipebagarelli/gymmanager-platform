import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../billing/domain/billing.dart';
import '../data/trainer_billing_repository.dart';

const _minPriceCents = 100;
const _maxPriceCents = 10000000;

/// Criar (sem [initial]) ou editar um plano. Retorna null se o personal cancelar.
Future<PlanDraft?> showPlanForm(BuildContext context, {Plan? initial, int subscribers = 0}) {
  return showModalBottomSheet<PlanDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PlanForm(initial: initial, subscribers: subscribers),
  );
}

class _PlanForm extends StatefulWidget {
  const _PlanForm({required this.initial, required this.subscribers});

  final Plan? initial;
  final int subscribers;

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _price = TextEditingController(
    text: widget.initial == null ? '' : formatPrice(widget.initial!.priceCents).replaceAll('R\$ ', ''),
  );
  late final _description = TextEditingController(text: widget.initial?.description ?? '');
  late bool _active = widget.initial?.active ?? true;
  final _errors = <String, String>{};

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final cents = parsePriceCents(_price.text);
    setState(() {
      _errors.clear();
      if (_name.text.trim().isEmpty) _errors['name'] = 'Dê um nome ao plano';
      if (cents == null) {
        _errors['price'] = 'Informe o valor mensal (ex.: 150,00)';
      } else if (cents < _minPriceCents) {
        _errors['price'] = 'O valor mínimo é R\$ 1,00';
      } else if (cents > _maxPriceCents) {
        _errors['price'] = 'O valor máximo é ${formatPrice(_maxPriceCents)}';
      }
    });
    if (_errors.isNotEmpty) return;
    Navigator.of(context).pop(PlanDraft(
      name: _name.text.trim(),
      priceCents: cents!,
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      active: _active,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final priceChanged = _editing && parsePriceCents(_price.text) != widget.initial!.priceCents;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_editing ? 'EDITAR PLANO' : 'NOVO PLANO', style: AppText.display(30)),
              const SizedBox(height: 14),
              TextField(
                key: const Key('plan-name'),
                controller: _name,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Nome', hintText: 'Ex.: Mensal 3x por semana', errorText: _errors['name'], counterText: ''),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('plan-price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Valor por mês',
                  prefixText: 'R\$ ',
                  hintText: '150,00',
                  errorText: _errors['price'],
                  helperText: priceChanged && widget.subscribers > 0
                      ? 'O novo valor vale para novas assinaturas. Quem já assina continua pagando o valor atual.'
                      : null,
                  helperMaxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('plan-description'),
                controller: _description,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  hintText: 'O que está incluído: treinos, acompanhamento pelo chat...',
                ),
              ),
              if (_editing)
                SwitchListTile(
                  key: const Key('plan-active'),
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  activeThumbColor: AppColors.volt,
                  onChanged: (v) => setState(() => _active = v),
                  title: Text('Disponível para novos alunos', style: AppText.body(size: 15, weight: FontWeight.w600)),
                  subtitle: Text(
                    _active
                        ? 'Aparece para seus alunos assinarem.'
                        : 'Fica oculto para novas assinaturas. Quem já assina continua.',
                    style: AppText.body(size: 12.5, color: AppColors.textMuted),
                  ),
                ),
              const SizedBox(height: 12),
              PillButton(key: const Key('plan-save'), label: _editing ? 'Salvar plano' : 'Criar plano', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

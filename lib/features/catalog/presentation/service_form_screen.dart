import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/service.dart';
import 'catalog_providers.dart';

/// Criação (serviceId == null) ou edição de um serviço.
class ServiceFormScreen extends ConsumerWidget {
  const ServiceFormScreen({super.key, this.serviceId});

  final String? serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (serviceId == null) return const _ServiceForm(existing: null);
    final service = ref.watch(serviceDetailProvider(serviceId!));
    return AsyncValueWidget(
      value: service,
      onRetry: () => ref.invalidate(serviceDetailProvider(serviceId!)),
      data: (s) => _ServiceForm(key: ValueKey(s.id), existing: s),
    );
  }
}

class _ServiceForm extends ConsumerStatefulWidget {
  const _ServiceForm({super.key, required this.existing});

  final Service? existing;

  @override
  ConsumerState<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<_ServiceForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description =
      TextEditingController(text: widget.existing?.description);
  late final _price = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.basePrice.toStringAsFixed(2).replaceAll('.', ','),
  );
  late int? _categoryId = widget.existing?.categoryId;
  late int _duration = widget.existing?.durationMinutes ?? 60;
  bool _saving = false;

  static const _durations = [30, 60, 90, 120, 180, 240, 300, 360, 480];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  double? _parsePrice(String raw) =>
      double.tryParse(raw.replaceAll('.', '').replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      showSnack(context, 'Escolha uma categoria.', error: true);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(catalogRepositoryProvider);
    final uid = ref.read(currentUserIdProvider)!;
    try {
      final base = widget.existing ??
          Service(
            id: '',
            professionalId: uid,
            professionalName: '',
            categoryId: _categoryId!,
            title: '',
            description: '',
            basePrice: 0,
            durationMinutes: 60,
            isActive: true,
          );
      final service = base.copyWith(
        title: _title.text.trim(),
        description: _description.text.trim(),
        basePrice: _parsePrice(_price.text)!,
        durationMinutes: _duration,
        categoryId: _categoryId,
      );
      if (widget.existing == null) {
        await repo.create(service);
      } else {
        await repo.update(service);
        ref.invalidate(serviceDetailProvider(service.id));
      }
      ref.invalidate(myServicesProvider);
      ref.invalidate(servicesProvider);
      if (mounted) {
        showSnack(context, 'Serviço salvo.');
        context.go('/pro/services');
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final isNew = widget.existing == null;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/pro/services')),
        title: Text(isNew ? 'Novo serviço' : 'Editar serviço'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _title,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      hintText: 'Ex.: Instalação de chuveiro elétrico',
                    ),
                    validator: (v) => (v ?? '').trim().length < 3
                        ? 'Informe um título com pelo menos 3 letras'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AsyncValueWidget(
                    value: categories,
                    data: (list) => DropdownButtonFormField<int>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: [
                        for (final c in list)
                          DropdownMenuItem(
                            value: c.id,
                            child: Row(children: [
                              Icon(c.iconData, size: 18),
                              const SizedBox(width: 8),
                              Text(c.name),
                            ]),
                          ),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                      validator: (v) => v == null ? 'Escolha uma categoria' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      hintText: 'O que está incluso, materiais, observações…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Preço inicial',
                            prefixText: 'R\$ ',
                          ),
                          validator: (v) {
                            final p = _parsePrice(v ?? '');
                            if (p == null || p < 0) return 'Preço inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _duration,
                          decoration:
                              const InputDecoration(labelText: 'Duração'),
                          items: [
                            for (final d in _durations)
                              DropdownMenuItem(
                                value: d,
                                child: Text(Formatters.duration(d)),
                              ),
                          ],
                          onChanged: (v) => setState(() => _duration = v ?? 60),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(isNew ? 'Anunciar' : 'Salvar alterações'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../bookings/domain/service_request.dart';
import '../../bookings/presentation/bookings_providers.dart';
import '../../catalog/presentation/catalog_providers.dart';
import 'reviews_providers.dart';

Future<void> showReviewSheet(
    BuildContext context, WidgetRef ref, ServiceRequest request) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReviewForm(request: request),
  );
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({required this.request});

  final ServiceRequest request;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  int _rating = 0;
  final _comment = TextEditingController();
  bool _saving = false;

  static const _labels = ['', 'Ruim', 'Regular', 'Bom', 'Muito bom', 'Excelente'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_rating == 0) {
      showSnack(context, 'Escolha uma nota de 1 a 5 estrelas.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(reviewsRepositoryProvider).create(
            requestId: widget.request.id,
            clientId: widget.request.clientId,
            professionalId: widget.request.professionalId,
            rating: _rating,
            comment: _comment.text,
          );
      ref.invalidate(myRequestsProvider);
      ref.invalidate(professionalReviewsProvider(widget.request.professionalId));
      ref.invalidate(servicesProvider);
      ref.invalidate(serviceDetailProvider);
      if (mounted) {
        Navigator.of(context).pop();
        showSnack(context, 'Obrigado pela avaliação!');
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Avaliar atendimento', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('${widget.request.serviceTitle} · ${widget.request.professionalName}',
              style: text.bodyMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 40,
                  tooltip: _labels[i],
                  icon: Icon(
                    i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber.shade700,
                  ),
                  onPressed: () => setState(() => _rating = i),
                ),
            ],
          ),
          Text(_labels[_rating],
              textAlign: TextAlign.center, style: text.labelLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Comentário (opcional)',
              hintText: 'Conte como foi o atendimento',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Enviar avaliação'),
          ),
        ],
      ),
    );
  }
}

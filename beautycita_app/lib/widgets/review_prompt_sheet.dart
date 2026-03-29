import 'package:flutter/material.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/review_prompt_provider.dart';
import 'package:beautycita/services/toast_service.dart';

class ReviewPromptSheet extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const ReviewPromptSheet({super.key, required this.appointment});

  @override
  State<ReviewPromptSheet> createState() => _ReviewPromptSheetState();
}

class _ReviewPromptSheetState extends State<ReviewPromptSheet> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  String get _salonName {
    final biz = widget.appointment['businesses'];
    if (biz is Map) return biz['name'] as String? ?? 'el salon';
    return 'el salon';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ToastService.showError('Selecciona una calificacion');
      return;
    }
    setState(() => _submitting = true);
    try {
      await submitReview(
        appointmentId: widget.appointment['id'] as String,
        businessId: widget.appointment['business_id'] as String,
        rating: _rating,
        comment: _commentController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ToastService.showSuccess('Gracias por tu resena!');
    } catch (e) {
      setState(() => _submitting = false);
      ToastService.showError('Error al enviar resena');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppConstants.paddingLG,
        right: AppConstants.paddingLG,
        top: AppConstants.paddingLG,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppConstants.paddingLG,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppConstants.paddingLG),

          // Question
          Text(
            'Como fue tu visita a $_salonName?',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingLG),

          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starValue),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    _rating >= starValue
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 44,
                    color: _rating >= starValue
                        ? colorScheme.secondary
                        : colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppConstants.paddingMD),

          // Optional comment
          TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Comentario opcional...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              ),
              contentPadding: const EdgeInsets.all(AppConstants.paddingMD),
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, AppConstants.minTouchHeight),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusSM),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enviar resena'),
            ),
          ),
        ],
      ),
    );
  }
}

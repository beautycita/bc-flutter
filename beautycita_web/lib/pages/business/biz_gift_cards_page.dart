import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/web_theme.dart';
import '../../providers/business_portal_provider.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _giftCardsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, bizId) async {
  final rows = await BCSupabase.client
      .from('gift_cards')
      .select()
      .eq('business_id', bizId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

// ── Page ─────────────────────────────────────────────────────────────────────

class BizGiftCardsPage extends ConsumerWidget {
  const BizGiftCardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _GiftCardsContent(bizId: biz['id'] as String);
      },
    );
  }
}

// ── Content ──────────────────────────────────────────────────────────────────

class _GiftCardsContent extends ConsumerWidget {
  const _GiftCardsContent({required this.bizId});
  final String bizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(_giftCardsProvider(bizId));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: const BoxDecoration(
            color: kWebSurface,
            border: Border(bottom: BorderSide(color: kWebCardBorder)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tarjetas de Regalo',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: kWebTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  cardsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (cards) => Text(
                      '${cards.length} tarjetas',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: kWebTextHint),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showCreateDialog(context, ref, bizId),
                icon: const Icon(Icons.add_outlined, size: 18),
                label: const Text('Nueva Tarjeta'),
                style: FilledButton.styleFrom(
                  backgroundColor: kWebPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: cardsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Error al cargar tarjetas: $e')),
            data: (cards) => cards.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.card_giftcard_outlined,
                            size: 48,
                            color: kWebTextHint.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'Aun no hay tarjetas de regalo',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: kWebTextHint),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              _showCreateDialog(context, ref, bizId),
                          child: const Text('Crear la primera'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _GiftCardTable(cards: cards, bizId: bizId),
                  ),
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(
      BuildContext context, WidgetRef ref, String bizId) {
    showDialog(
      context: context,
      builder: (_) => _CreateGiftCardDialog(
        bizId: bizId,
        onCreated: () => ref.invalidate(_giftCardsProvider(bizId)),
      ),
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _GiftCardTable extends StatelessWidget {
  const _GiftCardTable({required this.cards, required this.bizId});
  final List<Map<String, dynamic>> cards;
  final String bizId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String fmtMoney(dynamic v) =>
        v == null ? '-' : '\$${(v as num).toStringAsFixed(2)}';
    String fmtDate(dynamic v) {
      if (v == null) return '-';
      try {
        final d = DateTime.parse(v.toString());
        return '${d.day}/${d.month}/${d.year}';
      } catch (_) {
        return v.toString();
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.8),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(1.5),
            5: FlexColumnWidth(1.5),
            6: FlexColumnWidth(1.3),
            7: FlexColumnWidth(1.3),
            8: FlexColumnWidth(0.8),
          },
          children: [
            // Header
            TableRow(
              decoration: const BoxDecoration(color: kWebBackground),
              children: [
                _th(theme, 'Codigo'),
                _th(theme, 'Monto'),
                _th(theme, 'Restante'),
                _th(theme, 'Estado'),
                _th(theme, 'Comprador'),
                _th(theme, 'Destinatario'),
                _th(theme, 'Creado'),
                _th(theme, 'Canjeado'),
                _th(theme, ''),
              ],
            ),
            for (final c in cards)
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: kWebCardBorder, width: 0.5),
                  ),
                ),
                children: [
                  _td(theme,
                      child: _CodeCell(code: c['code'] as String? ?? '')),
                  _td(theme,
                      child: Text(fmtMoney(c['amount']),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kWebTextPrimary))),
                  _td(theme,
                      child: Text(fmtMoney(c['remaining_balance']),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: (c['remaining_balance'] as num? ?? 0) > 0
                                ? kWebSuccess
                                : kWebTextHint,
                            fontWeight: FontWeight.w500,
                          ))),
                  _td(theme, child: _StatusBadge(status: c['status'] as String? ?? 'active')),
                  _td(theme,
                      child: Text(c['buyer_name'] as String? ?? '-',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kWebTextSecondary))),
                  _td(theme,
                      child: Text(c['recipient_name'] as String? ?? '-',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kWebTextSecondary))),
                  _td(theme,
                      child: Text(fmtDate(c['created_at']),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kWebTextHint))),
                  _td(theme,
                      child: Text(fmtDate(c['redeemed_at']),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kWebTextHint))),
                  _td(theme,
                      child: _ShareButton(
                          code: c['code'] as String? ?? '',
                          amount: fmtMoney(c['amount']))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _th(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: kWebTextHint,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _td(ThemeData theme, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: child,
    );
  }
}

class _CodeCell extends StatefulWidget {
  const _CodeCell({required this.code});
  final String code;

  @override
  State<_CodeCell> createState() => _CodeCellState();
}

class _CodeCellState extends State<_CodeCell> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.code));
        setState(() => _copied = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _copied = false);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.code,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: kWebPrimary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _copied ? Icons.check_outlined : Icons.copy_outlined,
              size: 14,
              color: _copied ? kWebSuccess : kWebTextHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'active':
        bg = kWebSuccess.withValues(alpha: 0.1);
        fg = kWebSuccess;
      case 'redeemed':
        bg = kWebTextHint.withValues(alpha: 0.1);
        fg = kWebTextHint;
      case 'expired':
        bg = kWebError.withValues(alpha: 0.1);
        fg = kWebError;
      default:
        bg = kWebTextHint.withValues(alpha: 0.1);
        fg = kWebTextHint;
    }

    final labels = {
      'active': 'Activa',
      'redeemed': 'Canjeada',
      'expired': 'Expirada',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        labels[status] ?? status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.code, required this.amount});
  final String code;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Copiar enlace',
      child: IconButton(
        icon: const Icon(Icons.share_outlined, size: 16, color: kWebTextHint),
        onPressed: () {
          final text = 'Tarjeta de regalo BeautyCita\nCodigo: $code\nValor: $amount';
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copiado al portapapeles')),
          );
        },
      ),
    );
  }
}

// ── Create Dialog ─────────────────────────────────────────────────────────────

class _CreateGiftCardDialog extends ConsumerStatefulWidget {
  const _CreateGiftCardDialog({required this.bizId, required this.onCreated});
  final String bizId;
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateGiftCardDialog> createState() =>
      _CreateGiftCardDialogState();
}

class _CreateGiftCardDialogState extends ConsumerState<_CreateGiftCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _buyerCtrl = TextEditingController();
  final _recipientCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  DateTime? _expiryDate;
  String _generatedCode = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _generatedCode = _generateCode();
    // Live preview updates
    _amountCtrl.addListener(_onFieldChange);
    _recipientCtrl.addListener(_onFieldChange);
    _messageCtrl.addListener(_onFieldChange);
  }

  void _onFieldChange() => setState(() {});

  @override
  void dispose() {
    _amountCtrl.dispose();
    _buyerCtrl.dispose();
    _recipientCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final amount = double.parse(_amountCtrl.text.trim());
      await BCSupabase.client.from('gift_cards').insert({
        'business_id': widget.bizId,
        'code': _generatedCode,
        'amount': amount,
        'remaining_balance': amount,
        'buyer_name': _buyerCtrl.text.trim(),
        'recipient_name': _recipientCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'expiry_date': _expiryDate?.toIso8601String(),
        'status': 'active',
      });
      widget.onCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  Text(
                    'Nueva Tarjeta de Regalo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: kWebTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_outlined,
                        size: 20, color: kWebTextHint),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Live preview card
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kWebPrimary.withValues(alpha: 0.08),
                      kWebSecondary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kWebPrimary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    // Card visual
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kWebPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.card_giftcard_outlined,
                          color: kWebPrimary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _generatedCode,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontFamily: 'monospace',
                              color: kWebPrimary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _recipientCtrl.text.isNotEmpty
                                ? 'Para: ${_recipientCtrl.text}'
                                : 'Tarjeta de regalo',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: kWebTextSecondary),
                          ),
                          if (_messageCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '"${_messageCtrl.text}"',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: kWebTextHint,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _amountCtrl.text.isNotEmpty
                              ? '\$${_amountCtrl.text}'
                              : '\$0',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: kWebPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'MXN',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: kWebTextHint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Code actions (regenerate + copy)
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _generatedCode = _generateCode()),
                    icon: const Icon(Icons.refresh_outlined, size: 16),
                    label: const Text('Regenerar codigo'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _generatedCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Codigo copiado')),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Copiar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Amount
              _Label(theme, 'Monto (\$)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _dec(theme, 'Ej: 500.00'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: kWebTextPrimary),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  if (double.tryParse(v.trim()) == null) {
                    return 'Numero invalido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Buyer + recipient row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(theme, 'Comprador'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _buyerCtrl,
                          decoration: _dec(theme, 'Nombre'),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: kWebTextPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(theme, 'Destinatario'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _recipientCtrl,
                          decoration: _dec(theme, 'Nombre'),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: kWebTextPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Message
              _Label(theme, 'Mensaje (opcional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 2,
                decoration:
                    _dec(theme, 'Feliz cumpleanos! Con carino...'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: kWebTextPrimary),
              ),
              const SizedBox(height: 12),

              // Expiry
              _Label(theme, 'Fecha de vencimiento (opcional)'),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickExpiry,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: kWebBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kWebCardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: kWebTextHint),
                      const SizedBox(width: 8),
                      Text(
                        _expiryDate == null
                            ? 'Sin vencimiento'
                            : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _expiryDate == null
                              ? kWebTextHint
                              : kWebTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _saving ? null : _create,
                    style: FilledButton.styleFrom(
                      backgroundColor: kWebPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Crear Tarjeta'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _Label(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: kWebTextSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _dec(ThemeData theme, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          theme.textTheme.bodyMedium?.copyWith(color: kWebTextHint),
      filled: true,
      fillColor: kWebBackground,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kWebCardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kWebCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kWebPrimary, width: 1.5),
      ),
    );
  }
}

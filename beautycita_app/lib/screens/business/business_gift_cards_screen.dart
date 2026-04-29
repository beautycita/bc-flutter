import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:beautycita_core/supabase.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/empty_state.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final giftCardsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bizId) async {
  final data = await SupabaseClientService.client
      .from(BCTables.giftCards)
      .select()
      .eq('business_id', bizId)
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class BusinessGiftCardsScreen extends ConsumerStatefulWidget {
  const BusinessGiftCardsScreen({super.key});

  @override
  ConsumerState<BusinessGiftCardsScreen> createState() =>
      _BusinessGiftCardsScreenState();
}

class _BusinessGiftCardsScreenState
    extends ConsumerState<BusinessGiftCardsScreen> {
  String _search = '';
  String _statusFilter = 'all'; // all | active | redeemed | expired
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> cards) {
    final now = DateTime.now();
    var result = List<Map<String, dynamic>>.from(cards);

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((c) {
        final code = (c['code'] as String? ?? '').toLowerCase();
        final buyer = (c['buyer_name'] as String? ?? '').toLowerCase();
        final recip = (c['recipient_name'] as String? ?? '').toLowerCase();
        return code.contains(q) || buyer.contains(q) || recip.contains(q);
      }).toList();
    }

    if (_statusFilter != 'all') {
      result = result.where((c) {
        final isActive = c['is_active'] as bool? ?? false;
        final redeemedAt = c['redeemed_at'] as String?;
        final expiresAt = c['expires_at'] as String?;
        final isExpired = expiresAt != null &&
            DateTime.tryParse(expiresAt)?.isBefore(now) == true;
        final isRedeemed = redeemedAt != null;

        switch (_statusFilter) {
          case 'active':
            return isActive && !isRedeemed && !isExpired;
          case 'redeemed':
            return isRedeemed;
          case 'expired':
            return isExpired && !isRedeemed;
          default:
            return true;
        }
      }).toList();
    }

    return result;
  }

  void _exportCsv(List<Map<String, dynamic>> cards) {
    CsvExporter.exportMaps(
      context: context,
      filename: 'tarjetas_regalo',
      headers: [
        'Codigo', 'Monto', 'Restante', 'Comprador', 'Destinatario',
        'Activa', 'Canjeada', 'Vence', 'Creada'
      ],
      keys: [
        'code', 'amount', 'remaining_amount', 'buyer_name', 'recipient_name',
        'is_active', 'redeemed_at', 'expires_at', 'created_at'
      ],
      items: cards,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const EmptyState(icon: Icons.storefront_outlined, message: 'Sin negocio');
        final bizId = biz['id'] as String;
        final cardsAsync = ref.watch(giftCardsProvider(bizId));

        return cardsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: GoogleFonts.nunito(color: colors.error))),
          data: (allCards) {
            final filtered = _filter(allCards);

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(giftCardsProvider(bizId)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: AdminToolbar(
                      showSearch: true,
                      searchHint: 'Buscar codigo, comprador...',
                      searchController: _searchCtrl,
                      onSearchChanged: (q) => setState(() => _search = q),
                      showExport: true,
                      onExport: () => _exportCsv(filtered),
                      totalCount: allCards.length,
                      filteredCount: filtered.length,
                    ),
                  ),

                  // Status filter chips
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _StatusChip(
                          label: 'Todas',
                          selected: _statusFilter == 'all',
                          onTap: () => setState(() => _statusFilter = 'all'),
                        ),
                        _StatusChip(
                          label: 'Activas',
                          selected: _statusFilter == 'active',
                          color: const Color(0xFF059669),
                          onTap: () =>
                              setState(() => _statusFilter = 'active'),
                        ),
                        _StatusChip(
                          label: 'Canjeadas',
                          selected: _statusFilter == 'redeemed',
                          color: colors.primary,
                          onTap: () =>
                              setState(() => _statusFilter = 'redeemed'),
                        ),
                        _StatusChip(
                          label: 'Vencidas',
                          selected: _statusFilter == 'expired',
                          color: Colors.orange,
                          onTap: () =>
                              setState(() => _statusFilter = 'expired'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Create button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: () => _showCreateSheet(context, bizId),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('Nueva tarjeta de regalo',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusMD)),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.card_giftcard_outlined,
                            message: allCards.isEmpty
                                ? 'Todavia no has creado tarjetas de regalo'
                                : 'Sin resultados',
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) => _GiftCardTile(
                              card: filtered[i],
                              bizId: bizId,
                              onUpdated: () =>
                                  ref.invalidate(giftCardsProvider(bizId)),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateSheet(BuildContext context, String bizId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CreateGiftCardSheet(
        bizId: bizId,
        onCreated: () => ref.invalidate(giftCardsProvider(bizId)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status filter chip
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeColor = color ?? colors.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Chip(
          label: Text(label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.7),
              )),
          backgroundColor: selected ? activeColor : colors.surface,
          side: BorderSide(
              color: selected
                  ? activeColor
                  : colors.outline.withValues(alpha: 0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gift card tile
// ---------------------------------------------------------------------------

class _GiftCardTile extends StatelessWidget {
  final Map<String, dynamic> card;
  final String bizId;
  final VoidCallback onUpdated;

  const _GiftCardTile(
      {required this.card, required this.bizId, required this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final code = card['code'] as String? ?? '';
    final amount = (card['amount'] as num?)?.toDouble() ?? 0;
    final remaining = (card['remaining_amount'] as num?)?.toDouble() ?? 0;
    final isActive = card['is_active'] as bool? ?? false;
    final redeemedAt = card['redeemed_at'] as String?;
    final expiresAt = card['expires_at'] as String?;
    final buyerName = card['buyer_name'] as String?;
    final recipientName = card['recipient_name'] as String?;

    final isExpired = expiresAt != null &&
        DateTime.tryParse(expiresAt)?.isBefore(now) == true;
    final isRedeemed = redeemedAt != null;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isRedeemed) {
      statusColor = colors.primary;
      statusLabel = 'Canjeada';
      statusIcon = Icons.check_circle_rounded;
    } else if (isExpired) {
      statusColor = Colors.orange;
      statusLabel = 'Vencida';
      statusIcon = Icons.timer_off_rounded;
    } else if (isActive) {
      statusColor = const Color(0xFF059669);
      statusLabel = 'Activa';
      statusIcon = Icons.check_circle_outline_rounded;
    } else {
      statusColor = Colors.grey;
      statusLabel = 'Inactiva';
      statusIcon = Icons.cancel_outlined;
    }

    final fmt = NumberFormat('#,##0.00', 'es_MX');

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) =>
            _GiftCardDetailSheet(card: card, onUpdated: onUpdated),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            // Card icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(Icons.card_giftcard_rounded, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(code,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 11, color: statusColor),
                            const SizedBox(width: 3),
                            Text(statusLabel,
                                style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('\$${fmt.format(amount)} MXN',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF212121))),
                      if (remaining < amount && remaining > 0) ...[
                        const SizedBox(width: 6),
                        Text('(restante: \$${fmt.format(remaining)})',
                            style: GoogleFonts.nunito(
                                fontSize: 11,
                                color:
                                    colors.onSurface.withValues(alpha: 0.5))),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (buyerName != null) 'De: $buyerName',
                      if (recipientName != null) 'Para: $recipientName',
                    ].join('  '),
                    style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.5)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Quick share button
            IconButton(
              icon: Icon(Icons.share_rounded,
                  size: 18, color: colors.primary.withValues(alpha: 0.7)),
              onPressed: () => _shareCard(card),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Compartir',
            ),
            Icon(Icons.chevron_right,
                size: 18, color: colors.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  void _shareCard(Map<String, dynamic> card) {
    final code = card['code'] as String? ?? '';
    final amount = (card['amount'] as num?)?.toDouble() ?? 0;
    final fmt = NumberFormat('#,##0.00', 'es_MX');
    final msg = 'Tienes una tarjeta de regalo por \$${fmt.format(amount)} MXN.\n'
        'Codigo: $code\n'
        'Canjéala al reservar tu cita en BeautyCita.';
    SharePlus.instance.share(ShareParams(text: msg));
  }
}

// ---------------------------------------------------------------------------
// Gift card detail sheet
// ---------------------------------------------------------------------------

class _GiftCardDetailSheet extends StatelessWidget {
  final Map<String, dynamic> card;
  final VoidCallback onUpdated;

  const _GiftCardDetailSheet(
      {required this.card, required this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00', 'es_MX');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    final code = card['code'] as String? ?? '';
    final amount = (card['amount'] as num?)?.toDouble() ?? 0;
    final remaining = (card['remaining_amount'] as num?)?.toDouble() ?? 0;
    final buyerName = card['buyer_name'] as String?;
    final recipientName = card['recipient_name'] as String?;
    final message = card['message'] as String?;
    final isActive = card['is_active'] as bool? ?? false;
    final redeemedAt = card['redeemed_at'] as String?;
    final expiresAt = card['expires_at'] as String?;
    final createdAt = card['created_at'] as String?;

    final redeemedDt =
        redeemedAt != null ? DateTime.tryParse(redeemedAt) : null;
    final expiresDt =
        expiresAt != null ? DateTime.tryParse(expiresAt) : null;
    final createdDt =
        createdAt != null ? DateTime.tryParse(createdAt) : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          // Code header with copy button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tarjeta de Regalo',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.5))),
                    Text(code,
                        style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ToastService.showSuccess('Codigo copiado');
                },
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copiar codigo',
              ),
              IconButton(
                onPressed: () {
                  final msg =
                      'Tienes una tarjeta de regalo por \$${fmt.format(amount)} MXN.\n'
                      'Codigo: $code\n'
                      'Canjéala al reservar tu cita en BeautyCita.';
                  SharePlus.instance.share(ShareParams(text: msg));
                },
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Compartir',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount
          Row(
            children: [
              _DetailChip(
                  label: 'Valor',
                  value: '\$${fmt.format(amount)}',
                  color: const Color(0xFF059669)),
              const SizedBox(width: 8),
              _DetailChip(
                  label: 'Restante',
                  value: '\$${fmt.format(remaining)}',
                  color: remaining > 0
                      ? const Color(0xFF059669)
                      : Colors.grey),
            ],
          ),
          const SizedBox(height: 16),

          if (buyerName != null) _giftCardRow('Comprador', buyerName),
          if (recipientName != null) _giftCardRow('Destinatario', recipientName),
          if (message != null && message.isNotEmpty)
            _giftCardRow('Mensaje', message),
          _giftCardRow('Estado', isActive ? 'Activa' : 'Inactiva'),
          if (createdDt != null)
            _giftCardRow('Creada', dateFmt.format(createdDt.toLocal())),
          if (expiresDt != null)
            _giftCardRow('Vence', dateFmt.format(expiresDt.toLocal())),
          if (redeemedDt != null)
            _giftCardRow('Canjeada', dateFmt.format(redeemedDt.toLocal())),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 11, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

Widget _giftCardRow(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600]))),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.nunito(fontSize: 13))),
        ],
      ),
    );

// ---------------------------------------------------------------------------
// Create gift card sheet
// ---------------------------------------------------------------------------

class _CreateGiftCardSheet extends ConsumerStatefulWidget {
  final String bizId;
  final VoidCallback onCreated;

  const _CreateGiftCardSheet({required this.bizId, required this.onCreated});

  @override
  ConsumerState<_CreateGiftCardSheet> createState() =>
      _CreateGiftCardSheetState();
}

class _CreateGiftCardSheetState extends ConsumerState<_CreateGiftCardSheet> {
  final _amountCtrl = TextEditingController();
  final _buyerCtrl = TextEditingController();
  final _recipientCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  DateTime? _expiresAt;
  bool _saving = false;
  String _issueMode = 'salon'; // 'salon' (physical/cash) or 'online' (Stripe)
  bool _isVirtual = true; // virtual (email) or physical (copy code)

  @override
  void dispose() {
    _amountCtrl.dispose();
    _buyerCtrl.dispose();
    _recipientCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _save() async {
    final amountStr = _amountCtrl.text.trim();
    if (amountStr.isEmpty) {
      ToastService.showError('Ingresa el monto');
      return;
    }
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ToastService.showError('Monto invalido');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_issueMode == 'salon') {
        // Salon-issued: cash already collected, create card directly
        // BC 3% charged to salon via commission record
        final code = _generateCode();
        // Atomic: gift_cards + commission_records in one transaction
        await SupabaseClientService.client.rpc(
          'record_gift_card_commission',
          params: {
            'p_business_id': widget.bizId,
            'p_code': code,
            'p_amount': amount,
            'p_buyer_name': _buyerCtrl.text.trim().isEmpty
                ? null
                : _buyerCtrl.text.trim(),
            'p_recipient_name': _recipientCtrl.text.trim().isEmpty
                ? null
                : _recipientCtrl.text.trim(),
            'p_message': _messageCtrl.text.trim().isEmpty
                ? null
                : _messageCtrl.text.trim(),
            'p_expires_at': _expiresAt?.toUtc().toIso8601String(),
          },
        );

        // If virtual, send email with code
        if (_isVirtual && _emailCtrl.text.trim().isNotEmpty) {
          final msgText = _messageCtrl.text.trim();
          final messageBlock = msgText.isNotEmpty
              ? '<p style="margin:0 0 20px 0;font-size:14px;color:#374151;'
                  'font-style:italic;text-align:center;">'
                  '"$msgText"</p>'
              : '';
          try {
            await SupabaseClientService.client.functions.invoke('send-email', body: {
              'template': 'gift_card',
              'to': _emailCtrl.text.trim(),
              'subject': 'Tu tarjeta de regalo BeautyCita — \$${amount.toStringAsFixed(0)} MXN',
              'variables': {
                'AMOUNT': amount.toStringAsFixed(0),
                'CODE': code,
                'MESSAGE': messageBlock,
              },
            });
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Tarjeta creada, pero no pudimos enviar el email. '
                    'Comparte el codigo manualmente: $code',
                  ),
                  duration: const Duration(seconds: 8),
                ),
              );
            }
          }
        }

        widget.onCreated();
        if (mounted) {
          Navigator.pop(context);
          // Show code prominently so salon can copy it for physical card
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Tarjeta creada', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('\$${amount.toStringAsFixed(0)} MXN', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(code, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 4, color: const Color(0xFF7C3AED))),
                  ),
                  const SizedBox(height: 8),
                  Text(_isVirtual ? 'Codigo enviado por email' : 'Copia este codigo a la tarjeta fisica',
                      style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ToastService.showSuccess('Codigo copiado');
                  },
                  child: const Text('Copiar codigo'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Online mode: Create payment via Stripe
      final response = await SupabaseClientService.client.functions.invoke(
        'create-gift-card-payment',
        body: {
          'business_id': widget.bizId,
          'amount': amount,
          'buyer_name': _buyerCtrl.text.trim().isEmpty ? null : _buyerCtrl.text.trim(),
          'recipient_name': _recipientCtrl.text.trim().isEmpty ? null : _recipientCtrl.text.trim(),
          'message': _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
          'expires_at': _expiresAt?.toUtc().toIso8601String(),
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('error')) {
        throw Exception(data['error'] as String);
      }

      final clientSecret = data['client_secret'] as String? ?? '';
      final customerId = data['customer_id'] as String? ?? '';
      final ephemeralKey = data['ephemeral_key'] as String? ?? '';
      final giftCardCode = data['gift_card_code'] as String? ?? '';

      if (clientSecret.isEmpty) {
        throw Exception('Error al procesar el pago');
      }

      // Present Stripe PaymentSheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          merchantDisplayName: 'BeautyCita — Tarjeta de Regalo',
          returnURL: 'beautycita://stripe-redirect',
          style: ThemeMode.light,
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      // Payment succeeded — gift card will be created by webhook
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ToastService.showSuccess('Tarjeta de regalo creada: $giftCardCode (\$${amount.toStringAsFixed(0)} MXN)');
      }
    } on StripeException {
      // User cancelled payment sheet
      if (mounted) ToastService.showInfo('Pago cancelado');
    } catch (e) {
      final errMsg = e.toString().replaceAll('Exception: ', '');
      if (errMsg.toLowerCase().contains('pagos en linea') || errMsg.toLowerCase().contains('destination')) {
        ToastService.showError('Este salon no tiene pagos en linea configurados');
      } else {
        ToastService.showError('Error: $errMsg');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Nueva Tarjeta de Regalo',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const SizedBox(height: 16),

          // Issue mode selector
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'salon', icon: Icon(Icons.store, size: 16), label: Text('Desde salon')),
              ButtonSegment(value: 'online', icon: Icon(Icons.credit_card, size: 16), label: Text('Venta en linea')),
            ],
            selected: {_issueMode},
            onSelectionChanged: (v) => setState(() => _issueMode = v.first),
            style: SegmentedButton.styleFrom(textStyle: GoogleFonts.poppins(fontSize: 12)),
          ),
          const SizedBox(height: 8),
          Text(
            _issueMode == 'salon'
                ? 'El cliente paga en efectivo. BC cobra 3% al salon.'
                : 'El cliente paga en linea. BC cobra 3% al comprador.',
            style: GoogleFonts.nunito(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 12),

          // Physical vs Virtual toggle
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email_outlined, size: 14, color: _isVirtual ? colors.onPrimary : colors.onSurface),
                      const SizedBox(width: 4),
                      Text('Virtual (email)'),
                    ],
                  ),
                  selected: _isVirtual,
                  selectedColor: colors.primary,
                  onSelected: (_) => setState(() => _isVirtual = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.card_giftcard, size: 14, color: !_isVirtual ? colors.onPrimary : colors.onSurface),
                      const SizedBox(width: 4),
                      Text('Fisica (codigo)'),
                    ],
                  ),
                  selected: !_isVirtual,
                  selectedColor: colors.primary,
                  onSelected: (_) => setState(() => _isVirtual = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _Field(
            label: 'Monto (MXN) *',
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            hint: '500.00',
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Nombre del comprador',
            controller: _buyerCtrl,
            hint: 'Ana Garcia',
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Nombre del destinatario',
            controller: _recipientCtrl,
            hint: 'Maria Lopez',
          ),
          if (_isVirtual) ...[
            const SizedBox(height: 12),
            _Field(
              label: 'Email del destinatario',
              controller: _emailCtrl,
              hint: 'maria@ejemplo.com',
              keyboardType: TextInputType.emailAddress,
            ),
          ],
          const SizedBox(height: 12),
          _Field(
            label: 'Mensaje (opcional)',
            controller: _messageCtrl,
            hint: 'Feliz cumpleanos...',
            maxLines: 2,
          ),
          const SizedBox(height: 12),

          // Expiry date
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now(),
                lastDate:
                    DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (picked != null) setState(() => _expiresAt = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                    color: colors.outline.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 18,
                      color: colors.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _expiresAt != null
                          ? 'Vence: ${DateFormat('dd/MM/yyyy').format(_expiresAt!)}'
                          : 'Fecha de vencimiento (opcional)',
                      style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: _expiresAt != null
                              ? colors.onSurface
                              : colors.onSurface.withValues(alpha: 0.4)),
                    ),
                  ),
                  if (_expiresAt != null)
                    GestureDetector(
                      onTap: () => setState(() => _expiresAt = null),
                      child: Icon(Icons.close,
                          size: 18,
                          color:
                              colors.onSurface.withValues(alpha: 0.4)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: colors.onPrimary))
                  : Text('Crear tarjeta',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final int maxLines;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.nunito(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.4)),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

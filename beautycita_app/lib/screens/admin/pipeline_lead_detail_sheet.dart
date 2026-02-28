import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void showLeadDetailSheet(
  BuildContext context,
  Map<String, dynamic> lead, {
  VoidCallback? onChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LeadDetailSheet(lead: lead, onChanged: onChanged),
  );
}

// ---------------------------------------------------------------------------
// Status helpers (mirrors pipeline screen)
// ---------------------------------------------------------------------------

const _allStatuses = [
  'discovered',
  'selected',
  'outreach_sent',
  'registered',
  'declined',
  'unreachable',
];

const _statusLabels = {
  'discovered': 'Encontrado',
  'selected': 'Seleccionado',
  'outreach_sent': 'Contactado',
  'registered': 'Registrado',
  'declined': 'Rechazado',
  'unreachable': 'Inalcanzable',
};

Color _statusColor(String? status) {
  switch (status) {
    case 'discovered':
      return Colors.grey;
    case 'selected':
      return Colors.blue;
    case 'outreach_sent':
      return Colors.orange;
    case 'registered':
      return Colors.green;
    case 'declined':
      return Colors.red;
    case 'unreachable':
      return Colors.grey.shade400;
    default:
      return Colors.grey;
  }
}

// ---------------------------------------------------------------------------
// Channel helpers
// ---------------------------------------------------------------------------

const _channelOptions = [
  'whatsapp',
  'sms',
  'email',
  'phone_call',
  'in_person',
  'radio_ad',
  'social_media_ad',
  'flyer',
  'referral',
  'other',
];

const _channelLabels = {
  'whatsapp': 'WhatsApp',
  'sms': 'SMS',
  'email': 'Email',
  'phone_call': 'Llamada',
  'in_person': 'En persona',
  'radio_ad': 'Radio',
  'social_media_ad': 'Red social',
  'flyer': 'Volante',
  'referral': 'Referido',
  'other': 'Otro',
};

IconData _channelIcon(String? channel) {
  switch (channel) {
    case 'whatsapp':
      return Icons.chat;
    case 'sms':
      return Icons.sms;
    case 'email':
      return Icons.email;
    case 'phone_call':
      return Icons.phone;
    case 'in_person':
      return Icons.person_pin;
    case 'radio_ad':
      return Icons.radio;
    case 'social_media_ad':
      return Icons.campaign;
    case 'flyer':
      return Icons.description;
    case 'referral':
      return Icons.people;
    default:
      return Icons.more_horiz;
  }
}

Color _channelColor(String? channel) {
  switch (channel) {
    case 'whatsapp':
      return const Color(0xFF25D366);
    case 'sms':
      return Colors.blue;
    case 'email':
      return Colors.orange;
    case 'phone_call':
      return Colors.teal;
    case 'in_person':
      return Colors.purple;
    case 'radio_ad':
      return Colors.brown;
    case 'social_media_ad':
      return Colors.pink;
    case 'flyer':
      return Colors.indigo;
    case 'referral':
      return Colors.cyan;
    default:
      return Colors.grey;
  }
}

Color _sourceColor(String? source) {
  switch (source) {
    case 'google_maps':
      return Colors.red.shade400;
    case 'facebook':
      return const Color(0xFF1877F2);
    case 'bing':
      return Colors.teal.shade400;
    case 'manual':
      return Colors.purple.shade400;
    default:
      return Colors.grey;
  }
}

// ---------------------------------------------------------------------------
// Date formatting
// ---------------------------------------------------------------------------

String _formatDateTime(String? iso) {
  if (iso == null) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $hour:$min';
  } catch (_) {
    return iso;
  }
}

// ---------------------------------------------------------------------------
// Sheet widget
// ---------------------------------------------------------------------------

class _LeadDetailSheet extends StatefulWidget {
  final Map<String, dynamic> lead;
  final VoidCallback? onChanged;

  const _LeadDetailSheet({required this.lead, this.onChanged});

  @override
  State<_LeadDetailSheet> createState() => _LeadDetailSheetState();
}

class _LeadDetailSheetState extends State<_LeadDetailSheet> {
  late Map<String, dynamic> _lead;

  // Inline name editing
  bool _editingName = false;
  late TextEditingController _nameCtrl;
  bool _savingName = false;

  // Current status (local copy so UI updates instantly)
  late String _status;
  bool _savingStatus = false;

  @override
  void initState() {
    super.initState();
    _lead = Map<String, dynamic>.from(widget.lead);
    _status = _lead['status'] as String? ?? 'discovered';
    _nameCtrl = TextEditingController(
      text: _lead['business_name']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ---- name save ----
  Future<void> _saveName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) return;
    setState(() => _savingName = true);
    try {
      await SupabaseClientService.client
          .from('discovered_salons')
          .update({'business_name': newName})
          .eq('id', _lead['id'] as String);
      setState(() {
        _lead['business_name'] = newName;
        _editingName = false;
      });
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  // ---- status change ----
  Future<void> _changeStatus(String newStatus, WidgetRef ref) async {
    if (newStatus == _status) return;
    setState(() {
      _status = newStatus;
      _savingStatus = true;
    });
    try {
      await SupabaseClientService.client
          .from('discovered_salons')
          .update({'status': newStatus})
          .eq('id', _lead['id'] as String);
      setState(() => _lead['status'] = newStatus);
      widget.onChanged?.call();
    } catch (e) {
      // revert on failure
      setState(() => _status = _lead['status'] as String? ?? 'discovered');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Consumer(
        builder: (ctx, ref, _) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => _buildSheet(ctx, ref, scrollCtrl),
        ),
      ),
    );
  }

  Widget _buildSheet(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollCtrl,
  ) {
    final logAsync = ref.watch(pipelineOutreachLogProvider(_lead['id'] as String));

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Scrollable content
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _buildHeader(context, ref),
                const SizedBox(height: 12),
                _buildInfoCard(context),
                const SizedBox(height: 12),
                _buildOutreachTimeline(context, ref, logAsync),
                const SizedBox(height: 12),
                _buildRegisterContactButton(context, ref),
                const SizedBox(height: 16),
                _buildQuickActions(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1: Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final phone = _lead['phone']?.toString();
    final whatsapp = _lead['whatsapp']?.toString();
    final waVerified = _lead['whatsapp_verified'] as bool? ?? false;
    final source = _lead['source']?.toString();
    final city = _lead['location_city']?.toString() ?? '';
    final state = _lead['location_state']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Salon name row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _editingName
                  ? TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (_) => _saveName(),
                    )
                  : Text(
                      _lead['business_name']?.toString() ?? 'Sin nombre',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            if (_editingName) ...[
              if (_savingName)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: _saveName,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => setState(() {
                    _editingName = false;
                    _nameCtrl.text =
                        _lead['business_name']?.toString() ?? '';
                  }),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ] else
              IconButton(
                icon: Icon(Icons.edit, color: Colors.grey.shade500, size: 18),
                onPressed: () => setState(() => _editingName = true),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),

        // City/State
        if (city.isNotEmpty || state.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            [city, state].where((s) => s.isNotEmpty).join(', '),
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],

        const SizedBox(height: 10),

        // Status chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _allStatuses.map((s) {
              final isSelected = s == _status;
              final color = _statusColor(s);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: _savingStatus ? null : () => _changeStatus(s, ref),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.white,
                      border: Border.all(
                        color: color,
                        width: isSelected ? 0 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabels[s] ?? s,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 10),

        // Source badge + phone/WA row
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Source badge
            if (source != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _sourceColor(source).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _sourceColor(source).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  source.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _sourceColor(source),
                  ),
                ),
              ),

            // Phone
            if (phone != null && phone.isNotEmpty)
              _tappableBadge(
                icon: Icons.phone,
                label: phone,
                color: Colors.teal,
                onTap: () => _launch('tel:$phone'),
              ),

            // WhatsApp
            if (whatsapp != null && whatsapp.isNotEmpty)
              _tappableBadge(
                icon: Icons.chat,
                label: whatsapp,
                color: const Color(0xFF25D366),
                onTap: () => _launch(
                  'https://wa.me/${whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}',
                ),
                trailing: waVerified
                    ? const Icon(
                        Icons.verified,
                        size: 14,
                        color: Color(0xFF25D366),
                      )
                    : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _tappableBadge({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2: Salon Info card
  // ---------------------------------------------------------------------------

  Widget _buildInfoCard(BuildContext context) {
    final address = _lead['address']?.toString() ??
        _lead['full_address']?.toString();
    final rating = (_lead['rating_average'] as num?)?.toDouble();
    final reviewCount = (_lead['rating_count'] as num?)?.toInt();
    final categoriesRaw = _lead['categories'];
    final website = _lead['website']?.toString();
    final instagram = _lead['instagram']?.toString();
    final facebook = _lead['facebook']?.toString();

    // Parse categories — may be a List or comma-separated string
    List<String> categories = [];
    if (categoriesRaw is List) {
      categories = categoriesRaw.map((e) => e.toString()).toList();
    } else if (categoriesRaw is String && categoriesRaw.isNotEmpty) {
      categories = categoriesRaw.split(',').map((e) => e.trim()).toList();
    }

    final rows = <Widget>[];

    if (address != null && address.isNotEmpty) {
      rows.add(
        _infoRow(
          icon: Icons.location_on,
          color: Colors.red.shade400,
          child: GestureDetector(
            onTap: () {
              final q = Uri.encodeComponent(address);
              _launch('https://maps.google.com/?q=$q');
            },
            child: Text(
              address,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.blue.shade700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      );
    }

    if (rating != null) {
      rows.add(
        _infoRow(
          icon: Icons.star,
          color: Colors.amber,
          child: Text(
            reviewCount != null
                ? '${rating.toStringAsFixed(1)}  ($reviewCount resenas)'
                : rating.toStringAsFixed(1),
            style: GoogleFonts.nunito(fontSize: 13),
          ),
        ),
      );
    }

    if (categories.isNotEmpty) {
      rows.add(
        _infoRow(
          icon: Icons.category,
          color: Colors.deepPurple.shade300,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: categories
                .take(6)
                .map(
                  (c) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      c,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      );
    }

    if (website != null && website.isNotEmpty) {
      rows.add(
        _infoRow(
          icon: Icons.language,
          color: Colors.blue,
          child: GestureDetector(
            onTap: () => _launch(
              website.startsWith('http') ? website : 'https://$website',
            ),
            child: Text(
              website,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.blue.shade700,
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    if (instagram != null && instagram.isNotEmpty) {
      rows.add(
        _infoRow(
          icon: Icons.camera_alt,
          color: Colors.pink,
          child: GestureDetector(
            onTap: () {
              final handle = instagram.replaceAll('@', '').trim();
              _launch('https://instagram.com/$handle');
            },
            child: Text(
              instagram,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.pink.shade700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      );
    }

    if (facebook != null && facebook.isNotEmpty) {
      rows.add(
        _infoRow(
          icon: Icons.facebook,
          color: const Color(0xFF1877F2),
          child: GestureDetector(
            onTap: () => _launch(
              facebook.startsWith('http')
                  ? facebook
                  : 'https://facebook.com/$facebook',
            ),
            child: Text(
              facebook,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: const Color(0xFF1877F2),
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return _card(
      header: 'INFORMACION',
      child: Column(
        children: rows
            .expand((w) => [w, const Divider(height: 12, thickness: 0.5)])
            .take(rows.length * 2 - 1)
            .toList(),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 4), child: child)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3: Outreach timeline
  // ---------------------------------------------------------------------------

  Widget _buildOutreachTimeline(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> logAsync,
  ) {
    return _card(
      headerWidget: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'HISTORIAL DE CONTACTO',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
              letterSpacing: 0.8,
            ),
          ),
          logAsync.maybeWhen(
            data: (list) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${list.length}',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      child: logAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Error al cargar historial: $e',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Colors.red.shade400,
            ),
          ),
        ),
        data: (entries) => entries.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Sin historial de contacto',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            : Column(
                children: List.generate(entries.length, (i) {
                  final entry = entries[i];
                  final isLast = i == entries.length - 1;
                  return _timelineEntry(entry, isLast: isLast);
                }),
              ),
      ),
    );
  }

  Widget _timelineEntry(Map<String, dynamic> entry, {required bool isLast}) {
    final channel = entry['channel']?.toString() ?? 'other';
    final channelColor = _channelColor(channel);
    final sentAt = entry['sent_at']?.toString();
    final messageText = entry['message_text']?.toString();
    final notes = entry['notes']?.toString();
    final outcome = entry['outcome']?.toString();
    final testMode = entry['test_mode'] as bool? ?? false;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line + icon
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Circle icon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: channelColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: channelColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    _channelIcon(channel),
                    size: 14,
                    color: channelColor,
                  ),
                ),
                // Vertical line (except last)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Entry content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel + date row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _channelLabels[channel] ?? channel,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: channelColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (testMode)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.shade400),
                          ),
                          child: Text(
                            'TEST',
                            style: GoogleFonts.nunito(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (sentAt != null)
                        Text(
                          _formatDateTime(sentAt),
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  // Message text
                  if (messageText != null && messageText.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      messageText,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Notes
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      notes,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  // Outcome badge
                  if (outcome != null && outcome.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        outcome,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 4: Register contact button
  // ---------------------------------------------------------------------------

  Widget _buildRegisterContactButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showRegisterContactDialog(context, ref),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(
          'Registrar Contacto',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue.shade700,
          side: BorderSide(color: Colors.blue.shade300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Future<void> _showRegisterContactDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    String selectedChannel = 'whatsapp';
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: Text(
              'Registrar Contacto',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel dropdown
                  Text(
                    'Canal',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedChannel,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      items: _channelOptions.map((ch) {
                        return DropdownMenuItem(
                          value: ch,
                          child: Row(
                            children: [
                              Icon(
                                _channelIcon(ch),
                                size: 16,
                                color: _channelColor(ch),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _channelLabels[ch] ?? ch,
                                style: GoogleFonts.nunito(fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedChannel = v);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Notes field
                  Text(
                    'Notas',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    minLines: 2,
                    maxLines: 4,
                    style: GoogleFonts.nunito(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Descripcion del contacto...',
                      hintStyle: GoogleFonts.nunito(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Date picker
                  Text(
                    'Fecha',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogCtx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              selectedDate.hour,
                              selectedDate.minute,
                            ));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(selectedDate.toIso8601String()),
                            style: GoogleFonts.nunito(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    saving ? null : () => Navigator.of(dialogCtx).pop(),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.nunito(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          final salonId = _lead['id'] as String;
                          await SupabaseClientService.client
                              .from('salon_outreach_log')
                              .insert({
                            'discovered_salon_id': salonId,
                            'channel': selectedChannel,
                            'notes': notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                            'sent_at': selectedDate.toIso8601String(),
                          });

                          // Update discovered_salons metadata
                          final currentCount =
                              (_lead['outreach_count'] as num?)?.toInt() ?? 0;
                          await SupabaseClientService.client
                              .from('discovered_salons')
                              .update({
                            'outreach_count': currentCount + 1,
                            'last_outreach_at':
                                selectedDate.toIso8601String(),
                            'outreach_channel': selectedChannel,
                          }).eq('id', salonId);

                          setState(() {
                            _lead['outreach_count'] = currentCount + 1;
                            _lead['last_outreach_at'] =
                                selectedDate.toIso8601String();
                            _lead['outreach_channel'] = selectedChannel;
                          });

                          // Invalidate so timeline refreshes
                          ref.invalidate(pipelineOutreachLogProvider(salonId));

                          widget.onChanged?.call();

                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Guardar',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );

    notesCtrl.dispose();
  }

  // ---------------------------------------------------------------------------
  // Section 5: Quick action buttons
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final phone = _lead['phone']?.toString() ?? '';
    final whatsapp = _lead['whatsapp']?.toString() ?? phone;
    final email = _lead['email']?.toString();
    final phoneForWa =
        whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneForSms = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // WhatsApp
        _quickBtn(
          label: 'WhatsApp',
          icon: Icons.chat,
          color: const Color(0xFF25D366),
          onTap: phoneForWa.isNotEmpty
              ? () => _launch('https://wa.me/$phoneForWa')
              : null,
        ),

        // SMS
        _quickBtn(
          label: 'SMS',
          icon: Icons.sms,
          color: Colors.blue,
          onTap: phoneForSms.isNotEmpty
              ? () => _launch('sms:$phoneForSms')
              : null,
        ),

        // Email
        if (email != null && email.isNotEmpty)
          _quickBtn(
            label: 'Email',
            icon: Icons.email,
            color: Colors.orange,
            onTap: () => _launch('mailto:$email'),
          ),

        // Mark as registered
        _quickBtn(
          label: 'Registrado',
          icon: Icons.check_circle,
          color: Colors.teal,
          onTap: _status == 'registered'
              ? null
              : () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      title: Text(
                        'Marcar como registrado',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      content: Text(
                        'Confirmar que ${_lead['business_name'] ?? 'este salon'} se ha registrado en BeautyCita.',
                        style: GoogleFonts.nunito(fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Confirmar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    await _changeStatus('registered', ref);
                  }
                },
        ),

        // Mark as declined
        _quickBtn(
          label: 'Rechazado',
          icon: Icons.cancel_outlined,
          color: Colors.red,
          outlined: true,
          onTap: _status == 'declined'
              ? null
              : () => _changeStatus('declined', ref),
        ),
      ],
    );
  }

  Widget _quickBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool outlined = false,
  }) {
    final disabled = onTap == null;
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: disabled ? Colors.grey.shade400 : color,
          side: BorderSide(
            color: disabled ? Colors.grey.shade300 : color,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: disabled ? Colors.grey.shade200 : color,
        foregroundColor: disabled ? Colors.grey.shade500 : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared: card builder
  // ---------------------------------------------------------------------------

  Widget _card({
    String? header,
    Widget? headerWidget,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerWidget != null) ...[
            headerWidget,
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 10),
          ] else if (header != null) ...[
            Text(
              header,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // URL launcher helper
  // ---------------------------------------------------------------------------

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir: $url')),
        );
      }
    }
  }
}

// outreach_contact_sheet.dart
// Mobile-native bottom sheet for multi-channel salon outreach.
// Built fresh for mobile UX — NOT adapted from any web screen.

import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';
import '../providers/outreach_contact_provider.dart';
import '../services/toast_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kBrand = Color(0xFFC2185B);
const _kBrandLight = Color(0xFFFCE4EC);
const _kSurface = Color(0xFFF7F7F9);
const _kWaGreen = Color(0xFF25D366);

const _kOutcomes = [
  ('interested', 'Interesado'),
  ('not_interested', 'No interesado'),
  ('callback', 'Llamar después'),
  ('no_answer', 'No contestó'),
  ('wrong_number', 'Número incorrecto'),
  ('voicemail', 'Buzón de voz'),
];

// ─── Channel enum ─────────────────────────────────────────────────────────────

enum ContactChannel {
  whatsapp('whatsapp', 'WhatsApp', Icons.chat),
  waCall('wa_call', 'WA Llamada', Icons.phone),
  email('email', 'Email', Icons.email),
  sms('sms', 'SMS', Icons.sms),
  phoneCall('phone_call', 'Llamada', Icons.phone_in_talk);

  const ContactChannel(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;

  /// Maps to the template channel key used in the DB (whatsapp|email|sms).
  String get templateChannel => switch (this) {
        ContactChannel.whatsapp || ContactChannel.waCall => 'whatsapp',
        ContactChannel.email => 'email',
        ContactChannel.sms || ContactChannel.phoneCall => 'sms',
      };

  Color get color => switch (this) {
        ContactChannel.whatsapp => _kWaGreen,
        ContactChannel.waCall => _kWaGreen,
        ContactChannel.email => Colors.orange,
        ContactChannel.sms => Colors.blue,
        ContactChannel.phoneCall => Colors.teal,
      };

  bool get isCall =>
      this == ContactChannel.waCall || this == ContactChannel.phoneCall;

  bool get isMessage =>
      this == ContactChannel.whatsapp ||
      this == ContactChannel.sms ||
      this == ContactChannel.email;
}

// ─── Entry point ──────────────────────────────────────────────────────────────

/// Show the outreach contact sheet as a draggable modal bottom sheet.
///
/// [salon] must contain at minimum: id, business_name, phone.
Future<void> showOutreachContactSheet(
  BuildContext context,
  Map<String, dynamic> salon,
) {
  return showBurstBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => OutreachContactSheet(salon: salon),
  );
}

// ─── Widget ───────────────────────────────────────────────────────────────────

class OutreachContactSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> salon;

  const OutreachContactSheet({super.key, required this.salon});

  @override
  ConsumerState<OutreachContactSheet> createState() =>
      _OutreachContactSheetState();
}

class _OutreachContactSheetState extends ConsumerState<OutreachContactSheet> {
  // ── State ──────────────────────────────────────────────────────────────────

  late ContactChannel _channel;
  OutreachTemplate? _selectedTemplate;
  bool _sending = false;

  // Message channels
  final _bodyCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();

  // Call channels
  String? _outcome;
  final _durationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // History expand tracking
  final _expandedEntries = <String>{};

  // ── Derived ───────────────────────────────────────────────────────────────

  bool get _waVerified => widget.salon['whatsapp_verified'] == true;
  String get _salonId => widget.salon['id'] as String;

  /// Channels visible for this salon.
  List<ContactChannel> get _availableChannels {
    return ContactChannel.values.where((c) {
      if (c == ContactChannel.waCall) return _waVerified;
      if (c == ContactChannel.sms) return !_waVerified;
      return true;
    }).toList();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Default to WhatsApp if WA-verified, else SMS
    _channel = _waVerified ? ContactChannel.whatsapp : ContactChannel.sms;
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _subjectCtrl.dispose();
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Template substitution ─────────────────────────────────────────────────

  String _substitute(String template) {
    final s = widget.salon;
    return template
        .replaceAll('{salon_name}', s['business_name']?.toString() ?? '')
        .replaceAll('{city}', s['location_city']?.toString() ?? '')
        .replaceAll('{rating}', s['rating_average']?.toString() ?? '')
        .replaceAll('{review_count}', s['rating_count']?.toString() ?? '')
        .replaceAll(
            '{booking_system}', s['booking_system']?.toString() ?? 'ninguno')
        .replaceAll('{interest_count}', s['interest_count']?.toString() ?? '');
  }

  void _applyTemplate(OutreachTemplate t) {
    setState(() {
      _selectedTemplate = t;
      _bodyCtrl.text = _substitute(t.bodyTemplate);
      if (t.subject != null) {
        _subjectCtrl.text = _substitute(t.subject!);
      }
    });
  }

  // ── Channel switch ────────────────────────────────────────────────────────

  void _switchChannel(ContactChannel c) {
    if (c == _channel) return;
    setState(() {
      _channel = c;
      _selectedTemplate = null;
      _bodyCtrl.clear();
      _subjectCtrl.clear();
      _outcome = null;
      _durationCtrl.clear();
      _notesCtrl.clear();
    });
  }

  // ── Send / log ────────────────────────────────────────────────────────────

  Future<void> _onSend() async {
    if (_sending) return;

    // Validate
    if (_channel.isCall) {
      if (_outcome == null) {
        ToastService.showWarning('Selecciona un resultado de la llamada');
        return;
      }
    } else {
      if (_bodyCtrl.text.trim().isEmpty) {
        ToastService.showWarning('El mensaje no puede estar vacío');
        return;
      }
      if (_channel == ContactChannel.email &&
          _subjectCtrl.text.trim().isEmpty) {
        ToastService.showWarning('El asunto no puede estar vacío');
        return;
      }
    }

    setState(() => _sending = true);
    HapticFeedback.mediumImpact();

    try {
      Map<String, dynamic> result;

      switch (_channel) {
        case ContactChannel.whatsapp:
          result = await OutreachContactService.sendWa(
            salonId: _salonId,
            message: _bodyCtrl.text.trim(),
            templateId: _selectedTemplate?.id,
          );

        case ContactChannel.sms:
          result = await OutreachContactService.sendSms(
            salonId: _salonId,
            message: _bodyCtrl.text.trim(),
            templateId: _selectedTemplate?.id,
          );

        case ContactChannel.email:
          result = await OutreachContactService.sendEmail(
            salonId: _salonId,
            subject: _subjectCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
            templateId: _selectedTemplate?.id,
          );

        case ContactChannel.waCall:
        case ContactChannel.phoneCall:
          final dur = int.tryParse(_durationCtrl.text.trim());
          result = await OutreachContactService.logCall(
            salonId: _salonId,
            channel: _channel == ContactChannel.waCall ? 'wa_call' : 'phone',
            outcome: _outcome!,
            durationSeconds: dur,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );
      }

      if (result['success'] == true) {
        ToastService.showSuccess(_channel.isCall
            ? 'Llamada registrada'
            : 'Mensaje enviado');
        // Refresh history
        ref.invalidate(salonOutreachHistoryProvider(_salonId));
        // Clear compose area
        setState(() {
          _bodyCtrl.clear();
          _subjectCtrl.clear();
          _outcome = null;
          _durationCtrl.clear();
          _notesCtrl.clear();
          _selectedTemplate = null;
        });
      } else {
        final msg = result['error']?.toString() ?? 'Error desconocido';
        ToastService.showError(msg);
      }
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: const [0.5, 0.78, 0.95],
      builder: (ctx, scrollCtrl) => _SheetBody(
        scrollCtrl: scrollCtrl,
        salon: widget.salon,
        channel: _channel,
        availableChannels: _availableChannels,
        selectedTemplate: _selectedTemplate,
        bodyCtrl: _bodyCtrl,
        subjectCtrl: _subjectCtrl,
        outcome: _outcome,
        durationCtrl: _durationCtrl,
        notesCtrl: _notesCtrl,
        sending: _sending,
        expandedEntries: _expandedEntries,
        salonId: _salonId,
        onChannelSwitch: _switchChannel,
        onTemplateSelected: _applyTemplate,
        onOutcomeChanged: (v) => setState(() => _outcome = v),
        onSend: _onSend,
        onToggleExpand: (id) => setState(() {
          if (_expandedEntries.contains(id)) {
            _expandedEntries.remove(id);
          } else {
            _expandedEntries.add(id);
          }
        }),
        ref: ref,
      ),
    );
  }
}

// ─── Sheet body ────────────────────────────────────────────────────────────────
// Extracted so the DraggableScrollableSheet builder stays clean.

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.scrollCtrl,
    required this.salon,
    required this.channel,
    required this.availableChannels,
    required this.selectedTemplate,
    required this.bodyCtrl,
    required this.subjectCtrl,
    required this.outcome,
    required this.durationCtrl,
    required this.notesCtrl,
    required this.sending,
    required this.expandedEntries,
    required this.salonId,
    required this.onChannelSwitch,
    required this.onTemplateSelected,
    required this.onOutcomeChanged,
    required this.onSend,
    required this.onToggleExpand,
    required this.ref,
  });

  final ScrollController scrollCtrl;
  final Map<String, dynamic> salon;
  final ContactChannel channel;
  final List<ContactChannel> availableChannels;
  final OutreachTemplate? selectedTemplate;
  final TextEditingController bodyCtrl;
  final TextEditingController subjectCtrl;
  final String? outcome;
  final TextEditingController durationCtrl;
  final TextEditingController notesCtrl;
  final bool sending;
  final Set<String> expandedEntries;
  final String salonId;
  final ValueChanged<ContactChannel> onChannelSwitch;
  final ValueChanged<OutreachTemplate> onTemplateSelected;
  final ValueChanged<String?> onOutcomeChanged;
  final VoidCallback onSend;
  final ValueChanged<String> onToggleExpand;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXL),
        ),
      ),
      child: Column(
        children: [
          // ── Drag handle ──
          _DragHandle(),

          // ── Scrollable content ──
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMD,
                vertical: AppConstants.paddingSM,
              ),
              children: [
                // Salon header
                _SalonHeader(salon: salon),
                const SizedBox(height: AppConstants.paddingMD),

                // Channel selector
                _ChannelChips(
                  channels: availableChannels,
                  selected: channel,
                  onSelect: onChannelSwitch,
                ),
                const SizedBox(height: AppConstants.paddingMD),

                // Template picker
                _TemplatePicker(
                  channel: channel.templateChannel,
                  selectedTemplate: selectedTemplate,
                  onSelected: onTemplateSelected,
                  ref: ref,
                ),
                const SizedBox(height: AppConstants.paddingMD),

                // Compose area — switches by channel type
                if (channel.isCall)
                  _CallComposeArea(
                    channel: channel,
                    outcome: outcome,
                    durationCtrl: durationCtrl,
                    notesCtrl: notesCtrl,
                    onOutcomeChanged: onOutcomeChanged,
                  )
                else
                  _MessageComposeArea(
                    channel: channel,
                    bodyCtrl: bodyCtrl,
                    subjectCtrl: subjectCtrl,
                  ),

                const SizedBox(height: AppConstants.paddingMD),

                // Send / Log button
                _SendButton(
                  channel: channel,
                  sending: sending,
                  onTap: onSend,
                ),

                const SizedBox(height: AppConstants.paddingLG),

                // History divider
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingSM),
                    child: Text(
                      'Historial de contacto',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ]),

                const SizedBox(height: AppConstants.paddingSM),

                // History timeline
                _ContactHistoryTimeline(
                  salonId: salonId,
                  expandedEntries: expandedEntries,
                  onToggleExpand: onToggleExpand,
                  ref: ref,
                ),

                const SizedBox(height: AppConstants.paddingXXL),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Drag handle ──────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.paddingSM),
      child: Center(
        child: Container(
          width: AppConstants.bottomSheetDragHandleWidth,
          height: AppConstants.bottomSheetDragHandleHeight,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(
              AppConstants.bottomSheetDragHandleRadius,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Salon header ─────────────────────────────────────────────────────────────

class _SalonHeader extends StatelessWidget {
  const _SalonHeader({required this.salon});

  final Map<String, dynamic> salon;

  @override
  Widget build(BuildContext context) {
    final name = salon['business_name'] as String? ?? 'Salón';
    final city = salon['location_city'] as String? ?? '';
    final phone = salon['phone'] as String? ?? '';
    final waVerified = salon['whatsapp_verified'] == true;

    return Row(
      children: [
        // Avatar circle with initial
        Container(
          width: AppConstants.avatarSizeMD,
          height: AppConstants.avatarSizeMD,
          decoration: const BoxDecoration(
            color: _kBrandLight,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _kBrand,
            ),
          ),
        ),
        const SizedBox(width: AppConstants.paddingMD),

        // Name + meta
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (waVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: _kWaGreen, size: 16),
                  ],
                ],
              ),
              if (city.isNotEmpty || phone.isNotEmpty)
                Text(
                  [if (city.isNotEmpty) city, if (phone.isNotEmpty) phone]
                      .join(' · '),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Channel chips ─────────────────────────────────────────────────────────────

class _ChannelChips extends StatelessWidget {
  const _ChannelChips({
    required this.channels,
    required this.selected,
    required this.onSelect,
  });

  final List<ContactChannel> channels;
  final ContactChannel selected;
  final ValueChanged<ContactChannel> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: channels.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppConstants.paddingSM),
        itemBuilder: (_, i) {
          final ch = channels[i];
          final isSelected = ch == selected;
          return GestureDetector(
            onTap: () => onSelect(ch),
            child: AnimatedContainer(
              duration: AppConstants.shortAnimation,
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? ch.color : Colors.white,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusFull),
                border: Border.all(
                  color: isSelected ? ch.color : Colors.black12,
                  width: isSelected ? 0 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: ch.color.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ch.icon,
                    size: 16,
                    color: isSelected ? Colors.white : ch.color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ch.label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Template picker ──────────────────────────────────────────────────────────

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({
    required this.channel,
    required this.selectedTemplate,
    required this.onSelected,
    required this.ref,
  });

  final String channel;
  final OutreachTemplate? selectedTemplate;
  final ValueChanged<OutreachTemplate> onSelected;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(outreachTemplatesProvider(channel));

    return templatesAsync.when(
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (err, stack) => const SizedBox.shrink(),
      data: (templates) {
        if (templates.isEmpty) return const SizedBox.shrink();

        return DropdownButtonFormField<OutreachTemplate>(
          initialValue: selectedTemplate,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Plantilla',
            labelStyle: GoogleFonts.nunito(fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: AppConstants.paddingSM,
            ),
            isDense: true,
            prefixIcon:
                const Icon(Icons.article_outlined, size: 18, color: _kBrand),
          ),
          hint: Text('Seleccionar plantilla',
              style: GoogleFonts.nunito(fontSize: 13, color: Colors.black38)),
          items: templates
              .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(
                      t.name,
                      style: GoogleFonts.nunito(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (t) {
            if (t != null) onSelected(t);
          },
        );
      },
    );
  }
}

// ─── Message compose area ─────────────────────────────────────────────────────

class _MessageComposeArea extends StatelessWidget {
  const _MessageComposeArea({
    required this.channel,
    required this.bodyCtrl,
    required this.subjectCtrl,
  });

  final ContactChannel channel;
  final TextEditingController bodyCtrl;
  final TextEditingController subjectCtrl;

  InputDecoration _inputDec(String label, {Widget? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.nunito(fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        borderSide: const BorderSide(color: _kBrand),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMD,
        vertical: AppConstants.paddingMD,
      ),
      prefixIcon: prefixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject field — email only
        if (channel == ContactChannel.email) ...[
          TextField(
            controller: subjectCtrl,
            style: GoogleFonts.nunito(fontSize: 14),
            decoration: _inputDec(
              'Asunto',
              prefixIcon: const Icon(Icons.subject, size: 18, color: _kBrand),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppConstants.paddingSM),
        ],

        // Body field
        TextField(
          controller: bodyCtrl,
          style: GoogleFonts.nunito(fontSize: 14),
          decoration: _inputDec(
            channel == ContactChannel.email ? 'Cuerpo del email' : 'Mensaje',
            prefixIcon: Icon(
              channel.icon,
              size: 18,
              color: channel.color,
            ),
          ),
          maxLines: 5,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
        ),
      ],
    );
  }
}

// ─── Call compose area ────────────────────────────────────────────────────────

class _CallComposeArea extends StatelessWidget {
  const _CallComposeArea({
    required this.channel,
    required this.outcome,
    required this.durationCtrl,
    required this.notesCtrl,
    required this.onOutcomeChanged,
  });

  final ContactChannel channel;
  final String? outcome;
  final TextEditingController durationCtrl;
  final TextEditingController notesCtrl;
  final ValueChanged<String?> onOutcomeChanged;

  Color _outcomeColor(String? o) => switch (o) {
        'interested' => Colors.green,
        'not_interested' => Colors.red,
        'callback' => Colors.orange,
        'no_answer' => Colors.grey,
        'wrong_number' => Colors.red.shade300,
        'voicemail' => Colors.blue.shade300,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Outcome dropdown
        DropdownButtonFormField<String>(
          initialValue: outcome,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Resultado *',
            labelStyle: GoogleFonts.nunito(fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              borderSide: const BorderSide(color: _kBrand),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: AppConstants.paddingSM,
            ),
            isDense: true,
            prefixIcon: Icon(
              Icons.flag_outlined,
              size: 18,
              color: outcome != null ? _outcomeColor(outcome) : Colors.black38,
            ),
          ),
          hint: Text('Selecciona el resultado',
              style: GoogleFonts.nunito(fontSize: 13, color: Colors.black38)),
          items: _kOutcomes
              .map((pair) => DropdownMenuItem(
                    value: pair.$1,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _outcomeColor(pair.$1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(pair.$2,
                            style: GoogleFonts.nunito(fontSize: 13)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: onOutcomeChanged,
        ),
        const SizedBox(height: AppConstants.paddingSM),

        // Duration row
        Row(
          children: [
            // Duration field
            SizedBox(
              width: 130,
              child: TextField(
                controller: durationCtrl,
                style: GoogleFonts.nunito(fontSize: 14),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Duración (seg)',
                  labelStyle: GoogleFonts.nunito(fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                    borderSide: const BorderSide(color: _kBrand),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMD,
                    vertical: AppConstants.paddingMD,
                  ),
                  prefixIcon:
                      const Icon(Icons.timer_outlined, size: 18, color: Colors.black45),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.paddingSM),

            // Quick duration chips
            Expanded(
              child: Wrap(
                spacing: 6,
                children: [30, 60, 120, 300].map((s) {
                  final label = s < 60
                      ? '${s}s'
                      : '${s ~/ 60}m';
                  return GestureDetector(
                    onTap: () => durationCtrl.text = s.toString(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusFull),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.nunito(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.paddingSM),

        // Notes field
        TextField(
          controller: notesCtrl,
          style: GoogleFonts.nunito(fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Notas (opcional)',
            labelStyle: GoogleFonts.nunito(fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              borderSide: const BorderSide(color: _kBrand),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: AppConstants.paddingMD,
            ),
            prefixIcon: const Icon(Icons.notes, size: 18, color: Colors.black45),
          ),
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
        ),
      ],
    );
  }
}

// ─── Send button ──────────────────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.channel,
    required this.sending,
    required this.onTap,
  });

  final ContactChannel channel;
  final bool sending;
  final VoidCallback onTap;

  String get _label => switch (channel) {
        ContactChannel.waCall || ContactChannel.phoneCall => 'Registrar llamada',
        ContactChannel.email => 'Enviar email',
        ContactChannel.whatsapp => 'Enviar WhatsApp',
        ContactChannel.sms => 'Enviar SMS',
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppConstants.comfortableTouchHeight,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: sending ? null : onTap,
        icon: sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(channel.icon, size: 18),
        label: Text(
          _label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kBrand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _kBrand.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          ),
          elevation: AppConstants.elevationLow,
        ),
      ),
    );
  }
}

// ─── Contact history timeline ─────────────────────────────────────────────────

class _ContactHistoryTimeline extends StatelessWidget {
  const _ContactHistoryTimeline({
    required this.salonId,
    required this.expandedEntries,
    required this.onToggleExpand,
    required this.ref,
  });

  final String salonId;
  final Set<String> expandedEntries;
  final ValueChanged<String> onToggleExpand;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(salonOutreachHistoryProvider(salonId));

    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppConstants.paddingMD),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Text(
          'Error al cargar historial',
          style: GoogleFonts.nunito(fontSize: 13, color: Colors.red),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMD),
            child: Center(
              child: Text(
                'Sin contacto previo',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: Colors.black38,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          );
        }

        return Column(
          children: List.generate(entries.length, (i) {
            final entry = entries[i];
            final isLast = i == entries.length - 1;
            final isExpanded = expandedEntries.contains(entry.id);
            return _HistoryEntryRow(
              entry: entry,
              isLast: isLast,
              isExpanded: isExpanded,
              onToggle: () => onToggleExpand(entry.id),
            );
          }),
        );
      },
    );
  }
}

// ─── History entry row ────────────────────────────────────────────────────────

class _HistoryEntryRow extends StatelessWidget {
  const _HistoryEntryRow({
    required this.entry,
    required this.isLast,
    required this.isExpanded,
    required this.onToggle,
  });

  final OutreachLogEntry entry;
  final bool isLast;
  final bool isExpanded;
  final VoidCallback onToggle;

  String _formatDate(DateTime dt) {
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final h = dt.toLocal().hour.toString().padLeft(2, '0');
    final m = dt.toLocal().minute.toString().padLeft(2, '0');
    final local = dt.toLocal();
    return '${local.day} ${months[local.month - 1]} · $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final channelColor = switch (entry.channel) {
      'wa_message' => _kWaGreen,
      'wa_call' => _kWaGreen,
      'phone' || 'phone_call' => Colors.teal,
      'email' => Colors.orange,
      'sms' => Colors.blue,
      _ => Colors.grey,
    };

    final hasExpandable = (entry.messageText?.isNotEmpty ?? false) ||
        (entry.notes?.isNotEmpty ?? false) ||
        (entry.transcript?.isNotEmpty ?? false);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: channelColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    entry.channelIcon,
                    size: 14,
                    color: channelColor,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: Colors.black12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.paddingSM),

          // Entry card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppConstants.paddingSM,
              ),
              child: GestureDetector(
                onTap: hasExpandable ? onToggle : null,
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.paddingSM),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: channel label + date + outcome badge
                      Row(
                        children: [
                          Text(
                            entry.channelLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: channelColor,
                            ),
                          ),
                          const Spacer(),
                          // Outcome badge (calls only)
                          if (entry.outcome != null)
                            _OutcomeBadge(outcome: entry.outcome!),
                          if (entry.outcome != null)
                            const SizedBox(width: 6),
                          Text(
                            _formatDate(entry.sentAt),
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),

                      // RP name
                      if (entry.rpDisplayName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            entry.rpDisplayName!,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: Colors.black38,
                            ),
                          ),
                        ),

                      // Message preview (collapsed)
                      if (!isExpanded && entry.messageText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppConstants.paddingXS),
                          child: Text(
                            entry.messageText!,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      // Expanded content
                      if (isExpanded) ...[
                        if (entry.messageText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppConstants.paddingXS),
                            child: Text(
                              entry.messageText!,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        if (entry.notes != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppConstants.paddingXS),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.notes,
                                    size: 12, color: Colors.black38),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    entry.notes!,
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (entry.transcript != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppConstants.paddingXS),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4F8),
                                borderRadius: BorderRadius.circular(
                                    AppConstants.radiusXS),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.record_voice_over,
                                        size: 12, color: Colors.black38),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Transcripción',
                                      style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black45),
                                    ),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.transcript!,
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (entry.durationSeconds != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Duración: ${entry.durationSeconds}s',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: Colors.black38,
                              ),
                            ),
                          ),
                      ],

                      // Expand toggle hint
                      if (hasExpandable)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 16,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Outcome badge ────────────────────────────────────────────────────────────

class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge({required this.outcome});

  final String outcome;

  static const _labels = {
    'interested': 'Interesado',
    'not_interested': 'No interesado',
    'callback': 'Callback',
    'no_answer': 'No contestó',
    'wrong_number': 'Núm. incorrecto',
    'voicemail': 'Buzón',
  };

  Color get _color => switch (outcome) {
        'interested' => Colors.green,
        'not_interested' => Colors.red,
        'callback' => Colors.orange,
        'no_answer' => Colors.grey,
        'wrong_number' => Colors.red,
        'voicemail' => Colors.blue,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final label = _labels[outcome] ?? outcome;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _color.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

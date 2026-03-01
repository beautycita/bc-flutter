import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

class BusinessSettingsScreen extends ConsumerStatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  ConsumerState<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState
    extends ConsumerState<BusinessSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _igCtrl = TextEditingController();
  final _fbCtrl = TextEditingController();
  final _cancelHoursCtrl = TextEditingController();
  final _depositPctCtrl = TextEditingController();

  bool _autoConfirm = false;
  bool _acceptWalkins = false;
  bool _depositRequired = false;
  String _noShowPolicy = 'forfeit_deposit';
  bool _initialized = false;
  bool _saving = false;

  // Per-day schedule
  late List<_DayHours> _hours;

  static const _dayNames = [
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
    'Domingo',
  ];
  static const _dayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  void initState() {
    super.initState();
    _hours = List.generate(
      7,
      (i) => _DayHours(
        isOpen: i < 6, // Mon-Sat open, Sun closed by default
        open: const TimeOfDay(hour: 9, minute: 0),
        close: const TimeOfDay(hour: 20, minute: 0),
        breaks: [],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _websiteCtrl.dispose();
    _igCtrl.dispose();
    _fbCtrl.dispose();
    _cancelHoursCtrl.dispose();
    _depositPctCtrl.dispose();
    super.dispose();
  }

  void _initFromBiz(Map<String, dynamic> biz) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = biz['name'] as String? ?? '';
    _phoneCtrl.text = _formatPhoneLocal(biz['phone'] as String? ?? '');
    _addressCtrl.text = biz['address'] as String? ?? '';
    _cityCtrl.text = biz['city'] as String? ?? '';
    _websiteCtrl.text = biz['website'] as String? ?? '';
    _igCtrl.text = biz['instagram_handle'] as String? ?? '';
    _fbCtrl.text = biz['facebook_url'] as String? ?? '';
    _cancelHoursCtrl.text =
        (biz['cancellation_hours'] as int?)?.toString() ?? '24';
    _depositPctCtrl.text =
        (biz['deposit_percentage'] as num?)?.toString() ?? '0';
    _autoConfirm = biz['auto_confirm'] as bool? ?? false;
    _acceptWalkins = biz['accept_walkins'] as bool? ?? false;
    _depositRequired = biz['deposit_required'] as bool? ?? false;
    _noShowPolicy = biz['no_show_policy'] as String? ?? 'forfeit_deposit';

    // Parse hours JSON
    final hoursRaw = biz['hours'];
    if (hoursRaw != null) {
      Map<String, dynamic> hoursMap;
      if (hoursRaw is String) {
        hoursMap = jsonDecode(hoursRaw) as Map<String, dynamic>;
      } else {
        hoursMap = hoursRaw as Map<String, dynamic>;
      }
      for (var i = 0; i < 7; i++) {
        final dayData = hoursMap[_dayKeys[i]];
        if (dayData == null) {
          _hours[i] = _DayHours(
            isOpen: false,
            open: const TimeOfDay(hour: 9, minute: 0),
            close: const TimeOfDay(hour: 20, minute: 0),
            breaks: [],
          );
        } else {
          final d = dayData as Map<String, dynamic>;
          final breaks = <_BreakWindow>[];
          if (d['breaks'] is List) {
            for (final b in d['breaks'] as List) {
              final bm = b as Map<String, dynamic>;
              breaks.add(_BreakWindow(
                start: _parseTime(bm['start'] as String?),
                end: _parseTime(bm['end'] as String?),
              ));
            }
          }
          _hours[i] = _DayHours(
            isOpen: true,
            open: _parseTime(d['open'] as String?),
            close: _parseTime(d['close'] as String?),
            breaks: breaks,
          );
        }
      }
    }
  }

  TimeOfDay _parseTime(String? s) {
    if (s == null) return const TimeOfDay(hour: 9, minute: 0);
    final parts = s.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  /// Strip common MX country codes (+52, 52) and format as local number
  String _formatPhoneLocal(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    // Remove +52 or 52 prefix for MX numbers (10-digit local)
    if (digits.startsWith('52') && digits.length >= 12) {
      digits = digits.substring(2);
    }
    // Remove leading 1 for long-distance prefix if 11 digits
    if (digits.length == 11 && digits.startsWith('1')) {
      digits = digits.substring(1);
    }
    // Format as (XXX) XXX-XXXX for 10-digit numbers
    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return phone; // Return as-is if not standard 10 digits
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  InputDecoration _styledInput(
    String label, {
    Widget? prefixIcon,
    String? prefixText,
  }) {
    final colors = Theme.of(context).colorScheme;
    final gray = colors.onSurface.withValues(alpha: 0.12);
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon,
      prefixText: prefixText,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        borderSide: BorderSide(color: gray, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        borderSide: BorderSide(color: gray.withValues(alpha: 0.06), width: 1),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  BoxDecoration _cardDecoration(ColorScheme colors) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      border: Border.all(
        color: colors.onSurface.withValues(alpha: 0.08),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final colors = Theme.of(context).colorScheme;

    return bizAsync.when(
      data: (biz) {
        if (biz == null) {
          return const Center(child: Text('Sin negocio'));
        }

        _initFromBiz(biz);

        return ListView(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          children: [
            // ---------- Profile ----------
            _SectionHeader(label: 'PERFIL DEL NEGOCIO'),
            const SizedBox(height: AppConstants.paddingSM),
            TextField(
              controller: _nameCtrl,
              decoration: _styledInput('Nombre del negocio'),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _styledInput('Telefono'),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            TextField(
              controller: _addressCtrl,
              decoration: _styledInput('Direccion'),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            TextField(
              controller: _cityCtrl,
              decoration: _styledInput('Ciudad'),
            ),

            const SizedBox(height: AppConstants.paddingLG),
            _SectionHeader(label: 'REDES SOCIALES'),
            const SizedBox(height: AppConstants.paddingSM),
            TextField(
              controller: _websiteCtrl,
              decoration: _styledInput('Sitio web',
                  prefixIcon: const Icon(Icons.language_rounded, size: 20)),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            TextField(
              controller: _igCtrl,
              decoration: _styledInput('Instagram',
                  prefixIcon: Icon(Icons.camera_alt_rounded,
                      size: 20,
                      color: colors.onSurface.withValues(alpha: 0.5)),
                  prefixText: '@'),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            TextField(
              controller: _fbCtrl,
              decoration: _styledInput('Facebook URL',
                  prefixIcon: const Icon(Icons.facebook_rounded, size: 20)),
            ),

            // ---------- Operating hours ----------
            const SizedBox(height: AppConstants.paddingLG),
            _SectionHeader(label: 'HORARIO DE OPERACION'),
            const SizedBox(height: AppConstants.paddingSM),
            _buildHoursEditor(colors),

            // ---------- Policies ----------
            const SizedBox(height: AppConstants.paddingLG),
            _SectionHeader(label: 'POLITICAS'),
            const SizedBox(height: AppConstants.paddingSM),
            Container(
              decoration: _cardDecoration(colors),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Confirmar citas automaticamente',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text('Sin revision manual',
                        style: GoogleFonts.nunito(fontSize: 12)),
                    value: _autoConfirm,
                    onChanged: (v) => setState(() => _autoConfirm = v),
                    activeTrackColor: colors.primary,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text('Aceptar walk-ins',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text('Clientes sin cita previa',
                        style: GoogleFonts.nunito(fontSize: 12)),
                    value: _acceptWalkins,
                    onChanged: (v) => setState(() => _acceptWalkins = v),
                    activeTrackColor: colors.primary,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text('Requiere deposito',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    value: _depositRequired,
                    onChanged: (v) => setState(() => _depositRequired = v),
                    activeTrackColor: colors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cancelHoursCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _styledInput('Cancelacion (horas)'),
                  ),
                ),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: TextField(
                    controller: _depositPctCtrl,
                    keyboardType: TextInputType.number,
                    enabled: _depositRequired,
                    decoration: _styledInput('Deposito (%)'),
                  ),
                ),
              ],
            ),

            // No-show policy
            const SizedBox(height: AppConstants.paddingMD),
            _SectionHeader(label: 'POLITICA DE NO-SHOW'),
            const SizedBox(height: AppConstants.paddingSM),
            Container(
              decoration: _cardDecoration(colors),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: Text('Retener deposito',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text('Cliente pierde el deposito',
                        style: GoogleFonts.nunito(fontSize: 12)),
                    value: 'forfeit_deposit',
                    groupValue: _noShowPolicy,
                    onChanged: (v) =>
                        setState(() => _noShowPolicy = v ?? 'forfeit_deposit'),
                    activeColor: colors.primary,
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: Text('Reembolso total',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text('Devolver todo al cliente',
                        style: GoogleFonts.nunito(fontSize: 12)),
                    value: 'full_refund',
                    groupValue: _noShowPolicy,
                    onChanged: (v) =>
                        setState(() => _noShowPolicy = v ?? 'forfeit_deposit'),
                    activeColor: colors.primary,
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: Text('Reembolso parcial',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text('50% deposito retenido',
                        style: GoogleFonts.nunito(fontSize: 12)),
                    value: 'partial_refund',
                    groupValue: _noShowPolicy,
                    onChanged: (v) =>
                        setState(() => _noShowPolicy = v ?? 'forfeit_deposit'),
                    activeColor: colors.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.paddingXL),
            ElevatedButton(
              onPressed: _saving ? null : () => _save(biz['id'] as String),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar Cambios'),
            ),
            const SizedBox(height: AppConstants.paddingXL),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: GoogleFonts.nunito(color: colors.error)),
      ),
    );
  }

  // ---------- Hours editor ----------

  Widget _buildHoursEditor(ColorScheme colors) {
    return Container(
      decoration: _cardDecoration(colors),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const Divider(height: 1),
            _buildDayHoursRow(colors, i),
          ],
        ],
      ),
    );
  }

  Widget _buildDayHoursRow(ColorScheme colors, int dayIndex) {
    final day = _hours[dayIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  _dayNames[dayIndex],
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: day.isOpen
                        ? colors.onSurface
                        : colors.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: Switch(
                  value: day.isOpen,
                  onChanged: (v) {
                    setState(() {
                      _hours[dayIndex] = day.copyWith(isOpen: v);
                    });
                  },
                  activeTrackColor: colors.primary,
                ),
              ),
              if (day.isOpen) ...[
                _timeButton(context, day.open, (t) {
                  setState(
                      () => _hours[dayIndex] = day.copyWith(open: t));
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('-',
                      style: GoogleFonts.nunito(
                          color: colors.onSurface.withValues(alpha: 0.4))),
                ),
                _timeButton(context, day.close, (t) {
                  setState(
                      () => _hours[dayIndex] = day.copyWith(close: t));
                }),
              ] else
                Text(
                  'Cerrado',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeButton(
      BuildContext context, TimeOfDay time, ValueChanged<TimeOfDay> onPicked) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final picked =
            await showTimePicker(context: context, initialTime: time);
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _fmt(time),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.primary,
          ),
        ),
      ),
    );
  }

  // ---------- Save ----------

  Map<String, dynamic> _buildHoursJson() {
    final result = <String, dynamic>{};
    for (var i = 0; i < 7; i++) {
      final day = _hours[i];
      if (!day.isOpen) {
        result[_dayKeys[i]] = null;
      } else {
        result[_dayKeys[i]] = {
          'open': _fmt(day.open),
          'close': _fmt(day.close),
          'breaks': day.breaks
              .map((b) => {'start': _fmt(b.start), 'end': _fmt(b.end)})
              .toList(),
        };
      }
    }
    return result;
  }

  Future<void> _save(String bizId) async {
    setState(() => _saving = true);

    try {
      await SupabaseClientService.client.from('businesses').update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'website':
            _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        'instagram_handle':
            _igCtrl.text.trim().isEmpty ? null : _igCtrl.text.trim(),
        'facebook_url':
            _fbCtrl.text.trim().isEmpty ? null : _fbCtrl.text.trim(),
        'auto_confirm': _autoConfirm,
        'accept_walkins': _acceptWalkins,
        'deposit_required': _depositRequired,
        'cancellation_hours':
            int.tryParse(_cancelHoursCtrl.text.trim()) ?? 24,
        'deposit_percentage': _depositRequired
            ? (int.tryParse(_depositPctCtrl.text.trim()) ?? 0)
            : 0,
        'no_show_policy': _noShowPolicy,
        'hours': _buildHoursJson(),
      }).eq('id', bizId);

      ref.invalidate(currentBusinessProvider);

      ToastService.showSuccess('Cambios guardados');
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.paddingSM),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: colors.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class _DayHours {
  final bool isOpen;
  final TimeOfDay open;
  final TimeOfDay close;
  final List<_BreakWindow> breaks;

  const _DayHours({
    required this.isOpen,
    required this.open,
    required this.close,
    required this.breaks,
  });

  _DayHours copyWith({
    bool? isOpen,
    TimeOfDay? open,
    TimeOfDay? close,
    List<_BreakWindow>? breaks,
  }) {
    return _DayHours(
      isOpen: isOpen ?? this.isOpen,
      open: open ?? this.open,
      close: close ?? this.close,
      breaks: breaks ?? this.breaks,
    );
  }
}

class _BreakWindow {
  final TimeOfDay start;
  final TimeOfDay end;
  const _BreakWindow({required this.start, required this.end});
}

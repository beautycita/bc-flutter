import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../providers/feature_toggle_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';
import 'business_closures_screen.dart';
import 'business_shell_screen.dart';

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
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _igCtrl = TextEditingController();
  final _fbCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _cancelHoursCtrl = TextEditingController();
  final _depositPctCtrl = TextEditingController();

  bool _autoConfirm = false;
  bool _acceptWalkins = false;
  bool _depositRequired = false;
  String _noShowPolicy = 'forfeit_deposit';
  Set<int> _reminderHoursList = {24, 1};
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
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _descCtrl.dispose();
    _websiteCtrl.dispose();
    _igCtrl.dispose();
    _fbCtrl.dispose();
    _tiktokCtrl.dispose();
    _cancelHoursCtrl.dispose();
    _depositPctCtrl.dispose();
    super.dispose();
  }

  void _initFromBiz(Map<String, dynamic> biz) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = biz['name'] as String? ?? '';
    _phoneCtrl.text = _formatPhoneLocal(biz['phone'] as String? ?? '');
    _emailCtrl.text = biz['email'] as String? ?? '';
    _addressCtrl.text = biz['address'] as String? ?? '';
    _cityCtrl.text = biz['city'] as String? ?? '';
    _descCtrl.text = biz['description'] as String? ?? '';
    _websiteCtrl.text = biz['website'] as String? ?? '';
    _igCtrl.text = biz['instagram_handle'] as String? ?? '';
    _fbCtrl.text = biz['facebook_url'] as String? ?? '';
    _tiktokCtrl.text = biz['tiktok_handle'] as String? ?? '';
    _cancelHoursCtrl.text =
        (biz['cancellation_hours'] as int?)?.toString() ?? '24';
    _depositPctCtrl.text =
        (biz['deposit_percentage'] as num?)?.toInt().toString() ?? '0';
    _autoConfirm = biz['auto_confirm'] as bool? ?? false;
    _acceptWalkins = biz['accept_walkins'] as bool? ?? false;
    _depositRequired = biz['deposit_required'] as bool? ?? false;
    _noShowPolicy = biz['no_show_policy'] as String? ?? 'forfeit_deposit';
    final reminderRaw = biz['reminder_hours_list'];
    if (reminderRaw is List && reminderRaw.isNotEmpty) {
      _reminderHoursList = reminderRaw.map((e) => e as int).toSet();
    } else {
      _reminderHoursList = {24, 1};
    }

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
            const SizedBox(height: AppConstants.paddingSM),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _styledInput('Email del negocio',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20)),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              maxLength: 300,
              decoration: _styledInput('Descripcion del negocio'),
            ),
            const SizedBox(height: 4),
            _AiDescriptionButton(
              businessName: _nameCtrl.text,
              city: _cityCtrl.text,
              onGenerated: (text) {
                setState(() => _descCtrl.text = text);
              },
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
            const SizedBox(height: AppConstants.paddingSM),
            TextField(
              controller: _tiktokCtrl,
              decoration: _styledInput('TikTok',
                  prefixIcon: Icon(Icons.music_note_rounded,
                      size: 20,
                      color: colors.onSurface.withValues(alpha: 0.5)),
                  prefixText: '@'),
            ),

            // ---------- Quick links ----------
            const SizedBox(height: AppConstants.paddingLG),
            _SectionHeader(label: 'GESTION RAPIDA'),
            const SizedBox(height: AppConstants.paddingSM),
            _QuickLinkTile(
              icon: Icons.people_outline_rounded,
              label: 'Administrar Personal',
              onTap: () => ref.read(businessTabProvider.notifier).state = 4,
            ),
            _QuickLinkTile(
              icon: Icons.design_services_outlined,
              label: 'Administrar Servicios',
              onTap: () => ref.read(businessTabProvider.notifier).state = 3,
            ),
            _QuickLinkTile(
              icon: Icons.qr_code_rounded,
              label: 'QR para Walk-ins',
              onTap: () => ref.read(businessTabProvider.notifier).state = 8,
            ),

            // ---------- Operating hours ----------
            const SizedBox(height: AppConstants.paddingLG),
            _SectionHeader(label: 'HORARIO DE OPERACION'),
            const SizedBox(height: AppConstants.paddingSM),
            _buildHoursEditor(colors),

            // ---------- Closures / Holidays ----------
            const SizedBox(height: AppConstants.paddingLG),
            Container(
              decoration: _cardDecoration(colors),
              padding: const EdgeInsets.all(16),
              child: const BusinessClosuresSection(),
            ),

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
                  // Deposit toggle — gated by enable_deposit_required feature toggle
                  if (ref.watch(featureTogglesProvider).isEnabled('enable_deposit_required')) ...[
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
                if (ref.watch(featureTogglesProvider).isEnabled('enable_deposit_required')) ...[
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
              ],
            ),

            // No-show policy — only shown when deposit feature is enabled
            if (ref.watch(featureTogglesProvider).isEnabled('enable_deposit_required')) ...[
              const SizedBox(height: AppConstants.paddingMD),
              _SectionHeader(label: 'POLITICA DE NO-SHOW'),
              const SizedBox(height: AppConstants.paddingSM),
              Container(
                decoration: _cardDecoration(colors),
                clipBehavior: Clip.antiAlias,
                child: RadioGroup<String>(
                  groupValue: _noShowPolicy,
                  onChanged: (v) => setState(() => _noShowPolicy = v ?? 'forfeit_deposit'),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: Text('Retener deposito',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Text('Cliente pierde el deposito',
                            style: GoogleFonts.nunito(fontSize: 12)),
                        value: 'forfeit_deposit',
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: Text('Reembolso total',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Text('Devolver todo al cliente',
                            style: GoogleFonts.nunito(fontSize: 12)),
                        value: 'full_refund',
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: Text('Reembolso parcial',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Text('50% deposito retenido',
                            style: GoogleFonts.nunito(fontSize: 12)),
                        value: 'partial_refund',
                      ),
                    ],
                  ),
                ),
            ),
            ], // end enable_deposit_required gate

            // ---------- Recordatorios ----------
            const SizedBox(height: AppConstants.paddingLG),
            _SectionHeader(label: 'RECORDATORIOS'),
            const SizedBox(height: AppConstants.paddingSM),
            Container(
              decoration: _cardDecoration(colors),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enviar recordatorios',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Selecciona hasta 2 horarios para recordar al cliente',
                    style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1, 2, 4, 12, 24].map((h) {
                      final selected = _reminderHoursList.contains(h);
                      final label = h == 1
                          ? '1 hora'
                          : h < 24
                              ? '$h horas'
                              : '24 horas';
                      return FilterChip(
                        label: Text(label,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : colors.onSurface
                                      .withValues(alpha: 0.7),
                            )),
                        selected: selected,
                        selectedColor: colors.primary,
                        backgroundColor:
                            colors.onSurface.withValues(alpha: 0.06),
                        checkmarkColor: Colors.white,
                        onSelected: (on) {
                          setState(() {
                            if (on) {
                              if (_reminderHoursList.length < 2) {
                                _reminderHoursList.add(h);
                              } else {
                                ToastService.showInfo('Maximo 2 recordatorios');
                              }
                            } else {
                              _reminderHoursList.remove(h);
                            }
                          });
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: selected
                                ? colors.primary
                                : colors.onSurface
                                    .withValues(alpha: 0.1),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_reminderHoursList.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Builder(builder: (_) {
                      final sorted = _reminderHoursList.toList()..sort((a, b) => b.compareTo(a));
                      final labels = sorted.map((h) => h == 1 ? '1 hora antes' : h < 24 ? '$h horas antes' : '24 horas antes');
                      return Text(
                        'Activos: ${labels.join(' + ')}',
                        style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: colors.primary),
                      );
                    }),
                  ],
                ],
              ),
            ),

            // ---------- Importar datos (placeholder) ----------
            const SizedBox(height: AppConstants.paddingLG),
            _SectionHeader(label: 'IMPORTAR DATOS'),
            const SizedBox(height: AppConstants.paddingSM),
            Container(
              decoration: _cardDecoration(colors),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      size: 32, color: colors.primary.withValues(alpha: 0.5)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Importar datos',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Proximamente: importa tus clientes, servicios e historial de citas desde otros sistemas.',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
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
                      if (v && !day.isOpen) {
                        // Toggling ON — reset to reasonable defaults
                        _hours[dayIndex] = day.copyWith(
                          isOpen: true,
                          open: const TimeOfDay(hour: 9, minute: 0),
                          close: const TimeOfDay(hour: 19, minute: 0),
                        );
                      } else {
                        _hours[dayIndex] = day.copyWith(isOpen: v);
                      }
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
    // Validate close time > open time for all open days
    for (var i = 0; i < 7; i++) {
      final day = _hours[i];
      if (!day.isOpen) continue;
      final openMin = day.open.hour * 60 + day.open.minute;
      final closeMin = day.close.hour * 60 + day.close.minute;
      if (closeMin <= openMin) {
        ToastService.showWarning(
            'La hora de cierre debe ser posterior a la de apertura (${_dayKeys[i]})');
        return;
      }
    }

    setState(() => _saving = true);

    try {
      await SupabaseClientService.client.from('businesses').update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9+]'), ''),
        'email':
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'website':
            _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        'instagram_handle':
            _igCtrl.text.trim().isEmpty ? null : _igCtrl.text.trim(),
        'facebook_url':
            _fbCtrl.text.trim().isEmpty ? null : _fbCtrl.text.trim(),
        'tiktok_handle':
            _tiktokCtrl.text.trim().isEmpty ? null : _tiktokCtrl.text.trim(),
        'auto_confirm': _autoConfirm,
        'accept_walkins': _acceptWalkins,
        'deposit_required': _depositRequired,
        'cancellation_hours':
            int.tryParse(_cancelHoursCtrl.text.trim()) ?? 24,
        'deposit_percentage': _depositRequired
            ? (int.tryParse(_depositPctCtrl.text.trim()) ?? 0)
            : 0,
        'no_show_policy': _noShowPolicy,
        'reminder_hours_list': _reminderHoursList.toList(),
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

// ---------------------------------------------------------------------------
// Quick link tile for navigating to other tabs
// ---------------------------------------------------------------------------

class _QuickLinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickLinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface)),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: colors.onSurface.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Description Generator
// ---------------------------------------------------------------------------

class _AiDescriptionButton extends ConsumerStatefulWidget {
  final String businessName;
  final String city;
  final ValueChanged<String> onGenerated;

  const _AiDescriptionButton({
    required this.businessName,
    required this.city,
    required this.onGenerated,
  });

  @override
  ConsumerState<_AiDescriptionButton> createState() => _AiDescriptionButtonState();
}

class _AiDescriptionButtonState extends ConsumerState<_AiDescriptionButton> {
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      final bizId = biz?['id'] as String? ?? '';
      final svcs = bizId.isNotEmpty
          ? await SupabaseClientService.client
              .from('services')
              .select('name')
              .eq('business_id', bizId)
              .eq('is_active', true)
          : [];

      final serviceNames = (svcs as List)
          .map((s) => s['name'] as String)
          .take(6)
          .join(', ');

      final name = widget.businessName.isNotEmpty
          ? widget.businessName
          : biz?['name'] ?? 'Mi Salon';
      final city = widget.city.isNotEmpty
          ? widget.city
          : biz?['city'] ?? '';

      final response = await SupabaseClientService.client.functions.invoke(
        'aphrodite-chat',
        body: {
          'action': 'generate_copy',
          'field_type': 'business_description',
          'context': {
            'name': name,
            'city': city,
            'services': serviceNames,
          },
        },
      );

      if (response.status == 200 && response.data is Map) {
        final text = (response.data['text'] as String? ?? '').trim();
        if (text.isNotEmpty && mounted) {
          widget.onGenerated(text);
          ToastService.showSuccess('Descripcion generada');
        }
      }
    } catch (e) {
      if (mounted) ToastService.showError('No se pudo generar la descripcion');
      debugPrint('[AI Desc] Error: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _generating ? null : _generate,
        icon: _generating
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary,
                ),
              )
            : Icon(Icons.auto_awesome, size: 16, color: colors.primary),
        label: Text(
          _generating ? 'Generando...' : 'Generar con IA',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.primary,
          ),
        ),
      ),
    );
  }
}

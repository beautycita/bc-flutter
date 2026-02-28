import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';

import '../../config/breakpoints.dart';
import '../../providers/business_portal_provider.dart';

/// Business settings page — profile, social, operating hours, policies.
class BizSettingsPage extends ConsumerWidget {
  const BizSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _SettingsContent(biz: biz);
      },
    );
  }
}

class _SettingsContent extends ConsumerStatefulWidget {
  const _SettingsContent({required this.biz});
  final Map<String, dynamic> biz;

  @override
  ConsumerState<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends ConsumerState<_SettingsContent> {
  // Profile
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _descCtrl;

  // Social
  late TextEditingController _websiteCtrl;
  late TextEditingController _instagramCtrl;
  late TextEditingController _facebookCtrl;

  // Policies
  bool _autoConfirm = false;
  int _cancelHours = 24;
  bool _acceptWalkins = false;
  bool _depositRequired = false;
  double _depositPercent = 0;
  String _noShowPolicy = 'forfeit_deposit';

  // Operating hours: day name string → {open, start, end, breaks: [{start, end}]}
  // Uses day-name keys to match mobile format
  static const _dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  final Map<String, _DayHours> _hours = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.biz;
    _nameCtrl = TextEditingController(text: b['name'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: b['phone'] as String? ?? '');
    _addressCtrl = TextEditingController(text: b['address'] as String? ?? '');
    _cityCtrl = TextEditingController(text: b['city'] as String? ?? '');
    _descCtrl = TextEditingController(text: b['description'] as String? ?? '');

    _websiteCtrl = TextEditingController(text: b['website'] as String? ?? '');
    _instagramCtrl = TextEditingController(text: b['instagram_handle'] as String? ?? '');
    _facebookCtrl = TextEditingController(text: b['facebook_url'] as String? ?? '');

    _autoConfirm = b['auto_confirm'] as bool? ?? false;
    _cancelHours = (b['cancellation_hours'] as num?)?.toInt() ?? 24;
    _acceptWalkins = b['accept_walkins'] as bool? ?? false;
    _depositRequired = b['deposit_required'] as bool? ?? false;
    _depositPercent = (b['deposit_percent'] as num?)?.toDouble() ?? 0;
    _noShowPolicy = b['no_show_policy'] as String? ?? 'forfeit_deposit';

    _loadHours(b);
  }

  void _loadHours(Map<String, dynamic> biz) {
    // Initialize defaults with day-name keys
    for (var i = 0; i < 7; i++) {
      _hours[_dayKeys[i]] = _DayHours(open: i < 6, start: '09:00', end: '18:00', breaks: []);
    }

    // Try to parse existing hours JSON
    final hoursRaw = biz['hours'];
    if (hoursRaw == null) return;

    try {
      final Map<String, dynamic> parsed = hoursRaw is String ? jsonDecode(hoursRaw) : (hoursRaw as Map<String, dynamic>);
      for (final entry in parsed.entries) {
        // Support both old integer keys (1-7) and new day-name keys
        String? dayKey;
        final asInt = int.tryParse(entry.key);
        if (asInt != null && asInt >= 1 && asInt <= 7) {
          dayKey = _dayKeys[asInt - 1]; // Convert 1-based int to day name
        } else if (_dayKeys.contains(entry.key)) {
          dayKey = entry.key;
        }
        if (dayKey == null) continue;

        final data = entry.value as Map<String, dynamic>;
        final breaks = <_BreakWindow>[];
        if (data['breaks'] is List) {
          for (final br in data['breaks'] as List) {
            if (br is Map<String, dynamic>) {
              breaks.add(_BreakWindow(
                start: br['start'] as String? ?? '13:00',
                end: br['end'] as String? ?? '14:00',
              ));
            }
          }
        }
        _hours[dayKey] = _DayHours(
          open: data['open'] as bool? ?? false,
          start: data['start'] as String? ?? '09:00',
          end: data['end'] as String? ?? '18:00',
          breaks: breaks,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _descCtrl.dispose();
    _websiteCtrl.dispose();
    _instagramCtrl.dispose();
    _facebookCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _hoursToJson() {
    final result = <String, dynamic>{};
    for (final key in _dayKeys) {
      final h = _hours[key]!;
      result[key] = {
        'open': h.open,
        'start': h.start,
        'end': h.end,
        'breaks': [
          for (final b in h.breaks) {'start': b.start, 'end': b.end},
        ],
      };
    }
    return result;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await BCSupabase.client.from(BCTables.businesses).update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'instagram_handle': _instagramCtrl.text.trim(),
        'facebook_url': _facebookCtrl.text.trim(),
        'auto_confirm': _autoConfirm,
        'cancellation_hours': _cancelHours,
        'accept_walkins': _acceptWalkins,
        'deposit_required': _depositRequired,
        'deposit_percent': _depositPercent,
        'no_show_policy': _noShowPolicy,
        'hours': _hoursToJson(),
      }).eq('id', widget.biz['id'] as String);

      ref.invalidate(currentBusinessProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayNames = ['Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado', 'Domingo'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);
        final isMobile = WebBreakpoints.isMobile(constraints.maxWidth);
        final padding = isMobile ? 16.0 : 24.0;
        final maxWidth = isDesktop ? 800.0 : double.infinity;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configuracion', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 24),

                  // Profile
                  _SectionCard(
                    title: 'Perfil del negocio',
                    icon: Icons.store_outlined,
                    child: Column(
                      children: [
                        TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del negocio')),
                        const SizedBox(height: BCSpacing.md),
                        TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Telefono'), keyboardType: TextInputType.phone),
                        const SizedBox(height: BCSpacing.md),
                        TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Direccion')),
                        const SizedBox(height: BCSpacing.md),
                        TextFormField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'Ciudad')),
                        const SizedBox(height: BCSpacing.md),
                        TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descripcion'), maxLines: 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Social media
                  _SectionCard(
                    title: 'Redes sociales',
                    icon: Icons.share_outlined,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _websiteCtrl,
                          decoration: const InputDecoration(labelText: 'Sitio web', prefixIcon: Icon(Icons.language, size: 20)),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: BCSpacing.md),
                        TextFormField(
                          controller: _instagramCtrl,
                          decoration: const InputDecoration(labelText: 'Instagram', prefixText: '@ '),
                        ),
                        const SizedBox(height: BCSpacing.md),
                        TextFormField(
                          controller: _facebookCtrl,
                          decoration: const InputDecoration(labelText: 'Facebook URL', prefixIcon: Icon(Icons.facebook, size: 20)),
                          keyboardType: TextInputType.url,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Operating hours
                  _SectionCard(
                    title: 'Horario de operacion',
                    icon: Icons.schedule_outlined,
                    child: Column(
                      children: [
                        for (var i = 0; i < 7; i++) ...[
                          _HoursRow(
                            dayName: dayNames[i],
                            hours: _hours[_dayKeys[i]]!,
                            onChanged: (h) => setState(() => _hours[_dayKeys[i]] = h),
                          ),
                          if (i < 6) const SizedBox(height: 4),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Policies
                  _SectionCard(
                    title: 'Politicas',
                    icon: Icons.policy_outlined,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Auto-confirmar citas'),
                          subtitle: const Text('Las citas se confirman automaticamente'),
                          value: _autoConfirm,
                          onChanged: (v) => setState(() => _autoConfirm = v),
                        ),
                        SwitchListTile(
                          title: const Text('Aceptar walk-ins'),
                          subtitle: const Text('Permitir citas sin reservacion'),
                          value: _acceptWalkins,
                          onChanged: (v) => setState(() => _acceptWalkins = v),
                        ),
                        const Divider(),
                        ListTile(
                          title: const Text('Tiempo de cancelacion'),
                          subtitle: Text('El cliente puede cancelar hasta $_cancelHours horas antes'),
                          trailing: DropdownButton<int>(
                            value: _cancelHours,
                            items: [2, 4, 6, 12, 24, 48].map((h) => DropdownMenuItem(value: h, child: Text('$h hrs'))).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _cancelHours = v);
                            },
                          ),
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: const Text('Deposito requerido'),
                          subtitle: const Text('Cobrar deposito al reservar'),
                          value: _depositRequired,
                          onChanged: (v) => setState(() => _depositRequired = v),
                        ),
                        if (_depositRequired) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text('Porcentaje: ${_depositPercent.toStringAsFixed(0)}%'),
                                Expanded(
                                  child: Slider(
                                    value: _depositPercent,
                                    min: 0,
                                    max: 100,
                                    divisions: 20,
                                    label: '${_depositPercent.toStringAsFixed(0)}%',
                                    onChanged: (v) => setState(() => _depositPercent = v),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Divider(),
                        ListTile(
                          title: const Text('Politica de no-show'),
                          subtitle: Text(_noShowPolicyLabel(_noShowPolicy)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              RadioListTile<String>(
                                title: const Text('Perder deposito'),
                                value: 'forfeit_deposit',
                                groupValue: _noShowPolicy,
                                onChanged: (v) => setState(() => _noShowPolicy = v ?? 'forfeit_deposit'),
                                dense: true,
                              ),
                              RadioListTile<String>(
                                title: const Text('Reembolso completo'),
                                subtitle: const Text('Se devuelve el deposito al cliente'),
                                value: 'full_refund',
                                groupValue: _noShowPolicy,
                                onChanged: (v) => setState(() => _noShowPolicy = v ?? 'forfeit_deposit'),
                                dense: true,
                              ),
                              RadioListTile<String>(
                                title: const Text('Reembolso parcial'),
                                subtitle: const Text('Se devuelve una parte del deposito'),
                                value: 'partial_refund',
                                groupValue: _noShowPolicy,
                                onChanged: (v) => setState(() => _noShowPolicy = v ?? 'forfeit_deposit'),
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Guardar cambios'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _noShowPolicyLabel(String policy) {
    return switch (policy) {
      'forfeit_deposit' => 'El cliente pierde el deposito',
      'full_refund' => 'Reembolso completo al cliente',
      'partial_refund' => 'Reembolso parcial al cliente',
      _ => policy,
    };
  }
}

// ── Operating Hours Row ─────────────────────────────────────────────────────

class _DayHours {
  bool open;
  String start;
  String end;
  List<_BreakWindow> breaks;

  _DayHours({required this.open, required this.start, required this.end, required this.breaks});
}

class _BreakWindow {
  String start;
  String end;
  _BreakWindow({required this.start, required this.end});
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({required this.dayName, required this.hours, required this.onChanged});
  final String dayName;
  final _DayHours hours;
  final ValueChanged<_DayHours> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(dayName, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                width: 48,
                child: Switch(
                  value: hours.open,
                  onChanged: (v) => onChanged(_DayHours(open: v, start: hours.start, end: hours.end, breaks: hours.breaks)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              if (hours.open) ...[
                const SizedBox(width: 8),
                _SmallTimeDropdown(
                  value: hours.start,
                  onChanged: (v) => onChanged(_DayHours(open: true, start: v, end: hours.end, breaks: hours.breaks)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('-', style: theme.textTheme.bodySmall),
                ),
                _SmallTimeDropdown(
                  value: hours.end,
                  onChanged: (v) => onChanged(_DayHours(open: true, start: hours.start, end: v, breaks: hours.breaks)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.free_breakfast_outlined, size: 18),
                  tooltip: 'Agregar descanso',
                  onPressed: () {
                    final newBreaks = List<_BreakWindow>.from(hours.breaks)
                      ..add(_BreakWindow(start: '13:00', end: '14:00'));
                    onChanged(_DayHours(open: true, start: hours.start, end: hours.end, breaks: newBreaks));
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('Cerrado', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.4), fontStyle: FontStyle.italic)),
                ),
            ],
          ),
          // Break windows
          if (hours.open && hours.breaks.isNotEmpty) ...[
            for (var bi = 0; bi < hours.breaks.length; bi++)
              Padding(
                padding: const EdgeInsets.only(left: 90, top: 4),
                child: Row(
                  children: [
                    Icon(Icons.free_breakfast_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 8),
                    _SmallTimeDropdown(
                      value: hours.breaks[bi].start,
                      onChanged: (v) {
                        final newBreaks = List<_BreakWindow>.from(hours.breaks);
                        newBreaks[bi] = _BreakWindow(start: v, end: newBreaks[bi].end);
                        onChanged(_DayHours(open: true, start: hours.start, end: hours.end, breaks: newBreaks));
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('-', style: theme.textTheme.bodySmall),
                    ),
                    _SmallTimeDropdown(
                      value: hours.breaks[bi].end,
                      onChanged: (v) {
                        final newBreaks = List<_BreakWindow>.from(hours.breaks);
                        newBreaks[bi] = _BreakWindow(start: newBreaks[bi].start, end: v);
                        onChanged(_DayHours(open: true, start: hours.start, end: hours.end, breaks: newBreaks));
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: colors.error),
                      onPressed: () {
                        final newBreaks = List<_BreakWindow>.from(hours.breaks)..removeAt(bi);
                        onChanged(_DayHours(open: true, start: hours.start, end: hours.end, breaks: newBreaks));
                      },
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Quitar descanso',
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SmallTimeDropdown extends StatelessWidget {
  const _SmallTimeDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final times = <String>[];
    for (var h = 6; h <= 22; h++) {
      times.add('${h.toString().padLeft(2, '0')}:00');
      times.add('${h.toString().padLeft(2, '0')}:30');
    }

    return DropdownButton<String>(
      value: times.contains(value) ? value : times.first,
      items: [for (final t in times) DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      underline: const SizedBox.shrink(),
      isDense: true,
    );
  }
}

// ── Section Card ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

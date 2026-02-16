import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';
import '../models/curate_result.dart';

class TimeOverrideSheet extends StatefulWidget {
  final void Function(OverrideWindow window) onSelect;

  const TimeOverrideSheet({super.key, required this.onSelect});

  @override
  State<TimeOverrideSheet> createState() => _TimeOverrideSheetState();
}

class _TimeOverrideSheetState extends State<TimeOverrideSheet> {
  String? _selectedRange;
  String? _selectedTimeOfDay;
  DateTime? _selectedDate;

  static const _ranges = [
    ('today', 'Hoy'),
    ('tomorrow', 'Manana'),
    ('this_week', 'Esta semana'),
    ('next_week', 'Prox. semana'),
  ];

  static const _timesOfDay = [
    ('morning', 'Manana'),
    ('afternoon', 'Tarde'),
    ('evening', 'Noche'),
  ];

  bool get _canConfirm => _selectedRange != null || _selectedDate != null;

  void _onRangeTap(String range) {
    setState(() {
      _selectedRange = range;
      _selectedDate = null;
    });
  }

  void _onTimeOfDayTap(String timeOfDay) {
    setState(() {
      if (_selectedTimeOfDay == timeOfDay) {
        _selectedTimeOfDay = null;
      } else {
        _selectedTimeOfDay = timeOfDay;
      }
    });
  }

  Future<void> _pickDate() async {
    final palette = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      locale: const Locale('es', 'MX'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: palette.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedRange = null;
      });
    }
  }

  void _confirm() {
    if (!_canConfirm) return;

    final window = OverrideWindow(
      range: _selectedDate != null
          ? _selectedDate!.toIso8601String().substring(0, 10)
          : _selectedRange!,
      timeOfDay: _selectedTimeOfDay,
      specificDate: _selectedDate?.toIso8601String().substring(0, 10),
    );

    Navigator.of(context).pop();
    widget.onSelect(window);

    // Show snackbar after closing the sheet
    Future.delayed(const Duration(milliseconds: 300), () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hora seleccionada'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXL),
        ),
      ),
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingLG),

            // Title
            Text(
              'Cuando prefieres?',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: palette.onSurface,
              ),
            ),
            const SizedBox(height: AppConstants.paddingLG),

            // Day range pills
            Wrap(
              spacing: AppConstants.paddingSM,
              runSpacing: AppConstants.paddingSM,
              children: [
                ..._ranges.map((r) => _Pill(
                      label: r.$2,
                      selected: _selectedRange == r.$1,
                      onTap: () => _onRangeTap(r.$1),
                    )),
                _Pill(
                  label: _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}'
                      : 'Elegir fecha',
                  selected: _selectedDate != null,
                  onTap: _pickDate,
                  icon: Icons.calendar_today,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLG),

            // Time of day
            Text(
              'Horario:',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: palette.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Row(
              children: _timesOfDay.map((t) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: t != _timesOfDay.last
                          ? AppConstants.paddingSM
                          : 0,
                    ),
                    child: _Pill(
                      label: t.$2,
                      selected: _selectedTimeOfDay == t.$1,
                      onTap: () => _onTimeOfDayTap(t.$1),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppConstants.paddingLG),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canConfirm ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      palette.primary.withValues(alpha: 0.3),
                  padding:
                      const EdgeInsets.symmetric(vertical: AppConstants.paddingMD),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusLG),
                  ),
                ),
                child: Text(
                  'Buscar',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMD,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? palette.primary
              : palette.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          border: Border.all(
            color: selected
                ? palette.primary
                : Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : palette.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : palette.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

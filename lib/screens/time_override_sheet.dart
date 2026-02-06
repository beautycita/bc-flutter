import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
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
    ('tomorrow', 'Mañana'),
    ('this_week', 'Esta semana'),
    ('next_week', 'Próx. semana'),
  ];

  static const _timesOfDay = [
    ('morning', 'Mañana'),
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
                  primary: BeautyCitaTheme.primaryRose,
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
    return Container(
      decoration: const BoxDecoration(
        color: BeautyCitaTheme.backgroundWhite,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BeautyCitaTheme.radiusXL),
        ),
      ),
      padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
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
                  color: BeautyCitaTheme.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: BeautyCitaTheme.spaceLG),

            // Title
            Text(
              '¿Cuándo prefieres?',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: BeautyCitaTheme.textDark,
              ),
            ),
            const SizedBox(height: BeautyCitaTheme.spaceLG),

            // Day range pills
            Wrap(
              spacing: BeautyCitaTheme.spaceSM,
              runSpacing: BeautyCitaTheme.spaceSM,
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
            const SizedBox(height: BeautyCitaTheme.spaceLG),

            // Time of day
            Text(
              'Horario:',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: BeautyCitaTheme.textLight,
              ),
            ),
            const SizedBox(height: BeautyCitaTheme.spaceSM),
            Row(
              children: _timesOfDay.map((t) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: t != _timesOfDay.last
                          ? BeautyCitaTheme.spaceSM
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
            const SizedBox(height: BeautyCitaTheme.spaceLG),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canConfirm ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BeautyCitaTheme.primaryRose,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      BeautyCitaTheme.primaryRose.withValues(alpha: 0.3),
                  padding:
                      const EdgeInsets.symmetric(vertical: BeautyCitaTheme.spaceMD),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(BeautyCitaTheme.radiusLarge),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: BeautyCitaTheme.spaceMD,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? BeautyCitaTheme.primaryRose
              : BeautyCitaTheme.surfaceCream,
          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusLarge),
          border: Border.all(
            color: selected
                ? BeautyCitaTheme.primaryRose
                : BeautyCitaTheme.dividerLight,
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
                color: selected ? Colors.white : BeautyCitaTheme.textLight,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : BeautyCitaTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

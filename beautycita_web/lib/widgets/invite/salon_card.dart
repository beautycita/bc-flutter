import 'package:flutter/material.dart';

/// Desktop salon card for the invite list.
///
/// Displays salon photo, name, city, rating, and distance in a compact row.
/// Hover lifts the card 2px with increased shadow. Selected state shows a
/// left gradient border and subtle pink tint.
class SalonCard extends StatefulWidget {
  const SalonCard({
    required this.salon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Map<String, dynamic> salon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<SalonCard> createState() => _SalonCardState();
}

class _SalonCardState extends State<SalonCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = widget.salon['name'] as String? ?? '';
    final city = widget.salon['city'] as String? ?? '';
    final photoUrl = widget.salon['photo_url'] as String?;
    final rating = (widget.salon['rating'] as num?)?.toDouble();
    final distance = widget.salon['distance'] as String?;

    const brandPink = Color(0xFFec4899);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hovering ? -2 : 0, 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.selected
                    ? brandPink.withValues(alpha: 0.04)
                    : colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: widget.selected ? brandPink : Colors.transparent,
                    width: widget.selected ? 3 : 0,
                  ),
                  top: BorderSide(color: colors.outlineVariant, width: 1),
                  right: BorderSide(color: colors.outlineVariant, width: 1),
                  bottom: BorderSide(color: colors.outlineVariant, width: 1),
                ),
                boxShadow: _hovering
                    ? [
                        BoxShadow(
                          color: colors.onSurface.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: colors.onSurface.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  // Photo / placeholder
                  _SalonAvatar(photoUrl: photoUrl, name: name),
                  const SizedBox(width: 12),
                  // Name + city
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (city.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            city,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              color: colors.onSurface.withValues(alpha: 0.55),
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Rating + distance
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      if (distance != null) ...[
                        const SizedBox(height: 4),
                        _DistancePill(distance: distance),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 64x64 rounded salon photo, or gradient placeholder with first letter.
class _SalonAvatar extends StatelessWidget {
  const _SalonAvatar({required this.photoUrl, required this.name});

  final String? photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        height: 64,
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(letter),
              )
            : _placeholder(letter),
      ),
    );
  }

  Widget _placeholder(String letter) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFec4899), Color(0xFF9333ea)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Small rounded pill showing distance text.
class _DistancePill extends StatelessWidget {
  const _DistancePill({required this.distance});

  final String distance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        distance,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

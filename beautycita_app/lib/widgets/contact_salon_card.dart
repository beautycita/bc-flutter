import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/contact_match_provider.dart';

/// Compact card for a contact-matched salon, designed for horizontal scroll.
class ContactSalonCard extends StatelessWidget {
  final EnrichedMatch match;

  const ContactSalonCard({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRegistered = match.salonType == 'r';

    return InkWell(
      onTap: () => _onCardTap(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Salon photo / placeholder
            _buildAvatar(context),
            const SizedBox(width: 10),

            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    match.contactName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    match.salonName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (match.salonCity != null) ...[
                        Icon(Icons.location_on,
                            size: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            match.salonCity!,
                            style: TextStyle(
                                fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (match.salonRating != null) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.star_rounded,
                            size: 12, color: Colors.amber[600]),
                        const SizedBox(width: 1),
                        Text(
                          match.salonRating!.toStringAsFixed(1),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Action button
            _buildActionButton(context, isRegistered),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final photoUrl = match.salonPhoto;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(photoUrl),
        backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
      );
    }

    // Gradient placeholder with first letter.
    final letter =
        match.salonName.isNotEmpty ? match.salonName[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 24,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFec4899), Color(0xFF9333ea)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, bool isRegistered) {
    if (isRegistered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFec4899), Color(0xFF9333ea)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Reservar',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF9333ea), width: 1.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Invitar',
        style: TextStyle(
          color: Color(0xFF9333ea),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _onCardTap(BuildContext context) {
    if (match.salonType == 'r') {
      context.push('/provider/${match.salonId}');
    } else {
      // Navigate to invite detail, passing salon data via extra.
      context.push('/invite/detail', extra: match.salon);
    }
  }
}

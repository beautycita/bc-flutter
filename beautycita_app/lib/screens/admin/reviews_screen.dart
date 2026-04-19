import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  int? _ratingFilter;
  String _search = '';

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> reviews) {
    var list = reviews;
    if (_ratingFilter != null) {
      list = list
          .where((r) => (r['rating'] as num?)?.toInt() == _ratingFilter)
          .toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((r) {
        final comment = (r['comment'] as String? ?? '').toLowerCase();
        final bizName =
            ((r['businesses'] as Map?)?['name'] as String? ?? '').toLowerCase();
        return comment.contains(q) || bizName.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(adminReviewsProvider);
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Stats bar
        reviewsAsync.when(
          data: (reviews) => _buildStatsBar(reviews),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('Error al cargar', style: TextStyle(color: Colors.red.shade400, fontSize: 13))),
          ),
        ),

        // Search + filter
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.paddingMD,
            AppConstants.paddingSM,
            AppConstants.paddingMD,
            AppConstants.paddingSM,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar en resenas...',
                    hintStyle: GoogleFonts.nunito(fontSize: 14),
                    prefixIcon: Icon(Icons.search, size: 20,
                        color: colors.primary.withValues(alpha: 0.5)),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                      borderSide: BorderSide(
                          color: colors.primary.withValues(alpha: 0.12)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                      borderSide: BorderSide(
                          color: colors.primary.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                      borderSide: BorderSide(
                          color: colors.primary.withValues(alpha: 0.5)),
                    ),
                  ),
                  style: GoogleFonts.nunito(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<int?>(
                icon: Icon(Icons.star_rounded,
                    color: _ratingFilter != null
                        ? colors.secondary
                        : colors.onSurface),
                onSelected: (v) => setState(() => _ratingFilter = v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: null, child: Text('Todas')),
                  for (var i = 5; i >= 1; i--)
                    PopupMenuItem(
                      value: i,
                      child: Row(
                        children: [
                          ...List.generate(
                              i,
                              (_) => const Icon(Icons.star_rounded,
                                  size: 16, color: Color(0xFFFFB300))),
                          ...List.generate(
                              5 - i,
                              (_) => Icon(Icons.star_border_rounded,
                                  size: 16,
                                  color: Colors.grey.withValues(alpha: 0.3))),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Rating filter chip
        if (_ratingFilter != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD),
            child: Row(
              children: [
                Chip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                        _ratingFilter!,
                        (_) => const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFFFB300))),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _ratingFilter = null),
                  backgroundColor:
                      colors.secondary.withValues(alpha: 0.1),
                  side: BorderSide(
                      color: colors.secondary.withValues(alpha: 0.2)),
                ),
              ],
            ),
          ),

        // Reviews list
        Expanded(
          child: reviewsAsync.when(
            data: (reviews) {
              final filtered = _filtered(reviews);
              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rate_review_rounded, size: 48,
                          color: colors.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'Sin resenas',
                        style: GoogleFonts.nunito(color: colors.onSurface),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                color: colors.primary,
                onRefresh: () async => ref.invalidate(adminReviewsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingMD),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _buildReviewCard(filtered[i]),
                ),
              );
            },
            loading: () => Center(
                child: CircularProgressIndicator(
                    color: colors.primary)),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: GoogleFonts.nunito(color: Colors.red)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(List<Map<String, dynamic>> reviews) {
    if (reviews.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final total = reviews.length;
    final avgRating = reviews.fold(0.0,
            (sum, r) => sum + ((r['rating'] as num?)?.toDouble() ?? 0)) /
        total;
    final fiveStars = reviews.where((r) => (r['rating'] as num?) == 5).length;
    final oneStars = reviews.where((r) => (r['rating'] as num?) == 1).length;

    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMD),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _statItem('Total', '$total', const Color(0xFFF8BBD0)),
          _statDivider(),
          _statItem('Promedio', avgRating.toStringAsFixed(1), const Color(0xFFFFF9C4)),
          _statDivider(),
          _statItem('5 est.', '$fiveStars', const Color(0xFFC8E6C9)),
          _statDivider(),
          _statItem('1 est.', '$oneStars', const Color(0xFFFFCDD2)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color bgColor) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 1,
      height: 30,
      color: colors.primary.withValues(alpha: 0.08),
    );
  }

  void _showReviewDetail(Map<String, dynamic> review) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) {
          final bizData = review['businesses'] as Map<String, dynamic>?;
          final tags = review['review_tags'];
          String tagsStr = '—';
          if (tags != null) {
            if (tags is List) {
              tagsStr = tags.join(', ');
            } else {
              tagsStr = tags.toString();
            }
          }
          final rawDate = review['created_at'] as String? ?? '';
          String dateStr = rawDate;
          final dtParsed = DateTime.tryParse(rawDate)?.toLocal();
          if (dtParsed != null) {
            dateStr = '${dtParsed.day}/${dtParsed.month}/${dtParsed.year} '
                '${dtParsed.hour.toString().padLeft(2, '0')}:'
                '${dtParsed.minute.toString().padLeft(2, '0')}';
          }
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Detalle Resena',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _ReviewDetailRow('ID', review['id']?.toString()),
              _ReviewDetailRow('Calificacion', review['rating']?.toString()),
              _ReviewDetailRow('Comentario', review['comment'] as String?),
              _ReviewDetailRow('Tipo de servicio', review['service_type'] as String?),
              _ReviewDetailRow('Negocio', bizData?['name'] as String?),
              _ReviewDetailRow('Negocio ID', review['business_id']?.toString()),
              _ReviewDetailRow('Usuario ID', review['user_id']?.toString()),
              _ReviewDetailRow('Creado', dateStr),
              _ReviewDetailRow('Visible', review['is_visible']?.toString()),
              _ReviewDetailRow('Etiquetas', tagsStr),
              if (bizData != null) ...[
                const Divider(height: 24),
                Text('Datos del negocio',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600,
                        color: Colors.grey[600])),
                const SizedBox(height: 8),
                ...bizData.entries.map(
                  (e) => _ReviewDetailRow(e.key, e.value?.toString()),
                ),
              ],
              // Dump all raw keys not already shown above
              const Divider(height: 24),
              Text('Todos los campos',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600,
                      color: Colors.grey[600])),
              const SizedBox(height: 8),
              ...review.entries
                  .where((e) => e.key != 'businesses')
                  .map((e) => _ReviewDetailRow(e.key, e.value?.toString())),
            ],
          );
        },
      ),
    );
  }

  Widget _ReviewDetailRow(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value ?? '—',
            style: GoogleFonts.nunito(fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final colors = Theme.of(context).colorScheme;
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final comment = review['comment'] as String? ?? '';
    final rawDate = review['created_at'] as String? ?? '';
    final dtParsed = DateTime.tryParse(rawDate)?.toLocal();
    final date = dtParsed != null
        ? '${dtParsed.day}/${dtParsed.month}/${dtParsed.year}'
        : rawDate.split('T')[0];
    final bizData = review['businesses'] as Map<String, dynamic>?;
    final bizName = bizData?['name'] as String? ?? 'Salon desconocido';

    return GestureDetector(
      onTap: () => _showReviewDetail(review),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: stars + date
          Row(
            children: [
              ...List.generate(5, (i) => Icon(
                i < rating.round()
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 18,
                color: colors.secondary,
              )),
              const SizedBox(width: 8),
              Text(
                rating.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                date,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Business name
          Row(
            children: [
              Icon(Icons.store_rounded, size: 14,
                  color: colors.primary.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bizName,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Comment
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: colors.onSurface,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    ),
    );
  }
}

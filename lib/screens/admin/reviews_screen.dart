import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
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

    return Column(
      children: [
        // Stats bar
        reviewsAsync.when(
          data: (reviews) => _buildStatsBar(reviews),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
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
                        color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.5)),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                      borderSide: BorderSide(
                          color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.12)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                      borderSide: BorderSide(
                          color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                      borderSide: BorderSide(
                          color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.5)),
                    ),
                  ),
                  style: GoogleFonts.nunito(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<int?>(
                icon: Icon(Icons.star_rounded,
                    color: _ratingFilter != null
                        ? BeautyCitaTheme.secondaryGold
                        : BeautyCitaTheme.textLight),
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
                      BeautyCitaTheme.secondaryGold.withValues(alpha: 0.1),
                  side: BorderSide(
                      color: BeautyCitaTheme.secondaryGold.withValues(alpha: 0.2)),
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
                          color: BeautyCitaTheme.textLight.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'Sin resenas',
                        style: GoogleFonts.nunito(color: BeautyCitaTheme.textLight),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                color: BeautyCitaTheme.primaryRose,
                onRefresh: () async => ref.invalidate(adminReviewsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingMD),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _buildReviewCard(filtered[i]),
                ),
              );
            },
            loading: () => const Center(
                child: CircularProgressIndicator(
                    color: BeautyCitaTheme.primaryRose)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.08)),
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
                color: BeautyCitaTheme.textDark,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: BeautyCitaTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 30,
      color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.08),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final comment = review['comment'] as String? ?? '';
    final rawDate = review['created_at'] as String? ?? '';
    final dtParsed = DateTime.tryParse(rawDate)?.toLocal();
    final date = dtParsed != null
        ? '${dtParsed.day}/${dtParsed.month}/${dtParsed.year}'
        : rawDate.split('T')[0];
    final bizData = review['businesses'] as Map<String, dynamic>?;
    final bizName = bizData?['name'] as String? ?? 'Salon desconocido';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.06),
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
                color: BeautyCitaTheme.secondaryGold,
              )),
              const SizedBox(width: 8),
              Text(
                rating.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BeautyCitaTheme.textDark,
                ),
              ),
              const Spacer(),
              Text(
                date,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: BeautyCitaTheme.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Business name
          Row(
            children: [
              Icon(Icons.store_rounded, size: 14,
                  color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bizName,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BeautyCitaTheme.primaryRose,
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
                color: BeautyCitaTheme.textDark,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/web_theme.dart';
import '../../providers/admin_salons_provider.dart';
import '../../services/csv_export.dart';
import '../../widgets/bc_data_table.dart';
import '../../widgets/bulk_action_bar.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/master_detail_layout.dart';
import '../../widgets/pagination_bar.dart';
import 'salon_detail_panel.dart';

/// Admin salons management page with two tabs:
/// "Registrados" (businesses table) and "Descubiertos" (discovered_salons table).
class SalonsPage extends ConsumerStatefulWidget {
  const SalonsPage({super.key});

  @override
  ConsumerState<SalonsPage> createState() => _SalonsPageState();
}

class _SalonsPageState extends ConsumerState<SalonsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Registered tab state
  RegisteredSalon? _selectedRegistered;
  Set<RegisteredSalon> _checkedRegistered = {};
  final _registeredSearchController = TextEditingController();

  // Discovered tab state
  DiscoveredSalon? _selectedDiscovered;
  Set<DiscoveredSalon> _checkedDiscovered = {};
  final _discoveredSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedRegistered = null;
          _selectedDiscovered = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _registeredSearchController.dispose();
    _discoveredSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        // ── Tab bar ─────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              bottom: BorderSide(color: colors.outlineVariant),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Registrados'),
              Tab(text: 'Descubiertos'),
            ],
            labelColor: colors.primary,
            unselectedLabelColor:
                colors.onSurface.withValues(alpha: 0.6),
            indicatorColor: colors.primary,
            indicatorSize: TabBarIndicatorSize.label,
          ),
        ),

        // ── Tab views ───────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _RegisteredTab(
                selectedSalon: _selectedRegistered,
                checkedSalons: _checkedRegistered,
                searchController: _registeredSearchController,
                onSelect: (s) =>
                    setState(() => _selectedRegistered = s),
                onCheckedChanged: (s) =>
                    setState(() => _checkedRegistered = s),
              ),
              _DiscoveredTab(
                selectedSalon: _selectedDiscovered,
                checkedSalons: _checkedDiscovered,
                searchController: _discoveredSearchController,
                onSelect: (s) =>
                    setState(() => _selectedDiscovered = s),
                onCheckedChanged: (s) =>
                    setState(() => _checkedDiscovered = s),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Registered salons tab ─────────────────────────────────────────────────────

class _RegisteredTab extends ConsumerWidget {
  const _RegisteredTab({
    required this.selectedSalon,
    required this.checkedSalons,
    required this.searchController,
    required this.onSelect,
    required this.onCheckedChanged,
  });

  final RegisteredSalon? selectedSalon;
  final Set<RegisteredSalon> checkedSalons;
  final TextEditingController searchController;
  final ValueChanged<RegisteredSalon?> onSelect;
  final ValueChanged<Set<RegisteredSalon>> onCheckedChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filter = ref.watch(registeredSalonsFilterProvider);
    final salonsAsync = ref.watch(registeredSalonsProvider);

    // Surface errors instead of hiding them
    if (salonsAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48,
                  color: colors.error.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('Error cargando salones',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(
                '${salonsAsync.error}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(registeredSalonsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final items = salonsAsync.valueOrNull?.salons ?? [];
    final totalCount = salonsAsync.valueOrNull?.totalCount ?? 0;
    final isLoading = salonsAsync.isLoading;
    final totalPages = (totalCount / filter.pageSize).ceil();

    return MasterDetailLayout<RegisteredSalon>(
      items: items,
      isLoading: isLoading,
      selectedItem: selectedSalon,
      onSelect: onSelect,
      detailTitle: selectedSalon?.name ?? 'Salon',
      detailBuilder: (salon) =>
          RegisteredSalonDetailContent(salon: salon),
      filterBar: FilterBar(
        searchField: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Buscar salon...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BCSpacing.sm,
              vertical: BCSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(BCSpacing.radiusXs),
            ),
            suffixIcon: filter.searchText.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      searchController.clear();
                      ref
                          .read(registeredSalonsFilterProvider.notifier)
                          .state = filter.copyWith(
                        searchText: '',
                        page: 0,
                      );
                    },
                  )
                : null,
          ),
          onChanged: (value) => setRegisteredSearch(ref, value),
        ),
        filters: [
          _SalonFilterDropdown(
            value: filter.city,
            hint: 'Ciudad',
            items: const {
              null: 'Todas',
              'Puerto Vallarta': 'Puerto Vallarta',
              'Guadalajara': 'Guadalajara',
              'Cabo San Lucas': 'Cabo San Lucas',
              'Ciudad de Mexico': 'CDMX',
              'Monterrey': 'Monterrey',
            },
            onChanged: (value) {
              ref.read(registeredSalonsFilterProvider.notifier).state =
                  filter.copyWith(city: () => value, page: 0);
            },
          ),
          _SalonFilterDropdown(
            value: filter.verified == null
                ? null
                : (filter.verified! ? 'true' : 'false'),
            hint: 'Verificacion',
            items: const {
              null: 'Todos',
              'true': 'Verificados',
              'false': 'No verificados',
            },
            onChanged: (value) {
              ref.read(registeredSalonsFilterProvider.notifier).state =
                  filter.copyWith(
                verified: () =>
                    value == null ? null : value == 'true',
                page: 0,
              );
            },
          ),
          _SalonFilterDropdown(
            value: filter.bankingComplete == null
                ? null
                : (filter.bankingComplete! ? 'true' : 'false'),
            hint: 'Banca',
            items: const {
              null: 'Todos',
              'true': 'Banca completa',
              'false': 'Banca pendiente',
            },
            onChanged: (value) {
              ref.read(registeredSalonsFilterProvider.notifier).state =
                  filter.copyWith(
                bankingComplete: () =>
                    value == null ? null : value == 'true',
                page: 0,
              );
            },
          ),
        ],
        onClearAll: filter.hasActiveFilters
            ? () {
                searchController.clear();
                ref.read(registeredSalonsFilterProvider.notifier).state =
                    const SalonsFilter();
              }
            : null,
      ),
      table: BCDataTable<RegisteredSalon>(
        columns: [
          BCColumn<RegisteredSalon>(
            id: 'name',
            label: 'Nombre',
            sortable: true,
            cellBuilder: (salon) => Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      colors.primary.withValues(alpha: 0.1),
                  backgroundImage: salon.photoUrl != null
                      ? NetworkImage(salon.photoUrl!)
                      : null,
                  child: salon.photoUrl == null
                      ? Icon(Icons.store, size: 14, color: colors.primary)
                      : null,
                ),
                const SizedBox(width: BCSpacing.sm),
                Flexible(
                  child: Text(
                    salon.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          BCColumn<RegisteredSalon>(
            id: 'city',
            label: 'Ciudad',
            sortable: true,
            cellBuilder: (salon) => Text(
              salon.city ?? '-',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BCColumn<RegisteredSalon>(
            id: 'phone',
            label: 'Telefono',
            cellBuilder: (salon) => Text(
              salon.phone ?? '-',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BCColumn<RegisteredSalon>(
            id: 'average_rating',
            label: 'Rating',
            sortable: true,
            width: 80,
            cellBuilder: (salon) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 2),
                Text(
                  salon.rating > 0
                      ? '${salon.rating.toStringAsFixed(1)} (${salon.totalReviews})'
                      : '-',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          BCColumn<RegisteredSalon>(
            id: 'tier',
            label: 'Tier',
            width: 60,
            cellBuilder: (salon) => Text(
              'T${salon.tier}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          BCColumn<RegisteredSalon>(
            id: 'stripe_onboarding_status',
            label: 'Stripe',
            width: 100,
            cellBuilder: (salon) => _StripeChip(
              status: salon.stripeStatus,
            ),
          ),
          BCColumn<RegisteredSalon>(
            id: 'banking_complete',
            label: 'Banca',
            width: 90,
            cellBuilder: (salon) => _BankingChip(
              bankingComplete: salon.bankingComplete,
              idStatus: salon.idVerificationStatus,
            ),
          ),
          BCColumn<RegisteredSalon>(
            id: 'is_verified',
            label: 'Verificado',
            width: 70,
            cellBuilder: (salon) => Icon(
              salon.verified
                  ? Icons.verified
                  : Icons.remove_circle_outline,
              size: 18,
              color: salon.verified ? Colors.green : Colors.grey,
            ),
          ),
        ],
        items: items,
        selectedItems: checkedSalons,
        selectedItem: selectedSalon,
        isLoading: isLoading,
        sortColumn: filter.sortColumn,
        sortAscending: filter.sortAscending,
        onRowTap: (salon) => onSelect(salon),
        onSelectionChanged: onCheckedChanged,
        onSort: (column) {
          final ascending =
              filter.sortColumn == column ? !filter.sortAscending : true;
          ref.read(registeredSalonsFilterProvider.notifier).state =
              filter.copyWith(
            sortColumn: () => column,
            sortAscending: ascending,
          );
        },
        emptyIcon: Icons.store_outlined,
        emptyTitle: 'No hay salones registrados',
        emptySubtitle: filter.hasActiveFilters
            ? 'Intenta con otros filtros'
            : null,
      ),
      bulkActionBar: checkedSalons.isNotEmpty
          ? BulkActionBar(
              selectedCount: checkedSalons.length,
              onClearSelection: () => onCheckedChanged({}),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    final salons = checkedSalons.toList();
                    if (salons.isEmpty) return;
                    final csv = generateCsv(
                      headers: [
                        'id', 'name', 'phone', 'city', 'state',
                        'is_active', 'is_verified', 'tier',
                        'stripe_status', 'rating', 'total_reviews',
                        'created_at',
                      ],
                      rows: salons.map((s) => [
                        s.id,
                        s.name,
                        s.phone ?? '',
                        s.city ?? '',
                        s.state ?? '',
                        s.isActive.toString(),
                        s.verified.toString(),
                        s.tier.toString(),
                        s.stripeStatus,
                        s.rating.toStringAsFixed(1),
                        s.totalReviews.toString(),
                        s.createdAt.toIso8601String(),
                      ]).toList(),
                    );
                    downloadCsv(csv, 'salones_${DateTime.now().millisecondsSinceEpoch}.csv');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${salons.length} salones exportados'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Exportar'),
                ),
              ],
            )
          : null,
      pagination: totalPages > 1
          ? PaginationBar(
              currentPage: filter.page,
              totalPages: totalPages,
              totalItems: totalCount,
              pageSize: filter.pageSize,
              onPageChanged: (page) {
                ref
                    .read(registeredSalonsFilterProvider.notifier)
                    .state = filter.copyWith(page: page);
              },
              onPageSizeChanged: (size) {
                ref
                    .read(registeredSalonsFilterProvider.notifier)
                    .state = filter.copyWith(pageSize: size, page: 0);
              },
            )
          : null,
    );
  }
}

// ── Discovered salons tab ─────────────────────────────────────────────────────

class _DiscoveredTab extends ConsumerWidget {
  const _DiscoveredTab({
    required this.selectedSalon,
    required this.checkedSalons,
    required this.searchController,
    required this.onSelect,
    required this.onCheckedChanged,
  });

  final DiscoveredSalon? selectedSalon;
  final Set<DiscoveredSalon> checkedSalons;
  final TextEditingController searchController;
  final ValueChanged<DiscoveredSalon?> onSelect;
  final ValueChanged<Set<DiscoveredSalon>> onCheckedChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filter = ref.watch(discoveredSalonsFilterProvider);
    final salonsAsync = ref.watch(discoveredSalonsProvider);
    // Surface errors
    if (salonsAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48,
                  color: colors.error.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('Error cargando salones descubiertos',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(
                '${salonsAsync.error}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(discoveredSalonsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final items = salonsAsync.valueOrNull?.salons ?? [];
    final totalCount = salonsAsync.valueOrNull?.totalCount ?? 0;
    final isLoading = salonsAsync.isLoading;
    final totalPages = (totalCount / filter.pageSize).ceil();

    return MasterDetailLayout<DiscoveredSalon>(
      items: items,
      isLoading: isLoading,
      selectedItem: selectedSalon,
      onSelect: onSelect,
      detailTitle: selectedSalon?.name ?? 'Salon descubierto',
      detailBuilder: (salon) =>
          DiscoveredSalonDetailContent(salon: salon),
      filterBar: FilterBar(
        searchField: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Buscar salon...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BCSpacing.sm,
              vertical: BCSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(BCSpacing.radiusXs),
            ),
            suffixIcon: filter.searchText.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      searchController.clear();
                      ref
                          .read(discoveredSalonsFilterProvider.notifier)
                          .state = filter.copyWith(
                        searchText: '',
                        page: 0,
                      );
                    },
                  )
                : null,
          ),
          onChanged: (value) => setDiscoveredSearch(ref, value),
        ),
        filters: [
          _CountryFilterDropdown(
            value: filter.country,
            onChanged: (value) {
              ref.read(discoveredSalonsFilterProvider.notifier).state =
                  filter.copyWith(
                country: () => value,
                city: () => null,
                page: 0,
              );
            },
          ),
          _CityFilterDropdown(
            value: filter.city,
            country: filter.country,
            onChanged: (value) {
              ref.read(discoveredSalonsFilterProvider.notifier).state =
                  filter.copyWith(city: () => value, page: 0);
            },
          ),
          _StateFilterDropdown(
            value: filter.state,
            country: filter.country,
            onChanged: (value) {
              ref.read(discoveredSalonsFilterProvider.notifier).state =
                  filter.copyWith(state: () => value, city: () => null, page: 0);
            },
          ),
          _SalonFilterDropdown(
            value: filter.source,
            hint: 'Fuente',
            items: const {
              null: 'Todas',
              'google_maps': 'Google Maps',
              'denue': 'DENUE',
              'facebook': 'Facebook',
              'bing': 'Bing',
              'manual': 'Manual',
            },
            onChanged: (value) {
              ref.read(discoveredSalonsFilterProvider.notifier).state =
                  filter.copyWith(source: () => value, page: 0);
            },
          ),
          _SalonFilterDropdown(
            value: filter.enrichmentFilter,
            hint: 'Enrichment',
            items: const {
              null: 'Todos',
              'ig_enriched': 'IG Enriched',
              'wa_verified': 'WA Verified',
              'wa_checked': 'WA Checked',
              'has_website': 'Has Website',
              'has_ig': 'Has IG URL',
              'has_booking': 'Has Booking System',
              'not_enriched': 'Not Enriched',
            },
            onChanged: (value) {
              ref.read(discoveredSalonsFilterProvider.notifier).state =
                  filter.copyWith(enrichmentFilter: () => value, page: 0);
            },
          ),
        ],
        onClearAll: filter.hasActiveFilters
            ? () {
                searchController.clear();
                ref.read(discoveredSalonsFilterProvider.notifier).state =
                    const SalonsFilter();
              }
            : null,
      ),
      table: BCDataTable<DiscoveredSalon>(
        columns: [
          BCColumn<DiscoveredSalon>(
            id: 'name',
            label: 'Nombre',
            sortable: true,
            cellBuilder: (salon) => Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      colors.secondary.withValues(alpha: 0.1),
                  backgroundImage: salon.photoUrl != null
                      ? NetworkImage(salon.photoUrl!)
                      : null,
                  child: salon.photoUrl == null
                      ? Icon(Icons.store, size: 14, color: colors.secondary)
                      : null,
                ),
                const SizedBox(width: BCSpacing.sm),
                Flexible(
                  child: Text(
                    salon.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          BCColumn<DiscoveredSalon>(
            id: 'location_city',
            label: 'Ciudad',
            sortable: true,
            cellBuilder: (salon) => Text(
              salon.city ?? '-',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BCColumn<DiscoveredSalon>(
            id: 'rating_average',
            label: 'Rating',
            sortable: true,
            width: 90,
            cellBuilder: (salon) => salon.rating != null && salon.rating! > 0
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        '${salon.rating!.toStringAsFixed(1)} (${salon.reviewCount ?? 0})',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  )
                : Text('-', style: theme.textTheme.bodySmall),
          ),
          BCColumn<DiscoveredSalon>(
            id: 'enrichment',
            label: 'Enrichment',
            width: 100,
            cellBuilder: (salon) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: salon.waStatus == 'valid'
                      ? 'WA verificado'
                      : salon.waStatus == 'invalid'
                          ? 'WA invalido'
                          : 'WA no checado',
                  child: Icon(
                    Icons.chat,
                    size: 14,
                    color: salon.waStatus == 'valid'
                        ? Colors.green
                        : salon.waStatus == 'invalid'
                            ? Colors.red
                            : Colors.grey.shade300,
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: salon.isIgEnriched
                      ? 'IG enriquecido (${salon.igFollowers ?? 0} followers)'
                      : salon.instagramUrl != null
                          ? 'Tiene IG, pendiente enrichment'
                          : 'Sin IG',
                  child: Icon(
                    Icons.camera_alt,
                    size: 14,
                    color: salon.isIgEnriched
                        ? Colors.purple
                        : salon.instagramUrl != null
                            ? Colors.orange
                            : Colors.grey.shade300,
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: salon.website != null ? 'Tiene web' : 'Sin web',
                  child: Icon(
                    Icons.language,
                    size: 14,
                    color: salon.website != null
                        ? Colors.blue
                        : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          BCColumn<DiscoveredSalon>(
            id: 'phone',
            label: 'Telefono',
            cellBuilder: (salon) => Text(
              salon.phone ?? '-',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BCColumn<DiscoveredSalon>(
            id: 'source',
            label: 'Fuente',
            width: 90,
            cellBuilder: (salon) => _SourceChip(
              source: salon.source,
            ),
          ),
          BCColumn<DiscoveredSalon>(
            id: 'interest_signals',
            label: 'Senales',
            sortable: true,
            width: 70,
            cellBuilder: (salon) => Text(
              '${salon.interestSignals}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          BCColumn<DiscoveredSalon>(
            id: 'booking_system',
            label: 'Booking',
            width: 80,
            cellBuilder: (salon) => salon.bookingSystem != null
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(BCSpacing.radiusFull),
                    ),
                    child: Text(
                      salon.bookingSystem!,
                      style: const TextStyle(
                        color: Colors.deepPurple,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
        items: items,
        selectedItems: checkedSalons,
        selectedItem: selectedSalon,
        isLoading: isLoading,
        sortColumn: filter.sortColumn,
        sortAscending: filter.sortAscending,
        onRowTap: (salon) => onSelect(salon),
        onSelectionChanged: onCheckedChanged,
        onSort: (column) {
          final ascending =
              filter.sortColumn == column ? !filter.sortAscending : true;
          ref.read(discoveredSalonsFilterProvider.notifier).state =
              filter.copyWith(
            sortColumn: () => column,
            sortAscending: ascending,
          );
        },
        emptyIcon: Icons.explore_outlined,
        emptyTitle: 'No hay salones descubiertos',
        emptySubtitle: filter.hasActiveFilters
            ? 'Intenta con otros filtros'
            : null,
      ),
      bulkActionBar: checkedSalons.isNotEmpty
          ? BulkActionBar(
              selectedCount: checkedSalons.length,
              onClearSelection: () => onCheckedChanged({}),
              actions: [
                TextButton.icon(
                  onPressed: () => _sendBulkWaInvites(
                    context,
                    ref,
                    checkedSalons.toList(),
                    onCheckedChanged,
                  ),
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Enviar WA'),
                ),
              ],
            )
          : null,
      pagination: totalPages > 1
          ? PaginationBar(
              currentPage: filter.page,
              totalPages: totalPages,
              totalItems: totalCount,
              pageSize: filter.pageSize,
              onPageChanged: (page) {
                ref
                    .read(discoveredSalonsFilterProvider.notifier)
                    .state = filter.copyWith(page: page);
              },
              onPageSizeChanged: (size) {
                ref
                    .read(discoveredSalonsFilterProvider.notifier)
                    .state = filter.copyWith(pageSize: size, page: 0);
              },
            )
          : null,
    );
  }

  /// Show a progress dialog and send WA invites to each selected salon.
  Future<void> _sendBulkWaInvites(
    BuildContext context,
    WidgetRef ref,
    List<DiscoveredSalon> salons,
    ValueChanged<Set<DiscoveredSalon>> onCheckedChanged,
  ) async {
    final total = salons.length;
    int sent = 0;
    int failed = 0;
    bool started = false;

    // Show a modal progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Kick off the sends once on first build
            if (!started) {
              started = true;
              () async {
                for (final salon in salons) {
                  try {
                    await BCSupabase.client.functions.invoke(
                      'outreach-discovered-salon',
                      body: {
                        'action': 'invite',
                        'discovered_salon_id': salon.id,
                      },
                    );
                    sent++;
                  } catch (e) {
                    failed++;
                  }
                  if (ctx.mounted) {
                    setDialogState(() {});
                  }
                }
                // All done — close dialog, show result
                if (ctx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
                if (context.mounted) {
                  ref.invalidate(discoveredSalonsProvider);
                  onCheckedChanged({});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        failed == 0
                            ? '$sent invitaciones enviadas'
                            : '$sent enviadas, $failed fallidas',
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }();
            }

            final progress = sent + failed;
            return AlertDialog(
              title: const Text('Enviando invitaciones WA'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: total > 0 ? progress / total : 0,
                  ),
                  const SizedBox(height: 12),
                  Text('Enviando $progress/$total...'),
                  if (failed > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '$failed fallidas',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Chip widgets ──────────────────────────────────────────────────────────────

class _StripeChip extends StatelessWidget {
  const _StripeChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'complete' => ('OK', Colors.green),
      'pending' || 'pending_verification' => ('Pendiente', Colors.orange),
      'not_started' => ('Sin iniciar', kWebTextHint),
      _ => (status, kWebTextHint),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BankingChip extends StatelessWidget {
  const _BankingChip({required this.bankingComplete, required this.idStatus});
  final bool bankingComplete;
  final String idStatus;

  @override
  Widget build(BuildContext context) {
    final (label, color) = bankingComplete
        ? ('Completa', Colors.green)
        : switch (idStatus) {
            'pending' => ('Verificando', Colors.orange),
            'rejected' => ('Rechazada', Colors.red),
            _ => ('Pendiente', kWebTextHint),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({this.source});
  final String? source;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      'google_maps' => ('Google', kWebTertiary),
      'facebook' => ('Facebook', Colors.indigo),
      'bing' => ('Bing', Colors.teal),
      _ => (source ?? '-', kWebTextHint),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Filter dropdown ───────────────────────────────────────────────────────────

class _SalonFilterDropdown extends StatelessWidget {
  const _SalonFilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final Map<String?, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BCSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          hint: Text(hint, style: theme.textTheme.bodySmall),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface,
          ),
          items: items.entries
              .map((e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value),
                  ))
              .toList(),
          onChanged: (v) => onChanged(v),
        ),
      ),
    );
  }
}

// ── Country filter ───────────────────────────────────────────────────────────

class _CountryFilterDropdown extends StatelessWidget {
  const _CountryFilterDropdown({
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SalonFilterDropdown(
      value: value,
      hint: 'Pais',
      items: const {
        null: 'Todos',
        'MX': 'Mexico',
        'US': 'Estados Unidos',
      },
      onChanged: onChanged,
    );
  }
}

// ── City filter with country grouping ────────────────────────────────────────

class _CityFilterDropdown extends StatelessWidget {
  const _CityFilterDropdown({
    required this.value,
    required this.country,
    required this.onChanged,
  });

  final String? value;
  final String? country;
  final ValueChanged<String?> onChanged;

  // Cities organized by country
  static const _mxCities = [
    'Acapulco',
    'Aguascalientes',
    'Bahia de Banderas',
    'Cabo San Lucas',
    'Campeche',
    'Cancun',
    'Chetumal',
    'Chihuahua',
    'Ciudad de Mexico',
    'Colima',
    'Cuernavaca',
    'Culiacan',
    'Durango',
    'Guadalajara',
    'Guanajuato',
    'Hermosillo',
    'La Paz',
    'Leon',
    'Mazatlan',
    'Merida',
    'Mexicali',
    'Monterrey',
    'Morelia',
    'Oaxaca',
    'Pachuca',
    'Playa del Carmen',
    'Puebla',
    'Puerto Vallarta',
    'Queretaro',
    'Reynosa',
    'Saltillo',
    'San Jose del Cabo',
    'San Luis Potosi',
    'Tampico',
    'Taxco',
    'Tepic',
    'Tijuana',
    'Tlaquepaque',
    'Toluca',
    'Tonala',
    'Torreon',
    'Tuxtla Gutierrez',
    'Veracruz',
    'Villahermosa',
    'Zacatecas',
    'Zapopan',
  ];

  static const _usCities = [
    'Austin',
    'Charlotte',
    'Columbus',
    'Dallas',
    'Houston',
    'Jacksonville',
    'New York',
    'Philadelphia',
    'Phoenix',
    'San Antonio',
    'San Diego',
    'San Jose',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );

    // Build menu items based on selected country
    final items = <DropdownMenuItem<String?>>[];
    items.add(const DropdownMenuItem(value: null, child: Text('Todas')));

    if (country == null || country == 'MX') {
      items.add(DropdownMenuItem(
        enabled: false,
        value: '__mx_header__',
        child: Text('MEXICO', style: headerStyle),
      ));
      for (final city in _mxCities) {
        items.add(DropdownMenuItem(
          value: city,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(city),
          ),
        ));
      }
    }

    if (country == null || country == 'US') {
      items.add(DropdownMenuItem(
        enabled: false,
        value: '__us_header__',
        child: Text('ESTADOS UNIDOS', style: headerStyle),
      ));
      for (final city in _usCities) {
        items.add(DropdownMenuItem(
          value: city,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(city),
          ),
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BCSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          hint: Text('Ciudad', style: theme.textTheme.bodySmall),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface,
          ),
          menuMaxHeight: 400,
          items: items,
          onChanged: (v) {
            if (v != null && v.startsWith('__')) return;
            onChanged(v);
          },
        ),
      ),
    );
  }
}

class _StateFilterDropdown extends StatelessWidget {
  const _StateFilterDropdown({
    required this.value,
    required this.country,
    required this.onChanged,
  });

  final String? value;
  final String? country;
  final ValueChanged<String?> onChanged;

  static const _mxStates = [
    'Aguascalientes', 'Baja California', 'Baja California Sur', 'Campeche',
    'Chiapas', 'Chihuahua', 'Ciudad de Mexico', 'Coahuila', 'Colima',
    'Durango', 'Guanajuato', 'Guerrero', 'Hidalgo', 'Jalisco',
    'Mexico', 'Michoacan', 'Morelos', 'Nayarit', 'Nuevo Leon',
    'Oaxaca', 'Puebla', 'Queretaro', 'Quintana Roo', 'San Luis Potosi',
    'Sinaloa', 'Sonora', 'Tabasco', 'Tamaulipas', 'Tlaxcala',
    'Veracruz', 'Yucatan', 'Zacatecas',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final items = <DropdownMenuItem<String?>>[];
    items.add(const DropdownMenuItem(value: null, child: Text('Todos')));

    final states = (country == null || country == 'MX') ? _mxStates : <String>[];
    for (final s in states) {
      items.add(DropdownMenuItem(value: s, child: Text(s)));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BCSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          hint: Text('Estado', style: theme.textTheme.bodySmall),
          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface),
          menuMaxHeight: 400,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

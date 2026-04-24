import 'package:beautycita/widgets/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:beautycita_core/models.dart' hide Provider;
import '../../config/constants.dart';
import '../../providers/product_provider.dart';
import '../../providers/business_provider.dart';
import '../../services/toast_service.dart';

class PosManagementScreen extends ConsumerWidget {
  const PosManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posAsync = ref.watch(posEnabledProvider);
    final agreementAsync = ref.watch(posAgreementProvider);

    return posAsync.when(
      data: (enabled) {
        if (!enabled) {
          return agreementAsync.when(
            data: (agreed) => _PosOptInView(agreedBefore: agreed),
            loading: () => const _LoadingBody(),
            error: (e, _) => _PosOptInView(agreedBefore: false),
          );
        }
        return const _PosContentView();
      },
      loading: () => const _LoadingBody(),
      error: (e, _) => _ErrorBody(message: e.toString()),
    );
  }
}

// ---------------------------------------------------------------------------
// Opt-in prompt
// ---------------------------------------------------------------------------

class _PosOptInView extends ConsumerStatefulWidget {
  final bool agreedBefore;
  const _PosOptInView({required this.agreedBefore});

  @override
  ConsumerState<_PosOptInView> createState() => _PosOptInViewState();
}

class _PosOptInViewState extends ConsumerState<_PosOptInView> {
  bool _agreed = false;
  bool _saving = false;

  Future<void> _activate() async {
    if (!_agreed) {
      ToastService.showWarning('Acepta los terminos para continuar');
      return;
    }
    setState(() => _saving = true);
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) throw Exception('Negocio no encontrado');
      final bizId = biz['id'] as String;
      final service = ref.read(productServiceProvider);
      await service.acceptAgreement(bizId, '1.1');
      await service.enablePos(bizId);
      ref.invalidate(posEnabledProvider);
      ref.invalidate(posAgreementProvider);
      ref.invalidate(currentBusinessProvider);
      ToastService.showSuccess('Punto de Venta activado');
    } catch (e, st) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, st);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        const SizedBox(height: AppConstants.paddingXL),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.storefront_outlined,
                size: 40, color: colors.primary),
          ),
        ),
        const SizedBox(height: AppConstants.paddingLG),
        Text(
          'Activa tu Punto de Venta',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF212121),
          ),
        ),
        const SizedBox(height: AppConstants.paddingSM),
        Text(
          'Vende tus productos directamente desde BeautyCita. '
          'Crea tu catalogo, publica productos en el Feed de Inspiracion '
          'y llega a nuevas clientas.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: const Color(0xFF757575),
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppConstants.paddingXL),
        _FeatureRow(
          icon: Icons.inventory_2_outlined,
          title: 'Catalogo de productos',
          subtitle: 'Administra precios, stock y fotos',
        ),
        const SizedBox(height: AppConstants.paddingMD),
        _FeatureRow(
          icon: Icons.auto_awesome_outlined,
          title: 'Feed de Inspiracion',
          subtitle: 'Publica productos para que te descubran',
        ),
        const SizedBox(height: AppConstants.paddingMD),
        _FeatureRow(
          icon: Icons.trending_up_rounded,
          title: 'Mas ingresos',
          subtitle: 'Complementa tus servicios con ventas',
        ),
        const SizedBox(height: AppConstants.paddingXL),
        // Agreement card
        Container(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(
              color: colors.onSurface.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terminos del Vendedor',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: AppConstants.paddingSM),
              Text(
                'Al activar el Punto de Venta aceptas que:\n\n'
                '1. Eres responsable de la veracidad de la información de tus productos, precios y disponibilidad.\n\n'
                '2. Solo puedes vender productos relacionados con belleza, cuidado personal y bienestar: '
                'cosmeticos, productos capilares, cuidado de piel, herramientas de estilismo, '
                'accesorios de belleza y productos de bienestar. Productos fuera de estas categorías '
                'serán removidos sin previo aviso.\n\n'
                '3. Está prohibido publicar productos falsificados, ilegales, '
                'medicamentos controlados o cualquier producto que infrinja derechos de propiedad intelectual.\n\n'
                '4. BeautyCita se reserva el derecho de remover productos que no cumplan con estas políticas '
                'y de desactivar permanentemente el acceso al Punto de Venta en caso de infracciones repetidas.\n\n'
                '5. Puedes desactivar tu Punto de Venta en cualquier momento desde esta pantalla.\n\n'
                '6. Comisiones y cargo de procesamiento: por cada venta POS, BeautyCita retiene 10% del precio del producto:\n'
                '    • 7% como comisión de plataforma, reembolsable en caso de devolución (no se cobra sobre el monto devuelto al cliente).\n'
                '    • 3% como cargo de procesamiento de transacciones de BeautyCita, no reembolsable bajo ninguna circunstancia. '
                'Este 3% es el mismo cargo universal de BeautyCita que aplica a toda transacción de la plataforma '
                '(reservas, ventas POS, devoluciones, cancelaciones, disputas) y cubre los costos operativos '
                'de procesar cada transacción.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: const Color(0xFF757575),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppConstants.paddingSM),
              CheckboxListTile(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'He leido y acepto los terminos del vendedor (v1.1)',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                ),
                activeColor: colors.primary,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.paddingLG),
        SizedBox(
          width: double.infinity,
          height: AppConstants.minTouchHeight,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _activate,
            icon: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.onPrimary),
                  )
                : const Icon(Icons.storefront_rounded),
            label: Text(
              'Activar Punto de Venta',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusLG),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.paddingXL),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          ),
          child: Icon(icon, size: 22, color: colors.primary),
        ),
        const SizedBox(width: AppConstants.paddingMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: const Color(0xFF757575),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Main POS content (product list + showcases)
// ---------------------------------------------------------------------------

class _PosContentView extends ConsumerWidget {
  const _PosContentView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(businessProductsProvider);
    final showcasesAsync = ref.watch(businessShowcasesProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductSheet(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Agregar',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      body: RefreshIndicator(
        color: colors.primary,
        backgroundColor: colors.surface,
        onRefresh: () async {
          ref.invalidate(businessProductsProvider);
          ref.invalidate(businessShowcasesProvider);
        },
        child: productsAsync.when(
          data: (products) => _ProductList(
            products: products,
            showcases: showcasesAsync.valueOrNull ?? [],
            onEdit: (p) => _showProductSheet(context, ref, p),
            onDelete: (p) => _confirmDelete(context, ref, p),
            onToggleStock: (p, v) => _toggleStock(ref, p, v),
            onShowcase: () => _showShowcaseSheet(context, ref, products),
            onDeactivate: () => _confirmDeactivate(context, ref),
          ),
          loading: () => const _LoadingBody(),
          error: (e, _) => _ErrorBody(message: e.toString()),
        ),
      ),
    );
  }

  Future<void> _toggleStock(WidgetRef ref, Product product, bool value) async {
    try {
      final service = ref.read(productServiceProvider);
      await service.toggleStock(product.id, value);
      ref.invalidate(businessProductsProvider);
    } catch (e, st) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, st);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Product product) async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        title: Text(
          'Eliminar producto',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '¿Eliminar "${product.name}"? Esta accion no se puede deshacer.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF757575))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              ),
            ),
            child: Text('Eliminar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      final service = ref.read(productServiceProvider);
      await service.deleteProduct(product.id);
      ref.invalidate(businessProductsProvider);
      ToastService.showSuccess('Producto eliminado');
      if (context.mounted) await showShredderTransition(context);
    } catch (e, st) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, st);
    }
  }

  void _showProductSheet(
      BuildContext context, WidgetRef ref, Product? product) {
    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductFormSheet(product: product, ref: ref),
    );
  }

  void _showShowcaseSheet(
      BuildContext context, WidgetRef ref, List<Product> products) {
    if (products.isEmpty) {
      ToastService.showInfo('Agrega productos primero');
      return;
    }
    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShowcaseSheet(products: products, ref: ref),
    );
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref) async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        title: Text('Desactivar Punto de Venta',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Tu catálogo y productos se conservarán pero no serán visibles '
          'para las clientas. Puedes reactivar el POS en cualquier momento.',
          style: GoogleFonts.nunito(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: colors.onPrimary,
            ),
            child: Text('Desactivar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) return;
      final bizId = biz['id'] as String;
      final service = ref.read(productServiceProvider);
      await service.disablePos(bizId);
      ref.invalidate(posEnabledProvider);
      ref.invalidate(currentBusinessProvider);
      ToastService.showSuccess('Punto de Venta desactivado');
    } catch (e, st) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, st);
    }
  }
}

// ---------------------------------------------------------------------------
// Product list body
// ---------------------------------------------------------------------------

class _ProductList extends StatelessWidget {
  final List<Product> products;
  final List<ProductShowcase> showcases;
  final void Function(Product) onEdit;
  final void Function(Product) onDelete;
  final void Function(Product, bool) onToggleStock;
  final VoidCallback onShowcase;
  final VoidCallback onDeactivate;

  const _ProductList({
    required this.products,
    required this.showcases,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStock,
    required this.onShowcase,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (products.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          const SizedBox(height: AppConstants.paddingXL),
          Center(
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 64,
                    color: colors.onSurface.withValues(alpha: 0.25)),
                const SizedBox(height: AppConstants.paddingLG),
                Text(
                  'Sin productos todavia',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSM),
                Text(
                  'Toca + Agregar para crear tu primer producto',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: const Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingMD,
        AppConstants.paddingMD,
        AppConstants.paddingMD,
        120, // room for FAB
      ),
      children: [
        // Showcase section header
        Row(
          children: [
            Expanded(
              child: Text(
                'Catalogo de Productos',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF212121),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onShowcase,
              icon: Icon(Icons.auto_awesome_outlined,
                  size: 16, color: colors.primary),
              label: Text(
                'Publicar en Feed',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ),
          ],
        ),
        if (showcases.isNotEmpty) ...[
          Text(
            '${showcases.length} publicacion${showcases.length == 1 ? '' : 'es'} activa${showcases.length == 1 ? '' : 's'}',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: const Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
        ] else ...[
          const SizedBox(height: AppConstants.paddingSM),
        ],
        ...products.map(
          (p) => _ProductCard(
            product: p,
            onTap: () => onEdit(p),
            onDelete: () => onDelete(p),
            onToggleStock: (v) => onToggleStock(p, v),
          ),
        ),
        const SizedBox(height: AppConstants.paddingXL),
        const Divider(),
        const SizedBox(height: AppConstants.paddingMD),
        Center(
          child: OutlinedButton.icon(
            onPressed: onDeactivate,
            icon: const Icon(Icons.power_settings_new, size: 18, color: Colors.red),
            label: Text('Desactivar Punto de Venta',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLG)),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.paddingMD),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Product card (swipe to delete, tap to edit)
// ---------------------------------------------------------------------------

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleStock;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onDelete,
    required this.onToggleStock,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final categoryLabel =
        Product.categories[product.category] ?? product.category;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      child: Dismissible(
        key: ValueKey(product.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppConstants.paddingLG),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          ),
          child: Icon(Icons.delete_outline_rounded,
              color: colors.onPrimary, size: 28),
        ),
        confirmDismiss: (_) async {
          onDelete();
          return false; // deletion is handled in parent to show confirm dialog
        },
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          child: Container(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.onSurface.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Thumbnail
                _ProductThumbnail(photoUrl: product.photoUrl),
                const SizedBox(width: AppConstants.paddingMD),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF212121),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.brand != null && product.brand!.isNotEmpty)
                        Text(
                          product.brand!,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: const Color(0xFF9E9E9E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusFull),
                            ),
                            child: Text(
                              categoryLabel,
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppConstants.paddingSM),
                          Text(
                            '\$${product.price.toStringAsFixed(product.price == product.price.roundToDouble() ? 0 : 2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF212121),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Stock toggle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Switch(
                      value: product.inStock,
                      onChanged: onToggleStock,
                      activeThumbColor: colors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Text(
                      product.inStock ? 'En stock' : 'Agotado',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: product.inStock
                            ? Colors.green.shade600
                            : Colors.red.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  final String photoUrl;
  const _ProductThumbnail({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPlaceholder = photoUrl.isEmpty;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: isPlaceholder
          ? Icon(Icons.image_outlined,
              size: 28, color: colors.onSurface.withValues(alpha: 0.3))
          : CachedImage(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.broken_image_outlined,
                size: 28,
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Product form bottom sheet (add / edit)
// ---------------------------------------------------------------------------

class _ProductFormSheet extends ConsumerStatefulWidget {
  final Product? product;
  final WidgetRef ref;

  const _ProductFormSheet({required this.product, required this.ref});

  @override
  ConsumerState<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _photoCtrl;
  late String _category;
  late bool _inStock;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _brandCtrl = TextEditingController(text: p?.brand ?? '');
    _priceCtrl = TextEditingController(
        text: p != null ? p.price.toStringAsFixed(2) : '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _photoCtrl = TextEditingController(text: p?.photoUrl ?? '');
    _category = p?.category ?? Product.categories.keys.first;
    _inStock = p?.inStock ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _photoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) throw Exception('Negocio no encontrado');
      final bizId = biz['id'] as String;
      final service = ref.read(productServiceProvider);
      final price = double.parse(_priceCtrl.text.trim());

      if (_isEdit) {
        final updated = widget.product!.copyWith(
          name: _nameCtrl.text.trim(),
          brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          price: price,
          photoUrl: _photoCtrl.text.trim(),
          category: _category,
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          inStock: _inStock,
        );
        await service.updateProduct(updated);
        ToastService.showSuccess('Producto actualizado');
      } else {
        final now = DateTime.now();
        final newProduct = Product(
          id: '',
          businessId: bizId,
          name: _nameCtrl.text.trim(),
          brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          price: price,
          photoUrl: _photoCtrl.text.trim(),
          category: _category,
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          inStock: _inStock,
          createdAt: now,
          updatedAt: now,
        );
        await service.createProduct(newProduct);
        ToastService.showSuccess('Producto creado');
      }

      ref.invalidate(businessProductsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, st);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLG),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.paddingMD,
        AppConstants.paddingMD,
        AppConstants.paddingMD,
        AppConstants.paddingMD + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: AppConstants.bottomSheetDragHandleWidth,
                  height: AppConstants.bottomSheetDragHandleHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(
                        AppConstants.bottomSheetDragHandleRadius),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMD),
              Text(
                _isEdit ? 'Editar Producto' : 'Nuevo Producto',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: AppConstants.paddingLG),

              // Name
              _FormField(
                controller: _nameCtrl,
                label: 'Nombre del producto',
                hint: 'Ej. Serum Vitamina C',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // Brand (optional)
              _FormField(
                controller: _brandCtrl,
                label: 'Marca (opcional)',
                hint: 'Ej. L\'Oreal, MAC...',
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // Price
              _FormField(
                controller: _priceCtrl,
                label: 'Precio (MXN)',
                hint: '0.00',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo requerido';
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null || parsed < 0) return 'Precio invalido';
                  return null;
                },
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // Category dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categoria',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSM),
                        borderSide: BorderSide(
                          color: colors.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSM),
                        borderSide: BorderSide(
                          color: colors.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSM),
                        borderSide:
                            BorderSide(color: colors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                    ),
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: const Color(0xFF212121),
                    ),
                    items: Product.categories.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // Description (optional)
              _FormField(
                controller: _descCtrl,
                label: 'Descripcion (opcional)',
                hint: 'Agrega detalles del producto...',
                maxLines: 3,
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // Photo URL (placeholder for future upload)
              _FormField(
                controller: _photoCtrl,
                label: 'URL de foto (opcional)',
                hint: 'https://...',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // In stock toggle
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMD,
                    vertical: AppConstants.paddingSM),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'En stock',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF212121),
                            ),
                          ),
                          Text(
                            _inStock
                                ? 'Disponible para clientes'
                                : 'Marcado como agotado',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: const Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _inStock,
                      onChanged: (v) => setState(() => _inStock = v),
                      activeThumbColor: colors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.paddingLG),

              // Save button
              SizedBox(
                width: double.infinity,
                height: AppConstants.minTouchHeight,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLG),
                    ),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: colors.onPrimary),
                        )
                      : Text(
                          _isEdit ? 'Guardar cambios' : 'Crear producto',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingSM),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF212121)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(
              fontSize: 14,
              color: const Color(0xFFBDBDBD),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              borderSide:
                  BorderSide(color: colors.onSurface.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              borderSide:
                  BorderSide(color: colors.onSurface.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              borderSide: BorderSide(color: colors.error),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Showcase (publish to feed) bottom sheet
// ---------------------------------------------------------------------------

class _ShowcaseSheet extends ConsumerStatefulWidget {
  final List<Product> products;
  final WidgetRef ref;

  const _ShowcaseSheet({required this.products, required this.ref});

  @override
  ConsumerState<_ShowcaseSheet> createState() => _ShowcaseSheetState();
}

class _ShowcaseSheetState extends ConsumerState<_ShowcaseSheet> {
  Product? _selected;
  final _captionCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_selected == null) {
      ToastService.showWarning('Selecciona un producto');
      return;
    }
    setState(() => _saving = true);
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) throw Exception('Negocio no encontrado');
      final service = ref.read(productServiceProvider);
      await service.createShowcase(
        businessId: biz['id'] as String,
        productId: _selected!.id,
        caption: _captionCtrl.text.trim().isEmpty
            ? null
            : _captionCtrl.text.trim(),
      );
      ref.invalidate(businessShowcasesProvider);
      ToastService.showSuccess('Publicado en el Feed');
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, st);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLG),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.paddingMD,
        AppConstants.paddingMD,
        AppConstants.paddingMD,
        AppConstants.paddingMD + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: AppConstants.bottomSheetDragHandleWidth,
                height: AppConstants.bottomSheetDragHandleHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(
                      AppConstants.bottomSheetDragHandleRadius),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined,
                    color: colors.primary, size: 22),
                const SizedBox(width: AppConstants.paddingSM),
                Text(
                  'Publicar en Feed de Inspiracion',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF212121),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingXS),
            Text(
              'El producto aparecera en el feed de usuarias cerca de tu salon.',
              style: GoogleFonts.nunito(
                  fontSize: 13, color: const Color(0xFF757575)),
            ),
            const SizedBox(height: AppConstants.paddingLG),

            Text(
              'Selecciona un producto',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF424242),
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),

            // Product selector chips
            Wrap(
              spacing: AppConstants.paddingSM,
              runSpacing: AppConstants.paddingSM,
              children: widget.products.map((p) {
                final selected = _selected?.id == p.id;
                return ChoiceChip(
                  label: Text(
                    p.name,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? colors.onPrimary : const Color(0xFF424242),
                    ),
                  ),
                  selected: selected,
                  selectedColor: colors.primary,
                  backgroundColor: const Color(0xFFF5F5F5),
                  onSelected: (_) => setState(() => _selected = p),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusFull),
                  ),
                  side: BorderSide(
                    color: selected
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.15),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppConstants.paddingLG),

            // Caption
            Text(
              'Descripcion (opcional)',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _captionCtrl,
              maxLines: 3,
              style:
                  GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF212121)),
              decoration: InputDecoration(
                hintText: 'Escribe algo sobre este producto...',
                hintStyle: GoogleFonts.nunito(
                  fontSize: 14,
                  color: const Color(0xFFBDBDBD),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  borderSide: BorderSide(
                      color: colors.onSurface.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  borderSide: BorderSide(
                      color: colors.onSurface.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
                filled: true,
                fillColor: const Color(0xFFFAFAFA),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: AppConstants.paddingLG),

            SizedBox(
              width: double.infinity,
              height: AppConstants.minTouchHeight,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _publish,
                icon: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: colors.onPrimary),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  'Publicar en Feed',
                  style:
                      GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusLG),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared utility widgets
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        child: Text(
          'Error: $message',
          style: GoogleFonts.nunito(color: colors.error, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

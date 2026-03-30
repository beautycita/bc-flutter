import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';

/// Three-step checkout: Shipping → Payment → Confirmation.
class ProductCheckoutSheet extends StatefulWidget {
  final String productId;
  final String productName;
  final String? brand;
  final double price;
  final String businessId;
  final String salonName;
  final int quantity;

  const ProductCheckoutSheet({
    super.key,
    required this.productId,
    required this.productName,
    this.brand,
    required this.price,
    required this.businessId,
    required this.salonName,
    this.quantity = 1,
  });

  static Future<void> show(
    BuildContext context, {
    required String productId,
    required String productName,
    String? brand,
    required double price,
    required String businessId,
    required String salonName,
    int quantity = 1,
  }) {
    return showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductCheckoutSheet(
        productId: productId,
        productName: productName,
        brand: brand,
        price: price,
        businessId: businessId,
        salonName: salonName,
        quantity: quantity,
      ),
    );
  }

  @override
  State<ProductCheckoutSheet> createState() => _ProductCheckoutSheetState();
}

class _ProductCheckoutSheetState extends State<ProductCheckoutSheet> {
  int _step = 0; // 0 = shipping, 1 = payment, 2 = confirmation

  // Shipping fields
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _processing = false;
  String? _orderId;

  double get _total => widget.price * widget.quantity;
  double get _commission => (_total * 0.10 * 100).roundToDouble() / 100;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Step 1 → Step 2: validate shipping, call edge function, present Stripe
  // ---------------------------------------------------------------------------
  Future<void> _proceedToPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _processing = true);

    // Fresh stock check before proceeding to payment
    try {
      final freshProduct = await SupabaseClientService.client
          .from('products')
          .select('in_stock')
          .eq('id', widget.productId)
          .maybeSingle();
      if (freshProduct == null || freshProduct['in_stock'] != true) {
        ToastService.showError('Este producto ya no esta disponible');
        if (mounted) setState(() => _processing = false);
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PRODUCT-CHECKOUT] Stock check failed: $e');
      // Continue — edge function will also validate
    }

    final shippingAddress = {
      'name': _nameCtrl.text.trim(),
      'street': _streetCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'zip': _zipCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
    };

    try {
      // Call edge function
      final response =
          await SupabaseClientService.client.functions.invoke(
        'create-product-payment',
        body: {
          'product_id': widget.productId,
          'quantity': widget.quantity,
          'shipping_address': shippingAddress,
        },
      );

      final data = response.data as Map<String, dynamic>;

      if (data.containsKey('error')) {
        throw Exception(data['error'] as String);
      }

      final clientSecret = data['client_secret'] as String? ?? '';
      final customerId = data['customer_id'] as String? ?? '';
      final ephemeralKey = data['ephemeral_key'] as String? ?? '';
      final paymentIntentId = data['payment_intent_id'] as String? ?? '';

      if (clientSecret.isEmpty || customerId.isEmpty || ephemeralKey.isEmpty) {
        throw Exception('Error al procesar el pago. Intenta de nuevo.');
      }
      final commissionAmount =
          (data['commission'] as num?)?.toDouble() ?? _commission;

      // Show order summary, then present Stripe PaymentSheet
      setState(() {
        _step = 1;
        _processing = false;
      });

      // Small delay so UI renders step 2 before presenting sheet
      await Future.delayed(const Duration(milliseconds: 300));

      // Init + present Stripe PaymentSheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          merchantDisplayName: 'BeautyCita',
          returnURL: 'beautycita://stripe-redirect',
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
            name: CollectionMode.never,
            email: CollectionMode.never,
            phone: CollectionMode.never,
            address: AddressCollectionMode.never,
          ),
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF660033),
              background: Color(0xFFF9F9F9),
              componentBackground: Color(0xFFFFFFFF),
              componentBorder: Color(0xFFBDBDBD),
              componentDivider: Color(0xFFE0E0E0),
              primaryText: Color(0xFF212121),
              secondaryText: Color(0xFF757575),
              componentText: Color(0xFF212121),
              placeholderText: Color(0xFF9E9E9E),
              icon: Color(0xFF660033),
              error: Color(0xFFD32F2F),
            ),
            shapes: PaymentSheetShape(
              borderRadius: 12,
              borderWidth: 1.0,
            ),
            primaryButton: PaymentSheetPrimaryButtonAppearance(
              colors: PaymentSheetPrimaryButtonTheme(
                light: PaymentSheetPrimaryButtonThemeColors(
                  background: Color(0xFF660033),
                  text: Color(0xFFFFFFFF),
                  border: Color(0xFF660033),
                ),
                dark: PaymentSheetPrimaryButtonThemeColors(
                  background: Color(0xFF660033),
                  text: Color(0xFFFFFFFF),
                  border: Color(0xFF660033),
                ),
              ),
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      if (kDebugMode) debugPrint('[PRODUCT-CHECKOUT] Payment completed');

      // Payment succeeded — create order
      final userId = SupabaseClientService.currentUserId;
      if (userId == null) throw Exception('Not authenticated');

      final orderResult =
          await SupabaseClientService.client.from('orders').insert({
        'buyer_id': userId,
        'business_id': widget.businessId,
        'product_id': widget.productId,
        'product_name': widget.productName,
        'quantity': widget.quantity,
        'total_amount': _total,
        'commission_amount': commissionAmount,
        'status': 'paid',
        'shipping_address': shippingAddress,
        'stripe_payment_intent_id': paymentIntentId,
      }).select('id').single();

      _orderId = orderResult['id'] as String;

      if (mounted) {
        setState(() {
          _step = 2;
          _processing = false;
        });
      }
    } on StripeException catch (e) {
      if (kDebugMode) debugPrint('[PRODUCT-CHECKOUT] Stripe error: $e');
      // User cancelled the payment sheet — go back to shipping
      if (mounted) {
        setState(() {
          _step = 0;
          _processing = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PRODUCT-CHECKOUT] Error: $e');
      if (mounted) {
        setState(() => _processing = false);
        final errMsg = e.toString().replaceAll('Exception: ', '');
        // Detect Stripe Connect / destination account errors
        final lc = errMsg.toLowerCase();
        if (lc.contains('destination') ||
            lc.contains('account') ||
            lc.contains('connect') ||
            lc.contains('pagos en linea')) {
          ToastService.showError(
            'Este salon aun no ha configurado pagos en linea. Contacta al salon directamente.',
          );
        } else {
          ToastService.showError('Error: $errMsg');
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);

    return Container(
      margin: EdgeInsets.only(top: mq.size.height * 0.08),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLG),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: AppConstants.paddingMD),
            width: AppConstants.bottomSheetDragHandleWidth,
            height: AppConstants.bottomSheetDragHandleHeight,
            decoration: BoxDecoration(
              color: palette.onSurface.withValues(alpha: 0.2),
              borderRadius:
                  BorderRadius.circular(AppConstants.bottomSheetDragHandleRadius),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppConstants.screenPaddingHorizontal,
                AppConstants.paddingLG,
                AppConstants.screenPaddingHorizontal,
                AppConstants.paddingLG + mq.padding.bottom,
              ),
              child: switch (_step) {
                0 => _buildShippingStep(palette),
                1 => _buildPaymentStep(palette),
                2 => _buildConfirmationStep(palette),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 0 — Shipping Address
  // ---------------------------------------------------------------------------
  Widget _buildShippingStep(ColorScheme palette) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Direccion de envio',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: palette.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            widget.salonName,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: palette.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppConstants.paddingLG),

          _field(_nameCtrl, 'Nombre completo', Icons.person_outline),
          _field(_streetCtrl, 'Calle y numero', Icons.home_outlined),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _field(_cityCtrl, 'Ciudad', Icons.location_city_outlined),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Expanded(
                flex: 2,
                child: _field(_stateCtrl, 'Estado', Icons.map_outlined),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _field(_zipCtrl, 'C.P.', Icons.markunread_mailbox_outlined,
                    keyboard: TextInputType.number),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Expanded(
                flex: 2,
                child: _field(_phoneCtrl, 'Telefono', Icons.phone_outlined,
                    keyboard: TextInputType.phone),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // Order summary mini
          _orderSummaryCard(palette),

          const SizedBox(height: AppConstants.paddingLG),

          // Continue button
          SizedBox(
            width: double.infinity,
            height: AppConstants.minTouchHeight,
            child: FilledButton(
              onPressed: _processing ? null : _proceedToPayment,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                ),
              ),
              child: _processing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Continuar al pago',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        style: GoogleFonts.nunito(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
            vertical: AppConstants.paddingSM,
          ),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Payment (processing via Stripe PaymentSheet)
  // ---------------------------------------------------------------------------
  Widget _buildPaymentStep(ColorScheme palette) {
    return Column(
      children: [
        const SizedBox(height: AppConstants.paddingXL),
        Icon(
          Icons.credit_card_outlined,
          size: AppConstants.iconSizeXXL,
          color: palette.primary,
        ),
        const SizedBox(height: AppConstants.paddingLG),
        Text(
          'Procesando pago...',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: palette.onSurface,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSM),
        Text(
          'Complete el pago en la ventana de Stripe',
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: palette.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.paddingXL),
        const CircularProgressIndicator(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Confirmation
  // ---------------------------------------------------------------------------
  Widget _buildConfirmationStep(ColorScheme palette) {
    final shortId = _orderId != null
        ? _orderId!.substring(0, 8).toUpperCase()
        : '--------';

    return Column(
      children: [
        const SizedBox(height: AppConstants.paddingXL),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_outline,
            size: 48,
            color: palette.primary,
          ),
        ),
        const SizedBox(height: AppConstants.paddingLG),
        Text(
          'Compra exitosa!',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: palette.onSurface,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSM),
        Text(
          'Orden #$shortId',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: palette.primary,
          ),
        ),
        const SizedBox(height: AppConstants.paddingLG),

        // Order details card
        _orderSummaryCard(palette),

        const SizedBox(height: AppConstants.paddingLG),

        Container(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          decoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          ),
          child: Row(
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 20, color: palette.primary),
              const SizedBox(width: AppConstants.paddingSM),
              Expanded(
                child: Text(
                  'El salon tiene 14 dias para enviar tu pedido',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.paddingXL),

        SizedBox(
          width: double.infinity,
          height: AppConstants.minTouchHeight,
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // close checkout
              Navigator.of(context).pop(); // close product detail
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              ),
            ),
            child: Text(
              'Cerrar',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Shared order summary card
  // ---------------------------------------------------------------------------
  Widget _orderSummaryCard(ColorScheme palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: palette.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        border: Border.all(
          color: palette.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen del pedido',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          _summaryRow(
            palette,
            widget.productName,
            '\$${widget.price.toStringAsFixed(2)}',
          ),
          if (widget.quantity > 1)
            _summaryRow(
              palette,
              'Cantidad: ${widget.quantity}',
              'x${widget.quantity}',
            ),
          const Divider(height: 20),
          _summaryRow(
            palette,
            'Total',
            '\$${_total.toStringAsFixed(2)} MXN',
            bold: true,
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            'BeautyCita cobra 10% de comision',
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: palette.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    ColorScheme palette,
    String label,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: palette.onSurface.withValues(alpha: bold ? 1.0 : 0.7),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? palette.primary : palette.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

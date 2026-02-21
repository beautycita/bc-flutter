import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/btc_wallet_provider.dart';

/// Consistent card decoration used throughout the screen
BoxDecoration _cardDecoration(ColorScheme colorScheme) => BoxDecoration(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      border: Border.all(
        color: colorScheme.onSurface.withValues(alpha: 0.12),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

class BtcWalletScreen extends ConsumerStatefulWidget {
  const BtcWalletScreen({super.key});

  @override
  ConsumerState<BtcWalletScreen> createState() => _BtcWalletScreenState();
}

class _BtcWalletScreenState extends ConsumerState<BtcWalletScreen> {
  bool _depositExpanded = false;
  bool _withdrawExpanded = false;
  final _withdrawAddressController = TextEditingController();
  final _withdrawAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(btcWalletProvider.notifier).init());
  }

  @override
  void dispose() {
    _withdrawAddressController.dispose();
    _withdrawAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(btcWalletProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceLight = colorScheme.onSurface.withValues(alpha: 0.5);
    final mxnFormat = NumberFormat('#,##0.00', 'es_MX');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.currency_bitcoin_rounded, color: Color(0xFFF7931A), size: 24),
            const SizedBox(width: 8),
            const Text('Bitcoin Wallet'),
          ],
        ),
        actions: [
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.read(btcWalletProvider.notifier).refreshAll(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(btcWalletProvider.notifier).refreshAll(),
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenPaddingHorizontal,
            vertical: AppConstants.paddingMD,
          ),
          children: [
            // ── Balance Card ──
            _buildBalanceCard(state, textTheme, colorScheme, onSurfaceLight, mxnFormat),

            const SizedBox(height: AppConstants.paddingMD),

            // ── Price Ticker ──
            _buildPriceTicker(state, textTheme, colorScheme, onSurfaceLight, mxnFormat),

            const SizedBox(height: AppConstants.paddingLG),

            // ── Action Buttons ──
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Depositar',
                    color: const Color(0xFF4CAF50),
                    colorScheme: colorScheme,
                    onTap: () => setState(() {
                      _depositExpanded = !_depositExpanded;
                      if (_depositExpanded) _withdrawExpanded = false;
                    }),
                    isActive: _depositExpanded,
                  ),
                ),
                const SizedBox(width: AppConstants.paddingMD),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Retirar',
                    color: const Color(0xFFF7931A),
                    colorScheme: colorScheme,
                    onTap: () => setState(() {
                      _withdrawExpanded = !_withdrawExpanded;
                      if (_withdrawExpanded) _depositExpanded = false;
                    }),
                    isActive: _withdrawExpanded,
                  ),
                ),
              ],
            ),

            // ── Deposit Section ──
            AnimatedCrossFade(
              duration: AppConstants.mediumAnimation,
              crossFadeState: _depositExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: AppConstants.paddingMD),
                child: _buildDepositSection(state, textTheme, colorScheme, onSurfaceLight),
              ),
            ),

            // ── Withdrawal Section ──
            AnimatedCrossFade(
              duration: AppConstants.mediumAnimation,
              crossFadeState: _withdrawExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: AppConstants.paddingMD),
                child: _buildWithdrawSection(textTheme, colorScheme, onSurfaceLight),
              ),
            ),

            const SizedBox(height: AppConstants.paddingLG),

            // ── Transaction History ──
            Text(
              'Historial',
              style: textTheme.labelLarge?.copyWith(
                color: onSurfaceLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            _buildTransactionHistory(state, textTheme, colorScheme, onSurfaceLight, mxnFormat),

            const SizedBox(height: AppConstants.paddingXL),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    BtcWalletState state,
    TextTheme textTheme,
    ColorScheme colorScheme,
    Color onSurfaceLight,
    NumberFormat mxnFormat,
  ) {
    final btc = state.balanceBtc;
    final mxn = state.balance.balanceMxn;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: _cardDecoration(colorScheme),
      child: Column(
        children: [
          Text(
            'Saldo disponible',
            style: textTheme.labelMedium?.copyWith(
              color: onSurfaceLight,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${btc.toStringAsFixed(8)} BTC',
            style: textTheme.headlineMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '~ \$${mxnFormat.format(mxn)} MXN',
            style: textTheme.bodyLarge?.copyWith(
              color: onSurfaceLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTicker(
    BtcWalletState state,
    TextTheme textTheme,
    ColorScheme colorScheme,
    Color onSurfaceLight,
    NumberFormat mxnFormat,
  ) {
    final price = state.price;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMD,
        vertical: AppConstants.paddingSM + 4,
      ),
      decoration: _cardDecoration(colorScheme),
      child: Row(
        children: [
          // Pulsing green dot
          if (price != null)
            _PulsingDot()
          else
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: onSurfaceLight),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              price != null
                  ? '1 BTC = \$${mxnFormat.format(price.mxn)} MXN'
                  : 'Obteniendo precio...',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (price != null)
            Text(
              '\$${mxnFormat.format(price.usd)} USD',
              style: textTheme.bodySmall?.copyWith(color: onSurfaceLight),
            ),
        ],
      ),
    );
  }

  Widget _buildDepositSection(
    BtcWalletState state,
    TextTheme textTheme,
    ColorScheme colorScheme,
    Color onSurfaceLight,
  ) {
    final wallet = state.wallet;
    final address = wallet?.walletAddress ?? '';

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: _cardDecoration(colorScheme),
      child: Column(
        children: [
          if (address.isEmpty) ...[
            const SizedBox(height: AppConstants.paddingSM),
            Icon(Icons.account_balance_wallet_rounded, size: 40, color: onSurfaceLight),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              'Genera tu direccion de deposito Bitcoin',
              style: textTheme.bodyMedium?.copyWith(color: onSurfaceLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingMD),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () => ref.read(btcWalletProvider.notifier).generateDepositAddress(),
                icon: state.isLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_rounded, size: 20),
                label: Text(state.isLoading ? 'Generando...' : 'Generar direccion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, AppConstants.minTouchHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
          ] else ...[
            // QR Code
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  border: Border.all(
                    color: colorScheme.onSurface.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: QrImageView(
                  data: address.startsWith('bitcoin:') ? address : 'bitcoin:$address',
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF1A1A1A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMD),

            // Address + copy
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingSM + 4,
                vertical: AppConstants.paddingSM,
              ),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppConstants.radiusXS),
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      address,
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Copiar direccion',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: address));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Direccion copiada'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.paddingLG),

            // Confirmation tracker
            _buildConfirmationTracker(textTheme, colorScheme, onSurfaceLight),

            const SizedBox(height: AppConstants.paddingSM),
            Text(
              '1 conf = detectado  \u2022  3 conf = disponible',
              style: textTheme.bodySmall?.copyWith(
                color: onSurfaceLight,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmationTracker(
    TextTheme textTheme,
    ColorScheme colorScheme,
    Color onSurfaceLight,
  ) {
    const steps = ['Detectado', 'Confirmado', 'Disponible'];
    const currentStep = 0; // placeholder — no active deposit

    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i <= currentStep && currentStep > 0;
        final isDone = i < currentStep;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isActive
                            ? const Color(0xFF4CAF50)
                            : colorScheme.onSurface.withValues(alpha: 0.12),
                      ),
                    ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? const Color(0xFF4CAF50)
                          : colorScheme.onSurface.withValues(alpha: 0.08),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF4CAF50)
                            : colorScheme.onSurface.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: textTheme.labelSmall?.copyWith(
                                color: isActive ? Colors.white : onSurfaceLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: (i + 1 <= currentStep && currentStep > 0)
                            ? const Color(0xFF4CAF50)
                            : colorScheme.onSurface.withValues(alpha: 0.12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                steps[i],
                style: textTheme.labelSmall?.copyWith(
                  color: isActive ? const Color(0xFF4CAF50) : onSurfaceLight,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildWithdrawSection(
    TextTheme textTheme,
    ColorScheme colorScheme,
    Color onSurfaceLight,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: _cardDecoration(colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Direccion BTC destino',
            style: textTheme.labelMedium?.copyWith(color: onSurfaceLight),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _withdrawAddressController,
            decoration: InputDecoration(
              hintText: 'bc1q...',
              hintStyle: textTheme.bodyMedium?.copyWith(color: onSurfaceLight),
              filled: true,
              fillColor: colorScheme.onSurface.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                borderSide: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                borderSide: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                borderSide: const BorderSide(
                  color: Color(0xFFF7931A),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMD,
                vertical: AppConstants.paddingSM,
              ),
            ),
            style: textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          Text(
            'Monto',
            style: textTheme.labelMedium?.copyWith(color: onSurfaceLight),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _withdrawAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '0.00000000',
              hintStyle: textTheme.bodyMedium?.copyWith(color: onSurfaceLight),
              suffixText: 'BTC',
              filled: true,
              fillColor: colorScheme.onSurface.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                borderSide: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                borderSide: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                borderSide: const BorderSide(
                  color: Color(0xFFF7931A),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMD,
                vertical: AppConstants.paddingSM,
              ),
            ),
            style: textTheme.bodyMedium,
          ),

          const SizedBox(height: AppConstants.paddingSM),

          // Network fee estimate
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingSM),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppConstants.radiusXS),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comision de red estimada: ~0.00005 BTC',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Proximamente - retiros en desarrollo'),
                    backgroundColor: Colors.amber.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7931A),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, AppConstants.minTouchHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                ),
              ),
              child: const Text(
                'Confirmar retiro',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory(
    BtcWalletState state,
    TextTheme textTheme,
    ColorScheme colorScheme,
    Color onSurfaceLight,
    NumberFormat mxnFormat,
  ) {
    if (state.transactions.isEmpty && state.deposits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        decoration: _cardDecoration(colorScheme),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 40,
              color: onSurfaceLight.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              'No hay transacciones aun',
              style: textTheme.bodyMedium?.copyWith(color: onSurfaceLight),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: _cardDecoration(colorScheme),
      child: Column(
        children: [
          ...state.transactions.asMap().entries.map((entry) {
            final tx = entry.value;
            final isDeposit = tx.type == 'deposit';
            final isLast = entry.key == state.transactions.length - 1;
            return Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (isDeposit ? Colors.green : Colors.red).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                      border: Border.all(
                        color: (isDeposit ? Colors.green : Colors.red).withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: isDeposit ? Colors.green : Colors.red,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    tx.description ?? (isDeposit ? 'Deposito' : 'Retiro'),
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    DateFormat('dd MMM yyyy, HH:mm', 'es').format(tx.createdAt),
                    style: textTheme.bodySmall?.copyWith(color: onSurfaceLight),
                  ),
                  trailing: Text(
                    '${isDeposit ? '+' : '-'}\$${mxnFormat.format(tx.amountMxn)} MXN',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDeposit ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.colorScheme,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? color : colorScheme.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(
            color: isActive
                ? color
                : colorScheme.onSurface.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMD),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? Colors.white : color,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isActive ? Colors.white : color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green.withValues(alpha: _opacity.value),
        ),
      ),
    );
  }
}

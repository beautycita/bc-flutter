import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/btc_wallet_provider.dart';
import 'package:beautycita/widgets/totp_input_widget.dart';

const _btcOrange = Color(0xFFF7931A);
const _btcGreen = Color(0xFF4CAF50);

BoxDecoration _cardDecoration(ColorScheme cs) => BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      border: Border.all(color: cs.onSurface.withValues(alpha: 0.12), width: 1.5),
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(btcWalletProvider.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(btcWalletProvider);
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final dim = cs.onSurface.withValues(alpha: 0.5);
    final mxnFmt = NumberFormat('#,##0.00', 'es_MX');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.currency_bitcoin_rounded, color: _btcOrange, size: 24),
            SizedBox(width: 8),
            Text('Bitcoin Wallet'),
          ],
        ),
        actions: [
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
            _buildBalanceCard(state, textTheme, cs, dim, mxnFmt),
            const SizedBox(height: AppConstants.paddingMD),
            _buildPriceTicker(state, textTheme, cs, dim, mxnFmt),
            const SizedBox(height: AppConstants.paddingMD),

            // 2FA setup card (only when TOTP not configured)
            if (!state.totpEnabled) ...[
              _build2faSetupCard(textTheme, cs, dim),
              const SizedBox(height: AppConstants.paddingMD),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Depositar',
                    color: _btcGreen,
                    colorScheme: cs,
                    onTap: () {
                      if (!state.totpEnabled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Configura 2FA primero'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _depositExpanded = !_depositExpanded;
                        if (_depositExpanded) _withdrawExpanded = false;
                      });
                    },
                    isActive: _depositExpanded,
                  ),
                ),
                const SizedBox(width: AppConstants.paddingMD),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Retirar',
                    color: _btcOrange,
                    colorScheme: cs,
                    onTap: () {
                      if (!state.totpEnabled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Configura 2FA primero'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      if (state.confirmedBtc <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No tienes saldo disponible'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      _showWithdrawSheet(state);
                    },
                    isActive: _withdrawExpanded,
                  ),
                ),
              ],
            ),

            // Deposit section
            AnimatedCrossFade(
              duration: AppConstants.mediumAnimation,
              crossFadeState: _depositExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: AppConstants.paddingMD),
                child: _buildDepositSection(state, textTheme, cs, dim),
              ),
            ),

            const SizedBox(height: AppConstants.paddingLG),

            // Deposit history
            Text(
              'Historial de depositos',
              style: textTheme.labelLarge?.copyWith(color: dim, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            _buildDepositHistory(state, textTheme, cs, dim),

            const SizedBox(height: AppConstants.paddingXL),
          ],
        ),
      ),
    );
  }

  // ── Balance Card ──
  Widget _buildBalanceCard(
    BtcWalletState state,
    TextTheme tt,
    ColorScheme cs,
    Color dim,
    NumberFormat fmt,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: _cardDecoration(cs),
      child: Column(
        children: [
          Text('Saldo disponible', style: tt.labelMedium?.copyWith(color: dim, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(
            '${state.confirmedBtc.toStringAsFixed(8)} BTC',
            style: tt.headlineMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '~ \$${fmt.format(state.balanceMxn)} MXN',
            style: tt.bodyLarge?.copyWith(color: dim),
          ),
          if (state.pendingBtc > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Pendiente: ${state.pendingBtc.toStringAsFixed(8)} BTC',
                style: tt.bodySmall?.copyWith(color: Colors.amber.shade700, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Price Ticker ──
  Widget _buildPriceTicker(
    BtcWalletState state,
    TextTheme tt,
    ColorScheme cs,
    Color dim,
    NumberFormat fmt,
  ) {
    final price = state.price;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD, vertical: AppConstants.paddingSM + 4),
      decoration: _cardDecoration(cs),
      child: Row(
        children: [
          if (price != null) const _PulsingDot() else SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: dim)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              price != null ? '1 BTC = \$${fmt.format(price.mxn)} MXN' : 'Obteniendo precio...',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          if (price != null) Text('\$${fmt.format(price.usd)} USD', style: tt.bodySmall?.copyWith(color: dim)),
        ],
      ),
    );
  }

  // ── 2FA Setup Card ──
  Widget _build2faSetupCard(TextTheme tt, ColorScheme cs, Color dim) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: _btcOrange.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: _btcOrange.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.shield_rounded, size: 44, color: _btcOrange.withValues(alpha: 0.8)),
          const SizedBox(height: AppConstants.paddingSM),
          Text(
            'Protege tu billetera',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Configura autenticacion 2FA para generar tu direccion de deposito Bitcoin.',
            style: tt.bodySmall?.copyWith(color: dim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingMD),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showTotpSetupSheet(),
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: const Text('Configurar 2FA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _btcOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, AppConstants.minTouchHeight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLG)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Deposit Section ──
  Widget _buildDepositSection(BtcWalletState state, TextTheme tt, ColorScheme cs, Color dim) {
    final address = state.currentAddress ?? '';

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: _cardDecoration(cs),
      child: Column(
        children: [
          if (address.isEmpty) ...[
            const SizedBox(height: AppConstants.paddingSM),
            Icon(Icons.account_balance_wallet_rounded, size: 40, color: dim),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              'Genera tu direccion de deposito Bitcoin',
              style: tt.bodyMedium?.copyWith(color: dim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingMD),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isLoading ? null : () => _showTotpVerifySheet(action: 'generate'),
                icon: state.isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_rounded, size: 20),
                label: Text(state.isLoading ? 'Generando...' : 'Generar direccion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _btcOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, AppConstants.minTouchHeight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLG)),
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
                  border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                ),
                child: QrImageView(
                  data: 'bitcoin:$address',
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1A1A)),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1A1A)),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMD),

            // Address + copy
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSM + 4, vertical: AppConstants.paddingSM),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppConstants.radiusXS),
                border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      address,
                      style: tt.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 12, height: 1.4),
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
                        const SnackBar(content: Text('Direccion copiada'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),

            // New address link
            TextButton.icon(
              onPressed: () => _showTotpVerifySheet(action: 'generate'),
              icon: const Icon(Icons.autorenew_rounded, size: 16),
              label: const Text('Nueva direccion'),
              style: TextButton.styleFrom(foregroundColor: _btcOrange),
            ),
          ],
        ],
      ),
    );
  }

  // ── Deposit History ──
  Widget _buildDepositHistory(BtcWalletState state, TextTheme tt, ColorScheme cs, Color dim) {
    if (state.deposits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        decoration: _cardDecoration(cs),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 40, color: dim.withValues(alpha: 0.4)),
            const SizedBox(height: AppConstants.paddingSM),
            Text('No hay depositos aun', style: tt.bodyMedium?.copyWith(color: dim)),
          ],
        ),
      );
    }

    return Container(
      decoration: _cardDecoration(cs),
      child: Column(
        children: state.deposits.asMap().entries.map((entry) {
          final dep = entry.value;
          final isLast = entry.key == state.deposits.length - 1;
          final statusColor = dep.status == 'confirmed' ? _btcGreen : Colors.amber.shade700;

          return Column(
            children: [
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.arrow_downward_rounded, color: statusColor, size: 18),
                ),
                title: Text(
                  '${dep.amountBtc.toStringAsFixed(8)} BTC',
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  dep.status == 'confirmed'
                      ? 'Confirmado'
                      : '${dep.confirmations}/3 confirmaciones',
                  style: tt.bodySmall?.copyWith(color: statusColor),
                ),
                trailing: dep.txid != null
                    ? Text(
                        '${dep.txid!.substring(0, 8)}...',
                        style: tt.bodySmall?.copyWith(color: dim, fontFamily: 'monospace', fontSize: 10),
                      )
                    : null,
              ),
              if (!isLast) Divider(height: 1, indent: 16, endIndent: 16, color: cs.onSurface.withValues(alpha: 0.08)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── 2FA Setup Bottom Sheet ──
  void _showTotpSetupSheet() async {
    final notifier = ref.read(btcWalletProvider.notifier);
    final success = await notifier.setupTotp();
    if (!success || !mounted) return;

    final state = ref.read(btcWalletProvider);
    if (state.otpauthUri == null) return;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) => _TotpSetupSheet(
        otpauthUri: state.otpauthUri!,
        secret: state.totpSecret ?? '',
        onVerify: (code) async {
          final ok = await notifier.verifyTotp(code);
          if (ok && ctx.mounted) Navigator.pop(ctx);
          return ok;
        },
      ),
    );
  }

  // ── Withdraw Bottom Sheet ──
  void _showWithdrawSheet(BtcWalletState walletState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) => _WithdrawSheet(
        availableBtc: walletState.confirmedBtc,
        priceMxn: walletState.price?.mxn ?? 0,
        onSubmit: (destination, amountBtc, totpCode, {bool sendAll = false}) async {
          final result = await ref.read(btcWalletProvider.notifier).withdraw(
            destination: destination,
            amountBtc: amountBtc,
            totpCode: totpCode,
            sendAll: sendAll,
          );
          if (result != null && ctx.mounted) Navigator.pop(ctx);
          return result != null;
        },
      ),
    );
  }

  // ── TOTP Verify Bottom Sheet ──
  void _showTotpVerifySheet({required String action}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) => _TotpVerifySheet(
        onVerify: (code) async {
          if (action == 'generate') {
            final ok = await ref.read(btcWalletProvider.notifier).generateAddress(code);
            if (ok && ctx.mounted) Navigator.pop(ctx);
            return ok;
          }
          return false;
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Bottom sheets
// ═══════════════════════════════════════════════════════════════════════════════

class _TotpSetupSheet extends StatefulWidget {
  final String otpauthUri;
  final String secret;
  final Future<bool> Function(String code) onVerify;

  const _TotpSetupSheet({required this.otpauthUri, required this.secret, required this.onVerify});

  @override
  State<_TotpSetupSheet> createState() => _TotpSetupSheetState();
}

class _TotpSetupSheetState extends State<_TotpSetupSheet> {
  bool _showVerify = false;
  bool _isVerifying = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dim = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppConstants.paddingLG,
          AppConstants.paddingMD,
          AppConstants.paddingLG,
          MediaQuery.of(context).viewInsets.bottom + AppConstants.paddingLG,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMD),

              if (!_showVerify) ...[
                // Step 1: Show QR
                const Icon(Icons.qr_code_rounded, size: 32, color: _btcOrange),
                const SizedBox(height: 8),
                Text('Configurar 2FA', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Escanea este codigo con Google Authenticator o una app compatible',
                  style: tt.bodySmall?.copyWith(color: dim),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingMD),

                // QR code
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  ),
                  child: QrImageView(
                    data: widget.otpauthUri,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),

                // Manual secret
                Text('O ingresa este codigo manualmente:', style: tt.bodySmall?.copyWith(color: dim)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.secret));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Codigo copiado'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.secret,
                            style: tt.bodySmall?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w600, letterSpacing: 1.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded, size: 16, color: _btcOrange),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingLG),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showVerify = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _btcOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, AppConstants.minTouchHeight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLG)),
                    ),
                    child: const Text('Siguiente', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ] else ...[
                // Step 2: Verify code
                const Icon(Icons.pin_rounded, size: 32, color: _btcOrange),
                const SizedBox(height: 8),
                Text('Verifica tu codigo', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Ingresa el codigo de 6 digitos de tu app de autenticacion',
                  style: tt.bodySmall?.copyWith(color: dim),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingLG),

                TotpInputWidget(
                  isLoading: _isVerifying,
                  error: _error,
                  onComplete: (code) async {
                    setState(() {
                      _isVerifying = true;
                      _error = null;
                    });
                    final ok = await widget.onVerify(code);
                    if (!ok && mounted) {
                      setState(() {
                        _isVerifying = false;
                        _error = 'Codigo incorrecto — intenta de nuevo';
                      });
                    }
                  },
                ),

                const SizedBox(height: AppConstants.paddingMD),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TotpVerifySheet extends StatefulWidget {
  final Future<bool> Function(String code) onVerify;

  const _TotpVerifySheet({required this.onVerify});

  @override
  State<_TotpVerifySheet> createState() => _TotpVerifySheetState();
}

class _TotpVerifySheetState extends State<_TotpVerifySheet> {
  bool _isVerifying = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dim = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppConstants.paddingLG,
          AppConstants.paddingMD,
          AppConstants.paddingLG,
          MediaQuery.of(context).viewInsets.bottom + AppConstants.paddingLG,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            const Icon(Icons.lock_rounded, size: 32, color: _btcOrange),
            const SizedBox(height: 8),
            Text('Confirmar con 2FA', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Ingresa tu codigo de autenticacion',
              style: tt.bodySmall?.copyWith(color: dim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingLG),

            TotpInputWidget(
              isLoading: _isVerifying,
              error: _error,
              onComplete: (code) async {
                setState(() {
                  _isVerifying = true;
                  _error = null;
                });
                final ok = await widget.onVerify(code);
                if (!ok && mounted) {
                  setState(() {
                    _isVerifying = false;
                    _error = 'Codigo incorrecto';
                  });
                }
              },
            ),

            const SizedBox(height: AppConstants.paddingMD),
          ],
        ),
      ),
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  final double availableBtc;
  final double priceMxn;
  final Future<bool> Function(String destination, double amountBtc, String totpCode, {bool sendAll}) onSubmit;

  const _WithdrawSheet({required this.availableBtc, required this.priceMxn, required this.onSubmit});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _addressCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _sendAll = false;
  bool _showTotp = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _amount {
    if (_sendAll) return widget.availableBtc;
    return double.tryParse(_amountCtrl.text) ?? 0;
  }

  double get _mxnEquiv => _amount * widget.priceMxn;

  bool get _isValid {
    final addr = _addressCtrl.text.trim();
    return addr.startsWith('bc1') && addr.length >= 42 && _amount > 0 && _amount <= widget.availableBtc;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final dim = cs.onSurface.withValues(alpha: 0.5);
    final mxnFmt = NumberFormat('#,##0.00', 'es_MX');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppConstants.paddingLG,
          AppConstants.paddingMD,
          AppConstants.paddingLG,
          MediaQuery.of(context).viewInsets.bottom + AppConstants.paddingLG,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMD),

              if (!_showTotp) ...[
                const Icon(Icons.arrow_upward_rounded, size: 32, color: _btcOrange),
                const SizedBox(height: 8),
                Text('Retirar Bitcoin', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Disponible: ${widget.availableBtc.toStringAsFixed(8)} BTC',
                  style: tt.bodySmall?.copyWith(color: dim),
                ),
                const SizedBox(height: AppConstants.paddingLG),

                // Destination address
                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(
                    labelText: 'Direccion destino',
                    hintText: 'bc1q...',
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSM)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  style: tt.bodyMedium?.copyWith(fontFamily: 'monospace', fontSize: 13),
                  maxLines: 1,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppConstants.paddingMD),

                // Amount
                TextField(
                  controller: _amountCtrl,
                  enabled: !_sendAll,
                  decoration: InputDecoration(
                    labelText: 'Monto (BTC)',
                    hintText: '0.00000000',
                    prefixIcon: const Icon(Icons.currency_bitcoin_rounded, size: 20, color: _btcOrange),
                    suffixText: _mxnEquiv > 0 ? '~\$${mxnFmt.format(_mxnEquiv)} MXN' : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSM)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: tt.bodyMedium?.copyWith(fontFamily: 'monospace'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),

                // Send all toggle
                Row(
                  children: [
                    Checkbox(
                      value: _sendAll,
                      onChanged: (v) => setState(() {
                        _sendAll = v ?? false;
                        if (_sendAll) _amountCtrl.text = widget.availableBtc.toStringAsFixed(8);
                      }),
                      activeColor: _btcOrange,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Text('Enviar todo', style: tt.bodyMedium),
                  ],
                ),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: tt.bodySmall?.copyWith(color: cs.error)),
                ],

                const SizedBox(height: AppConstants.paddingMD),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValid ? () => setState(() => _showTotp = true) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _btcOrange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _btcOrange.withValues(alpha: 0.3),
                      minimumSize: const Size(0, AppConstants.minTouchHeight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLG)),
                    ),
                    child: Text('Continuar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ] else ...[
                // TOTP confirmation step
                const Icon(Icons.lock_rounded, size: 32, color: _btcOrange),
                const SizedBox(height: 8),
                Text('Confirmar retiro', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),

                // Summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.paddingMD),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                    border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monto: ${_amount.toStringAsFixed(8)} BTC', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('~\$${mxnFmt.format(_mxnEquiv)} MXN', style: tt.bodySmall?.copyWith(color: dim)),
                      const SizedBox(height: 8),
                      Text('Destino:', style: tt.bodySmall?.copyWith(color: dim)),
                      Text(
                        _addressCtrl.text.trim(),
                        style: tt.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),

                Text(
                  'Ingresa tu codigo 2FA para confirmar',
                  style: tt.bodySmall?.copyWith(color: dim),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingMD),

                TotpInputWidget(
                  isLoading: _isSubmitting,
                  error: _error,
                  onComplete: (code) async {
                    setState(() { _isSubmitting = true; _error = null; });
                    final ok = await widget.onSubmit(
                      _addressCtrl.text.trim(),
                      _amount,
                      code,
                      sendAll: _sendAll,
                    );
                    if (!ok && mounted) {
                      setState(() {
                        _isSubmitting = false;
                        _error = 'Error al procesar el retiro';
                      });
                    }
                  },
                ),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() { _showTotp = false; _error = null; }),
                  child: Text('Volver', style: TextStyle(color: dim)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Reusable widgets
// ═══════════════════════════════════════════════════════════════════════════════

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
            color: isActive ? color : colorScheme.onSurface.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMD),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: isActive ? Colors.white : color),
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
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _opacity = Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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

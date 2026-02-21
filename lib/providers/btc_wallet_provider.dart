import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/btcpay_service.dart';

/// Combined wallet state
class BtcWalletState {
  final bool isLoading;
  final BtcPrice? price;
  final BtcBalance balance;
  final BtcWallet? wallet;
  final List<BtcDeposit> deposits;
  final List<BtcTransaction> transactions;
  final String? error;

  const BtcWalletState({
    this.isLoading = false,
    this.price,
    this.balance = const BtcBalance(),
    this.wallet,
    this.deposits = const [],
    this.transactions = const [],
    this.error,
  });

  BtcWalletState copyWith({
    bool? isLoading,
    BtcPrice? price,
    BtcBalance? balance,
    BtcWallet? wallet,
    List<BtcDeposit>? deposits,
    List<BtcTransaction>? transactions,
    String? error,
  }) {
    return BtcWalletState(
      isLoading: isLoading ?? this.isLoading,
      price: price ?? this.price,
      balance: balance ?? this.balance,
      wallet: wallet ?? this.wallet,
      deposits: deposits ?? this.deposits,
      transactions: transactions ?? this.transactions,
      error: error,
    );
  }

  /// Balance in BTC (derived from MXN balance / price)
  double get balanceBtc {
    if (price == null || price!.mxn <= 0) return 0;
    return balance.balanceMxn / price!.mxn;
  }
}

class BtcWalletNotifier extends StateNotifier<BtcWalletState> {
  Timer? _priceTimer;

  BtcWalletNotifier() : super(const BtcWalletState());

  /// Load everything on screen open
  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);

    // Fetch price first, then everything else in parallel
    final price = await BTCPayService.getPrice();
    state = state.copyWith(price: price);

    final results = await Future.wait([
      BTCPayService.getBalance(),
      BTCPayService.getWallet(),
      BTCPayService.getDeposits(),
      BTCPayService.getTransactions(),
    ]);

    state = state.copyWith(
      isLoading: false,
      balance: results[0] as BtcBalance,
      wallet: results[1] as BtcWallet?,
      deposits: results[2] as List<BtcDeposit>,
      transactions: results[3] as List<BtcTransaction>,
    );

    // Start price polling every 30s
    _priceTimer?.cancel();
    _priceTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshPrice());
  }

  Future<void> _refreshPrice() async {
    final price = await BTCPayService.getPrice();
    if (price != null && mounted) {
      state = state.copyWith(price: price);
    }
  }

  Future<void> refreshAll() async {
    state = state.copyWith(isLoading: true);
    final results = await Future.wait([
      BTCPayService.getPrice(),
      BTCPayService.getBalance(),
      BTCPayService.getDeposits(),
      BTCPayService.getTransactions(),
    ]);
    state = state.copyWith(
      isLoading: false,
      price: results[0] as BtcPrice? ?? state.price,
      balance: results[1] as BtcBalance,
      deposits: results[2] as List<BtcDeposit>,
      transactions: results[3] as List<BtcTransaction>,
    );
  }

  /// Generate deposit address (calls getWallet which creates one if needed)
  Future<void> generateDepositAddress() async {
    state = state.copyWith(isLoading: true);
    final wallet = await BTCPayService.getWallet();
    state = state.copyWith(isLoading: false, wallet: wallet);
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    super.dispose();
  }
}

final btcWalletProvider =
    StateNotifierProvider.autoDispose<BtcWalletNotifier, BtcWalletState>((ref) {
  final notifier = BtcWalletNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

/// Standalone price provider for quick access elsewhere
final btcPriceProvider = FutureProvider.autoDispose<BtcPrice?>((ref) async {
  return BTCPayService.getPrice();
});

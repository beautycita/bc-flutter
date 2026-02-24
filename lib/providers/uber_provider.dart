import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/uber_service.dart';

/// Simple provider for Uber deep link service. No OAuth, no linking.
final uberServiceProvider = Provider<UberService>((ref) => UberService());

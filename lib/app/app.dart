import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/offline/offline_payment_controller.dart';
import '../core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'router/route_paths.dart';

class TngOfflineWalletApp extends ConsumerStatefulWidget {
  const TngOfflineWalletApp({super.key});

  @override
  ConsumerState<TngOfflineWalletApp> createState() =>
      _TngOfflineWalletAppState();
}

class _TngOfflineWalletAppState extends ConsumerState<TngOfflineWalletApp> {
  late final GoRouter _router;
  late final ProviderSubscription<OfflinePaymentState> _paymentSubscription;

  @override
  void initState() {
    super.initState();
    _router = ref.read(appRouterProvider);
    _paymentSubscription = ref.listenManual<OfflinePaymentState>(
      offlinePaymentControllerProvider,
      (previous, next) {
        final hadIncomingRequest = previous?.incomingRequest != null;
        final hasIncomingRequest = next.incomingRequest != null;
        if (!hadIncomingRequest && hasIncomingRequest) {
          _router.go(RoutePaths.payConfirm);
        }
      },
    );
  }

  @override
  void dispose() {
    _paymentSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'TNG Offline Wallet',
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}

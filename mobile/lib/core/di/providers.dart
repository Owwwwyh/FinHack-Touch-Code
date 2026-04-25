import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../connectivity/connectivity_service.dart';
import '../crypto/jws_signer.dart';
import '../crypto/native_keystore.dart';
import '../nfc/nfc_session.dart';
import '../../data/api/wallet_api.dart';
import '../../data/api/devices_api.dart';
import '../../data/api/tokens_api.dart';
import '../../data/api/score_api.dart';
import '../../data/db/app_db.dart';
import '../../data/ml/credit_scorer.dart';
import '../../domain/usecases/pay_offline.dart';
import '../../domain/usecases/receive_offline.dart';
import '../../domain/usecases/settle_pending.dart';
import '../../domain/usecases/refresh_score.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  ));
  dio.interceptors.add(AuthInterceptor(ref));
  return dio;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((_) {
  return const FlutterSecureStorage();
});

final dbProvider = Provider<AppDb>((_) => AppDb()));

final connectivityProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final keystoreProvider = Provider<NativeKeystore>((_) => NativeKeystore());

final jwsSignerProvider = Provider<JwsSigner>((ref) {
  return JwsSigner(keystore: ref.watch(keystoreProvider));
});

final nfcSessionProvider = Provider<NfcSession>((_) => NfcSession());

final walletApiProvider = Provider<WalletApi>((ref) {
  return WalletApi(ref.watch(dioProvider));
});

final devicesApiProvider = Provider<DevicesApi>((ref) {
  return DevicesApi(ref.watch(dioProvider));
});

final tokensApiProvider = Provider<TokensApi>((ref) {
  return TokensApi(ref.watch(dioProvider));
});

final scoreApiProvider = Provider<ScoreApi>((ref) {
  return ScoreApi(ref.watch(dioProvider));
});

final creditScorerProvider = Provider<CreditScorer>((_) => CreditScorer());

final payOfflineProvider = Provider<PayOffline>((ref) {
  return PayOffline(
    jwsSigner: ref.watch(jwsSignerProvider),
    nfcSession: ref.watch(nfcSessionProvider),
    outboxDao: ref.watch(dbProvider).outboxDao,
  );
});

final receiveOfflineProvider = Provider<ReceiveOffline>((ref) {
  return ReceiveOffline(
    inboxDao: ref.watch(dbProvider).inboxDao,
  );
});

final settlePendingProvider = Provider<SettlePending>((ref) {
  return SettlePending(
    tokensApi: ref.watch(tokensApiProvider),
    outboxDao: ref.watch(dbProvider).outboxDao,
  );
});

final refreshScoreProvider = Provider<RefreshScore>((ref) {
  return RefreshScore(
    scoreApi: ref.watch(scoreApiProvider),
    creditScorer: ref.watch(creditScorerProvider),
    balanceCacheDao: ref.watch(dbProvider).balanceCacheDao,
  );
});

class AuthInterceptor extends Interceptor {
  final Ref ref;
  AuthInterceptor(this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

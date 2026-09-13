import 'package:get_it/get_it.dart';

import '../../data/api/biotime_api_client.dart';
import '../../features/auth/auth_cubit.dart';
import '../config/api_url_resolver.dart';
import '../locale/locale_cubit.dart';
import '../storage/session_storage.dart';

final sl = GetIt.instance;

void configureDependencies() {
  sl.registerLazySingleton(SessionStorage.new);
  sl.registerLazySingleton(BioTimeApiClient.new);
  sl.registerLazySingleton(() => LocaleCubit(sl<SessionStorage>()));
  sl.registerLazySingleton(
    () => AuthCubit(api: sl<BioTimeApiClient>(), session: sl<SessionStorage>()),
  );
}

/// Call before runApp — pins API to localhost for local dev builds.
Future<void> bootstrapLocalApi() async {
  final url = ApiUrlResolver.effectiveUrl;
  api.configure(baseUrl: url);
  if (ApiUrlResolver.shouldPinLocalhost) {
    await session.saveBaseUrl(url);
  }
}

BioTimeApiClient get api => sl<BioTimeApiClient>();
SessionStorage get session => sl<SessionStorage>();

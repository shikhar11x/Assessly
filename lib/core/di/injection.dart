import 'package:get_it/get_it.dart';

import '../network/api_client.dart';

final GetIt sl = GetIt.instance;

Future<void> setupDependencies() async {
  if (!sl.isRegistered<ApiClient>()) {
    sl.registerLazySingleton<ApiClient>(ApiClient.new);
  }
}
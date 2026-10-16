import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/core/config/app_mode.dart';
import 'package:youwell/data/repositories/local_wellness_repository.dart';
import 'youwell_app.dart';
import 'authenticated_app.dart';

/// Connect storage and application state once, before rendering any screen.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  if (AppEnvironment.authEnabled) {
    runApp(AuthenticatedApp(preferences: preferences));
    return;
  }
  final localRepository = LocalWellnessRepository(
    preferences,
    storageKey: storageKeyForSurface(AppEnvironment.storageKey, appSurface),
  );
  final resetLocalData = kIsWeb && Uri.base.queryParameters['reset'] == '1';
  if (resetLocalData) await localRepository.clear();
  final controller = WellnessController(
    saved: resetLocalData ? null : await localRepository.read(),
    persist: localRepository.write,
  );
  runApp(YouWellApp(controller: controller));
}

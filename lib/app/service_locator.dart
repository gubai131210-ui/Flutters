import 'package:get_it/get_it.dart';

import '../core/data/database/app_database.dart';
import '../core/models/fragment_models.dart';
import '../core/repositories/fragment_repository.dart';
import '../core/services/app_services.dart';
import '../core/services/audio_coordinator.dart';
import '../core/services/context_feature_scorer.dart';
import '../core/stores/fragment_store.dart';
import '../core/stores/tag_usage_store.dart';
import '../core/theme/palette_controller.dart';
import '../features/shell/presentation/app_view_models.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  if (getIt.isRegistered<AppDatabase>()) {
    return;
  }

  getIt
    ..registerLazySingleton<AppDatabase>(AppDatabase.new)
    ..registerLazySingleton<DataCatalogService>(DataCatalogService.new)
    ..registerLazySingleton<PermissionService>(PermissionService.new)
    ..registerLazySingleton<TfliteTagModelService>(TfliteTagModelService.new)
    ..registerLazySingleton<AppPreferencesService>(AppPreferencesService.new)
    ..registerLazySingleton<MediaStorageService>(MediaStorageService.new)
    ..registerLazySingleton<AudioPlaybackService>(AudioPlaybackService.new)
    ..registerLazySingleton<FragmentMediaAudioService>(FragmentMediaAudioService.new)
    ..registerLazySingleton<PlaybackPlanner>(PlaybackPlanner.new)
    ..registerLazySingleton<WeatherSnapshotService>(WeatherSnapshotService.new)
    ..registerLazySingleton<ImportPickerService>(ImportPickerService.new)
    ..registerLazySingleton<ContextFeatureScorer>(ContextFeatureScorer.new)
    ..registerLazySingleton<TagUsageStore>(TagUsageStore.new)
    ..registerLazySingleton<FeelingTagService>(
      () => FeelingTagService(
        getIt<DataCatalogService>(),
        getIt<TfliteTagModelService>(),
        getIt<ContextFeatureScorer>(),
        getIt<TagUsageStore>(),
      ),
    )
    ..registerLazySingleton<FragmentRepository>(
      () => FragmentRepository(
        getIt<AppDatabase>(),
        getIt<DataCatalogService>(),
        getIt<FeelingTagService>(),
      ),
    )
    ..registerLazySingleton<FragmentStore>(
      () => FragmentStore(getIt<FragmentRepository>()),
    )
    ..registerLazySingleton<AudioCoordinator>(
      () => AudioCoordinator(
        getIt<AudioPlaybackService>(),
        getIt<FragmentMediaAudioService>(),
        getIt<MediaStorageService>(),
      ),
    )
    ..registerLazySingleton<PaletteController>(
      () => PaletteController(getIt<AppPreferencesService>()),
    )
    ..registerLazySingleton<ShellViewModel>(
      () => ShellViewModel(
        getIt<MediaStorageService>(),
        getIt<AppPreferencesService>(),
      ),
    )
    ..registerFactory<HomeViewModel>(
      () => HomeViewModel(
        getIt<FragmentStore>(),
        getIt<DataCatalogService>(),
        getIt<WeatherSnapshotService>(),
        getIt<AppPreferencesService>(),
      ),
    )
    ..registerFactory<PlayerViewModel>(
      () => PlayerViewModel(
        getIt<FragmentStore>(),
        getIt<PlaybackPlanner>(),
        getIt<AudioCoordinator>(),
      ),
    )
    ..registerFactory<CalendarViewModel>(
      () => CalendarViewModel(
        getIt<FragmentStore>(),
        getIt<MediaStorageService>(),
      ),
    )
    ..registerFactory<CaptureViewModel>(
      () => CaptureViewModel(
        getIt<FragmentRepository>(),
        getIt<FragmentStore>(),
        getIt<MediaStorageService>(),
        getIt<PermissionService>(),
        getIt<WeatherSnapshotService>(),
        RecordingService(),
        getIt<ImportPickerService>(),
        getIt<AppPreferencesService>(),
        getIt<DataCatalogService>(),
        getIt<TfliteTagModelService>(),
        getIt<FeelingTagService>(),
        getIt<TagUsageStore>(),
      ),
    )
    ..registerFactory<SearchViewModel>(
      () => SearchViewModel(
        getIt<FragmentStore>(),
        getIt<DataCatalogService>(),
      ),
    )
    ..registerFactory<SettingsViewModel>(
      () => SettingsViewModel(
        getIt<MediaStorageService>(),
        getIt<TfliteTagModelService>(),
        getIt<ImportPickerService>(),
        getIt<AppPreferencesService>(),
        getIt<ShellViewModel>(),
        getIt<DataCatalogService>(),
        getIt<FeelingTagService>(),
        getIt<AudioCoordinator>(),
      ),
    );

  await getIt<DataCatalogService>().load();
  final prefsData = await getIt<AppPreferencesService>().load();
  final rawCustom = (prefsData['customTags'] as List<dynamic>? ?? const <dynamic>[])
      .map((dynamic item) => FeelingTagDefinition.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
  getIt<DataCatalogService>().setCustomTags(rawCustom);

  await getIt<TfliteTagModelService>().warmUp();
  await getIt<TagUsageStore>().warmUp();
  await getIt<FragmentRepository>().ensureSeedData();
  // Prime the shared store once so first-frame Home has data.
  await getIt<FragmentStore>().ensureLoaded();

  // Wire night-mute: when the palette flips into the 22:00–07:00 window,
  // lower the BGM ceiling so the app does not stay loud at night.
  final palette = getIt<PaletteController>();
  final audio = getIt<AudioCoordinator>();
  void syncNightCeiling() {
    audio.setBgmCeiling(palette.nightMuted ? 0.45 : 0.88);
  }
  syncNightCeiling();
  palette.addListener(syncNightCeiling);
}

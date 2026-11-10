import 'package:tripytravy_core/tripytravy_core.dart';

class HexagonalDiContainer {
  final AttachmentProcessorPort attachmentProcessor;
  final AttachmentStoragePort attachmentStorage;
  final ContainerCipherPort containerCipher;
  final TripRepositoryPort tripRepository;
  final RouteProviderPort routeProvider;
  final ScheduleConflictPolicy schedulePolicy;
  final TemplateSanitizerPolicy sanitizerPolicy;

  late final ManageTripScheduleUseCase manageTripScheduleUseCase;
  late final AttachMediaOrVoucherUseCase attachMediaUseCase;
  late final ExportTripContainerUseCase exportTripUseCase;
  late final ImportTripContainerUseCase importTripUseCase;

  HexagonalDiContainer({
    AttachmentProcessorPort? attachmentProcessor,
    AttachmentStoragePort? attachmentStorage,
    ContainerCipherPort? containerCipher,
    TripRepositoryPort? tripRepository,
    RouteProviderPort? routeProvider,
    ScheduleConflictPolicy? schedulePolicy,
    TemplateSanitizerPolicy? sanitizerPolicy,
  })  : attachmentProcessor = attachmentProcessor ?? const CompositeAttachmentRegistry(),
        attachmentStorage = attachmentStorage ?? CasAttachmentStorageAdapter(),
        containerCipher = containerCipher ?? const TtrvContainerCipherAdapter(),
        tripRepository = tripRepository ?? InMemoryTripRepositoryAdapter(),
        routeProvider = routeProvider ?? const GeodesicRouteProviderAdapter(),
        schedulePolicy = schedulePolicy ?? const ScheduleConflictPolicy(),
        sanitizerPolicy = sanitizerPolicy ?? const TemplateSanitizerPolicy() {
    manageTripScheduleUseCase = ManageTripScheduleUseCase(
      schedulePolicy: this.schedulePolicy,
    );
    attachMediaUseCase = AttachMediaOrVoucherUseCase(
      processor: this.attachmentProcessor,
      storage: this.attachmentStorage,
    );
    exportTripUseCase = ExportTripContainerUseCase(
      storage: this.attachmentStorage,
      cipher: this.containerCipher,
      sanitizer: this.sanitizerPolicy,
    );
    importTripUseCase = ImportTripContainerUseCase(
      storage: this.attachmentStorage,
      cipher: this.containerCipher,
    );
  }
}

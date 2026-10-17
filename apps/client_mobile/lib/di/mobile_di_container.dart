import 'package:tripytravy_core/tripytravy_core.dart';

class MobileDiContainer {
  final AttachmentStoragePort attachmentStorage;
  final ContainerCipherPort containerCipher;
  final TripRepositoryPort tripRepository;

  late final ImportTripContainerUseCase importTripUseCase;

  MobileDiContainer({
    AttachmentStoragePort? attachmentStorage,
    ContainerCipherPort? containerCipher,
    TripRepositoryPort? tripRepository,
  })  : attachmentStorage = attachmentStorage ?? CasAttachmentStorageAdapter(),
        containerCipher = containerCipher ?? const TtrvContainerCipherAdapter(),
        tripRepository = tripRepository ?? InMemoryTripRepositoryAdapter() {
    importTripUseCase = ImportTripContainerUseCase(
      storage: this.attachmentStorage,
      cipher: this.containerCipher,
    );
  }
}

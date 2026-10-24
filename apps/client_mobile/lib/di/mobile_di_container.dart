import 'dart:io';
import 'package:tripytravy_core/tripytravy_core.dart';

class MobileDiContainer {
  final AttachmentStoragePort attachmentStorage;
  final ContainerCipherPort containerCipher;
  final TripRepositoryPort tripRepository;
  final ChecklistRepositoryPort checklistRepository;
  final MobileTripManagerService tripManager;

  late final ImportTripContainerUseCase importTripUseCase;

  MobileDiContainer({
    AttachmentStoragePort? attachmentStorage,
    ContainerCipherPort? containerCipher,
    TripRepositoryPort? tripRepository,
    ChecklistRepositoryPort? checklistRepository,
    MobileTripManagerService? tripManager,
  })  : attachmentStorage = attachmentStorage ?? CasAttachmentStorageAdapter(),
        containerCipher = containerCipher ?? const TtrvContainerCipherAdapter(),
        tripRepository = tripRepository ?? InMemoryTripRepositoryAdapter(),
        checklistRepository = checklistRepository ??
            FileChecklistRepositoryAdapter(baseDirectory: Directory.systemTemp),
        tripManager = tripManager ??
            MobileTripManagerService(
              tripRepository: tripRepository ?? InMemoryTripRepositoryAdapter(),
              attachmentStorage:
                  attachmentStorage ?? CasAttachmentStorageAdapter(),
              checklistRepository: checklistRepository ??
                  FileChecklistRepositoryAdapter(
                      baseDirectory: Directory.systemTemp),
              cipher: containerCipher ?? const TtrvContainerCipherAdapter(),
            ) {
    importTripUseCase = ImportTripContainerUseCase(
      storage: this.attachmentStorage,
      cipher: this.containerCipher,
    );
  }

  /// Convenient persistent factory targeting local application support directory.
  factory MobileDiContainer.persistent(Directory baseDirectory) {
    final tripRepo = FileTripRepositoryAdapter(baseDirectory: baseDirectory);
    final storage = FileCasAttachmentStorageAdapter(
      storageDirectory: Directory('${baseDirectory.path}/blobs'),
    );
    final checklistRepo =
        FileChecklistRepositoryAdapter(baseDirectory: baseDirectory);
    const cipher = TtrvContainerCipherAdapter();

    final manager = MobileTripManagerService(
      tripRepository: tripRepo,
      attachmentStorage: storage,
      checklistRepository: checklistRepo,
      cipher: cipher,
    );

    return MobileDiContainer(
      tripRepository: tripRepo,
      attachmentStorage: storage,
      checklistRepository: checklistRepo,
      containerCipher: cipher,
      tripManager: manager,
    );
  }
}

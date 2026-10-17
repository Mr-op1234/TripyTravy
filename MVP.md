# TripyTravy — Hexagonal MVP Specification & Build Guidebook

## 1. Hexagonal Architecture Overview (Ports & Adapters)

TripyTravy's MVP is structured around a strict **Hexagonal (Ports & Adapters) Architecture** so that **Core Trip Business Logic** remains completely isolated from **Variable Attachment Logics**, cryptographic runtimes, database engines, and UI frameworks.

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                         DRIVING ADAPTERS (Inbound UI/CLI)                     │
│  • agent_desktop (Flutter 3-Column Creator)                                   │
│  • client_mobile (Flutter Read-Only Timeline & Wallet Viewer)                 │
└───────────────────────────────────────┬───────────────────────────────────────┘
                                        │ Calls Inbound Ports (Use Cases)
                                        ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                   HEXAGONAL DOMAIN & APPLICATION CORE                         │
│                                                                               │
│  1. Pure Domain Entities & Value Objects:                                     │
│     • TripPackage, ItineraryDay, ItineraryEvent (6 Event Types)               │
│     • AttachmentDescriptor (assetId, category, visibility, sha256, byteSize)  │
│     • RoutePath, GeofenceArea, AttractionPoi, TravelerProfile                 │
│                                                                               │
│  2. Domain Policies (Zero External Dependencies):                             │
│     • TemplateSanitizerPolicy (strips PRIVATE_BOOKING vouchers & PII)         │
│     • ScheduleChronologyPolicy (validates IANA timezones & overlaps)          │
│                                                                               │
│  3. Inbound Driving Ports (Use Cases):                                        │
│     • ManageTripScheduleUseCase        • AttachMediaOrVoucherUseCase          │
│     • ExportTripContainerUseCase       • ImportTripContainerUseCase           │
│                                                                               │
│  4. Outbound Driven Ports (Interfaces):                                       │
│     • AttachmentProcessorPort          • AttachmentStoragePort                │
│     • ContainerCipherPort              • TripRepositoryPort                   │
└───────┬────────────────────────┬──────────────────────┬───────────────────────┘
        │                        │                      │
        ▼                        ▼                      ▼
┌──────────────────────┐ ┌────────────────────┐ ┌───────────────────────────────┐
│ VARIABLE ATTACHMENT  │ │ ATTACHMENT STORAGE │ │ CRYPTO & PERSISTENCE ADAPTERS │
│ PROCESSOR ADAPTERS   │ │ ADAPTERS           │ │                               │
│ • LossyPhotoWebp     │ │ • CasFileSystem    │ │ • RustNativeFfiCipherAdapter  │
│ • LosslessQrTicket   │ │   (SHA-256 Dedupe) │ │   (tripytravy_native TTRV v1) │
│ • PdfVoucherInspector│ │ • TtrvStreamPacker │ │ • SqliteTripRepositoryAdapter │
│ • PmTilesMapSlice    │ │ • InMemoryBlobStore│ │ • GeodesicOfflineRouteAdapter │
└──────────────────────┘ └────────────────────┘ └───────────────────────────────┘
```

---

## 2. Monorepo Structure Implemented in This Repository

```
TripyTravy/
├── Cargo.toml                                   # Rust workspace manifest
├── pubspec.yaml                                 # Dart/Flutter workspace manifest
├── architecture.md                              # Hexagonal System Architecture & TTRV v1 Spec
├── prd.md                                       # Product Requirements Document
├── MVP.md                                       # Hexagonal MVP Guidebook
├── packages/
│   ├── tripytravy_native/                       # [DRIVEN ADAPTER - RUST] TTRV v1 Crypto & Framing
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── error.rs                         # TtError enum
│   │       ├── seed.rs                          # 4-shard obfuscated seed reconstruction + Zeroize
│   │       ├── crypto.rs                        # HKDF-SHA256, Argon2id PIN KDF, AES-256-GCM + 40B AAD
│   │       ├── pack.rs                          # TTRV v1 40B header + zstd + inner asset stream
│   │       └── lib.rs                           # FFI exports & cryptographic test suite
│   │
│   └── tripytravy_core/                         # [HEXAGONAL CORE + PORTS + ADAPTERS - DART]
│       ├── pubspec.yaml
│       ├── proto/
│       │   └── itinerary.proto                  # Canonical Protobuf v3 wire schema
│       └── lib/
│           ├── tripytravy_core.dart             # Barrel export
│           ├── domain/                          # [INSIDE HEXAGON — PURE BUSINESS LOGIC]
│           │   ├── entities/
│           │   │   ├── attachment_descriptor.dart
│           │   │   ├── itinerary_event.dart
│           │   │   └── trip_package.dart
│           │   ├── policies/
│           │   │   ├── template_sanitizer_policy.dart
│           │   │   └── schedule_conflict_policy.dart
│           │   ├── ports/
│           │   │   ├── outbound/
│           │   │   │   ├── attachment_processor_port.dart
│           │   │   │   ├── attachment_storage_port.dart
│           │   │   │   ├── container_cipher_port.dart
│           │   │   │   ├── trip_repository_port.dart
│           │   │   │   └── route_provider_port.dart
│           │   └── usecases/
│           │       ├── attach_media_or_voucher_usecase.dart
│           │       ├── manage_trip_schedule_usecase.dart
│           │       ├── export_trip_container_usecase.dart
│           │       └── import_trip_container_usecase.dart
│           └── adapters/                        # [OUTSIDE HEXAGON — VARIABLE ADAPTERS]
│               └── outbound/
│                   ├── attachments/
│                   │   ├── composite_attachment_registry.dart
│                   │   ├── lossy_photo_webp_adapter.dart
│                   │   ├── lossless_barcode_ticket_adapter.dart
│                   │   ├── pdf_voucher_inspector_adapter.dart
│                   │   ├── pmtiles_map_slice_adapter.dart
│                   │   └── cas_attachment_storage_adapter.dart
│                   ├── crypto/
│                   │   └── ttrv_container_cipher_adapter.dart
│                   ├── persistence/
│                   │   └── in_memory_trip_repository_adapter.dart
│                   └── routing/
│                       └── geodesic_route_provider_adapter.dart
│
├── apps/
│   ├── agent_desktop/                           # [DRIVING ADAPTER] Desktop Trip Creator MVP
│   │   ├── pubspec.yaml
│   │   └── lib/
│   │       ├── main.dart
│   │       ├── di/hexagonal_di_container.dart
│   │       └── ui/creator_workspace_screen.dart
│   ├── client_mobile/                           # [DRIVING ADAPTER] Mobile Read-Only Trip Viewer MVP
│   │   ├── pubspec.yaml
│   │   └── lib/
│   │       ├── main.dart
│   │       ├── di/mobile_di_container.dart
│   │       └── ui/traveler_viewer_screen.dart
│   └── mvp_web_workbench/                       # Interactive Local Web Workbench (Creator + Viewer)
│       └── index.html
└── tools/
    └── hexagonal_mvp_engine.py                  # Executable Reference Engine & E2E Verification Suite
```

---

## 3. How the Hexagonal Attachment Pipeline Works End-to-End

1. **Creator Attaches a File in UI (`agent_desktop`)**:
   * The UI passes a `RawAttachmentInput(filename, mimeType, category, rawBytes)` to `AttachMediaOrVoucherUseCase.execute(...)`.
2. **Use Case Delegates to `AttachmentProcessorPort`**:
   * `CompositeAttachmentRegistry` selects the concrete strategy adapter based on `(mimeType, category)`:
     * `PHOTO_GALLERY` $\rightarrow$ `LossyPhotoWebpAdapter` strips EXIF metadata and optimizes dimensions.
     * `BOARDING_PASS` (image) $\rightarrow$ `LosslessBarcodeTicketAdapter` preserves crisp 1:1 contrast for QR/Aztec scanners.
     * `BOARDING_PASS` / `HOTEL_VOUCHER` (`application/pdf`) $\rightarrow$ `PdfVoucherInspectorAdapter` validates `%PDF-` magic header and EOF trailer and tags visibility as `PRIVATE_BOOKING`.
     * `OFFLINE_MAP_SLICE` (`application/vnd.pmtiles`) $\rightarrow$ `PmTilesMapSliceAdapter` validates the `"PMTiles"` v3 header and tags visibility as `TEMPLATE_SAFE`.
3. **Use Case Delegates to `AttachmentStoragePort`**:
   * `CasAttachmentStorageAdapter` computes the 32-byte `SHA-256` digest, deduplicates identical blobs across events, and returns an immutable `AttachmentDescriptor`.
4. **Domain Attaches Descriptor to Event**:
   * The pure `ItineraryEvent` stores only the `AttachmentDescriptor`—completely unaware of filesystem paths, compression algorithms, or storage backends.
5. **Container Export (`ExportTripContainerUseCase`)**:
   * If `isTemplate == true`, `TemplateSanitizerPolicy` strips all `PRIVATE_BOOKING` attachments and traveler PII while keeping `TEMPLATE_SAFE` attachments.
   * Collects unique blobs from `AttachmentStoragePort`, builds the deterministic `[uint32_be proto_len][proto_bytes][asset_blobs]` stream, and seals it via `ContainerCipherPort` (`TTRV` v1 40-byte Header `AAD` + `HKDF-SHA256` / `Argon2id` + `AES-256-GCM` + `zstd`).

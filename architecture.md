# TripyTravy — Technical Architecture & System Specification (v2.1 — Hexagonal Architecture)

## 1. System Overview & Hexagonal Monorepo Architecture

TripyTravy is a **closed-source, proprietary, 100% free, privacy-first, self-hosted, offline-first, completely accountless, and unbranded** cross-platform travel itinerary platform. It operates on a decentralized peer-to-peer model funded voluntarily through **community donations (Ko-fi / Buy Me a Coffee)**.

To keep the core itinerary scheduling, validation, and trip lifecycle rules 100% independent of variable file formats, media codecs, storage engines, and cryptographic runtimes, TripyTravy is built on a strict **Hexagonal (Ports & Adapters) Architecture**:

* **Inside the Hexagon (Pure Domain & Application Core)**:
  * Contains zero dependencies on `dart:io`, filesystem paths, SQLite/Drift, image compression libraries, PDF parsers, MapLibre, or FFI bindings.
  * Models all attachments exclusively as immutable **`AttachmentDescriptor`** value objects (`assetId`, `filename`, `mimeType`, `category`, `visibilityPolicy`, `byteSize`, `sha256Checksum`).
  * Communicates with the outside world strictly through **Inbound (Driving) Ports** (Use Cases) and **Outbound (Driven) Ports** (Interfaces for Attachment Processing, Attachment Storage, Cryptographic Container Framing, Trip Persistence, and Route Calculation).
* **Outside the Hexagon (Variable Adapters)**:
  * **Driving (Primary) Adapters**: Flutter Desktop Creator UI (`agent_desktop`), Flutter Mobile Read-Only Viewer UI (`client_mobile`), OS Intent / WhatsApp `content://` Share-Sheet Receivers, and CLI / Automated Test Runners.
  * **Driven (Secondary) Adapters**:
    * **Variable Attachment Processor Adapters**: Pluggable strategy adapters for Lossy Photo Optimization (`WebP <=1920px`), Lossless QR/Barcode Boarding Pass Preservation, PDF Voucher Validation, Offline `PMTiles` Map Slice Inspection, and GPX Trail Parsing.
    * **Variable Attachment Storage Adapters**: Sandboxed Content-Addressable Filesystem (`SHA-256` deduplicated), `.tt` Deterministic Binary Stream Indexer, and In-Memory/WASM Ephemeral Store.
    * **Cryptographic Container Adapter**: Bridges to `tripytravy_native` (Rust FFI) for 40-byte `TTRV` Header `AAD` authentication, Split-Seed `HKDF-SHA256` + `Argon2id` key derivation, `AES-256-GCM`, and `Zstandard` compression.

```
                    ┌────────────────────────────────────────────────────────────┐
                    │                DRIVING (PRIMARY) ADAPTERS                  │
                    │  • agent_desktop UI (3-Column Creator, Drag & Drop)        │
                    │  • client_mobile UI (Read-Only Timeline, Map, Wallet)      │
                    │  • OS File Intent & WhatsApp content:// Stream Receiver    │
                    └─────────────────────────────┬──────────────────────────────┘
                                                  │ Calls Inbound Driving Ports
                                                  ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 HEXAGONAL CORE (tripytravy_core)                                │
│                                                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ INBOUND (DRIVING) PORTS — APPLICATION USE CASES                                           │  │
│  │  • ManageTripScheduleUseCase       • AttachMediaOrVoucherUseCase                          │  │
│  │  • CompileDayRoutesUseCase         • ExportTripContainerUseCase (Std / PIN / Template)    │  │
│  │  • ValidateTripIntegrityUseCase    • ImportTripContainerUseCase                           │  │
│  └──────────────────────────────────────────────┬────────────────────────────────────────────┘  │
│                                                 │ Orchestrates                                  │
│                                                 ▼                                               │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ PURE DOMAIN ENTITIES, VALUE OBJECTS & POLICIES (Zero I/O or Infrastructure Imports)       │  │
│  │  • TripPackage, ItineraryDay, ItineraryEvent (Flight, Lodging, Transport, Activity, etc.) │  │
│  │  • AttachmentDescriptor (Category, VisibilityPolicy: PrivateBooking vs TemplateSafe)      │  │
│  │  • IanaTimezone, GeoLocation, RoutePath, GeofenceArea, AttractionPoi                      │  │
│  │  • TemplateSanitizationPolicy & ChronologicalOverlapPolicy                                │  │
│  └──────────────────────────────────────────────┬────────────────────────────────────────────┘  │
│                                                 │ Depends Only on Abstract Outbound Interfaces  │
│                                                 ▼                                               │
│  ┌─────────────────────────┬────────────────────┴───┬──────────────────────┬─────────────────┐  │
│  │ AttachmentProcessorPort │ AttachmentStoragePort  │ ContainerCipherPort  │ TripRepoPort &  │  │
│  │ (Variable Media Logic)  │ (CAS Blob Dedupe/IO)   │ (TTRV Crypto/Framing)│ RouteProvider   │  │
│  └────────────┬────────────┴───────────┬────────────┴──────────┬───────────┴────────┬────────┘  │
└───────────────┼────────────────────────┼───────────────────────┼────────────────────┼───────────┘
                │                        │                       │                    │
                ▼                        ▼                       ▼                    ▼
┌───────────────────────────┐ ┌──────────────────────┐ ┌───────────────────┐ ┌────────────────────┐
│ VARIABLE ATTACHMENT       │ │ ATTACHMENT STORAGE   │ │ CRYPTO ADAPTERS   │ │ STORAGE & ROUTING  │
│ PROCESSOR ADAPTERS        │ │ ADAPTERS             │ │                   │ │ ADAPTERS           │
│ • LossyPhotoWebpAdapter   │ │ • CasFileSystemStore │ │ • RustNativeFfi   │ │ • DriftSqliteRepo  │
│ • LosslessQrTicketAdapter │ │ • TtrvStreamPacker   │ │   (tripytravy_    │ │ • InMemoryRepo     │
│ • PdfVoucherAdapter       │ │ • InMemoryBlobStore  │ │    native)        │ │ • OsrmHttpRouter   │
│ • PmTilesMapSliceAdapter  │ │                      │ │ • FallbackCipher  │ │ • GeodesicRouter   │
└───────────────────────────┘ └──────────────────────┘ └───────────────────┘ └────────────────────┘
```

### 1.1 Hexagonal Monorepo Directory Structure

```
TripyTravy/
├── Cargo.toml                                   # Rust workspace root
├── pubspec.yaml                                 # Dart/Flutter Melos workspace root
├── architecture.md                              # Technical Architecture & Hexagonal Spec (v2.1)
├── prd.md                                       # Product Requirements Document (v2.0)
├── MVP.md                                       # Hexagonal MVP Guidebook & Verification Playbook
├── packages/
│   ├── tripytravy_native/                       # [DRIVEN ADAPTER - RUST] Native Crypto & Framing Engine
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── error.rs                         # Typed cryptographic & framing error codes
│   │       ├── seed.rs                          # 4-shard obfuscated seed reconstruction + Zeroizing
│   │       ├── crypto.rs                        # HKDF-SHA256, Argon2id PIN KDF, AES-256-GCM + 40B AAD
│   │       ├── pack.rs                          # TTRV v1 40B header parser/writer & zstd framing
│   │       └── lib.rs                           # C-ABI & flutter_rust_bridge FFI exports
│   │
│   └── tripytravy_core/                         # [HEXAGONAL CORE + PORTS + ADAPTERS - DART]
│       ├── pubspec.yaml
│       ├── proto/
│       │   └── itinerary.proto                  # Canonical Protobuf v3 wire schema
│       └── lib/
│           ├── tripytravy_core.dart             # Public package barrel export
│           ├── domain/                          # [INSIDE HEXAGON — PURE BUSINESS LOGIC]
│           │   ├── entities/                    # Pure domain models (Trip, Day, Event, AttachmentDescriptor)
│           │   ├── value_objects/               # IanaTimezone, Sha256Digest, GeoCoordinate, MoneyCurrency
│           │   ├── policies/                    # TemplateSanitizerPolicy, ScheduleConflictPolicy
│           │   ├── ports/
│           │   │   ├── inbound/                 # Driving ports (Use Case interfaces)
│           │   │   └── outbound/                # Driven ports (AttachmentProcessorPort, AttachmentStoragePort,
│           │   │                                # ContainerCipherPort, TripRepositoryPort, RouteProviderPort)
│           │   └── usecases/                    # Pure application services orchestrating domain & outbound ports
│           └── adapters/                        # [OUTSIDE HEXAGON — PLUGGABLE INFRASTRUCTURE ADAPTERS]
│               ├── outbound/
│               │   ├── attachments/             # Variable Attachment Processors & CAS Storage Adapters
│               │   ├── crypto/                  # Rust FFI & TTRV v1 Binary Container Adapters
│               │   ├── persistence/             # Drift SQLite & In-Memory Trip Repository Adapters
│               │   └── routing/                 # OSRM Online & Geodesic Offline Route Adapters
│               └── serialization/               # Protobuf <-> Domain Entity Mappers
├── apps/
│   ├── agent_desktop/                           # [DRIVING ADAPTER] Flutter Desktop Trip Creator
│   ├── client_mobile/                           # [DRIVING ADAPTER] Flutter Mobile Read-Only Trip Viewer
│   └── dashboard_portal/                        # Static Distribution Web Hub & PWA Viewer
└── tools/
    └── hexagonal_mvp_verifier.py                # Executable E2E Hexagonal & TTRV v1 Verification Suite
```

---

## 2. Hexagonal Separation of Business Logic vs. Variable Attachment Logic

A core architectural requirement of TripyTravy is isolating **Trip Business Logic** from **Variable Attachment Logics**. In travel planning, attachments vary widely in format, size, privacy sensitivity, and transformation rules (e.g., lossy destination photos vs. lossless QR boarding passes vs. multi-page hotel PDF vouchers vs. embedded `.pmtiles` vector map slices).

### 2.1 Domain Layer Attachment Model (`domain/entities/attachment_descriptor.dart`)

The domain layer never touches raw files or media libraries. It operates exclusively on `AttachmentDescriptor`:

* **`AttachmentCategory` Enum**:
  * `BOARDING_PASS` (Flight/rail boarding passes with barcodes/QR codes — defaults to `PRIVATE_BOOKING`)
  * `HOTEL_VOUCHER` (Lodging reservation confirmations — defaults to `PRIVATE_BOOKING`)
  * `ACTIVITY_TICKET` (Museum/tour entry vouchers — defaults to `PRIVATE_BOOKING`)
  * `PHOTO_GALLERY` (Property, destination, or attraction imagery — defaults to `TEMPLATE_SAFE`)
  * `DINING_MENU` (Restaurant menus or dietary cards — defaults to `TEMPLATE_SAFE`)
  * `OFFLINE_MAP_SLICE` (Cropped `.pmtiles` vector tile archive — defaults to `TEMPLATE_SAFE`)
  * `GENERAL_ADVISORY` (Packing lists, visa guidelines — configurable visibility)
* **`AttachmentVisibility` Enum**:
  * `PRIVATE_BOOKING`: Automatically stripped by `TemplateSanitizerPolicy` when exporting a trip with `is_template = true`.
  * `TEMPLATE_SAFE`: Preserved when exporting a shared community template.

### 2.2 Outbound Attachment Ports (`domain/ports/outbound/`)

The Hexagon defines two decoupled outbound ports for attachments:

1. **`AttachmentProcessorPort` (Variable Ingestion & Transformation Strategy)**:
   * Inspects, validates, and transforms raw incoming bytes according to the attachment's `AttachmentCategory` and MIME type before storage.
   * Each concrete adapter implements:
     * `bool canHandle(String mimeType, AttachmentCategory category)`
     * `Future<ProcessedAttachment> process(RawAttachmentInput input)`
2. **`AttachmentStoragePort` (Content-Addressable Persistence & Deduplication)**:
   * Stores and retrieves processed binary blobs by their 32-byte `SHA-256` content hash.
   * If a creator attaches the same `Swiss_Travel_Pass.pdf` to 6 different train rides across Days 1–5, `AttachmentStoragePort` stores the binary blob **once** and links all 6 events to the same `AttachmentDescriptor` (`sha256Checksum`).

### 2.3 Concrete Variable Attachment Adapters (`adapters/outbound/attachments/`)

| Concrete Adapter | Handled Categories / MIME Types | Variable Processing Logic Isolated from Core |
| :--- | :--- | :--- |
| **`LossyPhotoWebpAdapter`** | `PHOTO_GALLERY` (`image/jpeg`, `image/png`, `image/webp`) | Strips EXIF GPS/camera metadata for privacy, downscales longest edge to `<= 1920px`, and re-encodes to `WebP` (quality 82) to keep `.tt` files small. |
| **`LosslessBarcodeTicketAdapter`** | `BOARDING_PASS`, `ACTIVITY_TICKET` (`image/png`, `image/jpeg`) | Preserves 100% sharp pixel contrast without lossy chroma subsampling so QR codes, Aztec codes, and PDF417 barcodes scan reliably at airport gates. |
| **`PdfVoucherInspectorAdapter`** | `BOARDING_PASS`, `HOTEL_VOUCHER`, `ACTIVITY_TICKET` (`application/pdf`) | Verifies `%PDF-` magic header, validates non-corrupt EOF trailer, enforces size budget (`<= 25 MB`), and tags visibility as `PRIVATE_BOOKING`. |
| **`PmTilesMapSliceAdapter`** | `OFFLINE_MAP_SLICE` (`application/vnd.pmtiles`) | Verifies `"PMTiles"` v3 127-byte header, extracts geographic bounding box (`min/max lat/lon`) and zoom bounds (`min/max zoom`), and tags visibility as `TEMPLATE_SAFE`. |
| **`CompositeAttachmentRegistry`** | All Categories (Chain of Responsibility) | Routes each incoming attachment to the matching specialized adapter without `AttachMediaOrVoucherUseCase` knowing which codec or validator ran. |

---

## 3. Proprietary `.tt` Binary Container Specification (`TTRV` v1)

The `.tt` file format is a custom, compressed, and authenticated-encrypted binary container implemented as an Outbound Driven Adapter (`TtrvBinaryContainerAdapter` + `tripytravy_native` Rust FFI).

### 3.1 Outer Binary Wire Layout (40-Byte Header + Encrypted Stream + 16-Byte GCM Tag)

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Magic: "TTRV" (4B)                      |  Bytes 0..3
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|       Version (2B)            |          Flags (2B)           |  Bytes 4..7
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|                  File Salt: Random Nonce (16B)                |  Bytes 8..23
|                                                               |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 Initialization Vector (IV) (12B)              |  Bytes 24..35
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                Ciphertext Length (uint32 BE) (4B)             |  Bytes 36..39
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|              AES-256-GCM Ciphertext Stream (Variable)         |  Bytes 40..40+N-1
|      [Zstandard Compressed: ProtoLength + Proto + Assets]     |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  AES-GCM Auth Tag (16B)                       |  Last 16 Bytes
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 3.2 Outer Header Field Definitions (40 Bytes Fixed — Authenticated via GCM AAD)

| Field Name | Offset | Length | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Magic Bytes** | `0` | 4 Bytes | ASCII (`0x54 0x54 0x52 0x56`) | Identifies the TripyTravy container (`"TTRV"`). |
| **Version** | `4` | 2 Bytes | `uint16` (Big Endian) | Container wire version (`0x0001` for v1.0). |
| **Flags** | `6` | 2 Bytes | `uint16` (Big Endian Bitmask) | `Bit 0 (0x0001)`: Zstandard (`zstd`), `Bit 1 (0x0002)`: `AES-256-GCM`, `Bit 2 (0x0004)`: `PinProtected`, `Bit 3 (0x0008)`: `EmbeddedMapSlice`, `Bit 4 (0x0010)`: `TemplateSanitized`. |
| **File Salt** | `8` | 16 Bytes | `[u8; 16]` | Cryptographically random per-export salt (`OsRng`). |
| **IV / Nonce** | `24` | 12 Bytes | `[u8; 12]` | 96-bit unique random nonce for `AES-256-GCM`. |
| **Ciphertext Length** | `36` | 4 Bytes | `uint32` (Big Endian) | Exact byte length `N` of the encrypted payload stream (excluding the 16-byte trailing Auth Tag). |
| **Ciphertext Body** | `40` | `N` Bytes | `[u8; N]` | `AES-256-GCM` ciphertext of the `zstd`-compressed inner payload. |
| **Auth Tag** | `40 + N` | 16 Bytes | `[u8; 16]` | 128-bit `AES-256-GCM` authentication tag covering both the 40-byte header (`AAD`) and the `N`-byte ciphertext body. |

### 3.3 Inner Uncompressed Stream Layout (Deterministic Asset Indexing)

```
+-----------------------------------------------------------------------+
| Protobuf Length: uint32 Big Endian (4 Bytes) = M                      |
+-----------------------------------------------------------------------+
| Serialized TripPackage Protobuf Message (M Bytes)                     |
|   • Contains all_assets[] table with relative byte_offset,            |
|     byte_size, sha256_checksum, category, and visibility              |
+-----------------------------------------------------------------------+
| Concatenated Deduplicated Asset Blobs (Sum of unique byte_size Bytes) |
|   • Asset 0 Bytes: [offset = 0,          length = asset[0].byte_size] |
|   • Asset 1 Bytes: [offset = size(0),    length = asset[1].byte_size] |
|   • ...                                                               |
+-----------------------------------------------------------------------+
```

---

## 4. Cryptographic Architecture & App-Only Security Model

### 4.1 Multi-Shard Secret Seed Reconstruction & Zeroization (`seed.rs`)
* `CompiledSecretSeed` is split across four non-contiguous compile-time 32-byte obfuscated shards (`SHARD_0..SHARD_3`).
* At runtime, `reconstruct_secret_seed()` combines the shards via nonlinear XOR, wrapping addition, and bit-rotation inside a stack-allocated `zeroize::Zeroizing<[u8; 32]>` buffer that automatically scrubs RAM upon scope exit.

### 4.2 Dual-Mode Dynamic Key Derivation (`crypto.rs`)
* **Standard App-Only Mode (`Flags & 0x0004 == 0`)**:
  $$\text{PRK} = \text{HKDF-SHA256-Extract}(\text{FileSalt}, \text{CompiledSecretSeed})$$
  $$\text{AES Key} = \text{HKDF-SHA256-Expand}(\text{PRK}, \text{"TripyTravy-V1-Payload"}, 32)$$
* **PIN-Protected Mode (`Flags & 0x0004 != 0`)**:
  $$\text{PinKey} = \text{Argon2id}(\text{UserPIN}, \text{FileSalt}, m=19456\text{ KiB}, t=2, p=1, L=32)$$
  $$\text{PRK} = \text{HKDF-SHA256-Extract}(\text{FileSalt}, \text{CompiledSecretSeed} \parallel \text{PinKey})$$
  $$\text{AES Key} = \text{HKDF-SHA256-Expand}(\text{PRK}, \text{"TripyTravy-V1-PinPayload"}, 32)$$

### 4.3 Header Authentication via AES-256-GCM AAD
* Bytes `0..40` of the `.tt` file are passed as `AAD` into `AES-256-GCM`. Any tampering with the header flags, version, salt, length, or ciphertext body fails GCM authentication before decompression.

---

## 5. Canonical Wire Schema (`itinerary.proto`)

`itinerary.proto` serves strictly as the **Serialization DTO schema** inside `adapters/serialization/`—the Hexagonal Domain maps between pure Domain Entities (`Trip`, `ItineraryEvent`, `AttachmentDescriptor`) and Protobuf DTOs at the boundary of the `TtrvBinaryContainerAdapter` and `DriftSqliteTripRepositoryAdapter`.

*(See `packages/tripytravy_core/proto/itinerary.proto` for the full schema including `AttachmentCategory`, `AttachmentVisibility`, `FlightDetails`, `LodgingDetails`, `TransportDetails`, `ActivityDetails`, `MealDetails`, `NoteDetails`, `RoutePath`, `GeofenceArea`, `AttractionPoi`, `TravelerProfile`, and `OfflineMapSlice`.)*

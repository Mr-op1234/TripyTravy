# TripyTravy — Product Requirements Document (PRD v2.0)

## 1. Executive Summary & Vision

### 1.1 Product Mission

TripyTravy is a **privacy-first, 100% free, self-hosted, decentralized, and accountless** travel itinerary creation and delivery platform. It is engineered to democratize professional travel planning for everyone—empowering everyday travelers, backpackers, family vacation planners, group leaders, independent tour guides, and boutique travel advisors alike.

TripyTravy operates on a pure **donation-supported community model** (funded voluntarily via Ko-fi, Buy Me a Coffee, and GitHub Sponsors). It rejects the recurring SaaS subscriptions ($40–$150/month), telemetry tracking, user lock-in, and feature paywalls of commercial platforms like Travefy or TripIt Pro. Travel planning belongs to everyone and should remain completely free, distraction-free, and private.

### 1.2 Core Value Proposition

* **100% Free for Everyone**: Both the Desktop Creator (`tripytravy_agent`) and Mobile Viewer (`tripytravy_client`) apps are completely free with zero feature paywalls, zero seat limits, and zero locked capabilities.
* **Voluntary Community-Funded (Ko-fi / Buy Me a Coffee)**: Revenue is generated strictly through voluntary appreciation tips from grateful planners and businesses, keeping the software aligned with traveler utility rather than corporate monetization.
* **Privacy-First & Zero-Account Architecture**: Neither the trip creator nor the traveler ever creates an account, registers an email, or logs in. There are no passwords, tracking cookies, analytics SDKs, or centralized user databases.
* **Pure & Unbranded Presentation**: TripyTravy contains no commercial watermarks, agency advertising, or corporate branding fields. Every itinerary is rendered in a clean, distraction-free format focused 100% on the schedule, destination, and traveler experience.
* **Direct Multi-Platform Distribution**: Application binaries are downloaded directly from the official TripyTravy Dashboard web portal without signup gates:
  * **Windows**: `.exe` installer & portable build
  * **macOS**: `.dmg` disk image (Universal Binary: Apple Silicon & Intel)
  * **Linux**: `.deb` package & `.AppImage`
  * **Android**: `.apk` signed application package
  * **iOS**: `.ipa` via TestFlight / App Store + zero-install Offline PWA / WebAssembly Viewer on the Dashboard Portal
* **App-Only Decentralized `.tt` Container**: Completed trips are compiled into standalone, proprietary binary files (`.tt` / `TTRV` v1) sealed with `AES-256-GCM` authenticated encryption and dynamic `HKDF` key derivation in native Rust so they can only be opened inside official TripyTravy applications.
* **Optional PIN Confidentiality & Template Sanitization**: Creators can lock sensitive itineraries with an optional `Argon2id`-hardened PIN, or export a sanitized community template (`is_template = true`) that automatically strips traveler PII, PNR codes, and private voucher PDFs.
* **100% Offline Traveler Experience**: Travelers abroad can view timezone-accurate schedules, open boarding pass and hotel voucher PDFs, and navigate interactive street-level maps with routes, highlighted districts, and POI pins in airplane mode.

---

## 2. User Personas & End-to-End User Journeys

### 2.1 Target Personas

| Persona | Role | Key Needs & Pain Points | Primary Surface |
| :--- | :--- | :--- | :--- |
| **Everyday Traveler & Family Organizer** | Plans vacations for family, friend groups, road trips, or treks. | Wants a clean itinerary to share with co-travelers via WhatsApp without paying monthly SaaS fees or forcing friends to sign up for accounts. | TripyTravy Creator (Desktop) |
| **Independent Guide / Freelancer** | Organizes local treks, food walks, or custom private excursions. | Needs to deliver clear, unbranded schedules and voucher tickets with custom meeting points, highlighted walking zones, and offline maps. | TripyTravy Creator (Desktop) |
| **Travel Advisor / Tour Operator** | Plans complex multi-city or group trips for clients. | Needs fast desktop drag-and-drop scheduling, multi-timezone accuracy, media bundling, optional PIN protection, and template reuse. | TripyTravy Creator (Desktop) |
| **The Traveler / Guest** | End-user taking the trip. | Needs to tap a `.tt` file in WhatsApp or Mail and immediately view their schedule, vouchers, and offline map with zero login screens. | TripyTravy Client (Mobile / PWA) |

### 2.2 End-to-End User Journeys

#### Journey A: Personal / Group Trip Planning (Friend or Family Leader)
1. Alex plans a 5-day friends' trip to Switzerland and downloads TripyTravy Creator (`.exe` on Windows or `.dmg` on macOS) from the official Dashboard Portal with zero account signup.
2. Alex creates *"Swiss Alps Adventure 2026"*, sets currency to `CHF` and primary timezone to `Europe/Zurich`.
3. Alex adds outbound/return flights (with `Asia/Kolkata` departure and `Europe/Zurich` arrival timezones), scenic rail transfers (`Glacier Express`), chalet check-ins, and attaches rail pass PDFs.
4. Alex draws a highlighted walking zone around Zermatt Village, drops attraction pins, and toggles **Embed Offline Map Slice**.
5. Alex clicks **Export to `.tt` File** $\rightarrow$ generates `swiss_trip_2026.tt` (`4.1 MB`).
6. Alex shares `swiss_trip_2026.tt` in the group WhatsApp chat.
7. Friends tap the file on Android and iOS $\rightarrow$ the trip opens immediately offline with day-by-day timelines, boarding passes, and interactive offline maps.

#### Journey B: PIN-Protected Commercial / Private Delivery
1. A boutique tour organizer compiles an 8-day Kyoto cultural itinerary containing private ryokan confirmation codes, Shinkansen QR tickets, and emergency contact details.
2. During `.tt` export, the organizer enables **PIN Protection** (`123456`) so the file is encrypted with `Argon2id + HKDF` in addition to the native TripyTravy key.
3. The organizer sends `kyoto_autumn.tt` via email and shares the PIN over SMS.
4. The guests enter the PIN once upon importing the `.tt` file on their phones; the itinerary is stored securely for instant offline viewing throughout the trip.

#### Journey C: Sanitized Template Sharing (Community Exchange)
1. After returning from Rome, a traveler exports their trip with **Export as Sanitized Template** (`is_template = true`).
2. TripyTravy automatically strips all traveler names, emails, phone numbers, PNR confirmation codes, and attached voucher PDFs while keeping all daily schedules, restaurant recommendations, route polylines, and map polygons.
3. Another planner downloads `rome_3day_template.tt`, opens it in TripyTravy Creator on Desktop in full edit mode, adds their own flights and hotel bookings, and exports their personalized trip.

---

## 3. Scope & Functional Requirements

### 3.1 Module 1: Official TripyTravy Dashboard & Distribution Portal (`dashboard_portal`)

*Target: Modern Desktop & Mobile Web Browsers*

* **Public Download Hub (Zero Signup Wall)**: Direct, anonymous binary downloads for all official builds:
  * **Windows**: `TripyTravy-Agent-{version}-Setup.exe` & Portable `.zip`
  * **macOS**: `TripyTravy-Agent-{version}-Universal.dmg`
  * **Linux**: `tripytravy-agent_{version}_amd64.deb` & `.AppImage`
  * **Android**: `TripyTravy-Client-{version}-universal.apk`
  * **iOS**: Public TestFlight / App Store link + **Offline PWA / WebAssembly `.tt` Viewer** (enabling iOS users to open `.tt` files directly in Safari and "Add to Home Screen" for full offline access without sideloading barriers).
* **Release Integrity & Checksum Verification**: Displays SHA-256 checksums and code-signing verification instructions next to every download link.
* **Anonymous Auto-Update Feed**: Serves a static `/api/v1/releases/latest.json` endpoint consumed anonymously by desktop and mobile apps.
* **Voluntary Community Funding**: Features clean, non-intrusive *"Support TripyTravy on Ko-fi"* and *"Buy Me a Coffee"* links.
* **Community Template Gallery**: Hosts curated, PII-free sample `.tt` templates (e.g., 5-Day Swiss Alps, 7-Day Kyoto & Osaka, 4-Day Kashmir Valley) for immediate testing and inspiration.

---

### 3.2 Module 2: TripyTravy Creator — Desktop Application (`agent_desktop`)

*Target Platforms: Windows (`.exe`), macOS (`.dmg`), Linux (`.deb` / `.AppImage`)*

#### 3.2.1 Local Workspace & Trip Metadata (Zero Branding)
* **Pure Trip Focus**: Zero fields or UI slots for company logos, watermarks, or promotional links.
* **Trip Header Settings**: Trip Title, Subtitle, Destination Tags, Start Date, End Date, Primary IANA Timezone (e.g., `Europe/Zurich`), Currency Code (`ISO 4217`), and Primary Language (`BCP 47`).
* **Traveler Directory**: Local-only directory storing Full Name, Email, Phone, Passport Expiration Date (with `<6 months validity` warning badge relative to trip end date), Dietary Preferences, and Emergency Contact Name/Phone.
* **Polite Support Link**: Non-intrusive *"Support on Ko-fi"* link inside the About dialog.

#### 3.2.2 Day-by-Day Visual Builder
* **3-Column Desktop Layout**:
  1. **Left Pane**: Trip switcher, Day navigation list (`Day 1`..`Day N`), Traveler directory tab, and Asset manager tab.
  2. **Center Pane**: Vertical timeline canvas for the active day with interleaved event cards and transit route connectors (`RoutePath`).
  3. **Right Pane**: Context-sensitive inspector form for the selected event/route plus an interactive split/tabbed MapLibre canvas.
* **Drag-and-Drop Scheduling**: Reorder events within a day or move events across days with automatic chronological sorting and conflict detection (e.g., overlapping flight and activity times).
* **Explicit Timezone Locking**: Every timestamp stores an accompanying IANA timezone (`timezone_iana`) so departure, arrival, and reservation times always display in the destination's local wall-clock time regardless of where the laptop or phone is located.

#### 3.2.3 Six Canonical Event Component Types
1. **Flights (`FLIGHT`)**: Airline name, flight number, departure/arrival IATA codes, departure/arrival timestamps + distinct departure/arrival IANA timezones, terminal, gate, seat number, baggage allowance, PNR confirmation code, and boarding pass PDF/image attachments.
2. **Lodging (`LODGING`)**: Property name, geocoded address/coordinates, check-in/out timestamps + timezone, room type, meal plan, confirmation number, contact phone/email, property photo gallery, and booking voucher PDFs.
3. **Transportation (`TRANSPORT`)**: Transit mode (`RAIL`, `DRIVE`, `PUBLIC_TRANSIT`, `BOAT_FERRY`), carrier name, train/vehicle number, pickup/dropoff locations & timestamps, coach/seat number, pickup instructions, confirmation code, and ticket vouchers.
4. **Activities & Tours (`ACTIVITY`)**: Activity title, meeting point coordinates/address, start timestamp + timezone, duration in minutes, operator name & phone, dress code/notes, confirmation code, ticket vouchers, and photos.
5. **Food & Dining (`MEAL`)**: Restaurant name, location, reservation timestamp + timezone, duration, cuisine type, dress code, dietary notes, confirmation code, contact phone, and menu/reservation attachments.
6. **General Notes & Advisories (`NOTE`)**: Markdown-formatted notes with severity badges (`INFO`, `TIP`, `WARNING`, `CRITICAL`), category label (Packing, Visa, Emergency, Local Customs), interactive checklist items, and file attachments.

#### 3.2.4 Geospatial Planning & Route Compiler
* **Sequential Route Generation**: Connects consecutive events on a day (`Event A -> Event B`) using online OSRM/Valhalla routing (for driving, walking, cycling) or offline geodesic/manual polyline drawing (for flights, ferries, trains, and off-grid trails).
* **Baked Route Metrics**: Stores encoded polylines, distance (`distance_km`), travel duration (`duration_minutes`), transit mode, and navigation tips directly inside `RoutePath`.
* **Geofence Area & Zone Highlighting**: Polygon drawing tool allowing creators to highlight neighborhoods, walking zones, or parks with custom hex colors, opacity, and descriptions.
* **Attraction POI Catalog**: Categorized point-of-interest pins (`Viewpoint`, `Museum`, `Food`, `Shopping`, `Nature`) with opening hours, recommended duration, and auto-calculated straight-line/walking distance from the day's lodging.

#### 3.2.5 Media & Document Optimization Pipeline
* **Drag-and-Drop Asset Ingestion**: Accepts `JPEG`, `PNG`, `WebP`, and `PDF` files.
* **Automatic Image Optimization**: Re-encodes imported photos to `WebP` (or optimized `JPEG`) capped at `1920px` longest edge (`~120–250 KB` per photo) in memory before bundling.
* **SHA-256 Deduplication**: Identical PDFs or photos attached to multiple events (e.g., a multi-day rail pass PDF attached to 4 train rides) are stored once in the `.tt` binary blob table and referenced by `asset_id`.

#### 3.2.6 Export & Compilation Engine
* **`.tt` Container Export (`TTRV` v1)**:
  * **Standard Export**: Compiles Protobuf + deduplicated assets + Zstandard compression + `AES-256-GCM` encryption using `tripytravy_native` dynamic HKDF key derivation.
  * **PIN-Protected Export**: Adds `Argon2id` user PIN derivation (`Flags` Bit 2).
  * **Template Export**: Scrubs all traveler PII, confirmation codes, and private voucher PDFs (`Flags` Bit 4).
  * **Offline Map Slice Toggle**: Optionally embeds a cropped `.pmtiles` vector map slice (`Zoom 7–15`) for the trip's bounding box (`Flags` Bit 3).
* **Printable Vector PDF Export**: Generates a clean, multi-page vector PDF itinerary (with day-by-day schedules, confirmation table, emergency contacts, and QR/summary blocks) for paper printing.

---

### 3.3 Module 3: TripyTravy Client — Mobile Application (`client_mobile`)

*Target Platforms: Android (`.apk`), iOS (`.ipa` + Offline PWA Viewer)*

#### 3.3.1 Operating System File Association & WhatsApp Import (Zero Login)
* **Instant Boot**: Opens directly to the active trip or local trip library with zero login, onboarding walls, or account prompts.
* **Universal `.tt` File & Share-Sheet Handler**:
  * Handles direct `.tt` file taps from Files, Downloads, Telegram, and AirDrop.
  * Handles Android `content://` streams from WhatsApp and Gmail (where the URI path lacks a `.tt` extension) by inspecting `OpenableColumns.DISPLAY_NAME` and verifying the `"TTRV"` magic bytes.
* **Cryptographic Integrity & PIN Prompt**: Verifies the 40-byte header `AAD` and 16-byte `AES-GCM` authentication tag inside `tripytravy_native`. If `Flags` Bit 2 (`PinProtected`) is set, prompts the traveler for the trip PIN before unpacking.

#### 3.3.2 Traveler Interface & Timezone-Locked Timeline
* **Multi-Trip Switcher**: Manage Active, Upcoming, and Archived trips stored locally in Drift (SQLite).
* **Sticky Day Selector Bar**: Horizontal pill strip (`Day 1 · Oct 15`, `Day 2 · Oct 16`, ...) with instant scroll synchronization.
* **Semantic Event Cards**:
  * **Flights**: Indigo accent — displays IATA route badge (`CCU ➔ ZRH`), local departure/arrival times with explicit timezone badges, terminal/gate/seat pills, baggage allowance, PNR copy button, and 1-tap boarding pass PDF button.
  * **Lodging**: Emerald accent — displays check-in/out times, address with 1-tap map focus, room/meal plan, confirmation copy button, 1-tap phone dialer, photo carousel, and voucher PDF button.
  * **Transport**: Teal accent — displays mode icon, carrier/train number, coach/seat, pickup/dropoff times, and ticket voucher button.
  * **Activities**: Amber accent — displays start time, duration badge, meeting point map link, dress code, operator phone, and ticket voucher button.
  * **Meals**: Rose accent — displays reservation time, cuisine tag, dietary notes, and restaurant map pin.
  * **Notes**: Slate/Warning accent — renders markdown notes and interactive local checkboxes (e.g., packing checklist state saved locally on the phone).
* **Inter-Event Route Connectors**: Compact timeline connectors between cards showing transit mode icon, distance (`12.4 km`), travel duration (`25 min`), and a *"View Route on Map"* button.

#### 3.3.3 Integrated 3-Tier Offline Map & Route Interpreter
* **Zero-Network Map Rendering**: Renders the bundled global basemap (`Tier 1`), the trip's embedded or auto-cached `.pmtiles` street slice (`Tier 2`), and the `.tt` vector overlays (`Tier 3`) using MapLibre GL.
* **Day-Filtered Route & Polygon View**: Tapping any day highlights that day's sequential `RoutePath` polylines, numbered stop markers, `GeofenceArea` shaded zones, and `AttractionPoi` pins.
* **POI Bottom Sheet**: Tapping an attraction pin displays creator notes, category badge, opening hours, recommended duration, and distance from the day's hotel.

#### 3.3.4 Offline Media & Document Viewer
* **Native Offline PDF Reader**: Opens bundled boarding passes and vouchers from local sandbox storage in `<100ms` with pinch-to-zoom, page thumbnails, and system print/share support.
* **Offline High-Resolution Gallery**: Swipeable fullscreen image viewer for hotel and destination photos.

#### 3.3.5 Security & Read-Only Enforcement
* **Strict Read-Only Schedule**: Travelers cannot accidentally delete events, shift times, or alter booking confirmations on mobile (interactive state is limited to local packing/todo checkboxes).
* **Verified Integrity Badge**: Displays a subtle *"Verified TripyTravy Container"* badge confirming the `.tt` file passed `AES-256-GCM` authentication and per-asset `SHA-256` checks.

---

### 3.4 Module 4: Proprietary `.tt` Binary Container (`TTRV` v1)

* **Closed Binary Framing**: Custom 40-byte header (`TTRV` magic, version, flags, 16B salt, 12B IV, 4B length) + `AES-256-GCM` encrypted `zstd` stream + 16B GCM auth tag.
* **Header AAD Binding**: The 40-byte header is authenticated via GCM Additional Authenticated Data so header bit-flipping is rejected immediately.
* **Deterministic Asset Indexing**: Inner stream prefixes `uint32 proto_length` followed by `TripPackage` Protobuf and raw binary assets indexed by relative `byte_offset`, `byte_size`, and `sha256_checksum`.
* **Cross-Surface Compatibility**: Opens in full edit mode in `agent_desktop` and in read-only traveler mode in `client_mobile` and the Dashboard PWA viewer.

---

## 4. Non-Functional Requirements

### 4.1 Performance & Payload Budgets

| Metric | Target Requirement | Engineering Mechanism |
| :--- | :--- | :--- |
| **Geospatial Protobuf Overhead** | `< 100 KB` (`< 35 KB` typical for 1,000 route points + 20 polygons) | Precision-5 encoded polylines + Protobuf binary varints |
| **Standard `.tt` File Size** | `2 MB – 6 MB` (10-day trip, 8 WebP photos, 4 PDF vouchers, route logic) | Automatic WebP downscaling (`1920px`), SHA-256 asset deduplication, `zstd` level 6 compression |
| **Desktop `.tt` Compilation Time** | `< 2.0 seconds` for a 14-day trip on mid-range desktop hardware | Native Rust `zstd` + hardware AES-NI / ARMv8 Crypto extensions |
| **Mobile `.tt` Unpack & Render** | `< 800 ms` from file tap to interactive timeline on mid-tier phones | Streaming Rust FFI extraction + indexed `byte_offset` asset slicing |
| **Peak Unpack RAM Overhead** | `< 64 MB` even for large `50 MB` `.tt` files | Streamed asset extraction to sandbox disk rather than full in-memory cloning |

### 4.2 Complete Data Privacy & Zero Telemetry
* **Zero Network Analytics**: No Sentry, Firebase Crashlytics, Google Analytics, Mixpanel, or IP logging in any build.
* **Local Crash Diagnostics**: If an error occurs, the app writes a local diagnostic log that the user can optionally inspect and attach manually to a bug report.
* **100% Data Sovereignty**: All traveler PII remains strictly on the creator's desktop and the traveler's mobile device.

### 4.3 Security & Anti-Tampering
* **App-Only Container Access**: Standard archive tools (`7z`, `unzip`, `tar`), hex editors, and unauthorized scripts cannot unpack `.tt` files without the compiled Rust seed derivation logic.
* **Cryptographic Tamper Rejection**: Flipping even 1 bit in the 40-byte header, ciphertext payload, or 16-byte GCM tag aborts unpacking in Rust before decompression.
* **Memory Hygiene**: All reconstructed seed bytes, Argon2id outputs, HKDF PRKs, and AES keys are wrapped in `zeroize::Zeroizing` buffers and wiped immediately after use.

### 4.4 Reliability & Offline Autonomy
* **100% Airplane-Mode Functionality**: Once imported, every timeline card, timezone clock, PDF voucher, photo gallery, route polyline, geofence polygon, and cached/embedded map layer works with cellular and Wi-Fi radios turned completely off.
* **Crash-Safe Local Persistence**: Trips are stored in transactional **Drift (SQLite)** tables with atomic file writes for extracted assets.

---

## 5. Product Roadmap

* **Milestone 1 — Alpha MVP (`v0.1.0-alpha`)**:
  * Complete `tripytravy_native` Rust crate (`TTRV` v1 pack/unpack, split-seed HKDF, Argon2id PIN mode, AES-256-GCM with Header AAD, `zstd` compression, unit + tamper test suite).
  * Complete `tripytravy_core` Dart package (`itinerary.proto` v1, deterministic asset indexer, timezone utilities, validator, Drift SQLite storage).
  * Functional `agent_desktop` (Windows/macOS/Linux) supporting all 6 event types, day-by-day drag-and-drop builder, route/polygon map editor, PDF voucher & photo bundling, and `.tt` export/import.
  * Functional `client_mobile` (Android/iOS) supporting `.tt` file & WhatsApp import, read-only day timeline, offline PDF/photo viewer, and MapLibre route/polygon rendering.
* **Milestone 2 — Public Beta (`v0.2.0-beta`)**:
  * Embedded `.pmtiles` offline destination map slicing in `agent_desktop` + auto-caching on `client_mobile`.
  * Printable multi-page vector PDF itinerary export from `agent_desktop`.
  * Official `dashboard_portal` web hub hosting signed installers, SHA-256 checksums, sample `.tt` templates, Ko-fi integration, and the Offline PWA/WASM `.tt` viewer for iOS/Web.
* **Milestone 3 — v1.0 General Release**:
  * Anonymous background update checker via `/api/v1/releases/latest.json`.
  * Responsive Tablet/Mobile Creator mode (creating and editing `.tt` files directly on iPad/Android tablets).
* **Milestone 4 — Local P2P Sync (`v1.1+`)**:
  * Optional nearby Wi-Fi Direct / Local LAN QR-code transfer between desktop and mobile devices without internet or messaging apps.

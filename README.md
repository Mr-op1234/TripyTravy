# TripyTravy 🌍✈️

> **The World's First Decentralized, Privacy-First, Offline-First Travel Itinerary Planner.**

TripyTravy is a free, accountless, and unbranded cross-platform travel planning and itinerary management platform built with Flutter and Rust on a strict Hexagonal (Ports & Adapters) architecture.

---

## 📚 Documentation Index

The following specifications and engineering documents are available in the root repository:

| Document | Description |
| :--- | :--- |
| **[AgentLogs.md](AgentLogs.md)** | Step-by-step development logs detailing every user prompt, implementation action, and commit history. |
| **[architecture.md](architecture.md)** | Full technical architecture specification detailing Hexagonal design, domain entities, ports, adapters, and cryptographic container format (`.tt`). |
| **[prd.md](prd.md)** | Product Requirements Document outlining target users, core features, offline capabilities, and design principles. |
| **[MVP.md](MVP.md)** | Minimum Viable Product roadmap and milestone tracking. |

---

## 🏗️ Repository Architecture

TripyTravy is structured as a monorepo containing decoupled domain packages, native cryptographic cores, and presentation apps:

```
TripyTravy/
├── apps/
│   ├── agent_desktop/       # Flutter Desktop application (Windows, macOS, Linux)
│   └── client_mobile/       # Flutter Mobile application (Android, iOS)
├── packages/
│   ├── tripytravy_core/     # Hexagonal Core: Domain entities, ports, policies, and use cases
│   └── tripytravy_native/   # Rust Cryptographic Core (Argon2id, AES-256-GCM, Zstd compression)
├── AgentLogs.md             # Development logs (Steps 1 – 28+)
├── architecture.md          # System architecture & hexagonal diagram
├── MVP.md                   # MVP specification
├── prd.md                   # Product requirements document
└── README.md                # Project README & Quickstart
```

---

## 🚀 Quickstart: Running on Another Device

### Prerequisites

1. **Flutter SDK**: Version `>=3.47.0` (Dart `>=3.6.0`). Ensure `flutter doctor` passes.
2. **Desktop C++ Toolchain**:
   - **Windows**: Visual Studio 2022 with "Desktop development with C++" workload installed.
   - **macOS**: Xcode with Command Line Tools.
   - **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`.
3. **Rust Toolchain** *(Optional for core development / FFI)*: `cargo` and `rustc` (`1.75+`).

---

### Running the Desktop Application (`apps/agent_desktop`)

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Mr-op1234/TripyTravy.git
   cd TripyTravy
   ```

2. **Navigate to the Desktop app**:
   ```bash
   cd apps/agent_desktop
   ```

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Run the test suite**:
   ```bash
   flutter test
   ```

5. **Run the desktop app in debug mode**:
   ```bash
   flutter run -d windows
   # Or on macOS: flutter run -d macos
   # Or on Linux: flutter run -d linux
   ```

6. **Build a production Release executable**:
   ```bash
   flutter build windows
   ```
   The compiled executable will be located at:
   `apps/agent_desktop/build/windows/x64/runner/Release/agent_desktop.exe`

---

## ✨ Key Features Implemented

- **Edge-to-Edge Hero Banners**: Dynamic trip banners with local upload and web image URL previews.
- **Normalized SQLite Storage (3NF)**: Foreign-key connected relational persistence for trips, days, events, info cards, and file attachments.
- **Documents & Information Hub**: Vertical information cards with Google Maps link parsing, coordinates extraction, rich notes, and attachments.
- **Day-by-Day Itinerary Planner**: Organize events by days with custom titles, timings, maps locations, documents, and photo galleries.
- **Rich Description Editor**:
  - Live WYSIWYG formatting without exposed XML marks.
  - Keyboard shortcuts (`Ctrl+B`, `Ctrl+I`, `Ctrl+U`).
  - Text alignment controls (`Left`, `Center`, `Right`, `Justify`).
  - Interactive Visual Tables (add/remove rows and columns on the fly).
  - List formatting (bullet points, numbered lists with automatic newline continuation).
  - 3-Color Highlight Palette: Yellow (default), Light Red, and Navy Blue with hover color picker.
- **Image Upload Filter**: Strict restriction to image formats (`png`, `jpg`, `jpeg`, `webp`, `gif`, `bmp`, `heic`).
- **Smooth Inertial Scrolling**: Native mouse-wheel smoothing with cubic-bezier easing.

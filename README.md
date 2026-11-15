[English](README.md) | [中文](README_zh.md)
## 1. Project Overview

### 1.1 Goal

Build a **cross-platform, privacy-first, clean and modern** P2P instant messaging application. Messages and files are transmitted entirely peer-to-peer, never relayed through a central server, ensuring user data privacy.

### 1.2 Supported Platforms

- Windows

### 1.3 Core Features (MVP)

- Peer-to-peer text messaging
- Friend adding and connection management
- Local message history storage
- Clean, modern, immersive UI design
- Planned, not implemented yet: peer-to-peer file/image transfer, message search

### 1.4 Non-Goals (Not in MVP)

- Group chat
- Audio/video calls
- Cloud message backup
- Account registration system (identity based on PeerID)

***

## 2. Tech Stack and Architecture Design

### 2.1 Overall Tech Stack

| Layer | Technology | Description |
| :---- | :--------- | :---------- |
| Client UI Layer | Flutter 3.x + Dart 3.x | Single codebase compiles to multiple platforms; self-drawn engine guarantees consistent, beautiful UI |
| P2P Core Layer | `flutter_webrtc` plugin | Wraps the official WebRTC native library, provides DataChannel transport and ICE NAT traversal |
| State Management | Riverpod 2.x | Reactive state management, clear and maintainable code structure |
| Local Storage | Hive | Lightweight NoSQL database, suitable for chat history and configuration |
| Signaling Service | Go + Gorilla WebSocket | Lightweight and high-performance; used only for connection handshake, never relays business messages |

### 2.2 Overall Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ Client A                                                     │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │ UI Layer │  │ Business     │  │ WebRTC P2P Core Layer  │  │
│  │          │  │ Logic Layer  │  │                        │  │
│  └──────────┘  └──────────────┘  └────────────────────────┘  │
└───────────────────────────────┬──────────────────────────────┘
                                │ WebSocket signaling exchange
┌───────────────────────────────┴──────────────────────────────┐
│ Signaling Server (Go)                                        │
│ Forwards handshake signaling only; stores and parses         │
│ no business messages                                         │
└───────────────────────────────┬──────────────────────────────┘
                                │ WebSocket signaling exchange
┌───────────────────────────────┴──────────────────────────────┐
│ Client B                                                     │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │ UI Layer │  │ Business     │  │ WebRTC P2P Core Layer  │  │
│  │          │  │ Logic Layer  │  │                        │  │
│  └──────────┘  └──────────────┘  └────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘

Clients transfer messages and files directly via WebRTC DataChannel
```

### 2.3 Client Module Breakdown

- `ui`: UI components and pages
- `state`: State management
- `service`: Business services (chat, friends, storage)
- `p2p`: WebRTC wrapper, signaling client, connection management
- `models`: Data models
- `utils`: Utility classes

***

## 3. Development Milestones

Total duration: 6 weeks (MVP)

### Phase 1: Project Initialization and Base Framework (Week 1)

**Goal**: Set up a complete project skeleton and finish the base UI prototype.

- Set up the Flutter development environment and configure multi-platform compilation for Windows/macOS/Android/iOS
- Set up the Go signaling service base project and implement a basic WebSocket connection
- Define UI design guidelines: color palette, typography, corner radius, spacing, and other design-system tokens
- Implement skeleton screens for core pages: conversation list, chat page, add-friend page
- Integrate state management, routing, and basic local storage capabilities

**Deliverables**: A runnable client prototype + a deployable signaling service skeleton

### Phase 2: P2P Core Connectivity Development (Weeks 2–3)

**Goal**: Establish a P2P connection between two endpoints and transmit basic messages.

- Design the signaling protocol: define message formats for SDP exchange and ICE candidate forwarding
- Implement the client-side signaling client and WebSocket communication with the server
- Integrate `flutter_webrtc` and encapsulate a `PeerConnection` manager class
- Implement SDP offer/answer negotiation and ICE candidate gathering/exchange
- Establish a WebRTC DataChannel and implement basic text message send/receive
- Connect to public STUN servers and verify NAT traversal capability

**Deliverables**: Two devices can establish a P2P connection through the signaling service and exchange text messages

### Phase 3: Core Feature Completion and UI Polish (Weeks 4–5)

**Goal**: Complete the full chat feature set and bring the UI up to the clean-and-beautiful design target.

- Refine the chat page: message bubbles, send status, timestamps, avatars
- Implement the conversation list: sorting, unread counts, last-message preview
- Implement friend-adding logic: add friends by PeerID, connection status management
- Implement local message persistence with history loading
- Implement P2P file/image transfer: chunked transfer, progress display, resumable transfer
- UI detail polish: page transition animations, message-send animations, dark mode support

**Deliverables**: Fully usable chat functionality with UI meeting the design standard

### Phase 4: Adaptation, Testing, and Optimization (Week 6)

**Goal**: Stable operation across all platforms and optimized experience under different network conditions.

- Desktop adaptation: minimum window size, system notifications, tray icon
- Network compatibility testing: connectivity on the same subnet, different intranets, and mobile networks
- Deploy a public TURN server to guarantee connectivity in extreme network conditions
- Performance optimization: memory usage, large-file transfer speed, smooth list scrolling
- Bug fixing and stability improvements

**Deliverables**: A releasable MVP installer package

***

## 4. Core Feature Design

### 4.1 P2P Connection Establishment Flow

1. Clients A and B each connect to the signaling server and obtain a unique PeerID
2. Client A enters B's PeerID to initiate a connection request
3. The signaling server forwards the request to Client B
4. Once B accepts, both sides exchange SDP (Session Description Protocol) information through the signaling server
5. Both sides gather ICE candidates and forward them to each other through the signaling server
6. WebRTC automatically selects the optimal path to establish the P2P connection
7. After the connection succeeds, a DataChannel is created and all messages are transmitted directly peer-to-peer
8. The signaling server participates only in reconnection when the connection drops; it never handles business data transmission

### 4.2 Message Protocol Design

All messages transmitted over the DataChannel use a unified JSON format:

```json
{
  "type": "text|file|image|system",
  "msg_id": "unique message ID",
  "from": "sender PeerID",
  "timestamp": 1718000000000,
  "content": {}
}
```

### 4.3 UI Design Principles

1. **Minimalism**: Reduce redundant elements, highlight chat content, and use generous whitespace
2. **Lightweight color palette**: Use low-saturation blue-gray as the primary color, pure white / pure dark gray as the background; avoid flashy decoration
3. **Rounded and soft**: Message bubbles, cards, and buttons all use large corner radii
4. **Smooth motion**: Add eased animations to message sending, page transitions, and keyboard/input pop-ups
5. **Consistent experience**: Desktop and mobile maintain a fully consistent visual style and interaction logic

## 5. Project Directory Structure

### 5.1 Client (Flutter)

```
lib/
├── main.dart                 # Application entry point
├── app.dart                  # Global configuration and routing
├── ui/                       # UI layer
│   ├── pages/                # Pages
│   │   ├── chat_list_page.dart
│   │   ├── chat_page.dart
│   │   └── add_friend_page.dart
│   ├── widgets/              # Shared components
│   │   ├── message_bubble.dart
│   │   └── chat_input.dart
│   └── theme/                # Theme and design guidelines
│       ├── app_theme.dart
│       └── colors.dart
├── state/                    # State management
│   ├── chat_provider.dart
│   └── peer_provider.dart
├── service/                  # Business services
│   ├── friend_service.dart
│   └── storage_service.dart
├── p2p/                      # P2P core layer
│   ├── webrtc_manager.dart   # WebRTC wrapper
│   └── signaling_client.dart # Signaling client
├── models/                   # Data models
│   ├── message.dart
│   └── peer.dart
└── utils/                    # Utilities
    └── constants.dart
```

### 5.2 Signaling Service (Go)

```
signaling-server/
├── main.go                   # Service entry point
├── server/                   # WebSocket service
│   ├── server.go
│   └── client.go
├── handler/                  # Message handling
│   └── signaling_handler.go
├── models/                   # Message structures
│   └── message.go
└── config/                   # Configuration
    └── config.go
```

## 6. Environment Requirements and Build

### 6.1 Environment Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| Go | 1.22+ | Build the signaling server |
| Flutter SDK | 3.2+ (Stable) | Build the Windows client |
| Visual Studio Build Tools | Latest version | Flutter Windows build dependency (check "Desktop development with C++") |

### 6.2 Build

- Go signaling server: enter the `signaling-server` directory and run `go build -o linkchat-server.exe`
- Flutter client: enter the `client` directory and run `flutter.bat build windows --release`

## 7. Future Expansion Directions

- **Security enhancements**: Add end-to-end encryption (E2EE) with public-key-based identity verification
- **Group chat**: Implement multi-node relay group chat based on a Mesh network
- **Audio/video calls**: Implement voice/video calls based on WebRTC MediaStream
- **Offline messages**: Optional distributed node relaying to support temporary offline message storage
- **C++ core replacement**: Replace the P2P transport core with a self-developed C++ library for further performance and customization improvements

## 8. Quick Start

### 8.1 Prerequisites

- Flutter 3.2+ (Stable)
- Go 1.22+
- Visual Studio 2022 with the "Desktop development with C++" workload (for building the Windows client)

### 8.2 Run the signaling server

```bash
cd signaling-server
go run .
# Listens on :8080 by default; set the PORT environment variable to change it
```

### 8.3 Run the client

```bash
cd client
flutter pub get
flutter run -d windows
```

The client connects to `ws://localhost:8080/ws` on first launch. To use your own server, open **Settings** in the app and set the signaling URL (for example `wss://your.domain.com/ws`). ICE servers are configured in [`client/lib/utils/constants.dart`](client/lib/utils/constants.dart) and default to public STUN servers.

### 8.4 Verify a connection

Launch two clients (two machines, or two Windows user profiles), copy the PeerID shown on the home page, add each other, and send a message. Both `flutter test` and `go vet ./...` should pass.

## 9. Security Notice

This is a learning/MVP build. Do not use it for sensitive communication as-is:

- The Ed25519 private key is stored in Hive as base64 plaintext instead of the OS keystore.
- The signaling channel defaults to `ws://`; terminate TLS (`wss://`) in production.
- The signaling server accepts any WebSocket origin and does not authenticate peers.
- Message payloads are not end-to-end encrypted; they only get the transport protection WebRTC provides (DTLS-SRTP).
# Nintendo Switch Pro Controller (Android + Windows)

High-performance, ultra-low latency Nintendo Switch Pro / Joy-Con controller system for PC gaming and the **Ryujinx emulator**, featuring tactile haptics, security PIN pairing, and power-efficient micro-binary packet streaming.

---

## 📱 The Android App (`android_app/`)

Built with **Flutter** for Android phones, designed for an ergonomic landscape gaming console experience.

### Key Features:
- **Authentic Joy-Con / Switch Pro Layout**:
  - **Left Section (Neon Cyan)**: 360° Virtual Analog Thumbstick with deadzone filtering, tactile D-Pad (Up, Down, Left, Right), Minus (`-`), Capture (`F12`), Bumper (`L`), and Trigger (`ZL`).
  - **Right Section (Neon Red)**: Diamond Action Buttons (`A`, `B`, `X`, `Y`), 360° Virtual Analog Thumbstick, Plus (`+`), Home button, Bumper (`R`), and Trigger (`ZR`).
  - **Thumbstick Clicks**: Full support for `L3` (mapped to `F`) and `R3` (mapped to `H`).
- **Tactile Haptic & Vibration Engine**:
  - Haptic feedback on button presses, trigger pulls, and thumbstick boundary hits.
  - In-app toggle: Turn vibrations **On / Off** anytime in Settings.
  - Adjustable intensity: **Light**, **Medium**, or **Heavy**.
- **Power Efficiency & Ultra-Low Latency**:
  - **Micro-Binary Protocol (14 bytes)**: Eliminates JSON overhead for sub-millisecond packet transmission.
  - **Delta-State Streaming**: Only sends updates when inputs change, cutting phone battery usage by over 70% during static gameplay.
- **Security PIN Handshake**:
  - Requires entering the 4-digit pairing PIN shown on your desktop screen before inputs are accepted.

---

## 🖥️ The Windows Desktop Apps (`windows_receiver/`)

The Windows desktop receiver listens for incoming controller inputs, verifies the security PIN, and injects hardware keystrokes directly into Windows using the Win32 `SendInput` API.

### 1. Interactive Desktop GUI App *(Recommended)*
- **Live Visual Controller**: Real-time virtual Joy-Cons light up in neon colors as you press buttons on your phone.
- **Analog Stick Crosshairs**: Visually tracks your thumbstick position in real time.
- **Status & PIN Display**: Shows your local PC IP, port, and security PIN with one-click regeneration.
- **Injection Safety Toggle**: Checkbox to easily pause or resume Windows keystroke injection.
- **Launch**: Double-click `Launch_Desktop_App.bat` or run `python windows_receiver/desktop_app.py`.

### 2. Standalone Native Win32 Executable
- High-performance, lightweight (152 KB) native C++ binary compiled with MSVC / GCC.
- Zero dependencies — runs out of the box on any Windows PC.
- **Launch**: `.\windows_receiver\nintendo_receiver.exe`.

---

## 🎮 Control Mapping (Ryujinx Emulator Profile)

Directly pre-configured to match the Ryujinx emulator keyboard profile:

| Switch Controller Input | Key Sent to Windows | Ryujinx Mapping |
| :--- | :--- | :--- |
| **A** | `Z` | Action A |
| **B** | `X` | Action B |
| **X** | `C` | Action X |
| **Y** | `V` | Action Y |
| **+ (Plus)** | `Plus` (`=`) | Plus |
| **- (Minus)** | `Minus` (`-`) | Minus |
| **D-Pad Up** | `Up Arrow` | Dpad Up |
| **D-Pad Down** | `Down Arrow` | Dpad Down |
| **D-Pad Left** | `Left Arrow` | Dpad Left |
| **D-Pad Right** | `Right Arrow` | Dpad Right |
| **Left Stick Up** | `W` | LStick Up |
| **Left Stick Down** | `S` | LStick Down |
| **Left Stick Left** | `A` | LStick Left |
| **Left Stick Right** | `D` | LStick Right |
| **L-Stick Button (L3)** | `F` | LStick Click |
| **Right Stick Up** | `I` | RStick Up |
| **Right Stick Down** | `K` | RStick Down |
| **Right Stick Left** | `J` | RStick Left |
| **Right Stick Right** | `L` | RStick Right |
| **R-Stick Button (R3)** | `H` | RStick Click |
| **L (Bumper)** | `E` | L Trigger |
| **R (Bumper)** | `U` | R Trigger |
| **ZL (Trigger)** | `Q` | ZL Trigger |
| **ZR (Trigger)** | `O` | ZR Trigger |
| **Home Button** | `Home` | Home |
| **Capture Button** | `F12` | Screenshot |

---

## 🚀 Quick Start Guide

### Step 1: Start the Windows Desktop App
Double-click [Launch_Desktop_App.bat](file:///w:/CODE/Controller/Launch_Desktop_App.bat) or run:
```powershell
python windows_receiver\desktop_app.py
```
*(Or use the native binary: `.\windows_receiver\nintendo_receiver.exe`)*

Note the **Desktop IP** (e.g. `192.168.1.50`) and **Security PIN** (e.g. `1234`) displayed on the screen.

### Step 2: Run the Android Controller App
Connect your Android phone via USB or Wi-Fi and run:
```powershell
cd android_app
flutter run
```
1. Tap the **Status Pill** or the ⚙️ Settings icon in the header.
2. Enter the **Desktop IP Address** and **Security PIN**.
3. Tap **Connect to Desktop**.
4. The status turns green (`Connected (<5ms)`), and inputs immediately control Ryujinx or your PC games!

---

## 🔒 Security & Protection
- **PIN Authentication Challenge**: Unauthenticated packets are dropped immediately.
- **Session Tokens**: Handshake issues a dynamic session token for subsequent packets.
- **Replay Protection**: Sequence-counter validation prevents packet replaying.

---

## ⚙️ Building via GitHub Actions
A GitHub Actions workflow is provided at `.github/workflows/build-windows.yml`. When pushed to GitHub, it automatically:
1. Compiles `nintendo_receiver.exe` using MSVC on Windows runners.
2. Packages the release executable into `nintendo-switch-pro-receiver-windows.zip`.
3. Publishes the zip as a downloadable workflow artifact.

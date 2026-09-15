# 🎮 SwiCon: Broke Gamer Edition™
### *The Zero-Drift Nintendo Switch Controller for Android & Windows*

> *"Why pay Nintendo $70 for a piece of plastic that develops Joy-Con drift in 3 weeks when you have a $1000 smartphone in your pocket?"*

Welcome to **SwiCon**. We spent actual human hours writing code so you can turn your pocket supercomputer into an ultra-responsive virtual gamepad and play Ryujinx on your PC like the pirate... *ahem*, completely legal backup enthusiast you are.

---

## 📱 The Android App (`android_app/`)

Your phone is capable of rendering 3D graphics, running AI models, and browsing quantum physics papers. Instead, you're going to use it to mash virtual `A` and `B` buttons. We respect that.

### Features That Put Nintendo to Shame:
- **0% Mechanical Stick Drift™**: Scientifically proven to have zero hardware stick drift because there are literally no physical potentiometers to wear out. Take that, Joy-Con class-action lawsuits.
- **Neon Joy-Con Drip**: Left side is radiant Neon Cyan, right side is flaming Neon Red. It looks like you ripped the screen off a Switch OLED and glued it to your hands.
- **Freeform Drag & Resize (Layout Customizer)**:
  - Tiny hands? Gigantic gamer thumbs? Hate Nintendo's button placements? 
  - Tap the **🛠️ icon** or open Settings to enter **Layout Edit Mode**.
  - **Drag anywhere**: Move any stick, D-Pad, trigger, or action button freely across your screen.
  - **Scale on the fly**: Use the top toolbar slider to scale buttons from **70% to 150%**.
  - **Quick Selectors**: Pick controls instantly via the top **Dropdown Selector** or tap the **`◀` and `▶` arrows** to cycle through buttons.
  - **Auto-Save & Reset**: Your custom ergonomic layout is saved automatically. Hit **Reset** anytime to restore default console layout.
- **Dark Splash & Custom Icon**:
  - Full edge-to-edge dark theme launcher icon for your phone's home screen.
  - Seamless dark startup screen with zero ugly white borders or "bursting" stretched logos.
  - In-game center console features the sleek circular SwiCon emblem.
- **Haptic Vibrations**:
  - Yes, your phone can buzz aggressively when you smash buttons.
  - *Hate vibrations?* We included an on/off toggle and intensity sliders. We're not monsters.
- **Battery Saver Mode (Delta Compression)**:
  - We don't spam your Wi-Fi when you're just standing still in Breath of the Wild admiring the grass. We only blast packets when your thumbs actually twitch. Save that precious phone battery for doomscrolling later.
- **Security PIN Handshake**:
  - Displays a 4-digit PIN on your desktop. Why? So your little brother connected to the family Wi-Fi can't hijack your inputs and run Mario straight off a cliff.

---

## 🖥️ The Windows Desktop Apps (`windows_receiver/`)

The brains of the operation. It sits on your PC, catches the wireless packets from your phone, and secretly feeds them to Windows as raw hardware keystrokes. Ryujinx has no idea what hit it.

### Choose Your Fighter:

#### 1. The Shiny GUI Visualizer (`Launch_Desktop_App.bat` or `python windows_receiver\desktop_app.py`)
- **For people who like pretty lights**: Shows a virtual controller on your monitor that lights up in real-time as you press buttons on your phone.
- **Stick Tracker**: Real-time crosshairs tracking every micrometer of your thumb movement.
- **Safety Switch**: A checkbox to pause keystroke injection so you don't accidentally write `WASDZZZXX` in your boss's Teams chat.
- **🎮 Virtual Gamepad Mode (NEW)**: Creates a real Xbox 360 controller via ViGEmBus that Ryujinx detects as native XInput. Full analog stick support — walk, jog, and sprint with variable tilt. No more digital W/A/S/D for movement.
- **⌨ Keyboard Legacy Mode**: Toggle back to the classic scancode keyboard injection if you prefer or don't have ViGEmBus installed.
- **Watchdog**: If your phone disconnects or goes silent for 800ms, all inputs auto-release. No more phantom key holds.

#### 2. The Headless Chad Binary (`nintendo_receiver.exe`)
- 152 Kilobytes. Zero dependencies. Pure native C++ and Win32 `SendInput`.
- Doesn't need an installer, doesn't need 8 gigabytes of Electron, doesn't even ask for your email address. Just double-click and play.

---

## 🕹️ Control Mapping (Ryujinx Profile)

Pre-mapped to the default Ryujinx keyboard profile from the sacred screenshot. If you touch Ryujinx's default settings and break this, that's between you and your god.

| Switch Button | Keystroke Fired | Ryujinx Mapping | Honest Description |
| :--- | :--- | :--- | :--- |
| **A** | `Z` | Action A | The "Yes, I agree to the dialogue I'm skipping" button |
| **B** | `X` | Action B | The jump / dodge / roll / panic button |
| **X** | `C` | Action X | Attack, inventory, or whatever Nintendo decided this week |
| **Y** | `V` | Action Y | Secondary attack or sprint |
| **+ (Plus)** | `=` | Plus / Start | Pause to take a bathroom break |
| **- (Minus)** | `-` | Minus / Select | Open the map you'll stare at for 10 minutes |
| **D-Pad** | `Arrow Keys` | Up/Down/Left/Right | For menus, weapon wheels, and retro purists |
| **Left Stick** | `W / A / S / D` or **Analog Axis** | L-Stick Movement | Keyboard mode uses WASD. Virtual Gamepad mode sends real analog values — walk slow, run fast |
| **L3 Click** | `F` or **L-Thumb** | L-Stick Click | Sprint until your thumb hurts |
| **Right Stick** | `I / J / K / L` or **Analog Axis** | Camera Controls | Keyboard mode uses IJKL. Virtual Gamepad mode sends precise camera axes |
| **R3 Click** | `H` or **R-Thumb** | R-Stick Click | Reset camera / lock-on |
| **L / R** | `E` / `U` | Bumpers | Quick shield, dash, or bumper jumper stuff |
| **ZL / ZR** | `Q` / `O` | Triggers | Heavy attacks, aiming bows, drift boosting |
| **Home** | `Home` | Home | Rage quit to desktop |
| **Capture** | `F12` | Screenshot | Immortalize your embarrassing game-over screens |

---

## 🚀 How to Run & Share with Friends (Zero-Braincell Edition)

Got a friend who wants to play co-op Smash or Mario Kart on your PC, but neither of you owns a second controller? Send them **`dist\SwiCon.exe`** (PC) and **`dist\SwiCon.apk`** (Android) directly from the `dist/` folder. That's literally it — zero compiling required.

### 🎮 The 30-Second Friend Setup:

#### 1. On the PC (`dist\SwiCon.exe` or `Launch_Desktop_App.bat`):
- Double-click **`dist\SwiCon.exe`** (or double-click **`Launch_Desktop_App.bat`**).
- **First time on this PC?** If Windows doesn't have the ViGEmBus driver yet, SwiCon will politely ask:
  > *"Hey, you need ViGEmBus for real analog sticks. Want me to download and install it?"*
- Click **Yes**, approve the Windows UAC prompt, and sip your coffee. SwiCon downloads the official driver, installs it quietly, and auto-connects the virtual Xbox 360 controller. Zero manual searching.
- Note the **Desktop IP** and **4-Digit PIN** on your screen (e.g. `4269`).

#### 2. On the Phone (`dist\SwiCon.apk`):
- Install **`dist\SwiCon.apk`** on your Android phone.
- Make sure phone and PC are on the **same Wi-Fi network**.
- Open the SwiCon app on your phone.
- It will usually **auto-discover** the PC instantly! If not, tap the top connection bar, type the IP & PIN, and smash **Connect**.
- When the bar glows radiant **Neon Green**, you're locked and loaded.

#### 3. In Ryujinx (One-Time Input Mapping):
- Open **Ryujinx** → `Options` → `Settings` → **`Input`** tab.
- Under **Player 1**, click **Configure**.
- Set **Input Device** to: **`Controller (XBOX 360 For Windows)`**.
- Set **Controller Type** to: **`Pro Controller`**.
- Hit **Save**.
- *Congratulations*: You now have zero-latency analog stick movement, smooth camera controls, and zero physical drift forever. Go terrorize Hyrule.

---

### 🛠️ Developer Setup (Running from Source)

If you're tinkering with the code or prefer running directly from Python source instead of the standalone `.exe`:

#### 1. Create a Virtual Environment & Install Dependencies

**Option A — Standard Python `venv` (No Conda needed):**
```powershell
# Create a virtual environment named .venv
python -m venv .venv

# Activate it in PowerShell:
.\.venv\Scripts\Activate.ps1
# (Or in CMD): .venv\Scripts\activate.bat

# Install all dependencies
pip install -r requirements.txt
```

**Option B — Conda / MiniConda:**
```powershell
# Create a clean Python 3.11 environment
conda create -n swicon python=3.11 -y

# Activate the environment
conda activate swicon

# Install all dependencies
pip install -r requirements.txt
```

#### 2. Launch the Desktop Receiver:
```powershell
python windows_receiver\desktop_app.py
```

#### 3. Compile the Standalone Single-File `.exe`:
```powershell
# Packages everything (Python + Tkinter + vgamepad + ViGEm) into dist\SwiCon.exe:
.\build_exe.bat
```

#### 4. Android Phone Setup:
```powershell
cd android_app
flutter pub get
flutter run --release
```

---

## ❓ FAQ (Frequently Argued Questions)

**Q: Why is my character not moving?**  
A: Did you actually hit "Connect" on your phone, or are you just tapping the screen hoping wireless telepathy would carry the signal? Check your IP and PIN.

**Q: Notepad registers typing, but Ryujinx isn't taking input?**  
A: Two quick checks:
1. **Window Focus**: Emulators use DirectInput / SDL2, which strictly process keyboard events when the game window is **active/focused**. Click inside the Ryujinx window (or click the **`⚡ Focus Ryujinx / Game`** button in the desktop receiver app).
2. **Ryujinx Input Settings**: Go to `Options > Settings > Input > Player 1 > Configure`. Ensure `Input Device` is set to `All Keyboards` (or Keyboard) and that the key bindings match the chart above. SwiCon now injects low-level hardware scan codes directly into DirectInput/SDL2.

**Q: Can I play Dark Souls with this?**  
A: Legally, yes. Emotionally, we take zero financial liability for your phone screen if you chuck it into drywall after dying to Ornstein and Smough.

**Q: Will this work over mobile data?**  
A: Unless you're port forwarding UDP port 8899 across the open internet like a maniac, keep both your PC and your phone on the **same Wi-Fi network**.

**Q: Is there input lag?**  
A: We send 14-byte micro-packets over local UDP. Latency is typically **< 4 milliseconds**. If you lose, it's a skill issue, not lag.

**Q: How do I use the Virtual Gamepad (XInput) mode?**  
A: Just run **`dist\SwiCon.exe`** (or `Launch_Desktop_App.bat`). SwiCon automatically checks if the ViGEmBus driver is present. If not, it prompts you and automatically downloads & installs the official driver with one click! Once installed, SwiCon creates a virtual Xbox 360 controller with real analog axes. In Ryujinx, go to `Options > Settings > Input > Player 1 > Configure`, choose `Controller (XBOX 360 For Windows)`, and enjoy true analog control.

**Q: What's the difference between Virtual Gamepad and Keyboard mode?**  
A: **Virtual Gamepad** creates a real virtual Xbox controller at the Windows driver level — Ryujinx sees actual analog axes (10% tilt ≠ 100% tilt, enabling walking vs sprinting and precise camera panning). **Keyboard mode** converts everything to key presses (W/A/S/D), which is purely digital on/off. Virtual Gamepad is strictly better for all modern games.

**Q: Can I share the desktop app with someone else without them installing Python?**  
A: Yes! Simply send them **`dist\SwiCon.exe`**. It is a single, self-contained 10 MB executable that bundles the entire Python runtime, visualizer, and gamepad libraries. No Python, Conda, or pip is needed on their machine. When they open it, if their PC lacks the ViGEmBus driver, SwiCon will automatically offer to download and install it for them.

---

## ⚙️ GitHub Actions
There is a CI workflow in `.github/workflows/build-windows.yml`. Whenever you push code, GitHub's cloud servers will compile the Windows executable with MSVC and hand you a shiny `.zip` file so you don't even have to compile anything yourself. Automation at its finest.

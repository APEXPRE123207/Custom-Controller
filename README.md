# 🎮 Nintendo Switch Pro Controller: Broke Gamer Edition™

> *"Why pay Nintendo $70 for a piece of plastic that develops Joy-Con drift in 3 weeks when you have a $1000 smartphone in your pocket?"*

Welcome to the **Custom Nintendo Switch Controller** project. We spent actual human hours writing code so you can turn your pocket supercomputer into a virtual gamepad and play Ryujinx on your PC like the pirate... *ahem*, completely legal backup enthusiast you are.

---

## 📱 The Android App (`android_app/`)

Your phone is capable of rendering 3D graphics, running AI models, and browsing quantum physics papers. Instead, you're going to use it to mash virtual `A` and `B` buttons. We respect that.

### Features That Put Nintendo to Shame:
- **0% Mechanical Stick Drift™**: Scientifically proven to have zero hardware stick drift because there are literally no physical potentiometers to wear out. Take that, Joy-Con class-action lawsuits.
- **Neon Joy-Con Drip**: Left side is radiant Neon Cyan, right side is flaming Neon Red. It looks like you ripped the screen off a Switch OLED and glued it to your hands.
- **Haptic Vibrations**:
  - Yes, your phone can buzz aggressively when you smash buttons.
  - *Hate vibrations?* We included an on/off toggle and intensity sliders. We're not monsters.
- **Freeform Drag & Resize (Custom Layout Editor)**:
  - Tiny hands? Gigantic gamer thumbs? Hate Nintendo's button placements? Tap the 🛠️ icon or open Settings to enter **Layout Edit Mode**. Drag any stick, D-Pad, trigger, or action button anywhere on your screen and scale their sizes from 70% to 150%. Your layout is saved automatically.
- **Battery Saver Mode (Delta Compression)**:
  - We don't spam your Wi-Fi when you're just standing still in Breath of the Wild admiring the grass. We only blast packets when your thumbs actually twitch. Save that precious phone battery for doomscrolling later.
- **Security PIN Handshake**:
  - Displays a 4-digit PIN on your desktop. Why? So your little brother connected to the family Wi-Fi can't hijack your inputs and run Mario straight off a cliff.

---

## 🖥️ The Windows Desktop Apps (`windows_receiver/`)

The brains of the operation. It sits on your PC, catches the wireless packets from your phone, and secretly feeds them to Windows as raw hardware keystrokes. Ryujinx has no idea what hit it.

### Choose Your Fighter:

#### 1. The Shiny GUI Visualizer (`Launch_Desktop_App.bat` or `python desktop_app.py`)
- **For people who like pretty lights**: Shows a virtual controller on your monitor that lights up in real-time as you press buttons on your phone.
- **Stick Tracker**: Real-time crosshairs tracking every micrometer of your thumb movement.
- **Safety Switch**: A checkbox to pause keystroke injection so you don't accidentally write `WASDZZZXX` in your boss's Teams chat.

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
| **Left Stick** | `W / A / S / D` | L-Stick Movement | Standard PC gamer movement since the dawn of time |
| **L3 Click** | `F` | L-Stick Click | Sprint until your thumb hurts |
| **Right Stick** | `I / J / K / L` | Camera Controls | Look around and wonder how you got here |
| **R3 Click** | `H` | R-Stick Click | Reset camera / lock-on |
| **L / R** | `E` / `U` | Bumpers | Quick shield, dash, or bumper jumper stuff |
| **ZL / ZR** | `Q` / `O` | Triggers | Heavy attacks, aiming bows, drift boosting |
| **Home** | `Home` | Home | Rage quit to desktop |
| **Capture** | `F12` | Screenshot | Immortalize your embarrassing game-over screens |

---

## 🚀 How to Run (Don't Skip These Steps)

### Step 1: Start the PC Receiver
Pick your poison:
```powershell
# Option A: The fancy graphical window with live lights
python windows_receiver\desktop_app.py

# Option B: The lightweight native binary
.\windows_receiver\nintendo_receiver.exe
```
Look at your PC screen. It will shout two things at you:
1. Your **Desktop IP** (e.g., `192.168.1.50`)
2. Your **Security PIN** (e.g., `4269`)

### Step 2: Fire Up the Phone Controller
Plug your phone into your PC (or make sure Flutter sees it) and run:
```powershell
cd android_app
flutter run
```
1. Tap the status bar at the top (or the ⚙️ gear icon).
2. Type in your PC's IP and the PIN.
3. Hit **Connect to Desktop**.
4. If it turns glowing **Green**, congratulations, you're in. Open Ryujinx and go wild.

---

## ❓ FAQ (Frequently Argued Questions)

**Q: Why is my character not moving?**  
A: Did you actually hit "Connect" on your phone, or are you just tapping the screen hoping wireless telepathy would carry the signal? Check your IP and PIN.

**Q: Can I play Dark Souls with this?**  
A: Legally, yes. Emotionally, we take zero financial liability for your phone screen if you chuck it into drywall after dying to Ornstein and Smough.

**Q: Will this work over mobile data?**  
A: Unless you're port forwarding UDP port 8899 across the open internet like a maniac, keep both your PC and your phone on the **same Wi-Fi network**.

**Q: Is there input lag?**  
A: We send 14-byte micro-packets over local UDP. Latency is typically **< 4 milliseconds**. If you lose, it's a skill issue, not lag.

---

## ⚙️ GitHub Actions
There is a CI workflow in `.github/workflows/build-windows.yml`. Whenever you push code, GitHub's cloud servers will compile the Windows executable with MSVC and hand you a shiny `.zip` file so you don't even have to compile anything yourself. Automation at its finest.

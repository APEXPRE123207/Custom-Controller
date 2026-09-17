import sys
import os

# PyInstaller frozen bundle: point TCL_LIBRARY and TK_LIBRARY to bundled data
if hasattr(sys, '_MEIPASS'):
    tcl_path = os.path.join(sys._MEIPASS, 'tcl')
    tk_path = os.path.join(sys._MEIPASS, 'tk')
    if os.path.exists(tcl_path):
        os.environ['TCL_LIBRARY'] = tcl_path
    if os.path.exists(tk_path):
        os.environ['TK_LIBRARY'] = tk_path

import tkinter as tk
from tkinter import ttk, messagebox
import socket
import struct
import threading
import random
import ctypes
from ctypes import wintypes
import time
import math
import urllib.request
import tempfile
import winreg

# Win32 SendInput constants and structures
PUL = ctypes.POINTER(ctypes.c_ulong)
class KeyBdInput(ctypes.Structure):
    _fields_ = [("wVk", ctypes.c_ushort),
                ("wScan", ctypes.c_ushort),
                ("dwFlags", ctypes.c_ulong),
                ("time", ctypes.c_ulong),
                ("dwExtraInfo", PUL)]

class HardwareInput(ctypes.Structure):
    _fields_ = [("uMsg", ctypes.c_ulong),
                ("wParamL", ctypes.c_short),
                ("wParamH", ctypes.c_ushort)]

class MouseInput(ctypes.Structure):
    _fields_ = [("dx", ctypes.c_long),
                ("dy", ctypes.c_long),
                ("mouseData", ctypes.c_ulong),
                ("dwFlags", ctypes.c_ulong),
                ("time", ctypes.c_ulong),
                ("dwExtraInfo", PUL)]

class Input_I(ctypes.Union):
    _fields_ = [("ki", KeyBdInput),
                ("mi", MouseInput),
                ("hi", HardwareInput)]

class Input(ctypes.Structure):
    _fields_ = [("type", ctypes.c_ulong),
                ("ii", Input_I)]

try:
    import pydirectinput
    pydirectinput.PAUSE = 0.0
    pydirectinput.FAILSAFE = False
    HAVE_PYDIRECTINPUT = True
except ImportError:
    HAVE_PYDIRECTINPUT = False

# Virtual Gamepad (ViGEmBus / XInput) support
vg = None
HAVE_VGAMEPAD = False

def init_vgamepad_support():
    """Attempt to import vgamepad. Safe against missing ViGEmBus kernel driver."""
    global vg, HAVE_VGAMEPAD
    try:
        import vgamepad as _vg
        vg = _vg
        HAVE_VGAMEPAD = True
        return True
    except Exception as e:
        # VIGEM_ERROR_BUS_NOT_FOUND or missing DLLs
        # Purge partial imports so subsequent attempts after driver installation can succeed
        for mod in list(sys.modules.keys()):
            if mod.startswith('vgamepad'):
                sys.modules.pop(mod, None)
        vg = None
        HAVE_VGAMEPAD = False
        return False

# Attempt initial load (succeeds if ViGEmBus driver is already installed on Windows)
init_vgamepad_support()

# Windows Winsock Bluetooth SDP Registration Structures
class _GUID(ctypes.Structure):
    _fields_ = [
        ('Data1', wintypes.DWORD),
        ('Data2', wintypes.WORD),
        ('Data3', wintypes.WORD),
        ('Data4', ctypes.c_byte * 8)
    ]

_SPP_GUID = _GUID(0x00001101, 0x0000, 0x1000, (ctypes.c_byte * 8)(0x80, 0x00, 0x00, 0x80, 0x5F, 0x9B, 0x34, 0xFB))

class _SOCKADDR_BTH(ctypes.Structure):
    _fields_ = [
        ('addressFamily', ctypes.c_ushort),
        ('btAddr', ctypes.c_ulonglong),
        ('serviceClassId', _GUID),
        ('port', ctypes.c_ulong)
    ]

class _SOCKET_ADDRESS(ctypes.Structure):
    _fields_ = [
        ('lpSockaddr', ctypes.c_void_p),
        ('iSockaddrLength', ctypes.c_int)
    ]

class _CSADDR_INFO(ctypes.Structure):
    _fields_ = [
        ('LocalAddr', _SOCKET_ADDRESS),
        ('RemoteAddr', _SOCKET_ADDRESS),
        ('iSocketType', ctypes.c_int),
        ('iProtocol', ctypes.c_int)
    ]

class _WSAQUERYSET(ctypes.Structure):
    _fields_ = [
        ('dwSize', wintypes.DWORD),
        ('lpszServiceInstanceName', wintypes.LPWSTR),
        ('lpServiceClassId', ctypes.POINTER(_GUID)),
        ('lpVersion', ctypes.c_void_p),
        ('lpszComment', wintypes.LPWSTR),
        ('dwNameSpace', wintypes.DWORD),
        ('lpNSProviderId', ctypes.c_void_p),
        ('lpszContext', wintypes.LPWSTR),
        ('dwNumberOfProtocols', wintypes.DWORD),
        ('lpafpProtocols', ctypes.c_void_p),
        ('lpszQueryString', wintypes.LPWSTR),
        ('dwNumberOfCsAddrs', wintypes.DWORD),
        ('lpcsaBuffer', ctypes.POINTER(_CSADDR_INFO)),
        ('dwOutputFlags', wintypes.DWORD),
        ('lpBlob', ctypes.c_void_p)
    ]

def register_bt_sdp(sock, service_name="SwiCon Controller"):
    """Register Serial Port Profile (SPP) with Windows Bluetooth SDP database."""
    try:
        ws2_32 = ctypes.windll.ws2_32
        local_sa = _SOCKADDR_BTH()
        local_len = ctypes.c_int(ctypes.sizeof(local_sa))
        if ws2_32.getsockname(sock.fileno(), ctypes.byref(local_sa), ctypes.byref(local_len)) != 0:
            return None

        remote_sa = _SOCKADDR_BTH()
        remote_sa.addressFamily = 32  # AF_BTH
        remote_len = ctypes.c_int(ctypes.sizeof(remote_sa))

        csaddr = _CSADDR_INFO()
        csaddr.LocalAddr.lpSockaddr = ctypes.cast(ctypes.byref(local_sa), ctypes.c_void_p)
        csaddr.LocalAddr.iSockaddrLength = local_len.value
        csaddr.RemoteAddr.lpSockaddr = ctypes.cast(ctypes.byref(remote_sa), ctypes.c_void_p)
        csaddr.RemoteAddr.iSockaddrLength = remote_len.value
        csaddr.iSocketType = socket.SOCK_STREAM
        csaddr.iProtocol = socket.BTPROTO_RFCOMM

        qs = _WSAQUERYSET()
        qs.dwSize = ctypes.sizeof(qs)
        qs.lpszServiceInstanceName = service_name
        qs.lpServiceClassId = ctypes.pointer(_SPP_GUID)
        qs.dwNameSpace = 16  # NS_BTH
        qs.dwNumberOfCsAddrs = 1
        qs.lpcsaBuffer = ctypes.pointer(csaddr)

        res = ws2_32.WSASetServiceW(ctypes.byref(qs), 0, 0)  # RNRSERVICE_REGISTER = 0
        if res == 0:
            print(f"[BT] SDP service '{service_name}' registered successfully.")
            return qs
        else:
            print(f"[BT] WSASetServiceW failed: {ws2_32.WSAGetLastError()}")
    except Exception as e:
        print(f"[BT] Failed to register SDP service: {e}")
    return None

def unregister_bt_sdp(qs):
    """Unregister Serial Port Profile (SPP) from Windows Bluetooth SDP database."""
    if qs:
        try:
            ctypes.windll.ws2_32.WSASetServiceW(ctypes.byref(qs), 2, 0)  # RNRSERVICE_DELETE = 2
            print("[BT] SDP service unregistered.")
        except Exception:
            pass


INPUT_KEYBOARD = 1
KEYEVENTF_EXTENDEDKEY = 0x0001
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_SCANCODE = 0x0008
MAPVK_VK_TO_VSC = 0

# Virtual key codes matching Ryujinx configuration
VK_MAP = {
    'A': (0x5A, 'Z'),          # 'Z'
    'B': (0x58, 'X'),          # 'X'
    'X': (0x43, 'C'),          # 'C'
    'Y': (0x56, 'V'),          # 'V'
    'PLUS': (0xBB, '+'),       # '+' / '='
    'MINUS': (0xBD, '-'),      # '-'
    'DPAD_UP': (0x26, 'Up'),   # Up Arrow
    'DPAD_DOWN': (0x28, 'Down'), # Down Arrow
    'DPAD_LEFT': (0x25, 'Left'), # Left Arrow
    'DPAD_RIGHT': (0x27, 'Right'), # Right Arrow
    'L': (0x45, 'E'),          # 'E'
    'R': (0x55, 'U'),          # 'U'
    'ZL': (0x51, 'Q'),         # 'Q'
    'ZR': (0x4F, 'O'),         # 'O'
    'LSTICK_BTN': (0x46, 'F'), # 'F'
    'RSTICK_BTN': (0x48, 'H'), # 'H'
    'HOME': (0x24, 'Home'),
    'CAPTURE': (0x7B, 'F12'),
    'L_UP': (0x57, 'W'),       # 'W'
    'L_DOWN': (0x53, 'S'),     # 'S'
    'L_LEFT': (0x41, 'A'),     # 'A'
    'L_RIGHT': (0x44, 'D'),    # 'D'
    'R_UP': (0x49, 'I'),       # 'I'
    'R_DOWN': (0x4B, 'K'),     # 'K'
    'R_LEFT': (0x4A, 'J'),     # 'J'
    'R_RIGHT': (0x4C, 'L'),    # 'L'
}

# Mapping to pydirectinput key names for DirectInput hardware scan code delivery
VK_TO_PDI = {
    0x5A: 'z',
    0x58: 'x',
    0x43: 'c',
    0x56: 'v',
    0xBB: '=',
    0xBD: '-',
    0x26: 'up',
    0x28: 'down',
    0x25: 'left',
    0x27: 'right',
    0x45: 'e',
    0x55: 'u',
    0x51: 'q',
    0x4F: 'o',
    0x46: 'f',
    0x48: 'h',
    0x24: 'home',
    0x7B: 'f12',
    0x57: 'w',
    0x53: 's',
    0x41: 'a',
    0x44: 'd',
    0x49: 'i',
    0x4B: 'k',
    0x4A: 'j',
    0x4C: 'l',
}

EXTENDED_KEYS = {0x26, 0x28, 0x25, 0x27, 0x24}

# Global input state cache
g_key_states = {}

def inject_key(vk_code, pressed):
    if g_key_states.get(vk_code) == pressed:
        return
    g_key_states[vk_code] = pressed

    # 1. Primary: DirectInput via pydirectinput (required by Ryujinx / DirectX emulators)
    if HAVE_PYDIRECTINPUT and vk_code in VK_TO_PDI:
        pdi_key = VK_TO_PDI[vk_code]
        try:
            if pressed:
                pydirectinput.keyDown(pdi_key)
            else:
                pydirectinput.keyUp(pdi_key)
            return
        except Exception:
            pass

    # 2. Native Win32 SendInput with hardware scancode (KEYEVENTF_SCANCODE = 0x0008)
    scan_code = ctypes.windll.user32.MapVirtualKeyA(vk_code, MAPVK_VK_TO_VSC)
    flags = KEYEVENTF_SCANCODE
    if not pressed:
        flags |= KEYEVENTF_KEYUP
    if vk_code in EXTENDED_KEYS:
        flags |= KEYEVENTF_EXTENDEDKEY

    extra = ctypes.c_ulong(0)
    ii_ = Input_I()
    ii_.ki = KeyBdInput(0, scan_code, flags, 0, ctypes.pointer(extra))
    x = Input(ctypes.c_ulong(INPUT_KEYBOARD), ii_)
    res = ctypes.windll.user32.SendInput(1, ctypes.pointer(x), ctypes.sizeof(x))

    # 3. Fallback to keybd_event with scancode if SendInput was filtered by UIPI
    if res == 0:
        try:
            ctypes.windll.user32.keybd_event(vk_code, scan_code, flags, 0)
        except Exception:
            pass

def release_all():
    for vk, state in list(g_key_states.items()):
        if state:
            inject_key(vk, False)

# ============================================================================
# Virtual Gamepad Controller (XInput via ViGEmBus)
# ============================================================================

# Nintendo→Xbox button mapping (Note: Nintendo A/B and X/Y are swapped vs Xbox)
# Standard XInput button bitmasks (independent of vgamepad import state)
SWITCH_TO_XINPUT_BUTTONS = {
    (1 << 0):  0x2000,  # XUSB_GAMEPAD_B (Switch A → Xbox B)
    (1 << 1):  0x1000,  # XUSB_GAMEPAD_A (Switch B → Xbox A)
    (1 << 2):  0x8000,  # XUSB_GAMEPAD_Y (Switch X → Xbox Y)
    (1 << 3):  0x4000,  # XUSB_GAMEPAD_X (Switch Y → Xbox X)
    (1 << 4):  0x0001,  # XUSB_GAMEPAD_DPAD_UP
    (1 << 5):  0x0002,  # XUSB_GAMEPAD_DPAD_DOWN
    (1 << 6):  0x0004,  # XUSB_GAMEPAD_DPAD_LEFT
    (1 << 7):  0x0008,  # XUSB_GAMEPAD_DPAD_RIGHT
    (1 << 8):  0x0100,  # XUSB_GAMEPAD_LEFT_SHOULDER (L)
    (1 << 9):  0x0200,  # XUSB_GAMEPAD_RIGHT_SHOULDER (R)
    # ZL (1<<10) and ZR (1<<11) → analog triggers, handled separately
    (1 << 12): 0x0010,  # XUSB_GAMEPAD_START (+)
    (1 << 13): 0x0020,  # XUSB_GAMEPAD_BACK (-)
    (1 << 14): 0x0040,  # XUSB_GAMEPAD_LEFT_THUMB (L3)
    (1 << 15): 0x0080,  # XUSB_GAMEPAD_RIGHT_THUMB (R3)
    (1 << 16): 0x0400,  # XUSB_GAMEPAD_GUIDE (Home)
    # Capture (1<<17) → no Xbox equivalent, mapped to keyboard F12 fallback
}

# Deadzone: 5% of 127 ≈ 6
STICK_DEADZONE = 6
# Watchdog timeout (ms) — release all if no packets arrive
WATCHDOG_TIMEOUT_MS = 1500

def apply_deadzone_and_scale(raw_int8, deadzone=STICK_DEADZONE):
    """Convert int8 (-127..+127) to int16 (-32768..+32767) with deadzone."""
    if abs(raw_int8) <= deadzone:
        return 0
    # Remove deadzone range, then scale remaining to full int16 range
    max_raw = 127.0
    sign = 1 if raw_int8 > 0 else -1
    magnitude = abs(raw_int8) - deadzone
    effective_max = max_raw - deadzone
    normalized = magnitude / effective_max  # 0.0 → 1.0
    return int(sign * normalized * 32767)


VIGEMBUS_DOWNLOAD_URL = "https://github.com/nefarius/ViGEmBus/releases/download/v1.22.0/ViGEmBus_1.22.0_x64_x86_arm64.exe"
VIGEMBUS_REG_KEY = r"SYSTEM\CurrentControlSet\Services\ViGEmBus"


def is_vigembus_installed():
    """Check if the official ViGEmBus driver is installed on Windows."""
    global HAVE_VGAMEPAD, vg
    try:
        key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, VIGEMBUS_REG_KEY)
        winreg.CloseKey(key)
    except Exception:
        return False

    # Driver service exists in registry — ensure vgamepad module is loaded
    if not HAVE_VGAMEPAD or vg is None:
        init_vgamepad_support()

    return HAVE_VGAMEPAD


class VirtualGamepad:
    """Manages a virtual Xbox 360 controller via ViGEmBus/vgamepad."""

    def __init__(self):
        self.gamepad = None
        self.active = False
        self._prev_buttons = 0
        self._prev_lx = 0
        self._prev_ly = 0
        self._prev_rx = 0
        self._prev_ry = 0
        self._prev_lt = 0
        self._prev_rt = 0
        self.last_update_time = time.time()
        self._watchdog_thread = None
        self._watchdog_running = False

    def connect(self):
        """Create and plug in the virtual Xbox 360 controller."""
        if not HAVE_VGAMEPAD or vg is None:
            if not init_vgamepad_support():
                return False
        try:
            self.gamepad = vg.VX360Gamepad()
            self.active = True
            self.last_update_time = time.time()
            self._start_watchdog()
            return True
        except Exception as e:
            print(f"[VirtualGamepad] Failed to create: {e}")
            self.active = False
            return False

    def disconnect(self):
        """Release all inputs and destroy the virtual controller."""
        self._stop_watchdog()
        if self.gamepad and self.active:
            try:
                self.gamepad.reset()
                self.gamepad.update()
            except Exception:
                pass
        self.gamepad = None
        self.active = False

    def update_state(self, buttons, lx, ly, rx, ry):
        """Push a full controller state update to the virtual gamepad.
        
        Args:
            buttons: uint32 bitmask of pressed buttons
            lx, ly, rx, ry: int8 analog stick axes (-127..+127)
        """
        if not self.active or not self.gamepad:
            return

        self.last_update_time = time.time()

        # --- Reset gamepad report ---
        self.gamepad.reset()

        # --- Buttons ---
        for mask, xbutton in SWITCH_TO_XINPUT_BUTTONS.items():
            if buttons & mask:
                self.gamepad.press_button(button=xbutton)

        # --- Triggers (ZL / ZR are digital on Switch → map to full analog press) ---
        zl_pressed = (buttons & (1 << 10)) != 0
        zr_pressed = (buttons & (1 << 11)) != 0
        self.gamepad.left_trigger(value=255 if zl_pressed else 0)
        self.gamepad.right_trigger(value=255 if zr_pressed else 0)

        # --- Analog Sticks (with deadzone + scaling) ---
        scaled_lx = apply_deadzone_and_scale(lx)
        scaled_ly = apply_deadzone_and_scale(-ly)  # Invert Y: UDP up=-127, XInput up=+32767
        scaled_rx = apply_deadzone_and_scale(rx)
        scaled_ry = apply_deadzone_and_scale(-ry)  # Invert Y

        self.gamepad.left_joystick(x_value=scaled_lx, y_value=scaled_ly)
        self.gamepad.right_joystick(x_value=scaled_rx, y_value=scaled_ry)

        # --- Capture button (no Xbox equivalent) → keyboard F12 fallback ---
        capture_pressed = (buttons & (1 << 17)) != 0
        inject_key(0x7B, capture_pressed)  # F12

        # --- Send report ---
        self.gamepad.update()

    def release_all(self):
        """Center sticks, release all buttons and triggers."""
        if self.active and self.gamepad:
            try:
                self.gamepad.reset()
                self.gamepad.update()
            except Exception:
                pass

    def _start_watchdog(self):
        """Start a background thread that releases all inputs if connection is lost."""
        self._watchdog_running = True
        self._watchdog_thread = threading.Thread(target=self._watchdog_loop, daemon=True)
        self._watchdog_thread.start()

    def _stop_watchdog(self):
        self._watchdog_running = False

    def _watchdog_loop(self):
        while self._watchdog_running and self.active:
            elapsed_ms = (time.time() - self.last_update_time) * 1000
            if elapsed_ms > WATCHDOG_TIMEOUT_MS:
                self.release_all()
            time.sleep(0.2)  # Check every 200ms


class ViGEmInstallerDialog:
    """Modern modal dialog to download and install ViGEmBus driver automatically."""

    def __init__(self, parent, on_success=None):
        self.parent = parent
        self.on_success = on_success
        self.cancelled = False

        self.win = tk.Toplevel(parent)
        self.win.title("ViGEmBus Driver Installer")
        self.win.geometry("460x230")
        self.win.resizable(False, False)
        self.win.configure(bg="#161822")
        self.win.transient(parent)
        self.win.grab_set()

        # Center over parent window
        try:
            self.win.update_idletasks()
            pw = parent.winfo_width()
            ph = parent.winfo_height()
            px = parent.winfo_rootx()
            py = parent.winfo_rooty()
            x = px + max(0, (pw - 460) // 2)
            y = py + max(0, (ph - 230) // 2)
            self.win.geometry(f"+{x}+{y}")
        except Exception:
            pass

        # Title
        tk.Label(self.win, text="🎮 ViGEmBus Driver Setup", font=("Segoe UI", 12, "bold"),
                 fg="#00C3E3", bg="#161822").pack(pady=(16, 2))

        self.sub_lbl = tk.Label(self.win, text="Enables native Xbox 360 controller emulation with analog sticks.",
                                font=("Segoe UI", 9), fg="#8E95A5", bg="#161822")
        self.sub_lbl.pack(pady=(0, 10))

        # Status text
        self.status_lbl = tk.Label(self.win, text="Connecting to GitHub...",
                                   font=("Segoe UI", 9, "bold"), fg="#E2E6EF", bg="#161822")
        self.status_lbl.pack(pady=2)

        # Progress bar
        style = ttk.Style(self.win)
        try:
            style.theme_use('default')
        except Exception:
            pass
        style.configure("Cyan.Horizontal.TProgressbar", foreground='#00C3E3', background='#00C3E3',
                        troughcolor='#202430', bordercolor='#161822', lightcolor='#00C3E3', darkcolor='#00C3E3')
        self.progress = ttk.Progressbar(self.win, style="Cyan.Horizontal.TProgressbar",
                                        length=380, mode='determinate')
        self.progress.pack(pady=6)

        # Detail text
        self.detail_lbl = tk.Label(self.win, text="Preparing download...",
                                   font=("Segoe UI", 8), fg="#7E8494", bg="#161822")
        self.detail_lbl.pack(pady=(0, 10))

        # Bottom buttons
        btn_frame = tk.Frame(self.win, bg="#161822")
        btn_frame.pack(fill=tk.X, padx=20, pady=4)

        self.cancel_btn = tk.Button(btn_frame, text="Cancel", font=("Segoe UI", 9),
                                    bg="#2A2F3E", fg="#FFFFFF", relief=tk.FLAT, padx=14, pady=3,
                                    command=self._cancel)
        self.cancel_btn.pack(side=tk.RIGHT)

        self.win.protocol("WM_DELETE_WINDOW", self._cancel)

        # Start background worker
        self.thread = threading.Thread(target=self._run_install, daemon=True)
        self.thread.start()

    def _cancel(self):
        self.cancelled = True
        try:
            self.win.destroy()
        except Exception:
            pass

    def _run_install(self):
        target_file = os.path.join(tempfile.gettempdir(), "ViGEmBus_Setup.exe")

        try:
            # 1. Download installer
            self.parent.after(0, lambda: self.status_lbl.config(text="📥 Downloading official ViGEmBus installer..."))
            req = urllib.request.Request(
                VIGEMBUS_DOWNLOAD_URL,
                headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) SwiCon/1.0'}
            )
            with urllib.request.urlopen(req, timeout=30) as response, open(target_file, 'wb') as out_file:
                total_length = response.getheader('content-length')
                total_bytes = int(total_length) if total_length else 6278576
                downloaded = 0
                block_size = 65536

                while not self.cancelled:
                    chunk = response.read(block_size)
                    if not chunk:
                        break
                    out_file.write(chunk)
                    downloaded += len(chunk)
                    percent = min(100, int(downloaded * 100 / total_bytes))
                    dl_mb = downloaded / (1024 * 1024)
                    tot_mb = total_bytes / (1024 * 1024)

                    self.parent.after(0, lambda p=percent, d=dl_mb, t=tot_mb: self._update_progress(p, d, t))

            if self.cancelled:
                return

            # 2. Run Installer with Administrator Elevation
            self.parent.after(0, self._show_installing_state)

            class SHELLEXECUTEINFO(ctypes.Structure):
                _fields_ = [
                    ("cbSize", wintypes.DWORD),
                    ("fMask", wintypes.ULONG),
                    ("hwnd", wintypes.HWND),
                    ("lpVerb", wintypes.LPCWSTR),
                    ("lpFile", wintypes.LPCWSTR),
                    ("lpParameters", wintypes.LPCWSTR),
                    ("lpDirectory", wintypes.LPCWSTR),
                    ("nShow", ctypes.c_int),
                    ("hInstApp", wintypes.HINSTANCE),
                    ("lpIDList", wintypes.LPVOID),
                    ("lpClass", wintypes.LPCWSTR),
                    ("hkeyClass", wintypes.HKEY),
                    ("dwHotKey", wintypes.DWORD),
                    ("hIconOrMonitor", wintypes.HANDLE),
                    ("hProcess", wintypes.HANDLE),
                ]

            SEE_MASK_NOCLOSEPROCESS = 0x00000040
            sei = SHELLEXECUTEINFO()
            sei.cbSize = ctypes.sizeof(sei)
            sei.fMask = SEE_MASK_NOCLOSEPROCESS
            sei.lpVerb = "runas"
            sei.lpFile = target_file
            sei.lpParameters = "/passive"
            sei.nShow = 1

            ok = ctypes.windll.shell32.ShellExecuteExW(ctypes.byref(sei))
            if not ok:
                err = ctypes.windll.kernel32.GetLastError()
                self.parent.after(0, lambda: self._fail(f"Administrator permission was declined or cancelled (Code {err})."))
                return

            if sei.hProcess:
                ctypes.windll.kernel32.WaitForSingleObject(sei.hProcess, 300000)
                ctypes.windll.kernel32.CloseHandle(sei.hProcess)

            # Wait briefly for Windows driver stack to settle
            time.sleep(1.5)

            # 3. Verify driver installation
            if is_vigembus_installed():
                self.parent.after(0, self._finish_success)
            else:
                self.parent.after(0, lambda: self._fail("Installer finished, but ViGEmBus was not detected.\nA system restart may be needed."))

        except Exception as e:
            self.parent.after(0, lambda err=str(e): self._fail(f"Setup error: {err}"))

    def _update_progress(self, percent, dl_mb, tot_mb):
        if self.cancelled:
            return
        self.progress['value'] = percent
        self.detail_lbl.config(text=f"{dl_mb:.1f} MB / {tot_mb:.1f} MB ({percent}%)")

    def _show_installing_state(self):
        if self.cancelled:
            return
        self.status_lbl.config(text="⚙️ Installing ViGEmBus Driver...", fg="#00E676")
        self.progress.config(mode='indeterminate')
        self.progress.start(12)
        self.detail_lbl.config(
            text="👉 Please click 'Yes' on the Windows Administrator prompt.\nSetup runs quietly in passive mode.",
            fg="#FFA000"
        )
        self.cancel_btn.config(state=tk.DISABLED)

    def _finish_success(self):
        if self.cancelled:
            return
        self.progress.stop()
        self.progress.config(mode='determinate', value=100)
        self.status_lbl.config(text="✅ ViGEmBus Installed Successfully!", fg="#00E676")
        self.detail_lbl.config(text="Virtual Gamepad (Xbox 360) is now active and ready for Ryujinx!", fg="#FFFFFF")
        if self.on_success:
            self.on_success()
        self.parent.after(1600, self._cancel)

    def _fail(self, reason):
        if self.cancelled:
            return
        self.progress.stop()
        self.status_lbl.config(text="❌ Installation Incomplete", fg="#FF6B6B")
        self.detail_lbl.config(text=reason, fg="#FF8A80")
        self.cancel_btn.config(text="Close", state=tk.NORMAL)


class DesktopReceiverApp:
    def __init__(self, root):
        self.root = root
        self.root.title("SwiCon - Desktop Receiver")
        self.root.geometry("780x600")
        self.root.minsize(740, 560)
        self.root.configure(bg="#12141A")

        self.port = 8899
        self.pin = random.randint(1000, 9999)
        self.session_token = 0x55AA
        self.authenticated = False
        self.client_addr = None
        self.inject_enabled = tk.BooleanVar(value=True)

        # Input mode: 'gamepad' (XInput) or 'keyboard' (legacy)
        initial_mode = 'gamepad' if (HAVE_VGAMEPAD and is_vigembus_installed()) else 'keyboard'
        self.input_mode = tk.StringVar(value=initial_mode)
        self.virtual_gamepad = VirtualGamepad()

        self.server_running = False
        self.sock = None

        # Bluetooth state
        self.bt_available = False
        self.bt_server_sock = None
        self.bt_client_sock = None
        self.bt_authenticated = False
        self.bt_session_token = 0
        self._check_bluetooth_support()

        self.button_widgets = {}
        self._build_ui()
        self._start_server()

        # Prompt for ViGEmBus installation if missing on launch
        if not is_vigembus_installed():
            self.root.after(700, self._prompt_install_vigembus)

    def _check_bluetooth_support(self):
        """Check if Python's Bluetooth socket support is available."""
        try:
            import socket as _s
            if hasattr(_s, 'AF_BLUETOOTH') and hasattr(_s, 'BTPROTO_RFCOMM'):
                self.bt_available = True
            else:
                self.bt_available = False
        except Exception:
            self.bt_available = False

    def _get_local_ips(self):
        ips = []
        try:
            hostname = socket.gethostname()
            for ip in socket.gethostbyname_ex(hostname)[2]:
                if not ip.startswith("127."):
                    ips.append(ip)
        except Exception:
            pass
        if not ips:
            ips.append("127.0.0.1")
        return ips

    def _build_ui(self):
        # Header banner
        header = tk.Frame(self.root, bg="#191C24", height=60)
        header.pack(fill=tk.X)

        title_lbl = tk.Label(header, text="🎮 SwiCon - NINTENDO SWITCH PRO CONTROLLER RECEIVER", 
                             font=("Segoe UI", 13, "bold"), fg="#FFFFFF", bg="#191C24")
        title_lbl.pack(side=tk.LEFT, padx=18, pady=14)

        self.status_badge = tk.Label(header, text="● WAITING FOR CONTROLLER...", 
                                     font=("Segoe UI", 10, "bold"), fg="#FFA000", bg="#262A36", 
                                     padx=12, pady=4, relief=tk.FLAT)
        self.status_badge.pack(side=tk.RIGHT, padx=18, pady=14)

        # Connection info panel
        conn_frame = tk.Frame(self.root, bg="#181A22", relief=tk.RIDGE, bd=1)
        conn_frame.pack(fill=tk.X, padx=16, pady=10)

        # IP display
        ips = self._get_local_ips()
        ip_text = " | ".join(ips)
        tk.Label(conn_frame, text=f"Desktop IP: {ip_text}", font=("Segoe UI", 10, "bold"), 
                 fg="#00C3E3", bg="#181A22").pack(side=tk.LEFT, padx=14, pady=8)

        tk.Label(conn_frame, text=f"Port: {self.port}", font=("Segoe UI", 10), 
                 fg="#8E95A5", bg="#181A22").pack(side=tk.LEFT, padx=10, pady=8)

        # PIN Badge
        self.pin_lbl = tk.Label(conn_frame, text=f"Security PIN: {self.pin}", 
                                font=("Segoe UI", 11, "bold"), fg="#00E676", bg="#1D2A24", 
                                padx=10, pady=2)
        self.pin_lbl.pack(side=tk.RIGHT, padx=14, pady=8)

        # Bluetooth Status Badge
        bt_text = "🔵 BT: Listening" if self.bt_available else "⚫ BT: N/A"
        bt_fg = "#2196F3" if self.bt_available else "#555"
        self.bt_status_lbl = tk.Label(conn_frame, text=bt_text,
                                       font=("Segoe UI", 9, "bold"), fg=bt_fg, bg="#181A22",
                                       padx=6, pady=2)
        self.bt_status_lbl.pack(side=tk.RIGHT, padx=4, pady=8)

        # Main visualizer frame
        vis_frame = tk.Frame(self.root, bg="#12141A")
        vis_frame.pack(fill=tk.BOTH, expand=True, padx=16, pady=4)

        # Left Joy-Con panel (Neon Blue)
        left_box = tk.LabelFrame(vis_frame, text=" Left Joy-Con (Neon Cyan) ", font=("Segoe UI", 10, "bold"), 
                                 fg="#00C3E3", bg="#161822", bd=1)
        left_box.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=4)

        # Shoulder ZL, L
        trig_left = tk.Frame(left_box, bg="#161822")
        trig_left.pack(fill=tk.X, padx=10, pady=6)
        self.button_widgets['ZL'] = self._create_btn(trig_left, "ZL (Q)", "#00C3E3")
        self.button_widgets['ZL'].pack(side=tk.LEFT, padx=4)
        self.button_widgets['L'] = self._create_btn(trig_left, "L (E)", "#00C3E3")
        self.button_widgets['L'].pack(side=tk.LEFT, padx=4)

        # Left Stick visual canvas
        stick_frame_l = tk.Frame(left_box, bg="#161822")
        stick_frame_l.pack(pady=4)
        self.l_stick_label = tk.Label(stick_frame_l, text="Left Stick", font=("Segoe UI", 8), fg="#7E8494", bg="#161822")
        self.l_stick_label.pack()
        self.l_canvas = tk.Canvas(stick_frame_l, width=100, height=100, bg="#1E222D", highlightthickness=1, highlightbackground="#2A3040")
        self.l_canvas.pack(pady=2)
        self._draw_stick_base(self.l_canvas)
        self.l_thumb = self.l_canvas.create_oval(38, 38, 62, 62, fill="#00C3E3", outline="#FFFFFF")
        self.button_widgets['LSTICK_BTN'] = self._create_btn(stick_frame_l, "Click L3 (F)", "#00C3E3")
        self.button_widgets['LSTICK_BTN'].pack(pady=2)

        # D-Pad
        dpad_frame = tk.Frame(left_box, bg="#161822")
        dpad_frame.pack(pady=6)
        tk.Label(dpad_frame, text="D-Pad (Arrows)", font=("Segoe UI", 8), fg="#7E8494", bg="#161822").pack()
        self.button_widgets['DPAD_UP'] = self._create_btn(dpad_frame, "▲ Up", "#00C3E3")
        self.button_widgets['DPAD_UP'].pack()
        d_mid = tk.Frame(dpad_frame, bg="#161822")
        d_mid.pack()
        self.button_widgets['DPAD_LEFT'] = self._create_btn(d_mid, "◀ Left", "#00C3E3")
        self.button_widgets['DPAD_LEFT'].pack(side=tk.LEFT, padx=2)
        self.button_widgets['DPAD_RIGHT'] = self._create_btn(d_mid, "Right ▶", "#00C3E3")
        self.button_widgets['DPAD_RIGHT'].pack(side=tk.LEFT, padx=2)
        self.button_widgets['DPAD_DOWN'] = self._create_btn(dpad_frame, "▼ Down", "#00C3E3")
        self.button_widgets['DPAD_DOWN'].pack()

        # Center Console Panel (-, +, Capture, Home)
        center_box = tk.LabelFrame(vis_frame, text=" Console ", font=("Segoe UI", 10, "bold"), 
                                   fg="#FFFFFF", bg="#161822", bd=1)
        center_box.pack(side=tk.LEFT, fill=tk.BOTH, padx=4)

        c_top = tk.Frame(center_box, bg="#161822")
        c_top.pack(pady=10)
        self.button_widgets['MINUS'] = self._create_btn(c_top, "− (-)", "#FFFFFF")
        self.button_widgets['MINUS'].pack(side=tk.LEFT, padx=6)
        self.button_widgets['PLUS'] = self._create_btn(c_top, "+ (=)", "#FFFFFF")
        self.button_widgets['PLUS'].pack(side=tk.LEFT, padx=6)

        tk.Label(center_box, text="SWITCH\nPRO", font=("Segoe UI", 12, "bold"), 
                 fg="#3D4456", bg="#161822", justify=tk.CENTER).pack(expand=True)

        c_bot = tk.Frame(center_box, bg="#161822")
        c_bot.pack(pady=10)
        self.button_widgets['CAPTURE'] = self._create_btn(c_bot, "▣ F12", "#FFFFFF")
        self.button_widgets['CAPTURE'].pack(side=tk.LEFT, padx=6)
        self.button_widgets['HOME'] = self._create_btn(c_bot, "⌂ Home", "#FFFFFF")
        self.button_widgets['HOME'].pack(side=tk.LEFT, padx=6)

        # Right Joy-Con panel (Neon Red)
        right_box = tk.LabelFrame(vis_frame, text=" Right Joy-Con (Neon Red) ", font=("Segoe UI", 10, "bold"), 
                                  fg="#FF4554", bg="#161822", bd=1)
        right_box.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=4)

        # Shoulder ZR, R
        trig_right = tk.Frame(right_box, bg="#161822")
        trig_right.pack(fill=tk.X, padx=10, pady=6)
        self.button_widgets['R'] = self._create_btn(trig_right, "R (U)", "#FF4554")
        self.button_widgets['R'].pack(side=tk.RIGHT, padx=4)
        self.button_widgets['ZR'] = self._create_btn(trig_right, "ZR (O)", "#FF4554")
        self.button_widgets['ZR'].pack(side=tk.RIGHT, padx=4)

        # Right Stick visual canvas
        stick_frame_r = tk.Frame(right_box, bg="#161822")
        stick_frame_r.pack(pady=4)
        self.r_stick_label = tk.Label(stick_frame_r, text="Right Stick", font=("Segoe UI", 8), fg="#7E8494", bg="#161822")
        self.r_stick_label.pack()
        self.r_canvas = tk.Canvas(stick_frame_r, width=100, height=100, bg="#1E222D", highlightthickness=1, highlightbackground="#2A3040")
        self.r_canvas.pack(pady=2)
        self._draw_stick_base(self.r_canvas)
        self.r_thumb = self.r_canvas.create_oval(38, 38, 62, 62, fill="#FF4554", outline="#FFFFFF")
        self.button_widgets['RSTICK_BTN'] = self._create_btn(stick_frame_r, "Click R3 (H)", "#FF4554")
        self.button_widgets['RSTICK_BTN'].pack(pady=2)

        # Action Buttons (A, B, X, Y diamond)
        act_frame = tk.Frame(right_box, bg="#161822")
        act_frame.pack(pady=6)
        tk.Label(act_frame, text="Actions (X/A/B/Y)", font=("Segoe UI", 8), fg="#7E8494", bg="#161822").pack()
        self.button_widgets['X'] = self._create_btn(act_frame, "X (C)", "#FF4554")
        self.button_widgets['X'].pack()
        act_mid = tk.Frame(act_frame, bg="#161822")
        act_mid.pack()
        self.button_widgets['Y'] = self._create_btn(act_mid, "Y (V)", "#FF4554")
        self.button_widgets['Y'].pack(side=tk.LEFT, padx=2)
        self.button_widgets['A'] = self._create_btn(act_mid, "A (Z)", "#FF4554")
        self.button_widgets['A'].pack(side=tk.LEFT, padx=2)
        self.button_widgets['B'] = self._create_btn(act_frame, "B (X)", "#FF4554")
        self.button_widgets['B'].pack()

        # Bottom Controls — Input Mode Toggle + Injection Toggle
        bottom_bar = tk.Frame(self.root, bg="#181A22")
        bottom_bar.pack(fill=tk.X, side=tk.BOTTOM, padx=16, pady=8)

        # --- Input Mode Selection (top row of bottom bar) ---
        mode_frame = tk.Frame(bottom_bar, bg="#181A22")
        mode_frame.pack(fill=tk.X, pady=(0, 6))

        self.mode_status_lbl = tk.Label(mode_frame, text="", font=("Segoe UI", 9, "bold"),
                                        fg="#00E676", bg="#181A22")
        self.mode_status_lbl.pack(side=tk.LEFT, padx=(6, 12))

        gamepad_rb = tk.Radiobutton(mode_frame, text="🎮 Virtual Gamepad (XInput)",
                                     variable=self.input_mode, value='gamepad',
                                     font=("Segoe UI", 9, "bold"),
                                     fg="#E2E6EF", bg="#181A22", selectcolor="#202430",
                                     activebackground="#181A22", activeforeground="#FFFFFF",
                                     command=self._on_mode_change)
        gamepad_rb.pack(side=tk.LEFT, padx=4)

        keyboard_rb = tk.Radiobutton(mode_frame, text="⌨ Keyboard Injection (Legacy)",
                                      variable=self.input_mode, value='keyboard',
                                      font=("Segoe UI", 9, "bold"),
                                      fg="#E2E6EF", bg="#181A22", selectcolor="#202430",
                                      activebackground="#181A22", activeforeground="#FFFFFF",
                                      command=self._on_mode_change)
        keyboard_rb.pack(side=tk.LEFT, padx=4)

        self.vigem_btn = tk.Button(mode_frame, text="📥 Install ViGEmBus Driver", font=("Segoe UI", 8, "bold"),
                                   bg="#00796B", fg="#FFFFFF", relief=tk.FLAT, padx=8, pady=1,
                                   command=self._install_vigembus_dialog)
        self._update_vigem_ui_state()

        # --- Action buttons row ---
        action_frame = tk.Frame(bottom_bar, bg="#181A22")
        action_frame.pack(fill=tk.X)

        chk = tk.Checkbutton(action_frame, text="Enable Input Injection",
                             variable=self.inject_enabled, font=("Segoe UI", 9, "bold"),
                             fg="#E2E6EF", bg="#181A22", selectcolor="#202430",
                             activebackground="#181A22", activeforeground="#FFFFFF")
        chk.pack(side=tk.LEFT, padx=6)

        focus_btn = tk.Button(action_frame, text="⚡ Focus Ryujinx / Game", font=("Segoe UI", 8, "bold"),
                              bg="#00796B", fg="#FFFFFF", relief=tk.FLAT, padx=8, command=self._focus_emulator)
        focus_btn.pack(side=tk.RIGHT, padx=6)

        regen_btn = tk.Button(action_frame, text="Regenerate PIN", font=("Segoe UI", 8),
                              bg="#2A2F3E", fg="#FFFFFF", relief=tk.FLAT, padx=8, command=self._regen_pin)
        regen_btn.pack(side=tk.RIGHT, padx=6)

        # Initialize mode UI state
        self._on_mode_change()

    def _focus_emulator(self):
        target_hwnds = []
        user32 = ctypes.windll.user32
        def enum_cb(hwnd, extra):
            if user32.IsWindowVisible(hwnd):
                length = user32.GetWindowTextLengthW(hwnd)
                if length > 0:
                    buff = ctypes.create_unicode_buffer(length + 1)
                    user32.GetWindowTextW(hwnd, buff, length + 1)
                    t = buff.value.lower()
                    if "ryujinx" in t or "yuzu" in t or "switch" in t:
                        target_hwnds.append((hwnd, buff.value))
            return True
        WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_int, ctypes.c_int)
        user32.EnumWindows(WNDENUMPROC(enum_cb), 0)
        if target_hwnds:
            hwnd, title = target_hwnds[0]
            user32.ShowWindow(hwnd, 9)
            user32.SetForegroundWindow(hwnd)
            messagebox.showinfo("Focus Game", f"Focused window:\n{title}\n\nInputs are now routed directly to the emulator!")
        else:
            messagebox.showinfo("Focus Game", "Ryujinx window not automatically detected.\n\nPlease click directly inside your Ryujinx game window so Windows routes inputs to it!")

    def _draw_stick_base(self, canvas):
        canvas.create_oval(10, 10, 90, 90, outline="#3A4050", width=1)
        canvas.create_line(50, 12, 50, 88, fill="#2C3242")
        canvas.create_line(12, 50, 88, 50, fill="#2C3242")

    def _create_btn(self, parent, text, accent):
        lbl = tk.Label(parent, text=text, font=("Segoe UI", 8, "bold"), 
                       fg="#8E95A5", bg="#202430", padx=6, pady=3, relief=tk.FLAT,
                       highlightthickness=1, highlightbackground="#333A4C")
        lbl.accent_color = accent
        return lbl

    def _regen_pin(self):
        self.pin = random.randint(1000, 9999)
        self.pin_lbl.config(text=f"Security PIN: {self.pin}")
        self.authenticated = False
        self.status_badge.config(text="● WAITING FOR CONTROLLER...", fg="#FFA000")

    def _on_mode_change(self):
        """Handle switching between Virtual Gamepad and Keyboard modes."""
        mode = self.input_mode.get()
        if mode == 'gamepad':
            # Check if ViGEmBus driver is installed
            if not is_vigembus_installed():
                self.input_mode.set('keyboard')
                self.mode_status_lbl.config(text="⚠️ ViGEmBus driver missing", fg="#FFA000")
                self._update_stick_labels('keyboard')
                self._update_vigem_ui_state()
                self._prompt_install_vigembus()
                return

            # Activate virtual gamepad, release keyboard keys
            release_all()
            if not self.virtual_gamepad.active:
                ok = self.virtual_gamepad.connect()
                if not ok:
                    self.input_mode.set('keyboard')
                    self.mode_status_lbl.config(text="❌ Gamepad init failed — Keyboard mode", fg="#FF6B6B")
                    self._update_stick_labels('keyboard')
                    self._update_vigem_ui_state()
                    return
            self.mode_status_lbl.config(text="🎮 Virtual Gamepad Active (Xbox 360)", fg="#00E676")
            self._update_stick_labels('gamepad')
            self._update_vigem_ui_state()
        else:
            # Deactivate virtual gamepad, switch to keyboard
            if self.virtual_gamepad.active:
                self.virtual_gamepad.disconnect()
            self.mode_status_lbl.config(text="⌨ Keyboard Injection Mode", fg="#FFA000")
            self._update_stick_labels('keyboard')
            self._update_vigem_ui_state()

    def _update_vigem_ui_state(self):
        """Show or hide the 'Install ViGEmBus' button based on driver installation."""
        if hasattr(self, 'vigem_btn'):
            if is_vigembus_installed():
                self.vigem_btn.pack_forget()
            else:
                self.vigem_btn.pack(side=tk.LEFT, padx=6)

    def _prompt_install_vigembus(self):
        """Ask user if they would like to download and install ViGEmBus automatically."""
        prompt = (
            "🎮 Virtual Gamepad mode gives Ryujinx true analog stick control (walk/run, smooth camera), "
            "but requires the official ViGEmBus driver.\n\n"
            "ViGEmBus was not found on this computer.\n\n"
            "Would you like SwiCon to download and install it automatically right now?\n\n"
            "(Click 'Yes' to auto-download & install, or 'No' to stay in Keyboard mode)"
        )
        if messagebox.askyesno("Install ViGEmBus Driver?", prompt, icon='question'):
            self._install_vigembus_dialog()

    def _install_vigembus_dialog(self):
        """Open the auto-download & installer popup dialog."""
        ViGEmInstallerDialog(self.root, on_success=self._on_vigembus_installed_successfully)

    def _on_vigembus_installed_successfully(self):
        """Called when ViGEmBus installer finishes successfully."""
        init_vgamepad_support()
        self.input_mode.set('gamepad')
        self._on_mode_change()
        self._update_vigem_ui_state()

    def _update_stick_labels(self, mode):
        if mode == 'gamepad':
            self.l_stick_label.config(text="Left Stick (Analog)")
            self.r_stick_label.config(text="Right Stick (Analog)")
        else:
            self.l_stick_label.config(text="Left Stick (W/A/S/D)")
            self.r_stick_label.config(text="Right Stick (I/J/K/L)")

    def _set_btn_active(self, key, active):
        widget = self.button_widgets.get(key)
        if widget:
            if active:
                widget.config(bg=widget.accent_color, fg="#000000")
            else:
                widget.config(bg="#202430", fg="#8E95A5")

    def _start_server(self):
        self.server_running = True
        self.thread = threading.Thread(target=self._server_loop, daemon=True)
        self.thread.start()
        self.beacon_thread = threading.Thread(target=self._beacon_loop, daemon=True)
        self.beacon_thread.start()
        # Start Bluetooth RFCOMM server if available
        if self.bt_available:
            self.bt_thread = threading.Thread(target=self._bt_server_loop, daemon=True)
            self.bt_thread.start()

    def _bt_server_loop(self):
        """Bluetooth RFCOMM server — accepts connections and processes the SwiCon protocol."""
        BT_CHANNEL = 4  # RFCOMM channel number
        sdp_qs = None

        while self.server_running:
            try:
                # Create and bind the RFCOMM server socket
                self.bt_server_sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
                self.bt_server_sock.bind(("00:00:00:00:00:00", BT_CHANNEL))
                self.bt_server_sock.listen(1)
                self.bt_server_sock.settimeout(2.0)  # Allow periodic check of server_running

                # Register SPP Service with Windows SDP
                sdp_qs = register_bt_sdp(self.bt_server_sock)

                self.root.after(0, lambda: self.bt_status_lbl.config(text="🔵 BT: Listening (SPP)", fg="#2196F3"))

                while self.server_running:
                    try:
                        client_sock, client_info = self.bt_server_sock.accept()
                    except socket.timeout:
                        continue
                    except OSError:
                        break

                    bt_addr = client_info[0] if isinstance(client_info, tuple) else str(client_info)
                    print(f"[BT] Connection from {bt_addr}")
                    self.bt_client_sock = client_sock
                    self.bt_authenticated = False
                    self.bt_session_token = 0

                    self.root.after(0, lambda a=bt_addr: self.bt_status_lbl.config(
                        text=f"🔵 BT: Connected ({a[-5:]})", fg="#00E676"))

                    # Handle this client's stream
                    self._handle_bt_client(client_sock, bt_addr)

                    self.root.after(0, lambda: self.bt_status_lbl.config(
                        text="🔵 BT: Listening (SPP)", fg="#2196F3"))

            except Exception as e:
                print(f"[BT] Server error: {e}")
                self.root.after(0, lambda err=str(e): self.bt_status_lbl.config(
                    text=f"🔴 BT: Error", fg="#FF6B6B"))
                time.sleep(3)  # Wait before retrying
            finally:
                if sdp_qs:
                    unregister_bt_sdp(sdp_qs)
                    sdp_qs = None
                try:
                    self.bt_server_sock.close()
                except Exception:
                    pass
                self.bt_server_sock = None

    def _handle_bt_client(self, client_sock, bt_addr):
        """Process the binary protocol stream from a connected Bluetooth client."""
        buffer = b''
        client_sock.settimeout(5.0)

        # Packet sizes by type
        PACKET_SIZES = {
            1: 8,   # AUTH_REQUEST: SW(2) + type(1) + seq(1) + pin(4)
            4: 14,  # INPUT_STATE:  SW(2) + type(1) + seq(1) + buttons(4) + sticks(4) + token(2)
            5: 4,   # PING:         SW(2) + type(1) + seq(1)
            7: 4,   # DISCOVER:     SW(2) + type(1) + seq(1)
        }

        try:
            while self.server_running:
                try:
                    chunk = client_sock.recv(1024)
                except socket.timeout:
                    continue
                except ConnectionResetError:
                    break

                if not chunk:
                    break  # Client disconnected

                buffer += chunk

                # Parse packets from the buffer
                while len(buffer) >= 4:
                    # Find magic header 'SW'
                    if buffer[0] != ord('S') or buffer[1] != ord('W'):
                        buffer = buffer[1:]  # Skip invalid byte
                        continue

                    pkt_type = buffer[2]

                    if pkt_type not in PACKET_SIZES:
                        buffer = buffer[1:]  # Unknown type, skip
                        continue

                    expected_len = PACKET_SIZES[pkt_type]
                    if len(buffer) < expected_len:
                        break  # Wait for more data

                    packet = buffer[:expected_len]
                    buffer = buffer[expected_len:]
                    seq = packet[3]

                    # --- Process packet ---
                    if pkt_type == 1 and len(packet) >= 8:
                        # Auth Request
                        req_pin = struct.unpack("<I", packet[4:8])[0]
                        if req_pin == self.pin:
                            self.bt_authenticated = True
                            self.bt_session_token = random.randint(1, 0xFFFF)
                            resp = struct.pack("<BBBH", ord('S'), 0x57, 2, self.bt_session_token)
                            # Need to add seq byte: SW + type + seq + token
                            resp = struct.pack("<BBBBH", ord('S'), ord('W'), 2, seq, self.bt_session_token)
                            client_sock.send(resp)
                            self.root.after(0, lambda: self._on_bt_authenticated(bt_addr))
                        else:
                            resp = struct.pack("<BBBB", ord('S'), ord('W'), 3, seq)
                            client_sock.send(resp)

                    elif pkt_type == 5:
                        # Ping → Pong
                        pong = struct.pack("<BBBB", ord('S'), ord('W'), 6, seq)
                        client_sock.send(pong)

                    elif pkt_type == 4 and len(packet) >= 14:
                        # Input State
                        if not self.bt_authenticated:
                            continue
                        token = struct.unpack("<H", packet[12:14])[0]
                        if token != self.bt_session_token:
                            continue

                        buttons, lx, ly, rx, ry = struct.unpack("<Ibbbb", packet[4:12])
                        self.root.after(0, lambda b=buttons, lx=lx, ly=ly, rx=rx, ry=ry:
                                        self._process_inputs(b, lx, ly, rx, ry))

        except Exception as e:
            print(f"[BT] Client handler error: {e}")
        finally:
            try:
                client_sock.close()
            except Exception:
                pass
            self.bt_client_sock = None
            self.bt_authenticated = False

    def _on_bt_authenticated(self, bt_addr):
        """Called when a Bluetooth client successfully authenticates."""
        self.status_badge.config(text=f"● BT CONNECTED: {bt_addr[-8:]}", fg="#2196F3")

    def _beacon_loop(self):
        b_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        b_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        hostname = socket.gethostname()[:20].encode('utf-8')
        while self.server_running:
            try:
                # Broadcast Discovery Response (Type 8) so phones auto-detect PC instantly
                beacon = struct.pack("<BBBBHI B", ord('S'), ord('W'), 8, 0, self.port, self.pin, len(hostname)) + hostname
                b_sock.sendto(beacon, ("255.255.255.255", self.port))
            except Exception:
                pass
            time.sleep(1.2)
        b_sock.close()

    def _server_loop(self):
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            self.sock.bind(("0.0.0.0", self.port))
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("Socket Error", f"Could not bind UDP port {self.port}: {e}"))
            return

        while self.server_running:
            try:
                data, addr = self.sock.recvfrom(1024)
                if len(data) < 4 or data[0] != ord('S') or data[1] != ord('W'):
                    continue

                pkt_type = data[2]
                seq = data[3]

                # Auto-Discovery Probe from Mobile App
                if pkt_type == 7:
                    hostname = socket.gethostname()[:20].encode('utf-8')
                    resp = struct.pack("<BBBBHI B", ord('S'), ord('W'), 8, seq, self.port, self.pin, len(hostname)) + hostname
                    self.sock.sendto(resp, addr)
                    continue

                # Auth Request
                if pkt_type == 1 and len(data) >= 8:
                    req_pin = struct.unpack("<I", data[4:8])[0]
                    if req_pin == self.pin:
                        self.authenticated = True
                        self.client_addr = addr
                        self.session_token = random.randint(1, 0xFFFF)
                        # Auth OK packet
                        resp = struct.pack("<BBBBH", ord('S'), ord('W'), 2, seq, self.session_token)
                        self.sock.sendto(resp, addr)
                        self.root.after(0, lambda: self._on_authenticated(addr))
                    else:
                        resp = struct.pack("<BBBB", ord('S'), ord('W'), 3, seq)
                        self.sock.sendto(resp, addr)
                    continue

                # Ping
                if pkt_type == 5:
                    pong = struct.pack("<BBBB", ord('S'), ord('W'), 6, seq)
                    self.sock.sendto(pong, addr)
                    continue

                # Input State
                if pkt_type == 4 and len(data) >= 14:
                    if not self.authenticated:
                        continue
                    token = struct.unpack("<H", data[12:14])[0]
                    if token != self.session_token:
                        continue

                    buttons, lx, ly, rx, ry = struct.unpack("<Ibbbb", data[4:12])
                    self.root.after(0, lambda b=buttons, lx=lx, ly=ly, rx=rx, ry=ry: self._process_inputs(b, lx, ly, rx, ry))

            except Exception:
                break

    def _on_authenticated(self, addr):
        self.status_badge.config(text=f"● CONNECTED: {addr[0]}", fg="#00E676")

    def _process_inputs(self, buttons, lx, ly, rx, ry):
        inject = self.inject_enabled.get()
        mode = self.input_mode.get()

        btn_map = [
            ('A', 1 << 0), ('B', 1 << 1), ('X', 1 << 2), ('Y', 1 << 3),
            ('DPAD_UP', 1 << 4), ('DPAD_DOWN', 1 << 5), ('DPAD_LEFT', 1 << 6), ('DPAD_RIGHT', 1 << 7),
            ('L', 1 << 8), ('R', 1 << 9), ('ZL', 1 << 10), ('ZR', 1 << 11),
            ('PLUS', 1 << 12), ('MINUS', 1 << 13),
            ('LSTICK_BTN', 1 << 14), ('RSTICK_BTN', 1 << 15),
            ('HOME', 1 << 16), ('CAPTURE', 1 << 17)
        ]

        # Always update visual button highlights regardless of mode
        for name, mask in btn_map:
            pressed = (buttons & mask) != 0
            self._set_btn_active(name, pressed)

        # Always update stick thumb visualization
        cx_l = 50 + (lx / 127.0) * 32
        cy_l = 50 + (ly / 127.0) * 32
        self.l_canvas.coords(self.l_thumb, cx_l - 12, cy_l - 12, cx_l + 12, cy_l + 12)

        cx_r = 50 + (rx / 127.0) * 32
        cy_r = 50 + (ry / 127.0) * 32
        self.r_canvas.coords(self.r_thumb, cx_r - 12, cy_r - 12, cx_r + 12, cy_r + 12)

        if not inject:
            return

        # ===== VIRTUAL GAMEPAD MODE =====
        if mode == 'gamepad' and self.virtual_gamepad.active:
            self.virtual_gamepad.update_state(buttons, lx, ly, rx, ry)
            return

        # ===== KEYBOARD INJECTION MODE (Legacy) =====
        # Dispatch buttons to keyboard
        for name, mask in btn_map:
            pressed = (buttons & mask) != 0
            if name in VK_MAP:
                inject_key(VK_MAP[name][0], pressed)

        # Left Stick → W/A/S/D
        l_up = ly < -45
        l_down = ly > 45
        l_left = lx < -45
        l_right = lx > 45
        inject_key(VK_MAP['L_UP'][0], l_up)
        inject_key(VK_MAP['L_DOWN'][0], l_down)
        inject_key(VK_MAP['L_LEFT'][0], l_left)
        inject_key(VK_MAP['L_RIGHT'][0], l_right)

        # Right Stick → I/J/K/L
        r_up = ry < -45
        r_down = ry > 45
        r_left = rx < -45
        r_right = rx > 45
        inject_key(VK_MAP['R_UP'][0], r_up)
        inject_key(VK_MAP['R_DOWN'][0], r_down)
        inject_key(VK_MAP['R_LEFT'][0], r_left)
        inject_key(VK_MAP['R_RIGHT'][0], r_right)

    def close(self):
        self.server_running = False
        release_all()
        if self.virtual_gamepad.active:
            self.virtual_gamepad.disconnect()
        if self.sock:
            self.sock.close()
        # Clean up Bluetooth
        try:
            if self.bt_client_sock:
                self.bt_client_sock.close()
        except Exception:
            pass
        try:
            if self.bt_server_sock:
                self.bt_server_sock.close()
        except Exception:
            pass
        self.root.destroy()

if __name__ == "__main__":
    try:
        root = tk.Tk()
        app = DesktopReceiverApp(root)
        root.protocol("WM_DELETE_WINDOW", app.close)
        root.mainloop()
    except Exception as e:
        import traceback
        err_msg = traceback.format_exc()
        try:
            with open("swicon_crash.log", "w", encoding="utf-8") as f:
                f.write(err_msg)
            messagebox.showerror("SwiCon Error", f"Startup error:\n\n{err_msg}")
        except Exception:
            pass

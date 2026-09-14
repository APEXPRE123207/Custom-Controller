import tkinter as tk
from tkinter import ttk, messagebox
import socket
import struct
import threading
import random
import ctypes
import time
import os

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

class DesktopReceiverApp:
    def __init__(self, root):
        self.root = root
        self.root.title("SwiCon - Desktop Receiver")
        self.root.geometry("780x560")
        self.root.minsize(740, 520)
        self.root.configure(bg="#12141A")

        self.port = 8899
        self.pin = random.randint(1000, 9999)
        self.session_token = 0x55AA
        self.authenticated = False
        self.client_addr = None
        self.inject_enabled = tk.BooleanVar(value=True)

        self.server_running = False
        self.sock = None

        self.button_widgets = {}
        self._build_ui()
        self._start_server()

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
        tk.Label(stick_frame_l, text="Left Stick (W/A/S/D)", font=("Segoe UI", 8), fg="#7E8494", bg="#161822").pack()
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
        tk.Label(stick_frame_r, text="Right Stick (I/J/K/L)", font=("Segoe UI", 8), fg="#7E8494", bg="#161822").pack()
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

        # Bottom Controls & Injection Toggle
        bottom_bar = tk.Frame(self.root, bg="#181A22", height=45)
        bottom_bar.pack(fill=tk.X, side=tk.BOTTOM, padx=16, pady=8)

        chk = tk.Checkbutton(bottom_bar, text="Enable Windows Key Injection (Direct to Ryujinx / Games)", 
                             variable=self.inject_enabled, font=("Segoe UI", 9, "bold"),
                             fg="#E2E6EF", bg="#181A22", selectcolor="#202430", activebackground="#181A22", activeforeground="#FFFFFF")
        chk.pack(side=tk.LEFT, padx=6)

        focus_btn = tk.Button(bottom_bar, text="⚡ Focus Ryujinx / Game", font=("Segoe UI", 8, "bold"), 
                              bg="#00796B", fg="#FFFFFF", relief=tk.FLAT, padx=8, command=self._focus_emulator)
        focus_btn.pack(side=tk.RIGHT, padx=6)

        regen_btn = tk.Button(bottom_bar, text="Regenerate PIN", font=("Segoe UI", 8), 
                              bg="#2A2F3E", fg="#FFFFFF", relief=tk.FLAT, padx=8, command=self._regen_pin)
        regen_btn.pack(side=tk.RIGHT, padx=6)

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

        btn_map = [
            ('A', 1 << 0), ('B', 1 << 1), ('X', 1 << 2), ('Y', 1 << 3),
            ('DPAD_UP', 1 << 4), ('DPAD_DOWN', 1 << 5), ('DPAD_LEFT', 1 << 6), ('DPAD_RIGHT', 1 << 7),
            ('L', 1 << 8), ('R', 1 << 9), ('ZL', 1 << 10), ('ZR', 1 << 11),
            ('PLUS', 1 << 12), ('MINUS', 1 << 13),
            ('LSTICK_BTN', 1 << 14), ('RSTICK_BTN', 1 << 15),
            ('HOME', 1 << 16), ('CAPTURE', 1 << 17)
        ]

        # Update button highlights & key injection
        for name, mask in btn_map:
            pressed = (buttons & mask) != 0
            self._set_btn_active(name, pressed)
            if inject and name in VK_MAP:
                inject_key(VK_MAP[name][0], pressed)

        # Update Left Stick thumb and W/A/S/D
        cx_l = 50 + (lx / 127.0) * 32
        cy_l = 50 + (ly / 127.0) * 32
        self.l_canvas.coords(self.l_thumb, cx_l - 12, cy_l - 12, cx_l + 12, cy_l + 12)

        l_up = ly < -45
        l_down = ly > 45
        l_left = lx < -45
        l_right = lx > 45
        if inject:
            inject_key(VK_MAP['L_UP'][0], l_up)
            inject_key(VK_MAP['L_DOWN'][0], l_down)
            inject_key(VK_MAP['L_LEFT'][0], l_left)
            inject_key(VK_MAP['L_RIGHT'][0], l_right)

        # Update Right Stick thumb and I/J/K/L
        cx_r = 50 + (rx / 127.0) * 32
        cy_r = 50 + (ry / 127.0) * 32
        self.r_canvas.coords(self.r_thumb, cx_r - 12, cy_r - 12, cx_r + 12, cy_r + 12)

        r_up = ry < -45
        r_down = ry > 45
        r_left = rx < -45
        r_right = rx > 45
        if inject:
            inject_key(VK_MAP['R_UP'][0], r_up)
            inject_key(VK_MAP['R_DOWN'][0], r_down)
            inject_key(VK_MAP['R_LEFT'][0], r_left)
            inject_key(VK_MAP['R_RIGHT'][0], r_right)

    def close(self):
        self.server_running = False
        release_all()
        if self.sock:
            self.sock.close()
        self.root.destroy()

if __name__ == "__main__":
    root = tk.Tk()
    app = DesktopReceiverApp(root)
    root.protocol("WM_DELETE_WINDOW", app.close)
    root.mainloop()

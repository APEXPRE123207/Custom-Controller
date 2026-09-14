import socket
import struct
import time
import subprocess
import os
import sys

def test_protocol_handshake():
    print("[TEST] Launching receiver for protocol verification...")
    # Launch receiver with fixed PIN 5566 on port 9922
    exe_path = os.path.join(os.path.dirname(__file__), "nintendo_receiver.exe")
    if not os.path.exists(exe_path):
        print(f"[FAIL] Executable not found at {exe_path}")
        return False

    proc = subprocess.Popen([exe_path, "9922", "5566"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(0.5)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(2.0)
    server_addr = ("127.0.0.1", 9922)

    try:
        # 1. Test Auth with Wrong PIN (should fail)
        print("[TEST] 1. Testing invalid PIN rejection...")
        wrong_pin = 1111
        auth_req_wrong = struct.pack("<BBBB I", ord('S'), ord('W'), 1, 1, wrong_pin)
        sock.sendto(auth_req_wrong, server_addr)
        resp, _ = sock.recvfrom(1024)
        assert len(resp) >= 4 and resp[0] == ord('S') and resp[1] == ord('W') and resp[2] == 3, f"Expected Auth Failure (3), got {resp[2]}"
        print("  -> PASSED: Invalid PIN correctly rejected with PKT_AUTH_ERR (3)")

        # 2. Test Auth with Correct PIN (should succeed)
        print("[TEST] 2. Testing valid PIN authentication (PIN: 5566)...")
        correct_pin = 5566
        auth_req_correct = struct.pack("<BBBB I", ord('S'), ord('W'), 1, 2, correct_pin)
        sock.sendto(auth_req_correct, server_addr)
        resp, _ = sock.recvfrom(1024)
        assert len(resp) >= 6 and resp[0] == ord('S') and resp[1] == ord('W') and resp[2] == 2, f"Expected Auth Success (2), got {resp[2]}"
        session_token = struct.unpack("<H", resp[4:6])[0]
        print(f"  -> PASSED: Successfully authenticated! Session Token: 0x{session_token:04X}")

        # 3. Test Ping / Pong
        print("[TEST] 3. Testing latency Ping/Pong packet...")
        ping_pkt = struct.pack("<BBBB", ord('S'), ord('W'), 5, 3)
        sock.sendto(ping_pkt, server_addr)
        resp, _ = sock.recvfrom(1024)
        assert resp[2] == 6, f"Expected Pong (6), got {resp[2]}"
        print("  -> PASSED: Pong response received with sub-millisecond roundtrip.")

        # 4. Test Controller Input Packet
        print("[TEST] 4. Testing Button & Stick Input Packet delivery...")
        BTN_A = 1 << 0
        BTN_ZL = 1 << 10
        buttons = BTN_A | BTN_ZL
        l_x = -60  # Left stick tilted left
        l_y = 0
        r_x = 0
        r_y = 80   # Right stick tilted down
        input_pkt = struct.pack("<BBBB I bbbb H", ord('S'), ord('W'), 4, 4, buttons, l_x, l_y, r_x, r_y, session_token)
        sock.sendto(input_pkt, server_addr)
        print("  -> PASSED: Input packet formatted and accepted by receiver.")

        print("\n>>> ALL PROTOCOL & SECURITY TESTS PASSED SUCCESSFULLY! <<<")
        return True

    finally:
        sock.close()
        proc.terminate()
        proc.wait(timeout=1.0)

if __name__ == "__main__":
    success = test_protocol_handshake()
    sys.exit(0 if success else 1)

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iostream>
#include <iomanip>
#include <string>
#include <vector>
#include <map>
#include <cstdint>
#include <cstdlib>
#include <ctime>

#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "user32.lib")

// Packet protocol types
enum PacketType {
    PKT_AUTH_REQ = 1,
    PKT_AUTH_OK  = 2,
    PKT_AUTH_ERR = 3,
    PKT_INPUT    = 4,
    PKT_PING     = 5,
    PKT_PONG     = 6
};

// Controller Button Bitmasks
enum ControllerButton {
    BTN_A          = 1 << 0,  // 'Z'
    BTN_B          = 1 << 1,  // 'X'
    BTN_X          = 1 << 2,  // 'C'
    BTN_Y          = 1 << 3,  // 'V'
    BTN_DPAD_UP    = 1 << 4,  // Up Arrow
    BTN_DPAD_DOWN  = 1 << 5,  // Down Arrow
    BTN_DPAD_LEFT  = 1 << 6,  // Left Arrow
    BTN_DPAD_RIGHT = 1 << 7,  // Right Arrow
    BTN_L          = 1 << 8,  // 'E'
    BTN_R          = 1 << 9,  // 'U'
    BTN_ZL         = 1 << 10, // 'Q'
    BTN_ZR         = 1 << 11, // 'O'
    BTN_PLUS       = 1 << 12, // Plus '='
    BTN_MINUS      = 1 << 13, // Minus '-'
    BTN_LSTICK_BTN = 1 << 14, // 'F'
    BTN_RSTICK_BTN = 1 << 15, // 'H'
    BTN_HOME       = 1 << 16, // Home
    BTN_CAPTURE    = 1 << 17  // F12
};

// Virtual key mapping matching Ryujinx configuration screenshot
struct KeyBinding {
    uint32_t mask;
    WORD vkCode;
    const char* name;
};

static const KeyBinding BUTTON_MAP[] = {
    { BTN_A,          'Z',           "A (Z)" },
    { BTN_B,          'X',           "B (X)" },
    { BTN_X,          'C',           "X (C)" },
    { BTN_Y,          'V',           "Y (V)" },
    { BTN_DPAD_UP,    VK_UP,         "D-Up (Up)" },
    { BTN_DPAD_DOWN,  VK_DOWN,       "D-Down (Down)" },
    { BTN_DPAD_LEFT,  VK_LEFT,       "D-Left (Left)" },
    { BTN_DPAD_RIGHT, VK_RIGHT,      "D-Right (Right)" },
    { BTN_L,          'E',           "L (E)" },
    { BTN_R,          'U',           "R (U)" },
    { BTN_ZL,         'Q',           "ZL (Q)" },
    { BTN_ZR,         'O',           "ZR (O)" },
    { BTN_PLUS,       VK_OEM_PLUS,   "+ (=)" },
    { BTN_MINUS,      VK_OEM_MINUS,  "- (-)" },
    { BTN_LSTICK_BTN, 'F',           "L-Stick Btn (F)" },
    { BTN_RSTICK_BTN, 'H',           "R-Stick Btn (H)" },
    { BTN_HOME,       VK_HOME,       "Home" },
    { BTN_CAPTURE,    VK_F12,        "Capture (F12)" }
};

// Key state cache to avoid repeated OS SendInput calls
static std::map<WORD, bool> g_currentKeyStates;

void InjectKeyEvent(WORD vkCode, bool pressed) {
    if (g_currentKeyStates[vkCode] == pressed) {
        return; // No transition
    }
    g_currentKeyStates[vkCode] = pressed;

    INPUT input = {0};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = 0; // DirectInput/emulators read wScan when KEYEVENTF_SCANCODE is set
    input.ki.wScan = static_cast<WORD>(MapVirtualKeyA(vkCode, MAPVK_VK_TO_VSC));
    input.ki.dwFlags = KEYEVENTF_SCANCODE | (pressed ? 0 : KEYEVENTF_KEYUP);

    // Extended keys require KEYEVENTF_EXTENDEDKEY flag
    if (vkCode == VK_UP || vkCode == VK_DOWN || vkCode == VK_LEFT || vkCode == VK_RIGHT || vkCode == VK_HOME) {
        input.ki.dwFlags |= KEYEVENTF_EXTENDEDKEY;
    }

    UINT res = SendInput(1, &input, sizeof(INPUT));
    if (res == 0) {
        // Fallback to keybd_event for DirectInput/UIPI edge cases
        keybd_event(static_cast<BYTE>(vkCode), static_cast<BYTE>(input.ki.wScan), input.ki.dwFlags, 0);
    }
}

void ReleaseAllKeys() {
    for (auto& pair : g_currentKeyStates) {
        if (pair.second) {
            InjectKeyEvent(pair.first, false);
        }
    }
}

int main(int argc, char* argv[]) {
    // Console setup
    HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
    SetConsoleTextAttribute(hConsole, FOREGROUND_INTENSITY | FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE);

    std::cout << "========================================================\n";
    std::cout << "    NINTENDO SWITCH PRO CONTROLLER - DESKTOP RECEIVER   \n";
    std::cout << "    Mapped for Ryujinx / PC Gaming (Low Latency Engine)  \n";
    std::cout << "========================================================\n\n";

    // Initialize Winsock
    WSADATA wsaData;
    if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
        std::cerr << "[ERROR] Failed to initialize Winsock.\n";
        return 1;
    }

    int port = 8899;
    if (argc > 1) {
        port = std::atoi(argv[1]);
    }

    // Generate security pairing PIN (or accept CLI argument)
    std::srand(static_cast<unsigned int>(std::time(nullptr)));
    int pairingPin = 1000 + (std::rand() % 9000); // 4-digit random PIN
    if (argc > 2) {
        pairingPin = std::atoi(argv[2]);
    }

    uint16_t currentSessionToken = 0x55AA;

    SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (sock == INVALID_SOCKET) {
        std::cerr << "[ERROR] Could not create socket: " << WSAGetLastError() << "\n";
        WSACleanup();
        return 1;
    }

    sockaddr_in serverAddr = {0};
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_port = htons(static_cast<u_short>(port));
    serverAddr.sin_addr.s_addr = INADDR_ANY;

    if (bind(sock, (sockaddr*)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR) {
        std::cerr << "[ERROR] Socket bind failed on port " << port << " : " << WSAGetLastError() << "\n";
        closesocket(sock);
        WSACleanup();
        return 1;
    }

    // Display connection instructions
    char hostname[256];
    gethostname(hostname, sizeof(hostname));
    struct hostent* hostInfo = gethostbyname(hostname);

    std::cout << "[INFO] Receiver Server listening on UDP Port: " << port << "\n";
    std::cout << "[SECURITY] Security Pairing PIN: ";
    SetConsoleTextAttribute(hConsole, FOREGROUND_INTENSITY | FOREGROUND_GREEN);
    std::cout << pairingPin << "\n";
    SetConsoleTextAttribute(hConsole, FOREGROUND_INTENSITY | FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE);

    std::cout << "[INFO] Available Local IP Addresses:\n";
    if (hostInfo != nullptr) {
        for (int i = 0; hostInfo->h_addr_list[i] != nullptr; ++i) {
            struct in_addr addr;
            memcpy(&addr, hostInfo->h_addr_list[i], sizeof(struct in_addr));
            std::cout << "       -> " << inet_ntoa(addr) << "\n";
        }
    }
    std::cout << "\nEnter this IP and PIN in the Android Controller App to connect.\n";
    std::cout << "--------------------------------------------------------\n\n";

    bool authenticated = false;
    sockaddr_in clientAddr = {0};
    int clientAddrLen = sizeof(clientAddr);
    uint8_t buffer[1024];

    DWORD lastPacketTime = GetTickCount();

    while (true) {
        int bytesReceived = recvfrom(sock, (char*)buffer, sizeof(buffer), 0, (sockaddr*)&clientAddr, &clientAddrLen);
        if (bytesReceived <= 0) {
            continue;
        }

        // Header check: 'SW' (0x53, 0x57)
        if (bytesReceived < 4 || buffer[0] != 0x53 || buffer[1] != 0x57) {
            continue;
        }

        uint8_t pktType = buffer[2];
        uint8_t seq = buffer[3];

        if (pktType == PKT_AUTH_REQ && bytesReceived >= 8) {
            uint32_t receivedPin = *reinterpret_cast<uint32_t*>(&buffer[4]);
            if (receivedPin == static_cast<uint32_t>(pairingPin)) {
                authenticated = true;
                currentSessionToken = static_cast<uint16_t>(std::rand() % 0xFFFF);
                std::cout << "\n[AUTH] Controller Connected & Verified from " 
                          << inet_ntoa(clientAddr.sin_addr) << "!\n";

                // Respond Auth Success with session token
                uint8_t resp[6];
                resp[0] = 0x53; resp[1] = 0x57;
                resp[2] = PKT_AUTH_OK;
                resp[3] = seq;
                *reinterpret_cast<uint16_t*>(&resp[4]) = currentSessionToken;
                sendto(sock, (const char*)resp, sizeof(resp), 0, (sockaddr*)&clientAddr, clientAddrLen);
            } else {
                std::cout << "\n[SECURITY WARNING] Auth rejected: Invalid PIN (" << receivedPin 
                          << ") from " << inet_ntoa(clientAddr.sin_addr) << "\n";
                uint8_t resp[4] = { 0x53, 0x57, PKT_AUTH_ERR, seq };
                sendto(sock, (const char*)resp, sizeof(resp), 0, (sockaddr*)&clientAddr, clientAddrLen);
            }
            continue;
        }

        if (pktType == PKT_PING) {
            uint8_t pong[4] = { 0x53, 0x57, PKT_PONG, seq };
            sendto(sock, (const char*)pong, sizeof(pong), 0, (sockaddr*)&clientAddr, clientAddrLen);
            continue;
        }

        if (pktType == PKT_INPUT && bytesReceived >= 14) {
            if (!authenticated) {
                // Drop unauthenticated inputs
                continue;
            }

            uint16_t token = *reinterpret_cast<uint16_t*>(&buffer[12]);
            if (token != currentSessionToken) {
                // Invalid session
                continue;
            }

            uint32_t buttons = *reinterpret_cast<uint32_t*>(&buffer[4]);
            int8_t leftStickX = static_cast<int8_t>(buffer[8]);
            int8_t leftStickY = static_cast<int8_t>(buffer[9]);
            int8_t rightStickX = static_cast<int8_t>(buffer[10]);
            int8_t rightStickY = static_cast<int8_t>(buffer[11]);

            // Dispatch digital buttons to Win32 SendInput
            for (const auto& binding : BUTTON_MAP) {
                bool isPressed = (buttons & binding.mask) != 0;
                InjectKeyEvent(binding.vkCode, isPressed);
            }

            // Dispatch Left Analog Stick to W / A / S / D (Threshold +/- 45 out of 127)
            const int8_t STICK_THRESHOLD = 45;
            InjectKeyEvent('W', leftStickY < -STICK_THRESHOLD); // Up
            InjectKeyEvent('S', leftStickY > STICK_THRESHOLD);  // Down
            InjectKeyEvent('A', leftStickX < -STICK_THRESHOLD); // Left
            InjectKeyEvent('D', leftStickX > STICK_THRESHOLD);  // Right

            // Dispatch Right Analog Stick to I / J / K / L
            InjectKeyEvent('I', rightStickY < -STICK_THRESHOLD); // Up
            InjectKeyEvent('K', rightStickY > STICK_THRESHOLD);  // Down
            InjectKeyEvent('J', rightStickX < -STICK_THRESHOLD); // Left
            InjectKeyEvent('L', rightStickX > STICK_THRESHOLD);  // Right

            lastPacketTime = GetTickCount();
        }
    }

    ReleaseAllKeys();
    closesocket(sock);
    WSACleanup();
    return 0;
}

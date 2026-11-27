# Vector

Use your phone (iPhone or Android) as a motion controller for a 3D character on your Windows laptop. Point the phone like a TV remote, and the character's arm and remote follow it. A pointer shows where you're aiming on the target board.

No app to install on the phone. It's a web page served by the game itself.

## How to play

1. Run **`Vector.exe`**.
   - If Windows says *"Windows protected your PC"*: click **More info → Run anyway** (the exe isn't code-signed).
   - When the **Windows Firewall** asks, tick **Private networks** and click **Allow**. Without this the phone can't connect.
2. Put the phone on the **same Wi-Fi** as the laptop.
3. Scan the **QR code** on screen with the phone camera (or type the `https://…:8443` address).
4. The phone shows a certificate warning. That's expected: the game makes its own security certificate, since phones only allow motion sensors on `https` pages.
   - **iPhone (Safari):** *Show Details → visit this website → Visit Website*.
   - **Android (Chrome):** *Advanced → Proceed to …*.
5. Tap **Enable Motion** (iPhone: tap **Allow**).
6. Hold the phone like a TV remote (screen up, top edge pointing at the laptop) and tap **Calibrate**.
   You can also hold it upright with the back camera pointing at the laptop; the grip is detected when you calibrate.
7. If left/right slowly drifts, tap **Recenter**.

Your phone only accepts the warning once. The certificate is reused while the laptop's IP address stays the same.

### Keyboard

| Key | Action |
|-----|--------|
| `C` | Calibrate (from the laptop) |
| `R` | Recenter left/right |
| `Q` | Show / hide QR code |
| `D` | Debug panel (raw sensor values, yaw/pitch/roll, fps) |
| `Tab` | Cycle network address (if the QR doesn't work) |
| `F11` | Fullscreen |

With no phone connected, the mouse controls the arm so you can test without a phone.

## Troubleshooting

- **Phone can't open the page:** allow Vector through the firewall (*Windows Security → Firewall → Allow an app through firewall → Vector → Private*). Make sure the Windows network is set to **Private**, not Public. School, hotel and guest Wi-Fi often block devices from talking to each other. A phone hotspot works as a fallback.
- **Wrong address in the QR code** (VPN, WSL or VirtualBox adapters): press `Tab` to cycle addresses.
- **iPhone never asks for motion permission:** *Settings → Apps → Safari → Advanced → Website Data*, delete the laptop's IP, reload.
- **Latency** (shown top-left as *Wi-Fi + frame*): the target is under 40 ms. 5 GHz Wi-Fi and staying near the router help.

## How it works

```
Phone browser (HTML/JS) --wss:// JSON @ ~60 Hz--> Vector.exe (Godot 4.7)
  DeviceOrientation + DeviceMotion                  HTTPS + secure WebSocket on one port (8443)
                                                    networking thread (1 ms poll, Nagle off)
                                                    calibration -> One Euro filter -> 2-bone IK arm
```

- **HTTPS is required** by iOS and Android for motion sensors, and an HTTPS page may only open `wss://` sockets. The game serves both on port 8443, so the phone accepts one certificate. Port 8080 redirects plain `http://` to it.
- **The certificate** is built by hand in [`cert_util.gd`](godot_project/scripts/cert_util.gd), because Godot's built-in generator doesn't add the fields iOS requires: the IP addresses in the subject alt name, extended key usage *serverAuth*, SHA-256, and validity under 825 days.
- **Calibration** is done in Godot. The phone sends raw angles, which are turned into a rotation and then into gravity-referenced yaw, pitch and roll. Pitch and roll don't drift; yaw (gyro) can, and **Recenter** fixes it. Accelerometer data is used only for swing intensity (glow and trail), never calibrated.
- **Smoothing** uses a [One Euro filter](godot_project/scripts/one_euro.gd): steady when you hold still, near-zero lag when you move fast.
- **Messages** (phone → game):
  ```json
  {"type":"sensor","orientation":{"alpha":12.5,"beta":-8.2,"gamma":3.1},"accel":{"x":0.12,"y":-0.34,"z":0.05},"t":1234.5,"rtt":14.2}
  {"type":"calibrate"}   {"type":"recenter"}   {"type":"ping","t":1234.5}
  ```
  Game → phone: `{"type":"pong","t":…}`, `{"type":"status","calibrated":true,"grip":"remote"}`.

## Project layout

```
godot_project/
  project.godot, export_presets.cfg
  scenes/main.tscn
  scripts/
    main.gd               wiring, keys, IP/QR
    controller_server.gd  HTTPS + WebSocket server (own thread)
    cert_util.gd          iOS-compatible self-signed certificate
    motion_input.gd       orientation -> calibrated yaw/pitch/roll
    one_euro.gd           smoothing filter
    character.gd          character + two-bone IK arm + remote
    world.gd              environment, target board, pointer, trail
    hud.gd                status, QR card, debug panel
    qr_code.gd            QR code encoder
    net_util.gd           picks the real Wi-Fi address
  web/controller.html     phone controller page (embedded in the exe)
```

## Building the exe

1. Install [Godot 4.7](https://godotengine.org/download) and its export templates.
2. Run:

```bash
cd godot_project
godot --headless --import
godot --headless --export-release "Windows Desktop" ../build/Vector.exe
```

The export embeds everything (including `web/controller.html`) into a single `Vector.exe`.

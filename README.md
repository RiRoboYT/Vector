# VectorSports

A motion-controlled sports game for Windows: your phone (iPhone or Android) is the controller. It runs fullscreen on a laptop or TV (720p, 1080p, 1440p and 4K). No app is needed on the phone: it opens a web page served by the game.

**Available now: Bowling** for **1–8 players** (10 frames, real pin physics). Tennis, Golf and Baseball are placeholders in the menu.

## Multiplayer (bowling)

- **Everyone scans the same QR code.** Each phone that joins becomes a player ("You are Player 2"). A phone keeps its slot if it briefly disconnects.
- **Sharing a phone:** tap your name badge on the phone → **+ Add guest**. Guests take turns on that phone ("Pass the phone to Sam").
- **Names:** typed on the phone (the name sheet opens when you join; tap your name badge to change it later). Defaults are "Player 1", "Player 2"…
- **Lobby:** players appear as they join (up to 8). The host points at **Start** and presses A.
- **Calibration:** every phone calibrates when it joins and again before every game.
- **Turns:** each player bowls a full frame. A "MAYA'S TURN" banner appears; that player presses A when ready. Other phones show "Maya is bowling…" and their buttons are locked.
- **Results:** ranked podium with scores and strikes → Play Again (same players) or Menu.

## Getting started

1. Run **`VectorSports.exe`**.
   - *"Windows protected your PC"*: **More info → Run anyway**.
   - **Windows Firewall**: tick **Private networks → Allow**. Without this the phone can't connect.
2. Phone on the **same Wi-Fi** → scan the **QR code** with the camera.
3. On the certificate warning:
   - **iPhone:** *Show Details → visit this website → Visit Website*.
   - **Android:** *Advanced → Proceed*.
4. Tap **Enable Motion** → **Allow**.
5. **Calibration (always required):** hold the phone like a remote, point at the target on screen and press **A**. This is asked whenever the phone connects and before every game.

Flow: Safety screen → Home → Title → Choose a sport → Players lobby → How to bowl (first time) → Calibration (every phone) → Bowling.

## Phone controller

| Button | Menus | Bowling |
|---|---|---|
| ◀ ▶ (top) | – | Move left/right, or turn (in Turn mode) |
| **A** (small) | Select what the hand cursor points at | Switch between **Move** and **Turn** |
| **B** (big) | – | **Hold** B, swing your arm back, swing forward and **let go of B** to release |
| Center | Re-centres the pointer | – |

- **Ball speed** = how fast your arm swings forward at the moment you let go of B.
- **Spin**: twist your wrist left or right as you let go and the ball hooks that way. Swing straight for a straight ball.
- Hold on to your phone; only let go of the B button.

## Keyboard (testing without a phone)

Arrows = ◀ ▶, Enter/Z or mouse click = A, hold Space = B (longer hold = faster ball), hold Q/E while releasing = spin, Esc = leave the game, F11 = fullscreen, Q = show/hide QR code, Tab = next network address.

## Troubleshooting

- **Phone can't open the page:** allow VectorSports through the firewall (*Windows Security → Firewall → Allow an app*), and set the Windows network to **Private**. Guest, hotel and school Wi-Fi often block devices from reaching each other; a phone hotspot is a good fallback.
- **Wrong address in the QR code** (VPN, WSL, VirtualBox adapters): press **Tab**.
- **iPhone never asks for motion access:** *Settings → Apps → Safari → Advanced → Website Data*, delete the laptop's IP, reload.
- **Spin goes the wrong way for you:** tell me and I'll add an option to flip it.

## How it works

```
Phone (HTML/JS)  --wss:// JSON ~60 Hz-->  VectorSports.exe (Godot 4.7, Mobile renderer, Jolt physics)
 orientation + gyro + buttons              HTTPS + secure WebSocket on port 8443 (own network thread)
                                           calibration -> pointer / swing detection -> bowling physics
```

- **HTTPS is required** by phones for motion sensors. The game makes its own iOS-compatible certificate ([`cert_util.gd`](godot_project/scripts/cert_util.gd)) and serves the page and the WebSocket on one port.
- **Swing detection** ([`bowling_game.gd`](godot_project/scripts/bowling/bowling_game.gd)): while B is held, the gyro rotation around the phone's width axis is integrated. The first big rotation is taken as the back-swing, so it works with any grip or hand. At release, the peak forward rotation speed (last ~130 ms) sets the ball speed (3–10 m/s), and the wrist twist around the phone's long axis sets the spin.
- **Physics:** regulation lane (60 ft, 41.5 in wide), 1.5 kg pins with a lathe-turned shape and two-part convex collision, a 7 kg ball, gutters, kickbacks and a pit. Hook is stronger on the dry back end of the lane, like a real oil pattern. Checked by [`tests/test_physics.gd`](godot_project/tests/test_physics.gd): pocket hits strike, head-on leaves a pin, gutter balls score 0.
- **Scoring:** full 10-pin rules with the 10th-frame bonus ([`bowling_score.gd`](godot_project/scripts/bowling/bowling_score.gd), tested by [`tests/test_score.gd`](godot_project/tests/test_score.gd)).
- **Sounds** (menu click, ball roll, pin hits) are synthesised in code ([`sfx.gd`](godot_project/scripts/sfx.gd)).
- **Display:** the UI is laid out at 1280×720 and scaled sharply to any resolution. At 1440p and 4K the 3D view renders a little lower and is upscaled with FSR so low-end laptops stay smooth.

## Building

1. Install Godot 4.7 and its export templates.
2. Run:

```bash
cd godot_project
godot --headless --import
godot --headless --export-release "Windows Desktop" ../build/VectorSports.exe
```

Run the tests:

```bash
cd godot_project
godot --headless -s tests/test_score.gd
godot --headless -s tests/test_physics.gd
```

Font: M PLUS Rounded 1c (SIL Open Font License, see `godot_project/fonts/LICENSE.txt`).

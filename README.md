# VectorSports

A motion-controlled sports game for Windows: your phone (iPhone or Android) is the controller. It runs fullscreen on a laptop or TV (720p, 1080p, 1440p and 4K). No app is needed on the phone: it opens a web page served by the game.

**Available now: Bowling** (1–8 players, 10 frames, real pin physics) **Cricket** (1–8 players, Super Over / 2 / 5 overs, real ball, bat and fielding physics) and **Tennis** (doubles, 1–4 players, 1 / 3 / 5 games, real ball spin and bounce). Golf and Baseball are placeholders in the menu.

## Tennis

Doubles on an outdoor hard court, always two against two. Players run to the ball on their own; you only swing.

- **Who controls whom:**
  - 1 player: you control both players on your side, against two computer players.
  - 2 players: each of you controls both players on one side, with split screen.
  - 3 players: two of you share the near side; the third controls both far players.
  - 4 players: everyone controls one player.
- **Match:** 1, 3 or 5 games (first to 1, 2 or 3), with real scoring: 15/30/40, deuce and advantage. Serve alternates every game and moves between the deuce and ad courts.
- **Serve:** tap **B** to toss, then swing over your head as the ball reaches the top. Badly timed or flat-out serves can fault; two faults is a double fault.
- **Rally:** swing as the ball reaches your player. Forehand or backhand is picked for you.
  - Timing aims the shot: early goes cross-court, late goes down the line. Way off is a miss or a framed shot.
  - Swing speed sets the pace.
  - Finishing high gives topspin; finishing low gives slice. A slow flick up is a lob; a slow chop down is a drop shot.
- **Physics:**
  - Ball: drag, Magnus force from spin (topspin dips, slice floats) and a hard-court bounce where topspin kicks up and slice skids low ([`tennis_ball.gd`](godot_project/scripts/tennis/tennis_ball.gd)).
  - Net: real heights. A ball that clips the tape can trickle over.
- **Computer players:** Easy, Medium or Hard. They make more errors when stretched.
- **Haptics:** a tap on the toss, a buzz on every hit (double kick on the sweet spot, harder on big shots, dull tap on a framed shot), a light tick on a miss, and a long buzz on a fault. Points, games and matches won or lost each have their own feel.

## Cricket

Formats: **Super Over** (6 balls each, 2 wickets), **2 overs** (3 wickets) or **5 overs** (5 wickets). Play against the computer (Easy / Medium / Hard) or against each other: players are split into Blue and Orange teams.

Each ball:
1. **Batter takes guard:** ◀ ▶ moves across the crease. Point the phone **at the floor like a grounded bat** (screen facing the TV) and **tap B**. This sets the bat's starting position.
2. **Bowler sets the field:** the minimap opens. ▲ ▼ ◀ ▶ choose a fielder, **A** picks up or drops, then move them. **B** when done. Real restrictions apply: **powerplay overs** (first 30%) allow **max 2 fielders outside the 30-yard circle**, other overs max 5.
3. **Bowler aims:** ◀ ▶ line, ▲ ▼ length (marker on the pitch), **A** switches Fast / Medium / Spin. **Tap B** to run in.
4. **Timing meter:** a marker slides up and down a bar. **Tap B** when it's in the **green**:
   - **gold centre** = perfect pace and line
   - green = good
   - **top red** = no-ball (+1, ball again, next ball is a **free hit**)
   - **bottom red** = wide
   - no tap = dead ball
   The red ends are small, so most balls are fine. Pace ranges: Fast 125–150 km/h, Medium 105–125, Spin 72–92.
5. **Half swing:** grip the phone with your whole hand and make a short bowling swing (no button):
   - **straight** = no swing
   - **angled left or right** = the ball swings that way in the air
   - **wrist twist** during the swing = spin that way off the pitch
6. **Batter swings:** the bat copies the phone's rotation 1:1. Timing, bat speed and face angle decide the shot.
7. **Fielding and running are automatic:** fielders chase, catch (or drop), gather and throw, and batters judge their runs.

**Outs:** bowled, caught (including edges to the keeper), run out. You can't be bowled or caught off a no-ball or a free hit. **Extras:** wides and no-balls. LBW is not in this version.

**Split screen:** when the batter and the bowler are both people, the TV splits: bowler's view on the left, batter's view on the right.

**Left-handers:** in the phone's names sheet, tap *Right-handed* to switch each player to *Left-handed*.

### Cricket physics
- **Ball** ([`cricket_ball.gd`](godot_project/scripts/cricket/cricket_ball.gd)), stepped at 480 Hz:
  - gravity and quadratic air drag (Cd ≈ 0.37)
  - swing force before the ball pitches
  - bounce with different restitution and friction on the pitch and the outfield
  - spin turn off the pitch, and rolling friction on grass
  - checked by [`tests/test_cricket_ball.gd`](godot_project/tests/test_cricket_ball.gd): a 140 km/h ball reaches the batter in 0.52 s, a 38 m/s lofted hit carries 71 m for six, a 25 m/s drive rolls for four
- **Bat** ([`bat.gd`](godot_project/scripts/cricket/bat.gd)):
  - real dimensions
  - swept collision (continuous, so fast swings can't pass through the ball)
  - 1-D impact along the contact normal, using the bat's effective mass and restitution at that point of the blade (sweet spot about 15 cm from the toe; edges and handle are dead)
  - checked by [`tests/test_cricket_bat.gd`](godot_project/tests/test_cricket_bat.gd): timed well = 102 km/h along the ground, early = popped up, late = slower
- **Stumps and bails** are Jolt physics bodies that fly when the wicket is broken.
- **Fielding** ([`cricket_play.gd`](godot_project/scripts/cricket/cricket_play.gd)):
  - fielders predict the ball's path and the quickest one sprints to cut it off
  - catches depend on reach and pace
  - throws are aimed (with drag) at the keeper or bowler, or at the stumps for a run-out
  - the keeper stands back for pace and up for spin

## Before every match: hold A to get ready

After Start (and before every Play Again), each player **holds A on their phone for about a second**. Their card fills up and turns green with READY ✓. Players sharing a phone hold A one after another, and the keyboard player holds Enter. The match (after calibration) starts once everyone is ready.

## Haptics

The phone buzzes on button presses, ball release, bat contact (stronger when you middle it), boundaries, strikes, wickets, calibration and getting ready.
- **Android:** real vibration patterns.
- **iPhone:** Safari doesn't allow vibration, so the game uses Safari's built-in haptic tick from a toggle switch (iOS 18+). Longer buzzes are a few ticks in a row.

Turn haptics off in the phone's names sheet (tap your name badge).

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
godot --headless -s tests/test_cricket_ball.gd
godot --headless -s tests/test_cricket_bat.gd
godot --headless --fixed-fps 60 -s tests/test_cricket_human.gd
godot --headless -s tests/test_tennis_ball.gd
godot --headless --fixed-fps 60 -s tests/test_tennis_cpu.gd
godot --headless --fixed-fps 60 -s tests/test_tennis_human.gd
```

Font: M PLUS Rounded 1c (SIL Open Font License, see `godot_project/fonts/LICENSE.txt`).

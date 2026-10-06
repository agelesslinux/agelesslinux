# The Ageless Device: what the distro needs to provide

> Requirements sketch. The device itself is still being defined; this page
> pins down what Ageless Linux must do for it, what exists today, and the
> open questions. Update it as hardware decisions land.

## The device, as currently imagined

- **MCU:** Raspberry Pi RP2040 or RP2350 (Pico-class board).
- **Display and input:** OLED and a keyboard.
- **Wi-Fi:** optional (Pico W / Pico 2 W, CYW43439 radio).
- **Firmware:** undecided between MicroPython and a C/Pico SDK firmware with
  an app runtime. This choice drives most of what follows. See Q1.

## What the distro must do

| # | Requirement | Over | Status |
|---|---|---|---|
| D1 | A user plugs the device in and the OS can talk to it **without sudo or group setup**. | USB | ✅ `ageless-device`: udev rules with `TAG+="uaccess"` for every RP2040/RP2350 mode, and stable `/dev/ageless/<mode>-<serial>` names |
| D2 | **Detect** the device and say what mode it is in (bootloader, MicroPython, SDK app). | USB | ✅ `ageless-device list` (reads sysfs, no dependencies) |
| D3 | **Flash firmware** (UF2) | USB | ✅ `ageless-device flash fw.uf2`: copies to the BOOTSEL drive, falls back to `picotool` |
| D4 | **Sync files** both ways (notes, data, configs) | USB | 🟡 `ageless-device push/pull/ls` via `mpremote`. Works for MicroPython firmware; a C firmware needs its own protocol (Q2). |
| D5 | **Upload apps** to the device | USB | 🟡 `push` copies files. A real app needs a manifest and an install location (Q3). |
| D6 | **Run the Ageless Store** for any number of devices | Wi-Fi | ⬜ Design below |
| D7 | Devices **discover** the store on the LAN with no configuration | Wi-Fi | ⬜ mDNS / DNS-SD (below) |
| D8 | One **metapackage** installs and configures all of it | apt | 🟡 `ageless-device` (USB side); the store becomes `ageless-store` + `ageless-device` |
| D9 | A GUI entry point | desktop | ⬜ an Ageless Device pane in mintmenu ([mintmenu.md](mintmenu.md)) or a small GTK app |

## USB side (works today)

The `ageless-device` package (`packages/ageless-device/`, archive only, not
on the ISO) contains:

- `/usr/lib/udev/rules.d/70-ageless-device.rules`. It covers Raspberry Pi's
  vendor ID `2e8a` with these product IDs:

  | Product ID | Mode |
  |---|---|
  | `0003` | RP2040 BOOTSEL |
  | `000f` | RP2350 BOOTSEL |
  | `0005` | MicroPython |
  | `0009` | Pico SDK stdio on RP2350 |
  | `000a` | Pico SDK stdio on RP2040 |
  | `000c` | Debug Probe |

  The rules also tell ModemManager not to probe the serial ports, which
  otherwise holds them for several seconds after plug-in.
- `/usr/bin/ageless-device`, a stdlib-only Python CLI with these
  subcommands: `list`, `flash`, `ls`, `push`, `pull`, `repl`.
- Recommends `picotool` and `micropython-mpremote` (both in trixie main).
  `ageless-maker` recommends `ageless-device`.

What's untested: this hasn't touched real hardware yet. The unit tests
use a fake sysfs, and the rules are checked for coverage only.

## Wi-Fi side: the Ageless Store (proposal)

The desktop runs a small service that serves apps to devices on the LAN.

```
 ┌────────────── Ageless Linux PC ──────────────┐         ┌─ Ageless Device ─┐
 │ ageless-store (systemd service, port 8650)   │  mDNS   │ looks up          │
 │   /var/lib/ageless-store/apps/<id>/<ver>/    │◀────────│ _ageless-store._tcp│
 │   index.json  (signed)                       │  HTTP   │ GET /index.json   │
 │ avahi: _ageless-store._tcp                   │────────▶│ GET /apps/<id>.tar│
 └──────────────────────────────────────────────┘         └───────────────────┘
```

- **Discovery:** Avahi publishes `_ageless-store._tcp`. Devices browse for
  it with mDNS, which MicroPython can do on the Pico W through raw UDP
  multicast. Fallback: a host name typed on the device.
- **Transport:** plain HTTP on the LAN; a Pico W can't afford TLS for
  everything. Integrity comes from **signatures**, not the channel. The
  store signs `index.json` with an ed25519 key, and devices pin the store's
  public key on first pairing (shown as a short code on the OLED and in the
  desktop UI).
- **App format:** a tarball, or a directory for MicroPython, plus
  `app.json`:
  - `id`, `name`, `version`
  - `runtime` (`micropython-1.25` / `sdk-abi-1`)
  - `entry`
  - `size`, `sha256`
- **Sources of apps:** a Debian package per curated app (e.g.
  `ageless-app-notes`) drops files into `/usr/share/ageless-store/apps/`, so
  apt delivers and updates apps and the store just serves them. Users can
  also add their own (`ageless-store add ./myapp`).
- **Privacy:** no accounts, no ages, no telemetry. The store logs nothing
  beyond what systemd logs by default. This is the Ageless answer to the
  app store age-verification laws (see the app-store card in
  [Ageless System Info](laws.md)).
- **Implementation:** Python and stdlib `http.server` (or aiohttp) plus
  `python3-zeroconf` (in trixie) or an Avahi service file. It ships as
  `ageless-store`, which `ageless-device` recommends.

## Open questions

1. **Firmware runtime.** With **MicroPython**, D4/D5 are solved today
   (`mpremote`), apps are `.py` files, and the device is easy to hack on. A
   **C firmware** makes better use of RAM and display speed, but needs a
   custom sync protocol (Q2) and a binary app ABI. A middle path is a C
   firmware with an embedded MicroPython VM for apps.
2. **USB protocol for a C firmware:** pick one of these.
   - CDC serial with a framed protocol (simplest; works everywhere).
   - USB mass storage, so the device appears as a drive (no tools needed,
     but the firmware must not write while the host has it mounted).
   - A vendor interface with libusb (fastest, needs host tooling).

   **Recommendation:** CDC plus a small framed protocol, with mpremote's
   raw-REPL protocol as the model.
3. **App manifest and install location** on the device. The app format
   above proposes `/apps/<id>/` and `app.json`.
4. **Our own USB product ID.** Raspberry Pi has allocated product IDs under
   its vendor ID for RP2040-based products on request (repo
   `raspberrypi/usb-pid`). Check the current policy. A dedicated ID lets
   udev and the store tell an Ageless Device from any other Pico.
5. **Store trust.** One store per household, or many? How does a device
   choose? Is pairing by short code enough?
6. **Updates to the device firmware itself:** over Wi-Fi (needs a
   bootloader, e.g. a picowota-style A/B scheme) or USB only?

## Next steps

1. Pick the firmware runtime (Q1). Everything downstream depends on it.
2. Test `ageless-device` against a Pico 2 W running MicroPython: list,
   flash, push, pull. Fix whatever reality disagrees with.
3. Prototype `ageless-store` (Python, ~300 lines): serve a directory, sign
   the index, publish mDNS. Prototype a MicroPython client that lists and
   downloads apps.
4. Allocate the USB product ID (Q4) and add it to the udev rules.

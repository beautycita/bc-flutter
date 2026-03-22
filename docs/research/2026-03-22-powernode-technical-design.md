# PowerNode -- Technical Design Document

**Version:** 0.3 (Draft)
**Date:** 2026-03-22
**Author:** BC
**Status:** Pre-prototype Engineering Specification

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture](#2-system-architecture)
3. [Smart Home Integration Layer](#3-smart-home-integration-layer)
4. [Multi-Property Architecture](#4-multi-property-architecture)
5. [Hub Hardware Design (PowerNode Central)](#5-hub-hardware-design-powernode-central)
6. [Node Hardware Design (PowerNode Satellite)](#6-node-hardware-design-powernode-satellite)
7. [PLC Subsystem Detail](#7-plc-subsystem-detail)
8. [Smart Metering Subsystem](#8-smart-metering-subsystem)
9. [Breaker Control Subsystem](#9-breaker-control-subsystem)
10. [Firmware Architecture](#10-firmware-architecture)
11. [Security Architecture](#11-security-architecture)
12. [Portable Identity & Roaming Architecture](#12-portable-identity--roaming-architecture)
13. [Integrated Remote Desktop (PowerDesk)](#13-integrated-remote-desktop-powerdesk)
14. [Mobile App Architecture](#14-mobile-app-architecture)
15. [Bill of Materials (Detailed)](#15-bill-of-materials-detailed)
16. [Regulatory & Certification](#16-regulatory--certification)
17. [Prototype Plan](#17-prototype-plan)
18. [Risk Matrix](#18-risk-matrix)

---

## 1. Executive Summary

PowerNode is a unified smart home hub and PLC networking system that combines seven functions into a single product family:

1. **Whole-home Internet distribution** over existing house wiring (no new cables, no mesh WiFi dead zones).
2. **Per-circuit smart energy metering** with real-time dashboards.
3. **Remote breaker control** for scheduling, safety cutoffs, and automation (Phase 2).
4. **Unified smart home control** across all platforms (Tuya, eWeLink, TTLock, EZVIZ, Zigbee, Z-Wave, Matter, and more) from a single hub and app.
5. **Multi-property management** with per-property hubs linked to one cloud account.
6. **Portable network identity** -- take a Satellite node anywhere, plug it in, and it auto-connects back to your home hub via encrypted WireGuard VPN tunnel. You ARE on your home network regardless of physical location.
7. **Integrated remote desktop (PowerDesk)** -- access any PC, Mac, or tablet on your home network from anywhere. The hub IS the relay server. Zero monthly fees, no third-party servers.

### Product Family

| Device | Form Factor | Location | Function |
|--------|-------------|----------|----------|
| **PowerNode Central** (Hub) | DIN-rail module, 6 modules wide | Breaker panel | WAN ingress, PLC coordinator, metering, breaker control |
| **PowerNode Satellite** (Node) | Wall-plug (WiFi extender style) | Any outlet | PLC endpoint, WiFi 6 AP, GbE port |

A typical residential deployment consists of **1 Hub + 2--6 Nodes** (the HomePlug AV2 network supports up to 64 STAs; practical limit is 30+ nodes depending on wiring quality). The Hub also serves as a unified smart home controller, bridging devices across Tuya, eWeLink, Zigbee, Z-Wave, Matter, MQTT, and more into a single app for network management, energy visibility, and whole-home automation.

### Value Proposition

- **Zero new wiring.** Internet travels over existing L/N conductors via HomePlug AV2.
- **Per-circuit energy data.** CT clamps on individual breakers give room-level or appliance-level consumption visibility.
- **One app, every device.** Network management, energy monitoring, breaker control, AND unified smart home control (Tuya, eWeLink, Zigbee, Z-Wave, Matter, cameras, locks) in a single Flutter application. No more juggling 5+ apps.
- **Works with everything.** Cloud APIs (Tuya, eWeLink, TTLock, EZVIZ, Alexa, Google Home), local protocols (Zigbee 3.0, Z-Wave, Matter/Thread, MQTT, BLE), and legacy (IR/RF 433MHz). If it is a smart device, PowerNode controls it.
- **Multi-property management.** Each property gets a hub; one account links them all. Property selector in the app, cross-property automations, independent offline operation.
- **Portable identity.** Take a Satellite node to a hotel, office, cowork space, or store. Plug it in -- it presents its hardware X.509 certificate, establishes a WireGuard VPN tunnel to your home hub, and routes all traffic through your home network. Your hub is your gateway, firewall, and DNS -- everywhere.
- **Built-in remote desktop (PowerDesk).** Access any computer on your home network from anywhere. The hub runs the relay server on-premise -- zero cloud fees, zero third-party data exposure. Auto-discovers devices via mDNS.
- **Mexican market first.** Designed for 127V/60Hz single-phase residential (CFE standard). Component selection, regulatory path, and retail pricing all target Mexico.

### Competitive Positioning

PowerNode competes in the intersection of two markets:

| Competitor | Strengths | PowerNode Advantage |
|-----------|-----------|-------------------|
| **Home Assistant** (open source) | Extremely flexible, 2000+ integrations, free | PowerNode is plug-and-play, zero Linux knowledge required. Includes PLC networking (no WiFi dead zones). Pre-configured hardware, not a DIY project. |
| **Samsung SmartThings** | Big brand, Matter support, polished app | PowerNode supports Chinese platforms (Tuya, eWeLink) that SmartThings ignores. PLC networking included. Per-circuit energy metering. Multi-property management. |
| **Apple Home / HomePod** | Premium UX, Thread border router | Locked to Apple ecosystem. No Tuya, no eWeLink, no TTLock. No energy metering. No PLC networking. |
| **TP-Link Deco (mesh WiFi)** | Great WiFi mesh, affordable | No smart home integration, no energy metering, no breaker control. WiFi-only (no PLC for difficult wiring). |

**Target users:**
- Property managers with multiple locations (Airbnb hosts, vacation rental operators)
- Small business owners juggling 5+ smart home apps
- Tech-comfortable homeowners who want one hub for everything
- Mexican market specifically: no equivalent product exists that combines PLC + smart home + energy metering

### Key Specifications

| Parameter | Value |
|-----------|-------|
| PLC standard | HomePlug AV2 (IEEE 1901) |
| PLC PHY rate | Up to 600 Mbps |
| PLC real-world TCP | 200--400 Mbps |
| PLC max nodes | 64 STAs per network (practical: 30+) |
| WiFi | 802.11ax (WiFi 6), 2x2 MIMO, 2.4 + 5 GHz |
| Ethernet | GbE per node, 2x GbE on hub (WAN + LAN) |
| Metering channels | Up to 24 circuits (hub) |
| Metering accuracy | +/-2% of reading |
| Breaker control | Phase 2 (solid-state relay, MQTT + 2FA) |
| Smart home: Cloud APIs | Tuya, eWeLink, TTLock, EZVIZ, Alexa, Google Home, Hubspace |
| Smart home: Local protocols | Zigbee 3.0, Z-Wave (optional), Matter/Thread, MQTT, BLE mesh |
| Smart home: Legacy | IR blaster + 433MHz RF transmitter |
| Multi-property | One account, unlimited hubs, cross-property automations |
| Portable identity | WireGuard VPN tunnel, ATECC608B X.509 cert, roaming to any network |
| Remote desktop | PowerDesk (RustDesk-based), hub-hosted relay, <50ms latency target |
| Security | PKI (X.509 per device), AES-128 PLC, TLS 1.3, secure boot |
| Target retail | $649 USD (1 hub + 4 nodes) |
| Gross margin | 42% |

---

## 2. System Architecture

### 2.1 Physical Topology

```
                          ISP Modem/ONT
                               |
                          RJ45 (WAN)
                               |
                    +---------------------+
                    |  PowerNode Central   |
                    |  (Hub @ breaker      |
                    |   panel, DIN-rail)   |
                    +---------------------+
                       |              |
                  RJ45 (LAN)    PLC coupler
                       |         (L/N wires)
                  Local device        |
                               House wiring
                          (existing 127V/60Hz)
                               |
              +----------------+----------------+
              |                |                |
        +-----------+   +-----------+   +-----------+
        |  Node 1   |   |  Node 2   |   |  Node 3   |
        |  (Bedroom)|   |  (Living) |   |  (Office) |
        +-----------+   +-----------+   +-----------+
         WiFi 6 AP       WiFi 6 AP       WiFi 6 AP
         GbE port        GbE port        GbE port
```

The Hub is the Central Coordinator (CCo) of the HomePlug AV2 network. All Nodes are Stations (STAs). The PLC backbone runs over existing L and N conductors between the breaker panel and each outlet. No neutral conductor is required beyond what already exists for the outlet. The HomePlug AV2 standard supports up to 64 STAs per network; practical deployments of 30+ nodes are feasible depending on wiring quality and electrical noise.

The Hub additionally serves as a smart home controller, integrating cloud-connected devices (Tuya, eWeLink, TTLock, EZVIZ) and local-protocol devices (Zigbee, Z-Wave, Matter/Thread, MQTT, BLE) into a unified device model accessible from the PowerNode app.

### 2.2 Data Flow -- Internet Distribution

```
ISP fiber/cable
    |
    v
ISP Modem/ONT (bridge mode preferred)
    |
    v  RJ45 (Ethernet, 1 Gbps)
Hub WAN port (LAN8720A PHY #1)
    |
    v  RMII bus
ESP32-S3 (NAT/DHCP/firewall via lwIP stack)
    |
    v  SPI bus
QCA7006 PLC modem (modulates Ethernet frames onto power line)
    |
    v  Capacitive coupler (100nF X2 cap + toroid)
House wiring L/N (127V 60Hz + 2-86 MHz OFDM signal)
    |
    v  At each outlet
Node QCA7006 PLC modem (demodulates OFDM back to Ethernet frames)
    |
    v  SDIO bus
MT7921 WiFi 6 SoC (broadcasts as WiFi AP)
    |
    v  Also: RGMII bus
RTL8211F GbE PHY -> RJ45 jack (wired device)
```

The ESP32-S3 on the Hub acts as the network's router. It runs a lightweight IP stack (lwIP) providing NAT, DHCP server (for the entire PLC + WiFi network), DNS relay, and basic firewall. The QCA7006 on both Hub and Node sides handles all PLC modulation/demodulation transparently -- it presents standard Ethernet frames on its host interface.

### 2.3 Control Flow -- Breaker Management

```
User App (Flutter)
    |
    v  MQTT over TLS 1.3 (port 8883)
Cloud MQTT broker (AWS IoT Core or self-hosted Mosquitto)
    |  or local MQTT (hub's built-in broker, port 1883 on LAN)
    v
Hub ESP32-S3
    |
    v  GPIO -> optocoupler -> SSR gate
Solid-state relay on circuit breaker
    |
    v
Circuit ON/OFF
```

All breaker commands require two-factor confirmation:
1. App-side PIN entry (or biometric).
2. Physical button press on the Hub (within 30-second window).

This prevents remote-only actuation, which is a safety and liability requirement.

### 2.4 Metering Flow -- Energy Monitoring

```
Breaker panel circuit wire
    |
    v  (wire passes through CT clamp core)
SCT-013-020 CT clamp (outputs 0-1V AC proportional to current)
    |
    v  Signal conditioning (burden R + bias voltage)
ADS1115 ADC (16-bit, I2C)
    |
    v  I2C bus
Hub ESP32-S3 (RMS calculation, power computation)
    |
    v  MQTT publish (topic: powernode/{device_id}/meter/{circuit})
Local app (real-time dashboard) + Cloud (historical storage)
```

Metering data flows at 1-second resolution for real-time display and is aggregated into 1-minute averages for storage. The Hub retains 24 hours of per-second data in its PSRAM ring buffer. Cloud sync happens on a configurable schedule (default: every 60 seconds for 1-minute aggregates).

---

## 3. Smart Home Integration Layer

The Hub runs integration bridges for every major smart home platform, both cloud-based and local-protocol. All devices, regardless of source platform, are normalized into a common device model and controllable from a single app.

### 3.1 Cloud API Integrations (hub polls/webhooks)

| Platform | Covers | Protocol | Polling Interval | Notes |
|----------|--------|----------|-----------------|-------|
| **Tuya Open API** | Smart Life, most Chinese IoT -- lights, switches, plugs, sensors, curtain motors | HTTPS + MQTT (Tuya cloud) | 30s poll + Tuya MQTT push | Largest IoT ecosystem by device count. Hub registers as a Tuya cloud development project. |
| **eWeLink API** | Sonoff devices (switches, sensors, cameras) | HTTPS REST + WebSocket | 30s poll + WS push | Second-largest Chinese IoT platform. |
| **TTLock / Sciener API** | Smart locks (TTLock, Kaadas, many white-label brands) | HTTPS REST | 60s poll (lock state), on-demand for commands | Lock commands routed through hub for extra confirmation layer. |
| **EZVIZ / Hikvision API** | Cameras -- RTSP stream proxy + cloud API for PTZ/alerts | HTTPS REST + RTSP | Event-driven (motion alerts), RTSP continuous | Hub proxies RTSP streams locally; cloud API for PTZ control, arm/disarm, alert history. |
| **Alexa Smart Home Skill API** | Bidirectional -- PowerNode appears as Alexa skill AND consumes Alexa-connected devices | HTTPS + Lambda/event gateway | Event-driven | Users can say "Alexa, turn on living room" and it routes through PowerNode. PowerNode can also discover and control devices already paired to Alexa. |
| **Google Home API / Matter bridge** | Google Home ecosystem, Nest devices | HTTPS + Matter bridge | Event-driven + 60s poll | Hub acts as Matter bridge, exposing all PowerNode-managed devices to Google Home. |
| **Hubspace API** | Home Depot's smart home brand (lights, fans, plugs) | HTTPS REST | 60s poll | Growing ecosystem in North America. |

### 3.2 Local Protocol Integrations (hub has radios/bridges)

| Protocol | Hardware on Hub | Capability | Device Examples |
|----------|----------------|-----------|-----------------|
| **Zigbee 3.0** | CC2652P coordinator ($8) | Direct control of Zigbee devices without separate bridge. Hub IS the Zigbee coordinator. | Philips Hue bulbs (without Hue bridge), Aqara sensors, IKEA Tradfri, Sonoff Zigbee |
| **Z-Wave** | Optional USB-A stick (Silicon Labs UZB-7, ~$35) | Full Z-Wave controller. Pluggable -- users add only if they have Z-Wave devices. | Yale/Schlage locks, Aeotec sensors, Zooz switches |
| **Matter / Thread** | Thread border router module (nRF52840, $5) on hub | Native Thread border router. Matter devices auto-discovered. | All Matter-certified devices (Eve, Nanoleaf, new Philips Hue) |
| **MQTT** | Built-in broker (Mosquitto on ESP32-S3) | Any MQTT device auto-discovered via convention or manual add. | Tasmota-flashed devices, ESPHome, custom sensors, industrial IoT |
| **BLE** | ESP32-S3 native BLE 5.0 | BLE mesh, BLE beacons, device provisioning, Switchbot-style devices | Switchbot, Xiaomi BLE sensors, BLE locks, plant sensors |
| **IR blaster + 433MHz RF** | IR LED + 433MHz TX module ($3 total) on hub | Broadlink-style legacy device control. Learn and replay IR/RF codes. | Air conditioners, TV/AV receivers, projectors, RF ceiling fans, RF roller blinds |
| **mDNS / SSDP** | ESP32-S3 network stack | Auto-discovery of network devices. No additional hardware. | Sonos speakers, Chromecast, network printers, NAS devices |

### 3.3 Device Abstraction Layer

All devices, regardless of source platform, are normalized to a common device model:

```json
{
  "id": "uuid",
  "name": "Living Room Light",
  "type": "light",
  "capabilities": ["on_off", "brightness", "color_temp", "rgb"],
  "state": {
    "on": true,
    "brightness": 80,
    "color_temp": 4000
  },
  "location": "Living Room",
  "property_id": "uuid",
  "platform": "tuya",
  "platform_device_id": "tuya_abc123",
  "online": true,
  "last_seen": "2026-03-22T10:30:00Z"
}
```

**Supported device types:** `light`, `switch`, `plug`, `sensor`, `lock`, `camera`, `thermostat`, `curtain`, `fan`, `speaker`, `ir_remote`, `doorbell`, `garage_door`, `vacuum`, `generic`.

**Capability catalog:** `on_off`, `brightness`, `color_temp`, `rgb`, `lock_unlock`, `open_close`, `temperature`, `humidity`, `motion`, `contact`, `power_meter`, `stream`, `ptz`, `arm_disarm`, `ir_send`, `ir_learn`.

### 3.4 State Sync Engine

| Source Type | Sync Method | Latency |
|-------------|-------------|---------|
| Local Zigbee/Z-Wave/Thread | Real-time event-driven (radio interrupt) | < 100ms |
| Local MQTT | Real-time subscription | < 100ms |
| Local BLE | Poll or BLE notification (device-dependent) | 100ms--2s |
| Cloud API with WebSocket/MQTT push (Tuya, eWeLink) | Real-time push + periodic poll fallback | 500ms--2s |
| Cloud API poll-only (TTLock, Hubspace) | Configurable poll interval (30s--5min) | 30s--5min |
| Camera RTSP | Continuous stream proxy | Real-time |

### 3.5 Automation Engine

Cross-platform if/then rules:

```
IF [trigger]
  AND [optional conditions]
THEN [actions]
  AND [optional delays/sequences]

Examples:
- IF TTLock front door opens AFTER 10pm → turn on Tuya hallway light + start EZVIZ recording
- IF Zigbee motion sensor (bathroom) detects motion → turn on Tuya exhaust fan + set light to 30%
- IF EZVIZ camera detects person at front door → send push notification + unlock TTLock for 30s (with biometric confirmation)
- IF total power consumption > 4000W for > 5min → send alert + optional breaker action (Phase 2)
```

Rules are stored on the hub and execute locally (no cloud dependency for automation). Cloud is used only for remote push notifications.

### 3.6 Scene Engine

Cross-platform scenes -- named groups of device actions executed together:

| Scene | Actions |
|-------|---------|
| **Leaving** | Lock all TTLock doors + arm EZVIZ cameras + turn off all Tuya lights + set thermostat to away mode |
| **Good Night** | Lock front door + arm cameras + dim Zigbee bedroom light to 5% + close curtain motor + set AC to 24C |
| **Movie Time** | Turn off living room lights + close curtains + turn on IR for AV receiver + set Sonos to TV input |
| **Guest Arriving** | Unlock front door (temporary code via TTLock) + turn on entry lights + disarm entry camera |

Scenes are one-tap from the app or triggered by automation rules.

---

## 4. Multi-Property Architecture

### 4.1 Overview

Each physical property has one PowerNode Hub. A cloud account links multiple hubs. This architecture serves property managers, Airbnb hosts, and anyone with multiple locations.

```
                    Cloud (Supabase / MQTT Broker)
                     /          |          \
                    /           |           \
            +----------+  +----------+  +----------+
            | Hub #1   |  | Hub #2   |  | Hub #3   |
            | (Home)   |  | (Airbnb) |  | (Office) |
            +----------+  +----------+  +----------+
              Zigbee        Tuya          MQTT
              TTLock        EZVIZ         Zigbee
              Tuya          TTLock        sensors
```

### 4.2 Property Selector

The app shows a property selector at the top of the main screen (similar to switching "homes" in Google Home, but across ALL platforms and protocols). Tapping a property loads that hub's devices, automations, energy data, and network status. A special "All Properties" view shows aggregated alerts and summary cards.

### 4.3 Hub-to-Hub Communication

Hubs communicate via cloud MQTT for cross-property automations:

- **Topic namespace:** `powernode/account/{account_id}/hub/{hub_id}/...`
- **Cross-property rules:** "IF Airbnb hub detects guest check-in (TTLock code used) → send welcome push notification + set Home hub thermostat to eco mode (nobody home)"
- **Aggregated energy view:** Total kWh across all properties, per-property cost comparison
- **Centralized alerts:** All property alerts routed to one notification stream

### 4.4 Offline Mode

Each hub operates independently when internet is down:

- All local automations continue running (Zigbee, Z-Wave, Matter, MQTT, IR, PLC)
- Cloud API devices (Tuya, eWeLink) lose sync until connectivity returns but last-known state is retained
- Energy metering continues, data buffered in PSRAM ring buffer, synced when online
- Cross-property automations pause until cloud MQTT reconnects
- Camera RTSP streams remain accessible on LAN
- Hub-to-hub communication resumes automatically on reconnect with state reconciliation

---

## 5. Hub Hardware Design (PowerNode Central)

### 5.1 Block Diagram

```
+------------------------------------------------------------------+
|  PowerNode Central (DIN-rail enclosure, 6 modules wide)          |
|                                                                  |
|  +------------+     SPI      +------------+    Capacitive        |
|  | ESP32-S3   |<------------>| QCA7006    |---coupler--->  L/N   |
|  | WROOM-1    |              | PLC Modem  |              wiring  |
|  +------------+              +------------+                      |
|    |  |  |  |                                                    |
|    |  |  |  +-- RMII --+------------+   +------------+           |
|    |  |  |             | LAN8720A   |   | LAN8720A   |           |
|    |  |  |             | (WAN PHY)  |   | (LAN PHY)  |           |
|    |  |  |             +-----+------+   +-----+------+           |
|    |  |  |                   |                |                   |
|    |  |  |                 RJ45              RJ45                 |
|    |  |  |                 (WAN)             (LAN)                |
|    |  |  |                                                       |
|    |  |  +-- I2C bus ----+----------+----------+---...           |
|    |  |                  | ADS1115  | ADS1115  | (x6 total)      |
|    |  |                  | (4 ch)   | (4 ch)   |                 |
|    |  |                  +----+-----+----+-----+                 |
|    |  |                       |          |                       |
|    |  |                    CT clamps (up to 24)                  |
|    |  |                                                          |
|    |  +-- I2C ----------+------------+                           |
|    |                    | ATECC608B  |                           |
|    |                    | (crypto)   |                           |
|    |                    +------------+                           |
|    |                                                             |
|    +-- GPIO ----------> Status LEDs (4x: Power, PLC, Net, Err)  |
|    +-- GPIO ----------> Case-open tamper switch                  |
|    +-- GPIO ----------> Physical confirm button (breaker ctrl)   |
|    +-- GPIO ----------> SSR drivers (Phase 2, up to 24)         |
|    +-- GPIO ----------> IR LED (transmit) + IR receiver (learn)  |
|    +-- GPIO ----------> 433MHz TX module (RF legacy control)     |
|    |                                                             |
|    +-- UART ----------+------------+                             |
|    |                  | CC2652P    |  Zigbee 3.0 coordinator     |
|    |                  | (TI)      |  + Thread border router      |
|    |                  +------------+                              |
|    |                                                             |
|    +-- USB-A Host ----> Z-Wave stick (Silicon Labs UZB-7, opt.) |
|    |                                                             |
|    +-- UART ----------+------------+                             |
|                       | nRF52840   |  Thread border router       |
|                       | (optional) |  (if CC2652P Thread is      |
|                       +------------+   insufficient)             |
|                                                                  |
|  +------------+                                                  |
|  | HDR-15-12  |  (DIN-rail PSU, 12V/1.25A from mains)           |
|  | Mean Well  |---> 12V rail ---> LDO 3.3V, LDO 1.8V           |
|  +------------+                                                  |
+------------------------------------------------------------------+
```

### 5.2 Component Selection Rationale

#### 5.2.1 MCU: ESP32-S3-WROOM-1 (N16R8)

| Parameter | Value |
|-----------|-------|
| Core | Dual Xtensa LX7 @ 240 MHz |
| SRAM | 512 KB |
| PSRAM | 8 MB (octal SPI) |
| Flash | 16 MB (quad SPI) |
| WiFi | 802.11 b/g/n (2.4 GHz) |
| Bluetooth | BLE 5.0 |
| Peripherals | SPI x4, I2C x2, UART x3, RMII, USB OTG |
| Secure boot | eFuse v2, flash encryption AES-256-XTS |
| Price | ~$4.00 (1K qty) |

The ESP32-S3 was selected for its combination of processing power, ample PSRAM (critical for the 24-hour metering ring buffer and smart home device state cache), hardware crypto acceleration, RMII support (needed for Ethernet PHYs), USB OTG host support (for Z-Wave stick), and mature ESP-IDF toolchain. Its built-in WiFi is used only for the Hub's own configuration AP, not for client-facing WiFi (that is the Node's job via MT7921). Its BLE 5.0 radio handles BLE device communication, provisioning, and Switchbot-style device control.

The 8 MB PSRAM provides room for:
- Metering ring buffer: 24 circuits x 4 bytes x 86,400 seconds = ~8.3 MB (compressed with delta encoding to ~2 MB)
- Smart home device state cache: ~200 devices x 1 KB = ~200 KB
- Integration runtime state: ~512 KB (API tokens, polling state, automation rule engine)
- MQTT message queues: ~512 KB
- Web server assets: ~1 MB
- Firmware OTA staging: Uses flash A/B partitions, not PSRAM

The 16 MB flash accommodates the larger firmware footprint from integration runtimes (Zigbee stack, MQTT broker, cloud API clients, automation engine, IR/RF code database).

#### 5.2.2 PLC Modem: QCA7006

| Parameter | Value |
|-----------|-------|
| Standard | HomePlug AV2 (IEEE 1901) |
| PHY rate | Up to 600 Mbps |
| Frequency | 2--86 MHz (OFDM, 4096 subcarriers) |
| Encryption | 128-bit AES (hardware) |
| Host interface | SPI (up to 48 MHz) or RGMII |
| Roles | CCo (Central Coordinator) or STA (Station) |
| Power | ~1.5W active, ~0.3W standby |
| Package | QFN-64 (9x9 mm) |
| Price | ~$15.00 (100 qty) |

The QCA7006 is Qualcomm Atheros's HomePlug AV2-compliant PLC baseband and AFE (Analog Front End) in a single chip. It handles all OFDM modulation, FEC encoding (LDPC + Turbo), channel estimation, and AES encryption internally. The host MCU simply sends and receives Ethernet frames via SPI.

**SDK access note:** Qualcomm provides the QCA7006 SDK under NDA to volume customers. The reference design includes the coupling circuit, firmware binary, and host driver source. If NDA access proves difficult, alternative PLC chipsets include Broadcom BCM60500 and MaxLinear G.hn chips (see Risk Matrix, Section 18).

#### 5.2.3 Ethernet PHYs: LAN8720A x 2

| Parameter | Value |
|-----------|-------|
| Standard | 10/100 Mbps Ethernet |
| Interface | RMII (to ESP32-S3) |
| Package | QFN-24 (4x4 mm) |
| Power | 75 mW typical |
| Price | ~$1.50 (1K qty) |

Two LAN8720A PHYs provide WAN and LAN Ethernet ports on the Hub. The ESP32-S3's EMAC peripheral supports RMII, and the LAN8720A is the de facto standard PHY for ESP32 Ethernet. 100 Mbps is sufficient since the ISP connection in Mexican residential is typically 50--200 Mbps, and the PLC backbone is the throughput bottleneck (200--400 Mbps TCP).

**Note:** If GbE on the Hub WAN port becomes a requirement, replace one LAN8720A with an RTL8211F (RGMII) and use the ESP32-S3's second EMAC or an SPI-to-Ethernet bridge. This is a v2 consideration.

#### 5.2.4 ADC: ADS1115 x 6

| Parameter | Value |
|-----------|-------|
| Resolution | 16-bit |
| Channels | 4 differential (or 4 single-ended) |
| Sample rate | 8 to 860 SPS (programmable) |
| Interface | I2C (4 address options per chip) |
| Input range | +/-0.256V to +/-6.144V (PGA) |
| Price | ~$2.50 (1K qty) |

Six ADS1115 chips provide 24 channels for CT clamp reading. Each ADS1115 has 4 single-ended inputs. With I2C addressing (ADDR pin to GND, VDD, SDA, or SCL), 4 chips share one I2C bus. The remaining 2 chips go on the second I2C bus of the ESP32-S3.

At 860 SPS per channel, each chip cycles through its 4 channels at 215 readings/channel/second. For 60 Hz power measurement, the Nyquist minimum is 120 SPS; 215 SPS provides comfortable margin for accurate RMS calculation.

**I2C Bus Layout:**
- I2C Bus 0 (GPIO 1/2): ADS1115 #1--#4 (channels 1--16), ATECC608B
- I2C Bus 1 (GPIO 3/4): ADS1115 #5--#6 (channels 17--24)

#### 5.2.5 Crypto: ATECC608B

| Parameter | Value |
|-----------|-------|
| Algorithms | ECC P-256, SHA-256, AES-128, HMAC |
| Key storage | 16 key slots (private keys never leave chip) |
| Interface | I2C (1 MHz) |
| Tamper | Active shield, voltage/temperature monitors |
| Package | UDFN-8 (2x3 mm) |
| Price | ~$0.80 (1K qty) |

Each PowerNode device (Hub and Node) carries an ATECC608B for hardware-rooted identity. At manufacturing, a unique X.509 certificate is provisioned into a key slot. The private key is generated on-chip and never extracted. This certificate is used for:
- TLS mutual authentication (device proves identity to cloud/app)
- Firmware signature verification (public key stored in eFuse, signature checked by ATECC608B)
- PLC network key derivation (ECDH key exchange between Hub and Node during pairing)

#### 5.2.6 Power Supply: Mean Well HDR-15-12

| Parameter | Value |
|-----------|-------|
| Input | 85--264 VAC (universal) |
| Output | 12V DC, 1.25A (15W) |
| Efficiency | 87% |
| Form factor | DIN-rail mount, 17.5mm wide (1 module) |
| Protections | Short circuit, overload, over-voltage |
| Price | ~$8.00 |

The HDR-15-12 provides the 12V main rail. Downstream regulation:
- 12V -> 3.3V: AP2112K-3.3 LDO (600 mA, for ESP32-S3 + ADS1115 + ATECC608B + misc logic)
- 12V -> 1.8V: AP2112K-1.8 LDO (600 mA, for QCA7006 core)
- 12V -> 5.0V: TPS563200 buck (3A, for future SSR gate drivers in Phase 2)

Total power budget:

| Subsystem | Current (3.3V) | Power |
|-----------|----------------|-------|
| ESP32-S3 (active WiFi + BLE) | 350 mA | 1.16W |
| QCA7006 (active TX) | 450 mA @ 1.8V | 0.81W |
| LAN8720A x 2 | 50 mA | 0.17W |
| ADS1115 x 6 | 6 mA | 0.02W |
| ATECC608B | 1 mA | 0.003W |
| CC2652P (Zigbee coordinator) | 35 mA | 0.12W |
| nRF52840 (Thread, optional) | 20 mA | 0.07W |
| IR LED + 433MHz TX | 30 mA (avg) | 0.10W |
| LEDs + misc | 50 mA | 0.17W |
| **Total** | | **~2.6W** |

The 15W PSU provides ample headroom for Phase 2 SSR drivers and the smart home integration radios.

### 5.3 PLC Coupling Circuit

The coupling circuit injects the PLC signal (2--86 MHz) onto the power line while isolating the Hub electronics from mains voltage.

```
        Hub QCA7006                    Mains L/N
        TX/RX differential             (127V 60Hz)
             |    |
             |    |
        +----+    +----+
        |              |
      [10nF]        [10nF]      DC blocking caps (ceramic, 250V)
        |              |
        +------||------+
               ||
        Toroidal transformer            1:1 ratio, ferrite core
        (e.g., Coilcraft WBC4-1WL)     BW: 2-100 MHz
               ||
        +------||------+
        |              |
      [100nF]       [100nF]     X2 safety capacitors (275VAC rated)
        |              |
        +----+    +----+
             |    |
             L    N
        (to house wiring)
```

**Component details:**
- **DC blocking caps (10nF, 250V ceramic):** Prevent DC bias from reaching the transformer. X7R dielectric, 0805 package.
- **Toroidal transformer (1:1):** Provides galvanic isolation between the QCA7006 and mains. Ferrite core (NiZn for MHz range). Must have flat frequency response from 2 to 86 MHz. Common part: Coilcraft WBC4-1WL or equivalent.
- **X2 safety capacitors (100nF, 275VAC):** Class X2 rated for across-the-line use. These are the primary safety components -- they must be UL/IEC certified X2 type. Failure mode is open-circuit (safe). Common part: KEMET R46KN310000P1M.
- **TVS diodes:** Bidirectional TVS (e.g., SMBJ150CA) across L/N at the coupling point for surge protection.

### 5.4 PCB Design Notes

- **Layer stackup (4-layer):**
  - Layer 1 (Top): Signal + components
  - Layer 2: Ground plane (unbroken under analog section)
  - Layer 3: Power planes (3.3V, 1.8V, 12V)
  - Layer 4 (Bottom): Signal + QCA7006
- **Board dimensions:** 100 x 80 mm (fits DIN-rail 6-module enclosure)
- **Analog isolation:** CT clamp signal conditioning and ADS1115 chips are placed in a separate board zone with their own ground pour, connected to digital ground at a single star point near the ESP32-S3 ADC reference pin.
- **PLC zone:** QCA7006 and coupling circuit are on the bottom layer with their own ground pour. High-frequency traces (differential pairs to transformer) are impedance-controlled at 100 ohm differential.
- **RMII traces:** LAN8720A to ESP32-S3 RMII bus routed as 50-ohm single-ended, length-matched within 5mm, max length 100mm.
- **Thermal:** QCA7006 thermal pad soldered to internal ground plane with thermal vias (0.3mm, array of 9). No heatsink needed at 1.5W in DIN-rail enclosure with natural convection slots.
- **Connectors:** RJ45 jacks on board edge (HR911105A with built-in magnetics). CT clamp headers are 2.54mm pitch, 2-pin, locking (Molex KK 254). Status LEDs on board edge, light-piped to enclosure front panel.

### 5.5 Enclosure

- **Type:** DIN-rail mount, plastic (UL94 V-0 rated)
- **Size:** 6 modules wide (107mm) x 90mm deep x 58mm high
- **Mounting:** Standard 35mm DIN rail (TS-35)
- **Ventilation:** Slotted top and bottom for convection
- **Front panel:** 4x status LEDs (power, PLC link, internet, error), 1x physical confirm button (recessed, for breaker control), 1x reset pinhole, 1x USB-A port (for Z-Wave stick)
- **Bottom panel:** 2x RJ45 cutouts, CT clamp cable exit grommet, power entry (internal connection to DIN-rail PSU or hardwired to breaker)
- **IR window:** Small IR-transparent window on front panel for IR blaster output
- **Material:** ABS + polycarbonate blend, flame retardant
- **Color:** Matte white with PowerNode logo

---

## 6. Node Hardware Design (PowerNode Satellite)

### 6.1 Block Diagram

```
+-------------------------------------------------------+
|  PowerNode Satellite (wall-plug enclosure)             |
|                                                        |
|  AC mains (from outlet, through integrated prongs)     |
|       |                                                |
|       +--- PLC coupler ----+------------+              |
|       |                    | QCA7006    |              |
|       |                    | PLC Modem  |              |
|       |                    +-----+------+              |
|       |                          | SPI                 |
|       |                    +-----+------+              |
|       |                    | ESP32-C3   |              |
|       |                    | (RISC-V)   |              |
|       |                    +-----+------+              |
|       |                      |       |                 |
|       |                    I2C     GPIO                 |
|       |                      |       |                 |
|       |               +------+   +---+----+            |
|       |               |ATECC |   |WS2812B |            |
|       |               |608B  |   |LED x 8 |            |
|       |               +------+   +--------+            |
|       |                                                |
|       |     SDIO                    RGMII              |
|       |  +---------+          +-----------+            |
|       |  | MT7921  |          | RTL8211F  |            |
|       |  | WiFi 6  |          | GbE PHY   |            |
|       |  | 2x2     |          +-----+-----+            |
|       |  +---------+                |                  |
|       |  2.4GHz  5GHz             RJ45                 |
|       |  antenna antenna          jack                 |
|       |                                                |
|       +--- SMPS (TPS563200) ---> 5V ---> 3.3V, 1.8V   |
|       +--- USB-C (STUSB4500) --> 5V auxiliary power    |
+-------------------------------------------------------+
```

### 6.2 Component Selection Rationale

#### 6.2.1 WiFi SoC: MediaTek MT7921

| Parameter | Value |
|-----------|-------|
| Standard | 802.11ax (WiFi 6) |
| Bands | 2.4 GHz + 5 GHz (simultaneous) |
| MIMO | 2x2 |
| Max PHY rate | 1200 Mbps (5 GHz) + 574 Mbps (2.4 GHz) |
| Interface | PCIe 2.0 or SDIO 3.0 |
| Features | OFDMA, MU-MIMO, TWT, BSS coloring |
| Package | QFN (12x12 mm) |
| Price | ~$12.00 (100 qty) |

The MT7921 is a mature WiFi 6 SoC widely used in USB dongles and embedded systems. It runs its own firmware for the WiFi stack (AP mode, WPA3, etc.) and presents itself as a network interface to the host. The ESP32-C3 communicates with it via SDIO 3.0.

**Why not use the ESP32-S3's built-in WiFi for the Node?** The ESP32-S3 only supports WiFi 4 (802.11n) with a 1x1 antenna. For client-facing WiFi access points, WiFi 6 with 2x2 MIMO is the minimum acceptable standard in 2026. The MT7921 provides this while the ESP32-C3 handles system management duties (PLC bridge, BLE provisioning, LED control).

**Antenna design:** Two PCB trace antennas (one 2.4 GHz, one 5 GHz) etched on the main PCB. The wall-plug form factor provides a roughly vertical orientation which is favorable for omnidirectional PCB antennas. Antenna matching networks (PI topology: series inductor + shunt caps) tuned during prototype bring-up with a VNA.

#### 6.2.2 MCU: ESP32-C3-MINI-1

| Parameter | Value |
|-----------|-------|
| Core | Single RISC-V @ 160 MHz |
| SRAM | 400 KB |
| Flash | 4 MB (built-in) |
| Bluetooth | BLE 5.0 |
| Peripherals | SPI, I2C, UART, GPIO |
| Secure boot | eFuse v2, flash encryption |
| Package | Module (13.2 x 16.6 mm) |
| Price | ~$2.00 (1K qty) |

The ESP32-C3 is the Node's system controller. It does not need the processing power of the S3 because its duties are lightweight:
1. Bridge Ethernet frames between QCA7006 (SPI) and MT7921 (SDIO).
2. Run BLE for initial device provisioning.
3. Drive WS2812B LED ring for status indication.
4. Periodic health reporting (temperature, uptime, link quality) to Hub via PLC.
5. OTA firmware updates (A/B partition, signed images).

The RISC-V core at 160 MHz is sufficient for frame bridging at the throughput the PLC backbone provides (~400 Mbps PHY = ~50 MB/s Ethernet frames, well within the SPI + SDIO bus bandwidth).

#### 6.2.3 Ethernet PHY: RTL8211F

| Parameter | Value |
|-----------|-------|
| Standard | 10/100/1000 Mbps (GbE) |
| Interface | RGMII |
| Package | QFN-48 (6x6 mm) |
| Power | 400 mW typical |
| Price | ~$2.00 (1K qty) |

Each Node provides one GbE port for wired devices (game consoles, desktops, smart TVs). The RTL8211F connects to the ESP32-C3 via RGMII. Since the ESP32-C3 does not have a native RGMII MAC, the connection actually routes through the MT7921's secondary Ethernet interface or via an SPI-to-RGMII bridge. Alternative: the RTL8211F connects to the QCA7006's RGMII port directly (QCA7006 can act as an Ethernet switch between PLC, its host SPI, and an optional RGMII port). This keeps GbE traffic off the ESP32-C3's limited bus bandwidth.

**Preferred routing:**
```
QCA7006 (RGMII port) <--RGMII--> RTL8211F <--MDI--> RJ45 jack
```
This way, GbE frames go directly between PLC and Ethernet without passing through the ESP32-C3.

#### 6.2.4 USB-C Power: STUSB4500

| Parameter | Value |
|-----------|-------|
| Standard | USB PD 3.0 (sink only) |
| Negotiation | 5V/9V/15V/20V profiles |
| Interface | I2C for configuration, autonomous mode available |
| Package | QFN-24 (4x4 mm) |
| Price | ~$1.50 |

The STUSB4500 provides USB-C Power Delivery negotiation. In normal operation, the Node is powered by its integrated AC plug prongs (mains to SMPS). The USB-C port serves as:
1. **Alternative power input** when the Node is used as a desktop unit (not plugged into wall).
2. **Configuration port** for factory provisioning (USB serial to ESP32-C3).
3. **5V output** to charge a phone (pass-through from SMPS, up to 2A).

### 6.3 Power Architecture

```
AC mains (127V 60Hz, from integrated plug prongs)
    |
    v
EMI filter (common-mode choke + X2 cap + Y caps)
    |
    v
Bridge rectifier (MB6S)
    |
    v
DC ~170V peak (after filtering)
    |
    v
Flyback converter (e.g., TNY290PG, 10W)    <-- isolated AC-DC
    |
    v
5V DC rail (2A max)
    |
    +---> TPS563200 buck --> 3.3V (1.5A) --> ESP32-C3, QCA7006 I/O, ATECC608B, LEDs
    |
    +---> AP2112K LDO --> 1.8V (0.6A) --> QCA7006 core, RTL8211F core
    |
    +---> USB-C VBUS out (5V/2A) --> phone charging (when enabled)
    |
    +---> MT7921 (3.3V I/O, 1.2V core via internal regulator)
```

Total power budget:

| Subsystem | Power |
|-----------|-------|
| MT7921 (WiFi 6, 2x2, active TX) | 2.5W |
| QCA7006 (PLC active TX) | 1.5W |
| ESP32-C3 (active BLE) | 0.5W |
| RTL8211F (GbE active) | 0.4W |
| WS2812B LEDs (8x, white, 50%) | 0.5W |
| ATECC608B + misc | 0.1W |
| **Total** | **~5.5W** |

The 10W flyback provides headroom for USB-C charging pass-through.

### 6.4 LED Ring Behavior

8x WS2812B addressable RGB LEDs arranged in a ring on the front face of the Node.

| State | Pattern | Color |
|-------|---------|-------|
| Booting | Rotating chase (1 LED) | White |
| Provisioning (BLE active) | Slow pulse (all LEDs) | Blue |
| Connecting to Hub | Rotating chase (2 LEDs) | Cyan |
| Connected, idle | Solid (all LEDs, dim) | Green |
| Data activity | Sparkle (random LEDs flash) | Green/white |
| Internet down | Slow pulse (all LEDs) | Orange |
| Error / fault | Fast blink (all LEDs) | Red |
| Night mode (22:00--06:00) | All off | -- |

LED behavior is user-configurable via the app (brightness, night mode schedule, disable entirely).

### 6.5 Enclosure and Form Factor

- **Type:** Wall-plug (integrated AC prongs, plugs directly into outlet)
- **Dimensions:** ~85 x 65 x 45 mm (similar to TP-Link TL-WPA8630P)
- **Prongs:** NEMA 1-15 (2-prong, standard Mexican outlet) -- non-polarized
- **Pass-through outlet:** Yes. The bottom of the Node has a female NEMA 1-15 outlet so the user does not lose the outlet. The pass-through is wired directly (not switched, not filtered -- PLC signal couples upstream of the pass-through).
- **Front face:** LED ring (visible through translucent ring), PowerNode logo
- **Bottom face:** RJ45 jack, USB-C port, reset pinhole
- **Material:** ABS + polycarbonate, matte white, UL94 V-0
- **Thermal:** Internal copper heat spreader bonded to MT7921 and QCA7006 thermal pads. Ventilation slots on sides.

### 6.6 PCB Design Notes

- **Layer stackup (4-layer):**
  - Layer 1 (Top): Signal, ESP32-C3, ATECC608B, LEDs, connectors
  - Layer 2: Ground plane (critical under antenna areas -- must be un-poured in antenna keep-out zone)
  - Layer 3: Power planes (3.3V, 1.8V, 5V)
  - Layer 4 (Bottom): MT7921, RTL8211F, QCA7006, PLC coupling
- **Board dimensions:** 60 x 45 mm
- **Antenna keep-out:** 15 x 10 mm clear area at board edge for each PCB trace antenna (2.4 GHz and 5 GHz). No ground pour, no traces, no components in this zone.
- **SDIO traces:** MT7921 to ESP32-C3 SDIO bus, impedance-controlled 50 ohm, length-matched within 3mm.
- **RGMII traces:** QCA7006 to RTL8211F, impedance-controlled 50 ohm, length-matched within 5mm.
- **PLC coupling:** Bottom layer, near AC prong connections, with creepage/clearance distances per IEC 60950-1 (5.5mm for 127V working voltage, reinforced insulation).

---

## 7. PLC Subsystem Detail

### 9.1 Standard and Protocol

| Parameter | Value |
|-----------|-------|
| Standard | HomePlug AV2 (IEEE 1901) |
| Modulation | OFDM (Orthogonal Frequency-Division Multiplexing) |
| Subcarriers | 4096 (917 usable in 2-86 MHz band) |
| Subcarrier modulation | Adaptive: BPSK to 4096-QAM per subcarrier |
| FEC | LDPC (Low-Density Parity-Check) + Turbo code |
| Encryption | 128-bit AES-CCM (per-frame, hardware) |
| MAC | TDMA + CSMA/CA hybrid |
| Max PHY rate | 600 Mbps |
| Real-world TCP | 200--400 Mbps (depends on wiring quality) |

### 9.2 Network Topology

HomePlug AV2 uses a centralized topology:

- **CCo (Central Coordinator):** The Hub. Manages TDMA scheduling, beacon periods, network admission.
- **STA (Station):** Each Node. Requests time slots from CCo for data transmission.
- **AVLN (AV Logical Network):** All devices sharing the same Network Encryption Key (NEK). One AVLN per PowerNode system.

The CCo transmits beacons every 33.33ms (2 per AC line cycle at 60 Hz). Beacons contain the TDMA schedule, network time reference, and information about persistent and non-persistent time slots.

### 7.3 Frequency Planning and Interference

**Usable spectrum: 2--86 MHz**

Within this band, certain sub-bands are permanently notched (set to zero) to avoid interference with licensed radio services:

| Notched Band | Service |
|--------------|---------|
| 1.8--2.0 MHz | Amateur radio (160m) |
| 3.5--4.0 MHz | Amateur radio (80m) |
| 7.0--7.3 MHz | Amateur radio (40m) |
| 10.1--10.15 MHz | Amateur radio (30m) |
| 14.0--14.35 MHz | Amateur radio (20m) |
| 18.068--18.168 MHz | Amateur radio (17m) |
| 21.0--21.45 MHz | Amateur radio (15m) |
| 24.89--24.99 MHz | Amateur radio (12m) |
| 28.0--29.7 MHz | Amateur radio (10m) |
| 50.0--54.0 MHz | Amateur radio (6m) |

These notches are hard-coded in the QCA7006 firmware and comply with HomePlug AV2 specification and ITU-R recommendations. Additionally, the QCA7006 performs **adaptive bit loading**: subcarriers with high noise floors (from appliance EMI, dimmer switches, etc.) are automatically downgraded to lower modulation orders or muted entirely.

### 7.4 Coupling Circuit Design (Detailed)

The coupling circuit provides:
1. **Signal injection/extraction:** Transfer PLC signal between QCA7006 differential TX/RX pins and L/N mains conductors.
2. **Galvanic isolation:** Transformer provides reinforced isolation per IEC 62368-1.
3. **Safety:** X2 capacitors are the only components directly connected to mains.

**Schematic (per device, Hub and Node identical):**

```
QCA7006                                               MAINS
TX+  ----[10nF 250V]----+                        +----  L
                         |     1:1 toroid         |
                         +---====||||||====---+---+
                         |                    |
TX-  ----[10nF 250V]----+                    +----  N
                                              |
                                           [100nF X2]
                                           (across L-N)
                                              |
                                           [TVS bidirectional]
                                           (SMBJ150CA)
```

**Transformer specification:**
- Type: Toroidal, 1:1 ratio
- Core: NiZn ferrite (e.g., Fair-Rite 5961003801)
- Turns: 10:10 (bifilar wound for tight coupling)
- Bandwidth: 2--100 MHz (-3 dB points)
- Isolation: 4kV minimum (reinforced, per IEC 62368-1)
- Insertion loss: < 1 dB across 2--86 MHz
- Common part: Coilcraft WBC4-1WL or custom wound

**X2 capacitor specification:**
- Capacitance: 100 nF
- Voltage rating: 275 VAC (X2 class)
- Certification: IEC 60384-14 Class X2
- Failure mode: Open circuit (safe)
- Common part: KEMET R46KN310000P1M (or Vishay MKP equivalent)

### 7.5 Expected Performance on Mexican Residential Wiring

Mexican residential wiring (per NOM-001-SEDE-2012) is typically:
- **Voltage:** 127V single-phase, 60 Hz
- **Wire gauge:** 12 AWG (THW, copper) for branch circuits, 10 AWG for feeders
- **Conduit:** PVC or EMT (metal) conduit common in newer construction, exposed Romex in older homes
- **Panel:** Single-phase split-bus or main-lug, 100--200A service

PLC performance factors:

| Factor | Mexican Residential | Impact on PLC |
|--------|-------------------|---------------|
| Wire gauge (12 AWG copper) | Good conductor, low resistance | Positive: low attenuation |
| Typical run length (< 30m per circuit) | Short runs | Positive: strong signal |
| PVC conduit | No shielding | Neutral: slightly more EMI susceptibility |
| EMT conduit | Metallic shielding | Negative: higher attenuation, but still workable |
| Phase topology (single-phase) | All outlets on same phase | Positive: no cross-phase coupling needed |
| Common noise sources (blenders, washing machines) | Impulse noise | Negative: handled by LDPC FEC + adaptive modulation |
| GFCI outlets (in wet areas) | May attenuate high frequencies | Mild negative: reduced throughput on that circuit |

**Expected throughput by scenario:**

| Scenario | Distance | Throughput (TCP) |
|----------|----------|-----------------|
| Same circuit, < 15m | Short | 350--400 Mbps |
| Adjacent circuit, same phase | Medium | 250--350 Mbps |
| Distant circuit, through panel | Long | 150--250 Mbps |
| Through GFCI outlet | Any | 100--200 Mbps |
| Old wiring (> 30 years, spliced) | Varies | 80--200 Mbps |

These estimates assume QCA7006 with HomePlug AV2 at its full 2--86 MHz spectrum. Actual throughput should be validated during field testing at BC's rental properties (see Prototype Plan, Section 17).

---

## 8. Smart Metering Subsystem

### 8.1 Current Transformer (CT) Clamp

**Part:** SCT-013-020

| Parameter | Value |
|-----------|-------|
| Type | Split-core (clamp-on, non-invasive) |
| Rated current | 20A |
| Output type | Voltage (built-in burden resistor) |
| Output at rated current | 1V AC RMS |
| Accuracy | +/-0.5% at rated current |
| Linearity | +/-0.2% (1--20A range) |
| Phase error | < 2 degrees |
| Aperture | Fits up to 13mm wire (12 AWG in conduit) |
| Cable length | 1m (supplied) |

The SCT-013-020 has a built-in burden resistor that produces a voltage output proportional to current. This simplifies the signal conditioning -- no external burden resistor is needed (though one is used for impedance matching to the ADC, see below).

**Installation:** Each CT clamp clips around one conductor (hot or neutral, not both) of a circuit at the breaker panel. No wire cutting, no electrical contact. A licensed electrician opens the panel, clips CTs onto circuits, routes CT cables through a grommet in the Hub enclosure, and plugs them into the Hub's CT headers.

### 8.2 Signal Conditioning

The CT clamp output is a bipolar AC signal (swings +/- 1V at 20A). The ADS1115 in single-ended mode needs a unipolar input referenced to GND. The signal conditioning circuit adds a DC bias to center the AC signal within the ADC's input range.

**Circuit per channel:**

```
CT clamp output (+/-1V AC)
    |
    +----[22 ohm]----+---- to ADS1115 input (Ax)
    |                 |
    |               [10uF]    AC coupling cap (electrolytic)
    |                 |
    |                GND
    |
    +----[100K]------+---- 1.65V bias
    |                |
    +----[100K]------+
    |                |
   3.3V             GND
```

Wait -- with the SCT-013-020's built-in burden, the output is already voltage. The signal conditioning simplifies to:

```
CT output (0 to +/-1V AC)
        |
        +---[100 ohm series R]---+--- to ADS1115 input
        |                        |
        |                      [100nF]  (anti-aliasing LPF, fc = 16 kHz)
        |                        |
        |                       GND
        |
        +---[100K]---+---[100K]---+
        |             |            |
       3.3V         bias          GND
                   (1.65V)
                     |
                     +--- to ADS1115 input (via series R above)
```

**Resulting signal at ADC input:**
- No current: 1.65V DC
- 20A: 1.65V +/- 1.0V = 0.65V to 2.65V
- ADC range: 0V to 3.3V (ADS1115 with PGA set to +/-4.096V, but VDD = 3.3V clamps input)

**ADS1115 configuration:**
- PGA gain: +/-4.096V (allows full 0--3.3V input range)
- Data rate: 860 SPS
- Mode: Continuous conversion, auto-scan 4 channels

### 8.3 RMS Calculation Algorithm

The ESP32-S3 firmware computes true RMS current from the ADC samples:

```c
// Pseudo-code for one circuit's RMS calculation
#define SAMPLES_PER_CYCLE  16    // At 860 SPS / 4 channels = 215 SPS per channel
                                  // 215 / 60 Hz = ~3.6 samples per cycle
                                  // Actually: need higher rate. See note below.
#define VREF_BIAS          1.65f  // DC bias voltage
#define CT_RATIO           20.0f  // 20A produces 1.0V
#define VOLTAGE_NOMINAL    127.0f // Mexican mains nominal
#define POWER_FACTOR       0.95f  // Assumed PF for residential (adjustable)

float compute_irms(uint16_t *samples, int count) {
    float sum_sq = 0.0f;
    for (int i = 0; i < count; i++) {
        float voltage = (samples[i] * 4.096f / 32768.0f) - VREF_BIAS;
        float current = voltage * CT_RATIO;  // Convert voltage back to amps
        sum_sq += current * current;
    }
    return sqrtf(sum_sq / count);  // RMS current in amps
}

float compute_watts(float irms) {
    return irms * VOLTAGE_NOMINAL * POWER_FACTOR;
}
```

**Sampling rate concern:** At 860 SPS with 4 channels per ADS1115 chip, each channel gets 215 SPS. For a 60 Hz signal, that is only ~3.6 samples per cycle -- **too few for accurate RMS.** Solutions:

**Option A (preferred):** Dedicate each ADS1115 to fewer channels and run at higher effective SPS per channel.
- Use only 2 channels per ADS1115 chip (ignoring the other 2 inputs) = 430 SPS per channel = ~7 samples per cycle. Still marginal.

**Option B (recommended):** Use a higher-speed ADC.
- **MCP3208** (12-bit, 8-channel, SPI, 100 kSPS) -- 3 chips = 24 channels at 4.17 kSPS each = 69 samples per cycle. Excellent.
- Trade-off: 12-bit vs 16-bit resolution. At 12-bit, the current resolution is 20A / 4096 = ~5 mA. For monitoring purposes (not billing), this is acceptable.

**Option C:** Keep ADS1115 but oversample with interpolation. Not recommended -- fundamental aliasing cannot be fixed with interpolation.

**Design decision:** Use ADS1115 for low-current monitoring (0--20A range, adequate for "which circuits are active" granularity at 3--4 samples per cycle). For users wanting higher accuracy, offer an upgrade path with MCP3208 ADC boards in a future hardware revision. The +/-2% accuracy target is achievable with ADS1115 if we accumulate RMS over multiple cycles (1 second = 60 cycles x 3.6 samples = 216 samples -- statistically adequate).

### 8.4 Multi-Cycle RMS with ADS1115

Over a 1-second window (60 cycles at 60 Hz), each channel accumulates ~215 samples. The RMS calculation over 215 samples, even with irregular sampling relative to the AC waveform, converges to the true RMS with < 1% error (validated by simulation). This works because:

1. The 215 Hz sample rate and 60 Hz signal frequency are not integer multiples, so samples are distributed across different phase angles over multiple cycles (beating pattern).
2. Over 60+ cycles, the phase distribution becomes approximately uniform.
3. The error is dominated by ADC quantization noise (16-bit: negligible) and CT clamp accuracy (+/-0.5%), not sample timing.

**Reporting cadence:**
- **1-second RMS:** Computed from 215 accumulated samples. Published to MQTT for real-time dashboard.
- **1-minute average:** Mean of 60 one-second RMS values. Stored in Hub's PSRAM ring buffer and synced to cloud.
- **1-hour aggregate:** Min, max, mean Watts for the hour. Stored to cloud for historical trends.
- **Daily total:** kWh accumulator (trapezoidal integration of 1-second power readings). Reported at midnight.

### 8.5 Calibration

Each CT clamp + ADC channel combination must be calibrated at manufacturing or installation time. The calibration procedure:

1. Pass a known current through the CT (e.g., 10A from a calibrated load).
2. Read raw ADC values for 10 seconds.
3. Compute the calibration factor: `cal_factor = known_current / measured_irms_raw`.
4. Store `cal_factor` in Hub NVS (non-volatile storage) per channel.
5. All subsequent readings are multiplied by `cal_factor`.

The calibration factor compensates for:
- CT clamp manufacturing tolerance (+/-0.5%)
- Burden resistor tolerance (+/-1%)
- ADC gain error (+/-0.01%)
- PCB trace resistance (negligible)

**User-accessible calibration:** The app provides a "calibrate" function where the user plugs a known-wattage load (e.g., a 1000W space heater) into a circuit and taps "calibrate" -- the app divides the known wattage by 127V to get expected current and adjusts the cal_factor.

### 8.6 Energy Data Storage

**On-Hub storage (PSRAM ring buffer):**

```
Ring buffer structure:
- 24 circuits x 4 bytes (float32 Watts) x 86400 seconds = 8,294,400 bytes (~7.9 MB)
- Fits in 8 MB PSRAM with room for overhead
- Oldest data overwritten after 24 hours
- Used for: real-time app display, catch-up sync if cloud connection is temporarily lost
```

**Cloud storage (Supabase or AWS IoT):**

```sql
-- Table: energy_readings
CREATE TABLE energy_readings (
    device_id UUID NOT NULL,
    circuit_id SMALLINT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    watts_avg REAL NOT NULL,
    watts_min REAL NOT NULL,
    watts_max REAL NOT NULL,
    kwh_delta REAL NOT NULL,
    PRIMARY KEY (device_id, circuit_id, timestamp)
);

-- Partitioned by month for efficient queries and retention management
-- 1-minute granularity: 24 circuits x 1440 minutes x 30 days = ~1M rows/month/hub
-- Retention: 2 years (configurable)
```

---

## 9. Breaker Control Subsystem

### 9.1 Phase 1 (v1.0): Monitor Only

The v1.0 product ships with **metering only**. No breaker switching capability. This is a deliberate safety and liability decision:

- Remote breaker control in a consumer product has significant safety implications.
- NOM-001-SEDE-2012 compliance for switching equipment requires specific testing and certification.
- Liability exposure for fire or electrocution from a malfunctioning remote switch is substantial.
- The metering-only product provides immediate value and establishes market presence.

### 9.2 Phase 2 (v2.0): Solid-State Relay Switching

When regulatory and safety requirements are satisfied, v2.0 adds per-circuit switching.

#### 9.2.1 Relay Selection: IXYS CPC1017N

| Parameter | Value |
|-----------|-------|
| Type | Optically isolated AC solid-state relay |
| Voltage rating | 600V peak |
| On-state current | 100 mA (trigger), load current limited by external TRIAC/MOSFET |
| Isolation | 3750V RMS (input to output) |
| Turn-on time | 1 ms typical |
| Package | SOP-4 |
| Price | ~$2.00 |

**Note:** The CPC1017N is a trigger-only SSR. It drives the gate of an external power TRIAC or MOSFET that handles the actual load current. For a 20A residential circuit:

```
ESP32 GPIO (3.3V)
    |
    +---[330 ohm]---+
                    |
                  [CPC1017N]
                    |         |
                    +--- AC out (drives TRIAC gate)
                    |
                  [BTA40-600B]     <-- 40A TRIAC, 600V
                    |         |
                 LINE IN    LINE OUT
                 (from breaker)  (to circuit)
```

**BTA40-600B TRIAC:**
- 40A continuous (double the 20A circuit rating for derating)
- 600V blocking voltage
- Snubber: 100 ohm + 100 nF RC across MT1/MT2
- Heatsink: Required (TO-247 package, clip-on heatsink on DIN-rail bracket)

#### 9.2.2 Safety Architecture

The breaker control subsystem implements defense-in-depth:

**Layer 1 -- Hardware watchdog:**
- External watchdog IC (e.g., MAX6369) with 1.6-second timeout.
- ESP32-S3 must toggle the watchdog input every second.
- If the ESP32-S3 crashes or hangs, the watchdog times out and asserts its output.
- Watchdog output is wired to the ENABLE pin of the SSR driver power supply.
- **Result:** MCU crash = all SSRs lose gate drive = all TRIACs turn off at next zero crossing = all circuits return to ON state (fail-safe open).

**Layer 2 -- Fail-safe default:**
- SSRs are wired in series with the existing mechanical breakers, NOT as replacements.
- The mechanical breaker remains in the circuit and functions normally.
- The SSR can only ADD an additional OFF state; it cannot override a tripped breaker.
- Default state (SSR unpowered) = circuit ON. This is the safe default for a residential system.

**Layer 3 -- Two-factor actuation:**
- Any breaker OFF command via MQTT requires:
  1. Authenticated MQTT message with user's OAuth2 token + app PIN.
  2. Physical button press on the Hub within 30 seconds of the MQTT command.
- Without both factors, the command is rejected.
- Emergency OFF (e.g., overcurrent detected by metering) bypasses the physical button requirement but still requires authenticated MQTT.

**Layer 4 -- Rate limiting:**
- Maximum 10 switching events per circuit per hour.
- Maximum 100 switching events total per hour across all circuits.
- Prevents rapid cycling that could damage connected equipment.

**Layer 5 -- Current monitoring interlock:**
- Before switching a circuit OFF, the Hub checks the CT clamp reading for that circuit.
- If current > 16A (80% of breaker rating), the Hub delays switching by 5 seconds and alerts the user.
- This prevents switching off a circuit under heavy load (which is safe for the SSR but may cause transient issues for the load).

#### 9.2.3 NOM and CFE Considerations

- **NOM-001-SEDE-2012:** Mexican electrical installation code. Any modification to the breaker panel must comply. The PowerNode Hub is classified as an "accessory device" in the panel, not a replacement breaker.
- **Licensed electrician required:** Installation of the Hub (DIN-rail mounting, CT clamp placement, SSR wiring in Phase 2) must be performed by a certified electrician with NOM-001 credentials.
- **CFE coordination:** The Hub does not modify the CFE meter or service entrance. It operates entirely downstream of the meter. No CFE approval needed for in-home monitoring/switching.
- **Product certification:** The Hub as a product must obtain NOM-208-SCFI-2016 (telecom equipment) certification for the PLC modem and WiFi radio. The power section must meet NOM-019-SCFI (electrical safety for consumer electronics).

---

## 10. Firmware Architecture

### 10.1 Hub Firmware (ESP-IDF, FreeRTOS)

**Development environment:**
- Framework: ESP-IDF v5.2+ (FreeRTOS kernel)
- Language: C (with C++ for PLC driver abstraction)
- Build system: CMake + idf.py
- Flash layout: A/B OTA partitions, NVS partition, factory partition

**Task architecture:**

```
+------------------------------------------------------------------+
|  FreeRTOS Task Map (Hub)                                         |
|                                                                  |
|  Core 0:                          Core 1:                        |
|  +-------------------+            +-------------------+          |
|  | plc_manager_task  |            | metering_task     |          |
|  | (priority: 20)    |            | (priority: 22)    |          |
|  | - QCA7006 SPI     |            | - ADC read loop   |          |
|  | - Frame TX/RX     |            | - RMS computation |          |
|  | - CCo management  |            | - 1s publish      |          |
|  +-------------------+            +-------------------+          |
|                                                                  |
|  +-------------------+            +-------------------+          |
|  | mqtt_broker_task  |            | breaker_ctrl_task |          |
|  | (priority: 15)    |            | (priority: 18)    |          |
|  | - Local Mosquitto |            | - SSR GPIO control|          |
|  | - Cloud bridge    |            | - Safety interlocks|         |
|  | - Msg routing     |            | - Watchdog feed   |          |
|  +-------------------+            +-------------------+          |
|                                                                  |
|  +-------------------+            +-------------------+          |
|  | network_task      |            | ota_task          |          |
|  | (priority: 12)    |            | (priority: 8)     |          |
|  | - NAT / DHCP      |            | - Check for update|          |
|  | - DNS relay       |            | - Download + verify|         |
|  | - Firewall rules  |            | - A/B swap + boot |          |
|  +-------------------+            +-------------------+          |
|                                                                  |
|  +-------------------+            +-------------------+          |
|  | webserver_task    |            | zigbee_task       |          |
|  | (priority: 5)     |            | (priority: 16)    |          |
|  | - Config UI       |            | - CC2652P UART    |          |
|  | - REST API        |            | - Zigbee coord    |          |
|  | - SPIFFS assets   |            | - Device join/mgmt|          |
|  +-------------------+            +-------------------+          |
|                                                                  |
|  +-------------------+            +-------------------+          |
|  | cloud_integrations|            | automation_task   |          |
|  | (priority: 10)    |            | (priority: 14)    |          |
|  | - Tuya API poll   |            | - Rule engine     |          |
|  | - eWeLink API     |            | - Scene executor  |          |
|  | - TTLock API      |            | - Cross-platform  |          |
|  | - EZVIZ API       |            |   if/then rules   |          |
|  | - Hubspace API    |            | - Trigger eval    |          |
|  | - State sync      |            +-------------------+          |
|  +-------------------+                                           |
|                                                                  |
|  +-------------------+            +-------------------+          |
|  | ir_rf_task        |            | device_abstraction|          |
|  | (priority: 6)     |            | (priority: 11)    |          |
|  | - IR learn/send   |            | - Common model    |          |
|  | - 433MHz send     |            | - State normalize |          |
|  | - Code database   |            | - Event dispatch  |          |
|  +-------------------+            +-------------------+          |
|                                                                  |
|  +-------------------+            +-------------------+          |
|  | wireguard_srv_task|            | powerdesk_task    |          |
|  | (priority: 17)    |            | (priority: 7)     |          |
|  | - WG server listen|            | - hbbs signal srv |          |
|  | - Tunnel mgmt     |            | - hbbr relay srv  |          |
|  | - Roaming auth    |            | - Device registry |          |
|  | - DHCP for roaming|            | - Session mgmt    |          |
|  | - Route injection |            | - mDNS discovery  |          |
|  +-------------------+            +-------------------+          |
+------------------------------------------------------------------+
```

**Key task details:**

**plc_manager_task (Core 0, priority 20):**
- Initializes QCA7006 via SPI (48 MHz clock, mode 0).
- Sets Hub as CCo (Central Coordinator) via HPGP management frames.
- Handles node association (new device joins network).
- Manages Network Encryption Key (NEK) rotation (hourly).
- Bridges Ethernet frames between QCA7006 SPI interface and lwIP stack.
- Monitors PLC link quality per node (SNR, attenuation, PHY rate) and publishes to MQTT.

**metering_task (Core 1, priority 22):**
- Highest priority task on Core 1 (metering is time-critical for accurate RMS).
- Reads all 24 ADC channels in a round-robin scan (6 ADS1115 chips, 4 channels each).
- One complete scan of all 24 channels takes ~28ms (24 channels x 1.16ms per conversion at 860 SPS).
- Accumulates samples in per-channel ring buffers (256 samples each).
- Every 1 second: computes RMS from accumulated samples, applies calibration factor, computes Watts.
- Publishes per-circuit power data to MQTT topic `powernode/{hub_id}/meter/{circuit_id}`.
- Accumulates kWh per circuit (trapezoidal integration).
- Every 60 seconds: stores 1-minute aggregate to PSRAM ring buffer.

**mqtt_broker_task (Core 0, priority 15):**
- Runs an embedded MQTT broker (based on ESP-MQTT or a lightweight Mosquitto port).
- Local broker serves Hub-to-Node communication and LAN-based app connections.
- Cloud bridge: subscribes to cloud MQTT broker (AWS IoT Core or self-hosted) and relays messages bidirectionally.
- Topic namespace:
  ```
  powernode/{device_id}/meter/{circuit_id}    # Metering data (pub by hub)
  powernode/{device_id}/breaker/{circuit_id}  # Breaker commands (sub by hub)
  powernode/{device_id}/status                # Device status (pub by all)
  powernode/{device_id}/config                # Configuration (sub by all)
  powernode/{device_id}/ota                   # OTA commands (sub by all)
  powernode/{device_id}/network               # PLC/WiFi stats (pub by all)
  powernode/{device_id}/smarthome/{dev_id}    # Smart home device state (pub by hub)
  powernode/{device_id}/smarthome/{dev_id}/cmd # Smart home device commands (sub by hub)
  powernode/{device_id}/automation/trigger     # Automation trigger events
  powernode/{device_id}/scene/{scene_id}/exec  # Scene execution commands
  powernode/account/{acct_id}/cross-property   # Hub-to-hub cross-property messages
  ```

**network_task (Core 0, priority 12):**
- Runs lwIP stack for NAT, DHCP server, DNS relay.
- DHCP pool: 192.168.77.10 -- 192.168.77.250 (241 clients).
- DNS relay: forwards queries to ISP DNS or user-configured DNS (e.g., 1.1.1.1).
- Firewall: Stateful packet inspection, default-deny inbound, allow established+related.
- Parental controls: Per-MAC address allow/deny schedules, stored in NVS.
- Guest network: Separate VLAN-like logical network on PLC (different NEK).

**webserver_task (Core 0, priority 5):**
- HTTP server on port 80 (LAN only, not exposed to WAN).
- Serves a single-page config UI (built with Svelte or vanilla JS, stored in SPIFFS).
- REST API for programmatic configuration.
- Endpoints:
  ```
  GET  /api/status          # Hub status (uptime, firmware version, PLC stats)
  GET  /api/meters           # Current readings for all circuits
  GET  /api/meters/{id}     # Historical data for one circuit
  GET  /api/network          # Connected devices, PLC link quality
  POST /api/config           # Update configuration
  POST /api/ota/check        # Check for firmware update
  POST /api/ota/apply        # Apply firmware update
  POST /api/breaker/{id}     # Breaker control (Phase 2)
  POST /api/calibrate/{id}   # Calibrate CT clamp channel
  GET  /api/wireguard         # WireGuard tunnel status (connected peers)
  GET  /api/powerdesk         # PowerDesk approved devices and active sessions
  POST /api/powerdesk/approve # Approve a discovered device for remote access
  ```

**wireguard_srv_task (Core 0, priority 17):**
- Runs WireGuard server on UDP port 51820 (configurable).
- Manages authorized-peers list (one entry per paired node, loaded from NVS).
- Handles incoming tunnel handshakes from roaming nodes.
- Validates peer identity against authorized-peers list (public key match).
- Assigns DHCP lease from home pool to roaming node.
- Injects routes for roaming node's connected clients.
- NATs all tunnel traffic through WAN interface.
- Publishes roaming events to MQTT (`powernode/{hub_id}/roaming/{node_id}`).
- Monitors tunnel health (keepalive, latency, throughput).
- Supports up to 8 concurrent roaming tunnels.

**powerdesk_task (Core 1, priority 7):**
- Runs hbbs (signal server) on TCP 21115-21116 and hbbr (relay) on TCP 21117.
- Binds to LAN and WireGuard tunnel interfaces (never exposed to WAN directly).
- Performs mDNS discovery scan every 60 seconds for `_powerdesk._tcp.local`.
- Maintains device registry in NVS (discovered devices, approved/pending status).
- Validates incoming connection requests: requesting node must have active WireGuard tunnel AND target device must be approved.
- Relays video/input streams between remote PowerDesk client and target device.
- Rate limiting: max 5 connection attempts per minute per source.
- Publishes session events to MQTT for app notification.

### 10.2 Node Firmware (ESP-IDF, ESP32-C3)

**Task architecture:**

```
+------------------------------------------+
|  FreeRTOS Task Map (Node, single core)   |
|                                          |
|  +-------------------+                   |
|  | bridge_task       |                   |
|  | (priority: 20)    |                   |
|  | - QCA7006 SPI     |                   |
|  | - MT7921 SDIO     |                   |
|  | - Frame bridging  |                   |
|  +-------------------+                   |
|                                          |
|  +-------------------+                   |
|  | ble_prov_task     |                   |
|  | (priority: 15)    |                   |
|  | - BLE beacon      |                   |
|  | - Provisioning    |                   |
|  | - WiFi cred push  |                   |
|  +-------------------+                   |
|                                          |
|  +-------------------+                   |
|  | led_task          |                   |
|  | (priority: 5)     |                   |
|  | - WS2812B driver  |                   |
|  | - Status patterns |                   |
|  +-------------------+                   |
|                                          |
|  +-------------------+                   |
|  | health_task       |                   |
|  | (priority: 8)     |                   |
|  | - PLC link stats  |                   |
|  | - WiFi client cnt |                   |
|  | - Temp monitoring |                   |
|  | - MQTT publish    |                   |
|  +-------------------+                   |
|                                          |
|  +-------------------+                   |
|  | wireguard_cli_task|                   |
|  | (priority: 16)    |                   |
|  | - Roaming detect  |                   |
|  | - Cert present    |                   |
|  | - WG tunnel setup |                   |
|  | - Traffic routing |                   |
|  | - Keepalive mgmt  |                   |
|  +-------------------+                   |
+------------------------------------------+
```

**bridge_task** is the critical path:
1. QCA7006 raises an interrupt when an Ethernet frame arrives via PLC.
2. ESP32-C3 reads the frame from QCA7006 via SPI DMA.
3. ESP32-C3 inspects the frame's destination MAC:
   - If destined for a WiFi client: forward to MT7921 via SDIO.
   - If destined for the GbE port: forward to RTL8211F via QCA7006's RGMII (no ESP32 involvement -- handled in QCA7006 internal switch if wired this way).
   - If broadcast/multicast: forward to both.
4. Reverse path: MT7921 raises interrupt when a WiFi client sends a frame. ESP32-C3 reads via SDIO, writes to QCA7006 via SPI.

**Throughput budget:**
- SPI to QCA7006: 48 MHz, 8-bit = 48 Mbps raw (6 MB/s). With framing overhead, ~4 MB/s usable.
- SDIO to MT7921: 50 MHz, 4-bit = 200 Mbps raw (25 MB/s). Usable: ~15 MB/s.
- Bottleneck: SPI to QCA7006 at ~4 MB/s = ~32 Mbps TCP throughput per node.

**This is a problem.** 32 Mbps is well below the PLC backbone capability (200--400 Mbps). Solutions:

**Option A:** Use QCA7006's RGMII interface for the MT7921 connection (bypassing the ESP32-C3 for data frames). The ESP32-C3 handles only management traffic (provisioning, health, LED). This is architecturally cleaner and removes the throughput bottleneck.

**Option B:** Replace ESP32-C3 with a higher-performance SoC that has native RGMII or PCIe (e.g., ESP32-S3 with RMII, or a Linux-based SoC like Allwinner T113-S3).

**Recommended: Option A.** Route the data path through QCA7006's built-in Ethernet switch:

```
PLC <--internal--> QCA7006 <--RGMII--> MT7921 (WiFi)
                     |
                     +--RGMII--> RTL8211F (GbE)
                     |
                     +--SPI--> ESP32-C3 (management only, low bandwidth)
```

The QCA7006 has an internal 3-port Ethernet switch (PLC port, RGMII port, host SPI port). In this configuration, high-bandwidth data frames flow between PLC and RGMII (MT7921/RTL8211F) entirely within the QCA7006, at wire speed. The ESP32-C3 only sees management frames (MQTT, BLE provisioning, LED commands) which are < 1 Mbps.

**wireguard_cli_task (priority 16):**
- Monitors PLC link state. If no home hub responds on PLC within 30 seconds of boot, enters ROAMING MODE.
- In roaming mode, obtains internet connectivity (Ethernet, PLC passthrough via guest network, or user-provided WiFi via setup AP).
- Reads X.509 certificate from ATECC608B key slot 1.
- Contacts cloud trust registry (TLS 1.3) to resolve home hub's WireGuard endpoint.
- Presents certificate for validation. On success, receives hub's WireGuard public key and endpoint.
- Establishes WireGuard tunnel to home hub (Noise_IKpsk2 handshake, PSK from ECDH).
- Sets home hub as default gateway for all tunnel traffic.
- Configures WiFi AP to broadcast home SSID over tunnel.
- Maintains tunnel with 25-second persistent keepalive.
- On tunnel drop: exponential backoff reconnection (1s, 2s, 4s, 8s, max 60s).
- Publishes roaming status to MQTT for app notification.

### 10.3 OTA Firmware Update

Both Hub and Node use the ESP-IDF A/B partition scheme:

```
Flash layout (16 MB for Hub, 4 MB for Node):

Hub:
| Bootloader (64KB) | Partition Table (4KB) | NVS (16KB) | OTA Data (8KB) |
| App A (3MB) | App B (3MB) | SPIFFS (2MB) | Factory (3MB) | Reserved |

Node:
| Bootloader (64KB) | Partition Table (4KB) | NVS (16KB) | OTA Data (8KB) |
| App A (1.5MB) | App B (1.5MB) | Factory (512KB) | Reserved |
```

**Update flow:**
1. Hub checks cloud endpoint for new firmware version (every 6 hours, or on-demand via app).
2. If update available, Hub downloads the firmware binary to the inactive partition (A or B).
3. Hub verifies the binary signature (ECDSA P-256, public key in eFuse, signature check via ATECC608B).
4. If valid, Hub sets the OTA data partition to boot from the new partition on next restart.
5. Hub restarts, boots into new firmware.
6. New firmware runs self-test (PLC link, MQTT connect, metering read). If self-test passes, the new partition is confirmed. If self-test fails, the bootloader rolls back to the previous partition on next restart.
7. For Nodes: Hub pushes firmware updates to Nodes via PLC. Same verify/flash/reboot/confirm flow.

**Delta updates:** To minimize OTA download size over potentially slow PLC links, the update server generates binary diffs (using bsdiff or similar). A 3 MB firmware image with minor changes typically produces a 50--200 KB delta. The ESP32 reconstructs the full image by applying the delta to the current partition.

---

## 11. Security Architecture

### 11.1 Threat Model

| Threat | Vector | Impact | Mitigation |
|--------|--------|--------|------------|
| Unauthorized breaker control | MQTT injection | Physical safety (fire, electrocution) | Mutual TLS + 2FA + rate limiting |
| PLC eavesdropping | Neighbor on same transformer | Privacy (traffic content) | HomePlug AV2 AES-128 + network key rotation |
| Firmware tampering | Physical access to device | Full device compromise | Secure boot + flash encryption + tamper switch |
| Device impersonation | Rogue device on PLC network | Data theft, network disruption | X.509 device certificates, ECDH key exchange |
| Cloud account hijack | Credential theft | Remote control of all devices | OAuth2 + biometric + device-bound tokens |
| Man-in-the-middle | Network interception | Data theft, command injection | TLS 1.3 with mutual authentication (client cert) |
| Supply chain (counterfeit HW) | Factory compromise | Backdoored devices | ATECC608B provisioned at controlled factory, chain of custody |
| Third-party API token theft | Hub compromise or memory dump | Unauthorized access to user's Tuya/eWeLink/etc. accounts | All API tokens encrypted at rest on ATECC608B |
| Camera stream interception | Network sniffing | Privacy violation (video feeds) | RTSP proxied through encrypted tunnel, never exposed to internet |
| Unauthorized lock control | MQTT injection or API exploit | Physical security breach | Extra biometric confirmation layer in app for ALL lock commands |
| Stolen roaming node | Physical theft of Satellite node | Attacker could access home network via VPN tunnel | Owner marks node as lost in app; cert added to CRL; all hubs reject the node immediately. WireGuard keys rotated. |
| Roaming node on hostile network | Man-in-the-middle on hotel/public WiFi | Traffic interception before tunnel establishment | All pre-tunnel comms use TLS 1.3 with pinned certs. Once tunnel is up, all traffic is WireGuard-encrypted (ChaCha20-Poly1305). |
| Cloud trust registry compromise | Attacker compromises registry to redirect tunnels | Tunnel established to attacker's server instead of home hub | Hub's WireGuard public key is pinned on the node at pairing time. Even if registry returns wrong endpoint, handshake fails because attacker lacks hub's private key. |
| Unauthorized PowerDesk access | Attacker gains network access | Remote desktop access to home PCs | Double approval: node must have valid X.509 cert AND target device must be explicitly approved by hub owner. Rate limiting on relay. |
| Rogue roaming hub impersonation | Attacker sets up fake hub at public location | Node connects to fake hub, traffic intercepted | Node validates hub certificate chain (up to Root CA). Fake hub cannot produce valid cert. |

### 11.1.1 Third-Party API Credential Security

All third-party platform API tokens and OAuth2 refresh tokens are encrypted at rest using the ATECC608B's AES-128 hardware encryption. Tokens are decrypted only in volatile memory during active API calls.

**OAuth2 flows:** The hub handles OAuth2 authorization code flows for each platform. The user authenticates via the app (which opens a webview to the platform's OAuth page), and the resulting tokens are transmitted to the hub over encrypted MQTT and stored in the ATECC608B.

**Token rotation:** The hub automatically refreshes OAuth2 tokens before expiry. If a token becomes invalid (user revokes, platform changes), the app prompts re-authentication.

### 11.1.2 Camera Stream Security

- RTSP streams from cameras (EZVIZ, Hikvision, generic ONVIF) are proxied through the hub
- The hub terminates the RTSP connection locally and re-streams over an encrypted WebSocket/SRTP tunnel to the app
- Camera RTSP ports are never exposed to the internet or to the PLC network
- Camera credentials stored encrypted on ATECC608B

### 11.1.3 Lock Command Security

All lock commands (TTLock, Sciener, Z-Wave locks, Zigbee locks) require an additional biometric confirmation step in the app:

```
App: User taps "Unlock front door"
  -> App: Biometric prompt (fingerprint/face)
  -> App: Sends authenticated MQTT command with biometric confirmation token
  -> Hub: Verifies token freshness (< 5 seconds) and biometric flag
  -> Hub: Sends command to lock platform (TTLock API / Zigbee / Z-Wave)
  -> Hub: Logs lock event with user ID, timestamp, confirmation method
```

Temporary guest codes (for Airbnb scenarios) bypass biometric but require the property owner to pre-authorize the code via the app with biometric confirmation.

### 11.2 Device Identity and PKI

**Certificate hierarchy:**

```
PowerNode Root CA (offline, HSM-stored)
    |
    +--- PowerNode Intermediate CA (manufacturing server)
              |
              +--- Hub-{serial} certificate (per device)
              +--- Node-{serial} certificate (per device)
```

- **Root CA:** RSA-4096 or ECC P-384. Stored on an HSM (e.g., AWS CloudHSM or Microchip DM320118 dev kit for prototyping). Never touches a network-connected system.
- **Intermediate CA:** ECC P-256. Runs on the manufacturing provisioning station. Signs device certificates.
- **Device certificate:** ECC P-256. Generated on the ATECC608B during manufacturing. The private key is generated inside the ATECC608B and **never leaves the chip**. The CSR (Certificate Signing Request) is extracted, signed by the Intermediate CA, and the resulting certificate is written back to the ATECC608B.

**Provisioning flow (manufacturing):**

```
1. Flash firmware onto device.
2. Device boots into factory mode.
3. ATECC608B generates ECC P-256 key pair internally.
4. Device outputs CSR via USB serial.
5. Manufacturing station signs CSR with Intermediate CA.
6. Certificate is written to ATECC608B key slot.
7. Device serial number, MAC address, and certificate fingerprint are recorded in manufacturing database.
8. Device exits factory mode, enters normal boot.
```

### 11.3 PLC Network Security

HomePlug AV2 provides network-level encryption:

- **NEK (Network Encryption Key):** 128-bit AES key shared by all devices in the AVLN. Used to encrypt all data frames on the power line.
- **NMK (Network Membership Key):** Used during device association. Derived from a user-set password (DAK - Device Access Key) or pushed by the CCo during secure pairing.
- **Key rotation:** The Hub (CCo) generates a new random NEK every 60 minutes and distributes it to all Nodes via encrypted management frames (encrypted with the old NEK during the transition window).

**Pairing flow (adding a new Node):**

```
1. User plugs in new Node. Node boots into provisioning mode (BLE beacon).
2. User opens PowerNode app, taps "Add Device."
3. App discovers Node via BLE, connects.
4. App pushes: WiFi SSID/password, Hub's PLC NMK, user's OAuth2 token.
5. Node connects to Hub via PLC using the NMK.
6. Hub and Node perform ECDH key exchange (using ATECC608B device certs).
7. Hub verifies Node's certificate chain (up to Root CA).
8. Hub issues the current NEK to the Node (encrypted with ECDH-derived key).
9. Node is now a member of the AVLN.
10. App confirms pairing via MQTT.
```

### 11.4 Secure Boot and Flash Encryption

**ESP32-S3 (Hub) and ESP32-C3 (Node) both use:**

- **Secure Boot v2:** The bootloader verifies the firmware signature before executing it. The public key hash is burned into eFuse (one-time programmable). Only firmware signed with the corresponding private key (held by PowerNode's build server) will boot.
- **Flash Encryption (AES-256-XTS):** All flash contents are encrypted. The encryption key is generated by the ESP32 during first boot and stored in eFuse. This prevents reading firmware or NVS data from a desoldered flash chip.
- **JTAG disabled:** JTAG is permanently disabled via eFuse after manufacturing. Debug access requires reflashing the entire chip (which triggers secure boot failure since the attacker does not have the signing key).

### 11.5 Tamper Detection (Hub)

The Hub enclosure includes a case-open switch (microswitch on the DIN-rail enclosure lid):

```
Tamper detection flow:
1. Case-open switch is normally closed (NC) when lid is on.
2. Switch is connected to ESP32-S3 GPIO (interrupt-capable, pull-up).
3. If lid is opened: GPIO goes HIGH, interrupt fires.
4. ESP32-S3 firmware:
   a. Logs tamper event with timestamp to NVS.
   b. Publishes tamper alert to MQTT (to cloud and app).
   c. Optionally: commands ATECC608B to zero sensitive key slots.
   d. Device continues operating (does not brick itself -- that would be a DoS vector).
5. Admin must acknowledge tamper event in app to clear the alert.
```

The tamper response is configurable:
- **Level 1 (default):** Log + alert. No key destruction.
- **Level 2 (high security):** Log + alert + zero PLC NMK in ATECC608B (device must be re-provisioned).
- **Level 3 (maximum):** Log + alert + zero all keys (device is permanently decommissioned, must return to factory).

### 11.6 Network Segmentation

The Hub implements logical network separation on the PLC backbone:

- **Primary network:** All user devices (phones, laptops, smart TVs). Full internet access.
- **Guest network:** Isolated from primary. Internet access only, no LAN access. Separate NEK on PLC, separate SSID on WiFi.
- **IoT network:** For smart home devices (Zigbee, Z-Wave, Matter, Tuya/eWeLink cloud devices). Isolated from primary/guest at the IP layer. Internet access restricted to specific cloud API endpoints (Tuya cloud, eWeLink cloud, TTLock cloud, EZVIZ cloud -- allowlisted). All IoT traffic is routed through the hub's integration layer.

Each logical network uses a separate HomePlug AV2 NEK and a separate WiFi SSID/BSSID on the Nodes. The Hub's lwIP stack enforces inter-network isolation at the IP layer (no routing between subnets).

---

## 12. Portable Identity & Roaming Architecture

### 12.1 Overview

A PowerNode Satellite node is more than a network extender -- it is a **portable network identity**. A user can unplug a Satellite from their home, take it to any location (hotel, office, cowork space, friend's house, retail store), plug it into any outlet, and be transparently connected back to their home network via an encrypted WireGuard VPN tunnel. All traffic from devices connected to the roaming node routes through the home hub -- same IP range, same firewall rules, same DNS, same security posture.

### 12.2 Hardware Security: ATECC608B Certificate Storage

The node's identity is rooted in the ATECC608B hardware security module (already specified in the BOM). At manufacturing, an X.509 certificate is provisioned into the ATECC608B:

- **Certificate type:** ECC P-256, signed by the PowerNode Intermediate CA
- **Private key:** Generated on-chip, never extracted, never leaves the ATECC608B
- **Certificate fields:** Subject CN = `node-{serial}`, SAN = hub serial(s) the node is paired with
- **Storage:** Key slot 0 (private key), slot 1 (certificate), slot 2 (Intermediate CA cert)
- **Rotation:** Certificate rotated annually via OTA (new CSR generated on-chip, signed by cloud-hosted Intermediate CA, new cert written to ATECC608B)

No additional hardware is needed -- the ATECC608B and ESP32-C3 WireGuard capability are already in the design.

### 12.3 Roaming Authentication Protocol

Step-by-step flow when a node is plugged into a remote network:

```
1. NODE: Plugged into remote outlet. Powers on, runs normal boot sequence.
2. NODE: Attempts PLC discovery (sends HomePlug AV2 beacon on L/N wires).
3. NODE: No home hub responds on PLC (different building, different wiring).
         → Node enters ROAMING MODE.
4. NODE: Falls back to internet connectivity:
         a. If PLC detects another PowerNode hub (friend's house): requests
            internet passthrough via that hub's guest network.
         b. If no PLC response: uses any available connectivity
            (Ethernet port, or user connects to node's setup AP via WiFi
             and provides local WiFi credentials).
5. NODE: Once internet-connected, initiates roaming handshake:
         a. Resolves home hub's public endpoint via cloud trust registry
            (hub registers its WAN IP / DDNS address on heartbeat).
         b. Sends TLS 1.3 authentication request to cloud trust registry,
            presenting its X.509 certificate from ATECC608B.
         c. Cloud trust registry validates certificate chain
            (node cert → Intermediate CA → Root CA).
         d. Cloud trust registry returns home hub's current WireGuard
            public key and endpoint (IP:port).
6. HUB:  Receives incoming WireGuard handshake from node.
         a. Hub validates node's WireGuard public key against its
            authorized-nodes list (provisioned during initial pairing).
         b. Hub establishes WireGuard tunnel.
7. TUNNEL ESTABLISHED: Node ↔ Home Hub
         a. Node receives a home-network IP from the hub's DHCP
            (within the normal 192.168.77.x range).
         b. Node sets hub as default gateway for all traffic.
         c. Node's WiFi AP broadcasts the home SSID.
         d. All devices connected to the node's WiFi/Ethernet are
            transparently on the home network.
8. TRAFFIC ROUTING:
         a. All node traffic → WireGuard tunnel → home hub → home ISP.
         b. User's browsing IP = home IP (not hotel/office IP).
         c. User can access all home LAN resources (NAS, printers,
            smart home devices, cameras) as if physically home.
```

### 12.4 Certificate Management

| Event | Process |
|-------|---------|
| Manufacturing | ATECC608B generates key pair. CSR extracted via USB serial. Intermediate CA signs cert. Cert written to ATECC608B. |
| Annual rotation | Hub pushes OTA certificate renewal command. Node generates new key pair on ATECC608B. New CSR sent to cloud CA via encrypted MQTT. New cert written back. Old cert revoked in CRL. |
| Revocation (theft/loss) | Owner marks node as lost in app. Cloud trust registry adds cert to CRL. All hubs pull updated CRL on next heartbeat. Stolen node cannot establish tunnel. |
| Guest mode | Node owner creates a temporary guest certificate (24h/72h/7d expiry) via the app. Guest can roam to this node's hub but with guest-network restrictions (internet only, no LAN access). |

### 12.5 Multi-Hub Trust

If a user owns multiple hubs (e.g., home, vacation rental, office), their node can roam to any of them:

- During initial setup, the node is paired with multiple hubs (each hub's public key is stored on the node).
- When roaming, the node queries the cloud trust registry for the **nearest** hub (by latency, not geography).
- The node auto-connects to the nearest hub for lowest latency.
- User can override in the app (e.g., "always route through home hub even if office hub is closer").

### 12.6 WireGuard Implementation on ESP32

The ESP32-C3 (node) and ESP32-S3 (hub) both run WireGuard in firmware:

- **Library:** WireGuard-ESP32 (open source, MIT licensed, maintained by Kenta Ida)
- **Performance:** ESP32-S3 handles ~30 Mbps WireGuard throughput (sufficient for roaming use cases -- the bottleneck is the upstream internet connection, not the crypto)
- **Key exchange:** Noise_IKpsk2 (WireGuard standard), with the PSK derived from ATECC608B ECDH between node and hub
- **Keepalive:** 25-second persistent keepalive to maintain NAT mappings
- **Reconnection:** Automatic reconnect on tunnel drop, with exponential backoff (1s, 2s, 4s, 8s, max 60s)

### 12.7 Hub-Side: WireGuard Server and Routing

The hub runs a WireGuard server task (see Section 10 firmware updates):

- Listens on a configurable UDP port (default: 51820), forwarded via UPnP/NAT-PMP on the ISP router
- Maintains an authorized-peers list (one entry per paired node)
- When a roaming node connects, the hub:
  1. Assigns a DHCP lease from the home pool
  2. Adds a route for the node's connected clients
  3. NATs all tunnel traffic through the WAN interface (same as local traffic)
  4. Publishes "node roaming" event to MQTT for app notification
- Maximum concurrent roaming tunnels: limited by ESP32-S3 memory (~8 tunnels at 30 Mbps each)

---

## 13. Integrated Remote Desktop (PowerDesk)

### 13.1 Overview

PowerDesk is an integrated remote desktop solution built on the RustDesk protocol (open source, AGPL-3.0 for server / Apache-2.0 for client). The key architectural difference from vanilla RustDesk: **the relay server runs ON the PowerNode hub**, not in the cloud. This eliminates monthly fees, removes third-party data exposure, and leverages the WireGuard tunnel for encrypted transport.

### 13.2 Architecture

```
Remote User                    Internet              Home Network
+----------------+                                  +------------------+
| Phone/Tablet/  |     WireGuard Tunnel             | PowerNode Hub    |
| Laptop running |<================================>| (PowerDesk Relay)|
| PowerDesk      |                                  | - hbbs (signal)  |
| Client         |                                  | - hbbr (relay)   |
+----------------+                                  +--------+---------+
                                                             |
                                                         LAN |
                                                    +--------+---------+
                                                    |   |   |   |     |
                                                   PC  Mac  NAS iPad  ...
                                                   (PowerDesk agents installed)
```

### 13.3 RustDesk Protocol Details

RustDesk uses two server components:

| Component | Function | Port | On Hub |
|-----------|----------|------|--------|
| **hbbs** (signal server) | ID registration, peer discovery, NAT traversal signaling | TCP 21115-21116 | Yes |
| **hbbr** (relay server) | Relays video/input streams when P2P fails | TCP 21117 | Yes |

Since the PowerNode hub and roaming node are already connected via WireGuard tunnel, the relay path is always available and fast:

```
PowerDesk Client (on phone) → Node WiFi → WireGuard Tunnel → Hub → hbbr → LAN → Target PC
```

**No UDP hole punching needed.** The WireGuard tunnel provides a reliable, low-latency path. P2P mode is attempted first (for same-LAN scenarios), but the relay via hub is the expected path for remote access.

### 13.4 Hub Relay Server Implementation

The PowerNode hub runs hbbs and hbbr as lightweight services:

- **Resource usage:** hbbs + hbbr combined use ~15 MB RAM and minimal CPU when idle. During an active session, CPU usage scales with stream resolution.
- **Capacity:** The ESP32-S3 can comfortably relay 1-2 concurrent remote desktop sessions at 1080p/30fps. For more sessions, the hub prioritizes by connection order.
- **Storage:** Session keys and device registry stored in NVS (~4 KB).
- **Auto-start:** hbbs/hbbr start on hub boot, bind to LAN + WireGuard interfaces.

**Note:** If the ESP32-S3 proves insufficient for relay workloads during prototyping, the relay can be moved to a companion process running on a Raspberry Pi or similar on the LAN. The hub would then act only as the signal server (hbbs), with the relay on more capable hardware.

### 13.5 Device Discovery and Approval

The hub discovers potential remote desktop targets on the LAN:

1. **mDNS scan:** Hub broadcasts mDNS queries for `_powerdesk._tcp.local` every 60 seconds.
2. **Target devices** (PCs, Macs, tablets) running the PowerDesk agent respond with their hostname, OS, and PowerDesk ID.
3. **First-time approval:** New devices appear in the PowerNode app as "Discovered -- Pending Approval." The hub owner must explicitly approve each device before remote access is allowed.
4. **Approved devices** are added to the hub's authorized-targets list (stored in NVS).
5. **Connection flow:** PowerDesk client (on phone) → requests connection to target ID via hbbs → hub validates that requesting node is authenticated AND target is approved → hbbr relays the session.

### 13.6 Security Model

| Threat | Mitigation |
|--------|------------|
| Unauthorized remote access to PCs | Each target device must be explicitly approved by hub owner. Only authenticated nodes (valid X.509 cert) can request sessions. |
| Stream interception | All traffic flows through WireGuard tunnel (ChaCha20-Poly1305 encryption). hbbr relay is on LAN, never exposed to internet. |
| Rogue relay server | hbbs/hbbr run only on the hub. PowerDesk clients are hardcoded to connect to the hub's WireGuard IP, not a public relay. |
| Brute-force access | Rate limiting on hbbs: max 5 connection attempts per minute per source. Failed attempts logged and pushed to app. |
| Session persistence after node disconnects | WireGuard tunnel drop immediately terminates all relay sessions. No stale sessions. |

### 13.7 Latency Targets

| Scenario | Expected Latency | Notes |
|----------|-----------------|-------|
| Same LAN (node at home) | < 5ms | P2P direct connection, no relay needed |
| Same city (node at office, hub at home) | 20-40ms | WireGuard tunnel + relay, single ISP hop |
| Same country | 30-60ms | Viable for productivity work (document editing, browsing) |
| International | 80-200ms | Usable but noticeable lag; adequate for file access, not gaming |

Target: < 50ms for same-country connections, which covers the primary use case (accessing home PC from office/hotel within Mexico).

### 13.8 PowerDesk Client

The PowerDesk client is a branded build of the RustDesk client:

- **Platforms:** Android, iOS, Windows, macOS, Linux (RustDesk supports all)
- **Branding:** PowerDesk name, PowerNode color scheme, integrated with PowerNode app (deep link from app to PowerDesk)
- **Configuration:** Pre-configured to use the user's hub as signal/relay server (no manual server setup)
- **Discovery:** Shows only approved devices from the user's hub
- **Authentication:** Uses the same PowerNode account credentials (no separate PowerDesk login)

---

## 14. Mobile App Architecture

### 14.1 Framework and Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| State management | Riverpod |
| Backend | Supabase (auth, database, realtime) |
| MQTT client | mqtt_client (Dart package) |
| BLE | flutter_blue_plus |
| Charts | fl_chart |
| Local storage | Hive (offline cache) |
| Camera streaming | flutter_vlc_player (RTSP proxy) |
| Biometric | local_auth (for lock commands) |

### 14.2 App Screens

```
PowerNode App
├── Property Selector (top bar, persistent)
│   ├── Switch between properties (each property = one hub)
│   ├── "All Properties" aggregated view
│   └── Add new property (pair new hub)
│
├── Onboarding
│   ├── Welcome / product intro
│   ├── Create account (biometric or email)
│   ├── Add first Hub (BLE scan → pair → test)
│   └── Connect integrations (Tuya, eWeLink, TTLock, EZVIZ, etc.)
│
├── Dashboard (home screen, per property)
│   ├── Network status card (internet up/down, speed)
│   ├── Energy summary card (total watts now, today's kWh, cost)
│   ├── Smart home summary card (X devices online, Y alerts)
│   ├── Unified device grid/list (ALL devices regardless of platform)
│   │   └── Device cards with platform icon badge (Tuya/Zigbee/etc.)
│   ├── Favorite scenes (one-tap execution)
│   └── Quick actions (speed test, guest network toggle, arm cameras)
│
├── Smart Home Control
│   ├── Unified device grid (grouped by room)
│   │   ├── Device cards show state + platform badge
│   │   ├── Tap to control (light dimmer, lock toggle, etc.)
│   │   └── Long-press for device detail/settings
│   ├── Camera view
│   │   ├── Live grid (2x2 or fullscreen)
│   │   ├── RTSP proxy through hub (local streaming)
│   │   ├── Cloud fallback for remote viewing
│   │   ├── PTZ controls (EZVIZ/Hikvision)
│   │   └── Motion event timeline
│   ├── Lock control
│   │   ├── Lock/unlock with biometric confirmation
│   │   ├── Temporary guest codes (TTLock)
│   │   ├── Access log (who, when, which code)
│   │   └── Auto-lock schedules
│   ├── Scenes
│   │   ├── Pre-built templates (Leaving, Good Night, etc.)
│   │   ├── Cross-platform scene builder
│   │   └── One-tap execution or automation trigger
│   ├── Automations
│   │   ├── Visual rule builder (IF trigger THEN action)
│   │   ├── Cross-platform triggers and actions
│   │   ├── Time-based conditions
│   │   └── Activity log (automation execution history)
│   └── Integrations settings
│       ├── Connected platforms (Tuya, eWeLink, TTLock, etc.)
│       ├── Add/remove integrations (OAuth flow)
│       ├── Per-integration device list
│       └── Sync status / troubleshoot
│
├── Energy Monitor
│   ├── Per-circuit real-time watts (live updating bars)
│   ├── Circuit detail (tap a circuit → historical chart)
│   │   ├── Today / This week / This month / Custom range
│   │   ├── kWh total + estimated cost (CFE tariff rates)
│   │   └── Anomaly alerts (unusual consumption)
│   ├── Whole-home summary
│   │   ├── Daily/weekly/monthly totals
│   │   ├── Comparison to previous period
│   │   └── CFE bill estimate
│   ├── Multi-property energy comparison (All Properties view)
│   └── Circuit naming (user labels each circuit)
│
├── Breaker Control (Phase 2)
│   ├── Circuit toggle switches (with 2FA flow)
│   ├── Schedules (time-based ON/OFF per circuit)
│   ├── Scenes (e.g., "Away mode" = turn off selected circuits)
│   └── Activity log (who switched what, when)
│
├── Network Management
│   ├── Connected devices list (MAC, IP, hostname, WiFi/Ethernet)
│   ├── Per-device bandwidth usage
│   ├── Parental controls
│   │   ├── Per-device internet schedules
│   │   ├── Content filtering (DNS-based, via NextDNS or similar)
│   │   └── Pause internet per device
│   ├── Guest network (toggle, set password, see connected guests)
│   ├── PLC link quality (per node: SNR, PHY rate, attenuation)
│   ├── WiFi settings (SSID, password, channel, band steering)
│   └── Speed test (from Hub WAN port)
│
├── Devices (PowerNode hardware)
│   ├── Hub status (firmware version, uptime, temperature)
│   ├── Node list (with signal strength, firmware, connected clients)
│   ├── Add new Node (BLE provisioning flow)
│   └── Remove device
│
├── Alerts
│   ├── Over-current warnings
│   ├── Unusual consumption patterns
│   ├── Device offline notifications (PLC nodes + smart home devices)
│   ├── Camera motion/person detection alerts
│   ├── Lock activity alerts (unexpected unlock, failed attempts)
│   ├── Firmware update available
│   └── Tamper alerts
│
└── Settings
    ├── Account management
    ├── Property management (add/rename/remove properties)
    ├── Per-property integration settings (which platforms active)
    ├── Per-property room configuration (which devices in which rooms)
    ├── CFE tariff configuration (for cost estimation)
    ├── Notification preferences
    ├── LED brightness / night mode schedule
    ├── Advanced (DNS, DHCP range, port forwarding)
    └── About / Support
```

### 14.3 Real-Time Data Flow

```
Hub metering_task
    | (1-second interval)
    v
MQTT publish: powernode/{hub_id}/meter/{circuit_id}
    | payload: {"watts": 1247.3, "irms": 9.82, "kwh_today": 14.7, "ts": 1711100400}
    v
MQTT broker (Hub local)
    |
    +---> App (LAN mode): mqtt_client subscribes, updates Riverpod state
    |
    +---> Cloud MQTT bridge --> Supabase Realtime (for remote access)
                                    |
                                    v
                               App (remote mode): Supabase Realtime subscription
```

The app prefers LAN-mode MQTT (direct connection to Hub on 192.168.77.1:1883) for lowest latency. When the app detects it is on a different network (e.g., cellular), it falls back to cloud MQTT.

### 14.4 Offline Capability

The app caches the last 24 hours of energy data locally (Hive database). If the cloud connection is lost, the app can still display recent data and control devices via LAN MQTT (if on the same network). When connectivity is restored, the Hub syncs buffered data to the cloud.

### 14.5 CFE Tariff Integration

The app includes configurable CFE (Comision Federal de Electricidad) tariff rates for accurate cost estimation:

- **Tariff 1 (residential, < 150 kWh/month):** Basic, intermediate, excess tiers
- **Tariff 1A-1F (regional):** Adjusted by climate zone
- **DAC (high consumption):** Flat commercial rate

The user selects their tariff (or the app infers it from location + consumption), and the Energy Monitor shows estimated cost alongside kWh readings. This is informational only, not a billing replacement.

---

## 15. Bill of Materials (Detailed)

### 15.1 Hub BOM

| # | Component | Part Number | Description | Qty | Unit Cost (USD) | Extended (USD) |
|---|-----------|-------------|-------------|-----|-----------------|----------------|
| 1 | MCU | ESP32-S3-WROOM-1-N16R8 | Dual-core 240MHz, 16MB flash, 8MB PSRAM | 1 | $4.00 | $4.00 |
| 2 | PLC modem | QCA7006-AL3B | HomePlug AV2, QFN-64 | 1 | $15.00 | $15.00 |
| 3 | Ethernet PHY | LAN8720A-CP-TR | 10/100 RMII, QFN-24 | 2 | $1.50 | $3.00 |
| 4 | RJ45 jack | HR911105A | 10/100 w/ integrated magnetics | 2 | $0.50 | $1.00 |
| 5 | CT clamp | SCT-013-020 | 20A split-core, 1V output | 12 | $3.00 | $36.00 |
| 6 | ADC | ADS1115IDGSR | 16-bit, 4-ch, I2C, MSOP-10 | 3 | $2.50 | $7.50 |
| 7 | Crypto/secure element | ATECC608B-TNGLOAS | ECC P-256, I2C, UDFN-8 | 1 | $0.80 | $0.80 |
| 8 | DIN-rail PSU | Mean Well HDR-15-12 | 85-264VAC to 12V/1.25A | 1 | $8.00 | $8.00 |
| 9 | LDO 3.3V | AP2112K-3.3TRG1 | 600mA, SOT-23-5 | 1 | $0.30 | $0.30 |
| 10 | LDO 1.8V | AP2112K-1.8TRG1 | 600mA, SOT-23-5 | 1 | $0.30 | $0.30 |
| 11 | PLC coupling transformer | Coilcraft WBC4-1WL | 1:1, 2-100MHz, toroidal | 1 | $1.50 | $1.50 |
| 12 | X2 safety cap | KEMET R46KN310000P1M | 100nF, 275VAC, X2 | 2 | $0.25 | $0.50 |
| 13 | DC blocking caps | Ceramic 10nF 250V | X7R, 0805 | 2 | $0.05 | $0.10 |
| 14 | TVS diode | SMBJ150CA | Bidirectional, 150V, SMB | 1 | $0.30 | $0.30 |
| 15 | Watchdog IC | MAX6369KA29-T | 1.6s timeout, SOT-23-5 | 1 | $1.00 | $1.00 |
| 16 | Tamper switch | Omron D2F-01F | Microswitch, SPDT | 1 | $0.50 | $0.50 |
| 17 | Confirm button | Tactile switch 6x6mm | Through-hole, momentary | 1 | $0.10 | $0.10 |
| 18 | Status LEDs | Green/Red/Blue/Yellow 0603 | SMD | 4 | $0.05 | $0.20 |
| 19 | CT headers | Molex KK 254, 2-pin | Locking, THT, 2.54mm | 12 | $0.15 | $1.80 |
| 20 | Decoupling caps | 100nF + 10uF assorted | Ceramic + tantalum | 30 | $0.03 | $0.90 |
| 21 | Resistors | Assorted, 0402/0603 | Various values | 50 | $0.01 | $0.50 |
| 22 | Crystal | 25MHz, 20ppm | For QCA7006, HC-49S | 1 | $0.20 | $0.20 |
| 23 | Crystal | 50MHz, 20ppm | For LAN8720A, HC-49S | 1 | $0.20 | $0.20 |
| 24 | **Zigbee coordinator** | **CC2652P** | **Zigbee 3.0 + Thread, UART, w/ +20dBm PA** | 1 | **$8.00** | **$8.00** |
| 25 | **Thread border router** | **nRF52840 module (optional)** | **Thread/Matter, UART, if CC2652P insufficient** | 1 | **$5.00** | **$5.00** |
| 26 | **IR LED + receiver** | **TSAL6200 + TSOP38238** | **IR blaster TX + IR learn RX** | 1 | **$1.00** | **$1.00** |
| 27 | **433MHz TX module** | **STX882** | **433MHz ASK transmitter for RF legacy** | 1 | **$2.00** | **$2.00** |
| 28 | **USB-A connector** | **Molex 67643-0910** | **USB-A host port for Z-Wave stick** | 1 | **$0.50** | **$0.50** |
| 29 | PCB | 4-layer, 110x85mm | ENIG finish, 1.6mm, FR-4 (slightly larger for new components) | 1 | $6.00 | $6.00 |
| 30 | DIN-rail enclosure | Phoenix Contact ME series | 7 modules, ABS+PC, rail mount (wider for USB-A + IR window) | 1 | $7.00 | $7.00 |
| 31 | Cable grommet | M20, IP68 | For CT clamp cables | 1 | $0.30 | $0.30 |
| 32 | IR-transparent window | Polycarbonate, 940nm pass | Front panel IR window insert | 1 | $0.20 | $0.20 |
| 33 | SMT assembly | JLCPCB turnkey | Including solder paste, reflow | 1 | $10.00 | $10.00 |
| 34 | THT assembly | Manual | CT headers, RJ45, switches, USB-A | 1 | $3.00 | $3.00 |
| | **Hub Total** | | | | | **$126.70** |

**Note:** BOM costs are estimated at 100-unit prototype quantities. Volume pricing (10K+) would reduce total by approximately 25-35%. The Z-Wave USB stick (Silicon Labs UZB-7, ~$35) is sold separately as an optional accessory.

### 15.2 Node BOM

| # | Component | Part Number | Description | Qty | Unit Cost (USD) | Extended (USD) |
|---|-----------|-------------|-------------|-----|-----------------|----------------|
| 1 | PLC modem | QCA7006-AL3B | HomePlug AV2, QFN-64 | 1 | $15.00 | $15.00 |
| 2 | WiFi SoC | MT7921AUN | WiFi 6 2x2, QFN | 1 | $12.00 | $12.00 |
| 3 | MCU | ESP32-C3-MINI-1-N4 | RISC-V, 4MB flash, BLE 5.0 | 1 | $2.00 | $2.00 |
| 4 | Ethernet PHY | RTL8211FI-CG | GbE, RGMII, QFN-48 | 1 | $2.00 | $2.00 |
| 5 | RJ45 jack | HR911105A | 10/100/1000 w/ magnetics | 1 | $0.50 | $0.50 |
| 6 | Crypto/secure element | ATECC608B-TNGLOAS | ECC P-256, I2C, UDFN-8 | 1 | $0.80 | $0.80 |
| 7 | LED driver | WS2812B-2020 | Addressable RGB, 2x2mm | 8 | $0.08 | $0.64 |
| 8 | Flyback controller | TNY290PG | 10W, 85-265VAC input, DIP-8 | 1 | $0.80 | $0.80 |
| 9 | Flyback transformer | Custom wound | EE16, 127V:5V, 2A | 1 | $1.50 | $1.50 |
| 10 | Buck converter | TPS563200DDCR | 5V to 3.3V, 3A, SOT-23-6 | 1 | $1.00 | $1.00 |
| 11 | LDO 1.8V | AP2112K-1.8TRG1 | 600mA, SOT-23-5 | 1 | $0.30 | $0.30 |
| 12 | USB-C PD sink | STUSB4500QTR | USB PD 3.0, QFN-24 | 1 | $1.50 | $1.50 |
| 13 | USB-C connector | GCT USB4110-GF-A | 16-pin, mid-mount | 1 | $0.50 | $0.50 |
| 14 | PLC coupling transformer | Coilcraft WBC4-1WL | 1:1, 2-100MHz | 1 | $1.50 | $1.50 |
| 15 | X2 safety cap | KEMET R46KN310000P1M | 100nF, 275VAC | 2 | $0.25 | $0.50 |
| 16 | Bridge rectifier | MB6S | 600V, 0.5A, SOIC-4 | 1 | $0.10 | $0.10 |
| 17 | EMI filter | Common-mode choke + Y caps | Through-hole | 1 | $0.80 | $0.80 |
| 18 | Output capacitors | Electrolytic 470uF/10V | For SMPS output | 2 | $0.15 | $0.30 |
| 19 | Decoupling caps | 100nF + 10uF assorted | Ceramic + tantalum | 25 | $0.03 | $0.75 |
| 20 | Resistors | Assorted, 0402/0603 | Various values | 40 | $0.01 | $0.40 |
| 21 | Crystals | 25MHz + 40MHz, 20ppm | QCA7006 + MT7921 | 2 | $0.20 | $0.40 |
| 22 | PCB antenna (2.4GHz) | PCB trace, inverted-F | Etched on PCB | 1 | $0.00 | $0.00 |
| 23 | PCB antenna (5GHz) | PCB trace, inverted-F | Etched on PCB | 1 | $0.00 | $0.00 |
| 24 | Antenna matching | PI network (L+2C) | 0402 components | 2 | $0.10 | $0.20 |
| 25 | AC plug prongs | NEMA 1-15 blades | Brass, with spring contacts | 1 | $0.30 | $0.30 |
| 26 | Pass-through outlet | NEMA 1-15 receptacle | Integrated, rated 15A | 1 | $0.50 | $0.50 |
| 27 | PCB | 4-layer, 60x45mm | ENIG, 1.6mm, FR-4 | 1 | $3.00 | $3.00 |
| 28 | Enclosure | Custom wall-plug housing | ABS+PC, UL94 V-0, 2-piece | 1 | $4.00 | $4.00 |
| 29 | Thermal pad | Copper spreader, 0.5mm | For MT7921 + QCA7006 | 1 | $0.50 | $0.50 |
| 30 | SMT assembly | JLCPCB turnkey | Including reflow | 1 | $8.00 | $8.00 |
| | **Node Total** | | | | | **$59.29** |

### 15.3 System Pricing

| Configuration | Component Cost | Target Retail | Gross Margin |
|---------------|---------------|---------------|-------------|
| Hub only (smart home hub + PLC coordinator) | $126.70 | $249 | 49.1% |
| Node only | $59.29 | $99 | 40.1% |
| 1 Hub + 4 Nodes (typical home) | $363.86 | $649 | 43.9% |
| 1 Hub + 2 Nodes (small apartment) | $245.28 | $449 | 45.4% |
| Extra CT clamp (12-pack) | $36.00 | $79 | 54.4% |
| Z-Wave USB stick (optional) | $35.00 | $59 | 40.7% |

**Volume pricing estimates (10K units):**

| Item | Prototype (100 qty) | Volume (10K qty) | Reduction |
|------|---------------------|-------------------|-----------|
| Hub | $126.70 | $88.00 | -31% |
| Node | $59.29 | $41.00 | -31% |
| System (1+4) | $363.86 | $252.00 | -31% |

At volume pricing, the 1+4 system cost drops to ~$252, providing a 61.2% gross margin at $649 retail, or enabling a lower $499 price point at 49.5% margin.

---

## 16. Regulatory and Certification

### 16.1 Mexican Market (Primary)

| Standard | Scope | Applies To | Timeline | Estimated Cost |
|----------|-------|-----------|----------|----------------|
| NOM-001-SEDE-2012 | Electrical installations | Hub (panel mount), Phase 2 breaker control | Design phase | $0 (compliance by design) |
| NOM-019-SCFI-2016 | Electrical safety, consumer electronics | Hub + Node (power supplies, enclosures) | Pre-production | $8,000--15,000 |
| NOM-208-SCFI-2016 | Telecom equipment (RF emissions, PLC) | Hub + Node (PLC modem, WiFi) | Pre-production | $10,000--20,000 |
| IFT Type Approval | Conducted emissions, PLC in 2-86 MHz | Hub + Node (PLC subsystem) | Pre-production | $5,000--10,000 |
| NOM-024-SCFI-2013 | Commercial information (labeling) | Product packaging and device labels | Pre-production | $500 |

**Total estimated regulatory cost (Mexico): $23,500--$45,500**

**IFT (Instituto Federal de Telecomunicaciones) considerations:**
- PLC devices in Mexico must not interfere with licensed radio services. The HomePlug AV2 standard's built-in notching of amateur radio bands satisfies this requirement.
- The WiFi radio (MT7921) operates in unlicensed ISM bands (2.4 GHz and 5 GHz). Standard IFT approval for WiFi is well-established.
- PLC in the 2--86 MHz band is less common in Mexico. IFT may require additional documentation showing compliance with conducted emission limits. The QCA7006's output power (~-50 dBm/Hz) is within HomePlug AV2 specification, which aligns with international limits (EN 50561-1 in Europe, FCC Part 15 Subpart G in the US).

### 16.2 US Market (Future)

| Standard | Scope | Applies To |
|----------|-------|-----------|
| FCC Part 15 Subpart B | Unintentional radiator | Hub + Node |
| FCC Part 15 Subpart G | Access Broadband over Power Line (BPL) | PLC subsystem |
| UL 62368-1 | Audio/video, IT, and communications equipment safety | Hub + Node |
| Wi-Fi Alliance | WiFi 6 interoperability | Node (WiFi) |
| HomePlug Alliance | HomePlug AV2 certification | Hub + Node (PLC) |

**FCC Part 15 Subpart G** is the relevant regulation for PLC devices in the US. Key requirements:
- Conducted emissions on power line: < 30 dBuV/m below 30 MHz.
- Must not cause harmful interference to licensed services.
- Must accept interference from other devices.
- The HomePlug AV2 standard was designed to comply with these limits.

### 16.3 Certification Strategy

1. **Design for compliance from day one.** Use certified modules (ESP32-S3-WROOM-1 is pre-certified for WiFi/BLE in most markets). This eliminates the need for intentional radiator testing on the WiFi/BLE subsystem.
2. **Use a NRTL (Nationally Recognized Testing Laboratory)** for safety testing. UL, CSA, or TUV. Get pre-compliance testing done before formal submission.
3. **Start NOM process in parallel with prototype validation** (Month 4 of prototype plan). NOM certification can take 3--6 months.
4. **Budget 6--12 months and $25,000--$50,000** for full Mexican market certification.
5. **Defer US market certification** until Mexican market validates the product.

---

## 17. Prototype Plan

### 17.1 Timeline Overview

| Month | Milestone | Deliverables |
|-------|-----------|-------------|
| 1 | Schematic + BOM | KiCad schematics (Hub + Node), BOM finalized, components ordered |
| 2 | PCB layout + order | KiCad PCB layouts, Gerbers submitted to JLCPCB, stencils ordered |
| 3 | Board bring-up: PLC | Assembled boards, QCA7006 basic link (ping between Hub and Node), ESP32 firmware skeleton |
| 4 | WiFi + metering | MT7921 SDIO driver working, WiFi AP serving clients, CT clamp metering calibrated |
| 5 | Security + app MVP | ATECC608B provisioning, secure boot enabled, Flutter app with BLE pairing + live dashboard |
| 6 | Field test | Deployed at BC's rental properties in Puerto Vallarta, real-world performance data |

### 17.2 Month 1: Schematic Capture and Component Sourcing

**Tools:** KiCad 8.0 (open source EDA)

**Hub schematic blocks:**
1. ESP32-S3-WROOM-1 (module footprint, power decoupling, UART/USB programming header)
2. QCA7006 (reference design from Qualcomm, SPI interface to ESP32, coupling circuit)
3. LAN8720A x 2 (RMII interface to ESP32, RJ45 jacks with magnetics)
4. ADS1115 x 6 (I2C buses, CT clamp input headers, bias voltage dividers)
5. ATECC608B (I2C, pull-ups)
6. Power section (HDR-15-12 DIN-rail PSU connection, LDOs, decoupling)
7. GPIO expansion (LEDs, tamper switch, confirm button, SSR headers for Phase 2)

**Node schematic blocks:**
1. ESP32-C3-MINI-1 (module footprint, power, SPI to QCA7006, SDIO to MT7921)
2. QCA7006 (SPI + RGMII interfaces, coupling circuit)
3. MT7921 (SDIO interface, PCB antenna matching networks, RGMII to QCA7006/RTL8211F)
4. RTL8211F (RGMII to QCA7006, RJ45 jack)
5. ATECC608B (I2C)
6. Power section (flyback converter, buck converter, LDO, USB-C PD)
7. LED ring (WS2812B x 8, data line from ESP32-C3 GPIO)

**Component sourcing:**
- Primary: LCSC Electronics (for JLCPCB assembly compatibility)
- Secondary: Mouser, DigiKey (for parts not available on LCSC)
- Long-lead items to order immediately: QCA7006 (4-6 week lead time), MT7921 (4-6 weeks), custom flyback transformer (3-4 weeks)

### 17.3 Month 2: PCB Layout

**Hub PCB:**
- 4-layer stackup, 100 x 80 mm
- Critical routing: QCA7006 differential pairs (100 ohm), RMII buses (50 ohm, length-matched), PLC coupling traces (short, wide, away from digital)
- Design rules: 0.15mm trace/space (standard 4-layer), 0.3mm vias, 0.5mm BGA pitch (QCA7006)
- DRC + ERC in KiCad before Gerber export

**Node PCB:**
- 4-layer stackup, 60 x 45 mm
- Critical routing: SDIO bus (50 ohm, length-matched within 3mm), RGMII bus (50 ohm, length-matched within 5mm), antenna keep-out zones
- AC safety: Creepage/clearance distances per IEC 60950-1 between mains and low-voltage sections (5.5mm minimum at 127V)

**Order:**
- JLCPCB 4-layer PCBs: 10 pieces each (Hub + Node), ENIG finish
- SMT stencils: 1 each (top side)
- Turnaround: 7--10 days for PCB, 2--3 days for stencil

### 17.4 Month 3: PLC Bring-Up

**Objective:** Establish a working PLC link between Hub and Node prototype boards.

**Steps:**
1. Reflow solder ESP32 + QCA7006 sections (hot air rework station or reflow oven).
2. Power up Hub board, verify voltage rails (12V, 3.3V, 1.8V).
3. Flash ESP32-S3 with minimal firmware (UART console, SPI initialization).
4. Initialize QCA7006 via SPI: load firmware, configure as CCo.
5. Repeat for Node board: ESP32-C3 + QCA7006, configure as STA.
6. Connect both boards to AC mains via coupling circuits (use isolation transformer for safety during development).
7. Verify PLC link: QCA7006 association, beacon exchange, basic ping.
8. Measure link parameters: SNR per subcarrier, PHY rate, latency.
9. Run iperf through PLC link to measure TCP throughput.

**Expected outcome:** PLC link established, 200+ Mbps TCP throughput on bench test (short wiring run).

### 17.5 Month 4: WiFi and Metering Integration

**WiFi bring-up:**
1. Solder MT7921 onto Node board.
2. Flash MT7921 firmware (vendor-provided binary) via SPI flash connected to MT7921.
3. Initialize SDIO interface between ESP32-C3 and MT7921.
4. Configure MT7921 as WiFi AP (2.4 GHz + 5 GHz, WPA3-Personal).
5. Bridge WiFi clients to PLC backbone: phone connects to Node WiFi AP, traffic flows through PLC to Hub, Hub NATs to WAN.
6. Run speed test from phone through full path (WiFi -> PLC -> WAN).

**Metering bring-up:**
1. Solder ADS1115 chips and CT clamp headers onto Hub board.
2. Wire 3--4 CT clamps onto a test bench with known loads (100W, 500W, 1000W, 2000W).
3. Read ADC values, compute RMS, compare to reference meter (Kill-A-Watt or similar).
4. Compute calibration factors per channel.
5. Verify +/-2% accuracy across 0.5--20A range.
6. Implement 1-second MQTT publishing from Hub.

### 17.6 Month 5: Security Stack and App MVP

**Security stack:**
1. Provision ATECC608B chips (generate key pairs, sign certificates with test CA).
2. Enable ESP32 secure boot v2 (burn public key hash to eFuse on prototype boards).
3. Enable flash encryption (AES-256-XTS).
4. Implement TLS 1.3 for MQTT (using ATECC608B for client certificate).
5. Implement PLC NEK rotation (hourly, distributed by Hub CCo).

**Flutter app MVP:**
1. BLE scanning and device discovery.
2. BLE provisioning flow (push WiFi creds + PLC NMK to new Node).
3. MQTT connection to Hub (LAN mode).
4. Real-time energy dashboard (per-circuit watts, bar chart).
5. Device list (Hub + Nodes, basic status).
6. Settings page (SSID, password, circuit naming).

### 17.7 Month 6: Field Test

**Location:** BC's rental properties in Puerto Vallarta.

**Test scenarios:**

| Test | Location | Expected Result | Pass Criteria |
|------|----------|----------------|---------------|
| PLC range (same phase) | Hub at panel, Node in farthest room | Link established | > 100 Mbps TCP |
| PLC through GFCI | Node in bathroom (GFCI outlet) | Link established, reduced throughput | > 50 Mbps TCP |
| WiFi coverage | 4 Nodes, walk full property with phone | Seamless roaming | > 50 Mbps everywhere |
| Metering accuracy | 12 CT clamps on main circuits | Readings within +/-2% | Compare to CFE meter |
| Multi-day stability | Run for 7 days continuous | No crashes, no data loss | 100% uptime, data integrity |
| Heat soak | Monitor device temperatures | Within operating range | < 70C on all ICs |
| Interference | Run blender, vacuum, AC compressor | PLC degrades gracefully | No disconnection, > 50 Mbps |

**Data collected:**
- PLC link quality logs (SNR, PHY rate, packet error rate) -- 24/7 for 7 days.
- Energy metering data -- compared against CFE bill at end of month.
- WiFi roaming events -- latency during handoff between Nodes.
- Thermal data -- ambient + IC temperatures via on-chip sensors.
- Crash logs -- any ESP32 panics, watchdog resets, or QCA7006 link drops.

---

## 18. Risk Matrix

| # | Risk | Impact | Likelihood | Severity (I x L) | Mitigation | Contingency |
|---|------|--------|------------|-------------------|------------|-------------|
| 1 | QCA7006 NDA/SDK access denied or delayed | Cannot develop PLC subsystem | Medium | **Critical** | Apply to Qualcomm early (Month 0). Use distribution partner (e.g., Rutronik) for faster NDA process. | Switch to Broadcom BCM60500 (HomePlug AV2) or MaxLinear G.hn chipset. Add 2-month delay. |
| 2 | Mexican wiring quality degrades PLC throughput below usable levels | Product does not meet performance claims | Medium | **High** | Extensive field testing (Month 6) across different property ages and types. Adaptive modulation in QCA7006 handles poor wiring. | Add mesh WiFi fallback mode: Nodes can relay to each other via WiFi if PLC link is too degraded. |
| 3 | CFE regulatory pushback on PLC emissions | Cannot legally sell product | Low | **High** | Design within HomePlug AV2 emission limits (which comply with international standards). Engage IFT early with pre-compliance test data. | Limit PLC frequency range to 2--30 MHz (lower emissions, lower throughput ~200 Mbps PHY). |
| 4 | NOM certification timeline exceeds 12 months | Delayed market entry | High | **Medium** | Start NOM process in Month 4 (parallel with prototyping). Use certified modules (ESP32 pre-certified) to reduce scope. Budget 6--12 months. | Soft launch with B2B (installer channel) while certification is in process. Residential sale requires NOM. |
| 5 | Breaker control safety liability | Lawsuit or regulatory action if switching causes fire/damage | Low | **Critical** | Phase 1 = monitor only. Phase 2 requires NOM-001 compliance, licensed electrician install, hardware watchdog, 2FA, rate limiting. Professional liability insurance. | Permanently defer breaker control if risk is deemed unacceptable. Product is still viable as network + metering platform. |
| 6 | MT7921 SDIO driver complexity on ESP32-C3 | Node WiFi integration fails or is unstable | Medium | **Medium** | Use Option A architecture (QCA7006 internal switch handles data path, ESP32-C3 only manages). Reference existing open-source MT7921 Linux drivers for SDIO protocol. | Replace MT7921 with RTL8852AE (WiFi 6, SDIO, better documented) or use a Linux SoC (Allwinner T113-S3) that has mainline MT7921 driver support. |
| 7 | Component supply chain disruption (QCA7006, MT7921) | Cannot build product | Medium | **Medium** | Dual-source where possible. Maintain 6-month component buffer at scale. Identify alternate PLC chipset. | Broadcom BCM60500 as PLC alternate. RTL8852AE as WiFi alternate. Both require board respin but pin-compatibility is not required (different module footprint acceptable). |
| 8 | PLC signal crosses transformer to neighbor's house | Security/privacy concern, potential regulatory issue | Low | **Low** | HomePlug AV2 AES-128 encryption prevents data interception even if signal leaks. Signal attenuation through distribution transformer is typically > 40 dB (effectively eliminates leakage). | Add "private network" mode: Hub checks for unexpected PLC responses and alerts user. Increase transmit power control to minimize unnecessary signal level. |
| 9 | Consumer price sensitivity in Mexican market | $649 is too expensive for target market | Medium | **Medium** | Volume pricing reduces BOM to ~$252 enabling $499 price point. Emphasize energy savings payback + smart home consolidation value (replace 5+ apps and 3+ hubs with one device). | Offer Hub-only product at $249 (smart home + metering, no WiFi nodes). Sell Nodes separately at $99 each. Subscription model for cloud features. |
| 10 | Competitor launches similar product in Mexico before PowerNode | Lost first-mover advantage | Low | **Low** | No current PLC + metering + unified smart home product exists for the Mexican market. Execution speed is the defense. | Differentiate on app quality (Flutter, beautiful UX), local support, CFE tariff integration, Chinese platform support (Tuya, eWeLink), and PLC networking. |
| 11 | **Third-party API changes/deprecation** | Integration breaks, devices become uncontrollable | **High** | **High** | Abstract all integrations behind device model. Use versioned API clients. Monitor API changelogs. Maintain local protocol fallbacks (Zigbee/Matter direct control). | If cloud API dies, migrate affected devices to local protocol (many Tuya devices support Zigbee, eWeLink devices support Matter). Community-maintained API libraries (python-tuya, etc.) as fallback. |
| 12 | **Tuya/eWeLink rate limiting or API access restrictions** | Cannot poll device state frequently enough, or API access revoked | **Medium** | **High** | Use official developer programs (Tuya IoT Platform, eWeLink developer). Optimize polling intervals. Use push notifications (Tuya MQTT) where available. Cache state aggressively. | Move affected devices to local control (Tuya local key extraction, LAN-mode control). Zigbee pairing for devices that support it. |
| 13 | **Camera RTSP compatibility across brands** | Some cameras do not expose RTSP or use non-standard implementations | **Medium** | **Medium** | Focus on EZVIZ/Hikvision (well-documented RTSP). Use ONVIF discovery for generic cameras. Test top 10 camera brands during prototype phase. | Fall back to cloud-only viewing (EZVIZ app SDK) for incompatible cameras. Support ONVIF Profile S as baseline. |
| 14 | **Integration maintenance burden (N platforms x M device types)** | Engineering time consumed by keeping integrations working rather than building new features | **High** | **High** | Use abstract device model so new platforms only need a thin adapter. Prioritize platforms by user demand (Tuya first, then eWeLink, then TTLock, etc.). Community plugins in future. | Limit to top 5 platforms at launch. Add new integrations based on user requests only. Consider Home Assistant integration bridge as a catch-all fallback. |
| 15 | **Roaming node stolen/lost** | Attacker possesses authenticated device that can tunnel into home network | **Medium** | **High** | Instant revocation via app (cert added to CRL, all hubs reject within 1 heartbeat cycle). WireGuard keys rotated on revocation. Node has no cached credentials after power loss (keys in ATECC608B but tunnel requires live handshake with hub). | Remote wipe command zeroizes ATECC608B key slots. Device becomes inert hardware. |
| 16 | **Cloud trust registry outage** | Roaming nodes cannot resolve home hub endpoint | **Medium** | **Medium** | Hub endpoint can also be resolved via DDNS fallback (node stores hub's DDNS hostname). Local cache of last-known endpoint on node (valid for 24h). | Direct IP mode: user can manually configure hub's IP in node settings for registry-free operation. |
| 17 | **ESP32-S3 insufficient for PowerDesk relay** | Hub cannot handle video relay at acceptable quality/latency | **Medium** | **Medium** | Test during prototype phase. Limit to 1080p/30fps, 1-2 concurrent sessions. Optimize frame encoding. | Offload relay to companion device (Raspberry Pi or similar on LAN). Hub acts as signal server only (hbbs), relay on more capable hardware. |
| 18 | **WireGuard throughput limitation on ESP32** | Roaming tunnel bottleneck below user expectations (~30 Mbps) | **Low** | **Low** | 30 Mbps is sufficient for typical roaming use cases (browsing, email, remote desktop). ISP upload speed is usually the real bottleneck. | Document expected roaming throughput. If market demands more, move to Linux-based hub SoC in v2. |

### 18.1 Risk Response Summary

- **Accept:** Risks #8, #10, #13, #18 (low/medium severity, monitoring only)
- **Mitigate:** Risks #1, #2, #3, #4, #6, #7, #9, #11, #12, #14, #15, #16, #17 (active mitigation plans above)
- **Avoid:** Risk #5 (breaker control deferred to Phase 2, monitor-only in v1.0)

---

## Appendix A: Pin Assignments

### A.1 ESP32-S3 (Hub) Pin Map

| GPIO | Function | Connected To |
|------|----------|-------------|
| 0 | Boot button | Pull-up, grounded for flash mode |
| 1 | I2C0 SDA | ADS1115 #1--#4, ATECC608B |
| 2 | I2C0 SCL | ADS1115 #1--#4, ATECC608B |
| 3 | I2C1 SDA | ADS1115 #5--#6 |
| 4 | I2C1 SCL | ADS1115 #5--#6 |
| 10 | SPI2 MOSI | QCA7006 SPI |
| 11 | SPI2 MISO | QCA7006 SPI |
| 12 | SPI2 SCLK | QCA7006 SPI |
| 13 | SPI2 CS | QCA7006 SPI |
| 14 | QCA7006 INT | QCA7006 interrupt (active low) |
| 15 | QCA7006 RESET | QCA7006 reset (active low) |
| 18 | EMAC_TXD0 | LAN8720A #1 (WAN) RMII |
| 19 | EMAC_TXD1 | LAN8720A #1 (WAN) RMII |
| 20 | EMAC_TX_EN | LAN8720A #1 (WAN) RMII |
| 21 | EMAC_RXD0 | LAN8720A #1 (WAN) RMII |
| 38 | EMAC_RXD1 | LAN8720A #1 (WAN) RMII |
| 39 | EMAC_CRS_DV | LAN8720A #1 (WAN) RMII |
| 40 | EMAC_REF_CLK | LAN8720A #1 (WAN) 50MHz clock |
| 41 | EMAC_MDC | LAN8720A #1 + #2 MDIO clock |
| 42 | EMAC_MDIO | LAN8720A #1 + #2 MDIO data |
| 5 | LED_POWER | Green LED (power on) |
| 6 | LED_PLC | Blue LED (PLC link active) |
| 7 | LED_NET | Green LED (internet connected) |
| 8 | LED_ERR | Red LED (error state) |
| 9 | TAMPER_SW | Case-open microswitch (active high, pull-down) |
| 16 | CONFIRM_BTN | Physical confirm button (active low, pull-up) |
| 17 | WATCHDOG_FEED | MAX6369 WDI input |
| 35--37 | SSR_BANK_0 | Shift register data/clock/latch for SSR GPIO expansion (Phase 2) |
| 43 | UART0 TX | USB-UART (CP2102, programming/debug) |
| 44 | UART0 RX | USB-UART (CP2102, programming/debug) |

### A.2 ESP32-C3 (Node) Pin Map

| GPIO | Function | Connected To |
|------|----------|-------------|
| 0 | Boot button | Pull-up |
| 1 | SPI MOSI | QCA7006 SPI |
| 2 | SPI MISO | QCA7006 SPI |
| 3 | SPI SCLK | QCA7006 SPI |
| 4 | SPI CS | QCA7006 SPI |
| 5 | QCA7006 INT | QCA7006 interrupt |
| 6 | QCA7006 RESET | QCA7006 reset |
| 7 | I2C SDA | ATECC608B |
| 8 | I2C SCL | ATECC608B |
| 9 | WS2812B DATA | LED ring data in |
| 10 | SDIO CMD | MT7921 SDIO |
| 18 | SDIO CLK | MT7921 SDIO |
| 19 | SDIO D0 | MT7921 SDIO |
| 20 | UART0 RX | USB-C (debug/provisioning) |
| 21 | UART0 TX | USB-C (debug/provisioning) |

---

## Appendix B: MQTT Topic Schema

```
powernode/
├── {hub_id}/
│   ├── status                    # Hub status (JSON)
│   │   payload: {
│   │     "online": true,
│   │     "uptime_s": 86400,
│   │     "firmware": "1.0.3",
│   │     "temp_c": 42.5,
│   │     "wan_ip": "189.203.x.x",
│   │     "plc_nodes": 6,
│   │     "smarthome_devices": 47,
│   │     "integrations_active": ["tuya", "zigbee", "ttlock", "ezviz"]
│   │   }
│   │
│   ├── meter/
│   │   ├── {circuit_id}          # Per-circuit metering (1s interval)
│   │   │   payload: {
│   │   │     "watts": 1247.3,
│   │   │     "irms": 9.82,
│   │   │     "vrms": 126.8,
│   │   │     "pf": 0.95,
│   │   │     "kwh_today": 14.7,
│   │   │     "ts": 1711100400
│   │   │   }
│   │   └── summary               # Whole-home summary (1s interval)
│   │       payload: {
│   │         "total_watts": 3847.2,
│   │         "kwh_today": 42.1,
│   │         "cost_today_mxn": 84.20,
│   │         "circuits_active": 18,
│   │         "ts": 1711100400
│   │       }
│   │
│   ├── breaker/
│   │   ├── {circuit_id}/command  # Breaker command (app -> hub)
│   │   │   payload: {
│   │   │     "action": "off",
│   │   │     "token": "eyJ...",
│   │   │     "pin_hash": "sha256...",
│   │   │     "request_id": "uuid"
│   │   │   }
│   │   └── {circuit_id}/state    # Breaker state (hub -> app)
│   │       payload: {
│   │         "state": "on",
│   │         "last_changed": 1711100400,
│   │         "changed_by": "user_uuid"
│   │       }
│   │
│   ├── network/
│   │   ├── clients               # Connected device list
│   │   │   payload: [{
│   │   │     "mac": "AA:BB:CC:DD:EE:FF",
│   │   │     "ip": "192.168.77.42",
│   │   │     "hostname": "iPhone-BC",
│   │   │     "via_node": "node_id_1",
│   │   │     "rssi": -42,
│   │   │     "band": "5GHz"
│   │   │   }, ...]
│   │   └── plc                   # PLC backbone status
│   │       payload: [{
│   │         "node_id": "node_id_1",
│   │         "snr_db": 32.5,
│   │         "phy_rate_mbps": 480,
│   │         "attenuation_db": 18.2
│   │       }, ...]
│   │
│   ├── alert/                    # Alerts (hub -> app)
│   │   payload: {
│   │     "type": "overcurrent",
│   │     "circuit_id": 7,
│   │     "value": 19.8,
│   │     "threshold": 18.0,
│   │     "ts": 1711100400,
│   │     "message": "Circuito 7 (Cocina) consumo alto: 19.8A"
│   │   }
│   │
│   └── ota/
│       ├── check                 # OTA check request (cloud -> hub)
│       └── status                # OTA status (hub -> cloud)
│           payload: {
│             "state": "downloading",
│             "progress": 45,
│             "version": "1.0.4",
│             "error": null
│           }
│
├── {node_id}/
│   └── status                    # Node status (via PLC to hub, bridged to cloud)
│       payload: {
│         "online": true,
│         "uptime_s": 86400,
│         "firmware": "1.0.3",
│         "temp_c": 38.2,
│         "wifi_clients": 7,
│         "plc_snr_db": 32.5,
│         "plc_phy_rate_mbps": 480
│       }
│
├── {hub_id}/smarthome/
│   ├── {device_id}/state          # Smart home device state (pub by hub)
│   │   payload: {
│   │     "id": "uuid",
│   │     "name": "Living Room Light",
│   │     "type": "light",
│   │     "platform": "tuya",
│   │     "online": true,
│   │     "state": {"on": true, "brightness": 80},
│   │     "ts": 1711100400
│   │   }
│   │
│   ├── {device_id}/command        # Smart home device command (app -> hub)
│   │   payload: {
│   │     "action": "set_state",
│   │     "state": {"on": false},
│   │     "token": "eyJ...",
│   │     "request_id": "uuid"
│   │   }
│   │
│   ├── scene/{scene_id}/execute   # Scene execution (app -> hub)
│   │   payload: {
│   │     "token": "eyJ...",
│   │     "biometric_confirmed": false
│   │   }
│   │
│   └── automation/log             # Automation execution log (hub -> app)
│       payload: {
│         "rule_id": "uuid",
│         "trigger": "ttlock_front_door_open",
│         "actions_executed": ["tuya_hallway_light_on", "ezviz_front_cam_record"],
│         "ts": 1711100400
│       }
│
└── account/{account_id}/
    └── cross-property/            # Hub-to-hub cross-property messages
        payload: {
          "source_hub": "hub_id_1",
          "target_hub": "hub_id_2",
          "event": "guest_checkin",
          "data": {...}
        }
```

---

## Appendix C: Glossary

| Term | Definition |
|------|-----------|
| AVLN | AV Logical Network -- a HomePlug AV2 network identified by a shared NEK |
| BPL | Broadband over Power Line -- general term for internet over electrical wiring |
| CCo | Central Coordinator -- the master device in a HomePlug AV2 network |
| CFE | Comision Federal de Electricidad -- Mexico's state electric utility |
| CT | Current Transformer -- a sensor that measures AC current non-invasively |
| DAK | Device Access Key -- a per-device password used for HomePlug AV2 pairing |
| FEC | Forward Error Correction -- error-correcting codes applied to transmitted data |
| HPGP | HomePlug Green PHY -- a lower-power subset of HomePlug AV (used in smart grid) |
| IFT | Instituto Federal de Telecomunicaciones -- Mexico's telecom regulator |
| LDPC | Low-Density Parity-Check -- a type of FEC code used in HomePlug AV2 |
| NEK | Network Encryption Key -- the AES-128 key encrypting all data in an AVLN |
| NMK | Network Membership Key -- used during device association to an AVLN |
| NOM | Norma Oficial Mexicana -- Mexican Official Standard (regulatory compliance) |
| OFDM | Orthogonal Frequency-Division Multiplexing -- the modulation scheme used in PLC |
| PLC | Power Line Communication -- data transmission over electrical power wiring |
| RMII | Reduced Media-Independent Interface -- a standard interface between MAC and PHY |
| RGMII | Reduced Gigabit Media-Independent Interface -- RMII equivalent for gigabit |
| STA | Station -- a non-coordinator device in a HomePlug AV2 network |
| TWT | Target Wake Time -- a WiFi 6 power-saving feature |
| Tuya | Chinese IoT cloud platform (Smart Life app) -- largest by device count |
| eWeLink | Chinese IoT cloud platform (Sonoff devices) |
| TTLock | Smart lock cloud platform (Sciener/TTLock branded locks) |
| EZVIZ | Consumer camera brand by Hikvision |
| Matter | New smart home standard (Apple/Google/Amazon) for local interoperability |
| Thread | Low-power mesh networking protocol, transport layer for Matter |
| Zigbee | Low-power mesh protocol (2.4 GHz), widely used in smart home devices |
| Z-Wave | Sub-GHz mesh protocol, commonly used in locks and sensors |
| RTSP | Real Time Streaming Protocol -- standard for IP camera video streams |
| ONVIF | Open Network Video Interface Forum -- camera interoperability standard |
| CC2652P | Texas Instruments multi-protocol wireless MCU (Zigbee + Thread coordinator) |

---

*Document version 0.2 -- Unified smart home hub + PLC network pivot. Subject to revision as component availability, regulatory requirements, and field test results evolve.*

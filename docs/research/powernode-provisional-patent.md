# UNITED STATES PROVISIONAL PATENT APPLICATION

**Attorney Docket No.:** [TO BE ASSIGNED]
**Filing Date:** [TO BE ASSIGNED]
**Inventor(s):** [FULL LEGAL NAME TO BE ADDED BY ATTORNEY]
**Citizenship:** United States / Mexico
**Correspondence Address:** [TO BE ADDED BY ATTORNEY]

---

## 1. TITLE OF THE INVENTION

**Portable Encrypted Network Identity System with Power Line Communication, Unified Multi-Platform Smart Home Integration, and Integrated Remote Access**

---

## 2. CROSS-REFERENCE TO RELATED APPLICATIONS

This application is the first filing. No priority is claimed from any prior application. The applicant intends to file a corresponding application with the Mexican Institute of Industrial Property (IMPI) within twelve (12) months of the filing date of this provisional application, claiming priority under the Paris Convention for the Protection of Industrial Property.

---

## 3. FIELD OF THE INVENTION

The present invention relates generally to network communication systems, and more particularly to a portable encrypted network identity device that communicates over power line communication (PLC) infrastructure to extend a user's home network to remote locations, while simultaneously providing unified multi-platform smart home device control, per-circuit energy metering, and integrated remote desktop access, all coordinated through a central hub device installed at a residential electrical service panel.

---

## 4. BACKGROUND OF THE INVENTION

### 4.1 Power Line Communication Standards

Power line communication (PLC) technology enables data transmission over existing electrical wiring. Standards such as HomePlug AV2 (IEEE 1901) and ITU-T G.hn (G.9960/G.9961) provide data rates exceeding 1 Gbps at the physical layer. However, commercially available PLC products, including those from TP-Link (Powerline AV series), Devolo (Magic series), and similar manufacturers, are limited to network extension functionality. These devices act as simple Ethernet-over-power bridges and provide no smart home integration, no portable network identity capability, no energy metering functionality, and no remote access infrastructure. They are passive networking appliances with no intelligence beyond data transport.

### 4.2 WiFi Mesh Systems

WiFi mesh networking products such as Amazon Eero, Netgear Orbi, and TP-Link Deco provide whole-home wireless coverage through multiple coordinating access points. While some incorporate limited smart home features (e.g., Eero's Thread radio, Orbi's limited device management), these systems rely entirely on wireless propagation and do not leverage power line communication. They are not portable identity devices; they are infrastructure permanently installed in a single location. They provide no mechanism for a user to carry their network identity to a remote location and automatically establish a secure tunnel back to their home network.

### 4.3 Smart Home Hubs

Smart home hubs such as Samsung SmartThings, Hubitat Elevation, and the open-source Home Assistant platform aggregate control of smart home devices across multiple protocols (Zigbee, Z-Wave, WiFi, Bluetooth). However, these hubs suffer from significant limitations: (a) they do not provide network distribution over power lines; (b) they do not integrate per-circuit energy metering; (c) they do not support portable network identity or roaming capability; (d) they do not include integrated remote desktop access infrastructure; and (e) their multi-platform integration is typically limited, requiring extensive user configuration and often failing to normalize devices into a truly unified abstraction layer. Each platform's devices retain their platform-specific characteristics, creating fragmented user experiences.

### 4.4 VPN Routers and Travel Routers

Portable VPN solutions such as GL.iNet travel routers allow users to connect to a VPN server from remote locations. However, these devices: (a) rely on WiFi or Ethernet for upstream connectivity, not power line communication; (b) do not carry a hardware-bound cryptographic identity; (c) do not integrate smart home control; (d) do not provide energy metering; (e) do not include remote desktop relay infrastructure; and (f) require manual configuration of VPN credentials. They are generic networking devices, not identity-bearing nodes that automatically authenticate and establish tunnels upon physical connection to a power outlet.

### 4.5 Remote Desktop Solutions

Remote desktop applications such as RustDesk, TeamViewer, and AnyDesk provide screen-sharing and remote control capabilities. However, these are software-only solutions that: (a) operate as separate applications independent of network hardware; (b) typically require monthly subscription fees for commercial use or relay server access; (c) route traffic through third-party infrastructure, creating privacy and security concerns; (d) are not integrated into a user's network hardware; and (e) do not leverage power line communication or VPN tunnels for secure transport. There exists no solution where the remote desktop relay server is embedded in the user's own network hub hardware, operating entirely within the user's encrypted tunnel infrastructure.

### 4.6 Energy Monitoring Systems

Per-circuit energy monitoring systems such as Sense, Emporia Vue, and IoTaWatt use current transformer (CT) clamp sensors to measure power consumption on individual breaker circuits. These are standalone monitoring devices that: (a) do not provide network distribution; (b) do not integrate smart home control; (c) do not support portable network identity; and (d) are separate devices requiring their own installation, configuration, and app ecosystem.

### 4.7 The Problem Not Solved by the Prior Art

No existing product, system, or combination of commercially available products addresses the convergence of: power line communication-based network distribution; unified multi-platform smart home device control with cross-platform automation; portable encrypted network identity enabling automatic secure tunnel establishment from any PLC-equipped outlet; integrated remote desktop relay infrastructure operating within the user's own encrypted tunnel; and per-circuit energy metering from the same hub device.

The present invention addresses this gap by providing a complete, integrated system that unifies all of these capabilities into a hub-and-node architecture, where the hub is installed at the residential electrical panel and portable nodes carry the user's cryptographic identity to any location with PLC-equipped power infrastructure.

---

## 5. SUMMARY OF THE INVENTION

The present invention provides a system comprising a central hub device, one or more satellite node devices, and a software application for unified control.

The hub device is installed at or near a residential electrical service panel and simultaneously performs the following functions: (a) distributes internet connectivity to satellite nodes via power line communication through existing house wiring; (b) monitors per-circuit energy consumption via current transformer clamp sensors installed on individual breaker circuits; (c) serves as the central coordinator for smart home device integration across multiple third-party platforms via both cloud APIs and local wireless protocols; (d) operates an encrypted relay server for remote desktop access to devices on the home network; and (e) acts as the default network gateway for roaming nodes that connect from remote locations via encrypted VPN tunnels.

The satellite node device is a portable unit that plugs into any standard power outlet equipped with PLC capability. The node carries the user's cryptographic identity in a hardware security element and, upon physical connection to a remote PLC network, automatically: (a) establishes PLC communication with the remote location's infrastructure; (b) authenticates its identity via a certificate-based protocol against a trust registry; (c) establishes an encrypted VPN tunnel back to the user's home hub; and (d) routes all network traffic through this tunnel, causing all traffic to appear as originating from the user's home network regardless of physical location. This transforms any PLC-equipped power outlet into an extension of the user's home network.

The system further provides unified multi-property management, enabling a single user account to manage multiple hubs across different physical locations with independent operation and cross-property automation.

---

## 6. BRIEF DESCRIPTION OF THE DRAWINGS

The following drawings, to be prepared by a patent illustrator, form part of this specification:

**FIG. 1** is a system architecture overview diagram illustrating the hub device at the electrical service panel, satellite nodes in power outlets throughout and outside the home, cloud infrastructure, and the mobile/desktop application.

**FIG. 2** is a hardware block diagram of the hub device, showing the main processor, PLC modem, multi-protocol radio module, CT clamp analog-to-digital conversion circuitry, hardware security module, network interfaces, and power supply.

**FIG. 3** is a hardware block diagram of the portable satellite node device, showing the PLC modem, WiFi radio, hardware security element, cryptographic processing unit, indicator system, and power supply.

**FIG. 4** is a sequence diagram illustrating the roaming authentication protocol, including node identity presentation, certificate validation, trust registry lookup, challenge-response exchange, and tunnel authorization.

**FIG. 5** is a flow diagram illustrating VPN tunnel establishment between a roaming node and the home hub, including key exchange, tunnel parameter negotiation, routing table configuration, and traffic forwarding.

**FIG. 6** is a block diagram illustrating the unified device abstraction layer, showing how devices from multiple third-party platforms are normalized into a common device model with standardized capabilities, states, and control interfaces.

**FIG. 7** is an architecture diagram illustrating multi-property management, showing multiple hubs linked under a single user account with independent local operation, cloud synchronization, and cross-property automation via hub-to-hub messaging.

**FIG. 8** is a block diagram illustrating the remote desktop relay architecture, showing the relay server embedded in the hub, encrypted tunnel transport, client-side viewer, and direct peer-to-peer connection establishment.

**FIG. 9** is a diagram illustrating PLC coupling to residential electrical wiring, showing the hub's connection at the breaker panel, signal injection into house wiring, and reception at wall outlet satellite nodes.

**FIG. 10** is a diagram illustrating CT clamp metering integration, showing the physical installation of current transformer sensors on individual breaker circuits, analog signal conditioning, digital conversion, and data aggregation by the hub processor.

---

## 7. DETAILED DESCRIPTION OF PREFERRED EMBODIMENTS

The following detailed description refers to the accompanying drawings and describes preferred embodiments of the invention. It is to be understood that the invention is not limited to these specific embodiments and that various modifications, substitutions, and alterations may be made without departing from the spirit and scope of the invention.

### 7.1 System Overview

Referring to FIG. 1, the system 100 of the present invention comprises a central hub device 110, one or more satellite node devices 120, a cloud infrastructure component 130, and a client application 140 executable on a mobile device or personal computer.

The hub device 110 is installed at or near the electrical service panel 150 of a residential or commercial property. The hub device 110 connects to the property's internet connection 160 (via Ethernet or WiFi to an existing router) and to the property's electrical wiring 170 via a PLC coupling circuit.

Satellite node devices 120 are distributed throughout the property by plugging into standard power outlets 180. Each node 120 communicates with the hub 110 via PLC signals transmitted through the existing electrical wiring 170. Additionally, portable node devices 120p may be transported to remote locations and plugged into power outlets at those locations, where they automatically establish encrypted tunnels back to the user's home hub 110.

The cloud infrastructure 130 provides: (a) user account management; (b) a trust registry for roaming node authentication; (c) a message broker for hub-to-hub communication in multi-property configurations; (d) firmware update distribution; and (e) optional remote access relay when direct peer-to-peer connection is not possible.

The client application 140 provides a unified interface for: (a) viewing and controlling all smart home devices across all platforms; (b) monitoring per-circuit energy consumption; (c) managing property-level settings; (d) switching between multiple properties; (e) configuring automation rules and scenes; and (f) initiating remote desktop sessions.

### 7.2 Hub Device Hardware

Referring to FIG. 2, the hub device 110 comprises the following components in a preferred embodiment:

**7.2.1 Main Processor.** A dual-core microprocessor 210 with integrated WiFi and Bluetooth Low Energy (BLE) radio, operating at a clock frequency sufficient for concurrent network routing, smart home device management, and energy metering calculations. In a preferred embodiment, this is an ESP32-S3 dual-core Xtensa LX7 processor at 240 MHz, with 512 KB SRAM, 8 MB PSRAM, and 16 MB flash storage. The processor 210 runs a real-time operating system (RTOS) with task prioritization for time-critical PLC and radio operations.

**7.2.2 PLC Modem.** A power line communication modem 220 compliant with the HomePlug AV2 standard (IEEE 1901) or the ITU-T G.hn standard (G.9960), capable of data rates up to 600 Mbps at the PHY layer. In a preferred embodiment, the PLC modem 220 is based on a Qualcomm QCA7006 or equivalent PLC transceiver. The modem 220 includes a coupling circuit 222 for injecting and receiving PLC signals on the property's AC wiring at the service panel. The coupling circuit 222 comprises a signal coupler (capacitive or inductive) rated for the local mains voltage (120V/60Hz for US, 127V/60Hz for Mexico, or 220-240V/50Hz for other markets) and includes appropriate isolation and surge protection.

**7.2.3 Multi-Protocol Radio Module.** A multi-protocol wireless radio module 230 capable of Zigbee 3.0 (IEEE 802.15.4), Thread (IEEE 802.15.4), and optionally Z-Wave communication. In a preferred embodiment, the radio module 230 is a Texas Instruments CC2652P multiprotocol wireless MCU with integrated +20 dBm power amplifier for extended range. The radio module 230 communicates with the main processor 210 via a serial interface (UART or SPI). The module 230 runs firmware implementing both the Zigbee 3.0 stack and the Thread/OpenThread stack, with runtime switching between protocols or simultaneous operation via time-division multiplexing.

**7.2.4 CT Clamp Interface.** A current transformer (CT) clamp interface 240 comprising a plurality of analog input channels, each connected to a CT clamp sensor 242 installed on an individual breaker circuit at the service panel. In a preferred embodiment, the interface 240 includes an ADS1115 16-bit analog-to-digital converter (ADC) or equivalent, with up to 16 multiplexed input channels. Each CT clamp sensor 242 is a split-core current transformer with a rated measurement range of 0-100A, producing a proportional voltage output that is conditioned by a burden resistor network and anti-aliasing filter before digitization. A voltage reference sensor 244 is also connected to measure the AC mains voltage waveform, enabling true power (watts), apparent power (VA), power factor, and energy (kWh) calculations through real-time multiplication and integration of the voltage and current waveforms.

**7.2.5 Hardware Security Module (HSM).** A dedicated hardware security module 250 for cryptographic key storage and operations. In a preferred embodiment, the HSM 250 is a Microchip ATECC608B secure element connected to the main processor 210 via I2C. The HSM 250 stores the hub's private key, X.509 device certificate, and root CA certificate in tamper-resistant memory. It performs ECDSA signing, ECDH key agreement, and SHA-256 hashing operations in hardware, ensuring that private keys are never exposed to the main processor's memory space.

**7.2.6 Network Interface.** An Ethernet interface 260 (10/100 Mbps or Gigabit) for wired connection to the property's existing router or internet gateway. Additionally, the main processor's integrated WiFi radio 262 (IEEE 802.11 b/g/n/ac) provides wireless connectivity as an alternative or backup uplink. The hub 110 obtains an IP address on the local network and establishes outbound connections to the cloud infrastructure 130 and to third-party smart home platform cloud APIs.

**7.2.7 Relay Controller.** An optional relay controller 270 comprising a plurality of relay outputs, each capable of switching an individual breaker circuit on or off via a motorized circuit breaker or a relay module connected in series with the breaker. This enables remote circuit control (e.g., turning off a specific circuit from the app). In a preferred embodiment, the relay controller 270 uses solid-state relays rated for the breaker's amperage, with galvanic isolation and overcurrent protection.

**7.2.8 Power Supply.** A power supply unit 280 converting AC mains voltage to the DC voltages required by the hub's components (3.3V, 5V). The power supply 280 includes a battery backup (lithium polymer cell) with a charge controller, enabling the hub to maintain operation during brief power outages and to send power-failure notifications to the user.

**7.2.9 Enclosure.** The hub 110 is housed in an enclosure designed for mounting adjacent to or integrated into a residential electrical service panel. The enclosure is rated for the appropriate safety standards (UL, NOM for Mexico) and provides ventilation for thermal management.

### 7.3 Satellite Node Hardware

Referring to FIG. 3, the satellite node device 120 comprises the following components in a preferred embodiment:

**7.3.1 PLC Modem.** A power line communication modem 310 of the same type and standard as the hub's PLC modem 220, enabling bidirectional communication with the hub 110 via the property's electrical wiring. The modem 310 includes an integrated coupling circuit for connecting to the AC wiring through the power outlet's hot and neutral conductors.

**7.3.2 WiFi Radio.** A WiFi radio 320 (IEEE 802.11 b/g/n/ac) capable of operating as an access point (AP mode), providing local wireless coverage at the node's location. Devices within WiFi range of the node 120 can connect to the node's AP and receive internet connectivity sourced from the hub 110 via the PLC backhaul. The WiFi radio 320 also operates in station (STA) mode during initial setup and configuration.

**7.3.3 Hardware Security Element.** A hardware security element 330, functionally identical to the hub's HSM 250 (e.g., ATECC608B), storing the node's unique private key, X.509 device certificate signed by the user's personal CA, and the root CA certificate. The security element 330 performs all cryptographic operations locally, ensuring the node's identity cannot be cloned or extracted.

**7.3.4 Cryptographic Processing.** The node's main processor 340 (in a preferred embodiment, an ESP32-S3 or equivalent) runs a lightweight VPN client implementation (WireGuard protocol preferred for its minimal attack surface and high performance). When roaming, the processor 340 coordinates with the security element 330 to perform the authentication handshake and establish the encrypted tunnel to the home hub 110.

**7.3.5 Ethernet Port.** An optional RJ45 Ethernet port 350 allowing a wired device (laptop, desktop PC) to connect directly to the node 120 and receive network connectivity through the PLC backhaul to the hub 110 (or through the VPN tunnel when roaming).

**7.3.6 Indicator System.** An LED indicator system 360 providing visual feedback on the node's status: PLC link quality, WiFi AP status, VPN tunnel status (connected/disconnected/roaming), and power status.

**7.3.7 Form Factor.** The node 120 is housed in a compact enclosure designed to plug directly into a standard power outlet (NEMA 5-15 for US/Mexico or appropriate plug type for other markets). The enclosure is sufficiently compact to occupy only one outlet position in a duplex outlet, leaving the adjacent outlet available for other use.

### 7.4 PLC Communication Protocol

The PLC communication between the hub 110 and satellite nodes 120 operates as follows:

**7.4.1 Physical Layer.** PLC signals are transmitted over the existing AC electrical wiring using orthogonal frequency-division multiplexing (OFDM) in the 2-86 MHz frequency band (as specified by HomePlug AV2) or the 2-200 MHz band (as specified by G.hn). The signals are coupled onto the AC wiring at the hub 110 via the coupling circuit 222 at the service panel, and received at each node 120 via the node's coupling circuit integrated into its power plug. Signal attenuation, noise characteristics, and multipath effects vary depending on the wiring topology, length, and connected loads; the PLC modem's adaptive modulation and coding scheme adjusts transmission parameters in real time to maintain reliable communication.

**7.4.2 Network Layer.** The PLC network operates as a bridged Ethernet segment, with the hub 110 acting as the central coordinator (CCo) in HomePlug AV2 terminology. Each node 120 is assigned a terminal equipment identifier (TEI) upon joining the network. The hub 110 manages time-division multiple access (TDMA) scheduling for the PLC medium, allocating transmission slots to each node to prevent collisions and provide quality-of-service guarantees.

**7.4.3 Security Layer.** All PLC communication is encrypted using AES-128 (HomePlug AV2) or AES-256 (G.hn) encryption at the link layer. A network membership key (NMK) derived from the hub's identity is distributed to authorized nodes during the pairing process. This link-layer encryption protects against eavesdropping by other PLC devices on the same electrical circuit (e.g., in multi-tenant buildings where wiring may be shared).

**7.4.4 Local vs. Roaming Operation.** When a node 120 is operating on its home network (i.e., connected to the same electrical wiring as its home hub 110), it functions as a transparent network bridge, extending WiFi and Ethernet connectivity from the hub. When a node 120p is plugged into a remote location's power outlet, it detects that the PLC network coordinator is not its home hub (based on the coordinator's identity certificate) and initiates the roaming authentication protocol described in Section 7.6.

### 7.5 Smart Home Integration Layer

The hub 110 integrates with multiple third-party smart home platforms simultaneously through a multi-layer integration architecture:

**7.5.1 Cloud API Integration.** The hub 110 maintains persistent or periodic connections to the cloud APIs of the following platforms (non-exhaustive list of supported platforms): Tuya/Smart Life (via Tuya Cloud API), eWeLink/Sonoff (via eWeLink Cloud API), Amazon Alexa (via Alexa Smart Home Skill API), Google Home (via Google Smart Home API), TTLock (via TTLock Cloud API), EZVIZ/Hikvision (via EZVIZ Open Platform API), Broadlink (via Broadlink Cloud API), and others as added. For each platform, the hub stores the user's OAuth tokens or API credentials in encrypted storage on the HSM 250. The hub periodically polls or maintains WebSocket connections to each platform's API to receive device state updates and send control commands.

**7.5.2 Local Protocol Integration.** The hub 110 simultaneously communicates with devices via local wireless protocols, bypassing cloud APIs for lower latency and offline operation:

- **Zigbee 3.0:** Via the CC2652P radio module 230, the hub acts as a Zigbee coordinator, directly controlling Zigbee-compatible devices (lights, sensors, locks, switches) without requiring the devices' original brand hub.
- **Z-Wave:** Via an optional Z-Wave radio module (e.g., Silicon Labs EFR32ZG14), the hub acts as a Z-Wave primary controller.
- **Matter/Thread:** Via the CC2652P radio module 230 running OpenThread, the hub acts as a Thread border router and Matter controller, supporting the new Matter standard for cross-platform device communication.
- **MQTT:** The hub runs a local MQTT broker, enabling communication with any MQTT-capable device on the local network (e.g., devices running Tasmota, ESPHome, or custom firmware).
- **Bluetooth Low Energy (BLE):** Via the ESP32-S3's integrated BLE radio, the hub communicates with BLE-based devices (locks, sensors, beacons).
- **Infrared (IR):** Via an optional IR blaster module connected to the hub, the hub controls legacy IR devices (air conditioners, TVs, audio equipment) by learning and replaying IR codes.
- **433 MHz RF:** Via an optional 433 MHz RF transmitter module, the hub controls legacy RF devices (older switches, outlets, blinds).

**7.5.3 Device Abstraction Layer.** Referring to FIG. 6, the hub 110 implements a device abstraction layer 600 that normalizes all devices from all platforms and protocols into a unified device model. Each physical device, regardless of its origin platform or communication protocol, is represented as a normalized device object 610 with the following standardized attributes:

- **Device ID:** A universally unique identifier assigned by the hub.
- **Device Name:** User-assigned name.
- **Device Type:** Standardized type from a defined taxonomy (e.g., "light," "switch," "thermostat," "lock," "camera," "sensor," "cover," "media_player").
- **Capabilities:** A list of standardized capabilities (e.g., "on_off," "brightness," "color_temperature," "color_rgb," "position," "lock_unlock," "temperature_set," "media_play_pause").
- **State:** A dictionary of key-value pairs representing the device's current state, using standardized keys (e.g., "is_on: true," "brightness: 75," "color_temp: 4000," "position: 50," "is_locked: true").
- **Source Platform:** Identifier of the originating platform (for internal routing of commands).
- **Source Protocol:** Identifier of the communication protocol used (cloud_api, zigbee, zwave, mqtt, ble, ir, rf).
- **Online Status:** Whether the device is currently reachable.

When the user issues a command through the client application 140 (e.g., "turn on living room light to 50% brightness"), the device abstraction layer 600 translates the standardized command into the platform-specific and protocol-specific command format required by the target device's native interface, then routes the command through the appropriate communication channel. This translation is bidirectional: incoming state updates from any platform are normalized into the standard format before being stored and presented to the user.

**7.5.4 Cross-Platform Automation Engine.** The hub 110 includes an automation engine 620 that evaluates user-defined rules and scenes involving devices across multiple platforms and protocols. A user can create an automation such as: "When the Tuya motion sensor detects motion AND the time is after sunset, turn on the eWeLink light to 50% brightness, set the Broadlink air conditioner to 22C, and unlock the TTLock front door." The automation engine 620 evaluates trigger conditions from any source platform, and executes actions on any target platform, using the device abstraction layer 600 for both trigger evaluation and action execution. Automations are stored locally on the hub and execute without cloud dependency (for devices accessible via local protocols) or with cloud dependency (for devices accessible only via cloud APIs).

### 7.6 Roaming Authentication Protocol

Referring to FIG. 4, the roaming authentication protocol operates as follows when a portable node 120p is plugged into a power outlet at a remote location:

**Step 1 — PLC Network Discovery (401).** The node 120p powers on and its PLC modem 310 scans for PLC network coordinators on the AC wiring. If a PLC coordinator is detected, the node requests to join the PLC network as a guest station.

**Step 2 — Coordinator Identity Check (402).** The node 120p receives the PLC coordinator's identity certificate. The node compares the coordinator's certificate against its stored home hub certificate. If they match, the node is on its home network and proceeds to normal home operation (no roaming required). If they do not match, the node enters roaming mode.

**Step 3 — Identity Presentation (403).** The node 120p presents its X.509 device certificate to the remote PLC coordinator. This certificate contains: the node's public key, the node's unique device ID, the identity of the node's home hub, and the certificate chain signed by the user's personal CA.

**Step 4 — Trust Registry Validation (404).** The remote PLC coordinator (which is another instance of the hub device 110 at the remote location) validates the node's certificate by: (a) verifying the certificate chain cryptographically (signature validation up to a known root CA); (b) checking the certificate's validity period; (c) querying the cloud-based trust registry 130 to confirm the certificate has not been revoked; and (d) optionally checking a local whitelist if the remote hub's owner has pre-authorized specific roaming nodes.

**Step 5 — Challenge-Response Authentication (405).** The remote hub generates a cryptographic challenge (a random nonce) and sends it to the node. The node uses its hardware security element 330 to sign the nonce with its private key (ECDSA-P256) and returns the signed response. The remote hub verifies the signature using the node's public key from its certificate. This proves the node possesses the private key corresponding to the presented certificate, preventing certificate theft/replay.

**Step 6 — Tunnel Authorization (406).** Upon successful authentication, the remote hub authorizes the node to establish an outbound encrypted tunnel. The remote hub allocates a temporary IP address to the node on an isolated guest VLAN (preventing the roaming node from accessing the remote location's local network) and permits outbound tunnel traffic from the node to the node's home hub.

**Step 7 — VPN Tunnel Establishment (407).** The node 120p establishes an encrypted VPN tunnel (WireGuard protocol in the preferred embodiment) from the remote location, through the remote hub's internet connection, to the node's home hub 110. The tunnel endpoints are: (a) the node's temporary IP on the remote hub's guest VLAN; and (b) the home hub's public IP or dynamic DNS hostname. The key exchange uses keys derived from the node's hardware security element and the home hub's HSM, with the WireGuard handshake providing perfect forward secrecy.

**Step 8 — Traffic Routing (408).** Once the tunnel is established, the node 120p configures its routing table such that all network traffic (from the node itself and from any devices connected to the node's WiFi AP or Ethernet port) is routed through the VPN tunnel to the home hub 110. The home hub 110 acts as the default gateway, performing NAT (network address translation) on the tunneled traffic and forwarding it to the internet through the home network's internet connection. To any external service, the traffic appears to originate from the home network's public IP address.

**Step 9 — Keepalive and Reconnection (409).** The node 120p sends periodic keepalive packets through the tunnel to maintain the connection and detect failures. If the tunnel drops (due to internet interruption at either end), the node automatically reattempts establishment using exponential backoff. The node's WiFi AP displays appropriate status via the LED indicator system 360 to inform connected users of tunnel state.

### 7.7 VPN Tunnel Implementation

Referring to FIG. 5, the VPN tunnel between a roaming node 120p and the home hub 110 is implemented as follows:

**7.7.1 Protocol.** The preferred embodiment uses the WireGuard protocol (RFC-style specification by Jason Donenfeld, incorporated into the Linux kernel as of version 5.6) for its simplicity, performance, and minimal attack surface. WireGuard uses Curve25519 for key exchange, ChaCha20-Poly1305 for symmetric encryption and authentication, BLAKE2s for hashing, and SipHash for hashtable keying.

**7.7.2 Key Management.** Each node's WireGuard private key is generated inside and stored within the hardware security element 330 and is never exported. The corresponding public key is embedded in the node's X.509 certificate. The home hub's WireGuard private key is similarly stored in its HSM 250. Public keys are exchanged during the initial pairing process (when a new node is registered to a user's account).

**7.7.3 NAT Traversal.** To handle NAT traversal (since both the node and the home hub may be behind NAT routers), the system employs: (a) WireGuard's built-in UDP hole-punching via persistent keepalives; (b) the home hub maintains a registration with the cloud infrastructure 130, advertising its current public IP and port; (c) if direct peer-to-peer connectivity cannot be established, the cloud infrastructure 130 provides a relay service as a fallback (TURN-style relay), though this is a degraded mode with higher latency.

**7.7.4 Split Tunneling (Optional).** The system supports an optional split tunneling mode where only traffic destined for the home network's local subnet is routed through the VPN tunnel, while internet-bound traffic exits directly through the remote location's internet connection. This mode is configurable per-node via the client application 140.

### 7.8 Remote Desktop Relay Server

Referring to FIG. 8, the hub device 110 includes an integrated remote desktop relay server 800:

**7.8.1 Relay Architecture.** The relay server 800 runs on the hub's processor 210 (or on an optional co-processor for higher performance). In a preferred embodiment, the relay server implements a protocol compatible with the open-source RustDesk remote desktop system, specifically the RustDesk relay server (hbbs/hbbr) protocol. The relay server 800 listens for connections from remote desktop clients and target machines on the local network.

**7.8.2 Registration.** Devices on the home network (PCs, Macs, tablets) that wish to be remotely accessible run a lightweight agent application that registers with the hub's relay server 800, advertising their availability for remote sessions. Each registered device receives a unique access ID.

**7.8.3 Connection Flow.** When a user initiates a remote desktop session from the client application 140 (or from a roaming node's connected device): (a) the client connects to the hub's relay server 800 via the VPN tunnel (if roaming) or directly (if on the home network); (b) the relay server 800 brokers the connection to the target device's agent; (c) if both client and target are on the same local network (or both reachable via the VPN tunnel), the relay server facilitates a direct peer-to-peer connection; (d) if direct connection is not possible, the relay server 800 relays the screen data and input events.

**7.8.4 Security.** All remote desktop traffic is encrypted end-to-end between the client and the target device. The relay server 800 facilitates connection establishment but cannot decrypt the screen content or input events. Authentication for remote desktop sessions uses the same PKI infrastructure (X.509 certificates) as the rest of the system. Additionally, per-device access can be restricted via the client application 140 (e.g., requiring explicit approval from the target device's local user before allowing remote access).

**7.8.5 Advantages Over Prior Art.** By integrating the relay server into the hub hardware: (a) no third-party service or subscription is required; (b) all traffic remains within the user's own infrastructure (hub + VPN tunnel); (c) performance is optimized because the relay server has direct low-latency access to the local network; (d) the relay server is always available whenever the hub is powered on, with no dependency on external service availability.

### 7.9 Energy Metering System

Referring to FIG. 10, the energy metering system operates as follows:

**7.9.1 CT Clamp Installation.** Split-core current transformer sensors 242 are installed on individual breaker circuits at the electrical service panel. Each CT clamp 242 clips around a single conductor (hot wire) for a given breaker circuit without requiring any electrical disconnection or modification to the circuit. The CT clamps 242 are connected to the hub's CT clamp interface 240 via low-voltage signal cables.

**7.9.2 Measurement.** The hub's ADC 240 samples the CT clamp outputs and the voltage reference sensor 244 at a rate sufficient to capture the AC waveform (typically 4,000 samples per second per channel or higher). For each circuit, the processor 210 calculates: instantaneous current (from the CT clamp reading and the sensor's turns ratio), instantaneous voltage (from the voltage reference), instantaneous power (voltage x current), real power (time-averaged instantaneous power over complete AC cycles), apparent power (RMS voltage x RMS current), power factor (real power / apparent power), and cumulative energy consumption (integral of real power over time).

**7.9.3 Reporting.** Per-circuit energy data is stored locally on the hub with configurable resolution (per-second for real-time display, per-minute for historical graphs). Data is transmitted to the cloud infrastructure 130 at regular intervals for long-term storage and analytics. The client application 140 displays: real-time per-circuit power consumption, historical consumption graphs (hourly, daily, weekly, monthly), cost estimates based on configured electricity tariff rates, anomaly detection alerts (e.g., unusual consumption patterns indicating appliance failure or forgotten appliances), and comparison across time periods.

**7.9.4 Integration with Smart Home Automation.** Energy metering data is available as trigger conditions in the automation engine 620. For example: "If kitchen circuit power exceeds 2000W for more than 30 minutes, send a notification" or "If total home consumption exceeds 5 kW, turn off non-essential circuits via the relay controller 270."

### 7.10 Multi-Property Management Architecture

Referring to FIG. 7, the multi-property management system operates as follows:

**7.10.1 Account Structure.** A single user account in the cloud infrastructure 130 can be associated with multiple hub devices 110a, 110b, 110c, etc., each installed at a different physical property. Each hub registers with the cloud infrastructure upon initial setup, linking itself to the user's account via a secure pairing process (QR code scan from the client application).

**7.10.2 Independent Local Operation.** Each hub operates independently and autonomously when the internet connection is unavailable. All smart home device control, automation execution, energy metering, and PLC networking functions continue to operate locally without cloud dependency. The hub stores all device states, automation rules, and metering data locally.

**7.10.3 Property Switching.** The client application 140 provides a property selector interface allowing the user to switch between properties instantly. When a property is selected, the application connects to the corresponding hub (directly if on the same local network, or via the cloud infrastructure's relay if remote) and loads the property's devices, automations, and metering data.

**7.10.4 Cross-Property Automation.** Automations can reference devices and conditions across multiple properties. For example: "When the vacation home's security camera detects motion, send a notification to my phone AND turn on the vacation home's lights." Cross-property automations are coordinated via a hub-to-hub MQTT messaging system routed through the cloud infrastructure's message broker 130. Each hub publishes relevant state changes to a property-specific MQTT topic, and other hubs subscribed to that topic can use those state changes as automation triggers.

**7.10.5 Roaming Across Properties.** A user's portable node 120p can roam between the user's own properties without triggering the full roaming authentication protocol. Since all of the user's hubs share the same trust chain (signed by the user's personal CA), a node arriving at any of the user's properties is recognized as a trusted local device and granted full network access (not guest VLAN access) immediately.

### 7.11 Client Application

The client application 140 provides the following interfaces:

**7.11.1 Property Dashboard.** A main dashboard displaying: total current power consumption, active device count, hub online status, recent automation executions, and quick access to frequently used devices and scenes.

**7.11.2 Device Grid.** A unified device grid displaying all devices across all platforms, organized by room, device type, or custom groups. Each device shows its current state and provides one-tap control (toggle, slider, etc.) directly from the grid. Long-press or detail view provides full device control and configuration.

**7.11.3 Automation Builder.** A visual automation builder allowing users to create IF-THEN rules with: triggers (device state changes, time-based schedules, energy thresholds, location-based geofencing, weather conditions), conditions (additional criteria that must be met), and actions (device commands, notifications, scene activation).

**7.11.4 Energy Dashboard.** A dedicated energy monitoring view with: real-time per-circuit power display, historical consumption charts, cost tracking, and anomaly alerts.

**7.11.5 Remote Desktop.** A remote desktop client interface for initiating and managing remote desktop sessions to registered devices on the home network.

**7.11.6 Node Management.** An interface for managing satellite nodes: viewing node locations, PLC signal quality, WiFi client counts, roaming status, and pairing new nodes.

**7.11.7 Property Selector.** A property switching mechanism (dropdown, sidebar, or swipe gesture) for quickly switching between managed properties.

### 7.12 Security Architecture

The system implements a six-layer security architecture:

**Layer 1 — PLC Link-Layer Encryption.** All PLC communication is encrypted at the link layer using AES-128 or AES-256 as specified by the HomePlug AV2 or G.hn standard, preventing eavesdropping on the power line medium.

**Layer 2 — Transport Layer Security.** All communication between the hub and cloud infrastructure, between the hub and third-party APIs, and between the client application and the hub (when accessed remotely) uses TLS 1.3 with certificate pinning where applicable.

**Layer 3 — Public Key Infrastructure (PKI).** Each user's account includes a personal Certificate Authority (CA). All hubs and nodes belonging to the user are issued X.509 certificates signed by this CA. Certificate revocation is managed via the cloud trust registry. This PKI underpins all device authentication (roaming, pairing, inter-hub communication).

**Layer 4 — Secure Boot.** Both hub and node devices implement secure boot, verifying the integrity and authenticity of the firmware at every boot. The boot ROM verifies the bootloader's signature; the bootloader verifies the firmware's signature. Only firmware signed by the manufacturer's code-signing key is executed.

**Layer 5 — Firmware Signing.** All firmware updates are signed with the manufacturer's code-signing key (ECDSA-P256). The hub and nodes verify the firmware signature before applying updates. Firmware is distributed via the cloud infrastructure 130 with integrity verification (SHA-256 hash comparison) before installation.

**Layer 6 — Tamper Detection.** The hub's HSM 250 and the node's security element 330 include tamper detection features (voltage glitch detection, temperature range monitoring, physical tamper mesh in higher-security variants). Upon tamper detection, the security element erases stored keys, preventing extraction of cryptographic material from physically compromised devices.

---

## 8. CLAIMS

### Independent System Claims

**Claim 1.** A network system comprising:
a central hub device configured to be installed at an electrical service panel of a first property, the hub device comprising a power line communication (PLC) modem coupled to the property's electrical wiring, a network interface connected to an internet gateway, and a hardware security module storing a cryptographic identity of the hub device;
at least one portable satellite node device configured to be plugged into a power outlet, the node device comprising a PLC modem for communication over electrical wiring, a wireless access point, and a hardware security element storing a cryptographic identity of the node device;
wherein, when the node device is plugged into a power outlet at the first property, the node device communicates with the hub device via PLC through the property's electrical wiring, and the hub device provides internet connectivity to the node device via the PLC communication;
and wherein, when the node device is plugged into a power outlet at a second property remote from the first property, the node device is configured to: detect that the PLC network at the second property is not the node's home network, authenticate the node device's identity to a PLC network coordinator at the second property via a certificate-based authentication protocol, and upon successful authentication, establish an encrypted VPN tunnel through the second property's internet connection to the hub device at the first property, such that all network traffic from the node device and devices connected to the node device is routed through the encrypted tunnel and the hub device acts as the default network gateway for the node device.

**Claim 2.** A unified smart home control system comprising:
a hub device comprising a processor, a plurality of communication interfaces including at least a first wireless radio operating a first local wireless protocol and a network interface for connecting to at least one third-party cloud API;
a device abstraction layer implemented on the processor, the device abstraction layer configured to: receive device state information from a plurality of smart home devices connected via different communication protocols and different third-party platforms, normalize each device's state into a standardized device model having a standardized device type, a set of standardized capabilities, and a standardized state representation, and translate standardized control commands into protocol-specific and platform-specific commands for each target device;
an automation engine implemented on the processor, the automation engine configured to evaluate user-defined automation rules having trigger conditions referencing devices from a first platform and action targets referencing devices from a second platform different from the first platform, executing the actions via the device abstraction layer;
wherein the hub device simultaneously integrates with a plurality of third-party smart home platforms via their respective cloud APIs and simultaneously communicates with devices via at least two different local wireless protocols.

**Claim 3.** A system for distributed power line network management and energy metering comprising:
a hub device configured to be installed at an electrical service panel, the hub device comprising: a PLC modem coupled to the property's electrical wiring for distributing network connectivity, a plurality of current transformer sensor inputs each connected to a current transformer sensor installed on a respective breaker circuit, an analog-to-digital converter for digitizing current measurements from the sensors, a voltage reference input for measuring the AC mains voltage waveform, and a processor configured to compute per-circuit power consumption from the digitized current and voltage measurements;
at least one satellite node device plugged into a power outlet and communicating with the hub device via PLC;
wherein the hub device simultaneously distributes internet connectivity to the satellite nodes via PLC through the electrical wiring and monitors per-circuit energy consumption from the current transformer sensors.

### Independent Method Claims

**Claim 4.** A method of extending a user's home network to a remote location via power line communication, the method comprising:
providing a portable node device storing a cryptographic identity in a hardware security element, the cryptographic identity comprising a private key and an X.509 certificate signed by the user's personal certificate authority;
physically connecting the node device to a power outlet at a remote location;
the node device discovering a PLC network coordinator on the remote location's electrical wiring via the node device's PLC modem;
the node device determining that the PLC network coordinator is not the node device's home hub by comparing the coordinator's identity to a stored home hub identity;
the node device presenting its X.509 certificate to the remote PLC network coordinator;
the remote PLC network coordinator validating the node device's certificate by verifying the certificate chain and confirming certificate validity against a trust registry;
the remote PLC network coordinator issuing a cryptographic challenge to the node device;
the node device signing the challenge using its private key via the hardware security element and returning the signed response;
the remote PLC network coordinator verifying the signed response, thereby confirming the node device possesses the private key corresponding to the presented certificate;
the remote PLC network coordinator authorizing the node device to establish an outbound encrypted tunnel;
the node device establishing an encrypted VPN tunnel from the remote location through the remote location's internet connection to the user's home hub;
the node device routing all network traffic through the encrypted VPN tunnel such that the home hub acts as the default gateway for the node device.

**Claim 5.** A method of normalizing smart home devices from a plurality of disparate platforms into a unified control interface, the method comprising:
connecting a hub device to a plurality of third-party smart home platforms via their respective cloud APIs using stored authentication credentials;
simultaneously communicating with a plurality of smart home devices via at least two different local wireless protocols;
for each smart home device, regardless of the device's originating platform or communication protocol, generating a normalized device representation comprising a standardized device type, a set of standardized capabilities, and a standardized state representation;
receiving a control command in a standardized format from a client application;
translating the standardized control command into a platform-specific and protocol-specific command for the target device; and
transmitting the translated command to the target device via the appropriate communication interface.

### Dependent System Claims

**Claim 6.** The system of Claim 1, wherein the encrypted VPN tunnel uses the WireGuard protocol, with key material derived from the node device's hardware security element and the hub device's hardware security module.

**Claim 7.** The system of Claim 1, wherein the hub device further comprises a remote desktop relay server, and wherein when the node device is connected via the encrypted VPN tunnel from a remote location, a device connected to the node device can initiate a remote desktop session to a device on the first property's local network through the relay server, with all remote desktop traffic routed through the encrypted VPN tunnel.

**Claim 8.** The system of Claim 1, wherein the remote PLC network coordinator, upon successful authentication of the node device, assigns the node device a temporary IP address on an isolated guest network segment, preventing the node device from accessing the remote location's local network resources.

**Claim 9.** The system of Claim 1, further comprising a cloud-based trust registry storing certificate validity status for all registered node devices, wherein the remote PLC network coordinator queries the trust registry during the authentication protocol to confirm the node device's certificate has not been revoked.

**Claim 10.** The system of Claim 1, wherein the hardware security element of the node device is configured such that private key material stored therein cannot be exported or read by the node device's main processor, and all cryptographic signing operations using the private key are performed within the hardware security element.

**Claim 11.** The system of Claim 2, wherein the plurality of third-party smart home platforms comprises at least three of: Tuya, eWeLink, Amazon Alexa, Google Home, TTLock, EZVIZ, and Broadlink; and wherein the at least two different local wireless protocols comprise at least two of: Zigbee, Z-Wave, Thread, MQTT, Bluetooth Low Energy, infrared, and 433 MHz RF.

**Claim 12.** The system of Claim 2, wherein the automation engine is configured to execute automation rules locally on the hub device without requiring internet connectivity for devices accessible via local wireless protocols.

**Claim 13.** The system of Claim 3, wherein the processor is further configured to detect anomalous power consumption patterns on individual breaker circuits and generate alerts to a user via a client application.

**Claim 14.** The system of Claim 3, further comprising a relay controller connected to one or more breaker circuits, enabling remote switching of individual circuits via the client application, and wherein the automation engine is configured to execute automation rules that switch circuits on or off based on energy consumption thresholds.

### Dependent Method Claims

**Claim 15.** The method of Claim 4, wherein the step of the node device establishing an encrypted VPN tunnel further comprises NAT traversal using persistent UDP keepalive packets, and wherein if direct peer-to-peer connectivity cannot be established, the encrypted tunnel is routed through a cloud-based relay service.

**Claim 16.** The method of Claim 4, further comprising: configuring the node device's wireless access point to serve as an access point for client devices at the remote location; and routing all traffic from the client devices through the encrypted VPN tunnel to the home hub, such that all client devices appear to be on the user's home network.

**Claim 17.** The method of Claim 4, wherein the node device, upon detecting that the remote PLC network coordinator is associated with another property belonging to the same user, bypasses the guest network isolation and is granted full network access at the remote property.

### Multi-Property Claims

**Claim 18.** A multi-property smart home management system comprising:
a plurality of hub devices, each installed at a respective property and each registered to a single user account;
a cloud message broker facilitating communication between the plurality of hub devices;
a client application configured to connect to any of the plurality of hub devices and to switch between properties via a property selector interface;
wherein each hub device operates autonomously when internet connectivity is unavailable, maintaining local smart home device control, automation execution, and energy metering;
and wherein the cloud message broker enables cross-property automation rules, such that a state change detected by a first hub device at a first property can trigger an action executed by a second hub device at a second property.

### Apparatus Claims

**Claim 19.** A portable network identity device comprising:
a housing configured to plug into a standard power outlet;
a power line communication modem within the housing, configured to communicate over the electrical wiring connected to the power outlet;
a wireless access point within the housing, configured to provide WiFi connectivity to client devices;
a hardware security element within the housing, storing a private key and an X.509 certificate, the X.509 certificate identifying the device and its associated home hub;
a processor within the housing, configured to: detect whether the PLC network accessible via the power outlet is the device's home network or a foreign network; when on the home network, operate as a transparent network bridge extending the home hub's network to the device's location; when on a foreign network, execute a certificate-based authentication protocol with the foreign network's coordinator and, upon successful authentication, establish an encrypted VPN tunnel to the device's home hub, routing all traffic through the tunnel;
and an Ethernet port for wired device connectivity.

**Claim 20.** A central hub device for smart home management and network distribution comprising:
a housing configured for installation at an electrical service panel;
a power line communication modem coupled to the property's electrical wiring;
a multi-protocol wireless radio module supporting at least Zigbee and Thread protocols;
a hardware security module storing the hub device's cryptographic identity and performing cryptographic operations;
a plurality of current transformer sensor inputs for per-circuit energy metering;
an analog-to-digital converter for digitizing current measurements;
a network interface for internet connectivity;
a processor configured to simultaneously: coordinate PLC communication with satellite node devices, integrate smart home devices via cloud APIs and local wireless protocols into a unified device abstraction layer, compute per-circuit energy consumption from current transformer measurements, operate a remote desktop relay server, authenticate roaming node devices via a certificate-based protocol, and serve as a VPN gateway for roaming node devices establishing encrypted tunnels from remote locations.

---

## 9. ABSTRACT

A network system comprising a central hub device installed at an electrical service panel and portable satellite node devices that plug into power outlets. The hub distributes internet via power line communication (PLC) through existing house wiring, integrates smart home devices from multiple third-party platforms into a unified abstraction layer with cross-platform automation, monitors per-circuit energy consumption via current transformer sensors, and operates a remote desktop relay server. Each portable node carries a hardware-bound cryptographic identity. When plugged into a power outlet at a remote location, the node authenticates via a certificate-based protocol with the remote location's PLC coordinator, establishes an encrypted VPN tunnel back to the user's home hub, and routes all traffic through the tunnel, making the home hub the default gateway regardless of the node's physical location. The system supports multi-property management with independent hub operation and cross-property automation via cloud-brokered messaging.

[148 words]

---

## NOTES FOR PATENT ATTORNEY

1. **Inventor Details:** Full legal name, residence address, and citizenship to be added prior to filing.

2. **Priority Claim:** This provisional establishes priority date for a subsequent non-provisional USPTO application and for a Mexican IMPI application to be filed within 12 months under the Paris Convention.

3. **Drawings:** Ten figures are referenced throughout the specification. These should be prepared by a patent illustrator based on the descriptions in Section 6 and the corresponding sections of the detailed description.

4. **Claim Strategy:** The claims are structured to cover: (a) the system as a whole (Claims 1-3, 18, 20); (b) the methods/processes (Claims 4-5); (c) the portable node as a standalone apparatus (Claim 19); and (d) numerous dependent claims narrowing to specific implementations. The attorney should consider whether additional independent claims are warranted for the remote desktop relay integration or the energy metering as standalone inventions.

5. **Prior Art Search:** The inventor is aware of the following prior art categories that should be distinguished: HomePlug AV2/G.hn PLC standards (networking only), WiFi mesh systems (Eero, Orbi, Deco), smart home hubs (SmartThings, Hubitat, Home Assistant), VPN travel routers (GL.iNet), remote desktop software (RustDesk, TeamViewer, AnyDesk), PLC adapters (TP-Link AV, Devolo Magic), and energy monitoring systems (Sense, Emporia Vue, IoTaWatt). None of these combine the claimed elements into a single integrated system.

6. **Continuation/Divisional Strategy:** The breadth of this disclosure may warrant divisional applications separating: (a) the portable PLC identity and roaming system; (b) the unified multi-platform smart home integration; (c) the integrated energy metering with PLC distribution; and (d) the integrated remote desktop relay. The attorney should advise on optimal filing strategy.

7. **International Filing:** Beyond Mexico (IMPI), the inventor should consider PCT filing for broader international protection if the commercial plan warrants it.

8. **Trade Secret vs. Patent:** Certain implementation details (specific cloud API integration methods, specific automation rule evaluation algorithms) may be better protected as trade secrets rather than patent disclosure. The attorney should advise on what level of detail serves the claims without unnecessarily disclosing competitive know-how.

---

*This provisional patent application was drafted on March 22, 2026. The content herein is confidential and privileged. Distribution is restricted to the inventor and retained patent counsel.*

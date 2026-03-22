# Wireless Power Delivery — Integrated Residential Concept

**Date:** 2026-03-21
**Author:** BC (Kriket)
**Status:** Concept / Pre-patent exploration

## The Vision

A residential infrastructure where power AND data arrive through the same wire, and devices in the home receive both wirelessly through focused beams — no cables, no charging pads, no separate data connections.

## Architecture

### Layer 1: ISP-to-Home (Power Line Communication)

Instead of separate coax/fiber/DSL:
- ISP feeds fiber to neighborhood CFE transformer
- Coupling unit injects broadband data onto the low-voltage distribution line
- Every house on that transformer gets internet through their power outlets
- Data rides at 2-86 MHz on top of 60Hz power (OFDM modulation)

For new construction: 4-conductor cable instead of 3 (dedicated data line alongside power conductors) eliminates noise/attenuation entirely.

### Layer 2: In-Home Distribution

Any wall outlet = internet + power. HomePlug-style bridge with built-in WiFi router. Single device, any socket.

### Layer 3: Wireless Power via Wall-Mounted Phased Array

Wall-embedded antenna array (3m × 3m, hundreds of elements) delivers focused RF power beams to mapped device locations.

**Technology:** Phased array beamforming at 5.8 GHz ISM band
- Constructive interference concentrates energy at target
- Destructive interference everywhere else (safe for people)
- Rectenna receivers on devices convert RF to DC
- Beam focus: <10cm diameter at 3m distance

### Layer 4: App-Controlled Beam Mapping

1. Place device (TV, speaker, lamp, phone dock) in permanent spot
2. Open app — phone camera sees room
3. Tap device location on screen (or AR identification)
4. Transmitter array sweeps — receiver reports signal strength via BLE
5. Optimal beam pattern stored
6. Multiple simultaneous beams via spatial multiplexing

### Safety System

- Radar-based occupancy detection (same array senses reflections)
- Beam cuts in microseconds if person/pet enters beam path
- Power levels within SAR limits for each beam
- Failsafe: no beam without active receiver acknowledgment

## Business Model

Sell to housing developers for new construction in Mexico. Incremental cost of data-capable power infrastructure during construction is minimal vs separate data cabling. Leapfrogs Telmex/Izzi last-mile infrastructure in underserved areas.

## Regulatory Considerations

- **IFT (Mexico):** Regulates telecom + spectrum. BPL has specific regulations.
- **CFE:** Partnership needed for transformer-level injection
- **5.8 GHz ISM band:** Higher EIRP allowed. Need new regulatory category for "directed residential power delivery"
- **SAR limits:** Per-beam power must stay within biological safety thresholds

## Key Research Questions

1. Signal propagation on Mexican CFE power grid (60Hz, 127V/220V) — noise floor?
2. Cost of coupling unit on CFE pad-mounted transformers
3. IFT regulatory status for BPL in Mexico
4. Resonant coupling efficiency at room scale with SAR compliance
5. Building material resonant frequencies (wall as amplifier potential)

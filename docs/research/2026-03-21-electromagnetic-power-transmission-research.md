# Electromagnetic Power Transmission Research

**Date:** 2026-03-21
**Participants:** BC (Kriket) + Claude Opus 4.6
**Status:** Theoretical exploration / Pre-experimental

## Core Thesis

The current AC power grid and wireless power delivery methods may not represent the optimal configuration. Unexplored combinations of coil geometry, field topology, transmission medium, and driving frequency could produce fundamentally different results.

## Existing Technology (What Works Today)

- **Power Line Communication (PLC):** Data on AC power lines proven (HomePlug AV2, 2 Gbps, OFDM 2-86 MHz on 60Hz carrier)
- **Broadband over Power Lines (BPL):** ISP-to-home via power grid, deployed then mostly abandoned (RF interference)
- **Magnetic resonance coupling:** MIT 2007, ~40% efficiency at 2m (WiTricity commercialized)
- **RF beamforming for power:** Ossia Cota (5.8 GHz, 1W), Energous WattUp (915 MHz, 10W at 1m)
- **Qi wireless charging:** Contact-distance induction, universal standard

## BC's Integrated Concept

1. ISP injects data at neighborhood transformer (fiber-to-transformer)
2. Power + data travel on same wire to the home
3. Smart outlet/router extracts data from power line
4. Wall-embedded phased array delivers focused wireless power to mapped devices
5. App-directed beam calibration for stationary receivers (phone dock, TV, speakers, lighting)

### Beamforming Power Delivery

Instead of flooding room with magnetic field: **focused directed beams** via phased array antenna on wall.

- Array elements with individually controlled phase/amplitude
- Constructive interference at target, destructive everywhere else
- At 5.8 GHz with 3m array: beam width <10cm at 3m distance
- Rectennas on devices convert RF to DC
- Safety: radar-based occupancy detection, beam cuts in microseconds if person enters path

### Power Budget

| Device | Draw | Feasibility |
|--------|------|-------------|
| Phone charging | 5-15W | Very feasible |
| LED accent lighting | 5-20W | Very feasible |
| Smart speaker | 10-30W | Feasible |
| Soundbar | 30-50W | Feasible at short range |
| TV (55") | 80-120W | Challenging — large rectenna panel needed |
| Laptop | 45-65W | Feasible with dedicated dock receiver |

## Experimental Models

### Model 1: Counter-Rotating Bifilar Coil (SUCCESS PROBABILITY: HIGH)

Tesla's bifilar coil (US Patent 512,340) — zero inductance, high capacitance. With L≈0, resonant frequency approaches broadband. Counter-rotating magnet at 2ω relative velocity.

**Predicted output:** Capacitive discharge pulses, not sinusoidal AC. Rise times faster than mechanical rotation would predict.

**Key measurement:** Oscilloscope waveform analysis. Sub-microsecond edges from ~100 Hz mechanical system = bifilar effect confirmed.

### Model 2: Ferrofluid Resonance Chamber (SUCCESS PROBABILITY: MEDIUM-HIGH)

Ferrofluid in toroidal chamber with Rodin coil. Drive at frequency where EM wavelength in ferrofluid = Rosensweig instability wavelength (~7mm → ~1.5 GHz).

**Predicted result:** Self-organizing electromagnetic waveguide. If coupled resonance produces narrow spectral lines = MASER-like coherent microwave source from mechanical-electromagnetic coupling.

### Model 3: Liquid Metal Vortex Dynamo (SUCCESS PROBABILITY: HIGH)

GaInSn alloy (σ = 3.46×10⁶ S/m) in 30cm toroid at 30 m/s flow. Magnetic Reynolds number Rm ≈ 39 (above critical ~10-100).

**Predicted result:** Self-sustaining magnetic field (~400 Gauss) with no electrical input. Only mechanical spin. Earth's core does this. The pyramid mercury connection.

### Model 4: Piezoelectric Crystal Feedback Loop (SUCCESS PROBABILITY: MEDIUM)

Quartz crystal oscillator + bifilar coil feedback. If bifilar Q > 10 (loop gain > 1), self-oscillation without external power.

**Critical question:** Does bifilar coil Q factor sustain crystal oscillation without amplifier?

### Model 5: Diamond-Anvil Moissanite Transducer (SUCCESS PROBABILITY: LOW-MEDIUM)

SiC under extreme pressure at semiconductor-metal phase transition boundary. Simultaneously piezoelectric and conductive. EM field drives it across transition = pulsed phonon-photon-electron triple coupling.

## Unexplored Variable Space

### Coil Geometries
- Bifilar (Tesla patent) — zero inductance, capacitive
- Rodin — vortex mathematics, claimed longitudinal waves
- Möbius — non-orientable surface, undefined inside/outside
- Halbach array — one-sided field

### Media
- Ferrofluid (self-organizing), mercury/GaInSn (liquid metal dynamo)
- Salt water (Schumann resonance), plasma (self-sustaining current loop)
- Piezoelectric crystals (feedback coupling)
- Exotic: diamond, moissanite under pressure

### Rotation Configurations
- Co-rotating (DC from AC geometry?)
- Counter-rotating (2ω, novel waveform)
- Precessing/gyroscopic (helical field)
- Triple-axis Lissajous patterns

### Frequency Regimes of Interest
- Schumann 7.83 Hz (Earth resonance)
- Building material resonant frequencies (wall becomes amplifier)
- Terahertz gap (0.1-10 THz, poorly characterized)

## 3D Periodic Table Concept

Standard 2D table organized by atomic number + electron configuration. 3D reorganization using:
- Axis 1: Atomic number
- Axis 2: Electronegativity
- Axis 3: Atomic radius

Elements form a spiral. Transition metals form central cylinder. Lanthanides/actinides fit naturally inside. Reveals hidden relationships between elements that appear distant in 2D.

## Next Steps

1. Build 3D periodic table interactive visualization
2. Mathematical modeling of Model 1 (bifilar counter-rotation) waveform predictions
3. Patent landscape search for novel configurations
4. Bill of materials for bench-scale Model 3 (liquid metal dynamo)

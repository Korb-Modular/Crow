# RotatingCVs – Variable-Width Rotating LFO for Monome Crow

**Author:** Marcus Korb  
**Version:** 2.1  
**License:** MIT

RotatingCVs generates **four phase-shifted control voltages** (Out1..Out4, 90° apart) from a **master LFO**.  
- **CV1 (In1)** controls rotation speed **bipolar** (direction & rate).  
- **CV2 (In2)** controls the **active lobe width** (bandpass-like shaping) in **degrees**.  
- Outputs swing around a **global voltage offset** you can set once for all channels.  
- Choose **cosine** (smooth) or **triangle** (linear) lobes; optionally sharpen edges.

> Final script file: `RotatingCVs.lua` (this repo).  
> Key implementation lines and defaults are documented below. :contentReference[oaicite:6]{index=6}

---

## Features

- **Four outputs, 90° phase-shifted**: `channel_offsets = {0, 90, 180, 270}`. :contentReference[oaicite:7]{index=7}  
- **Width control via CV2** (degrees over the LFO phase):  
  - −5 V → **15°** (very narrow, gaps likely)  
  - 0 V  → **90°** (classic crossfade)  
  - +5 V → **360°** (very wide, strong overlap)  
  Mapping is **linear** and adjustable via `width_at_neg5`, `width_at_zero`, `width_at_pos5`. :contentReference[oaicite:8]{index=8}
- **Global output offset**: set `output_offset_volts` to move the baseline  
  (e.g., −5.0 → −5..+5 V; 0.0 → 0..+10 V). Outputs are clamped to **±10 V**. :contentReference[oaicite:9]{index=9}  
- **Lobe shapes**: `shape_mode = "cosine"` (default) or `"triangle"`, with optional `edge_exponent`. :contentReference[oaicite:10]{index=10}  
- **Smooth outputs**: per-channel `slew_time` (default 0.02 s). :contentReference[oaicite:11]{index=11}

---

## Quick Start

1. Copy `RotatingCVs.lua` to your Crow environment and run it via Druid.  
2. Patch:  
   - **In1** → CV source for speed (−5..+5 V; negative = reverse).  
   - **In2** → CV source for width (−5..+5 V).  
   - **Out1..Out4** → your destination modules (VCAs, panners, etc.).  
3. Turn **CV2** to see the transition from **narrow peaks** (gaps) to **full overlap**.

---

## Parameters (in the script)

```lua
-- Timing & smoothing
local update_interval  = 0.01  -- seconds per tick (10 ms)
local slew_time        = 0.02  -- seconds (per output)
Lower update_interval = smoother but more events; 10–20 ms is a good range. 

lua
Kopieren
Bearbeiten
-- Speed (deg/s at +5 V), bipolar via CV1
local speed_deg_per_5v = 180.0
-- Effective speed multiplier inside CV1 handler:
rotation_speed_dps = (vv / 5.0) * speed_deg_per_5v * 24
The * 24 gives you a much higher max rate while keeping intuitive scaling.
One full rotation = 360 / rotation_speed_dps seconds. 

lua
Kopieren
Bearbeiten
-- Width mapping (degrees) via CV2
local width_at_neg5 = 15.0
local width_at_zero = 90.0
local width_at_pos5 = 360.0
Linear interpolation between these three anchor points. 

lua
Kopieren
Bearbeiten
-- Shape and edges
local shape_mode    = "cosine"  -- or "triangle"
local edge_exponent = 1.0       -- >1 to sharpen
Cosine gives smooth shoulders; triangle gives linear ramps. 

lua
Kopieren
Bearbeiten
-- Output baseline (volts)
local output_offset_volts = -5.0
-- Gain mapping clamps to ±10 V internally
Use 0.0 for a 0..+10 V swing; stay mindful of the ±10 V limit. 

How Width Shaping Works
For a given channel, we compute the signed phase difference to the master phase, then apply a lobe function where the gain is non-zero only inside ±W/2:

Triangle: linear from 1 at center to 0 at ±W/2

Cosine: smooth from 1 at center to 0 at ±W/2

Outside the lobe, gain is 0 → output sits at baseline (output_offset_volts).
This is what creates gaps at narrow widths and overlap at wide widths. 

Troubleshooting
Druid shows “Event queue full”
Reduce event load by slightly increasing update_interval (e.g., 0.015–0.02),
keep print() minimal, or increase slew_time a bit to smooth fast moves. 

Too slow / too fast
Adjust speed_deg_per_5v and/or the internal multiplier (×24) to taste. 

No “gaps” at narrow widths
Ensure your CV2 really reaches near −5 V; width anchor width_at_neg5 can be reduced further (e.g., 10°) for even tighter peaks. 

Changelog
v2.1

Fixed lobe width shaping (hard zero outside ±W/2).

Added global output offset with ±10 V clamp.

Higher speed headroom via ×24 scaling in CV1.

Default shape cosine; params and structure cleaned.

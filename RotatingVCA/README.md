# Rotating CVs

## Script Description
This Lua script implements a rotating four-channel crossfade for Monome Crow. The four outputs are phase-shifted by 90° (0°, 90°, 180°, 270°). Two CV inputs control behavior at runtime, and the crossfade law can be switched between two modes.

```lua
-- Crossfade mode: "scale" (wider cos stretch) or "power" (musically optimized)
crossfade_mode = "power"
-- crossfade_mode = "scale"   -- toggle by commenting/uncommenting
```

## Inputs
- **Input 1 (CV1)** — Rotation speed (−5 V … +5 V):  
  negative = rotate left, positive = rotate right, 0 V = stop.
- **Input 2 (CV2)** — CV width/overlap (0 V … 10 V):  
  0 V = no overlap, 10 V = maximum overlap.

## Initialization
On init, all four outputs are set to −5 V with a 20 ms slew. A metro periodically calls `update()`.

## Gain Shaping
`calculate_gain()` produces a per-channel gain (0…1):

- `"scale"`: a scaled cosine for a wider, more linear blend.
- `"power"`: an exponentially shaped cosine for a more “musical” crossfade.

## Update Flow
`update_outputs()` advances the global phase based on elapsed time, derives the channel phases (0/90/180/270°), computes gains, and writes voltages to the four outputs.

## Output Voltage Range
Voltages are mapped from gain with:

```lua
local volts = gain * 10 - 5   -- scale 0–1 gain to −5 V to +5 V
```

You can change the output range by adjusting the multiplier and offset here (e.g., `gain * 8 - 4` → ±4 V, or `gain * 5` → 0…+5 V).



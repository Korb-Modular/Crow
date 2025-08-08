# Rotating VCA

## Description of the Script
The Lua script implements a rotating crossfade with four outputs for the Monome Crow. Two CV inputs control rotation speed and crossfade width, while the four outputs are each phase-shifted by 90°. The crossfade can be switched between “scale” and “power” modes.

## Initialization (`init`)
At startup, all outputs are set to –5 V with a slew time of 20 ms. CV1 continuously sets the rotation speed (–5 V to +5 V), and CV2 determines the crossfade width (0 V to 10 V). A metro triggers the update function periodically.

## `calculate_gain`
This function generates a gain value for each channel. Depending on the mode, it uses either a scaled cosine function (“scale”) or an exponentially shaped cosine curve (“power”).

## `update_outputs`
`update_outputs` uses the elapsed time to compute the new global phase, derives the phase-shifted channel phases, and writes the resulting voltages to the four outputs. The line:

```lua
local volts = gain * 10 - 5   -- scale 0–1 gain to –5 V to +5 V
```

maps each 0–1 gain to –5 V…+5 V; you can modify the multiplier (10) and offset (–5) here to change the output voltage range as needed.


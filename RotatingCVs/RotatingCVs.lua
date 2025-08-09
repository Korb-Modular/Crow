-- Rotating Crossfade with 4 outputs for Monome Crow
-- CV1: Rotation speed (–5 V to +5 V → slow rotation backward/forward)
-- CV2: Crossfade width (–5 V to +5 V → overlap amount between channels; 0 V = mid width)
-- Outputs 1–4: Rotating CV –5 V to +5 V, 90° phase shifted
-- Crossfade modes: "scale" or "power"

-- Utility functions

function clamp(val, min, max)
  return math.max(min, math.min(max, val))
end

function now()
  return time()
end

-- Configuration

local update_interval = 0.02         -- Output update rate (20 ms)
local slew_time = 0.02               -- Slew time for smooth transitions
local phase = 0                      -- Global phase (0–360°)
local last_time = 0
local rotation_speed = 0            -- Degrees per second
local bandwidth = 0                 -- Crossfade width (0.0 to 1.0)
local channel_offsets = {0, 90, 180, 270}  -- Output phase offsets

-- Rotation speed factor: degrees per second per volt
-- 0.5 → max speed = 2.5°/s at +5 V = ~144 sec per rotation (very slow)
local max_rotation_per_volt = 0.5

-- Crossfade mode: "scale" (wider cos stretch) or "power" (musically optimized)
crossfade_mode = "power"
-- crossfade_mode = "scale"

-- Initialization

function init()
  print("Rotating Crossfade Script started.")

  for i = 1, 4 do
    output[i].slew = slew_time
    output[i].volts = -5
  end

  last_time = now()

  -- CV1: Rotation speed input
  input[1].mode = 'stream'
  input[1].stream = function(volts)
    rotation_speed = clamp(volts, -5, 5) * max_rotation_per_volt
  end

  -- CV2: Crossfade bandwidth input (–5..+5 V → 0..1)
  input[2].mode = 'stream'
  input[2].stream = function(volts)
    -- Map –5..+5 V to 0..1 (0 V = 0.5)
    bandwidth = clamp((volts + 5) / 10, 0, 1)
  end

  metro.init(update_outputs, update_interval):start()
end

-- Gain calculation based on phase difference and crossfade mode

function calculate_gain(phase_diff)
  local rad = math.rad(phase_diff)
  local bw = clamp(bandwidth, 0, 1)

  if crossfade_mode == "scale" then
    -- Cosine curve stretched horizontally by bandwidth
    return math.max(0, math.cos(rad * (1 - bw)))

  elseif crossfade_mode == "power" then
    -- Cosine curve softened exponentially
    local exponent = 4 - 3.7 * bw  -- narrow (4) to wide (0.3)
    return math.max(0, math.cos(rad)) ^ exponent

  else
    -- Fallback to standard cosine
    return math.max(0, math.cos(rad))
  end
end

-- Output update loop

function update_outputs()
  local now_time = now()
  local dt = now_time - last_time
  last_time = now_time

  -- Update global phase with wrapping
  phase = (phase + rotation_speed * dt) % 360

  -- Compute output voltages for each channel
  for i = 1, 4 do
    local channel_phase = (phase - channel_offsets[i]) % 360
    local gain = calculate_gain(channel_phase)
    local volts = gain * 10 - 5   -- scale 0–1 gain to –5 V to +5 V
    output[i].volts = volts
  end
end

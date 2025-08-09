-- Rotating Crossfade with 4 outputs for Monome Crow
-- CV1: Rotation speed (–5 V to +5 V → slow rotation backward/forward)
-- CV2: Signal width (–5 V to +5 V; width at −5/0/+5 V is configurable)
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
-- Width control via CV2 (degrees of active lobe)
local width_at_neg5 = 30            -- degrees at −5 V (very narrow, small peak)
local width_at_zero = 90            -- degrees at 0 V
local width_at_pos5 = 270           -- degrees at +5 V (very wide)
local current_width = width_at_zero -- updated by CV2 in real time
local edge_exponent = 1.0           -- 1.0 = cosine; >1 = sharper peak
local channel_offsets = {0, 90, 180, 270}  -- Output phase offsets

-- Rotation speed factor: degrees per second per volt
-- 0.5 → max speed = 2.5°/s at +5 V = ~144 sec per rotation (very slow)
local max_rotation_per_volt = 0.5

-- Crossfade mode: "scale" (wider cos stretch) or "power" (musically optimized)
crossfade_mode = "power"  -- legacy; width-based shaping ignores mode
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

  -- CV2: Signal width control (–5..+5 V → width in degrees)
  input[2].mode = 'stream'
  input[2].stream = function(volts)
    current_width = width_from_cv2(volts)
  end

  metro.init(update_outputs, update_interval):start()
end

-- Gain calculation based on phase difference and crossfade mode

function calculate_gain(phase_diff)
  -- Normalize to signed angle (−180..+180) to measure closeness to channel center
  local pd = normalize_angle_deg(phase_diff)
  local W = clamp(current_width, 0.1, 359.9) -- avoid divide-by-zero and full wrap

  -- Variable-width cosine lobe: positive for |pd| < W/2, zero otherwise
  -- x = pd * pi / W ensures cos(x) crosses zero at ±W/2
  local x = math.rad(pd) * (180 / W) -- since math.rad(pd) = pd * pi/180 → x = pd * pi / W
  local g = math.max(0, math.cos(x))

  if edge_exponent and edge_exponent ~= 1.0 then
    g = g ^ edge_exponent
  end

  return g
end

-- Convert arbitrary angle to range −180..+180 degrees
function normalize_angle_deg(a)
  local x = (a + 180) % 360
  if x < 0 then x = x + 360 end
  return x - 180
end

-- Map CV2 voltage (−5..+5 V) to target lobe width in degrees
function width_from_cv2(volts)
  local v = clamp(volts, -5, 5)
  if v <= 0 then
    -- v in [−5, 0] → t in [0, 1] between width_at_neg5 and width_at_zero
    local t = (v + 5) / 5
    return width_at_neg5 + (width_at_zero - width_at_neg5) * t
  else
    -- v in (0, 5] → t in (0, 1] between width_at_zero and width_at_pos5
    local t = v / 5
    return width_at_zero + (width_at_pos5 - width_at_zero) * t
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

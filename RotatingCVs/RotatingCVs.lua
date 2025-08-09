--[[
RotatingCVs – Variable-Width Rotating LFO for Monome Crow
---------------------------------------------------------
Author: Marcus Korb

Description:
    Generates four phase-shifted CV outputs (90° apart) from a master LFO.
    LFO speed is controlled via Input 1 (–5..+5 V, bipolar speed & direction).
    Active lobe width (like a bandpass filter shape) is controlled via Input 2.
    Outputs swing around a global voltage offset, adjustable via a single parameter.
    Shape mode can be "triangle" (linear slopes) or "cosine" (smooth slopes), with
    optional edge exponent for sharper transitions.

Inputs:
    In1 (CV1) : Rotation speed control (–5..+5 V)
    In2 (CV2) : Lobe width control (–5..+5 V → narrow/mid/wide)

Outputs:
    Out1..Out4 : CV outputs, 90° phase-shifted, centered around global offset

Width Control (CV2 mapping):
    - At –5 V → narrow lobe (default: 30°) → steep edges, possible silent gaps
    - At  0 V → medium lobe (default: 90°) → standard crossfade
    - At +5 V → wide lobe (default: 270°) → strong overlap
    Mapping is linear between these three points, adjustable via:
        width_at_neg5, width_at_zero, width_at_pos5

Global Output Offset:
    output_offset_volts shifts the baseline of all outputs:
        -5.0 → swing = -5..+5 V
         0.0 → swing = 0..+10 V
        +2.0 → swing = +2..+12 V (clamped to ±10 V)

Version: 2.1
License: MIT
]]--

-- ===== Utility =====
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end

-- ===== Parameters =====
local update_interval    = 0.01     -- seconds per tick
local slew_time          = 0.02     -- seconds
local phase_deg          = 0.0      -- 0..360
local speed_deg_per_5v   = 180.0    -- deg/sec at CV1 = +5 V
local width_at_neg5      = 15.0     -- deg width at CV2 = –5 V
local width_at_zero      = 90.0     -- deg width at CV2 =  0 V
local width_at_pos5      = 360.0    -- deg width at CV2 = +5 V
local current_width      = width_at_zero
local edge_exponent      = 1.0      -- >1 sharpens edges
local shape_mode         = "cosine" -- "triangle" or "cosine"
local channel_offsets    = {0, 90, 180, 270} -- per-output phase offsets
local output_offset_volts = -5.0    -- global baseline offset (V)

-- Internal
local rotation_speed_dps = 0.0

-- ===== Helpers =====
local function normalize_pm180(a)
    local x = (a + 180.0) % 360.0
    return x - 180.0
end

local function map_width_from_cv2(v)
    local vv = clamp(v, -5.0, 5.0)
    if vv <= 0.0 then
        local t = (vv + 5.0)/5.0
        return width_at_neg5 + (width_at_zero - width_at_neg5)*t
    else
        local t = vv/5.0
        return width_at_zero + (width_at_pos5 - width_at_zero)*t
    end
end

local function gain_triangle(pd_deg, W)
    local halfW = W * 0.5
    local d = math.abs(pd_deg)
    if d >= halfW then
        return 0.0
    else
        return 1.0 - (d / halfW)
    end
end

local function gain_cosine(pd_deg, W)
    local halfW = W * 0.5
    local d = math.abs(pd_deg)
    if d >= halfW then
        return 0.0
    else
        -- scale so that cos crosses zero exactly at ±W/2
        local x = (d / halfW) * (math.pi / 2)
        return math.cos(x)
    end
end

local function lobe_gain(phase_diff_deg)
    local pd = normalize_pm180(phase_diff_deg)
    local W  = clamp(current_width, 0.1, 359.9)
    local g
    if shape_mode == "triangle" then
        g = gain_triangle(pd, W)
    else
        g = gain_cosine(pd, W)
    end
    if edge_exponent and edge_exponent ~= 1.0 then
        g = g ^ edge_exponent
    end
    return g
end

local function gain_to_volts(g)
    -- g: 0..1 → amplitude 10 Vpp, then apply offset
    local v = g * 10.0 + output_offset_volts
    return clamp(v, -10.0, 10.0) -- prevent exceeding Crow safe range
end

-- ===== Crow lifecycle =====
function init()
    print("RotatingCVs v2.1 – Width control fix + Global voltage offset")
    for i=1,4 do
        output[i].slew  = slew_time
        output[i].volts = output_offset_volts
    end

    -- CV1: Speed control
    input[1].mode   = 'stream'
    input[1].stream = function(v)
        local vv = clamp(v, -5.0, 5.0)
        rotation_speed_dps = (vv/5.0) * speed_deg_per_5v *24
    end

    -- CV2: Width control
    input[2].mode   = 'stream'
    input[2].stream = function(v)
        current_width = map_width_from_cv2(v)
    end

    metro.init(tick, update_interval):start()
end

function tick()
    phase_deg = (phase_deg + rotation_speed_dps * update_interval) % 360.0
    for i=1,4 do
        local pd   = phase_deg - channel_offsets[i]
        local g    = lobe_gain(pd)
        output[i].volts = gain_to_volts(g)
    end
end

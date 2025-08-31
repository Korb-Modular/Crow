
-- Crow: Dual AD Envelopes (0–10 V) with TXi control
-- In1 -> Env1, In2 -> Env2
-- Out1: Env1, Out2: Env1 inverted (10V - env)
-- Out3: Env2, Out4: Env2 inverted (10V - env)
-- Attack: 1–3 ms, Decay: 1–5000 ms ; both per envelope
-- TXi params:
--   1 = Attack Env1, 2 = Decay Env1, 3 = Attack Env2, 4 = Decay Env2

-- ========= helpers =========
local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end

-- Map TXi 0..10V to time ranges
local function map_attack(v)  -- 0..10V -> 0.001..0.003 s
  v = clamp(v or 0, 0, 10)
  return 0.001 + (v/10.0) * (0.003 - 0.001)
end

local function map_decay(v)   -- 0..10V -> 0.001..5.000 s
  v = clamp(v or 0, 0, 10)
  return 0.001 + (v/10.0) * (5.000 - 0.001)
end

-- Current times (seconds)
local a1, d1 = 0.002, 0.100
local a2, d2 = 0.002, 0.100

-- Rebuild all output actions from current times
local function set_actions()
  -- Non-inverted AD: 0 -> 10V in attack, back to 0 in decay
  output[1].action = ar(a1, d1, 10)
  output[3].action = ar(a2, d2, 10)

  -- Inverted AD within 0–10V:
  -- baseline 10V, fall during "attack" to 0V, then rise back to 10V during "decay"
  -- ensure the baseline is set before each trigger:
  output[2].action = to(10) >> fall(a1, 0) >> rise(d1, 10)
  output[4].action = to(10) >> fall(a2, 0) >> rise(d2, 10)
end

-- ========= init =========
function init()
  -- inputs as trigger detectors (rising edge ~1V threshold)
  input[1].mode('change', 1.0, 0.1)
  input[2].mode('change', 1.0, 0.1)

  -- outputs idle states
  output[1].volts = 0
  output[3].volts = 0
  output[2].volts = 10
  output[4].volts = 10

  set_actions()

  -- poll TXi regularly
  if ii and ii.txi then
    -- request initial reads
    for i=1,4 do ii.txi.get(i) end
    -- poll ~20 Hz
    poll = metro.init(function()
      for i=1,4 do ii.txi.get(i) end
    end, 0.05, -1)
    poll:start()
  else
    print("ii.txi not detected; using defaults.")
  end
end

-- ========= input triggers =========
input[1].change = function(state)
  if state > 0 then
    -- trigger Env1 (Out1 normal, Out2 inverted)
    output[1]()  -- ar(a1,d1,10)
    output[2]()  -- inverted sequence
  end
end

input[2].change = function(state)
  if state > 0 then
    -- trigger Env2 (Out3 normal, Out4 inverted)
    output[3]()
    output[4]()
  end
end

-- ========= TXi handling =========
-- TXi returns 0..10 (volts). Update times and rebuild actions.
if ii and ii.txi then
  ii.txi.event = function(ch, v)
    if ch == 1 then a1 = map_attack(v); set_actions()
    elseif ch == 2 then d1 = map_decay(v); set_actions()
    elseif ch == 3 then a2 = map_attack(v); set_actions()
    elseif ch == 4 then d2 = map_decay(v); set_actions()
    end
  end
end

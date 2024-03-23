-- ┌───┐                ┌───┐ --
-- │ ┌─┘ ┌─────┐┌─────┐ └─┐ │ --
-- │ │   │ ┌───┘│ ╶───┤   │ │ --
-- │ │   │ ├───┐└───┐ │   │ │ --
-- │ │   │ └─╴ │┌───┘ │   │ │ --
-- │ └─┐ └─────┘└─────┘ ┌─┘ │ --
-- └───┘                └───┘ --
---@module  "Animation Blending Library (Lite Edition)" <GSAnimBlend-Lite>
---@version v1.9.10-lite
---@see     GrandpaScout @ https://github.com/GrandpaScout
-- A much lighter version of the base GSAnimBlend library.
--
-- Adds prewrite-like animation blending to the rewrite.
-- Also includes the ability to modify how the blending works per-animation with curves.
--
-- This library is fully documented. If you use Sumneko's Lua Language server, you will get
-- descriptions of each function, method, and field in this library.

local ID = "GSAnimBlend-Lite"
local VER = "1.9.10+lite"
local FIG = {"0.1.0-rc.14", "0.1.4"}

--|================================================================================================================|--
--|=====|| SCRIPT ||===============================================================================================|--
--||==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==||--

-- Localize Lua basic
local getmetatable = getmetatable
local setmetatable = setmetatable
local error = error
local next = next
local ipairs = ipairs
local pairs = pairs
local rawset = rawset
local tostring = tostring
-- Localize Lua math
local m_cos = math.cos
local m_max = math.max
local m_sin = math.sin
local m_sqrt = math.sqrt
local m_pi = math.pi
local m_1s2pi = m_pi * 0.5
local m_2s3pi = m_pi / 1.5
local m_4s9pi = m_pi / 2.25
-- Localize Figura globals
local animations = animations
local figuraMetatables = figuraMetatables
local events = events
-- Localize current environment
local _ENV = _ENV --[[@as _G]]

---@diagnostic disable: duplicate-set-field, duplicate-doc-field

---Any fields, functions, and methods injected by this library will be prefixed with
---**[GS&nbsp;AnimBlend&nbsp;Library]** in their description.
---
---If this library is required without being stored to a variable, it will automatically set up the blending features.  
---If this library is required *and* stored to a variable, it will also contain extra tools.
---```lua
---require "···"
--- -- OR --
---local anim_blend = require "···"
---```
---@class Lib.GS.AnimBlendLite
---This library's perferred ID.
---@field _ID string
---This library's version.
---@field _VERSION string
local this = {}
local thismt = {
  __type = ID,
  __metatable = false,
  __index = {
    _ID = ID,
    _VERSION = VER
  }
}

-- Create private space for blending trigger.
-- This is done non-destructively so other scripts may do this as well.
if not getmetatable(_ENV) then setmetatable(_ENV, {}) end

-----======================================= VARIABLES ========================================-----

local _ENVMT = getmetatable(_ENV)

---Contains the data required to make animation blending for each animation.
---@type {[Animation]: Lib.GS.AnimBlendLite.AnimData}
local animData = {}

---Contains the currently blending animations.
---@type {[Animation]?: true}
local blending = {}

this.animData = animData
this.blending = blending

local ticker = 0
local last_delta = 0
local allowed_contexts = {
  RENDER = true,
  FIRST_PERSON = true,
  OTHER = true
}


-----=================================== PREPARE ANIMATIONS ===================================-----

-- This will at least catch players running at around 30 fps.
-- Any lower and their computer is already having trouble, they don't need the blending.
local tPass = 0.037504655

local blendCommand = [[getmetatable(_ENV).GSLib_triggerBlend(%q)]]

_ENVMT.GSLib_triggerBlend = setmetatable({}, {
  __call = function(self, id) self[id]() end
})

local animNum = 0
for _, anim in ipairs(animations:getAnimations()) do
  local blend = anim:getBlend()
  local len = anim:getLength()
  len = len > tPass and len or false
  local tID = "blendAnim_" .. animNum

  animData[anim] = {
    blendTimeIn = 0,
    blendTimeOut = 0,
    blend = blend,
    length = len,
    triggerId = tID,
    curve = nil
  }

  _ENVMT.GSLib_triggerBlend[tID] = function() if anim:getLoop() == "ONCE" then anim:stop() end end

  if len then anim:newCode(len - tPass, blendCommand:format(tID)) end

  animNum = animNum + 1
end


-----============================ PREPARE METATABLE MODIFICATIONS =============================-----

local animation_mt = figuraMetatables.Animation
local animationapi_mt = figuraMetatables.AnimationAPI

local ext_Animation = next(animData)
if not ext_Animation then
  error(
    "No animations have been found!\n" ..
    "This library cannot build its functions without an animation to use.\n" ..
    "Create an animation or stop this library from running to fix the error."
  )
end

-- Check for conflicts
if ext_Animation.blendTime then
  local path = tostring(ext_Animation.blendTime):match("^function: (.-):%d+%-%d+$")
  error(
    "Conflicting script [" .. path .. "] found!\n" ..
    "Remove the other script or this script to fix the error."
  )
end

local _animationIndex = animation_mt.__index
local _animationNewIndex = animation_mt.__newindex or rawset
local _animationapiIndex = animationapi_mt.__index

local animPlay = ext_Animation.play
local animStop = ext_Animation.stop
local animPause = ext_Animation.pause
local animRestart = ext_Animation.restart
local animBlend = ext_Animation.blend
local animLength = ext_Animation.length
local animGetPlayState = ext_Animation.getPlayState
local animGetBlend = ext_Animation.getBlend
local animIsPlaying = ext_Animation.isPlaying
local animIsPaused = ext_Animation.isPaused
local animNewCode = ext_Animation.newCode
local animapiGetPlaying = animations.getPlaying

---Contains the old functions, just in case you need direct access to them again.
this.oldF = {
  play = animPlay,
  stop = animStop,
  pause = animPause,
  restart = animRestart,

  getBlend = animGetBlend,
  getPlayState = animGetPlayState,
  isPlaying = animIsPlaying,
  isPaused = animIsPaused,

  setBlend = ext_Animation.setBlend,
  setLength = ext_Animation.setLength,
  setPlaying = ext_Animation.setPlaying,

  blend = animBlend,
  length = animLength,
  playing = ext_Animation.playing,

  api_getPlaying = animapiGetPlaying
}


-----==================================== CALLBACKS CURVES ====================================-----

---Contains custom blending curves.
---
---These callbacks change the curve used when blending.
local curves = {}

---A callback that uses the `linear` easing method to blend.
---@param x number
---@return number result
function curves.linear(x) return x end

-- I planned to add easeOutIn curves but I'm lazy. I'll do it if people request it.

---A callback that uses the [`easeInSine`](https://easings.net/#easeInSine) easing method to blend.
---@param x number
---@return number result
function curves.easeInSine(x) return 1 - m_cos(x * m_hpi) end

---A callback that uses the [`easeOutSine`](https://easings.net/#easeOutSine) easing method to blend.
---@param x number
---@return number result
function curves.easeOutSine(x) return m_sin(x * m_1s2pi) end

---A callback that uses the [`easeInOutSine`](https://easings.net/#easeInOutSine) easing method to blend.
---@param x number
---@return number result
function curves.easeInOutSine(x) return (m_cos(x * m_pi) - 1) * -0.5 end

---A callback that uses the [`easeInQuad`](https://easings.net/#easeInQuad) easing method to blend.
---@param x number
---@return number result
function curves.easeInQuad(x) return x ^ 2 end

---A callback that uses the [`easeOutQuad`](https://easings.net/#easeOutQuad) easing method to blend.
---@param x number
---@return number result
function curves.easeOutQuad(x) return 1 - (1 - x) ^ 2 end

---A callback that uses the [`easeInOutQuad`](https://easings.net/#easeInOutQuad) easing method to blend.
---@param x number
---@return number result
function curves.easeInOutQuad(x) return x < 0.5 and (2 * x ^ 2) or (1 - (-2 * x + 2) ^ 2 * 0.5) end

---A callback that uses the [`easeInCubic`](https://easings.net/#easeInCubic) easing method to blend.
---@param x number
---@return number result
function curves.easeInCubic(x) return x ^ 3 end

---A callback that uses the [`easeOutCubic`](https://easings.net/#easeOutCubic) easing method to blend.
---@param x number
---@return number result
function curves.easeOutCubic(x) return 1 - (1 - x) ^ 3 end

---A callback that uses the [`easeInOutCubic`](https://easings.net/#easeInOutCubic) easing method to blend.
---@param x number
---@return number result
function curves.easeInOutCubic(x) return x < 0.5 and (4 * x ^ 3) or (1 - (-2 * x + 2) ^ 3 * 0.5) end

---A callback that uses the [`easeInQuart`](https://easings.net/#easeInQuart) easing method to blend.
---@param x number
---@return number result
function curves.easeInQuart(x) return x ^ 4 end

---A callback that uses the [`easeOutQuart`](https://easings.net/#easeOutQuart) easing method to blend.
---@param x number
---@return number result
function curves.easeOutQuart(x) return 1 - (1 - x) ^ 4 end

---A callback that uses the [`easeInOutQuart`](https://easings.net/#easeInOutQuart) easing method to blend.
---@param x number
---@return number result
function curves.easeInOutQuart(x) return x < 0.5 and (8 * x ^ 4) or (1 - (-2 * x + 2) ^ 4 * 0.5) end

---A callback that uses the [`easeInQuint`](https://easings.net/#easeInQuint) easing method to blend.
---@param x number
---@return number result
function curves.easeInQuint(x) return x ^ 5 end

---A callback that uses the [`easeOutQuint`](https://easings.net/#easeOutQuint) easing method to blend.
---@param x number
---@return number result
function curves.easeOutQuint(x) return 1 - (1 - x) ^ 5 end

---A callback that uses the [`easeInOutQuint`](https://easings.net/#easeInOutQuint) easing method to blend.
---@param x number
---@return number result
function curves.easeInOutQuint(x) return x < 0.5 and (16 * x ^ 5) or (1 - (-2 * x + 2) ^ 5 * 0.5) end

---A callback that uses the [`easeInExpo`](https://easings.net/#easeInExpo) easing method to blend.
---@param x number
---@return number result
function curves.easeInExpo(x) return x == 0 and 0 or 2 ^ (10 * x - 10) end

---A callback that uses the [`easeOutExpo`](https://easings.net/#easeOutExpo) easing method to blend.
---@param x number
---@return number result
function curves.easeOutExpo(x) return x == 1 and 1 or 1 - 2 ^ (-10 * x) end

---A callback that uses the [`easeInOutExpo`](https://easings.net/#easeInOutExpo) easing method to blend.
---@param x number
---@return number result
function curves.easeInOutExpo(x)
  return (x == 0 or x == 1) and x
    or (x < 0.5) and 2 ^ (20 * x - 10) * 0.5
    or (2 - 2 ^ (-20 * x + 10)) * 0.5
end

---A callback that uses the [`easeInCirc`](https://easings.net/#easeInCirc) easing method to blend.
---@param x number
---@return number result
function curves.easeInCirc(x) return 1 - m_sqrt(1 - x ^ 2) end

---A callback that uses the [`easeOutCirc`](https://easings.net/#easeOutCirc) easing method to blend.
---@param x number
---@return number result
function curves.easeOutCirc(x) return m_sqrt(1 - (x - 1) ^ 2) end

---A callback that uses the [`easeInOutCirc`](https://easings.net/#easeInOutCirc) easing method to blend.
---@param x number
---@return number result
function curves.easeInOutCirc(x)
  return x < 0.5 and ((1 - m_sqrt(1 - (2 * x) ^ 2)) * 0.5) or ((m_sqrt(1 - (-2 * x + 2) ^ 2) + 1) * 0.5)
end

---A callback that uses the [`easeInBack`](https://easings.net/#easeInBack) easing method to blend.
---@param x number
---@return number result
function curves.easeInBack(x) return 2.70158 * x ^ 3 - 1.70158 * x ^ 2 end

---A callback that uses the [`easeOutBack`](https://easings.net/#easeOutBack) easing method to blend.
---@param x number
---@return number result
function curves.easeOutBack(x)
  local xm1 = x - 1
  return 1 + 2.70158 * xm1 ^ 3 + 1.70158 * xm1 ^ 2
end

---A callback that uses the [`easeInOutBack`](https://easings.net/#easeInOutBack) easing method to blend.
---@param x number
---@return number result
function curves.easeInOutBack(x)
  local x2 = x * 2
  return x < 0.5
    and (x2 ^ 2 * (3.5949095 * x2 - 2.5949095)) * 0.5
    or ((x2 - 2) ^ 2 * (3.5949095 * (x2 - 2) + 2.5949095) + 2) * 0.5
end

---A callback that uses the [`easeInElastic`](https://easings.net/#easeInElastic) easing method to blend.
---@param x number
---@return number result
function curves.easeInElastic(x)
  return (x == 0 or x == 1) and (x) or (-(2 ^ (10 * x - 10)) * m_sin((x * 10 - 10.75) * m_2s3pi))
end

---A callback that uses the [`easeOutElastic`](https://easings.net/#easeOutElastic) easing method to blend.
---@param x number
---@return number result
function curves.easeOutElastic(x)
  return (x == 0 or x == 1) and (x) or (2 ^ (-10 * x) * m_sin((x * 10 - 0.75) * m_2s3pi) + 1)
end

---A callback that uses the [`easeInOutElastic`](https://easings.net/#easeInOutElastic) easing method to blend.
---@param x number
---@return number result
function curves.easeInOutElastic(x)
  return (x == 0 or x == 1) and x
    or (x < 0.5) and -(2 ^ (x * 20 - 10) * m_sin((x * 20 - 11.125) * m_4s9pi)) * 0.5
    or (2 ^ (x * -20 + 10) * m_sin((x * 20 - 11.125) * m_4s9pi)) * 0.5 + 1
end

---A callback that uses the [`easeInBounce`](https://easings.net/#easeInBounce) easing method to blend.
---@param x number
---@return number result
function curves.easeInBounce(x)
  return 1 - (
    (x < 1 / 2.75) and 7.5625 * x ^ 2
    or (x < 2 / 2.75) and 7.5625 * (x - 1.5 / 2.75) ^ 2 + 0.75
    or (x < 2.5 / 2.75) and 7.5625 * (x - 2.25 / 2.75) ^ 2 + 0.9375
    or 7.5625 * (x - 2.625 / 2.75) ^ 2 + 0.984375
  )
end

---A callback that uses the [`easeOutBounce`](https://easings.net/#easeOutBounce) easing method to blend.
---@param x number
---@return number result
function curves.easeOutBounce(x)
  return (x < 1 / 2.75) and 7.5625 * x ^ 2
  or (x < 2 / 2.75) and 7.5625 * (x - 1.5 / 2.75) ^ 2 + 0.75
  or (x < 2.5 / 2.75) and 7.5625 * (x - 2.25 / 2.75) ^ 2 + 0.9375
  or 7.5625 * (x - 2.625 / 2.75) ^ 2 + 0.984375
end

---A callback that uses the [`easeInOutBounce`](https://easings.net/#easeInOutBounce) easing method to blend.
---@param x number
---@return number result
function curves.easeInOutBounce(x)
  local s = x < 0.5 and -1 or 1
  x = x < 0.5 and (1 - 2 * x) or (2 * x - 1)
  -- What the fuck. (Lite Edition)
  return (1 + s * (
    (x < 1 / 2.75) and 7.5625 * x ^ 2
    or (x < 2 / 2.75) and 7.5625 * (x - 1.5 / 2.75) ^ 2 + 0.75
    or (x < 2.5 / 2.75) and 7.5625 * (x - 2.25 / 2.75) ^ 2 + 0.9375
    or 7.5625 * (x - 2.625 / 2.75) ^ 2 + 0.984375
  )) * 0.5
end

---The default curve used by this library. This is used when no other curve is being used.
---@type string
this.defaultCurve = "linear"
this.curves = curves


-----===================================== SET UP LIBRARY =====================================-----

---Causes a blending event to happen.
---
---If `time`, `from`, or `to` are `nil`, they will take from the animation's data to determine this
---value.
---
---One of `from` or `to` *must* be set.
---
---If `starting` is given, it will be used instead of the guessed value from the data given.
---@param anim Animation
---@param time? number
---@param from? number
---@param to? number
---@param starting? boolean
---@return Lib.GS.AnimBlendLite.BlendState
function this.blend(anim, time, from, to, starting)
  local data = animData[anim]
  local dataBlend = data.blend
  local _from = from or dataBlend

  if starting == nil then starting = _from < (to or dataBlend) end

  data.state = {
    time = 0,
    max = time or (starting and data.blendTimeIn or data.blendTimeOut),

    from = from or false,
    to = to or false,

    callback = curves[data.curve] or curves[this.defaultCurve],

    paused = false,
    starting = starting
  }

  blending[anim] = true

  animBlend(anim, _from)
  animPlay(anim)
  if starting then anim:setTime(anim:getOffset()) end
  animPause(anim)

  return blendState
end


-----===================================== BLENDING LOGIC =====================================-----

events.TICK:register(function() ticker = ticker + 1 end, "GSAnimBlendLite:Tick_TimeTicker")

events.RENDER:register(function(delta, ctx)
  if not allowed_contexts[ctx] or (delta == last_delta and ticker == 0) then return end
  local elapsed_time = ticker + (delta - last_delta)
  ticker = 0
  for anim in pairs(blending) do
    local data = animData[anim]
    local state = data.state
    if not state.paused then
      state.time = state.time + elapsed_time

      if state.time > state.max or (animGetPlayState(anim) == "STOPPED") then
        (state.starting and animPlay or animStop)(anim)
        animBlend(anim, state.to or data.blend)
        blending[anim] = nil
      else
        local from = state.from or data.blend
        animBlend(anim, from + ((state.to or data.blend) - from) * state.callback(state.time / state.max))
      end
    end
  end
  last_delta = delta
end, "GSAnimBlendLite:Render_UpdateBlendStates")


-----================================ METATABLE MODIFICATIONS =================================-----

---===== FIELDS =====---

local animationGetters = {}
local animationSetters = {}

function animationGetters:blendCurve() return animData[self].curve end
function animationSetters:blendCurve(value)
  animData[self].curve = curves[value] and value or nil
end


---===== METHODS =====---

local animationMethods = {}

function animationMethods:play()
  if blending[self] then
    local state = animData[self].state
    if state.paused then
      state.paused = false
      return self
    elseif state.starting then
      return self
    end

    animStop(self)
    this.blend(self, state.time, animGetBlend(self), nil, true)
    return self
  elseif animData[self].blendTimeIn == 0 or animGetPlayState(self) ~= "STOPPED" then
    return animPlay(self)
  end

  this.blend(self, nil, 0, nil, true)
  return self
end

function animationMethods:stop()
  if blending[self] then
    local state = animData[self].state
    if not state.starting then return self end

    this.blend(self, state.time, animGetBlend(self), 0, false)
    return self
  elseif animData[self].blendTimeOut == 0 or animGetPlayState(self) == "STOPPED" then
    return animStop(self)
  end

  this.blend(self, nil, nil, 0, false)
  return self
end

function animationMethods:pause()
  if blending[self] then
    animData[self].state.paused = true
    return self
  end

  return animPause(self)
end

function animationMethods:restart(blend)
  if blend then
    animStop(self)
    this.blend(self, nil, 0, nil, true)
  elseif blending[self] then
    animBlend(self, animData[self].blend)
    blending[self] = nil
  else
    animRestart(self)
  end

  return self
end


---===== GETTERS =====---

function animationMethods:getBlendTime()
  local data = animData[self]
  return data.blendTimeIn, data.blendTimeOut
end

function animationMethods:isBlending() return not not blending[self] end
function animationMethods:getBlend() return animData[self].blend end

function animationMethods:getPlayState()
  return blending[self] and (animData[self].state.paused and "PAUSED" or "PLAYING") or animGetPlayState(self)
end

function animationMethods:isPlaying()
  return blending[self] and not animData[self].state.paused or animIsPlaying(self)
end

function animationMethods:isPaused()
  return (not blending[self] or animData[self].state.paused) and animIsPaused(self)
end


---===== SETTERS =====---

function animationMethods:setBlendTime(time_in, time_out)
  if time_in == nil then time_in = 0 end

  animData[self].blendTimeIn = m_max(time_in, 0)
  animData[self].blendTimeOut = m_max(time_out or time_in, 0)
  return self
end

function animationMethods:setCurve(curve)
  animData[self].curve = curves[curve] and curve or nil
  return self
end
animationMethods.setOnBlend = animationMethods.setCurve

function animationMethods:setBlend(weight)
  if weight == nil then weight = 0 end

  animData[self].blend = weight
  return blending[self] and self or animBlend(self, weight)
end

function animationMethods:setLength(len)
  if len == nil then len = 0 end

  local data = animData[self]
  if data.length then animNewCode(self, data.length, "") end

  data.length = len > tPass and len or false

  if data.length then animNewCode(self, data.length - tPass, blendCommand:format(data.triggerId)) end
  return animLength(self, len)
end

function animationMethods:setPlaying(state) return state and self:play() or self:stop() end


---===== CHAINED =====---

animationMethods.blendTime = animationMethods.setBlendTime
animationMethods.curve = animationMethods.setCurve
animationMethods.onBlend = animationMethods.setCurve
animationMethods.blend = animationMethods.setBlend
animationMethods.length = animationMethods.setLength
animationMethods.playing = animationMethods.setPlaying


---===== METAMETHODS =====---

function animation_mt:__index(key)
  if animationGetters[key] then
    return animationGetters[key](self)
  elseif animationMethods[key] then
    return animationMethods[key]
  else
    return _animationIndex(self, key)
  end
end

function animation_mt:__newindex(key, value)
  if animationSetters[key] then
    animationSetters[key](self, value)
  else
    _animationNewIndex(self, key, value)
  end
end


-----============================== ANIMATION API MODIFICATIONS ===============================-----

if animationapi_mt then
  local apiMethods = {}

  function apiMethods:getPlaying(ignore_blending)
    if ignore_blending then return animapiGetPlaying(animations) end
    local anims = {}
    for _, anim in ipairs(animations:getAnimations()) do
      if anim:isPlaying() then anims[#anims+1] = anim end
    end

    return anims
  end

  function animationapi_mt:__index(key) return apiMethods[key] or _animationapiIndex(self, key) end
end


do return setmetatable(this, thismt) end


--|==================================================================================================================|--
--|=====|| DOCUMENTATION ||==========================================================================================|--
--||=:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:=:==:=:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:==:=||--

---@diagnostic disable: duplicate-set-field, duplicate-doc-field, duplicate-doc-alias
---@diagnostic disable: missing-return, unused-local, lowercase-global, unreachable-code

---@class Lib.GS.AnimBlendLite.AnimData
---The blending-in time of this animation in ticks.
---@field blendTimeIn number
---The blending-out time of this animation in ticks.
---@field blendTimeOut number
---The faked blend weight value of this animation.
---@field blend number
---Where in the timeline the stop instruction is placed.  
---If this is `false`, there is no stop instruction due to length limits.
---@field length number|false
---The id for this animation's blend trigger
---@field triggerId string
---The callback function this animation will call every frame while it is blending.
---@field curve? Lib.GS.AnimBlendLite.curve
---The active blend state.
---@field state? Lib.GS.AnimBlendLite.BlendState

---@class Lib.GS.AnimBlendLite.BlendState
---The amount of time this blend has been running for in ticks.
---@field time number
---The maximum time this blend will run in ticks.
---@field max number|false
---The starting blend weight.
---@field from number|false
---The ending blend weight.
---@field to number|false
---The callback to call each blending frame.
---@field callback Lib.GS.AnimBlendLite.blendCallback
---Determines if this blend is paused.
---@field paused boolean
---Determines if this blend is starting or ending an animation.
---@field starting boolean

---@alias Lib.GS.AnimBlendLite.blendCallback fun(x: number): (result: number)

---@alias Lib.GS.AnimBlendLite.curve string
---| "linear"           # The default blending curve. Goes from 0 to 1 without any fancy stuff.
---| "easeInSine"       # [Learn More...](https://easings.net/#easeInSine)
---| "easeOutSine"      # [Learn More...](https://easings.net/#easeOutSine)
---| "easeInOutSine"    # [Learn More...](https://easings.net/#easeInOutSine)
---| "easeInQuad"       # [Learn More...](https://easings.net/#easeInQuad)
---| "easeOutQuad"      # [Learn More...](https://easings.net/#easeOutQuad)
---| "easeInOutQuad"    # [Learn More...](https://easings.net/#easeInOutQuad)
---| "easeInCubic"      # [Learn More...](https://easings.net/#easeInCubic)
---| "easeOutCubic"     # [Learn More...](https://easings.net/#easeOutCubic)
---| "easeInOutCubic"   # [Learn More...](https://easings.net/#easeInOutCubic)
---| "easeInQuart"      # [Learn More...](https://easings.net/#easeInQuart)
---| "easeOutQuart"     # [Learn More...](https://easings.net/#easeOutQuart)
---| "easeInOutQuart"   # [Learn More...](https://easings.net/#easeInOutQuart)
---| "easeInQuint"      # [Learn More...](https://easings.net/#easeInQuint)
---| "easeOutQuint"     # [Learn More...](https://easings.net/#easeOutQuint)
---| "easeInOutQuint"   # [Learn More...](https://easings.net/#easeInOutQuint)
---| "easeInExpo"       # [Learn More...](https://easings.net/#easeInExpo)
---| "easeOutExpo"      # [Learn More...](https://easings.net/#easeOutExpo)
---| "easeInOutExpo"    # [Learn More...](https://easings.net/#easeInOutExpo)
---| "easeInCirc"       # [Learn More...](https://easings.net/#easeInCirc)
---| "easeOutCirc"      # [Learn More...](https://easings.net/#easeOutCirc)
---| "easeInOutCirc"    # [Learn More...](https://easings.net/#easeInOutCirc)
---| "easeInBack"       # [Learn More...](https://easings.net/#easeInBack)
---| "easeOutBack"      # [Learn More...](https://easings.net/#easeOutBack)
---| "easeInOutBack"    # [Learn More...](https://easings.net/#easeInOutBack)
---| "easeInElastic"    # [Learn More...](https://easings.net/#easeInElastic)
---| "easeOutElastic"   # [Learn More...](https://easings.net/#easeOutElastic)
---| "easeInOutElastic" # [Learn More...](https://easings.net/#easeInOutElastic)
---| "easeInBounce"     # [Learn More...](https://easings.net/#easeInBounce)
---| "easeOutBounce"    # [Learn More...](https://easings.net/#easeOutBounce)
---| "easeInOutBounce"  # [Learn More...](https://easings.net/#easeInOutBounce)

---@class Animation
---#### [GS AnimBlend Library (Lite)]
---The curve that should be used while the animation is blending.
---
---If this is `nil`, it will default to the library's default curve.
---@field blendCurve? Lib.GS.AnimBlendLite.curve
local Animation


---===== METHODS =====---

---#### [GS AnimBlend Library]
---Starts this animation from the beginning, even if it is currently paused or playing.
---
---If `blend` is set, it will also restart with a blend.
function Animation:restart(blend) end


---===== GETTERS =====---

---#### [GS AnimBlend Library]
---Gets the blending times of this animation in ticks.
---@return number, number
function Animation:getBlendTime() end

---#### [GS AnimBlend Library]
---Gets if this animation is currently blending.
---@return boolean
function Animation:isBlending() end


---===== SETTERS =====---

---#### [GS AnimBlend Library]
---Sets the blending time of this animation in ticks.
---
---If two values are given, the blending in and out times are set respectively.
---@generic self
---@param self self
---@param time_in? number
---@param time_out? number
---@return self
function Animation:setBlendTime(time_in, time_out) end

---#### [GS AnimBlend Library (Lite)]
---Sets the blending curve of this animation.
---@generic self
---@param self self
---@param curve? Lib.GS.AnimBlendLite.curve
---@return self
function Animation:setCurve(curve) end

---#### [GS AnimBlend Library (Lite)]
---Alias of `<Animation>:setCurve`.
---> ***
---> Sets the blending curve of this animation.
---> ***
---@generic self
---@param self self
---@param curve? Lib.GS.AnimBlendLite.curve
---@return self
function Animation:setOnBlend(curve) end


---===== CHAINED =====---

---#### [GS AnimBlend Library]
---Sets the blending time of this animation in ticks.
---
---If two values are given, the blending in and out times are set respectively.
---@generic self
---@param self self
---@param time_in? number
---@param time_out? number
---@return self
function Animation:blendTime(time_in, time_out) end

---#### [GS AnimBlend Library (Lite)]
---Sets the blending curve of this animation.
---@generic self
---@param self self
---@param curve? Lib.GS.AnimBlendLite.curve
---@return self
function Animation:curve(curve) end

---#### [GS AnimBlend Library (Lite)]
---Alias of `<Animation>:curve`.
---> ***
---> Sets the blending curve of this animation.
---> ***
---@generic self
---@param self self
---@param curve? Lib.GS.AnimBlendLite.curve
---@return self
function Animation:onBlend(curve) end


---@class AnimationAPI
local AnimationAPI


---===== GETTERS =====---

---#### [GS AnimBlend Library]
---Gets an array of every playing animation.
---
---Set `ignore_blending` to ignore animations that are currently blending.
---@param ignore_blending? boolean
---@return Animation[]
function AnimationAPI:getPlaying(ignore_blending) end

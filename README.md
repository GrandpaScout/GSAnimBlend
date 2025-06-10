# `❰GSAnimBlend❱` Animation Blending
This library adds blending to the start and end of Figura animations to create smoother transitions.

&nbsp;
## Installation
To install this library:
* Download this repository by pressing the big `<> Code` button and clicking *Download ZIP*.
* Open the `.zip` file it gives you and open the `script` folder
* Pick the version of this library you want to use, open it, and put the `GSAnimBlend.lua` file in your avatar.

> [!NOTE]  
> The **Lite** and **Tiny** versions of GSAnimBlend are *not* actively being worked on.  
> They may not work as intended and may have issues that will not be resolved at the moment.
>
> An update/replacement is planned for a later date.

&nbsp;
## Simple Usage
To use the basic features of this library, simply require it.
```lua
require("GSAnimBlend")
```

Once you have required the library, simply use the `:setBlendTime()` method to change how long the blending is on an
animation. This method expects one or two times in ticks. (1/20ths of a second.)  
The default value is `0` so you have to use this method if you want an animation to blend.
```lua
animations.MyModel.MyAnimation:setBlendTime(5)     -- Blending in/out set to the same time
animations.MyModel.MyAnimation:setBlendTime(5, 10) -- Blending in/out set to different times.
```
You can also change *how* blending happens with the `:setBlendCurve()` method.
```lua
animations.MyModel.MyAnimation:setBlendCurve("linear")
animations.MyModel.MyAnimation:setBlendCurve("easeInSine")
animations.MyModel.MyAnimation:setBlendCurve("easeOutBack")
animations.MyModel.MyAnimation:setBlendCurve("easeInOutCubic")
animations.MyModel.MyAnimation:setBlendCurve("smoothstep")
```

&nbsp;
## Advanced Usage
To use more advanced features of the library, require it to a variable.
```lua
local GSBlend = require("GSAnimBlend")
```

&nbsp;
### Blending Curves
Blending curves allow you to change the "velocity" of a blend by using different easings.

Blending curves are defined by a function that takes in the blending progress of a blend as a number 0-1 and outputs a
*modified* blending progress of that blend as any finite number. While the output number can be any finite number, it is
recommended to return 0 when the input is 0 and 1 when the input is 1 to keep things smooth.

GSAnimBlend stores all of its premade blending curves in `GSBlend.curve`.

By default, all animations use the linear curve as described by this function:
```lua
local function linear(x)
  return x
end
```

An example curve that blends in, out, then back in again.
```lua
local function wave(x)
  return (math.cos(x * math.pi * 3) - 1) / -2
end

animations.MyModel.MyAnimation:setBlendCurve(wave)
```

&nbsp;
### Blending Callbacks
Blending callbacks allow you to change what happens while an animtion is blending.  
The default blending callback simply applies the blend weights of the blend to the blending animation and nothing else.

GSAnimBlend stores all of its premade blending callbacks in `GSBlend.callback`.

By default, all animations will use this blending callback:
```lua
local animBlend = GSBlend.oldF.blend

local function base(state, data)
  animBlend(state.anim, math.lerp(state.from, state.to, state.progress))
end
```

Blending callbacks need access to the default Figura implementations of Animation methods to work properly, which
GSAnimBlend provides at `GSBlend.oldF`.

> [!TIP]  
> You can explore GSAnimBlend's library table with Figura's built in repl command.
> ```lua
> /figura run GSBlend = require("GSAnimBlend")
> /figura run printTable(GSBlend)
> /figura run printTable(GSBlend.oldF)
> ```

`state` is an object that contains information that is immediately useful to blending callbacks. It is updated every
frame before the blending callback is run.  
While this object is not read-only, it is not recommended to change anything in the state unless you know what you are
doing.
```ts
interface CallbackState {
  anim: Animation     // The animation that is blending.
  time: number        // How long the blend has been running.
  max: number         // The max time this blend will run for.
  progress: number    // The modified progress as a percentage. (See Blending Curves.)
  rawProgress: number // The progress as a raw percentage.
  from: number        // The starting blend weight.
  to: number          // The ending blend weight.
  starting: boolean   // Whether this blend is starting or stopping the animation.
  done: boolean       // If this is true, the blend is finished, do cleanup.
}
```

`data` is an object that contains more internal information about the animation itself such as its current blending
curve or its current overrall blending state.
```ts
interface AnimData {
  blendTimeIn: number    // How long a blend-in lasts.
  blendTimeOut: number   // How long a blend-out lasts.
  blend: number          // The faked blend weight of this animation.
  blendSane: number      // The preferred blend weight of this animation.
  length: number | false // The length of this animation. False if length isn't finite.
  triggerId: number      // The trigger id of this animation. Used internally.
  startFunc?: function   // The instruction keyframe that was at 0.0s.
  endFunc?: function     // The instruction keyframe that was at the end of the animation.
  startSource?: string   // The source of the keyframe that was at 0.0s.
  endSource?: string     // The source of the keyframe that was at the end of the animation.
  callback?: function    // The blending callback this animation uses if any.
  curve?: function       // The blending curve this animation uses if any.
  state?: BlendState     // The current/last overrall blending state.
}

interface BlendState {
  time: number         // How long this blend has been going for.
  max: number | false  // The max time of this blend. If false, uses one of blendTimeIn/Out.
  from: number | false // The blend weight to blend in from. If false, uses blendSane.
  to: number | false   // The blend weight to blend in to. If false, uses blendSane.
  callback: function   // The blending callback this blend will use.
  curve: function      // The blending curve this blend will use.
  callbackState: CallbackState // The callback state to send to the blending callback.
  paused: boolean      // Whether this blend has been paused by :pause().
  starting: boolean    // Whether this blend is starting or stopping the animation.
  delay: number        // How long to wait before starting this blend.
}
```

An example callback that produces flame particles around the player when the blend is more than halfway done.
```lua
local animBlend = GSBlend.oldF.blend

local function flame(state, data)
  if state.rawProgress > 0.5 then
    particles:newParticle(
      "flame",
      player:getPos():add(math.random() * 2 - 1, math.random() * 2, math.random() * 2 - 1)
    )
  end

  animBlend(state.anim, math.lerp(state.from, state.to, state.progress))
end

animations.MyModel.MyAnimation:onBlend(flame)
```

&nbsp;
### Callback Generators
Some of the functions in `GSBlend.callback` and `GSBlend.curve` start with `gen`. These are generators and are not meant
to be used as blending callbacks/curves themselves, instead *returning* functions that are meant to be used as callbacks.

As an example, the generator `GSBlend.callback.genBlendVanilla` takes a list of parts that follow vanilla parts (such
as parts named `Head` or `LeftArm`) and makes a blending callback that smoothly transitions between the vanilla
rotations and the animation rotations instead of overwriting the vanilla rotations immediately.
```lua
-- This throws an error.
animations.MyModel.MyAnimation:onBlend(GSBlend.callback.genBlendVanilla)

-- This is how you are supposed to use the "genBlendVanilla" generator.
animations.MyModel.MyAnimation:onBlend(GSBlend.callback.genBlendVanilla({
  models.MyModel.Head, models.MyModel.Body,
  models.MyModel.LeftArm, models.MyModel.RightArm
}))
```

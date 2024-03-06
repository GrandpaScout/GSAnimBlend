# `❰GSAnimBlend❱` Animation Blending
This library adds blending to the start and end of Figura animations to create smoother transitions.


## Usage
This library has two modes which change depending on how you require the library.

### Simple
To use the basic features of this library, simply require it.
```lua
require("GSAnimBlend")
```

Once you have required the library, simply use the `:setBlendTime()` method to change how long the blending is on an
animation. This method expects an amount of time in ticks. (1/20ths of a second.)  
The default value is `0` so you have to use this method if you want an animation to blend.
```lua
animations.MyModel.MyAnimation:setBlendTime(5)
```

### Advanced
To use more advanced features of the library, require it to a variable.
```lua
local Blend = require("GSAnimBlend")
```

For more information on the advanced features you can use, see the wiki **(WIP)**


## Installation
To install this library:
* Download this repository by pressing the big `<> Code` button and clicking *Download ZIP*.
* Open the `.zip` file it gives you and open the `script` folder
* Pick the version of this library you want to use, open it, and put the `GSAnimBlend.lua` file in your avatar.

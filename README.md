sfxr.lua
========

A port of the sfxr sound effect synthesizer to pure Lua, designed to be used
together with the *awesome* [LÖVE](https://love2d.org) game framework.

Demo
----

To run the demo application you first need to download
[LoveFrames](https://github.com/NikolaiResokav/LoveFrames) as a submodule:
```
git submodule update --init
love demo
```
Note: Due to LoveFrames only supporting LÖVE 0.9.x, this dependency is inherited
by the demo. A move to a new GUI framework is pending.

Example usage
-------------

These examples should play a randomly generated sound.

With [LÖVE](http://love2d.org):
```lua
local sfxr = require("sfxr")

function love.load()
    local sound = sfxr.newSound()
    sound:randomize()
    sound:play()
end
```

With [lao](https://github.com/TheLinx/lao):
```lua
require("ao")
local sfxr = require("sfxr")

local driverId = ao.defaultDriverId()
local device = ao.openLive(driverId, {bits = 16, rate = 44100, channels = 1})

local sound = sfxr.newSound()
sound:randomize()

local buffer = sound:generateString()
device:play(buffer, #buffer)
```

**More documentation is available at the [Project Wiki](https://github.com/nucular/sfxrlua/wiki)**

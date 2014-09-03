sfxr.lua
========
[![Build Status](https://travis-ci.org/nucular/sfxrlua.svg?branch=master)](https://travis-ci.org/nucular/sfxrlua)

A port of the sfxr sound effect synthesizer to pure Lua, designed to be used
together with the *awesome* Löve game framework.


Example usage
-------------

These examples should play a randomly generated sound.

With [Löve](http://love2d.org) 0.9.x:
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

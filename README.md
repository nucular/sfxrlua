sfxr.lua
========

A port of the sfxr sound effect synthesizer to pure Lua, designed to be used
together with the *awesome* Löve2D game framework.


Example usage
-------------

These examples should play a randomly generated sound.

With [Löve2D](http://love2d.org) 0.9:
```lua
local sfxr = require("sfxr")

function love.load()
    local sound = sfxr.newSound()
    sound:randomize()
    love.audio.newSource(sound:generateSoundData()):play()
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

Known Issues
------------

Issues marked with an exclamation mark should be prioritized to be fixed before
adding any more complicated features. These marked with a question mark either
are of less priority or it is unknown if they should be handled as a bug.

- ! The sine wave sound distorts when played with a frequency lower than 0.33.
- ! The phaser offset has no audible effect, the phaser sweep however has.
- ! The Lowpass and Highpass filters sounds distorted.
- ! Changing is broken when the amount is < 0.
- Sometimes (sometimes!) the generator yields nil, which causes setSample to fail.
- ? `Sound.repeatSpeed`, `Sound.waveType` and `Sound.frequency.deltaSlide` should be lowercased instead of camelcased.
- ? Everything seems to be pitched slightly higher than at the original (floating point error?)

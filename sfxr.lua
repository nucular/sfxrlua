-- sfxr.lua
-- original by Tomas Pettersson, ported to Lua by nucular

--[[
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]--

local sfxr = {}
sfxr.__index = sfxr

local function new()
    local obj = setmetatable({}, sfxr)
    obj:__init()
    return obj
end

-- Constants

sfxr.SQUARE = 0
sfxr.SAWTOOTH = 1
sfxr.SINE = 2
sfxr.NOISE = 3

-- Utilities

local function trunc(n)
    return math.floor(n - 0.5)
end

local function random(low, high)
    return low + math.random() * (high - low)
end

local function maybe(n)
    return trunc(random(0, n or 1)) == 0
end

-- Class functions

function sfxr:__init()
    -- Build tables to store the parameters in
    self.volume = {}
    self.envelope = {}
    self.frequency = {}
    self.vibrato = {}
    self.change = {}
    self.duty = {}
    self.phaser = {}
    self.lowpass = {}
    self.highpass = {}

    -- Phaser and noise buffers
    self.phaserBuffer = {}
    self.noiseBuffer = {}

    self:resetParameters()
    self:resetBuffers()
end

function sfxr:resetParameters()
    -- Set all parameters to the default values
    self.repeatSpeed = 0.0
    self.waveType = sfxr.SQUARE
    self.superSamples = 8

    self.volume.master = 0.5
    self.volume.sound = 0.5

    self.envelope.attack = 0.0
    self.envelope.sustain = 0.3
    self.envelope.punch = 0.0
    self.envelope.decay = 0.4

    self.frequency.start = 0.3
    self.frequency.min = 0.0
    self.frequency.slide = 0.0
    self.frequency.deltaSlide = 0.0

    self.vibrato.depth = 0.0
    self.vibrato.speed = 0.0
    self.vibrato.delay = 0.0

    self.change.amount = 0.0
    self.change.speed = 0.0
    
    self.duty.ratio = 0.5
    self.duty.sweep = 0.0

    self.phaser.offset = 0.0
    self.phaser.sweep = 0.0

    self.lowpass.cutoff = 1.0
    self.lowpass.sweep = 0.0
    self.lowpass.resonance = 0.0
    self.highpass.cutoff = 0.0
    self.highpass.sweep = 0.0
end

function sfxr:resetBuffers()
    -- Fill the sample buffers with zeroes
    for i=1, 1025 do
        self.phaserBuffer[i] = 0
    end

    for i=1, 33 do
        self.noiseBuffer[i] = 0
    end
end


sfxr:__init()

return setmetatable({new = new},
    {
        __call = function(_, ...)
            return new(...)
        end
    })

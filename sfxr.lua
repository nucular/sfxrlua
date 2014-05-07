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

local function clamp(n, min, max)
    return math.max(min or -math.inf, math.min(max or math.inf, n))
end

local function cpypol(a, b)
    if b < 0 then
        return -a
    else
        return a
    end
end

-- The main Sound class

sfxr.Sound = {}
sfxr.Sound.__index = sfxr.Sound

function sfxr.Sound:__init()
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
    -- Reset the sample buffers
    for i=1, 1025 do
        self.phaserBuffer[i] = 0
    end

    for i=1, 33 do
        self.noiseBuffer[i] = sfxr.random(-1, 1)
    end
end

function sfxr:generate()
    -- Basically the main synthesizing function, yields the sample data

    -- Initialize ALL the locals!
    local phase = 0

    local fperiod = 100 / ((self.frequency.start - 0.025)^2 + 0.001)
    local maxperiod = 100 / (self.frequency.min^2 + 0.001)
    local period = trunc(fperiod)
    
    local slide = 1.0 - self.frequency.slide^3 * 0.01
    local dslide = -self.frequency.deltaSlide^3 * 0.000001

    local square_duty = 0.5 - self.duty.ratio * 0.5
    local square_slide = -self.duty.sweep * 0.00005

    local env_vol = 0
    local env_stage = 0
    local env_time = 0
    local env_length = {self.envelope.attack^2 * 100000,
        self.envelope.sustain^2 * 100000,
        self.envelope.decay^2 * 100000}

    local phase = self.phaser.offset^2 * 1020
    phase = cpypol(phase, self.phaser.offset)
    local dphase = self.phaser.sweep^2
    dphase = cpypol(dphase, self.phaser.sweep)

    local iphase = math.abs(trunc(fphase))

    local ltp = 0
    local ltdp = 0
    local ltw = self.lowpass.cutoff^3 * 0.1
    local ltw_d = 1 + self.lowpass.ramp * 0.0001
    local ltdmp = 5 / (1 + self.lowpass.resonance^2 * 20) * (0.01 + fltw)
    ltdmp = clamp(ltdmp, nil, 0.8)
    local ltphp = 0
    local lthp = self.highpass.cutoff^2 * 0.1
    local lthp_d = 1 + self.highpass.sweep * 0.0003

    local vib_phase = 0
    local vib_speed = self.vibrato.speed^2 * 0.01
    local vib_amp = self.vibrato.depth * 0.5

    local chg_time = 0
    if self.change.speed == 1 then
        local chg_limit = 0
    else
        local chg_limit = (1 - self.change.speed)^2 * 20000 + 32
    end

    if self.change.amount >= 0 then
        local chg_mod = 1.0 - self.change.amount^2 * 0.9
    else
        local chg_mod = 1.0 - self.change.amount^2 * 10
    end
end

-- Constructor

function sfxr.newSound(...)
    local instance = setmetatable({}, sfxr.Sound)
    instance:__init(...)
    return instance
end

return sfxr
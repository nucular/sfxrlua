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
    return math.max(min or -math.huge, math.min(max or math.huge, n))
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

function sfxr.Sound:resetParameters()
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

function sfxr.Sound:resetBuffers()
    -- Reset the sample buffers
    for i=1, 1025 do
        self.phaserBuffer[i] = 0
    end

    for i=1, 33 do
        self.noiseBuffer[i] = random(-1, 1)
    end
end

function sfxr.Sound:generate()
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
    local env_stage = 1
    local env_time = 0
    local env_length = {self.envelope.attack^2 * 100000,
        self.envelope.sustain^2 * 100000,
        self.envelope.decay^2 * 100000}

    local phase = self.phaser.offset^2 * 1020
    phase = cpypol(phase, self.phaser.offset)
    local dphase = self.phaser.sweep^2
    dphase = cpypol(dphase, self.phaser.sweep)
    local ipp = 0

    local iphase = math.abs(trunc(phase))

    local ltp = 0
    local ltdp = 0
    local ltw = self.lowpass.cutoff^3 * 0.1
    local ltw_d = 1 + self.lowpass.sweep * 0.0001
    local ltdmp = 5 / (1 + self.lowpass.resonance^2 * 20) * (0.01 + ltw)
    ltdmp = clamp(ltdmp, nil, 0.8)
    local ltphp = 0
    local lthp = self.highpass.cutoff^2 * 0.1
    local lthp_d = 1 + self.highpass.sweep * 0.0003

    local vib_phase = 0
    local vib_speed = self.vibrato.speed^2 * 0.01
    local vib_amp = self.vibrato.depth * 0.5

    local chg_time = 0
    local chg_limit = 0
    if self.change.speed == 1 then
        chg_limit = 0
    else
        chg_limit = (1 - self.change.speed)^2 * 20000 + 32
    end

    local chg_mod = 0
    if self.change.amount >= 0 then
        chg_mod = 1.0 - self.change.amount^2 * 0.9
    else
        chg_mod = 1.0 - self.change.amount^2 * 10
    end

    -- Yay, the main closure

    return function()
        -- Update the change time and apply it if needed
        chg_time = chg_time + 1
        if chg_limit ~= 0 and chg_time >= chg_limit then
            chg_limit = 0
            fperiod = fperiod * chg_mod
        end

        -- Apply the frequency slide and stuff
        slide = slide + dslide
        fperiod = fperiod * slide

        if fperiod > maxperiod then
            fperiod = fmaxperiod
            -- If the frequency is too low, stop generating
            if (self.frequency.min > 0) then
                return nil
            end
        end

        -- Vibrato
        local rfperiod = fperiod
        if vib_amp > 0 then
            vib_phase = vib_phase + vib_speed
            rfperiod = fperiod * (1.0 + math.sin(vib_phase) * vib_amp)
        end
        -- Update the period
        period = trunc(rfperiod)
        if (period < 8) then period = 8 end

        -- Update the square duty
        square_duty = clamp(square_duty + square_slide, 0, 0.5)

        -- Volume envelopes

        env_time = env_time + 1

        if env_time > env_length[env_stage] then
            env_time = 0
            env_stage = env_stage + 1
            -- After the decay stop generating
            if env_stage == 4 then
                return nil
            end
        end

        if env_stage == 1 then
            env_vol = env_time / env_length[1]
        elseif env_stage == 2 then
            env_vol = 1 + (1 - env_time / env_length[2])^1 * 2 * self.envelope.punch
        elseif env_stage == 3 then
            env_vol = 1 - env_time / env_length[3]
        end

        -- Phaser

        phase = phase + dphase
        iphase = math.abs(trunc(phase))
        if iphase > 1024 then iphase = 1024 end

        -- Lowpass stuff

        if lthp_d ~= 0 then
            lthp = clamp(lthp * lthp_d, 0.00001, 0.1)
        end

        -- And finally the actual tone generation and supersampling

        local ssample = 0
        for si = 0, self.superSamples do
            local sample = 0

            phase = phase + 1

            -- fill the noise buffer every period
            if phase >= period then
                --phase = 0
                phase = phase % period
                if self.waveType == sfxr.NOISE then
                    for i = 1, 32 do
                        self.noiseBuffer[i] = random(-1, 1)
                    end
                end
            end

            -- Tone oscillators ahead!!!

            local fp = phase / period

            if self.waveType == sfxr.SQUARE then
                if fp < square_duty then
                    sample = 0.5
                else
                    sample = -0.5
                end

            elseif self.waveType == sfxr.SAWTOOTH then
                sample = 1 - fp * 2

            elseif self.waveType == sfxr.SINE then
                sample = math.sin(fp * 2 * math.pi)

            elseif self.waveType == sfxr.NOISE then
                sample = self.noiseBuffer[math.floor(phase * 32 / period) + 1]
            end

            -- Apply the lowpass filter to the sample

            local pp = ltp
            ltw = clamp(ltw * ltw_d, 0, 0.1)
            if self.lowpass.cutoff ~= 1 then
                ltdp = ltdp + (sample - ltp) * ltw
                ltdp = ltdp - ltdp * ltdmp
            else
                ltp = sample
                ltdp = 0
            end
            ltp = ltp + ltdp

            -- Apply the highpass filter to the sample

            ltphp = ltphp + ltp - pp
            ltphp = ltphp - ltphp * lthp
            sample = ltphp

            -- Apply the phaser to the sample

            self.phaserBuffer[bit.band(ipp, 1023) + 1] = sample
            sample = sample + self.phaserBuffer[bit.band(ipp - iphase + 1024, 1023) + 1]
            ipp = bit.band(ipp + 1, 1023)

            -- Accumulation and envelope application
            ssample = ssample + sample * env_vol
        end

        -- Apply the volumes
        ssample = ssample / self.superSamples * self.volume.master
        ssample = ssample * 2 * self.volume.sound

        -- Hard limit
        ssample = clamp(ssample, -1, 1)

        -- Aaaand finally
        return ssample
    end
end

function sfxr.Sound:getEnvelopeLimit()
    local env_length = {self.envelope.attack^2 * 100000,
        self.envelope.sustain^2 * 100000,
        self.envelope.decay^2 * 100000}

    return env_length[1] + env_length[2] + env_length[3] + 2
end

function sfxr.Sound:getLimit()
    return self:getEnvelopeLimit()
end

function sfxr.Sound:generateTable()
    local t = {}
    t[self:getLimit()] = 0

    local i = 1
    for v in self:generate() do
        if not v then
            break
        end
        t[i] = v
        i = i + 1
    end

    return t
end

function sfxr.Sound:generateSoundData(freq, bits)
    local tab = self:generateTable()

    local data = love.sound.newSoundData(#tab, freq, bits, 1)

    for i = 0, #tab - 1 do
        data:setSample(i, tab[i + 1])
    end

    return data
end

-- Constructor

function sfxr.newSound(...)
    local instance = setmetatable({}, sfxr.Sound)
    instance:__init(...)
    return instance
end

return sfxr
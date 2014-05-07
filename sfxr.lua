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
    local fperiod, maxperiod
    local slide, dslide
    local square_duty, square_slide
    local chg_mod, chg_time, chg_limit

    local function reset()
        fperiod = 100 / ((self.frequency.start - 0.025)^2 + 0.001)
        maxperiod = 100 / (self.frequency.min^2 + 0.001)
        period = trunc(fperiod)
        
        slide = 1.0 - self.frequency.slide^3 * 0.01
        dslide = -self.frequency.deltaSlide^3 * 0.000001

        square_duty = 0.5 - self.duty.ratio * 0.5
        square_slide = -self.duty.sweep * 0.00005

        chg_mod = 0
        if self.change.amount >= 0 then
            chg_mod = 1.0 - self.change.amount^2 * 0.9
        else
            chg_mod = 1.0 - self.change.amount^2 * 10
        end

        chg_time = 0
        chg_limit = 0
        if self.change.speed == 1 then
            chg_limit = 0
        else
            chg_limit = (1 - self.change.speed)^2 * 20000 + 32
        end
    end
    reset()

    local phase = 0

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

    local rep_time = 0
    local rep_limit = trunc((1 - self.repeatSpeed)^2 * 20000 + 32)
    if self.repeatSpeed == 0 then
        rep_limit = 0
    end

    -- Yay, the main closure

    return function()
        -- Repeat maybe
        rep_time = rep_time + 1
        if rep_limit ~= 0 and rep_time >= rep_limit then
            reset()
            rep_time = 0
        end

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
            fperiod = maxperiod
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

    return trunc(env_length[1] + env_length[2] + env_length[3] + 2)
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
    local data = love.sound.newSoundData(self:getLimit() + 1, freq, bits, 1)

    local i = 0
    for v in self:generate() do
        data:setSample(i, v)
        i = i + 1
    end

    return data
end

function sfxr.Sound:randomize(seed)
    math.randomseed(seed)
    self.repeatSpeed = random(1, 2)

    if maybe() then
        self.frequency.start = random(-1, 1)^3 + 0.5
    else
        self.frequency.start = random(-1, 1)^2
    end
    self.frequency.limit = 0
    self.frequency.slide = random(-1, 1)^5
    if self.frequency.start > 0.7 and self.frequency.slide > 0.2 then
        self.frequency.slide = -self.frequency.slide
    elseif self.frequency.start < 0.2 and self.frequency.slide <-0.05 then
        self.frequency.slide = -self.frequency.slide
    end
    self.frequency.deltaSlide = random(-1, 1)^3

    self.duty.ratio = random(-1, 1)
    self.duty.sweep = random(-1, 1)^3

    self.vibrato.depth = random(-1, 1)^3
    self.vibrato.speed = random(-1, 1)
    self.vibrato.delay = random(-1, 1)

    self.envelope.attack = random(-1, 1)^3
    self.envelope.sustain = random(-1, 1)^2
    self.envelope.punch = random(-1, 1)^2
    self.envelope.decay = random(-1, 1)
    
    if self.envelope.attack + self.envelope.sustain + self.envelope.decay < 0.2 then
        self.envelope.sustain = self.envelope.sustain + 0.2 + random(0, 0.3)
        self.envelope.decay = self.envelope.decay + 0.2 + random(0, 0.3)
    end

    self.lowpass.resonance = random(-1, 1)
    self.lowpass.cutoff = 1 - random(0, 1)^3
    self.lowpass.sweep = random(-1, 1)^3
    if self.lowpass.cutoff < 0.1 and self.lowpass.sweep < -0.05 then
        self.lowpass.sweep = -self.lowpass.sweep
    end
    self.highpass.cutoff = random(0, 1)^3
    self.highpass.sweep = random(-1, 1)^5

    self.phaser.offset = random(-1, 1)^3
    self.phaser.sweep = random(-1, 1)^3

    self.change.speed = random(-1, 1)
    self.change.amount = random(-1, 1)
end

function sfxr.Sound:mutate(amount, changeFreq)
    local amount = (amount or 1)
    local a = amount / 20
    local b = (1 - a) * 10
    local changeFreq = changeFreq or true

    if changeFreq == true then
        if maybe(b) then self.frequency.start = self.frequency.start + random(-a, a) end
        if maybe(b) then self.frequency.slide = self.frequency.slide + random(-a, a) end
        if maybe(b) then self.frequency.deltaSlide = self.frequency.deltaSlide + random(-a, a) end
    end

    if maybe(b) then self.duty.ratio = self.duty.ratio + random(-a, a) end
    if maybe(b) then self.duty.sweep = self.duty.sweep + random(-a, a) end

    if maybe(b) then self.vibrato.depth = self.vibrato.depth + random(-a, a) end
    if maybe(b) then self.vibrato.speed = self.vibrato.speed + random(-a, a) end
    if maybe(b) then self.vibrato.delay = self.vibrato.delay + random(-a, a) end

    if maybe(b) then self.envelope.attack = self.envelope.attack + random(-a, a) end
    if maybe(b) then self.envelope.sustain = self.envelope.sustain + random(-a, a) end
    if maybe(b) then self.envelope.punch = self.envelope.punch + random(-a, a) end
    if maybe(b) then self.envelope.decay = self.envelope.decay + random(-a, a) end

    if maybe(b) then self.lowpass.resonance = self.lowpass.resonance + random(-a, a) end
    if maybe(b) then self.lowpass.cutoff = self.lowpass.cutoff + random(-a, a) end
    if maybe(b) then self.lowpass.sweep = self.lowpass.sweep + random(-a, a) end
    if maybe(b) then self.highpass.cutoff = self.highpass.cutoff + random(-a, a) end
    if maybe(b) then self.highpass.sweep = self.highpass.sweep + random(-a, a) end

    if maybe(b) then self.phaser.offset = self.phaser.offset + random(-a, a) end
    if maybe(b) then self.phaser.sweep = self.phaser.sweep + random(-a, a) end

    if maybe(b) then self.change.speed = self.change.speed + random(-a, a) end
    if maybe(b) then self.change.amount = self.change.amount + random(-a, a) end

    if maybe(b) then self.repeatSpeed = self.repeatSpeed + random(-a, a) end
end

-- Constructor

function sfxr.newSound(...)
    local instance = setmetatable({}, sfxr.Sound)
    instance:__init(...)
    return instance
end

return sfxr
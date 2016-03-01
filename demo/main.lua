#/usr/bin/env love
-- love .

local sfxr = require("sfxr")

-- Global stuff
local source
local sound
local sounddata

local seed
local playbutton
local playing = false

local wavecanvas
local statistics = {
    generation = 0,
    transfer = 0,
    waveview = 0,
    duration = 0
}

-- This will hold all sliders and the wave form box
local guiparams = {}
-- The parameter list is built from this
-- {{"Text", "table name", {{"Text", "table paramter", min, max}, ...}}, ...}
local guicategories = {
    {
        "Envelope",
        "envelope",
        {
            {"Attack Time", "attack", 0, 1},
            {"Sustain Time", "sustain", 0, 1},
            {"Sustain Punch", "punch", 0, 1},
            {"Decay Time", "decay", 0, 1}
        }
    },
    {
        "Frequency",
        "frequency",
        {
            {"Start", "start", 0, 1},
            {"Minimum", "min", 0, 1},
            {"Slide", "slide", -1, 1},
            {"Delta Slide", "dslide", -1, 1}
        }
    },
    {
        "Vibrato",
        "vibrato",
        {
            {"Depth", "depth", 0, 1},
            {"Speed", "speed", 0, 1}
        }
    },
    {
        "Change",
        "change",
        {
            {"Amount", "amount", -1, 1},
            {"Speed", "speed", 0, 1}
        }
    },
    {
        "Square Duty",
        "duty",
        {
            {"Ratio", "ratio", 0, 1},
            {"Sweep", "sweep", -1, 1}
        }
    },
    {
        "Phaser",
        "phaser",
        {
            {"Offset", "offset", -1, 1},
            {"Sweep", "sweep", -1, 1}
        }
    },
    {
        "Low Pass",
        "lowpass",
        {
            {"Cutoff", "cutoff", 0, 1},
            {"Sweep", "sweep", -1, 1},
            {"Resonance", "resonance", 0, 1}
        }
    },
    {
        "High Pass",
        "highpass",
        {
            {"Cutoff", "cutoff", 0, 1},
            {"Sweep", "sweep", -1, 1}
        }
    }
}

-- Easy lookup of wave forms
local waveFormList = {
    ["Square"] = 0,
    ["Sawtooth"] = 1,
    ["Sine"] = 2,
    ["Noise"] = 3,
    [0] = "Square",
    [1] = "Sawtooth",
    [2] = "Sine",
    [3] = "Noise"
}


function stopSound()
    playbutton:SetText("Play")
    if source then
        source:stop()
    end
end

function playSound()
    -- Stop the currently playing source
    if source then
        source:stop()
    end

    local t = love.timer.getTime()
    local tab = sound:generateTable(sfxr.FREQ_44100, sfxr.BITS_FLOAT)
    t = love.timer.getTime() - t
    statistics.generation = math.floor(t * 10000) / 10

    if #tab == 0 then
        return nil
    end

    sounddata = love.sound.newSoundData(#tab, 44100, 16, 1)
    statistics.duration = math.floor(sounddata:getDuration() * 10000) / 10

    -- Stuff for the wave view
    local waveview = {}
    local j = 0
    local max = -1
    local min = 1
    local avg = 0.5

    local t = love.timer.getTime()
    for i = 0, #tab - 1 do

        local v = tab[i + 1]
        -- Copy the sample over to the SoundData
        sounddata:setSample(i, v)

        -- Add the minimal and maximal sample to the wave view
        -- every 256 samples. This is how Audacity does it, actually.
        j = j + 1
        min = math.min(v, min)
        max = math.max(v, max)
        if j >= 256 then
            waveview[#waveview + 1] = min
            waveview[#waveview + 1] = max
            j = 0
            min, max = 1, -1
        end
    end
    t = love.timer.getTime() - t
    statistics.transfer = math.floor(t * 10000) / 10

    updateWaveCanvas(waveview)
    updateStatistics()

    if sounddata then
        source = love.audio.newSource(sounddata)
        source:play()
        playbutton:SetText("Stop Playing")
        playing = true
    end
end

function createSeedBox()
    local f = lf.Create("form"):SetName("Random Seed")

    seed = lf.Create("numberbox")
        :SetValue(math.floor(love.timer.getTime()))
        :SetMax(math.huge)
        :SetMin(-math.huge)
        :SetWidth(100)

    f:AddItem(seed):SetPos(5, 240)
end

function createPresetGenerators()
    local f = lf.Create("form")
        :SetName("Preset Generators")
    local generators = {
        {"Pickup/Coin", sound.randomPickup},
        {"Laser/Shoot", sound.randomLaser},
        {"Explosion", sound.randomExplosion},
        {"Powerup", sound.randomPowerup},
        {"Hit/Hurt", sound.randomHit},
        {"Jump", sound.randomJump},
        {"Blip/Select", sound.randomBlip}
    }

    for i, v in ipairs(generators) do
        local b = lf.Create("button")
            :SetText(v[1])
            :SetWidth(100)
        f:AddItem(b)

        b.OnClick = function(self)
            v[2](sound, seed:GetValue())
            seed:SetValue(seed:GetValue() + 1)
            updateParameters()
            playSound()
        end
    end

    f:SetPos(5, 5):SetWidth(110)
end

function createRandomizers()
    local f = lf.Create("form"):SetName("Randomizers")

    local b = lf.Create("button")
        :SetText("Mutate")
        :SetWidth(100)
    f:AddItem(b)

    b.OnClick = function(self)
        sound:mutate()
        updateParameters()
        playSound()
    end

    local b = lf.Create("button")
        :SetText("Randomize")
        :SetWidth(100)
    f:AddItem(b)

    b.OnClick = function(self)
        sound:randomize(seed:GetValue())
        updateParameters()
        seed:SetValue(seed:GetValue() + 1)
        playSound()
    end

    f:SetPos(5, 515):SetSize(110, 80)
end

function createParameters()
    local f = lf.Create("form"):SetName("Parameters")

    local l = lf.Create("list")
        :SetSpacing(5)
        :SetPadding(5)
        :SetSize(340, 565)
    f:AddItem(l)


    -- Waveforms
    l:AddItem(lf.Create("text"):SetPos(0, pheight):SetText("Wave Form"))

    local m = lf.Create("multichoice")
    for i = 0, #waveFormList do
    	m:AddChoice(waveFormList[i])
    end
    m:SetChoice("Square")

    m.OnChoiceSelected = function(o, c)
        sound.wavetype = waveFormList[c]
    end

    l:AddItem(m)
    guiparams.waveform = m


    -- Repeat speed
    local t = lf.Create("text")
        :SetText("Repeat Speed 0")
        :SetPos(0, pheight)

    local s = lf.Create("slider")
        :SetWidth(120)
        :SetMinMax(0, 1)
        :SetValue(sound.repeatspeed)

    s.OnValueChanged = function(o)
        local v = o:GetValue()
        if v <= 0.02 and v >= -0.02 and v ~= 0 then
            o:SetValue(0)
            sound.repeatspeed = 0
            t:SetText("Repeat Speed 0")
        else
            sound.repeatspeed = v
            t:SetText("Repeat Speed " .. tostring(math.floor(v * 100) / 100))
        end
    end

    l:AddItem(t):AddItem(s)
    guiparams.repeatspeed = {s, t}


    for i1, v1 in ipairs(guicategories) do
        local c = lf.Create("collapsiblecategory"):SetText(v1[1])
        l:AddItem(c)

        local p = lf.Create("panel")
        local pheight = 0
        p.Draw = function() end
        c:SetObject(p)

        guiparams[v1[2]] = {}

        for i2, v2 in ipairs(v1[3]) do
            lf.Create("text", p)
                :SetText(v2[1])
                :SetPos(0, pheight)

            local t = lf.Create("text", p)
                :SetText("0")
                :SetPos(95, pheight)

            local s = lf.Create("slider", p)
                :SetPos(130, pheight - 3)
                :SetWidth(170)
                :SetMinMax(v2[3], v2[4])
                :SetValue(sound[v1[2]][v2[2]])

            s.OnValueChanged = function(o)
                local v = o:GetValue()
                if v <= 0.02 and v >= -0.02 and v ~= 0 then
                    o:SetValue(0)
                    sound[v1[2]][v2[2]] = 0
                    t:SetText("0")
                else
                    sound[v1[2]][v2[2]] = v
                    t:SetText(math.floor(v * 100) / 100)
                end
            end

            guiparams[v1[2]][v2[2]] = {s, t}
            pheight = pheight + 30
        end

        p:SetHeight(pheight - 10)
    end


    f:SetPos(125, 5):SetSize(350, 590)
end

function createActionButtons()
    local f = lf.Create("form"):SetName("Actions")

    local b = lf.Create("button")
        :SetText("Generate and Play")
        :SetWidth(140)

    b.OnClick = function(o)
        if not playing then
            playSound()
        else
            stopSound()
        end
    end

    playbutton = b
    f:AddItem(b)


    local fr = lf.Create("frame")
        :SetName("File Picker")
        :SetSize(400, 300)
        :Center()
        :SetVisible(false)
        :SetModal(false)

    local frl = lf.Create("columnlist", fr)
        :SetPos(5, 30)
        :SetSize(390, 235)
        :AddColumn("Name")

    local frt = lf.Create("textinput", fr)
        :SetPos(5, 270)
        :SetWidth(300)

    local frb = lf.Create("button", fr)
        :SetPos(315, 270)

    frl.OnRowSelected = function(p, row, data)
        frt:SetText(data[1])
    end

    fr.OnClose = function(o)
        frl:Clear()
        fr:SetVisible(false):SetModal(false)
        return false
    end

    local function saveHandler(type, cb)
        return function()
            fr:SetName("Save to ." .. type)
            frt:SetText("sound." .. type)
            frb:SetText("Save")

            love.filesystem.getDirectoryItems("sounds", function(name)
                if name:find(type, #type-#name+1, true) then
                    frl:AddRow(name)
                end
            end)

            frb.OnClick = function(o)
                local name = frt:GetText()
                if (#name > 0) then
                    local f = love.filesystem.newFile("sounds/" .. name, "w")
                    if f then
                        cb(f)
                        frl:Clear()
                        fr:SetVisible(false):SetModal(false)
                    end
                end
            end

            frt.OnEnter = frb.OnClick
            fr:SetVisible(true)
                :SetModal(true)
                :Center()
        end
    end

    local function loadHandler(type, cb)
        return function()
            fr:SetName("Load from ." .. type)
            frt:SetText("sound." .. type)
            frb:SetText("Load")

            love.filesystem.getDirectoryItems("sounds", function(name)
                if name:find(type, #type-#name+1, true) then
                    frl:AddRow(name)
                end
            end)

            frb.OnClick = function(o)
                local name = frt:GetText()
                if (#name > 0) then
                    local f = love.filesystem.newFile("sounds/" .. name, "r")
                    if f then
                        cb(f)
                        frl:Clear()
                        fr:SetVisible(false):SetModal(false)
                    end
                end
            end

            frt.OnEnter = frb.OnClick
            fr:SetVisible(true)
                :SetModal(true)
                :Center()
        end
    end


    local sb = lf.Create("button")
        :SetText("Save Lua")
        :SetWidth(67)
    sb.OnClick = saveHandler("lua", function(f) sound:save(f, true) end)
    f:AddItem(sb)

    local lb = lf.Create("button")
        :SetText("Load Lua")
        :SetWidth(67)
    lb.OnClick = loadHandler("lua", function(f) sound:load(f) end)
    f:AddItem(lb)

    local bsb = lf.Create("button")
        :SetText("Save binary")
        :SetWidth(67)
    bsb.OnClick = saveHandler("sfs", function(f) sound:saveBinary(f) end)
    f:AddItem(bsb)

    local blb = lf.Create("button")
        :SetText("Load binary")
        :SetWidth(67)
    blb.OnClick = loadHandler("sfs", function(f) sound:loadBinary(f) end)
    f:AddItem(blb)

    local eb = lf.Create("button")
        :SetText("Export WAV")
        :SetWidth(140)
    eb.OnClick = saveHandler("wav", function(f) sound:exportWAV(f) end)
    f:AddItem(eb)

    f:SetPos(485, 455):SetSize(150, 140)

    lb:SetPos(78, 47)
    bsb:SetY(77)
    blb:SetPos(78, 77)
    eb:SetY(107)
end

function createOther()
    local f = lf.Create("form")
        :SetName("Wave View")
        :SetPos(485, 5)
        :SetSize(150, 170)

    local draw = function(o)
        if source then
            love.graphics.setColor(255, 255, 255)
            love.graphics.draw(wavecanvas, 495, 25)

            -- Draw a fancy position cursor
            local pos = source:tell("samples")
            local max = sounddata:getSampleCount()
            local x = 495 + (pos / max) * 125
            love.graphics.setColor(255, 153, 0)
            love.graphics.line(x, 25, x, 165)
        end

        lf.skins.available["Orange"].DrawForm(o)
    end
    f.Draw = draw


    local f = lf.Create("form"):SetName("Volume")

    local t = lf.Create("text"):SetText("Master 0.5")
    f:AddItem(t)


    local s = lf.Create("slider")
        :SetMinMax(0, 1)
        :SetSize(135, 20)

    s.OnValueChanged = function(o)
        local v = o:GetValue()
        if v <= 0.52 and v >= 0.48 and v ~= 0.5 then
            o:SetValue(0.5)
            v = 0.5
        end
        sound.volume.master = v
        t:SetText("Master " .. tostring(math.floor(v * 100) / 100))
    end

    s:SetValue(sound.volume.master)
    f:AddItem(s)


    local t = lf.Create("text"):SetText("Sound 0.5")
    f:AddItem(t)

    local s = lf.Create("slider")
        :SetMinMax(0, 1)
        :SetSize(135, 20)

    s.OnValueChanged = function(o)
        local v = o:GetValue()
        if v <= 0.52 and v >= 0.48 and v ~= 0.5 then
            o:SetValue(0.5)
            v = 0.5
        end
        sound.volume.sound = v
        t:SetText("Sound " .. tostring(math.floor(v * 100) / 100))
    end

    s:SetValue(sound.volume.sound)
    f:AddItem(s)


    f:SetPos(485, 340):SetWidth(150)


    local f = lf.Create("form"):SetName("Times / Duration")

    local t = lf.Create("text"):SetText("Generation: 0ms")
    f:AddItem(t)
    statistics.generationtext = t

    local t = lf.Create("text"):SetText("Transfer: 0ms")
    f:AddItem(t)
    statistics.transfertext = t

    local t = lf.Create("text"):SetText("Wave View: 0ms")
    f:AddItem(t)
    statistics.waveviewtext = t

    local t = lf.Create("text"):SetText("Duration: 0ms")
    f:AddItem(t)
    statistics.durationtext = t

    f:SetPos(485, 185):SetWidth(150)
end

function updateParameters()
    -- Iterate through the list of parameters and update all of them
    for i1, v1 in ipairs(guicategories) do
        for i2, v2 in ipairs(v1[3]) do
            local v = sound[v1[2]][v2[2]]
            local s, t = unpack(guiparams[v1[2]][v2[2]])
            s:SetValue(v)
            t:SetText(math.floor(v * 100) / 100)
        end
    end

    local s, t = unpack(guiparams.repeatspeed)
    local v = sound.repeatspeed

    s:SetValue(v)
    t:SetText("Repeat Speed " .. tostring(math.floor(v * 100) / 100))

    guiparams.waveform:SetChoice(waveFormList[sound.wavetype])
end

function updateWaveCanvas(waveview)
    local t = love.timer.getTime()
    wavecanvas:clear()
    love.graphics.setCanvas(wavecanvas)
    love.graphics.setColor(255, 255, 255)
    love.graphics.setLineStyle("rough")

    -- Iterate through the passed table and draw all lines to the canvas
    local step = 125 / #waveview
    local last = 70
    for i, v in ipairs(waveview) do
        local x = (i * step)
        local y = (-v + 1) * 70

        love.graphics.line(x - step, last, x, y)
        last = y
    end

    -- Draw the zero line
    love.graphics.setColor(255, 80, 51, 200)
    love.graphics.line(0, 70, 125, 70)

    love.graphics.setCanvas()
    t = love.timer.getTime() - t
    statistics.waveview = math.floor(t * 10000) / 10
end

function updateStatistics()
    statistics.durationtext:SetText("Duration: " .. statistics.duration .. " ms")
    statistics.transfertext:SetText("Transfer: " .. statistics.transfer .. " ms")
    statistics.waveviewtext:SetText("Wave View: " .. statistics.waveview .. " ms")
    statistics.generationtext:SetText("Generation: " .. statistics.generation .. " ms")
end

function love.load()
    require("loveframes")
    lf = loveframes
    lf.util.SetActiveSkin("Orange")

    love.graphics.setBackgroundColor(200, 200, 200)

    if not love.filesystem.isDirectory("sounds") then
        love.filesystem.createDirectory("sounds")
    end

    sound = sfxr.newSound()

    createSeedBox()
    createPresetGenerators()
    createRandomizers()
    createParameters()
    createActionButtons()
    createOther()

    wavecanvas = love.graphics.newCanvas(125, 140)

    love.mousepressed = lf.mousepressed
    love.mousereleased = lf.mousereleased
    love.keyreleased = lf.keyreleased
    love.textinput = lf.textinput
end

function love.update(dt)
    lf.update(dt)
    if source then
        if playing and not source:isPlaying() then
            playing = false
            playbutton:SetText("Generate and Play")
        end
    end
end

function love.draw()
    lf.draw()
end

function love.keypressed(key)
    if key == " " then
        playSound()
    elseif key == "escape" then
        love.event.push("quit")
    end
    lf.keypressed(key)
end

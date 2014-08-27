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
    "Square", "Sawtooth", "Sine", "Noise"
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
    local f = lf.Create("form")
    f:SetName("Random Seed")

    seed = lf.Create("numberbox")
    seed:SetValue(math.floor(love.timer.getTime()))
    seed:SetMax(math.huge)
    seed:SetMin(-math.huge)
    seed:SetWidth(100)
    f:AddItem(seed)

    f:SetPos(5, 240)
end

function createPresetGenerators()
    local f = lf.Create("form")
    f:SetName("Preset Generators")
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
        b:SetText(v[1])
        b:SetWidth(100)
        f:AddItem(b)

        b.OnClick = function(self)
            v[2](sound, seed:GetValue())
            seed:SetValue(seed:GetValue() + 1)
            updateParameters()
            playSound()
        end
    end

    f:SetPos(5, 5)
    f:SetWidth(110)
end

function createRandomizers()
    local f = lf.Create("form")
    f:SetName("Randomizers")

    local b = lf.Create("button")
    b:SetText("Mutate")
    b:SetWidth(100)
    f:AddItem(b)
    b.OnClick = function(self)
        sound:mutate()
        updateParameters()
        playSound()
    end

    local b = lf.Create("button")
    b:SetText("Randomize")
    b:SetWidth(100)
    f:AddItem(b)
    b.OnClick = function(self)
        sound:randomize(seed:GetValue())
        updateParameters()
        seed:SetValue(seed:GetValue() + 1)
        playSound()
    end

    f:SetPos(5, 515)
    f:SetSize(110, 80)
end

function createParameters()
    local f = lf.Create("form")
    f:SetName("Parameters")

    local l = lf.Create("list")
    l:SetSpacing(5)
    l:SetPadding(5)
    l:SetSize(340, 565)
    f:AddItem(l)


    -- Waveforms
    l:AddItem(lf.Create("text"):SetPos(0, pheight):SetText("Wave Form"))
    local m = lf.Create("multichoice")
    m:AddChoice("Square")
    m:AddChoice("Sawtooth")
    m:AddChoice("Sine")
    m:AddChoice("Noise")
    m:SetChoice("Square")
    m.OnChoiceSelected = function(o, c)
        sound.wavetype = waveFormList[c]
    end
    l:AddItem(m)
    guiparams.waveform = m


    -- Repeat speed
    local t = lf.Create("text"):SetPos(0, pheight)
    t:SetText("Repeat Speed 0")
    local s = lf.Create("slider")
    s:SetWidth(120)
    s:SetMinMax(0, 1)
    s:SetValue(sound.repeatspeed)
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
    l:AddItem(t)
    l:AddItem(s)
    guiparams.repeatspeed = {s, t}


    for i1, v1 in ipairs(guicategories) do
        local c = lf.Create("collapsiblecategory")
        c:SetText(v1[1])
        l:AddItem(c)

        local p = lf.Create("panel")
        local pheight = 0
        p.Draw = function() end
        c:SetObject(p)

        guiparams[v1[2]] = {}

        for i2, v2 in ipairs(v1[3]) do
            lf.Create("text", p):SetPos(0, pheight):SetText(v2[1])
            local t = lf.Create("text", p):SetPos(95, pheight):SetText("0")

            local s = lf.Create("slider", p):SetPos(130, pheight - 3):SetWidth(170)
            s:SetMinMax(v2[3], v2[4])
            s:SetValue(sound[v1[2]][v2[2]])

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


    f:SetPos(125, 5)
    f:SetSize(350, 590)
end

function createActionButtons()
    local f = lf.Create("form")
    f:SetName("Actions")

    local b = lf.Create("button")
    b:SetText("Generate and Play")
    b:SetWidth(140)
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
    fr:SetName("File Picker")
    fr:SetSize(400, 300)
    fr:Center()
    fr:SetVisible(false)
    fr:SetModal(false)
    
    local frl = lf.Create("columnlist", fr)
    frl:SetPos(5, 30)
    frl:SetSize(390, 235)
    frl:AddColumn("Name")

    local frt = lf.Create("textinput", fr)
    frt:SetPos(5, 270)
    frt:SetWidth(300)
    local frb = lf.Create("button", fr)
    frb:SetPos(315, 270)

    frl.OnRowSelected = function(p, row, data)
        frt:SetText(data[1])
    end

    fr.OnClose = function(o)
        frl:Clear()
        fr:SetVisible(false):SetModal(false)
        return false
    end

    local function save(type, cb)
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
            fr:SetVisible(true):SetModal(true):Center()
        end
    end

    local function load(type, cb)
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
            fr:SetVisible(true):SetModal(true):Center()
        end
    end


    local sb = lf.Create("button")
    sb:SetText("Save Lua")
    sb:SetWidth(67)
    sb.OnClick = save("lua", function(f) sound:save(f, true) end)
    f:AddItem(sb)

    local lb = lf.Create("button")
    lb:SetText("Load Lua")
    lb:SetWidth(67)
    lb.OnClick = load("lua", function(f) sound:load(f) end)
    f:AddItem(lb)

    local bsb = lf.Create("button")
    bsb:SetText("Save binary")
    bsb:SetWidth(67)
    bsb.OnClick = save("sfs", function(f) sound:saveBinary(f) end)
    f:AddItem(bsb)

    local blb = lf.Create("button")
    blb:SetText("Load binary")
    blb:SetWidth(67)
    blb.OnClick = load("sfs", function(f) sound:loadBinary(f) end)
    f:AddItem(blb)

    local eb = lf.Create("button")
    eb:SetText("Export WAV")
    eb:SetWidth(140)
    eb.OnClick = save("wav", function(f) sound:exportWAV(f) end)
    f:AddItem(eb)

    f:SetPos(485, 455)
    f:SetSize(150, 140)

    -- well ugh
    lb:SetPos(78, 47)
    bsb:SetY(77)
    blb:SetPos(78, 77)
    eb:SetY(107)
end

function createOther()
    local f = lf.Create("form")
    f:SetName("Wave View")
    f:SetPos(485, 5)
    f:SetSize(150, 170)
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


    local f = lf.Create("form")
    f:SetName("Volume")

    local t = lf.Create("text")
    t:SetText("Master 0.5")
    f:AddItem(t)
    local s = lf.Create("slider")
    s:SetMinMax(0, 1)
    s:SetSize(135, 20)
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

    local t = lf.Create("text")
    t:SetText("Sound 0.5")
    f:AddItem(t)
    local s = lf.Create("slider")
    s:SetMinMax(0, 1)
    s:SetSize(135, 20)
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

    f:SetPos(485, 340)
    f:SetWidth(150)


    local f = lf.Create("form")
    f:SetName("Times / Duration")

    local t = lf.Create("text")
    t:SetText("Generation: 0ms")
    f:AddItem(t)
    statistics.generationtext = t

    local t = lf.Create("text")
    t:SetText("Transfer: 0ms")
    f:AddItem(t)
    statistics.transfertext = t

    local t = lf.Create("text")
    t:SetText("Wave View: 0ms")
    f:AddItem(t)
    statistics.waveviewtext = t

    local t = lf.Create("text")
    t:SetText("Duration: 0ms")
    f:AddItem(t)
    statistics.durationtext = t

    f:SetPos(485, 185)
    f:SetWidth(150)
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

    guiparams.waveform:SetChoice(waveFormList[sound.wavetype + 1])
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

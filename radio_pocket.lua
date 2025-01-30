local basaltExists = fs.exists("basalt.lua")

if(basaltExists == false) then
    shell.run("wget run https://basalt.madefor.cc/install.lua packed")
end

local basalt = require("basalt")
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()
 -- Change this to point at your server instance (the C# one)
convertUrl = "ws://127.0.0.1:2468"

local stations = {
    { name = "Truckers FM", url = "https://live.truckers.fm" },
    { name = "99.9 Virgin Radio Toronto", url = "https://18153.live.streamtheworld.com/CKFMFMAAC_SC" },
    { name = "Jammin' 107.7 FM", url="https://crystalout.surfernetwork.com:8001/WWRX_MP3"},
    { name = ".977 Today's Hits", url = "https://15113.live.streamtheworld.com/977_HITSAAC_SC"},
    { name = "Chirp", url = "http://stream.rtmp.ca/hls/chirper.m3u8"},
    { name = "NeuroSama", url = "https://www.youtube.com/watch?v=thCiTnOzkOM"},
}


-- Discover speakers
local speakers = {}
for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == "speaker" then
        table.insert(speakers, peripheral.wrap(side))
    end
end

local ws = nil
local audioBuffer = {}
local BUFFER_SIZE = 20
local running = false

local function playOnSpeaker(speaker, decoded)
    local play_success, play_err = pcall(function()
        while not speaker.playAudio(decoded) do
            os.pullEvent("speaker_audio_empty")
        end
    end)
    if not play_success then
        print("Error playing audio on speaker:", play_err)
    end
end


parallel.waitForAny(
    function()
        while running do
            basalt.autoUpdate()
            os.sleep(0.05)
        end
    end,
    function()
        while running do
            -- same playAudio logic here
        end
    end
)


local function playAudio()
    while running do
        if #audioBuffer > 0 then
            local chunk = table.remove(audioBuffer, 1)
            local ok, decoded = pcall(decoder, chunk)
            if ok then
                for _, sp in ipairs(speakers) do
                    playOnSpeaker(sp, decoded)
                end
            end
        else
            os.sleep(0.05)
        end
    end
end

local function receiveAudio()
    while running and ws and not ws.isClosed do
        local chunk = ws.receive()
        if chunk then
            table.insert(audioBuffer, chunk)
            if #audioBuffer > BUFFER_SIZE then
                table.remove(audioBuffer, 1)
            end
        else
            running = false
        end
    end
end

parallel.waitForAny(
    function()
        while running do
            local eventData = {os.pullEvent()}
            basalt.processEvent(eventData)
            basalt.autoUpdate()
        end
    end,
    function()
        while running do
            playAudio()
        end
    end,
    function()
        while running do
            receiveAudio()
        end
    end
)

local function stopRadio()
    running = false
    if ws then
        pcall(function() ws.close() end)
    end
end

local function startRadio(stationUrl)
    stopRadio()
    local w, err = http.websocket(convertUrl)
    w.send(stationUrl)
    if not w then return end
    ws = w
    running = true
    parallel.waitForAny(playAudio, receiveAudio)
end

local mainFrame = basalt.createFrame()
local list = mainFrame:addList():setPosition(2,2):setSize(24,10)
for _, s in ipairs(stations) do
    list:addItem(s.name)
end

local toggleBtn = mainFrame:addButton():setPosition(2,16):setSize(10,3):setText("Start")
toggleBtn:onClick(function()
    if running then
        toggleBtn:setText("Start")
        stopRadio()
        running = false
    else
        local station = stations[list:getItemIndex()]
        if station then
            running = true
            toggleBtn:setText("Stop")
            startRadio(station.url)
        end
    end
end)

basalt.autoUpdate()


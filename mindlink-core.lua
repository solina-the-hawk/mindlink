-- =========================================================================
-- MINDLINK: Telepathic Communication Ledger
-- =========================================================================

Mindlink = Mindlink or {}
Mindlink.consoles = Mindlink.consoles or {}
Mindlink.tabs = Mindlink.tabs or {}
Mindlink.events = Mindlink.events or {}

-- =========================================================================
-- Configuration
-- =========================================================================
Mindlink.config = {
    -- Dimensions & Position (Uses Geyser formatting)
    x = "-25%", y = -550,
    width = "25%", height = "50%",
    
    fontSize = 9,
    timestamp = false, -- false or "[HH:mm:ss] "
    
    -- Main Window Behavior
    gagMain = false,    
    colorMain = true,   
    
    -- XTerm256 Color for Emotes. (242 is dark grey). 
    -- Mindlink will automatically set this in Achaea and create the trigger!
    emoteColor = 242,
    
    hiddenChannels = {
        ["clt"] = false,
        ["market"] = true,
    },
    
    ignorePatterns = {
        -- Because we use XTerm 237+, you rarely need these anymore!
        "^writ%.%s*$", 
        "^%s*[%w_]+%s+%d+%s+%d+%s+", -- Added %s* to catch invisible leading spaces!
        "^%s*[FB]G:%s+%d",           -- Catch palette rows even with leading spaces
    },
    
    allTab = "All",
    
    tabNames = {
        "All", "Local", "City", "Party", "Tells", "Clans", "Misc"
    },
    
    logTabs = {
        ["Local"] = true,
        ["Tells"] = true,
    },
    
    channelMap = {
        say = "Local", yell = "Local", whisper = "Local",
        ct = "City", ht = "City",
        party = "Party", tell = "Tells",
        newbie = "Misc", market = "Misc",
        clt = "Clans", ot = "Clans", 
    },
    
    colors = {
        activeTab = {r = 40, g = 60, b = 90},   
        inactiveTab = {r = 30, g = 30, b = 30}, 
        windowBg = {r = 0, g = 0, b = 0},       
    }, 

    highlights = {
        words = {
            ["Zaleria"] = "<200,170,191>",
            ["Solina"] = "<125,249,255>",
        },
        channels = {
            ["ct"] = "<0, 191, 255>",
            ["hnt"] = "<135, 206, 235>",
            ["ht"] = "<0, 191, 255>",  
        },
        linesContaining = {}
    }
}

Mindlink.currentTab = Mindlink.currentTab or Mindlink.config.allTab

-- =========================================================================
-- Automated Logging
-- =========================================================================
function Mindlink.logMessage(tabName, rawText)
    if not Mindlink.config.logTabs[tabName] then return end
    
    local plainText = string.gsub(rawText, "\27%[[%d;]*m", "")
    local logDir = getMudletHomeDir() .. "/MindlinkLogs"
    if not lfs.attributes(logDir) then lfs.mkdir(logDir) end
    
    local dateStr = os.date("%Y-%m-%d")
    local timeStr = os.date("%H:%M:%S")
    local fileName = logDir .. "/" .. tabName .. "_" .. dateStr .. ".txt"
    
    local file = io.open(fileName, "a")
    if file then
        file:write("[" .. timeStr .. "] " .. plainText .. "\n")
        file:close()
    end
end

-- =========================================================================
-- UI Creation & Interaction
-- =========================================================================
function Mindlink.createUI()
    Mindlink.container = Geyser.Container:new({
        name = "MindlinkContainer",
        x = Mindlink.config.x, y = Mindlink.config.y,
        width = Mindlink.config.width, height = Mindlink.config.height,
    })

    Mindlink.tabBar = Geyser.HBox:new({
        name = "MindlinkTabBar", x = 0, y = 0,
        width = "100%", height = "25px",
    }, Mindlink.container)

    for _, tabName in ipairs(Mindlink.config.tabNames) do
        Mindlink.tabs[tabName] = Geyser.Label:new({
            name = "MindlinkTab_" .. tabName,
        }, Mindlink.tabBar)
        
        Mindlink.tabs[tabName]:echo("<center>" .. tabName .. "</center>")
        Mindlink.tabs[tabName]:setClickCallback("Mindlink.switchTab", tabName)

        Mindlink.consoles[tabName] = Geyser.MiniConsole:new({
            name = "MindlinkWin_" .. tabName,
            x = 0, y = "25px", width = "100%", height = "-25px",
            color = "black",
        }, Mindlink.container)
        
        Mindlink.consoles[tabName]:setFontSize(Mindlink.config.fontSize)
        Mindlink.consoles[tabName]:setWrap(80)
        
        local bg = Mindlink.config.colors.windowBg
        Mindlink.consoles[tabName]:setColor(bg.r, bg.g, bg.b)
        Mindlink.consoles[tabName]:hide()
    end

    Mindlink.switchTab(Mindlink.currentTab)
end

function Mindlink.switchTab(tabName)
    local activeCol = Mindlink.config.colors.activeTab
    local inactiveCol = Mindlink.config.colors.inactiveTab

    if Mindlink.currentTab and Mindlink.consoles[Mindlink.currentTab] then
        Mindlink.consoles[Mindlink.currentTab]:hide()
        Mindlink.tabs[Mindlink.currentTab]:setColor(inactiveCol.r, inactiveCol.g, inactiveCol.b)
    end

    Mindlink.consoles[tabName]:show()
    Mindlink.tabs[tabName]:setColor(activeCol.r, activeCol.g, activeCol.b)
    Mindlink.currentTab = tabName
end

-- =========================================================================
-- Custom Highlighting Engine
-- =========================================================================
function Mindlink.applyHighlights(text, channel)
    local result = text

    local function fixColor(colorStr)
        if not colorStr or colorStr == "" then return "" end
        if type(colorStr) == "table" then
            return string.format("<%d,%d,%d>", colorStr[1], colorStr[2], colorStr[3] or 255)
        end
        local cleanColor = string.gsub(colorStr, "[<> ]", "")
        if color_table[cleanColor] then
            local rgb = color_table[cleanColor]
            return string.format("<%d,%d,%d>", rgb[1], rgb[2], rgb[3])
        end
        return "<" .. cleanColor .. ">"
    end

    if channel then
        for prefix, color in pairs(Mindlink.config.highlights.channels) do
            if string.find(channel:lower(), "^" .. prefix:lower()) then
                local safeColor = fixColor(color)
                result = safeColor .. string.gsub(result, "<[0-9,:]+>", "")
                break 
            end
        end
    end

    for str, color in pairs(Mindlink.config.highlights.linesContaining) do
        if string.find(result, str, 1, true) then
            local safeColor = fixColor(color)
            result = safeColor .. string.gsub(result, "<[0-9,:]+>", "")
            break 
        end
    end

    local function smartWordHighlight(word, color)
        local safeColor = fixColor(color)
        local escapedWord = word:gsub("([^%w])", "%%%1")
        local pattern = string.match(word, "^%a+$") and ("(%f[%a]" .. escapedWord .. "%f[%A])") or ("(" .. escapedWord .. ")")
        
        local out = ""
        local activeColor = string.match(result, "^(<[0-9,:]+>)") or "<192,192,192>"
        local lastEnd = 1
        
        for colorTag in string.gmatch(result, "<[0-9,:]+>") do
            local startIdx, endIdx = string.find(result, colorTag, lastEnd, true)
            local textSegment = string.sub(result, lastEnd, startIdx - 1)
            
            textSegment = string.gsub(textSegment, pattern, safeColor .. "%1" .. activeColor)
            
            out = out .. textSegment .. colorTag
            activeColor = colorTag
            lastEnd = endIdx + 1
        end
        
        local finalSegment = string.sub(result, lastEnd)
        finalSegment = string.gsub(finalSegment, pattern, safeColor .. "%1" .. activeColor)
        out = out .. finalSegment
        
        result = out
    end

    for word, color in pairs(Mindlink.config.highlights.words) do
        smartWordHighlight(word, color)
    end

    if Legacy and Legacy.NDB and type(Legacy.NDB.db) == "table" then
        local plainText = string.gsub(result, "<[0-9,:]+>", "")
        local processedNames = {}
        
        for word in string.gmatch(plainText, "%a+") do
            local titleWord = word:sub(1,1):upper() .. word:sub(2):lower()
            
            if not processedNames[titleWord] and not Mindlink.config.highlights.words[titleWord] then
                local entry = Legacy.NDB.db[titleWord]
                if entry and entry.city then
                    local color = nil
                    if Legacy.Settings and Legacy.Settings.NDB and Legacy.Settings.NDB.Config then
                        local cityConfig = Legacy.Settings.NDB.Config[entry.city:lower()]
                        if cityConfig and cityConfig.color then
                            color = cityConfig.color
                        end
                    end
                    if color then
                        smartWordHighlight(titleWord, color)
                        processedNames[titleWord] = true
                    end
                end
            end
        end
    end

    return result
end

-- =========================================================================
-- Tab Printing Helper
-- =========================================================================
function Mindlink.appendChat(targetTab, formattedText, timeStr)
    local console = Mindlink.consoles[targetTab]
    if not console then return end

    console:decho(timeStr .. formattedText .. "\n")

    if Mindlink.config.allTab and targetTab ~= Mindlink.config.allTab then
        local allConsole = Mindlink.consoles[Mindlink.config.allTab]
        if allConsole then
            allConsole:decho(timeStr .. formattedText .. "\n")
        end
    end
end

-- =========================================================================
-- GMCP Chat Processing
-- =========================================================================
function Mindlink.onGMCPChat()
    if not gmcp.Comm or not gmcp.Comm.Channel or not gmcp.Comm.Channel.Text then return end
    
    local channel = gmcp.Comm.Channel.Text.channel
    local text = gmcp.Comm.Channel.Text.text
    
    if Mindlink.config.debug then
        cecho(string.format("\n<yellow>[Mindlink Debug] Raw Channel ID: <red>'%s'<reset>\n", channel))
    end

    local targetTab = "Misc" 
    for prefix, mappedTab in pairs(Mindlink.config.channelMap) do
        if string.find(channel:lower(), "^" .. prefix:lower()) then
            targetTab = mappedTab
            break
        end
    end

    if not Mindlink.tabs[targetTab] then targetTab = Mindlink.config.allTab end
    
    local isChannelHidden = false
    for prefix, _ in pairs(Mindlink.config.hiddenChannels) do
        if string.find(channel:lower(), "^" .. prefix:lower()) then
            isChannelHidden = true
            break
        end
    end

    local timeStr = Mindlink.config.timestamp and getTime(true, Mindlink.config.timestamp) or ""
    local formattedText = ansi2decho(text):gsub("<reset>", "")
    formattedText = Mindlink.applyHighlights(formattedText, channel)

    Mindlink.appendChat(targetTab, formattedText, timeStr)
    Mindlink.logMessage(targetTab, text)

    local cleanText = ansi2string(text):gsub("%s+$", "")
    
    local function processMainWindow(action)
        local found = false
        local lineNum = getLineCount("main")
        for i = lineNum, math.max(1, lineNum - 10), -1 do
            moveCursor("main", 0, i)
            local currentLine = getCurrentLine("main")
            if string.find(currentLine, cleanText, 1, true) then
                selectCurrentLine("main")
                action()
                found = true
                break
            end
        end
        moveCursor("main", 0, getLineCount("main"))
        if not found then
            tempTrigger(cleanText, function() 
                selectCurrentLine()
                action() 
            end, 1)
        end
    end

    if Mindlink.config.gagMain or isChannelHidden then
        processMainWindow(function() deleteLine() end)
    elseif Mindlink.config.colorMain then
        local mainText = timeStr .. formattedText .. "<192,192,192>"
        processMainWindow(function() dreplace(mainText) end)
    end
end

-- =========================================================================
-- Trigger-Based Capture (For Emotes/Color Triggers)
-- =========================================================================
function Mindlink.captureFromTrigger(targetTab)
    local console = Mindlink.consoles[targetTab]
    if not console then return end

    local rawText = line
    
    if Mindlink.config.ignorePatterns then
        for _, pattern in ipairs(Mindlink.config.ignorePatterns) do
            if string.find(rawText, pattern) then return end
        end
    end

    local timeStr = Mindlink.config.timestamp and getTime(true, Mindlink.config.timestamp) or ""
    local formattedText = ""
    local lastColor = ""
    local lineLen = utf8 and utf8.len(line) or string.len(line)

    for i = 1, lineLen do
        selectSection(i - 1, 1)
        local char = getSelection()
        if char == "" then break end
        
        local r, g, b = getFgColor()
        local colorTag = string.format("<%d,%d,%d>", r, g, b)
        
        if colorTag ~= lastColor then
            formattedText = formattedText .. colorTag
            lastColor = colorTag
        end
        
        formattedText = formattedText .. char
    end
    deselect() 
    
    formattedText = Mindlink.applyHighlights(formattedText)

    Mindlink.appendChat(targetTab, formattedText, timeStr)
    Mindlink.logMessage(targetTab, rawText)

    if Mindlink.config.gagMain then
        deleteLine()
    elseif Mindlink.config.colorMain then
        selectCurrentLine()
        dreplace(timeStr .. formattedText)
    end
end

-- =========================================================================
-- Output Gagging Utility (Hides Achaea Config Walls)
-- =========================================================================
function Mindlink.silenceColorConfig()
    local startID
    -- Trigger 1: Listens for the very first line of the block
    startID = tempRegexTrigger("^Channel emotes set to \\d+\\.", function()
        deleteLine()
        
        local gagID
        -- Trigger 2: Aggressively gags everything until the end phrase is found
        gagID = tempRegexTrigger("^.*$", function()
            deleteLine()
            if string.find(line, "To restore the defaults, enter CONFIG COLOUR DEFAULT", 1, true) then
                killTrigger(gagID) -- Stop gagging!
            end
        end)
        
        -- Failsafe: Turn off the gag after 2.5 seconds just in case the end line drops
        tempTimer(2.5, function() if gagID then killTrigger(gagID) end end)
    end, 1) -- '1' means this start listener fires exactly once, then self-destructs
    
    -- Failsafe: Turn off the listener if the command fails
    tempTimer(2.5, function() if startID then killTrigger(startID) end end)
end

-- =========================================================================
-- In-Game Commands & Help Interface
-- =========================================================================
function Mindlink.showHelp()
    cecho("\n<dodger_blue>=======================================================================<reset>")
    cecho("\n<dodger_blue>                        M I N D L I N K   H E L P                      <reset>")
    cecho("\n<dodger_blue>=======================================================================<reset>\n")
    cecho("\n<white>Mindlink is a zero-dependency telepathic ledger. Most permanent changes")
    cecho("\n(like adding new tabs or custom colors) are made by editing the")
    cecho("\n<yellow>Mindlink.config<white> block at the very top of the Mindlink script.<reset>\n")
    
    cecho("\n<cyan>In-Game Commands (Current Session Only):<reset>")
    cecho("\n  <yellow>mindlink gag <channel><reset>  - Toggles hiding a channel from the main window.")
    cecho("\n  <yellow>mindlink emote <color><reset>  - Tests a new XTerm256 color for emote catching.")
    cecho("\n  <yellow>mindlink toggle gag<reset>     - Toggles hiding ALL captured chat from the main window.")
    cecho("\n  <yellow>mindlink toggle color<reset>   - Toggles applying custom colors to the main window.")
    cecho("\n  <yellow>mindlink debug<reset>          - Toggles printing raw GMCP channel IDs (for setup).")
    
    cecho("\n\n<cyan>How to Catch Emotes (Automatic!):<reset>")
    cecho("\n  Mindlink catches emotes completely automatically using XTerm256 colors.")
    cecho("\n  To permanently change the color, edit <yellow>Mindlink.config.emoteColor<reset> in the script.")
    cecho("\n  Mindlink will instantly sync Achaea and your Mudlet triggers on save!")
    
    cecho("\n<dodger_blue>=======================================================================<reset>\n")
end

function Mindlink.handleCommand(args)
    local cmd = args:lower()
    
    if cmd == "help" or cmd == "" then
        Mindlink.showHelp()
        
    elseif cmd == "toggle gag" then
        Mindlink.config.gagMain = not Mindlink.config.gagMain
        local state = Mindlink.config.gagMain and "<green>ON" or "<red>OFF"
        cecho("\n<dodger_blue>[Mindlink]:<reset> Main Window Gagging is now " .. state .. "<reset>\n")
        
    elseif cmd == "toggle color" then
        Mindlink.config.colorMain = not Mindlink.config.colorMain
        local state = Mindlink.config.colorMain and "<green>ON" or "<red>OFF"
        cecho("\n<dodger_blue>[Mindlink]:<reset> Main Window Coloring is now " .. state .. "<reset>\n")
        
    elseif cmd == "debug" then
        Mindlink.config.debug = not Mindlink.config.debug
        local state = Mindlink.config.debug and "<green>ON" or "<red>OFF"
        cecho("\n<dodger_blue>[Mindlink]:<reset> GMCP Channel Sniffer is now " .. state .. "<reset>\n")
        
    elseif cmd:sub(1, 4) == "gag " then
        local chan = cmd:sub(5):match("^%s*(.-)%s*$") 
        if chan == "" then
            cecho("\n<dodger_blue>[Mindlink]:<reset> Please specify a channel prefix (e.g., <yellow>mindlink gag ct<reset>)\n")
        else
            if Mindlink.config.hiddenChannels[chan] then
                Mindlink.config.hiddenChannels[chan] = nil
                cecho("\n<dodger_blue>[Mindlink]:<reset> Channel '<yellow>" .. chan .. "<reset>' is no longer gagged.\n")
            else
                Mindlink.config.hiddenChannels[chan] = true
                cecho("\n<dodger_blue>[Mindlink]:<reset> Channel '<yellow>" .. chan .. "<reset>' is now hidden (session only).\n")
            end
        end
        
    elseif cmd:sub(1, 6) == "emote " then
        local colorNum = cmd:sub(7):match("^%s*(%d+)%s*$")
        if colorNum then
            Mindlink.config.emoteColor = tonumber(colorNum)
            
            -- Silently eat the massive output block
            Mindlink.silenceColorConfig()
            
            send("config colour emotes " .. colorNum, false)
            
            if Mindlink.emoteTrigger then killTrigger(Mindlink.emoteTrigger) end
            Mindlink.emoteTrigger = tempColorTrigger(Mindlink.config.emoteColor, -1, [[Mindlink.captureFromTrigger("Local")]])
            
            cecho("\n<dodger_blue>[Mindlink]:<reset> Emote color set to " .. colorNum .. " and trigger updated!\n")
            cecho("<dodger_blue>[Mindlink]:<reset> (Note: Update <yellow>Mindlink.config.emoteColor<reset> in the script to make this permanent.)\n")
        else
            cecho("\n<dodger_blue>[Mindlink]:<reset> Please specify a valid XTerm256 color number (0-255).\n")
        end
        
    else
        cecho("\n<dodger_blue>[Mindlink]:<reset> Unknown command. Type <yellow>mindlink help<reset> for options.\n")
    end
end

-- =========================================================================
-- Initialization
-- =========================================================================
function Mindlink.init()
    for _, handlerID in ipairs(Mindlink.events) do killAnonymousEventHandler(handlerID) end
    Mindlink.events = {}
    if Mindlink.aliasHandler then killAlias(Mindlink.aliasHandler) end

    sendGMCP([[Core.Supports.Add ["Comm.Channel 1"] ]])
    table.insert(Mindlink.events, registerAnonymousEventHandler("gmcp.Comm.Channel.Text", "Mindlink.onGMCPChat"))

    Mindlink.aliasHandler = tempAlias("^mindlink(?: (.*))?$", [[
        local args = matches[2] or "help"
        Mindlink.handleCommand(args)
    ]])

    if Mindlink.emoteTrigger then killTrigger(Mindlink.emoteTrigger) end
    
    -- Silently eat the massive output block on load
    Mindlink.silenceColorConfig()
    send("config colour emotes " .. Mindlink.config.emoteColor, false)
    
    Mindlink.emoteTrigger = tempColorTrigger(Mindlink.config.emoteColor, -1, [[Mindlink.captureFromTrigger("Local")]])

    Mindlink.createUI()
    cecho("\n<green>[Mindlink]:<reset> Telepathic Ledger Initialized. Type <yellow>mindlink help<reset> for commands.\n")
end

Mindlink.init()
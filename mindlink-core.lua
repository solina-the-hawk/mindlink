-- To catch emotes properly, you need to configure their colour to something
-- seldom used elsewhere, select that colour in the Mindlink trigger, and
-- then add exclusions for anything else which still does use that colour in
-- the config below. I find setting emotes to dark grey works best for this,
-- since by default it's used by very little, and so the default config below
-- has an ignore set up for Hashan's 'leaden' alchemy room descriptions.
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
    gagMain = false,    -- Set to true to hide ALL captured chat from the main window
    colorMain = true,   -- Set to true to apply our custom colors to the main window too!
    
    -- Hide specific channels from the main window (they still go to your tabs!)
    -- Use the GMCP prefix (e.g., "clt" for clans)
    hiddenChannels = {
        ["clt"] = true,
        ["market"] = true,
        -- ["ot"] = true,
    },
    
    ignorePatterns = {
        "Lines of leaden shadow coil underfoot",
        "^writ%.%s*$" -- The ^ means "starts with" and %s*$ means "only spaces after". 
    },
    
    allTab = "All",
    
    -- The tabs you want created, in order from left to right
    tabNames = {
        "All", "Local", "City", "Party", "Tells", "Clans", "Misc"
    },
    
    -- Automated Logging
    -- Set to true for any tab you want automatically logged to text files
    logTabs = {
        ["Local"] = true,
        ["Tells"] = true,
    },
    
    -- Map GMCP channel prefixes to your specific tabs
    channelMap = {
        say = "Local",
        yell = "Local",
        whisper = "Local",
        ct = "City",
        ht = "City",
        party = "Party",
        tell = "Tells",
        newbie = "Misc",
        market = "Misc",
        clt = "Clans", -- Clans
        ot = "Clans",  -- Order
    },
    
    -- Colors (R, G, B)
    colors = {
        activeTab = {r = 40, g = 60, b = 90},   -- Muted blue for active
        inactiveTab = {r = 30, g = 30, b = 30}, -- Dark grey for inactive
        windowBg = {r = 0, g = 0, b = 0},       -- Black chat background
    }, 

    -- =========================================================================
    -- Custom Highlights
    -- Use Mudlet color tags (e.g., "<gold>", "<255,0,0>")
    -- =========================================================================
    highlights = {
        -- Highlight specific words/names anywhere they appear
        words = {
            ["Zaleria"] = "<200,170,191>",
        },
        
        -- Highlight the ENTIRE line if it comes from a specific GMCP channel
        -- Note: Make sure to use the raw GMCP channel name (e.g., "ct", "cyrene")
        channels = {
            ["ct"] = "<0, 191, 255>",
            ["hnt"] = "<135, 206, 235>",
            ["ht"] = "<0, 191, 255>",  
        },
        
        -- Highlight the ENTIRE line if it contains a specific string
        linesContaining = {
            -- ["has been slain"] = "<red>",
        }
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
    if not lfs.attributes(logDir) then
        lfs.mkdir(logDir)
    end
    
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
-- UI Creation
-- =========================================================================
function Mindlink.createUI()
    Mindlink.container = Geyser.Container:new({
        name = "MindlinkContainer",
        x = Mindlink.config.x, y = Mindlink.config.y,
        width = Mindlink.config.width, height = Mindlink.config.height,
    })

    Mindlink.tabBar = Geyser.HBox:new({
        name = "MindlinkTabBar",
        x = 0, y = 0,
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
            x = 0, y = "25px",
            width = "100%", height = "-25px",
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

-- =========================================================================
-- UI Interaction
-- =========================================================================
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
    
    -- Dynamically print the channel ID if the user typed "mindlink debug"
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

    -- 1. Generate the fully highlighted string
    local timeStr = Mindlink.config.timestamp and getTime(true, Mindlink.config.timestamp) or ""
    local formattedText = ansi2decho(text):gsub("<reset>", "")
    formattedText = Mindlink.applyHighlights(formattedText, channel)

    -- 2. Print to the Tabs
    Mindlink.appendChat(targetTab, formattedText, timeStr)
    Mindlink.logMessage(targetTab, text)

    -- 3. Handle Main Window (Buffer Scanning to fix GMCP desync!)
    -- Strip ANSI and trailing whitespace for a flawless text match
    local cleanText = ansi2string(text):gsub("%s+$", "")
    
    local function processMainWindow(action)
        local found = false
        local lineNum = getLineCount("main")
        
        -- Scan the last 10 lines of the buffer (Looking back in time)
        for i = lineNum, math.max(1, lineNum - 10), -1 do
            moveCursor("main", 0, i)
            local currentLine = getCurrentLine("main")
            
            -- If we find the text already printed, process it immediately
            if string.find(currentLine, cleanText, 1, true) then
                selectCurrentLine("main")
                action()
                found = true
                break
            end
        end
        
        -- Snap the invisible cursor back to the bottom of the screen
        moveCursor("main", 0, getLineCount("main"))
        
        -- If it wasn't in the buffer, set a substring trigger to catch it when it arrives
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
        -- Explicitly append the default grey to guarantee the color doesn't bleed to prompts
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
            if string.find(rawText, pattern) then
                return
            end
        end
    end

    -- 1. Extract raw line and format it
    local timeStr = Mindlink.config.timestamp and getTime(true, Mindlink.config.timestamp) or ""
    
    -- THE FIX: Scan the line character-by-character to perfectly preserve ANY 
    -- internal color changes (like SAY colors inside emotes)
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
    deselect() -- Clear the selection so we don't mess up the visual buffer
    
    -- Pass the perfectly reconstructed multi-color string through our highlighter
    formattedText = Mindlink.applyHighlights(formattedText)

    -- 2. Print to the Tabs
    Mindlink.appendChat(targetTab, formattedText, timeStr)
    Mindlink.logMessage(targetTab, rawText)

    -- 3. Handle Main Window
    if Mindlink.config.gagMain then
        deleteLine()
    elseif Mindlink.config.colorMain then
        selectCurrentLine()
        dreplace(timeStr .. formattedText)
    end
end

-- =========================================================================
-- Initialization
-- =========================================================================
function Mindlink.init()
    -- Kill old events
    for _, handlerID in ipairs(Mindlink.events) do
        killAnonymousEventHandler(handlerID)
    end
    Mindlink.events = {}

    -- Kill old aliases
    if Mindlink.aliasHandler then killAlias(Mindlink.aliasHandler) end

    -- Register GMCP Event
    sendGMCP([[Core.Supports.Add ["Comm.Channel 1"] ]])
    table.insert(Mindlink.events, registerAnonymousEventHandler("gmcp.Comm.Channel.Text", "Mindlink.onGMCPChat"))

    -- Register Command Alias
    Mindlink.aliasHandler = tempAlias("^mindlink(?: (.*))?$", [[
        local args = matches[2] or "help"
        Mindlink.handleCommand(args)
    ]])

    Mindlink.createUI()
    cecho("\n<green>[Mindlink]:<reset> Telepathic Ledger Initialized. Type <yellow>mindlink help<reset> for commands.\n")
end

Mindlink.init()

-- =========================================================================
-- In-Game Commands & Help Interface
-- =========================================================================
function Mindlink.showHelp()
    cecho("\n<dodger_blue>=======================================================================<reset>")
    cecho("\n<dodger_blue>                        M I N D L I N K   H E L P                      <reset>")
    cecho("\n<dodger_blue>=======================================================================<reset>\n")
    cecho("\n<white>Mindlink is a zero-dependency telepathic ledger. Most lasting config changes")
    cecho("\n<white>(like adding new tabs or custom colors) are made by editing the")
    cecho("\n<yellow>Mindlink.config<white> block at the very top of the Mindlink script.<reset>\n")
    
    cecho("\n<cyan>In-Game Commands (Current Session Only):<reset>")
    cecho("\n  <yellow>mindlink toggle gag<reset>   - Toggles hiding captured chat from the main window.")
    cecho("\n  <yellow>mindlink toggle color<reset> - Toggles applying custom colors to the main window.")
    cecho("\n  <yellow>mindlink debug<reset>        - Toggles printing raw GMCP channel IDs (for setup).")
    
    cecho("\n\n<cyan>How to Map a New Channel:<reset>")
    cecho("\n  1. Turn on <yellow>mindlink debug<reset> and speak on the channel to find its raw ID.")
    cecho("\n  2. Open the script and add that ID to <yellow>Mindlink.config.channelMap<reset>.")
    cecho("\n     Example: <white>[\"market\"] = \"Misc\",<reset>")
    
    cecho("\n\n<cyan>How to Hide a Spammy Channel from main output:<reset>")
    cecho("\n  Add its raw ID to <yellow>Mindlink.config.hiddenChannels<reset>.")
    cecho("\n  It will be gagged from the main window, but still log to your tabs.")
    
    cecho("\n\n<cyan>How to Catch Emotes:<reset>")
    cecho("\n  1. In Achaea, set emotes to a fairly unique color (this is dark grey): <white>CONFIG COLOUR EMOTES 8<reset>")
    cecho("\n  2. In Mudlet, make a Color Trigger looking for that exact Dark Grey colour.")
    cecho("\n  (foreground ANSI 8). One is included in the MPackage file.")
    cecho("\n  3. Make the trigger execute this script: <yellow>Mindlink.captureFromTrigger(\"Local\")<reset>")
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
        if Mindlink.config.debug then
            cecho("<gray>   (Speak on a channel to see its raw ID printed here!)<reset>\n")
        end
        
    else
        cecho("\n<dodger_blue>[Mindlink]:<reset> Unknown command. Type <yellow>mindlink help<reset> for options.\n")
    end
end

Mindlink.init()
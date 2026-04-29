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
    x = "-25%", y = -550,
    width = "25%", height = "50%",
    
    fontSize = 9,
    timestamp = false, 
    
    gagMain = false,    
    colorMain = true,   
    
    emoteColor = 242,
    
    hiddenChannels = {
        ["clt"] = false,
        ["market"] = true,
    },
    
    ignorePatterns = {
        "^writ%.%s*$", 
        "^%s*[%w_]+%s+%d+%s+%d+%s+", 
        "^%s*[FB]G:%s+%d",           
    },
    
    allTab = "All",
    
    tabNames = {
        "All", "Local", "City", "Party", "Tells", "Orgs", "Misc"
    },
    
    logTabs = {
        ["Local"] = true,
        ["Tells"] = true,
    },
    
    channelMap = {
        say = "Local", yell = "Local", whisper = "Local",
        shout = "Misc", 
        ct = "City", ht = "City", hnt = "City",
        party = "Party", intrepid = "Party", 
        tell = "Tells",
        newbie = "Misc", market = "Misc",
        clt = "Orgs", ot = "Orgs", 
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
            ["say"] = "<0, 255, 255>",
            ["whisper"] = "<0, 255, 255>",
            ["yell"] = "<255, 255, 0>",
        },
        linesContaining = {}
    }
}

Mindlink.currentTab = Mindlink.currentTab or Mindlink.config.allTab

-- =========================================================================
-- Universal Color Parser
-- =========================================================================
function Mindlink.parseColor(colorStr)
    if not colorStr then return 192, 192, 192 end
    if type(colorStr) == "table" then return colorStr[1], colorStr[2], colorStr[3] or 255 end
    local clean = string.gsub(colorStr, "[<> ]", "")
    if color_table[clean] then return unpack(color_table[clean]) end
    local r, g, b = string.match(clean, "(%d+),(%d+),(%d+)")
    if r then return tonumber(r), tonumber(g), tonumber(b) end
    return 192, 192, 192
end

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
-- Word Highlighting Engine (Channels Handled Externally Now)
-- =========================================================================
function Mindlink.applyWordHighlights(text)
    local result = text

    for str, color in pairs(Mindlink.config.highlights.linesContaining) do
        if string.find(result, str, 1, true) then
            local r, g, b = Mindlink.parseColor(color)
            local safeColor = string.format("<%d,%d,%d>", r, g, b)
            result = safeColor .. string.gsub(result, "<[%d,:]+>", "")
            break 
        end
    end

    local function smartWordHighlight(word, color)
        local r, g, b = Mindlink.parseColor(color)
        local safeColor = string.format("<%d,%d,%d>", r, g, b)
        local escapedWord = word:gsub("([^%w])", "%%%1")
        local pattern = string.match(word, "^%a+$") and ("(%f[%a]" .. escapedWord .. "%f[%A])") or ("(" .. escapedWord .. ")")
        
        local out = ""
        local activeColor = string.match(result, "^(<[%d,:]+>)") or "<192,192,192>"
        local lastEnd = 1
        
        for colorTag in string.gmatch(result, "<[%d,:]+>") do
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
-- GMCP Chat Processing (Decoupled Geyser/Main Pipelines)
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

    -- Process explicitly defined channel colors
    local chanColorStr = nil
    for prefix, color in pairs(Mindlink.config.highlights.channels) do
        if string.find(channel:lower(), "^" .. prefix:lower()) then
            chanColorStr = color
            break
        end
    end
    local cR, cG, cB
    if chanColorStr then
        cR, cG, cB = Mindlink.parseColor(chanColorStr)
    end

    -- 1. Format for Tabs (Geyser Window)
    local continuousText = text:gsub("\r?\n", " ")
    local timeStr = Mindlink.config.timestamp and getTime(true, Mindlink.config.timestamp) or ""
    
    local formattedText = ""
    if chanColorStr then
        -- FIXED: Force explicit RGB construction over purely stripped text. No grey ANSI tags survive!
        formattedText = string.format("<%d,%d,%d>", cR, cG, cB) .. ansi2string(continuousText)
    else
        -- Fallback to Achaea's native colors if channel is completely unmapped
        formattedText = ansi2decho(continuousText):gsub("<reset>", "")
    end
    
    formattedText = Mindlink.applyWordHighlights(formattedText)
    Mindlink.appendChat(targetTab, formattedText, timeStr)
    Mindlink.logMessage(targetTab, continuousText)

    -- 2. Mathematical Highlighting for Main Window
    local cleanLines = {}
    for s in string.gmatch(ansi2string(text), "([^\r\n]+)") do
        table.insert(cleanLines, s:match("^%s*(.-)%s*$") or s)
    end
    if #cleanLines == 0 then return end

    -- Core Painting Engine
    local function applyToMainWindow(lineStr, currentIdx)
        moveCursor("main", 0, currentIdx)
        local fullLine = getCurrentLine("main")
        local startIdx = string.find(fullLine, lineStr, 1, true)
        
        if not startIdx then return currentIdx + 1 end 
        
        local startPos = startIdx - 1 
        
        if Mindlink.config.gagMain or isChannelHidden then
            local currentLineTrimmed = fullLine:match("^%s*(.-)%s*$")
            if currentLineTrimmed == lineStr then
                deleteLine() 
                return currentIdx 
            else
                selectSection("main", startPos, string.len(lineStr))
                replace("") 
                return currentIdx + 1
            end
        elseif Mindlink.config.colorMain then
            if chanColorStr then
                selectSection("main", startPos, string.len(lineStr))
                setFgColor(cR, cG, cB)
            end
            
            for word, color in pairs(Mindlink.config.highlights.words) do
                local wR, wG, wB = Mindlink.parseColor(color)
                local escapedWord = word:gsub("([^%w])", "%%%1")
                local pattern = string.match(word, "^%a+$") and ("%f[%a]()" .. escapedWord .. "()%f[%A]") or ("()" .. escapedWord .. "()")
                
                local searchPos = 1
                while true do
                    local matchStart, matchEnd = string.match(lineStr, pattern, searchPos)
                    if not matchStart then break end
                    
                    local actualLen = matchEnd - matchStart
                    local sectionPos = startPos + (matchStart - 1)
                    
                    selectSection("main", sectionPos, actualLen)
                    setFgColor(wR, wG, wB)
                    
                    searchPos = matchEnd
                end
            end
            deselect("main")
            return currentIdx + 1
        end
        return currentIdx + 1
    end

    -- Look back in time 30 lines
    local found = false
    local lineNum = getLineCount("main")
    
    for i = lineNum, math.max(1, lineNum - 30), -1 do
        moveCursor("main", 0, i)
        local currentLine = getCurrentLine("main")
        
        if string.find(currentLine, cleanLines[1], 1, true) then
            found = true
            local targetIdx = i
            for j = 1, #cleanLines do
                targetIdx = applyToMainWindow(cleanLines[j], targetIdx)
            end
            break
        end
    end
    
    moveCursor("main", 0, getLineCount("main"))
    
    -- If not found, set temporary triggers
    if not found then
        for idx, lineText in ipairs(cleanLines) do
            local safeText = lineText:gsub("([%.%^%$%(%)%[%]%*%+%-%?%|%{%}\\])", "\\%1")
            
            local trigID
            trigID = tempRegexTrigger(safeText, function()
                applyToMainWindow(lineText, getLineNumber())
            end, 1)
            
            tempTimer(3, function() if trigID then killTrigger(trigID) end end)
        end
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
    
    -- Send fully formatted string to Geyser Tab
    formattedText = Mindlink.applyWordHighlights(formattedText)
    Mindlink.appendChat(targetTab, formattedText, timeStr)
    Mindlink.logMessage(targetTab, rawText)

    -- Handle Main Window (Mathematical Word Painting)
    if Mindlink.config.gagMain then
        deleteLine()
    elseif Mindlink.config.colorMain then
        -- Emotes already have the correct native game color. We just paint the names!
        for word, color in pairs(Mindlink.config.highlights.words) do
            local wR, wG, wB = Mindlink.parseColor(color)
            local escapedWord = word:gsub("([^%w])", "%%%1")
            local pattern = string.match(word, "^%a+$") and ("%f[%a]()" .. escapedWord .. "()%f[%A]") or ("()" .. escapedWord .. "()")
            
            local searchPos = 1
            while true do
                local matchStart, matchEnd = string.match(rawText, pattern, searchPos)
                if not matchStart then break end
                
                selectSection("main", matchStart - 1, matchEnd - matchStart)
                setFgColor(wR, wG, wB)
                searchPos = matchEnd
            end
        end
        deselect("main")
    end
end

-- =========================================================================
-- Output Gagging Utility (Hides Achaea Config Walls)
-- =========================================================================
function Mindlink.silenceColorConfig()
    local startID
    startID = tempRegexTrigger("^Channel emotes set to \\d+\\.", function()
        deleteLine()
        local gagID
        gagID = tempRegexTrigger("^.*$", function()
            deleteLine()
            if string.find(line, "To restore the defaults, enter CONFIG COLOUR DEFAULT", 1, true) then
                killTrigger(gagID) 
            end
        end)
        tempTimer(2.5, function() if gagID then killTrigger(gagID) end end)
    end, 1)
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
    cecho("\n  Mindlink catches emotes completely automatically using XTerm256 colors (TYPE COLOURS in game).")
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
    Mindlink.silenceColorConfig()
    send("config colour emotes " .. Mindlink.config.emoteColor, false)
    Mindlink.emoteTrigger = tempColorTrigger(Mindlink.config.emoteColor, -1, [[Mindlink.captureFromTrigger("Local")]])

    Mindlink.createUI()
    cecho("\n<green>[Mindlink]:<reset> Telepathic Ledger Initialized. Type <yellow>mindlink help<reset> for commands.\n")
end

-- =========================================================================
-- Initialization Hook
-- =========================================================================
if gmcp and gmcp.Char and gmcp.Char.Name then
    Mindlink.init()
else
    if Mindlink.loginTrigger then killTrigger(Mindlink.loginTrigger) end
    Mindlink.loginTrigger = tempRegexTrigger("Password correct\\. Welcome to Achaea\\.", function()
        Mindlink.init()
    end, 1)
end
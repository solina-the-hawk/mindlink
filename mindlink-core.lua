-- =========================================================================
-- MINDLINK: Telepathic Communication Ledger
-- A robust message catching interface for Mudlet, so you can happily talk
-- while sailing or traveling, and easily refer back to conversations without
-- losing your place in the main window.
-- Author: Solina (https://github.com/solina-the-hawk/mindlink/)
-- Version: 1.2.0
-- =========================================================================
Mindlink = Mindlink or {}

-- =========================================================================
-- Configuration
-- This is the only section of the script you should be editing, unless you
-- are confident you understand how things work and want to customize further!
-- It will also contain the most comments to help you out!
-- =========================================================================
Mindlink.config = {
    
    -- This controls where the Mindlink window appears on your screen, and how big it is. Adjust as needed!
    -- I strongly recommend creating a Display Border in your Mudlet profile preferences (Main Display tab) to 
    -- put this and other geyser windows into so they never overlap the main output!
    x = "-25%", y = -550,
    width = "25%", height = "50%",
    
    -- colors: The background colors for your Mindlink tabs and window using RGB (Red, Green, Blue) values.
    colors = {
        activeTab = {r = 40, g = 60, b = 90},   
        inactiveTab = {r = 30, g = 30, b = 30}, 
        windowBg = {r = 0, g = 0, b = 0},       
    }, 

    -- fontSize: This determines the size of text in the Mindlink window. You might want it smaller or bigger
    -- depending on how big you make the window itself!
    fontSize = 9,
    
    -- timestamp: Set to false to disable timestamps, true for a default "[hh:mm:ss] ", or use a custom
    -- string like: "(HH:mm) "
    timestamp = "(HH:mm) ", 
    
    -- colorMain: Set to true to apply your custom Mindlink colors to the text in your main window as well.
    colorMain = true,
    
    -- emoteColor: Set this color to one of the XTerm256 color numbers that Achaea uses (Type COLOURS in
    -- game to see them). This is how Mindlink identifies emotes to capture them.
    emoteColor = 242,

    -- gagMain: Set to true to hide ALL captured chat from your main window, routing it exclusively to
    -- the Mindlink tabs.
    gagMain = false, 
    
    -- hiddenChannels: If gagMain is false, you can use this list to hide SPECIFIC spammy channels from the 
    -- main window while keeping the rest. Set a channel to true to hide it, or false/remove it to show it.
    hiddenChannels = {
        ["clt"] = false,
        ["market"] = true,
    },

    -- ignorePatterns: This is a list of Regex patterns. If a captured line matches ANY of these patterns, it
    -- will be ignored and not sent to the Mindlink tabs or logs. (e.g., catching random combat numbers or 'writ.')
    ignorePatterns = {
        "^writ%.%s*$", 
        "^%s*[%w_]+%s+%d+%s+%d+%s+", 
        "^%s*[FB]G:%s+%d",           
    },
    
    -- allTab: The name of your catch-everything tab. If a message comes through a channel that isn't mapped 
    -- below, it will default to this tab.
    allTab = "All",
    
    -- tabNames: A list of every tab you want generated in the UI. You can name these whatever you like, 
    -- and have more or fewer, just make sure you map channels to them in the channelMap below!
    tabNames = {
        "All", "Local", "City", "Party", "Tells", "Orgs", "Misc"
    },
    
    -- channelMap: This tells Mindlink where to put incoming GMCP messages. 
    -- The left side is Achaea's internal channel prefix (e.g., "ct" for City), and the right side is 
    -- the exact name of the tab you defined in tabNames above.
    channelMap = {
        say = "Local", yell = "Local", whisper = "Local",
        shout = "Misc", 
        ct = "City", ht = "City", hnt = "City",
        party = "Party", intrepid = "Party", 
        tell = "Tells",
        newbie = "Misc", market = "Misc",
        clt = "Orgs", ot = "Orgs", 
    },
    
    -- logTabs: Choose which tabs get saved to text files on your computer. These default to false, but if
    -- you are interested in logging specific tabs, just add them here and set to true.
    logTabs = {
        ["All"] = false,
        ["Local"] = true,
        ["City"] = false,
        ["Party"] = false,
        ["Tells"] = true,
        ["Orgs"] = false,
        ["Misc"] = false,
    },

    -- highlights: The core color engine! Use Mudlet's <R,G,B> tag format for all colors here.
    highlights = {
        -- words: Force specific names or words to always be highlighted in a specific color.
        words = {
            ["Solina"] = "<125,249,255>",
        },
        -- channels: Force entire channels to be colored. (Note: say, whisper, and yell MUST be mapped 
        -- here to display properly in the Mindlink tabs).
        channels = {
            ["ct"] = "<0,191,255>",
            ["hnt"] = "<135,206,235>",
            ["ht"] = "<0,191,255>",  
            ["say"] = "<0,255,255>",
            ["whisper"] = "<0,255,255>",
            ["yell"] = "<255,255,0>",
        },
        -- linesContaining: If a message contains this exact string of text, the entire line will be painted.
        linesContaining = {
            -- Example: Enter a phrase of your choosing and watch the entire line containing it highlight!
            ["The sun shines brightly on the daisies"] = "<255,255,153>",
        }
}
}

Mindlink.currentTab = Mindlink.currentTab or Mindlink.config.allTab

-- =========================================================================
 -- Runtime States
 -- Internal variables used for math and tracking. Do not edit!
 -- =========================================================================
Mindlink.consoles = Mindlink.consoles or {}
Mindlink.tabs = Mindlink.tabs or {}
Mindlink.events = Mindlink.events or {}

-- =========================================================================
-- Universal Color Parser
-- This parses colors in various formats as well as named colors, and returns the RGB values Mudlet wants.
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
-- This automatically logs tabs specified in the config. Each tab gets its own file within a subfolder of
-- your Mudlet profile called 'MindlinkLogs', and each day's logs are separated into different files with
-- timestamped file names for easy location.
-- =========================================================================
function Mindlink.logMessage(tabName, rawText)
    if not Mindlink.config.logTabs[tabName] then return end
    
    local plainText = string.gsub(rawText, "\27%[[%d;]*m", "")
    
    -- 1. Check and create the master Mindlink folder
    local baseDir = getMudletHomeDir() .. "/Mindlink"
    if not lfs.attributes(baseDir) then lfs.mkdir(baseDir) end
    
    -- 2. Check and create the nested Logs folder
    local logDir = baseDir .. "/Logs"
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
-- This builds the Geyser window we stick everything in, creates tabs, colors them.
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
-- This is the core of the color engine that applies your word and line highlights.
-- =========================================================================
function Mindlink.applyWordHighlights(text)
    local result = text
    -- SLEDGEHAMMER: Strip absolutely every Mudlet tag to guarantee a clean text match
    local plainText = string.gsub(result, "<[^>]+>", "")

    for str, color in pairs(Mindlink.config.highlights.linesContaining) do
        if string.find(plainText, str, 1, true) then
            local r, g, b = Mindlink.parseColor(color)
            local safeColor = string.format("<%d,%d,%d>", r, g, b)
            -- Apply the color and use plainText to wipe out any native game tags
            result = safeColor .. plainText
            break 
        end
    end

    local function smartWordHighlight(word, color)
        local r, g, b = Mindlink.parseColor(color)
        local safeColor = string.format("<%d,%d,%d>", r, g, b)
        local escapedWord = word:gsub("([^%w])", "%%%1")
        local pattern = string.match(word, "^%a+$") and ("(%f[%a]" .. escapedWord .. "%f[%A])") or ("(" .. escapedWord .. ")")
        
        local out = ""
        local activeColor = string.match(result, "^(<[^>]+>)") or "<192,192,192>"
        local lastEnd = 1
        
        for colorTag in string.gmatch(result, "<[^>]+>") do
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
-- This is a simple helper function to send formatted text to the correct tab.
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
-- This is the main function that processes incoming GMCP chat messages, applies channel mapping, highlights,
-- and then sends them to the appropriate Geyser tab and handles main window coloring/gagging separately.
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
    local timeStr = ""
    if type(Mindlink.config.timestamp) == "string" then
        timeStr = getTime(true, Mindlink.config.timestamp)
    elseif Mindlink.config.timestamp then
        timeStr = getTime(true, "[hh:mm:ss] ")
    end
    
    local formattedText = ""
    if chanColorStr then
        formattedText = string.format("<%d,%d,%d>", cR, cG, cB) .. ansi2string(continuousText)
    else
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
            local linePainted = false
            
            -- 1. Paint the whole line if linesContaining triggers
            for str, color in pairs(Mindlink.config.highlights.linesContaining) do
                if string.find(lineStr, str, 1, true) then
                    local lR, lG, lB = Mindlink.parseColor(color)
                    selectSection("main", startPos, string.len(lineStr))
                    setFgColor(lR, lG, lB)
                    linePainted = true
                    break
                end
            end
            
            -- 2. Apply Channel Color ONLY if linesContaining didn't override it
            if not linePainted and chanColorStr then
                selectSection("main", startPos, string.len(lineStr))
                setFgColor(cR, cG, cB)
            end
            
            -- 3. Paint Word Highlights on top!
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
-- This uses temporary triggers to catch uniquely colored lines that might not come through GMCP, like emotes, 
-- and applies the same processing to them as we would to communications.
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

    local timeStr = ""
    if type(Mindlink.config.timestamp) == "string" then
        timeStr = getTime(true, Mindlink.config.timestamp)
    elseif Mindlink.config.timestamp then
        timeStr = getTime(true, "[hh:mm:ss] ")
    end
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
    
    -- Send fully formatted string to Mindlink Tabs
    formattedText = Mindlink.applyWordHighlights(formattedText)
    Mindlink.appendChat(targetTab, formattedText, timeStr)
    Mindlink.logMessage(targetTab, rawText)

    -- Handle Main Window (Mathematical Word Painting)
    if Mindlink.config.gagMain then
        deleteLine()
    elseif Mindlink.config.colorMain then
        -- 1. Check linesContaining for emotes
        for str, color in pairs(Mindlink.config.highlights.linesContaining) do
            if string.find(rawText, str, 1, true) then
                local lR, lG, lB = Mindlink.parseColor(color)
                selectCurrentLine("main")
                setFgColor(lR, lG, lB)
                break
            end
        end

        -- 2. Word Highlights on top
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
-- This is a little utility that uses temporary triggers to catch and delete the lines Achaea outputs when you change emote
-- colors in your config, since those lines would otherwise flood your main window and not come through GMCP for capture.
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
-- Profile Management (External JSON Config)
-- This handles exporting and importing your config values so you can share
-- your setup with others without overwriting their personal window sizes!
-- =========================================================================
function Mindlink.saveProfile()
    -- Check and create the master Mindlink folder before saving
    local baseDir = getMudletHomeDir() .. "/Mindlink"
    if not lfs.attributes(baseDir) then lfs.mkdir(baseDir) end
    
    local filepath = baseDir .. "/Mindlink_Profile.json"
    
    -- Export all behavioral and color settings, strictly excluding window UI dimensions
    local exportData = {
        timestamp = Mindlink.config.timestamp,
        colorMain = Mindlink.config.colorMain,
        emoteColor = Mindlink.config.emoteColor,
        gagMain = Mindlink.config.gagMain,
        hiddenChannels = Mindlink.config.hiddenChannels,
        ignorePatterns = Mindlink.config.ignorePatterns,
        allTab = Mindlink.config.allTab,
        tabNames = Mindlink.config.tabNames,
        channelMap = Mindlink.config.channelMap,
        logTabs = Mindlink.config.logTabs,
        colors = Mindlink.config.colors,
        highlights = Mindlink.config.highlights
    }
    
    local file = io.open(filepath, "w")
    if file then
        file:write(yajl.to_string(exportData))
        file:close()
        cecho("\n<dodger_blue>[Mindlink]:<reset> Profile successfully exported to:\n<gray>" .. filepath .. "<reset>\n")
    else
        cecho("\n<red>[Mindlink]: Failed to write profile to disk.<reset>\n")
    end
end

function Mindlink.loadProfile()
    -- Point to the new nested location
    local filepath = getMudletHomeDir() .. "/Mindlink/Mindlink_Profile.json"
    local file = io.open(filepath, "r")
    
    if not file then 
        cecho("\n<red>[Mindlink Error]:<reset> No Mindlink_Profile.json found to load! Type <yellow>mindlink profile save<reset> to create one.\n")
        return 
    end
    
    local contents = file:read("*a")
    file:close()
    
    local success, profile = pcall(yajl.to_value, contents)
    if not success or type(profile) ~= "table" then
        cecho("\n<red>[Mindlink Error]:<reset> Your Mindlink_Profile.json has a formatting error! Check for missing quotes or commas.\n")
        return
    end
    
    -- Direct assignments for simple variables
    if profile.timestamp ~= nil then Mindlink.config.timestamp = profile.timestamp end
    if profile.colorMain ~= nil then Mindlink.config.colorMain = profile.colorMain end
    if profile.emoteColor ~= nil then Mindlink.config.emoteColor = profile.emoteColor end
    if profile.gagMain ~= nil then Mindlink.config.gagMain = profile.gagMain end
    if profile.allTab ~= nil then Mindlink.config.allTab = profile.allTab end

    -- Direct overwrites for tables (Imports the exact shared profile state)
    if profile.hiddenChannels then Mindlink.config.hiddenChannels = profile.hiddenChannels end
    if profile.ignorePatterns then Mindlink.config.ignorePatterns = profile.ignorePatterns end
    if profile.tabNames then Mindlink.config.tabNames = profile.tabNames end
    if profile.channelMap then Mindlink.config.channelMap = profile.channelMap end
    if profile.logTabs then Mindlink.config.logTabs = profile.logTabs end
    if profile.colors then Mindlink.config.colors = profile.colors end
    if profile.highlights then Mindlink.config.highlights = profile.highlights end
    
    cecho("\n<dodger_blue>[Mindlink]:<reset> External profile loaded. Settings applied!<reset>\n")
end

-- =========================================================================
-- In-Game Commands & Help Interface
-- Powers the text that appears when you type "mindlink help" in game, as well as the various toggles and commands
-- you can use on the fly without editing your config.
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
    cecho("\n  <yellow>mindlink profile save<reset>   - Exports your current script config to a shareable JSON file.")
    cecho("\n  <yellow>mindlink profile load<reset>   - Manually reloads your JSON profile from disk.")
    
    cecho("\n\n<cyan>How We Catch Emotes (Emote Colors):<reset>")
    cecho("\n  Mindlink catches emotes completely automatically using XTerm256 colors.")
    cecho("\n  Type COLOURS in game to see the available colours.")
    cecho("\n  To change the colour used for emotes, edit <yellow>emoteColor<reset> in the configuration")
    cecho("\n  section at the top the script. Mindlink will update the colour used in")
    cecho("\n  Achaea and your Mudlet triggers on saving the script!")

    cecho("\n<dodger_blue>=======================================================================<reset>\n")
end

-- Master Alias: Route all user commands to functions
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
    elseif cmd == "profile save" then
        Mindlink.saveProfile()
        
    elseif cmd == "profile load" then
        Mindlink.loadProfile()
        
        -- Rebuild the UI triggers in case the emote color was changed in the JSON
        if Mindlink.emoteTrigger then killTrigger(Mindlink.emoteTrigger) end
        Mindlink.emoteTrigger = tempColorTrigger(Mindlink.config.emoteColor, -1, [[Mindlink.captureFromTrigger("Local")]])
        
        -- Safely hide and destroy the old UI elements to prevent ghost tabs
        if Mindlink.container then Mindlink.container:hide() end
        if Mindlink.tabs then
            for _, tab in pairs(Mindlink.tabs) do tab:hide() end
        end
        if Mindlink.consoles then
            for _, console in pairs(Mindlink.consoles) do console:hide() end
        end
        
        -- Reset the tables and redraw the UI with the newly loaded profile data
        Mindlink.tabs = {}
        Mindlink.consoles = {}
        Mindlink.currentTab = Mindlink.config.allTab
        
        Mindlink.createUI()
        if Mindlink.container then Mindlink.container:show() end
        
        cecho("\n<dodger_blue>[Mindlink]:<reset> User Interface rebuilt successfully!\n")
    else
        cecho("\n<dodger_blue>[Mindlink]:<reset> Unknown command. Type <yellow>mindlink help<reset> for options.\n")
    end
end

-- =========================================================================
-- Initialization
-- This sets up the GMCP event handler, the emote trigger, and the in-game command alias. 
-- It also loads your profile settings and applies them on startup. It waits to make
-- sure you are logged in before firing.
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

    -- Create the Emote Trigger EXACTLY ONCE
    if Mindlink.emoteTrigger then killTrigger(Mindlink.emoteTrigger) end
    Mindlink.silenceColorConfig()
    send("config colour emotes " .. Mindlink.config.emoteColor, false)
    Mindlink.emoteTrigger = tempColorTrigger(Mindlink.config.emoteColor, -1, [[Mindlink.captureFromTrigger("Local")]])

    Mindlink.createUI()
    cecho("\n<dodger_blue>[Mindlink]:<reset> Telepathic Ledger Initialized. Type <yellow>mindlink help<reset> for commands.\n")
end

if gmcp and gmcp.Char and gmcp.Char.Name then
    Mindlink.init()
else
    if Mindlink.loginTrigger then killTrigger(Mindlink.loginTrigger) end
    Mindlink.loginTrigger = tempRegexTrigger("Password correct\\. Welcome to Achaea\\.", function()
        Mindlink.init()
    end, 1)
end
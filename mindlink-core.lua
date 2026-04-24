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
    gagMain = false,
    
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
    }, -- Make sure this comma is here!

    -- =========================================================================
    -- Custom Highlights
    -- Use Mudlet color tags (e.g., "<gold>", "<255,0,0>")
    -- =========================================================================
    highlights = {
        -- Highlight specific words/names anywhere they appear
        words = {
            ["Zaleria"] = "<200,170,191>",
        },
        
        -- Highlight the ENTIRE line if it comes from a specific GMCP channel (e.g., "tell", "ct")
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
} -- THIS bracket finally closes Mindlink.config

Mindlink.currentTab = Mindlink.currentTab or Mindlink.config.allTab

-- =========================================================================
-- Automated Logging
-- =========================================================================
function Mindlink.logMessage(tabName, rawText)
    if not Mindlink.config.logTabs[tabName] then return end
    
    -- Strip ANSI escape codes to ensure clean text files
    local plainText = string.gsub(rawText, "\27%[[%d;]*m", "")
    
    -- Get or create the logging directory in your Mudlet profile folder
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
    -- Reverted back to Geyser.Container. 
    -- This natively supports your "-25%" and "50%" relative coordinates flawlessly.
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

    -- Helper function to universally translate ANY color format into strict decho tags
    local function fixColor(colorStr)
        if not colorStr or colorStr == "" then return "" end
        
        -- If Legacy NDB passes an RGB table instead of a string
        if type(colorStr) == "table" then
            return string.format("<%d,%d,%d>", colorStr[1], colorStr[2], colorStr[3] or 255)
        end
        
        -- Strip out any brackets or spaces to get the raw color name or numbers
        local cleanColor = string.gsub(colorStr, "[<> ]", "")
        
        -- If it exists in Mudlet's color_table (e.g., "cornflower_blue", "purple")
        if color_table[cleanColor] then
            local rgb = color_table[cleanColor]
            return string.format("<%d,%d,%d>", rgb[1], rgb[2], rgb[3])
        end
        
        -- Otherwise, assume it's a valid RGB string like "0,191,255" and wrap it in brackets
        return "<" .. cleanColor .. ">"
    end

    -- 1. Full Line Overrides (Channels)
    if channel then
        for prefix, color in pairs(Mindlink.config.highlights.channels) do
            if string.find(channel:lower(), "^" .. prefix:lower()) then
                local safeColor = fixColor(color)
                result = safeColor .. string.gsub(result, "<[0-9,:]+>", "")
                break 
            end
        end
    end

    -- 2. Full Line Overrides (Strings)
    for str, color in pairs(Mindlink.config.highlights.linesContaining) do
        if string.find(result, str, 1, true) then
            local safeColor = fixColor(color)
            result = safeColor .. string.gsub(result, "<[0-9,:]+>", "")
            break 
        end
    end

    -- Helper function to apply Smart-Color word replacements
    local function smartWordHighlight(word, color)
        local safeColor = fixColor(color)
        local escapedWord = word:gsub("([^%w])", "%%%1")
        
        -- If the word is purely letters, enforce word boundaries so "Ash" doesn't highlight inside "Hashan".
        -- If it has punctuation (like "(Cyrene):"), just match the exact string anywhere.
        local pattern = string.match(word, "^%a+$") and ("(%f[%a]" .. escapedWord .. "%f[%A])") or ("(" .. escapedWord .. ")")
        
        local out = ""
        -- Default to the first color tag in the string, or light grey if none exist
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

    -- 3. Word/Name Highlights (Manual Config)
    for word, color in pairs(Mindlink.config.highlights.words) do
        smartWordHighlight(word, color)
    end

    -- 4. Dynamic Name Database Hook (Legacy.NDB)
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
-- GMCP Chat Processing
-- =========================================================================
function Mindlink.appendChat(targetTab, text, channel)
    local console = Mindlink.consoles[targetTab]
    if not console then return end

    local timeStr = Mindlink.config.timestamp and getTime(true, Mindlink.config.timestamp) or ""
    local formattedText = ansi2decho(text):gsub("<reset>", "")
    
    -- PASS TEXT THROUGH THE HIGHLIGHTER
    formattedText = Mindlink.applyHighlights(formattedText, channel)

    console:decho(timeStr .. formattedText .. "\n")

    if Mindlink.config.allTab and targetTab ~= Mindlink.config.allTab then
        local allConsole = Mindlink.consoles[Mindlink.config.allTab]
        if allConsole then
            allConsole:decho(timeStr .. formattedText .. "\n")
        end
    end
end

function Mindlink.onGMCPChat()
    if not gmcp.Comm or not gmcp.Comm.Channel or not gmcp.Comm.Channel.Text then return end
    
    local channel = gmcp.Comm.Channel.Text.channel
    local text = gmcp.Comm.Channel.Text.text
    
    -- === ADD THIS DEBUG LINE ===
    cecho(string.format("\n<yellow>[Mindlink Debug] Raw Channel ID: <red>'%s'<reset>\n", channel))
    -- ===========================

    local targetTab = "Misc" 

    for prefix, mappedTab in pairs(Mindlink.config.channelMap) do
        if string.find(channel, "^" .. prefix) then
            targetTab = mappedTab
            break
        end
    end

    if not Mindlink.tabs[targetTab] then targetTab = Mindlink.config.allTab end

    -- INCLUDE THE CHANNEL VARIABLE HERE
    Mindlink.appendChat(targetTab, text, channel)
    Mindlink.logMessage(targetTab, text)

    if Mindlink.config.gagMain then
        local cleanText = ansi2string(text)
        tempExactMatchTrigger(cleanText, [[deleteLine()]], 1)
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

    local timeStr = Mindlink.config.timestamp and getTime(true, Mindlink.config.timestamp) or ""

    -- THE FIX: Instead of copying the buffer, we extract the color and text,
    -- format it with decho tags, and pass it through our highlighter!
    selectCurrentLine()
    local r, g, b = getFgColor()
    local baseColorTag = string.format("<%d,%d,%d>", r, g, b)
    
    -- Build the string and run it through the smart-highlighter
    local formattedText = baseColorTag .. rawText
    formattedText = Mindlink.applyHighlights(formattedText)

    -- Print to the target tab
    console:decho(timeStr .. formattedText .. "\n")

    -- Print to the All tab
    if Mindlink.config.allTab and targetTab ~= Mindlink.config.allTab then
        local allConsole = Mindlink.consoles[Mindlink.config.allTab]
        if allConsole then
            allConsole:decho(timeStr .. formattedText .. "\n")
        end
    end
    
    Mindlink.logMessage(targetTab, rawText)

    if Mindlink.config.gagMain then
        deleteLine()
    end
end

-- =========================================================================
-- Initialization
-- =========================================================================
function Mindlink.init()
    for _, handlerID in ipairs(Mindlink.events) do
        killAnonymousEventHandler(handlerID)
    end
    Mindlink.events = {}

    sendGMCP([[Core.Supports.Add ["Comm.Channel 1"] ]])
    table.insert(Mindlink.events, registerAnonymousEventHandler("gmcp.Comm.Channel.Text", "Mindlink.onGMCPChat"))

    Mindlink.createUI()
    cecho("\n<green>[Mindlink]:<reset> Telepathic Ledger Initialized.\n")
end

Mindlink.init()

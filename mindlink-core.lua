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
    
    -- Add this new table!
    ignorePatterns = {
        "Lines of leaden shadow coil underfoot",
        "^writ%.%s*$" -- The ^ means "starts with" and %s*$ means "only spaces after". 
    },
    
    allTab = "All",
    
    -- The tabs you want created, in order from left to right
    tabNames = {
        "All", "Local", "City", "Party", "Tells", "Clans", "Misc"
    },
    
    -- Map GMCP channel prefixes to your specific tabs
    -- If a channel isn't found here, it defaults to the "Misc" tab
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
    }
}

Mindlink.currentTab = Mindlink.currentTab or Mindlink.config.allTab

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
-- GMCP Chat Processing
-- =========================================================================
function Mindlink.appendChat(targetTab, text)
    local console = Mindlink.consoles[targetTab]
    if not console then return end

    local timeStr = Mindlink.config.timestamp and getTime(true, Mindlink.config.timestamp) or ""
    local formattedText = ansi2decho(text):gsub("<reset>", "")

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
    local targetTab = "Misc" 

    for prefix, mappedTab in pairs(Mindlink.config.channelMap) do
        if string.find(channel, "^" .. prefix) then
            targetTab = mappedTab
            break
        end
    end

    if not Mindlink.tabs[targetTab] then targetTab = Mindlink.config.allTab end

    Mindlink.appendChat(targetTab, text)

    if Mindlink.config.gagMain then
        local cleanText = strip_colours(text)
        tempExactMatchTrigger(cleanText, [[deleteLine()]], 1)
    end
end

-- =========================================================================
-- Trigger-Based Capture (For Emotes/Color Triggers)
-- =========================================================================
function Mindlink.captureFromTrigger(targetTab)
    local console = Mindlink.consoles[targetTab]
    if not console then return end

    -- Grab the raw text of the line to check against our ignore list
    local rawText = strip_colours(line)
    
    if Mindlink.config.ignorePatterns then
        for _, pattern in ipairs(Mindlink.config.ignorePatterns) do
            if string.find(rawText, pattern) then
                return -- This line matches an ignored pattern. Abort!
            end
        end
    end

    local timeStr = Mindlink.config.timestamp and getTime(true, Mindlink.config.timestamp) or ""

    -- Select the line exactly as it appears in the main window (colors intact!)
    selectCurrentLine()
    copy()

    -- Paste it to the target tab
    console:decho(timeStr)
    appendBuffer(console.name)

    -- Paste it to the All tab
    if Mindlink.config.allTab and targetTab ~= Mindlink.config.allTab then
        local allConsole = Mindlink.consoles[Mindlink.config.allTab]
        if allConsole then
            allConsole:decho(timeStr)
            appendBuffer(allConsole.name)
        end
    end

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
    cecho("\n<green>[Mindlink]:<reset> Telepathic Pnemonics Initialized.\n")
end

Mindlink.init()

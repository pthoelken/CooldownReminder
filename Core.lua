local ADDON_NAME = ...

local function GetAddonMetadata(field)
    if type(C_AddOns) == "table" and type(C_AddOns.GetAddOnMetadata) == "function" then
        return C_AddOns.GetAddOnMetadata(ADDON_NAME, field)
    end

    if type(GetAddOnMetadata) == "function" then
        return GetAddOnMetadata(ADDON_NAME, field)
    end
end

local function GetAddonVersion()
    local version = GetAddonMetadata("Version")
    if type(version) == "string" and version ~= "" then
        return version
    end

    return "dev"
end

local CDR = CreateFrame("Frame", "CooldownReminderEventFrame")
CooldownReminder = CDR

CDR.ADDON_NAME = ADDON_NAME
CDR.VERSION = GetAddonVersion()
CDR.UI = {}
CDR.Utils = {}

local CONST = {
    READY_SCAN_INTERVAL = 0.5,
    READY_SCAN_DEBOUNCE_SECONDS = 0.05,
    UI_REFRESH_DEBOUNCE_SECONDS = 0.01,
    GCD_IGNORE_SECONDS = 2,
    SPELL_GRID_COLUMNS = 12,
    SPELL_GRID_ROWS = 3,
    SPELL_GRID_ICON_SIZE = 32,
    SPELL_GRID_ICON_SPACING = 6,
    WATCHED_ROWS = 5,
    WATCHED_ROW_HEIGHT = 34,
    ALERT_ICON_SIZE = 38,
    ALERT_ROW_HEIGHT = 46,
    ALERT_ROW_SPACING = 6,
    ALERT_MIN_WIDTH = 48,
    ALERT_MAX_WIDTH = 420,
    ALERT_MAX_STACK_WIDTH = 1600,
    ACTION_SLOT_FIRST = 1,
    ACTION_SLOT_LAST = 180,
}
CDR.CONST = CONST

CDR.SOUND_OPTIONS = {
    { id = "raid_warning", soundKit = "RAID_WARNING", fallback = 8959 },
    { id = "ready_check", soundKit = "READY_CHECK", fallback = 8959 },
    { id = "checkbox", soundKit = "IG_MAINMENU_OPTION_CHECKBOX_ON", fallback = 856 },
    { id = "auction", soundKit = "AUCTION_WINDOW_OPEN", fallback = 5274 },
    { id = "boss_warning", soundKit = "UI_RAID_BOSS_WHISPER_WARNING", fallback = 8959 },
    { id = "quest", soundKit = "IG_QUEST_LIST_OPEN", fallback = 618 },
    { id = "invite", soundKit = "IG_PLAYER_INVITE", fallback = 880 },
    { id = "map_ping", soundKit = "MAP_PING", fallback = 3175 },
    { id = "loot", soundKit = "LOOT_WINDOW_COIN_SOUND", fallback = 120 },
    { id = "level_up", soundKit = "LEVEL_UP", fallback = 888 },
    { id = "pvp_queue", soundKit = "PVP_ENTER_QUEUE", fallback = 8458 },
    { id = "epic_toast", soundKit = "UI_EPICLOOT_TOAST", fallback = 31578 },
    { id = "alarm", soundKit = "ALARM_CLOCK_WARNING_3", fallback = 12867 },
}

CDR.LANGUAGE_OPTIONS = {
    { id = "auto" },
    { id = "enUS" },
    { id = "ptBR" },
    { id = "esES" },
    { id = "esMX" },
    { id = "frFR" },
    { id = "deDE" },
    { id = "itIT" },
    { id = "ruRU" },
    { id = "zhCN" },
    { id = "koKR" },
    { id = "zhTW" },
}

CDR.REMINDER_LAYOUT_OPTIONS = {
    { id = "vertical" },
    { id = "horizontal" },
}

CDR.COOLDOWN_SPELL_SUPPLEMENTS = {
    { id = 5394, cooldown = 30 }, -- Healing Stream Totem
    { id = 51485, cooldown = 30 }, -- Earthgrab Totem
    { id = 79206, cooldown = 120 }, -- Spiritwalker's Grace
    { id = 98008, cooldown = 180 }, -- Spirit Link Totem
    { id = 108271, cooldown = 90 }, -- Astral Shift
    { id = 108280, cooldown = 180 }, -- Healing Tide Totem
    { id = 108281, cooldown = 120 }, -- Ancestral Guidance
    { id = 157153, cooldown = 30 }, -- Cloudburst Totem
    { id = 192058, cooldown = 60 }, -- Capacitor Totem
    { id = 192077, cooldown = 120 }, -- Wind Rush Totem
    { id = 198103, cooldown = 300 }, -- Earth Elemental
    { id = 207399, cooldown = 300 }, -- Ancestral Protection Totem
}

CDR.defaults = {
    spells = {},
    order = {},
    language = "auto",
    monitoringEnabled = true,
    ui = {
        showLoadMessage = true,
    },
    sound = {
        enabled = true,
        id = "raid_warning",
    },
    reminder = {
        point = "LEFT",
        relativePoint = "LEFT",
        x = 260,
        y = 80,
        width = 260,
        height = CONST.ALERT_ROW_HEIGHT,
        scale = 1,
        showTitle = true,
        layout = "vertical",
        topMost = false,
    },
}

local U = CDR.Utils

function U.CopyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            U.CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function U.Clamp(value, minValue, maxValue)
    local ok, result = pcall(function()
        if value < minValue then
            return minValue
        end
        if value > maxValue then
            return maxValue
        end
        return value
    end)
    if ok then
        return result
    end
    if minValue and minValue > 0 then
        return minValue
    end
    return 0
end

function U.Round(value)
    return math.floor((value or 0) + 0.5)
end

function U.Trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

function U.NormalizeName(name)
    local value = U.Trim(name or "")
    if strlower then
        return strlower(value)
    end
    return string.lower(value)
end

function U.ToSpellID(value)
    local ok, spellID = pcall(function()
        local numericValue = tonumber(value)
        if numericValue and numericValue > 0 then
            return numericValue
        end
    end)
    if ok then
        return spellID
    end
end

function U.AddUnique(list, lookup, value)
    value = U.ToSpellID(value)
    if value and not lookup[value] then
        lookup[value] = true
        table.insert(list, value)
    end
end

function U.CopyAliasList(source)
    local aliases = {}
    local lookup = {}
    for _, spellID in ipairs(source or {}) do
        U.AddUnique(aliases, lookup, spellID)
    end
    return aliases
end

function U.BuildLookup(list)
    local lookup = {}
    for _, value in ipairs(list or {}) do
        local numericValue = U.ToSpellID(value)
        if numericValue then
            lookup[numericValue] = true
        end
    end
    return lookup
end

function U.SecondsText(seconds)
    seconds = math.max(0, U.Round(seconds or 0))
    if seconds >= 3600 then
        return string.format("%dh %02dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
    end
    if seconds >= 60 then
        return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
    end
    return string.format("%ds", seconds)
end

function U.CreateBackdrop(frame, alpha)
    if not frame.SetBackdrop then
        return
    end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame:SetBackdropColor(0.015, 0.015, 0.018, alpha or 0.88)
    frame:SetBackdropBorderColor(0.28, 0.26, 0.22, 0.85)
end

function U.SetTextureColor(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        texture:SetVertexColor(r, g, b, a)
    end
end

function U.CreateAnimatedBorder(frame)
    local borders = {}
    local points = {
        { "TOPLEFT", "TOPRIGHT", 0, 1, 0, 1, nil, 2 },
        { "BOTTOMLEFT", "BOTTOMRIGHT", 0, -1, 0, -1, nil, 2 },
        { "TOPLEFT", "BOTTOMLEFT", -1, 0, -1, 0, 2, nil },
        { "TOPRIGHT", "BOTTOMRIGHT", 1, 0, 1, 0, 2, nil },
    }

    for _, data in ipairs(points) do
        local texture = frame:CreateTexture(nil, "OVERLAY")
        texture:SetPoint(data[1], frame, data[1], data[3], data[4])
        texture:SetPoint(data[2], frame, data[2], data[5], data[6])
        if data[7] then
            texture:SetWidth(data[7])
        end
        if data[8] then
            texture:SetHeight(data[8])
        end
        U.SetTextureColor(texture, 1, 0.78, 0.24, 0.75)
        table.insert(borders, texture)
    end

    frame.animatedBorder = borders
    frame:SetScript("OnUpdate", function(row, elapsed)
        row.pulseTime = (row.pulseTime or 0) + elapsed
        local alpha = 0.35 + ((math.sin(row.pulseTime * 4.2) + 1) * 0.28)
        for _, texture in ipairs(row.animatedBorder or {}) do
            texture:SetAlpha(alpha)
        end
    end)
end

function U.GetSoundOption(soundID)
    for _, option in ipairs(CDR.SOUND_OPTIONS) do
        if option.id == soundID then
            return option
        end
    end
    return CDR.SOUND_OPTIONS[1]
end

function U.GetReminderLayoutOption(layoutID)
    for _, option in ipairs(CDR.REMINDER_LAYOUT_OPTIONS) do
        if option.id == layoutID then
            return option
        end
    end
    return CDR.REMINDER_LAYOUT_OPTIONS[1]
end

function U.GetLanguageLabel(languageID)
    if languageID == "auto" then
        return CDR:L("LANG_AUTO")
    end
    local keys = {
        enUS = "LANG_EN",
        ptBR = "LANG_PT_BR",
        deDE = "LANG_DE",
        frFR = "LANG_FR",
        esES = "LANG_ES",
        esMX = "LANG_ES_MX",
        itIT = "LANG_IT",
        ruRU = "LANG_RU",
        zhCN = "LANG_ZH_CN",
        koKR = "LANG_KO",
        zhTW = "LANG_ZH_TW",
    }
    return CDR:L(keys[languageID] or "LANG_EN")
end

function U.GetSoundLabel(soundID)
    local option = U.GetSoundOption(soundID)
    return CDR:L("SOUND_" .. string.upper(option.id))
end

function U.GetReminderLayoutLabel(layoutID)
    local option = U.GetReminderLayoutOption(layoutID)
    return CDR:L("LAYOUT_" .. string.upper(option.id))
end

function CDR:L(key)
    local locales = CooldownReminderLocales or {}
    local fallback = locales.enUS or {}
    local active = self.locale or fallback
    return active[key] or fallback[key] or key
end

function CDR:ApplyLocale()
    local locales = CooldownReminderLocales or {}
    local selected = self.db and self.db.language or "auto"
    local localeKey = selected

    if selected == "auto" or not locales[selected] then
        localeKey = GetLocale and GetLocale() or "enUS"
    end
    if not locales[localeKey] then
        localeKey = "enUS"
    end

    self.localeKey = localeKey
    self.locale = locales[localeKey] or locales.enUS or {}
end

function CDR:InitializeDatabase()
    local oldSoundEnabled
    if type(CooldownReminderDB) == "table" and type(CooldownReminderDB.sound) == "boolean" then
        oldSoundEnabled = CooldownReminderDB.sound
    end

    if type(CooldownReminderDB) ~= "table" then
        CooldownReminderDB = {}
    end

    U.CopyDefaults(CooldownReminderDB, self.defaults)
    self.db = CooldownReminderDB

    if oldSoundEnabled ~= nil then
        self.db.sound.enabled = oldSoundEnabled
    end
    self.db.monitoringEnabled = self.db.monitoringEnabled ~= false
    self.db.ui.showLoadMessage = self.db.ui.showLoadMessage ~= false
    self.db.sound.id = U.GetSoundOption(self.db.sound.id).id

    if self.db.reminder.showTitle == nil then
        self.db.reminder.showTitle = true
    end
    if self.db.reminder.point == "CENTER" and self.db.reminder.relativePoint == "CENTER" and self.db.reminder.x == 0 and self.db.reminder.y == 140 then
        self.db.reminder.point = self.defaults.reminder.point
        self.db.reminder.relativePoint = self.defaults.reminder.relativePoint
        self.db.reminder.x = self.defaults.reminder.x
        self.db.reminder.y = self.defaults.reminder.y
    end
    self.db.reminder.layout = U.GetReminderLayoutOption(self.db.reminder.layout).id
    self.db.reminder.topMost = self.db.reminder.topMost == true

    local seenNames = {}
    local normalizedSpells = {}
    for spellID, spellData in pairs(self.db.spells) do
        local numericID = U.ToSpellID(spellID)
        if numericID and type(spellData) == "table" then
            spellData.name = spellData.name or U.GetSpellInfoCompat(numericID) or ("Spell " .. numericID)
            spellData.icon = spellData.icon or U.GetSpellTextureCompat(numericID) or 134400
            spellData.nameKey = U.NormalizeName(spellData.name)
            spellData.aliases = U.CopyAliasList(spellData.aliases)
            spellData.actionSlots = U.CopyAliasList(spellData.actionSlots)
            U.AddUnique(spellData.aliases, U.BuildLookup(spellData.aliases), numericID)

            if not seenNames[spellData.nameKey] then
                seenNames[spellData.nameKey] = numericID
                normalizedSpells[numericID] = spellData
            end
        end
    end
    self.db.spells = normalizedSpells
    if self.NormalizeWatchedOrder then
        self:NormalizeWatchedOrder()
    end
end

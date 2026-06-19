local CDR = CooldownReminder
local UI = CDR.UI
local U = CDR.Utils
local CONST = CDR.CONST

local function CalculateRemainingCooldown(startTime, duration, modRate, now)
    if not startTime or not duration or duration <= CONST.GCD_IGNORE_SECONDS then
        return 0
    end
    if startTime <= 0 or startTime > now then
        return 0
    end
    modRate = tonumber(modRate) or 1
    if modRate <= 0 then
        modRate = 1
    end
    return math.max(0, (startTime + duration - now) / (modRate or 1))
end

local function GetRemainingCooldown(startTime, duration, modRate, now)
    local ok, remaining = pcall(CalculateRemainingCooldown, startTime, duration, modRate, now)
    return ok and remaining or 0
end

local function IsGreaterThan(value, threshold)
    local ok, result = pcall(function()
        return value and value > threshold
    end)
    return ok and result
end
U.IsGreaterThan = IsGreaterThan

local function NumberOrNil(value)
    local ok, number = pcall(function()
        local numericValue = tonumber(value)
        if numericValue == nil then
            return nil
        end
        if numericValue < 0 then
            return 0
        end
        return numericValue
    end)
    return ok and number or nil
end

local function NumberOrZero(value)
    return NumberOrNil(value) or 0
end

local function GetSpellBaseOrRechargeCooldown(spellID)
    local cooldown = NumberOrZero(U.GetSpellBaseCooldownCompat(spellID))
    local _, maxCharges, _, chargeCooldown = U.GetSpellChargesCompat(spellID)
    chargeCooldown = NumberOrZero(chargeCooldown)
    if IsGreaterThan(maxCharges, 1) and chargeCooldown > cooldown then
        cooldown = chargeCooldown
    end
    return cooldown
end

local function IsCooldownEnabled(value)
    local ok, result = pcall(function()
        return value ~= 0 and value ~= false
    end)
    return ok and result
end

local function AdvanceTrackedCharges(state, maxCharges, rechargeDuration, now)
    local trackedCharges = tonumber(state.trackedCharges)
    if not trackedCharges then
        return
    end

    maxCharges = tonumber(maxCharges or 0) or 0
    rechargeDuration = tonumber(rechargeDuration or state.trackedChargeDuration or 0) or 0
    if maxCharges <= 1 then
        state.trackedCharges = nil
        state.trackedChargeReadyAt = nil
        state.trackedMaxCharges = nil
        return
    end

    trackedCharges = U.Clamp(trackedCharges, 0, maxCharges)
    local readyAt = tonumber(state.trackedChargeReadyAt)
    local increments = 0
    while readyAt and rechargeDuration > CONST.GCD_IGNORE_SECONDS and trackedCharges < maxCharges and now >= readyAt and increments < maxCharges do
        trackedCharges = trackedCharges + 1
        readyAt = readyAt + rechargeDuration
        increments = increments + 1
    end

    if trackedCharges >= maxCharges then
        readyAt = nil
    end

    state.trackedCharges = trackedCharges
    state.trackedChargeReadyAt = readyAt
    state.trackedMaxCharges = maxCharges
    state.trackedChargeDuration = rechargeDuration
    return trackedCharges, readyAt
end

function CDR:GetStateScheduledReadyAt(state)
    if not state then
        return 0
    end

    return math.max(state.cooldownBlockUntil or 0, state.pendingReadyAt or 0)
end

function U.GetSpellInfoCompat(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if type(info) == "table" then
            return info.name, info.iconID, info.spellID or spellID
        end
        if info then
            local name, _, icon = C_Spell.GetSpellInfo(spellID)
            return name, icon, spellID
        end
    end

    if GetSpellInfo then
        local name, _, icon = GetSpellInfo(spellID)
        return name, icon, spellID
    end
end

function U.GetSpellTextureCompat(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end
    local _, icon = U.GetSpellInfoCompat(spellID)
    return icon
end

function U.GetSpellCooldownCompat(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
        if type(cooldownInfo) == "table" then
            return cooldownInfo.startTime or cooldownInfo.start or cooldownInfo.cooldownStartTime or 0,
                cooldownInfo.duration or cooldownInfo.cooldownDuration or 0,
                cooldownInfo.isEnabled,
                cooldownInfo.modRate or cooldownInfo.rate or 1
        end
        if cooldownInfo ~= nil then
            local startTime, duration, isEnabled, modRate = C_Spell.GetSpellCooldown(spellID)
            return startTime or 0, duration or 0, isEnabled, modRate or 1
        end
    end

    if GetSpellCooldown then
        local startTime, duration, isEnabled, modRate = GetSpellCooldown(spellID)
        return startTime or 0, duration or 0, isEnabled, modRate or 1
    end

    return 0, 0, true, 1
end

function U.GetSpellChargesCompat(spellID)
    if C_Spell and C_Spell.GetSpellCharges then
        local ok, chargeInfo, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate = pcall(C_Spell.GetSpellCharges, spellID)
        if type(chargeInfo) == "table" then
            return NumberOrNil(chargeInfo.currentCharges),
                NumberOrNil(chargeInfo.maxCharges),
                NumberOrZero(chargeInfo.cooldownStartTime or chargeInfo.startTime or chargeInfo.start),
                NumberOrZero(chargeInfo.cooldownDuration or chargeInfo.duration),
                NumberOrNil(chargeInfo.chargeModRate or chargeInfo.modRate or chargeInfo.rate) or 1
        end
        if ok and (chargeInfo ~= nil or maxCharges ~= nil) then
            return NumberOrNil(chargeInfo),
                NumberOrNil(maxCharges),
                NumberOrZero(cooldownStartTime),
                NumberOrZero(cooldownDuration),
                NumberOrNil(chargeModRate) or 1
        end
    end

    if GetSpellCharges then
        local ok, currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate = pcall(GetSpellCharges, spellID)
        if ok then
            return NumberOrNil(currentCharges),
                NumberOrNil(maxCharges),
                NumberOrZero(cooldownStartTime),
                NumberOrZero(cooldownDuration),
                NumberOrNil(chargeModRate) or 1
        end
    end
end

function U.GetSpellChargeCountsCompat(spellID)
    local currentCharges, maxCharges = U.GetSpellChargesCompat(spellID)
    if maxCharges then
        return currentCharges, maxCharges
    end
end

local function GetActionChargeInfo(slot)
    if not GetActionCharges then
        return
    end

    local ok, currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate = pcall(GetActionCharges, slot)
    if ok then
        return NumberOrNil(currentCharges),
            NumberOrNil(maxCharges),
            NumberOrZero(cooldownStartTime),
            NumberOrZero(cooldownDuration),
            NumberOrNil(chargeModRate) or 1
    end
end

local function GetActionTextureCompat(slot)
    if GetActionTexture then
        local ok, texture = pcall(GetActionTexture, slot)
        if ok then
            return texture
        end
    end

    if C_ActionBar and C_ActionBar.GetActionTexture then
        local ok, texture = pcall(C_ActionBar.GetActionTexture, slot)
        if ok then
            return texture
        end
    end
end

local GetTextureLookupKeys

local function TexturesMatch(left, right)
    if left == nil or right == nil then
        return false
    end

    if left == right or tostring(left) == tostring(right) then
        return true
    end

    local leftKeys = {}
    for _, key in ipairs(GetTextureLookupKeys(left)) do
        leftKeys[key] = true
    end
    for _, key in ipairs(GetTextureLookupKeys(right)) do
        if leftKeys[key] then
            return true
        end
    end

    return false
end

GetTextureLookupKeys = function(texture)
    local keys = {}
    local seen = {}
    local function addKey(key)
        if key == nil or key == "" or seen[key] then
            return
        end
        seen[key] = true
        table.insert(keys, key)
    end
    local function addStringKeys(value)
        value = tostring(value or "")
        if value == "" then
            return
        end

        local normalized = value:gsub("/", "\\")
        local lowered = string.lower(normalized)
        addKey(normalized)
        addKey(lowered)

        local basename = lowered:match("([^\\]+)$")
        if basename then
            addKey(basename)
            addKey((basename:gsub("%.[%w_]+$", "")))
        end
    end

    addKey(texture)
    addStringKeys(texture)

    if type(texture) == "number" then
        local path
        if C_Texture and C_Texture.GetFilenameFromFileDataID then
            local ok, result = pcall(C_Texture.GetFilenameFromFileDataID, texture)
            if ok then
                path = result
            end
        end
        if not path and GetFileInfo then
            local ok, result = pcall(GetFileInfo, texture)
            if ok then
                path = result
            end
        end
        addStringKeys(path)
    end

    return keys
end

function U.GetSpellBaseCooldownCompat(spellID)
    if C_Spell and C_Spell.GetSpellBaseCooldown then
        local cooldown = C_Spell.GetSpellBaseCooldown(spellID)
        if type(cooldown) == "table" then
            cooldown = cooldown.cooldownMS or cooldown.durationMS or cooldown.baseCooldownMS or cooldown[1]
        end
        cooldown = NumberOrZero(cooldown)
        return cooldown > 0 and (cooldown / 1000) or 0
    end

    if GetSpellBaseCooldown then
        local cooldown = GetSpellBaseCooldown(spellID)
        cooldown = NumberOrZero(cooldown)
        return cooldown > 0 and (cooldown / 1000) or 0
    end

    return 0
end

local function IsKnownSpellCompat(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
        local isKnown = C_SpellBook.IsSpellKnownOrInSpellBook(spellID)
        if isKnown then
            return true
        end
    end

    if IsPlayerSpell and IsPlayerSpell(spellID) then
        return true
    end

    if IsSpellKnown then
        if IsSpellKnown(spellID) or IsSpellKnown(spellID, false) then
            return true
        end
    end

    return false
end

function U.GetCooldownStatus(spellID)
    local now = GetTime()

    local startTime, duration, isEnabled, modRate = U.GetSpellCooldownCompat(spellID)
    if IsCooldownEnabled(isEnabled) then
        local remaining = GetRemainingCooldown(startTime, duration, modRate, now)
        if remaining > 0 then
            return true, remaining
        end
    end

    return false, 0
end

function U.GetActionSpellID(slot)
    if not GetActionInfo then
        return
    end

    local actionType, actionID = GetActionInfo(slot)
    if actionType == "spell" then
        return U.ToSpellID(actionID)
    end

    if actionType == "macro" and actionID and GetMacroSpell then
        local _, macroSpellID = GetMacroSpell(actionID)
        return U.ToSpellID(macroSpellID)
    end
end

function U.GetActionCooldownStatus(slot)
    local now = GetTime()

    if GetActionCharges then
        local currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate = GetActionChargeInfo(slot)
        if IsGreaterThan(maxCharges, 1) then
            if currentCharges and currentCharges > 0 then
                return false, 0, true
            end

            local remaining = GetRemainingCooldown(cooldownStartTime, cooldownDuration, chargeModRate, now)
            if remaining > 0 then
                return true, remaining, false
            end
        end
    end

    if GetActionCooldown then
        local startTime, duration, isEnabled, modRate = GetActionCooldown(slot)
        if IsCooldownEnabled(isEnabled) then
            local remaining = GetRemainingCooldown(startTime, duration, modRate, now)
            if remaining > 0 then
                return true, remaining, false
            end
        end
    end

    if GetActionCharges then
        local _, maxCharges = GetActionChargeInfo(slot)
        if IsGreaterThan(maxCharges, 1) then
            local actionSpellID = U.GetActionSpellID(slot)
            if actionSpellID then
                return U.GetCooldownStatus(actionSpellID)
            end
        end
    end

    return false, 0
end

function U.SpellHasMeaningfulCooldown(spell)
    if not spell then
        return false
    end

    if tonumber(spell.forcedCooldown or 0) > CONST.GCD_IGNORE_SECONDS then
        return true
    end

    for _, spellID in ipairs(spell.aliases or { spell.id }) do
        local baseCooldown = U.GetSpellBaseCooldownCompat(spellID)
        if baseCooldown and baseCooldown > CONST.GCD_IGNORE_SECONDS then
            return true
        end

        local _, maxCharges = U.GetSpellChargesCompat(spellID)
        if IsGreaterThan(maxCharges, 1) then
            return true
        end

        local _, duration = U.GetSpellCooldownCompat(spellID)
        if IsGreaterThan(duration, CONST.GCD_IGNORE_SECONDS) then
            return true
        end
    end

    for _, slot in ipairs(spell.actionSlots or {}) do
        local actionOnCooldown = U.GetActionCooldownStatus(slot)
        if actionOnCooldown then
            return true
        end

        if GetActionCharges then
            local maxCharges = select(2, GetActionCharges(slot))
            if IsGreaterThan(maxCharges, 1) then
                return true
            end
        end

        if GetActionCooldown then
            local _, duration = GetActionCooldown(slot)
            if IsGreaterThan(duration, CONST.GCD_IGNORE_SECONDS) then
                return true
            end
        end
    end

    return false
end

local function IsPassiveBookSlot(slotIndex, spellBank)
    if C_SpellBook and C_SpellBook.IsSpellBookItemPassive then
        return C_SpellBook.IsSpellBookItemPassive(slotIndex, spellBank)
    end
    if IsPassiveSpell then
        return IsPassiveSpell(slotIndex, spellBank)
    end
    return false
end

local function IsSpellBookTypeSpell(itemType)
    if not itemType then
        return true
    end
    if type(itemType) == "string" then
        return itemType == "SPELL" or itemType == "PETACTION"
    end
    if Enum and Enum.SpellBookItemType then
        return itemType == Enum.SpellBookItemType.Spell or itemType == 3
    end
    return itemType == 1 or itemType == 3
end

local function IsSpellBookTypeFlyout(itemType)
    if type(itemType) == "string" then
        return itemType == "FLYOUT"
    end
    if Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout then
        return itemType == Enum.SpellBookItemType.Flyout
    end
    return false
end

local function SortSpells(a, b)
    if a.name == b.name then
        return a.id < b.id
    end
    return a.name < b.name
end

local function AddSpellToList(spellsByName, spellID, source, forcedCooldown)
    spellID = U.ToSpellID(spellID)
    if not spellID then
        return
    end

    local name, icon = U.GetSpellInfoCompat(spellID)
    if not name or name == "" then
        return
    end

    local nameKey = U.NormalizeName(name)
    local spell = spellsByName[nameKey]
    if spell then
        if source == "player" or source == "known" or IsKnownSpellCompat(spellID) then
            spell.isKnown = true
        end
        U.AddUnique(spell.aliases, spell.aliasLookup, spellID)
        if tonumber(forcedCooldown or 0) > tonumber(spell.forcedCooldown or 0) then
            spell.forcedCooldown = forcedCooldown
        end
        spell.search = spell.search .. " " .. tostring(spellID)
        return spell
    end

    spell = {
        id = spellID,
        name = name,
        nameKey = nameKey,
        icon = icon or U.GetSpellTextureCompat(spellID) or 134400,
        source = source,
        isKnown = source == "player" or source == "known" or IsKnownSpellCompat(spellID),
        search = nameKey .. " " .. tostring(spellID),
        aliases = { spellID },
        aliasLookup = { [spellID] = true },
        forcedCooldown = forcedCooldown,
    }
    spellsByName[nameKey] = spell
    return spell
end

local function CanAddActionSpell(spellsByName, spellID)
    if IsKnownSpellCompat(spellID) then
        return true
    end

    local name = U.GetSpellInfoCompat(spellID)
    return name and spellsByName[U.NormalizeName(name)] ~= nil
end

local function AttachActionSlot(spell, slot)
    if not spell then
        return
    end

    spell.actionSlots = spell.actionSlots or {}
    spell.actionSlotLookup = spell.actionSlotLookup or {}
    U.AddUnique(spell.actionSlots, spell.actionSlotLookup, slot)
end

local function ScanActionBarSpells(spellsByName)
    if not GetActionInfo then
        return
    end

    for slot = CONST.ACTION_SLOT_FIRST, CONST.ACTION_SLOT_LAST do
        local spellID = U.GetActionSpellID(slot)
        if spellID and CanAddActionSpell(spellsByName, spellID) then
            AttachActionSlot(AddSpellToList(spellsByName, spellID, "action"), slot)
        end
    end
end

local function AddFlyoutSpells(spellsByName, flyoutID, source)
    if not flyoutID or not GetFlyoutInfo or not GetFlyoutSlotInfo then
        return
    end

    local _, _, numSlots = GetFlyoutInfo(flyoutID)
    if not numSlots or numSlots <= 0 then
        return
    end

    for slotIndex = 1, numSlots do
        local spellID, overrideSpellID, isKnown = GetFlyoutSlotInfo(flyoutID, slotIndex)
        if isKnown ~= false then
            AddSpellToList(spellsByName, overrideSpellID or spellID, source)
        end
    end
end

local function AddModernBookSlot(spellsByName, slotIndex, spellBank, source)
    if not C_SpellBook or not C_SpellBook.GetSpellBookItemInfo then
        return
    end

    local itemInfo, actionID, spellID = C_SpellBook.GetSpellBookItemInfo(slotIndex, spellBank)
    local itemType
    local isPassive

    if type(itemInfo) == "table" then
        itemType = itemInfo.itemType
        actionID = itemInfo.actionID
        spellID = itemInfo.spellID or itemInfo.actionID
        isPassive = itemInfo.isPassive
    else
        itemType = itemInfo
    end

    if IsSpellBookTypeFlyout(itemType) then
        AddFlyoutSpells(spellsByName, actionID or spellID, source)
        return
    end

    if not IsSpellBookTypeSpell(itemType) then
        return
    end

    if isPassive == nil then
        isPassive = IsPassiveBookSlot(slotIndex, spellBank)
    end
    if isPassive then
        return
    end

    AddSpellToList(spellsByName, spellID or actionID, source)
end

local function ScanModernSpellBook(spellsByName, spellBank, source)
    if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines or not C_SpellBook.GetSpellBookSkillLineInfo then
        return false
    end

    local numLines = C_SpellBook.GetNumSpellBookSkillLines()
    if not numLines or numLines <= 0 then
        return false
    end

    for lineIndex = 1, numLines do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
        if type(lineInfo) == "table" and not lineInfo.shouldHide then
            local offset = lineInfo.itemIndexOffset or lineInfo.spellBookItemIndexOffset or lineInfo.offset or 0
            local numItems = lineInfo.numSpellBookItems or lineInfo.numSlots or 0
            for slotIndex = offset + 1, offset + numItems do
                AddModernBookSlot(spellsByName, slotIndex, spellBank, source)
            end
        end
    end

    return true
end

local function ScanLegacySpellBook(spellsByName)
    if not GetNumSpellTabs or not GetSpellTabInfo or not GetSpellBookItemInfo then
        return
    end

    for tabIndex = 1, GetNumSpellTabs() do
        local _, _, offset, numSlots = GetSpellTabInfo(tabIndex)
        for slotIndex = offset + 1, offset + numSlots do
            local itemType, spellID = GetSpellBookItemInfo(slotIndex, BOOKTYPE_SPELL)
            if IsSpellBookTypeFlyout(itemType) then
                AddFlyoutSpells(spellsByName, spellID, "player")
            elseif IsSpellBookTypeSpell(itemType) and not IsPassiveBookSlot(slotIndex, BOOKTYPE_SPELL) then
                AddSpellToList(spellsByName, spellID, "player")
            end
        end
    end
end

local function AddKnownCooldownSupplements(spellsByName)
    for _, supplement in ipairs(CDR.COOLDOWN_SPELL_SUPPLEMENTS) do
        local name = U.GetSpellInfoCompat(supplement.id)
        local nameKey = U.NormalizeName(name)
        if nameKey ~= "" and spellsByName[nameKey] then
            AddSpellToList(spellsByName, supplement.id, "known", supplement.cooldown)
        elseif IsKnownSpellCompat(supplement.id) then
            AddSpellToList(spellsByName, supplement.id, "known", supplement.cooldown)
        end
    end
end

function CDR:BuildPlayerSpellList()
    local spellsByName = {}
    local playerBank = BOOKTYPE_SPELL

    if Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player then
        playerBank = Enum.SpellBookSpellBank.Player
    end

    if not ScanModernSpellBook(spellsByName, playerBank, "player") then
        ScanLegacySpellBook(spellsByName)
    end
    ScanActionBarSpells(spellsByName)
    AddKnownCooldownSupplements(spellsByName)

    self.playerSpells = {}
    self.playerSpellsByID = {}
    self.playerSpellsByName = {}

    for nameKey, spell in pairs(spellsByName) do
        spell.aliasLookup = nil
        spell.actionSlotLookup = nil
        table.sort(spell.aliases)
        if spell.actionSlots then
            table.sort(spell.actionSlots)
        end
        table.insert(self.playerSpells, spell)
        self.playerSpellsByID[spell.id] = spell
        for _, aliasID in ipairs(spell.aliases or {}) do
            self.playerSpellsByID[aliasID] = spell
        end
        self.playerSpellsByName[nameKey] = spell
    end

    table.sort(self.playerSpells, SortSpells)
    self:ReconcileWatchedSpellData()
end

function CDR:ReconcileWatchedSpellData()
    if not self.db or not self.db.spells then
        return
    end

    for spellID, saved in pairs(self.db.spells) do
        local nameKey = saved.nameKey or U.NormalizeName(saved.name)
        local playerSpell = self.playerSpellsByName and self.playerSpellsByName[nameKey]
        if playerSpell then
            local aliases = U.CopyAliasList(saved.aliases)
            local lookup = U.BuildLookup(aliases)
            for _, aliasID in ipairs(playerSpell.aliases or {}) do
                U.AddUnique(aliases, lookup, aliasID)
            end
            U.AddUnique(aliases, lookup, spellID)

            local actionSlots = {}
            local actionSlotLookup = {}
            for _, slot in ipairs(playerSpell.actionSlots or {}) do
                U.AddUnique(actionSlots, actionSlotLookup, slot)
            end
            for _, slot in ipairs(saved.actionSlots or {}) do
                local texture = GetActionTextureCompat(slot)
                if self:IsWatchedActionSlot(spellID, slot, lookup) or TexturesMatch(texture, playerSpell.icon or saved.icon) then
                    U.AddUnique(actionSlots, actionSlotLookup, slot)
                end
            end

            local baseCooldown = math.max(tonumber(saved.baseCooldown or 0) or 0, tonumber(playerSpell.forcedCooldown or 0) or 0)
            for _, aliasID in ipairs(aliases) do
                baseCooldown = math.max(baseCooldown, GetSpellBaseOrRechargeCooldown(aliasID))
            end

            saved.aliases = aliases
            saved.actionSlots = actionSlots
            saved.name = playerSpell.name or saved.name
            saved.icon = playerSpell.icon or saved.icon
            saved.baseCooldown = baseCooldown
        end
    end
    self:NormalizeWatchedOrder()
end

function CDR:NormalizeWatchedOrder()
    if not self.db or not self.db.spells then
        return
    end

    if type(self.db.order) ~= "table" then
        self.db.order = {}
    end

    local ordered = {}
    local seen = {}
    for _, spellID in ipairs(self.db.order) do
        spellID = U.ToSpellID(spellID)
        if spellID and self.db.spells[spellID] and not seen[spellID] then
            seen[spellID] = true
            table.insert(ordered, spellID)
        end
    end

    local missing = {}
    for spellID in pairs(self.db.spells) do
        if not seen[spellID] then
            table.insert(missing, spellID)
        end
    end
    table.sort(missing, function(a, b)
        local aName = self.db.spells[a].name or ""
        local bName = self.db.spells[b].name or ""
        if aName == bName then
            return a < b
        end
        return aName < bName
    end)

    for _, spellID in ipairs(missing) do
        table.insert(ordered, spellID)
    end

    self.db.order = ordered
end

function CDR:GetWatchedOrderIndex(spellID)
    self:NormalizeWatchedOrder()
    for index, orderedID in ipairs(self.db.order or {}) do
        if orderedID == spellID then
            return index
        end
    end
end

function CDR:MoveWatchedSpell(spellID, delta)
    self:NormalizeWatchedOrder()
    local index = self:GetWatchedOrderIndex(spellID)
    if not index then
        return
    end

    local targetIndex = U.Clamp(index + delta, 1, #self.db.order)
    if targetIndex == index then
        return
    end

    table.remove(self.db.order, index)
    table.insert(self.db.order, targetIndex, spellID)
    self:RefreshConfig()
    self:RefreshReminderAlerts()
end

function CDR:MoveWatchedSpellNear(draggedSpellID, targetSpellID)
    draggedSpellID = U.ToSpellID(draggedSpellID)
    targetSpellID = U.ToSpellID(targetSpellID)
    if not draggedSpellID or not targetSpellID or draggedSpellID == targetSpellID then
        return
    end

    self:NormalizeWatchedOrder()
    local draggedIndex = self:GetWatchedOrderIndex(draggedSpellID)
    local targetIndex = self:GetWatchedOrderIndex(targetSpellID)
    if not draggedIndex or not targetIndex then
        return
    end

    local insertAfterTarget = draggedIndex < targetIndex
    table.remove(self.db.order, draggedIndex)
    if draggedIndex < targetIndex then
        targetIndex = targetIndex - 1
    end
    if insertAfterTarget then
        targetIndex = targetIndex + 1
    end
    table.insert(self.db.order, U.Clamp(targetIndex, 1, #self.db.order + 1), draggedSpellID)
    self:RefreshConfig()
    self:RefreshReminderAlerts()
end

function CDR:StartWatchedDrag(spellID)
    self.draggedWatchedSpellID = U.ToSpellID(spellID)
end

function CDR:FinishWatchedDrag()
    self.draggedWatchedSpellID = nil
    if UI.watchedRows then
        for _, row in ipairs(UI.watchedRows) do
            row:SetAlpha(1)
        end
    end
end

function CDR:DragWatchedOver(targetSpellID)
    if not self.draggedWatchedSpellID or self.draggedWatchedSpellID == targetSpellID then
        return
    end
    self:MoveWatchedSpellNear(self.draggedWatchedSpellID, targetSpellID)
end

function CDR:GetAvailableSpells()
    local filter = U.NormalizeName(UI.searchBox and UI.searchBox:GetText() or "")
    local results = {}

    for _, spell in ipairs(self.playerSpells or {}) do
        if spell.isKnown ~= false and U.SpellHasMeaningfulCooldown(spell) and not self:IsWatchedName(spell.nameKey) then
            if filter == "" or string.find(spell.search, filter, 1, true) then
                table.insert(results, spell)
            end
        end
    end

    if filter ~= "" then
        table.sort(results, function(a, b)
            local aPosition = string.find(a.nameKey, filter, 1, true) or 9999
            local bPosition = string.find(b.nameKey, filter, 1, true) or 9999
            if aPosition ~= bPosition then
                return aPosition < bPosition
            end
            return SortSpells(a, b)
        end)
    else
        table.sort(results, function(a, b)
            return SortSpells(a, b)
        end)
    end

    return results
end

function CDR:GetWatchedList()
    local watched = {}
    self:NormalizeWatchedOrder()

    for _, spellID in ipairs(self.db.order or {}) do
        local saved = self.db.spells and self.db.spells[spellID]
        if saved then
            table.insert(watched, {
                id = spellID,
                name = saved.name or ("Spell " .. spellID),
                nameKey = saved.nameKey or U.NormalizeName(saved.name),
                icon = saved.icon or U.GetSpellTextureCompat(spellID) or 134400,
                baseCooldown = saved.baseCooldown,
            })
        end
    end

    return watched
end

function CDR:IsWatchedName(nameKey)
    for _, saved in pairs(self.db.spells or {}) do
        if (saved.nameKey or U.NormalizeName(saved.name)) == nameKey then
            return true
        end
    end
    return false
end

function CDR:AddWatchedSpell(spellID)
    local spell = self.playerSpellsByID and self.playerSpellsByID[spellID]
    if not spell then
        return
    end

    if self:IsWatchedName(spell.nameKey) then
        return
    end

    local baseCooldown = tonumber(spell.forcedCooldown or 0) or 0
    for _, aliasID in ipairs(spell.aliases or {}) do
        baseCooldown = math.max(baseCooldown, GetSpellBaseOrRechargeCooldown(aliasID))
    end

    self.db.spells[spell.id] = {
        name = spell.name,
        nameKey = spell.nameKey,
        icon = spell.icon,
        aliases = U.CopyAliasList(spell.aliases),
        actionSlots = U.CopyAliasList(spell.actionSlots),
        baseCooldown = baseCooldown,
    }
    if type(self.db.order) ~= "table" then
        self.db.order = {}
    end
    table.insert(self.db.order, spell.id)
    self:NormalizeWatchedOrder()

    self.cooldownState[spell.id] = self.cooldownState[spell.id] or {}
    self.readySpells[spell.id] = nil

    local onCooldown, remaining = self:GetWatchedCooldownStatus(spell.id)
    self.cooldownState[spell.id].seenCooldown = onCooldown
    self.cooldownState[spell.id].remaining = remaining
    if onCooldown and remaining > CONST.GCD_IGNORE_SECONDS then
        self:QueueReadyFallback(spell.id, remaining)
    elseif not onCooldown then
        self:MarkReady(spell.id)
    end

    self:RefreshConfig()
    self:RefreshReminderAlerts()
    self:ScheduleCooldownProbes(spell.id)
end

function CDR:RemoveWatchedSpell(spellID)
    self.db.spells[spellID] = nil
    self:NormalizeWatchedOrder()
    self.cooldownState[spellID] = nil
    self.readySpells[spellID] = nil
    self:RefreshConfig()
    self:RefreshReminderAlerts()
end

function CDR:GetWatchedCandidates(spellID)
    local saved = self.db.spells[spellID]
    local candidates = {}
    local lookup = {}

    if not saved then
        return candidates
    end

    local state = self.cooldownState[spellID]
    U.AddUnique(candidates, lookup, state and state.lastCastSpellID)
    U.AddUnique(candidates, lookup, saved.lastCastSpellID)
    U.AddUnique(candidates, lookup, spellID)

    for _, aliasID in ipairs(saved.aliases or {}) do
        U.AddUnique(candidates, lookup, aliasID)
    end

    local playerSpell = self.playerSpellsByName and self.playerSpellsByName[saved.nameKey or U.NormalizeName(saved.name)]
    if playerSpell then
        for _, aliasID in ipairs(playerSpell.aliases or {}) do
            U.AddUnique(candidates, lookup, aliasID)
        end
    end

    return candidates
end

function CDR:IsWatchedActionSlot(spellID, slot, candidateLookup)
    local saved = self.db.spells[spellID]
    if not saved then
        return false
    end

    local actionSpellID = U.GetActionSpellID(slot)
    if not actionSpellID then
        return false
    end

    if candidateLookup and candidateLookup[actionSpellID] then
        return true
    end

    local actionName = U.GetSpellInfoCompat(actionSpellID)
    return U.NormalizeName(actionName) == (saved.nameKey or U.NormalizeName(saved.name))
end

local function AddActionSnapshotRecord(index, key, record)
    if key == nil or key == "" then
        return
    end

    local records = index[key]
    if not records then
        records = {}
        index[key] = records
    end
    table.insert(records, record)
end

function CDR:InvalidateActionCooldownSnapshot(refreshFrames)
    self.actionCooldownSnapshot = nil
    if refreshFrames then
        self.actionButtonFrames = nil
    end
end

local function GetFrameName(frame)
    if not frame or not frame.GetName then
        return
    end

    local ok, name = pcall(frame.GetName, frame)
    if ok and type(name) == "string" then
        return name
    end
end

local function GetFrameAttribute(frame, attribute)
    if not frame or not frame.GetAttribute then
        return
    end

    local ok, value = pcall(frame.GetAttribute, frame, attribute)
    if ok then
        return value
    end
end

local function GetNamedFrameRegion(frame, suffix)
    local name = GetFrameName(frame)
    if not name then
        return
    end

    return _G and _G[name .. suffix]
end

local function GetFrameActionSlot(frame)
    if not frame then
        return
    end

    local action = frame.action
    if not action and frame.GetAttribute then
        action = GetFrameAttribute(frame, "action")
    end

    return U.ToSpellID(action)
end

local function GetFrameSpellID(frame)
    if not frame then
        return
    end

    local spellID = U.ToSpellID(frame.spellID or frame.spellId or frame.actionID)
    if not spellID then
        spellID = U.ToSpellID(GetFrameAttribute(frame, "spell"))
    end
    return spellID
end

local function IsActionButtonType(frame)
    local buttonType = frame and (frame.buttonType or frame.type)
    if not buttonType then
        buttonType = GetFrameAttribute(frame, "type")
    end

    buttonType = type(buttonType) == "string" and string.lower(buttonType) or buttonType
    return buttonType == "action" or buttonType == "spell" or buttonType == "macro" or buttonType == "item"
end

local function GetFrameIconTexture(frame)
    if not frame then
        return
    end

    local icon = frame.icon or frame.Icon or frame.IconTexture or GetNamedFrameRegion(frame, "Icon")
    if not icon and frame.GetNormalTexture then
        local ok, normalTexture = pcall(frame.GetNormalTexture, frame)
        if ok then
            icon = normalTexture
        end
    end
    if icon and icon.GetTexture then
        local ok, texture = pcall(icon.GetTexture, icon)
        if ok then
            return texture
        end
    end
end

local function GetFrameCooldownFrame(frame)
    if not frame then
        return
    end

    return frame.cooldown or frame.Cooldown or GetNamedFrameRegion(frame, "Cooldown")
end

local function GetCooldownFrameRemaining(cooldownFrame)
    if not cooldownFrame then
        return false, 0
    end

    if cooldownFrame.IsShown then
        local ok, shown = pcall(cooldownFrame.IsShown, cooldownFrame)
        if ok and not shown then
            return false, 0
        end
    end

    local startTime
    local duration
    local modRate = 1
    if cooldownFrame.GetCooldownTimes then
        local ok, startValue, durationValue, modRateValue = pcall(cooldownFrame.GetCooldownTimes, cooldownFrame)
        if ok then
            startTime = NumberOrNil(startValue)
            duration = NumberOrNil(durationValue)
            modRate = NumberOrNil(modRateValue) or modRate
            if modRate <= 0 then
                modRate = 1
            end
        end
    end

    if not duration or duration <= 0 then
        startTime = NumberOrNil(cooldownFrame.startTime or cooldownFrame.start)
        duration = NumberOrNil(cooldownFrame.duration)
        modRate = NumberOrNil(cooldownFrame.modRate or cooldownFrame.rate) or modRate
        if modRate <= 0 then
            modRate = 1
        end
    end

    if not startTime or not duration or duration <= 0 then
        return false, 0
    end

    local now = GetTime()
    if startTime > (now + 3600) then
        startTime = startTime / 1000
        duration = duration / 1000
    end

    local remaining = GetRemainingCooldown(startTime, duration, modRate, now)
    return remaining > 0, remaining
end

local function IsLikelyActionButtonFrame(frame)
    if not frame then
        return false
    end

    if GetFrameActionSlot(frame) then
        return true
    end

    if GetFrameSpellID(frame) or IsActionButtonType(frame) then
        return true
    end

    local name = GetFrameName(frame)
    if not name then
        return false
    end

    if string.find(name, "ActionButton", 1, true) or string.find(name, "MultiBar", 1, true) then
        return true
    end
    if string.find(name, "BT4Button", 1, true) or string.find(name, "DominosActionButton", 1, true) then
        return true
    end
    if string.find(name, "ElvUI_Bar", 1, true) then
        return true
    end

    local cooldownFrame = GetFrameCooldownFrame(frame)
    if string.find(name, "Button", 1, true) and GetFrameIconTexture(frame) and cooldownFrame then
        local onCooldown = GetCooldownFrameRemaining(cooldownFrame)
        if onCooldown then
            return true
        end
    end

    return false
end

local function IsFrameVisible(frame)
    if frame and frame.IsVisible then
        local ok, visible = pcall(frame.IsVisible, frame)
        if ok then
            return visible
        end
    end

    return true
end

function CDR:RefreshActionButtonFrames()
    if self.actionButtonFrames then
        return
    end

    local frames = {}
    local seen = {}
    local function addFrame(frame)
        if not frame or seen[frame] or not IsLikelyActionButtonFrame(frame) then
            return
        end
        if not GetFrameIconTexture(frame) and not GetFrameCooldownFrame(frame) then
            return
        end

        seen[frame] = true
        table.insert(frames, frame)
    end

    local prefixes = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
        "MultiBar5Button",
        "MultiBar6Button",
        "MultiBar7Button",
        "PetActionButton",
        "StanceButton",
        "ExtraActionButton",
        "BT4Button",
        "DominosActionButton",
        "ElvUI_Bar1Button",
        "ElvUI_Bar2Button",
        "ElvUI_Bar3Button",
        "ElvUI_Bar4Button",
        "ElvUI_Bar5Button",
        "ElvUI_Bar6Button",
    }

    if _G then
        for _, prefix in ipairs(prefixes) do
            for index = 1, 120 do
                addFrame(_G[prefix .. index])
            end
        end
    end

    self.actionButtonFrames = frames
end

function CDR:GetActionCooldownSnapshot()
    local now = GetTime()
    local snapshot = self.actionCooldownSnapshot
    if snapshot and snapshot.expiresAt and snapshot.expiresAt > now then
        return snapshot
    end

    snapshot = {
        expiresAt = now + CONST.ACTION_SNAPSHOT_MAX_AGE_SECONDS,
        bySlot = {},
        bySpellID = {},
        byNameKey = {},
    }

    for slot = CONST.ACTION_SLOT_FIRST, CONST.ACTION_SLOT_LAST do
        local actionSpellID = U.GetActionSpellID(slot)
        local texture = GetActionTextureCompat(slot)
        if actionSpellID or texture then
            local actionName = actionSpellID and U.GetSpellInfoCompat(actionSpellID)
            local nameKey = U.NormalizeName(actionName)
            local actionOnCooldown, remaining, actionHasUsableCharge = U.GetActionCooldownStatus(slot)
            local record = {
                slot = slot,
                spellID = actionSpellID,
                nameKey = nameKey,
                texture = texture,
                onCooldown = actionOnCooldown,
                remaining = remaining,
                actionOnCooldown = actionOnCooldown,
                actionRemaining = remaining,
                frameOnCooldown = false,
                frameRemaining = 0,
                hasUsableCharge = actionHasUsableCharge,
            }

            snapshot.bySlot[slot] = record
            AddActionSnapshotRecord(snapshot.bySpellID, actionSpellID, record)
            AddActionSnapshotRecord(snapshot.byNameKey, nameKey, record)
        end
    end

    self:RefreshActionButtonFrames()
    for _, frame in ipairs(self.actionButtonFrames or {}) do
        if IsFrameVisible(frame) then
            local slot = GetFrameActionSlot(frame)
            local actionSpellID = slot and U.GetActionSpellID(slot)
            if not actionSpellID then
                actionSpellID = GetFrameSpellID(frame)
            end
            local texture = GetFrameIconTexture(frame)
            local frameOnCooldown, frameRemaining = GetCooldownFrameRemaining(GetFrameCooldownFrame(frame))
            local actionOnCooldown, actionRemaining, actionHasUsableCharge = false, 0, false
            if slot then
                actionOnCooldown, actionRemaining, actionHasUsableCharge = U.GetActionCooldownStatus(slot)
                if actionHasUsableCharge then
                    frameOnCooldown = false
                    frameRemaining = 0
                end
            end

            local onCooldown = frameOnCooldown or actionOnCooldown
            local remaining = math.max(frameRemaining or 0, actionRemaining or 0)
            if slot or actionSpellID or texture then
                local actionName = actionSpellID and U.GetSpellInfoCompat(actionSpellID)
                local nameKey = U.NormalizeName(actionName)
                local frameName = GetFrameName(frame)
                local record = {
                    recordKey = "frame:" .. tostring(frameName or frame),
                    slot = slot,
                    spellID = actionSpellID,
                    nameKey = nameKey,
                    texture = texture,
                    onCooldown = onCooldown,
                    remaining = remaining,
                    actionOnCooldown = actionOnCooldown,
                    actionRemaining = actionRemaining,
                    frameOnCooldown = frameOnCooldown,
                    frameRemaining = frameRemaining,
                    hasUsableCharge = actionHasUsableCharge,
                }

                if slot and snapshot.bySlot[slot] and onCooldown and remaining > (snapshot.bySlot[slot].remaining or 0) then
                    snapshot.bySlot[slot].onCooldown = true
                    snapshot.bySlot[slot].remaining = remaining
                    snapshot.bySlot[slot].actionOnCooldown = snapshot.bySlot[slot].actionOnCooldown or actionOnCooldown
                    snapshot.bySlot[slot].actionRemaining = math.max(snapshot.bySlot[slot].actionRemaining or 0, actionRemaining or 0)
                    snapshot.bySlot[slot].frameOnCooldown = snapshot.bySlot[slot].frameOnCooldown or frameOnCooldown
                    snapshot.bySlot[slot].frameRemaining = math.max(snapshot.bySlot[slot].frameRemaining or 0, frameRemaining or 0)
                elseif slot and not snapshot.bySlot[slot] then
                    snapshot.bySlot[slot] = record
                end

                AddActionSnapshotRecord(snapshot.bySpellID, actionSpellID, record)
                AddActionSnapshotRecord(snapshot.byNameKey, nameKey, record)
            end
        end
    end

    self.actionCooldownSnapshot = snapshot
    return snapshot
end

function CDR:GetWatchedChargeProfile(spellID)
    local maxCharges = 0
    local currentCharges
    local rechargeDuration = 0
    local rechargeRemaining = 0
    local candidates = self:GetWatchedCandidates(spellID)
    local now = GetTime()

    for _, candidateID in ipairs(candidates) do
        local current, max, cooldownStartTime, cooldownDuration, chargeModRate = U.GetSpellChargesCompat(candidateID)
        local baseCooldown = U.GetSpellBaseCooldownCompat(candidateID)
        current = NumberOrNil(current)
        max = NumberOrZero(max)
        cooldownDuration = NumberOrZero(cooldownDuration)
        baseCooldown = NumberOrZero(baseCooldown)
        if max > maxCharges then
            maxCharges = max
        end
        if max > 1 and current then
            currentCharges = math.max(currentCharges or 0, U.Clamp(current, 0, max))
        end
        if cooldownDuration > rechargeDuration then
            rechargeDuration = cooldownDuration
        end
        local remaining = GetRemainingCooldown(cooldownStartTime, cooldownDuration, chargeModRate, now)
        if remaining > rechargeRemaining then
            rechargeRemaining = remaining
        end
        if baseCooldown > rechargeDuration then
            rechargeDuration = baseCooldown
        end
    end

    local saved = self.db.spells[spellID]
    local savedBaseCooldown = NumberOrZero(saved and saved.baseCooldown)
    if savedBaseCooldown > rechargeDuration then
        rechargeDuration = savedBaseCooldown
    end

    local candidateLookup = U.BuildLookup(candidates)
    for _, slot in ipairs(saved and saved.actionSlots or {}) do
        if self:IsWatchedActionSlot(spellID, slot, candidateLookup) and GetActionCharges then
            local current, max, cooldownStartTime, cooldownDuration, chargeModRate = GetActionChargeInfo(slot)
            current = NumberOrNil(current)
            max = NumberOrZero(max)
            cooldownDuration = NumberOrZero(cooldownDuration)
            if max > maxCharges then
                maxCharges = max
            end
            if max > 1 and current then
                currentCharges = math.max(currentCharges or 0, U.Clamp(current, 0, max))
            end
            if cooldownDuration > rechargeDuration then
                rechargeDuration = cooldownDuration
            end
            local remaining = GetRemainingCooldown(cooldownStartTime, cooldownDuration, chargeModRate, now)
            if remaining > rechargeRemaining then
                rechargeRemaining = remaining
            end
        end
    end

    return maxCharges, rechargeDuration, currentCharges, rechargeRemaining
end

function CDR:RecordWatchedChargeCast(spellID, state)
    local maxCharges, rechargeDuration, currentCharges = self:GetWatchedChargeProfile(spellID)
    if maxCharges <= 1 then
        return false
    end

    local now = GetTime()
    local previousTrackedCharges = AdvanceTrackedCharges(state, maxCharges, rechargeDuration, now)
    local apiCharges = currentCharges and U.Clamp(currentCharges, 0, maxCharges)
    local trackedCharges = U.Clamp((previousTrackedCharges or maxCharges) - 1, 0, maxCharges)

    if apiCharges and previousTrackedCharges and apiCharges < previousTrackedCharges then
        trackedCharges = apiCharges
    elseif apiCharges and not previousTrackedCharges and apiCharges < trackedCharges then
        trackedCharges = apiCharges
    end

    state.trackedCharges = trackedCharges
    state.trackedMaxCharges = maxCharges
    state.trackedChargeDuration = rechargeDuration
    if trackedCharges < maxCharges and rechargeDuration > CONST.GCD_IGNORE_SECONDS and (not state.trackedChargeReadyAt or state.trackedChargeReadyAt <= now) then
        state.trackedChargeReadyAt = now + rechargeDuration
    end

    local remaining = state.trackedChargeReadyAt and math.max(0, state.trackedChargeReadyAt - now) or 0
    return true, trackedCharges, maxCharges, remaining
end

function CDR:GetWatchedCooldownStatus(spellID)
    local onCooldown = false
    local longestRemaining = 0
    local candidates = self:GetWatchedCandidates(spellID)
    local state = self.cooldownState and self.cooldownState[spellID]
    local now = GetTime()
    local saved = self.db.spells[spellID]
    local maxCharges, rechargeDuration, currentCharges, rechargeRemaining = self:GetWatchedChargeProfile(spellID)
    if maxCharges > 1 then
        local trackedCharges, readyAt
        if state then
            trackedCharges, readyAt = AdvanceTrackedCharges(state, maxCharges, rechargeDuration, now)
        end
        if currentCharges then
            currentCharges = U.Clamp(currentCharges, 0, maxCharges)
            if state and trackedCharges and readyAt and readyAt > now and currentCharges > trackedCharges then
                currentCharges = trackedCharges
            elseif trackedCharges and currentCharges < trackedCharges and rechargeRemaining <= 0 then
                currentCharges = trackedCharges
            elseif state then
                state.trackedCharges = currentCharges
                state.trackedMaxCharges = maxCharges
                state.trackedChargeDuration = rechargeDuration
                if currentCharges < maxCharges and rechargeRemaining > 0 then
                    state.trackedChargeReadyAt = now + rechargeRemaining
                end
            end

            if currentCharges > 0 then
                if state and currentCharges >= maxCharges then
                    state.trackedChargeReadyAt = nil
                end
                return false, 0, true
            end
            if rechargeRemaining > 0 then
                return true, math.max(longestRemaining, rechargeRemaining), false
            end
            if state and rechargeDuration > CONST.GCD_IGNORE_SECONDS and not state.trackedChargeReadyAt then
                state.trackedChargeReadyAt = now + rechargeDuration
            end
            if state and state.trackedChargeReadyAt and state.trackedChargeReadyAt > now then
                return true, math.max(longestRemaining, state.trackedChargeReadyAt - now), false
            end
        elseif trackedCharges then
            if trackedCharges > 0 then
                return false, 0, true
            end
            if readyAt and readyAt > now then
                return true, math.max(longestRemaining, readyAt - now), false
            end
        end
    end

    for _, candidateID in ipairs(candidates) do
        local candidateOnCooldown, remaining = U.GetCooldownStatus(candidateID)
        if candidateOnCooldown then
            onCooldown = true
            if remaining > longestRemaining then
                longestRemaining = remaining
            end
        end
    end

    if onCooldown then
        return true, longestRemaining, false
    end

    local scheduledReadyAt = self:GetStateScheduledReadyAt(state)
    local scheduledRemaining = 0
    if scheduledReadyAt > now then
        scheduledRemaining = math.max(0, scheduledReadyAt - now)
    elseif scheduledReadyAt > 0 then
        return false, 0, false
    end

    local savedNameKey = saved and (saved.nameKey or U.NormalizeName(saved.name))
    local candidateLookup = U.BuildLookup(candidates)
    local snapshot = self:GetActionCooldownSnapshot()
    local checkedActionRecords = {}
    local actionOnCooldown = false
    local actionChargeReadyConfirmed = false
    local function checkActionRecord(record, matchStrength)
        local recordKey = record and (record.recordKey or record.slot or tostring(record))
        if not record or checkedActionRecords[recordKey] then
            return
        end

        checkedActionRecords[recordKey] = true
        if record.hasUsableCharge and matchStrength ~= "texture" then
            actionChargeReadyConfirmed = true
        end
        if record.onCooldown and matchStrength ~= "texture" then
            local remaining = record.remaining or 0
            if scheduledRemaining > 0 then
                if record.actionOnCooldown then
                    remaining = record.actionRemaining or remaining
                elseif record.frameOnCooldown then
                    remaining = scheduledRemaining
                end
            end
            actionOnCooldown = true
            onCooldown = true
            if remaining > longestRemaining then
                longestRemaining = remaining
            end
        end
    end

    for _, slot in ipairs(saved and saved.actionSlots or {}) do
        local record = snapshot.bySlot[slot]
        if record then
            checkActionRecord(record, "slot")
        elseif self:IsWatchedActionSlot(spellID, slot, candidateLookup) then
            local actionOnCooldownNow, remaining, actionHasUsableCharge = U.GetActionCooldownStatus(slot)
            checkActionRecord({
                slot = slot,
                onCooldown = actionOnCooldownNow,
                remaining = remaining,
                actionOnCooldown = actionOnCooldownNow,
                actionRemaining = remaining,
                frameOnCooldown = false,
                frameRemaining = 0,
                hasUsableCharge = actionHasUsableCharge,
            }, "slot")
        end
    end

    for _, candidateID in ipairs(candidates) do
        for _, record in ipairs(snapshot.bySpellID[candidateID] or {}) do
            checkActionRecord(record, "spell")
        end
    end

    if savedNameKey then
        for _, record in ipairs(snapshot.byNameKey[savedNameKey] or {}) do
            checkActionRecord(record, "name")
        end
    end

    if onCooldown then
        return true, math.max(longestRemaining, scheduledRemaining), false
    end

    if scheduledRemaining > 0 then
        return true, scheduledRemaining, false
    end

    -- During heavy combat WoW can briefly report empty action cooldowns; only
    -- explicit usable charges are stable enough to bypass fallback blocks.
    local actionReadyConfirmed = actionChargeReadyConfirmed and not actionOnCooldown
    return false, 0, actionReadyConfirmed
end

function CDR:GetWatchedChargeDisplay(spellID)
    local maxCharges, rechargeDuration, currentCharges, rechargeRemaining = self:GetWatchedChargeProfile(spellID)
    if maxCharges <= 1 then
        return
    end

    local state = self.cooldownState and self.cooldownState[spellID]
    local trackedCharges
    local now = GetTime()
    if state then
        trackedCharges = AdvanceTrackedCharges(state, maxCharges, rechargeDuration or state.trackedChargeDuration or 0, now)
    end

    if not currentCharges then
        currentCharges = trackedCharges
    elseif trackedCharges and state and state.trackedChargeReadyAt and state.trackedChargeReadyAt > now and currentCharges > trackedCharges then
        currentCharges = trackedCharges
    elseif currentCharges <= 0 and rechargeRemaining <= 0 and trackedCharges and trackedCharges > 0 then
        currentCharges = trackedCharges
    end

    currentCharges = currentCharges or maxCharges
    return U.Clamp(currentCharges, 0, maxCharges), maxCharges
end

function CDR:GetWatchedBaseCooldown(spellID)
    local longestCooldown = 0
    local saved = self.db.spells[spellID]
    if not saved then
        return 0
    end

    local savedBaseCooldown = tonumber(saved.baseCooldown or 0) or 0
    if savedBaseCooldown > longestCooldown then
        longestCooldown = savedBaseCooldown
    end

    local playerSpell = self.playerSpellsByName and self.playerSpellsByName[saved.nameKey or U.NormalizeName(saved.name)]
    local forcedCooldown = playerSpell and tonumber(playerSpell.forcedCooldown or 0) or 0
    if forcedCooldown > longestCooldown then
        longestCooldown = forcedCooldown
    end

    for _, candidateID in ipairs(self:GetWatchedCandidates(spellID)) do
        local baseCooldown = GetSpellBaseOrRechargeCooldown(candidateID)
        if baseCooldown and baseCooldown > longestCooldown then
            longestCooldown = baseCooldown
        end
    end

    local candidateLookup = U.BuildLookup(self:GetWatchedCandidates(spellID))
    for _, slot in ipairs(saved.actionSlots or {}) do
        if self:IsWatchedActionSlot(spellID, slot, candidateLookup) and GetActionCooldown then
            local _, duration = GetActionCooldown(slot)
            if IsGreaterThan(duration, longestCooldown) then
                longestCooldown = duration
            end
        end
        if self:IsWatchedActionSlot(spellID, slot, candidateLookup) and GetActionCharges then
            local _, maxCharges, _, cooldownDuration = GetActionChargeInfo(slot)
            if IsGreaterThan(maxCharges, 1) and IsGreaterThan(cooldownDuration, longestCooldown) then
                longestCooldown = cooldownDuration
            end
        end
    end

    return longestCooldown
end

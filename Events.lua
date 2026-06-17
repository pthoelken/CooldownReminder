local CDR = CooldownReminder
local UI = CDR.UI
local U = CDR.Utils
local CONST = CDR.CONST

function CDR:MarkReady(spellID)
    if not self.db.spells[spellID] then
        return false
    end

    if not self.readySpells[spellID] then
        self.readySpells[spellID] = true
        return true
    end

    return false
end

function CDR:IsMonitoringEnabled()
    return not self.db or self.db.monitoringEnabled ~= false
end

function CDR:SetMonitoringEnabled(enabled, silent)
    if not self.db then
        return
    end

    self.db.monitoringEnabled = enabled == true
    if self.db.monitoringEnabled then
        self:ScanCooldowns(true)
        if not silent then
            print("|cffffd100CooldownReminder:|r " .. self:L("MONITORING_ENABLED"))
        end
    else
        if UI.reminder then
            UI.reminder:Hide()
        end
        if not silent then
            print("|cffffd100CooldownReminder:|r " .. self:L("MONITORING_DISABLED"))
        end
    end

    if UI.config and UI.config:IsShown() then
        self:RefreshConfig()
    end
end

function CDR:UpdateReadyStateForSpell(spellID, playSound)
    if not self.db or not self.db.spells or not self.db.spells[spellID] then
        return
    end

    local onCooldown, remaining = self:GetWatchedCooldownStatus(spellID)
    local state = self.cooldownState[spellID] or {}
    self.cooldownState[spellID] = state

    if onCooldown then
        state.seenCooldown = true
        state.remaining = remaining
        self.readySpells[spellID] = nil
        if remaining > CONST.GCD_IGNORE_SECONDS and not state.pendingReadyAt then
            self:QueueReadyFallback(spellID, remaining)
        end
    else
        state.seenCooldown = false
        state.remaining = 0
        state.pendingReadyAt = nil
        if self:MarkReady(spellID) and playSound then
            self:PlaySelectedSound(false)
        end
    end

    self:RefreshReminderAlerts()
    if UI.config and UI.config:IsShown() then
        self:RefreshConfig()
    end
end

function CDR:QueueReadyFallback(spellID, delaySeconds)
    if not self.db.spells[spellID] or not C_Timer then
        return
    end

    delaySeconds = tonumber(delaySeconds or 0) or 0
    if delaySeconds <= CONST.GCD_IGNORE_SECONDS then
        return
    end

    local state = self.cooldownState[spellID] or {}
    self.cooldownState[spellID] = state
    state.readyToken = (state.readyToken or 0) + 1
    state.pendingReadyAt = GetTime() + delaySeconds

    local token = state.readyToken
    C_Timer.After(delaySeconds + 0.12, function()
        CDR:FinishPendingReady(spellID, token)
    end)
end

function CDR:ScheduleCooldownProbes(spellID)
    if not C_Timer then
        return
    end

    local delays = { 0.05, 0.25, 0.75, 1.5 }
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            if CDR.db and CDR.db.spells and CDR.db.spells[spellID] then
                CDR:ScanCooldowns(false)
                if UI.config and UI.config:IsShown() then
                    CDR:RefreshConfig()
                end
            end
        end)
    end
end

function CDR:FinishPendingReady(spellID, token)
    if not self.db or not self.db.spells or not self.db.spells[spellID] then
        return
    end

    local state = self.cooldownState[spellID]
    if not state or state.readyToken ~= token or self.readySpells[spellID] then
        return
    end

    local onCooldown, remaining = self:GetWatchedCooldownStatus(spellID)
    if onCooldown then
        state.seenCooldown = true
        state.remaining = remaining
        self:QueueReadyFallback(spellID, remaining)
        return
    end

    state.seenCooldown = false
    state.remaining = 0
    state.pendingReadyAt = nil
    if self:MarkReady(spellID) then
        self:PlaySelectedSound(false)
    end
    self:RefreshReminderAlerts()
    if UI.config and UI.config:IsShown() then
        self:RefreshConfig()
    end
end

function CDR:ScanCooldowns(initialScan)
    if not self.db or not self.db.spells then
        return
    end

    local now = GetTime()
    local playReadySound = false
    for spellID in pairs(self.db.spells) do
        local onCooldown, remaining = self:GetWatchedCooldownStatus(spellID)
        local state = self.cooldownState[spellID]
        if not state then
            state = {}
            self.cooldownState[spellID] = state
        end

        if onCooldown then
            state.seenCooldown = true
            state.remaining = remaining
            state.ignoreUntil = nil
            self.readySpells[spellID] = nil
            if remaining > CONST.GCD_IGNORE_SECONDS and not state.pendingReadyAt then
                self:QueueReadyFallback(spellID, remaining)
            end
        elseif initialScan then
            state.seenCooldown = false
            state.remaining = 0
            state.pendingReadyAt = nil
            self:MarkReady(spellID)
        elseif state.seenCooldown or (state.pendingReadyAt and now >= state.pendingReadyAt) then
            state.seenCooldown = false
            state.remaining = 0
            state.pendingReadyAt = nil
            if self:MarkReady(spellID) then
                playReadySound = true
            end
        elseif state.ignoreUntil and now > state.ignoreUntil then
            state.ignoreUntil = nil
        end
    end

    if playReadySound then
        self:PlaySelectedSound(false)
    end

    self:RefreshReminderAlerts()
    if UI.config and UI.config:IsShown() then
        self:RefreshConfig()
    end
end

function CDR:IsWatchedCast(spellName, spellID)
    if not self.db or not self.db.spells then
        return
    end

    if spellID and self.db.spells[spellID] then
        return spellID
    end

    if spellID then
        for watchedSpellID, saved in pairs(self.db.spells) do
            if saved.lastCastSpellID == spellID then
                return watchedSpellID
            end
            for _, aliasID in ipairs(saved.aliases or {}) do
                if aliasID == spellID then
                    return watchedSpellID
                end
            end
        end
    end

    local nameKey = U.NormalizeName(spellName)
    if nameKey ~= "" then
        for watchedSpellID, saved in pairs(self.db.spells) do
            if (saved.nameKey or U.NormalizeName(saved.name)) == nameKey then
                return watchedSpellID
            end
        end
    end
end

function CDR:OnSpellCastSucceeded(unitTarget, _, spellID)
    if unitTarget ~= "player" or not self.db or not self.db.spells then
        return
    end

    local spellName = spellID and U.GetSpellInfoCompat(spellID)
    local watchedSpellID = self:IsWatchedCast(spellName, spellID)
    if not watchedSpellID then
        return
    end

    local saved = self.db.spells[watchedSpellID]
    local state = self.cooldownState[watchedSpellID] or {}
    self.cooldownState[watchedSpellID] = state

    if spellID and saved then
        saved.lastCastSpellID = spellID
        state.lastCastSpellID = spellID
        saved.aliases = U.CopyAliasList(saved.aliases)
        local lookup = {}
        for _, aliasID in ipairs(saved.aliases) do
            lookup[aliasID] = true
        end
        U.AddUnique(saved.aliases, lookup, spellID)
    end

    local currentCharges, maxCharges = self:GetWatchedChargeInfo(watchedSpellID)
    if maxCharges > 1 and currentCharges > 0 then
        self:MarkReady(watchedSpellID)
    else
        self.readySpells[watchedSpellID] = nil
    end
    state.pendingReadyAt = nil
    local baseCooldown = self:GetWatchedBaseCooldown(watchedSpellID)
    if baseCooldown > CONST.GCD_IGNORE_SECONDS then
        saved.baseCooldown = baseCooldown
        self:QueueReadyFallback(watchedSpellID, baseCooldown)
    end
    self:RefreshReminderAlerts()

    C_Timer.After(0.08, function()
        CDR:UpdateReadyStateForSpell(watchedSpellID, false)
    end)
    C_Timer.After(0.25, function()
        CDR:UpdateReadyStateForSpell(watchedSpellID, false)
    end)
    C_Timer.After(0.6, function()
        CDR:ScanCooldowns(false)
    end)
end

function CDR:TestReminder()
    local firstSpellID
    local testName
    local testIcon

    for spellID in pairs(self.db.spells) do
        firstSpellID = spellID
        testName = self.db.spells[spellID].name
        testIcon = self.db.spells[spellID].icon
        break
    end

    if not firstSpellID then
        if self.playerSpells and self.playerSpells[1] then
            firstSpellID = self.playerSpells[1].id
            testName = self.playerSpells[1].name
            testIcon = self.playerSpells[1].icon
        else
            print("|cffffd100CooldownReminder:|r " .. self:L("NO_SPELLBOOK_SPELLS"))
            return
        end
    end

    self.readySpells[firstSpellID] = true
    self.testReadySpell = {
        id = firstSpellID,
        name = testName or U.GetSpellInfoCompat(firstSpellID) or ("Spell " .. firstSpellID),
        icon = testIcon or U.GetSpellTextureCompat(firstSpellID) or 134400,
    }
    self:RefreshReminderAlerts()
    self:PlaySelectedSound(false)
    C_Timer.After(4, function()
        if CDR.testReadySpell and CDR.testReadySpell.id == firstSpellID then
            CDR.readySpells[firstSpellID] = nil
            CDR.testReadySpell = nil
            CDR:RefreshReminderAlerts()
        end
    end)
end

function CDR:RegisterSlashCommands()
    SLASH_COOLDOWNREMINDER1 = "/cdr"
    SLASH_COOLDOWNREMINDER2 = "/cooldownreminder"
    SlashCmdList.COOLDOWNREMINDER = function(message)
        message = string.lower(U.Trim(message or ""))
        if message == "test" then
            CDR:TestReminder()
        elseif message == "reset" then
            CDR:ResetReminderLayout()
            print("|cffffd100CooldownReminder:|r " .. CDR:L("POSITION_RESET"))
        elseif message == "ac" or message == "on" or message == "enable" then
            CDR:SetMonitoringEnabled(true)
        elseif message == "ia" or message == "off" or message == "disable" then
            CDR:SetMonitoringEnabled(false)
        else
            CDR:ToggleConfig()
        end
    end
end

function CDR:PrintLoadMessage()
    if self.loadMessagePrinted or not self.db or not self.db.ui.showLoadMessage then
        return
    end

    self.loadMessagePrinted = true
    print("|cffbda6ff[CooldownReminder]|r |cff33ff33" .. (self.VERSION or "") .. "|r " .. self:L("LOAD_MESSAGE"))
end

function CDR:Initialize()
    self.cooldownState = {}
    self.readySpells = {}
    self.playerSpells = {}
    self.playerSpellsByID = {}
    self.playerSpellsByName = {}
    self.activeTab = 1

    self:InitializeDatabase()
    self:ApplyLocale()
    self:CreateReminderWindow()
    self:CreateConfigWindow()
    self:RegisterSettingsCategory()
    self:RegisterSlashCommands()
end

CDR:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == self.ADDON_NAME then
            self:Initialize()
        end
    elseif event == "PLAYER_LOGIN" then
        self:BuildPlayerSpellList()
        self:ScanCooldowns(true)
        self:PrintLoadMessage()
        if self.ticker then
            self.ticker:Cancel()
        end
        self.ticker = C_Timer.NewTicker(CONST.READY_SCAN_INTERVAL, function()
            CDR:ScanCooldowns(false)
        end)
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "ACTIONBAR_SLOT_CHANGED" then
        self:BuildPlayerSpellList()
        self:ScanCooldowns(false)
        if UI.config and UI.config:IsShown() then
            self:RefreshConfig()
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
        self:ScanCooldowns(false)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        self:OnSpellCastSucceeded(...)
    end
end)

CDR:RegisterEvent("ADDON_LOADED")
CDR:RegisterEvent("PLAYER_LOGIN")
CDR:RegisterEvent("SPELLS_CHANGED")
CDR:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
CDR:RegisterEvent("PLAYER_TALENT_UPDATE")
CDR:RegisterEvent("TRAIT_CONFIG_UPDATED")
CDR:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
CDR:RegisterEvent("SPELL_UPDATE_COOLDOWN")
CDR:RegisterEvent("SPELL_UPDATE_CHARGES")
CDR:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
CDR:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

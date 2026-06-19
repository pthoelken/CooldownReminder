local CDR = CooldownReminder
local UI = CDR.UI
local U = CDR.Utils
local CONST = CDR.CONST

local function GetFontStringFont(fontString)
    if fontString and fontString.GetObjectType and fontString:GetObjectType() == "FontString" and fontString.GetFont then
        local fontPath, _, flags = fontString:GetFont()
        if fontPath then
            return fontPath, flags
        end
    end
end

local function GetCooldownCountdownFont(cooldown)
    local fontPath, flags

    if cooldown then
        for _, key in ipairs({ "Text", "text", "Countdown", "timer", "Timer" }) do
            fontPath, flags = GetFontStringFont(cooldown[key])
            if fontPath then
                return fontPath, flags
            end
        end

        if cooldown.CountdownFrame then
            for _, key in ipairs({ "Countdown", "Text" }) do
                fontPath, flags = GetFontStringFont(cooldown.CountdownFrame[key])
                if fontPath then
                    return fontPath, flags
                end
            end
        end
    end

    if cooldown and cooldown.GetRegions then
        for _, region in ipairs({ cooldown:GetRegions() }) do
            fontPath, flags = GetFontStringFont(region)
            if fontPath then
                return fontPath, flags
            end
        end
    end

    if cooldown and cooldown.GetChildren then
        for _, child in ipairs({ cooldown:GetChildren() }) do
            if child and child.GetRegions then
                for _, region in ipairs({ child:GetRegions() }) do
                    fontPath, flags = GetFontStringFont(region)
                    if fontPath then
                        return fontPath, flags
                    end
                end
            end
        end
    end

    local fontHeight
    if NumberFontNormalHuge and NumberFontNormalHuge.GetFont then
        fontPath, fontHeight, flags = NumberFontNormalHuge:GetFont()
        if fontPath then
            return fontPath, flags
        end
    end

    if NumberFontNormal and NumberFontNormal.GetFont then
        fontPath, fontHeight, flags = NumberFontNormal:GetFont()
        if fontPath then
            return fontPath, flags
        end
    end
end

local function ApplyCooldownNumberFont(fontString, cooldown, fontSize)
    local fontPath, flags = GetCooldownCountdownFont(cooldown)
    if fontString and fontString.SetFont and fontPath then
        fontString:SetFont(fontPath, fontSize, flags or "OUTLINE")
    elseif fontString and fontString.SetFontObject and NumberFontNormal then
        fontString:SetFontObject(NumberFontNormal)
    end
end

local function GetReminderBaseCooldown(addon, spellID, saved)
    local baseCooldown = tonumber(saved and saved.baseCooldown or 0) or 0
    if baseCooldown <= CONST.GCD_IGNORE_SECONDS and type(addon.GetWatchedBaseCooldown) == "function" then
        baseCooldown = tonumber(addon:GetWatchedBaseCooldown(spellID) or 0) or 0
    end
    return baseCooldown
end

function CDR:SaveReminderPosition()
    if not UI.reminder or not self.db then
        return
    end

    local point, _, relativePoint, x, y = UI.reminder:GetPoint(1)
    self.db.reminder.point = point or "CENTER"
    self.db.reminder.relativePoint = relativePoint or point or "CENTER"
    self.db.reminder.x = U.Round(x or 0)
    self.db.reminder.y = U.Round(y or 0)
    if self.db.reminder.showTitle then
        local rowWidth = UI.reminder:GetWidth()
        if self.db.reminder.layout == "horizontal" then
            local count = math.max(1, UI.reminder.visibleCount or 1)
            rowWidth = (UI.reminder:GetWidth() - (CONST.ALERT_ROW_SPACING * (count - 1))) / count
        end
        self.db.reminder.width = U.Round(U.Clamp(rowWidth, 150, CONST.ALERT_MAX_WIDTH))
    end
    self.db.reminder.height = U.Round(UI.reminder:GetHeight())
    self.db.reminder.scale = UI.reminder:GetScale()
end

function CDR:SetReminderScale(scale)
    if not UI.reminder or not self.db then
        return
    end

    scale = U.Clamp(scale or 1, 0.6, 2)
    self.db.reminder.scale = scale
    UI.reminder:SetScale(scale)

    if UI.scaleSlider and U.Round(UI.scaleSlider:GetValue() * 100) ~= U.Round(scale * 100) then
        UI.scaleSlider:SetValue(scale)
    end
end

function CDR:SetReminderLayout(layout)
    layout = U.GetReminderLayoutOption(layout).id
    if self.db.reminder.layout == layout then
        return
    end

    self.db.reminder.layout = layout
    self:RefreshReminderAlerts()
    if UI.layoutDropdown then
        UIDropDownMenu_SetText(UI.layoutDropdown, U.GetReminderLayoutLabel(layout))
    end
    if UI.config and UI.config:IsShown() then
        self:RefreshConfig()
    end
end

function CDR:SetReminderMode(mode)
    mode = U.GetReminderModeOption(mode).id
    if self.db.reminder.mode == mode then
        return
    end

    self.db.reminder.mode = mode
    self:RefreshReminderAlerts()
    if UI.modeDropdown then
        UIDropDownMenu_SetText(UI.modeDropdown, U.GetReminderModeLabel(mode))
    end
    if UI.config and UI.config:IsShown() then
        self:RefreshConfig()
    end
end

function CDR:ApplyReminderStrata()
    if not UI.reminder or not self.db or not self.db.reminder then
        return
    end

    UI.reminder:SetFrameStrata(self.db.reminder.topMost and "HIGH" or "MEDIUM")
    UI.reminder:SetFrameLevel(self.db.reminder.topMost and 80 or 5)
end

function CDR:SetReminderTopMost(enabled)
    self.db.reminder.topMost = enabled == true
    self:ApplyReminderStrata()
    self:RefreshReminderAlerts()
end

function CDR:ApplyReminderLayout()
    if not UI.reminder or not self.db then
        return
    end

    self:ApplyReminderStrata()
    local reminder = self.db.reminder
    UI.reminder:ClearAllPoints()
    UI.reminder:SetPoint(reminder.point or "CENTER", UIParent, reminder.relativePoint or "CENTER", reminder.x or 0, reminder.y or 140)
    UI.reminder:SetSize(U.Clamp(reminder.width or 260, CONST.ALERT_MIN_WIDTH, CONST.ALERT_MAX_WIDTH), reminder.height or CONST.ALERT_ROW_HEIGHT)
    UI.reminder:SetScale(U.Clamp(reminder.scale or 1, 0.6, 2))
end

function CDR:ResetReminderLayout()
    local defaults = self.defaults.reminder
    self.db.reminder.point = defaults.point
    self.db.reminder.relativePoint = defaults.relativePoint
    self.db.reminder.x = defaults.x
    self.db.reminder.y = defaults.y
    self.db.reminder.width = defaults.width
    self.db.reminder.height = defaults.height
    self.db.reminder.scale = defaults.scale
    self:ApplyReminderLayout()
    self:RefreshReminderAlerts()
    if UI.scaleSlider then
        UI.scaleSlider:SetValue(defaults.scale)
    end
end

function CDR:CreateReminderRow(index)
    local row = CreateFrame("Frame", nil, UI.reminder, BackdropTemplateMixin and "BackdropTemplate")
    row:SetHeight(CONST.ALERT_ROW_HEIGHT)
    row:EnableMouse(true)
    U.CreateBackdrop(row, 0.82)
    U.CreateAnimatedBorder(row)

    row:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            UI.reminder:StartMoving()
        end
    end)
    row:SetScript("OnMouseUp", function(frame, button)
        UI.reminder:StopMovingOrSizing()
        CDR:SaveReminderPosition()
        if button == "RightButton" and frame.spellID then
            CDR.readySpells[frame.spellID] = nil
            CDR:RefreshReminderAlerts()
        end
    end)
    row:SetScript("OnMouseWheel", function(_, delta)
        CDR:SetReminderScale((CDR.db.reminder.scale or 1) + (delta * 0.05))
        CDR:SaveReminderPosition()
    end)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(CONST.ALERT_ICON_SIZE, CONST.ALERT_ICON_SIZE)
    icon:SetPoint("LEFT", 4, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, row, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    if cooldown.SetDrawEdge then
        cooldown:SetDrawEdge(true)
    end
    if cooldown.SetDrawBling then
        cooldown:SetDrawBling(false)
    end
    if cooldown.SetDrawSwipe then
        cooldown:SetDrawSwipe(true)
    end
    if cooldown.SetSwipeColor then
        cooldown:SetSwipeColor(0, 0, 0, 0.86)
    end
    if cooldown.SetEdgeScale then
        cooldown:SetEdgeScale(0.85)
    end
    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(false)
    end
    cooldown:Hide()
    row.cooldown = cooldown

    local cooldownShade = row:CreateTexture(nil, "ARTWORK")
    cooldownShade:SetAllPoints(icon)
    U.SetTextureColor(cooldownShade, 0, 0, 0, 0.34)
    cooldownShade:Hide()
    row.cooldownShade = cooldownShade

    local iconOverlay = CreateFrame("Frame", nil, row)
    iconOverlay:SetAllPoints(icon)
    if iconOverlay.SetFrameLevel and cooldown.GetFrameLevel then
        iconOverlay:SetFrameLevel((cooldown:GetFrameLevel() or row:GetFrameLevel() or 0) + 1)
    end
    row.iconOverlay = iconOverlay

    local baseCooldownText = iconOverlay:CreateFontString(nil, "OVERLAY")
    ApplyCooldownNumberFont(baseCooldownText, cooldown, 11)
    baseCooldownText:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -1)
    baseCooldownText:SetSize(CONST.ALERT_ICON_SIZE - 4, 14)
    baseCooldownText:SetJustifyH("LEFT")
    baseCooldownText:SetTextColor(1, 0.82, 0.2, 1)
    if baseCooldownText.SetShadowColor then
        baseCooldownText:SetShadowColor(0, 0, 0, 1)
        baseCooldownText:SetShadowOffset(1, -1)
    end
    baseCooldownText:Hide()
    row.baseCooldownText = baseCooldownText

    local charges = iconOverlay:CreateFontString(nil, "OVERLAY")
    ApplyCooldownNumberFont(charges, cooldown, 14)
    charges:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 0)
    charges:SetJustifyH("RIGHT")
    charges:SetTextColor(1, 1, 1, 1)
    if charges.SetShadowColor then
        charges:SetShadowColor(0, 0, 0, 1)
        charges:SetShadowOffset(1, -1)
    end
    charges:Hide()
    row.charges = charges

    local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    title:SetPoint("RIGHT", -10, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    row.title = title

    UI.alertRows[index] = row
    return row
end

function CDR:CreateReminderWindow()
    local frame = CreateFrame("Frame", "CooldownReminderAlertStack", UIParent)
    UI.reminder = frame
    UI.alertRows = {}

    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:RegisterForDrag("LeftButton")

    if frame.SetResizeBounds then
        frame:SetResizeBounds(CONST.ALERT_MIN_WIDTH, CONST.ALERT_ROW_HEIGHT, CONST.ALERT_MAX_STACK_WIDTH, 600)
    else
        frame:SetMinResize(CONST.ALERT_MIN_WIDTH, CONST.ALERT_ROW_HEIGHT)
        frame:SetMaxResize(CONST.ALERT_MAX_STACK_WIDTH, 600)
    end

    frame:SetScript("OnDragStart", function(reminder)
        reminder:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(reminder)
        reminder:StopMovingOrSizing()
        CDR:SaveReminderPosition()
    end)
    frame:SetScript("OnMouseWheel", function(_, delta)
        CDR:SetReminderScale((CDR.db.reminder.scale or 1) + (delta * 0.05))
        CDR:SaveReminderPosition()
    end)

    local resize = CreateFrame("Button", nil, frame)
    resize:SetSize(16, 16)
    resize:SetPoint("BOTTOMRIGHT", -2, 2)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        CDR:SaveReminderPosition()
        CDR:RefreshReminderAlerts()
    end)
    frame.resize = resize

    self:ApplyReminderLayout()
    frame:Hide()
end

function CDR:GetReadyList()
    local ready = {}
    local orderIndex = {}
    self:NormalizeWatchedOrder()
    for index, spellID in ipairs(self.db.order or {}) do
        orderIndex[spellID] = index
    end

    for spellID in pairs(self.readySpells or {}) do
        local saved = self.db.spells[spellID]
        if saved then
            local onCooldown, _, actionReadyConfirmed = self:GetWatchedCooldownStatus(spellID)
            if onCooldown then
                self.readySpells[spellID] = nil
            else
                local now = GetTime()
                local state = self.cooldownState and self.cooldownState[spellID]
                if state and self:ShouldDeferReady(spellID, state, now, actionReadyConfirmed) then
                    self.readySpells[spellID] = nil
                else
                    local blockedUntil = state and math.max(state.castSettleUntil or 0, state.cooldownBlockUntil or 0, state.pendingReadyAt or 0) or 0
                    if blockedUntil > now then
                        self.readySpells[spellID] = nil
                    else
                        local charges, maxCharges = self:GetWatchedChargeDisplay(spellID)
                        table.insert(ready, {
                            id = spellID,
                            name = saved.name or ("Spell " .. spellID),
                            icon = saved.icon or U.GetSpellTextureCompat(spellID) or 134400,
                            charges = charges,
                            maxCharges = maxCharges,
                            baseCooldown = GetReminderBaseCooldown(self, spellID, saved),
                            pulseUntil = state and state.readyPulseUntil or nil,
                        })
                    end
                end
            end
        elseif self.testReadySpell and self.testReadySpell.id == spellID then
            table.insert(ready, {
                id = spellID,
                name = self.testReadySpell.name,
                icon = self.testReadySpell.icon,
                baseCooldown = 0,
                pulseUntil = GetTime() + CONST.READY_PULSE_SECONDS,
            })
        else
            self.readySpells[spellID] = nil
        end
    end

    table.sort(ready, function(a, b)
        local aIndex = orderIndex[a.id] or 9999
        local bIndex = orderIndex[b.id] or 9999
        if aIndex ~= bIndex then
            return aIndex < bIndex
        end
        if a.name == b.name then
            return a.id < b.id
        end
        return a.name < b.name
    end)

    return ready
end

function CDR:GetTimeReminderList()
    local spells = {}
    local now = GetTime()
    self:NormalizeWatchedOrder()

    for _, spellID in ipairs(self.db.order or {}) do
        local saved = self.db.spells[spellID]
        if saved then
            local isTestSpell = self.testReadySpell and self.testReadySpell.id == spellID
            local onCooldown, remaining, actionReadyConfirmed = self:GetWatchedCooldownStatus(spellID)
            local state = self.cooldownState and self.cooldownState[spellID]

            if isTestSpell then
                onCooldown = false
                remaining = 0
            elseif onCooldown then
                self.readySpells[spellID] = nil
            elseif state and self:ShouldDeferReady(spellID, state, now, actionReadyConfirmed) then
                local blockedUntil = math.max(state.castSettleUntil or 0, state.cooldownBlockUntil or 0, state.pendingReadyAt or 0)
                onCooldown = true
                remaining = math.max(0, blockedUntil - now)
                self.readySpells[spellID] = nil
            end

            local charges, maxCharges = self:GetWatchedChargeDisplay(spellID)
            local baseCooldown = GetReminderBaseCooldown(self, spellID, saved)
            local cooldownDuration = math.max(remaining or 0, baseCooldown)
            table.insert(spells, {
                id = spellID,
                name = saved.name or ("Spell " .. spellID),
                icon = saved.icon or U.GetSpellTextureCompat(spellID) or 134400,
                charges = charges,
                maxCharges = maxCharges,
                baseCooldown = baseCooldown,
                onCooldown = onCooldown == true,
                remaining = remaining or 0,
                cooldownDuration = cooldownDuration,
                pulseUntil = state and state.readyPulseUntil or nil,
            })
        end
    end

    if #spells == 0 and self.testReadySpell then
        table.insert(spells, {
            id = self.testReadySpell.id,
            name = self.testReadySpell.name,
            icon = self.testReadySpell.icon,
            baseCooldown = 0,
            onCooldown = false,
            remaining = 0,
            pulseUntil = now + CONST.READY_PULSE_SECONDS,
        })
    end

    return spells
end

function CDR:GetReminderDisplayList()
    if self.db and self.db.reminder and self.db.reminder.mode == "time" then
        return self:GetTimeReminderList()
    end

    return self:GetReadyList()
end

function CDR:RefreshReminderAlerts()
    if not UI.reminder then
        return
    end

    if self.db and self.db.monitoringEnabled == false then
        for _, row in ipairs(UI.alertRows or {}) do
            row.spellID = nil
            row:Hide()
        end
        UI.reminder:Hide()
        return
    end

    self:ApplyReminderStrata()
    local spells = self:GetReminderDisplayList()
    local count = #spells
    local showTitle = self.db.reminder.showTitle
    local showCooldownDuration = self.db.reminder.showCooldownDuration ~= false
    local layout = self.db.reminder.layout or "vertical"
    local rowWidth = showTitle and U.Clamp(self.db.reminder.width or 260, 150, CONST.ALERT_MAX_WIDTH) or (CONST.ALERT_ICON_SIZE + 8)
    local rowHeight = CONST.ALERT_ROW_HEIGHT
    local totalWidth = rowWidth
    local totalHeight = rowHeight

    if count > 0 then
        if layout == "horizontal" then
            totalWidth = (rowWidth * count) + (CONST.ALERT_ROW_SPACING * (count - 1))
        else
            totalHeight = (rowHeight * count) + (CONST.ALERT_ROW_SPACING * (count - 1))
        end
    end

    UI.reminder:SetSize(totalWidth, totalHeight)
    UI.reminder.rowWidth = rowWidth
    UI.reminder.visibleCount = count
    if showTitle then
        self.db.reminder.width = rowWidth
    end
    self.db.reminder.height = totalHeight

    for index, spell in ipairs(spells) do
        local row = UI.alertRows[index] or self:CreateReminderRow(index)
        row.spellID = spell.id
        row.cooldownActive = spell.onCooldown == true
        row.readyPulseUntil = spell.pulseUntil
        row:SetSize(rowWidth, rowHeight)
        row:ClearAllPoints()
        if index == 1 then
            row:SetPoint("TOPLEFT", UI.reminder, "TOPLEFT", 0, 0)
        elseif layout == "horizontal" then
            row:SetPoint("TOPLEFT", UI.alertRows[index - 1], "TOPRIGHT", CONST.ALERT_ROW_SPACING, 0)
        else
            row:SetPoint("TOPLEFT", UI.alertRows[index - 1], "BOTTOMLEFT", 0, -CONST.ALERT_ROW_SPACING)
        end
        row.icon:SetTexture(spell.icon)
        if row.icon.SetDesaturated then
            row.icon:SetDesaturated(spell.onCooldown == true)
        end
        if spell.onCooldown then
            row.icon:SetVertexColor(0.5, 0.5, 0.5, 1)
            row.cooldownShade:Show()
            if spell.remaining and spell.remaining > 0 then
                if row.cooldown.SetCooldown and spell.cooldownDuration and spell.cooldownDuration > 0 then
                    local duration = math.max(spell.cooldownDuration, spell.remaining)
                    row.cooldown:SetCooldown(GetTime() - math.max(0, duration - spell.remaining), duration)
                    row.cooldown:Show()
                else
                    row.cooldown:Hide()
                end
            else
                row.cooldown:Hide()
            end
        else
            row.icon:SetVertexColor(1, 1, 1, 1)
            row.cooldownShade:Hide()
            row.cooldown:Hide()
        end
        if spell.maxCharges and spell.maxCharges > 1 and spell.charges and spell.charges > 0 then
            row.charges:SetText(tostring(spell.charges))
            row.charges:Show()
        else
            row.charges:SetText("")
            row.charges:Hide()
        end
        local baseCooldownText = showCooldownDuration and not spell.onCooldown and U.CompactCooldownText(spell.baseCooldown or 0) or ""
        if baseCooldownText ~= "" then
            row.baseCooldownText:SetText(baseCooldownText)
            row.baseCooldownText:Show()
        else
            row.baseCooldownText:SetText("")
            row.baseCooldownText:Hide()
        end
        row.title:SetText(spell.name)
        if spell.onCooldown then
            row.title:SetTextColor(0.58, 0.58, 0.58)
        else
            row.title:SetTextColor(1, 0.82, 0.24)
        end
        row.title:SetShown(showTitle)
        row:Show()
    end

    for index = count + 1, #UI.alertRows do
        UI.alertRows[index].spellID = nil
        UI.alertRows[index].cooldownActive = false
        UI.alertRows[index].readyPulseUntil = nil
        if UI.alertRows[index].charges then
            UI.alertRows[index].charges:Hide()
        end
        if UI.alertRows[index].baseCooldownText then
            UI.alertRows[index].baseCooldownText:Hide()
        end
        if UI.alertRows[index].icon then
            if UI.alertRows[index].icon.SetDesaturated then
                UI.alertRows[index].icon:SetDesaturated(false)
            end
            UI.alertRows[index].icon:SetVertexColor(1, 1, 1, 1)
        end
        if UI.alertRows[index].cooldown then
            UI.alertRows[index].cooldown:Hide()
        end
        if UI.alertRows[index].cooldownShade then
            UI.alertRows[index].cooldownShade:Hide()
        end
        UI.alertRows[index]:Hide()
    end

    UI.reminder.resize:SetShown(count > 0 and showTitle)
    UI.reminder:SetShown(count > 0)
end

function CDR:PlaySelectedSound(force)
    if not force and self.db.monitoringEnabled == false then
        return
    end
    if not force and not self.db.sound.enabled then
        return
    end

    local option = U.GetSoundOption(self.db.sound.id)
    local soundID
    if SOUNDKIT and option.soundKit then
        soundID = SOUNDKIT[option.soundKit]
    end
    soundID = soundID or option.fallback

    if soundID then
        PlaySound(soundID, "Master")
    end
end

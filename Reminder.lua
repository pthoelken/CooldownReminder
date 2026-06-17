local CDR = CooldownReminder
local UI = CDR.UI
local U = CDR.Utils
local CONST = CDR.CONST

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

    local charges = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
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
    for spellID in pairs(self.readySpells or {}) do
        local saved = self.db.spells[spellID]
        if saved then
            local onCooldown = self:GetWatchedCooldownStatus(spellID)
            if onCooldown then
                self.readySpells[spellID] = nil
            else
                local charges, maxCharges = self:GetWatchedChargeDisplay(spellID)
                table.insert(ready, {
                    id = spellID,
                    name = saved.name or ("Spell " .. spellID),
                    icon = saved.icon or U.GetSpellTextureCompat(spellID) or 134400,
                    charges = charges,
                    maxCharges = maxCharges,
                })
            end
        elseif self.testReadySpell and self.testReadySpell.id == spellID then
            table.insert(ready, {
                id = spellID,
                name = self.testReadySpell.name,
                icon = self.testReadySpell.icon,
            })
        else
            self.readySpells[spellID] = nil
        end
    end

    table.sort(ready, function(a, b)
        local aIndex = CDR:GetWatchedOrderIndex(a.id) or 9999
        local bIndex = CDR:GetWatchedOrderIndex(b.id) or 9999
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
    local ready = self:GetReadyList()
    local count = #ready
    local showTitle = self.db.reminder.showTitle
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

    for index, spell in ipairs(ready) do
        local row = UI.alertRows[index] or self:CreateReminderRow(index)
        row.spellID = spell.id
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
        if spell.maxCharges and spell.maxCharges > 1 and spell.charges then
            row.charges:SetText(tostring(spell.charges))
            row.charges:Show()
        else
            row.charges:SetText("")
            row.charges:Hide()
        end
        row.title:SetText(spell.name)
        row.title:SetShown(showTitle)
        row:Show()
    end

    for index = count + 1, #UI.alertRows do
        UI.alertRows[index].spellID = nil
        if UI.alertRows[index].charges then
            UI.alertRows[index].charges:Hide()
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

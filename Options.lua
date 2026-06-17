local CDR = CooldownReminder
local UI = CDR.UI
local U = CDR.Utils
local CONST = CDR.CONST

local function L(key)
    return CDR:L(key)
end

function CDR:CreateTab(parent, id, text)
    local tabName = "CooldownReminderConfigFrameTab" .. id
    local tab = CreateFrame("Button", tabName, parent, BackdropTemplateMixin and "BackdropTemplate")
    tab:SetID(id)
    tab:SetSize(id == 1 and 88 or 118, 28)
    tab:SetFrameLevel(parent:GetFrameLevel() + 2)
    tab:RegisterForClicks("LeftButtonUp")
    U.CreateBackdrop(tab, 0.9)

    local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 0)
    tab.label = label
    function tab:SetText(value)
        self.label:SetText(value)
    end
    tab:SetText(text)

    local topLine = tab:CreateTexture(nil, "OVERLAY")
    topLine:SetPoint("TOPLEFT", 3, -1)
    topLine:SetPoint("TOPRIGHT", -3, -1)
    topLine:SetHeight(2)
    U.SetTextureColor(topLine, 1, 0.8, 0.22, 0.82)
    tab.topLine = topLine

    local selectedFill = tab:CreateTexture(nil, "ARTWORK")
    selectedFill:SetPoint("TOPLEFT", 2, -2)
    selectedFill:SetPoint("BOTTOMRIGHT", -2, 2)
    U.SetTextureColor(selectedFill, 0.22, 0.16, 0.04, 0.62)
    tab.selectedFill = selectedFill

    tab:SetScript("OnClick", function(button)
        CDR:SetActiveTab(button:GetID())
    end)
    tab:SetScript("OnEnter", function(button)
        if not button.selected then
            if button.SetBackdropBorderColor then
                button:SetBackdropBorderColor(0.62, 0.5, 0.2, 0.95)
            end
            button.label:SetTextColor(1, 0.86, 0.36)
        end
    end)
    tab:SetScript("OnLeave", function()
        CDR:RefreshTabStyles()
    end)

    return tab
end

function CDR:SetTabStyle(tab, selected)
    tab.selected = selected
    if selected then
        tab:SetFrameLevel(UI.config:GetFrameLevel() + 5)
        if tab.SetBackdropColor then
            tab:SetBackdropColor(0.08, 0.06, 0.025, 0.98)
            tab:SetBackdropBorderColor(1, 0.78, 0.22, 1)
        end
        tab.label:SetTextColor(1, 0.86, 0.28)
        tab.topLine:SetAlpha(1)
        tab.selectedFill:SetAlpha(1)
    else
        tab:SetFrameLevel(UI.config:GetFrameLevel() + 2)
        if tab.SetBackdropColor then
            tab:SetBackdropColor(0.012, 0.012, 0.014, 0.96)
            tab:SetBackdropBorderColor(0.26, 0.25, 0.22, 0.95)
        end
        tab.label:SetTextColor(0.84, 0.8, 0.72)
        tab.topLine:SetAlpha(0)
        tab.selectedFill:SetAlpha(0)
    end
end

function CDR:RefreshTabStyles()
    if UI.spellsTab and UI.settingsTab then
        self:SetTabStyle(UI.spellsTab, self.activeTab == 1)
        self:SetTabStyle(UI.settingsTab, self.activeTab == 2)
    end
end

function CDR:SetActiveTab(tabID)
    self.activeTab = tabID
    UI.spellsPanel:SetShown(tabID == 1)
    UI.settingsPanel:SetShown(tabID == 2)
    self:RefreshTabStyles()
end

function CDR:CreateSpellsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    UI.spellsPanel = panel
    panel:SetPoint("TOPLEFT", 28, -54)
    panel:SetPoint("BOTTOMRIGHT", -28, 46)
    panel:SetScript("OnMouseUp", function()
        CDR:FinishWatchedDrag()
    end)

    local intro = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", 0, 0)
    intro:SetPoint("RIGHT", 0, 0)
    intro:SetJustifyH("LEFT")
    UI.spellsIntro = intro

    local searchLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -18)
    UI.searchLabel = searchLabel

    local search = CreateFrame("EditBox", "CooldownReminderSearchBox", panel, "InputBoxTemplate")
    UI.searchBox = search
    search:SetHeight(24)
    search:SetPoint("TOPLEFT", searchLabel, "TOPRIGHT", 12, -4)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function()
        if UI.spellGridScrollFrame and FauxScrollFrame_SetOffset then
            FauxScrollFrame_SetOffset(UI.spellGridScrollFrame, 0)
            if UI.spellGridScrollFrame.ScrollBar then
                UI.spellGridScrollFrame.ScrollBar:SetValue(0)
            end
        end
        CDR:RefreshConfig()
    end)
    search:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)

    local refresh = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    UI.refreshButton = refresh
    refresh:SetSize(116, 24)
    refresh:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -22, -34)
    search:SetPoint("TOPRIGHT", refresh, "TOPLEFT", -16, 0)
    refresh:SetScript("OnClick", function()
        CDR:BuildPlayerSpellList()
        CDR:RefreshConfig()
    end)
    refresh:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("REFRESH"), 1, 0.82, 0.2)
        GameTooltip:AddLine(L("REFRESH_TOOLTIP"), 0.78, 0.78, 0.72, true)
        GameTooltip:Show()
    end)
    refresh:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local searchResultsTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchResultsTitle:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -24)
    UI.searchResultsTitle = searchResultsTitle

    local gridScroll = CreateFrame("ScrollFrame", "CooldownReminderSpellGridScrollFrame", panel, "FauxScrollFrameTemplate")
    UI.spellGridScrollFrame = gridScroll
    gridScroll:SetPoint("TOPLEFT", searchResultsTitle, "BOTTOMLEFT", 0, -10)
    gridScroll:SetPoint("RIGHT", panel, "RIGHT", -26, 0)
    gridScroll:SetHeight((CONST.SPELL_GRID_ICON_SIZE + CONST.SPELL_GRID_ICON_SPACING) * CONST.SPELL_GRID_ROWS - CONST.SPELL_GRID_ICON_SPACING)
    gridScroll:SetScript("OnVerticalScroll", function(scroll, offset)
        FauxScrollFrame_OnVerticalScroll(scroll, offset, CONST.SPELL_GRID_ICON_SIZE + CONST.SPELL_GRID_ICON_SPACING, function()
            CDR:RefreshConfig()
        end)
    end)

    UI.spellGridButtons = {}
    local iconStride = CONST.SPELL_GRID_ICON_SIZE + CONST.SPELL_GRID_ICON_SPACING
    local totalButtons = CONST.SPELL_GRID_COLUMNS * CONST.SPELL_GRID_ROWS
    for index = 1, totalButtons do
        local button = CreateFrame("Button", nil, panel, BackdropTemplateMixin and "BackdropTemplate")
        U.CreateBackdrop(button, 0.34)
        button:SetSize(CONST.SPELL_GRID_ICON_SIZE, CONST.SPELL_GRID_ICON_SIZE)

        local column = (index - 1) % CONST.SPELL_GRID_COLUMNS
        local row = math.floor((index - 1) / CONST.SPELL_GRID_COLUMNS)
        button:SetPoint("TOPLEFT", gridScroll, "TOPLEFT", column * iconStride, -(row * iconStride))
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button:SetScript("OnClick", function(clickedButton)
            if clickedButton.spell then
                CDR:AddWatchedSpell(clickedButton.spell.id)
                UI.searchBox:SetText("")
                UI.searchBox:ClearFocus()
            end
        end)
        button:SetScript("OnEnter", function(hoveredButton)
            if hoveredButton.SetBackdropBorderColor then
                hoveredButton:SetBackdropBorderColor(1, 0.78, 0.22, 1)
            end
            CDR:ShowSpellGridTooltip(hoveredButton)
        end)
        button:SetScript("OnLeave", function(hoveredButton)
            if hoveredButton.SetBackdropBorderColor then
                hoveredButton:SetBackdropBorderColor(0.28, 0.26, 0.22, 0.85)
            end
            GameTooltip:Hide()
        end)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        button.icon = icon

        UI.spellGridButtons[index] = button
    end

    local searchEmpty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchEmpty:SetPoint("TOPLEFT", gridScroll, "TOPLEFT", 0, -2)
    searchEmpty:SetPoint("RIGHT", -22, 0)
    searchEmpty:SetJustifyH("LEFT")
    UI.searchEmpty = searchEmpty

    local watchedTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    watchedTitle:SetPoint("TOPLEFT", gridScroll, "BOTTOMLEFT", 0, -22)
    UI.watchedTitle = watchedTitle

    local watchedHint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    watchedHint:SetPoint("TOPLEFT", watchedTitle, "BOTTOMLEFT", 0, -6)
    watchedHint:SetPoint("RIGHT", -22, 0)
    watchedHint:SetJustifyH("LEFT")
    UI.watchedHint = watchedHint

    local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", watchedHint, "BOTTOMLEFT", 0, -12)
    empty:SetPoint("RIGHT", 0, 0)
    empty:SetJustifyH("LEFT")
    UI.emptyWatched = empty

    local watchedScroll = CreateFrame("ScrollFrame", "CooldownReminderWatchedScrollFrame", panel, "FauxScrollFrameTemplate")
    UI.watchedScrollFrame = watchedScroll
    watchedScroll:SetPoint("TOPLEFT", watchedHint, "BOTTOMLEFT", 0, -10)
    watchedScroll:SetPoint("RIGHT", panel, "RIGHT", -26, 0)
    watchedScroll:SetHeight((CONST.WATCHED_ROW_HEIGHT + 6) * CONST.WATCHED_ROWS - 6)
    watchedScroll:SetScript("OnVerticalScroll", function(scroll, offset)
        FauxScrollFrame_OnVerticalScroll(scroll, offset, CONST.WATCHED_ROW_HEIGHT + 6, function()
            CDR:RefreshConfig()
        end)
    end)

    UI.watchedRows = {}
    for index = 1, CONST.WATCHED_ROWS do
        local row = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate")
        U.CreateBackdrop(row, 0.42)
        row:SetHeight(CONST.WATCHED_ROW_HEIGHT)
        row:EnableMouse(true)
        row:SetPoint("LEFT", watchedScroll, "LEFT", 0, 0)
        row:SetPoint("RIGHT", watchedScroll, "RIGHT", -2, 0)
        if index == 1 then
            row:SetPoint("TOP", watchedScroll, "TOP", 0, 0)
        else
            row:SetPoint("TOP", UI.watchedRows[index - 1], "BOTTOM", 0, -6)
        end

        local handle = CreateFrame("Frame", nil, row)
        handle:SetSize(14, 26)
        handle:SetPoint("LEFT", 6, 0)
        row.dragHandle = handle

        for dotIndex = 1, 6 do
            local dot = handle:CreateTexture(nil, "OVERLAY")
            dot:SetSize(2, 2)
            local column = (dotIndex - 1) % 2
            local gripRow = math.floor((dotIndex - 1) / 2)
            dot:SetPoint("TOPLEFT", handle, "TOPLEFT", column * 6, -(4 + gripRow * 7))
            U.SetTextureColor(dot, 0.8, 0.72, 0.48, 0.72)
        end

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(26, 26)
        icon:SetPoint("LEFT", handle, "RIGHT", 6, 0)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.icon = icon

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("LEFT", icon, "RIGHT", 9, 0)
        name:SetPoint("RIGHT", -154, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        row.name = name

        local status = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        status:SetPoint("RIGHT", -90, 0)
        status:SetWidth(72)
        status:SetJustifyH("RIGHT")
        row.status = status

        local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        remove:SetSize(74, 22)
        remove:SetPoint("RIGHT", -5, 0)
        remove:SetScript("OnClick", function(button)
            if button:GetParent().spellID then
                CDR:RemoveWatchedSpell(button:GetParent().spellID)
            end
        end)
        row.remove = remove

        row:SetScript("OnEnter", function(frame)
            if frame.SetBackdropBorderColor then
                frame:SetBackdropBorderColor(0.55, 0.48, 0.28, 0.9)
            end
            if frame.spellID then
                CDR:DragWatchedOver(frame.spellID)
            end
        end)
        row:SetScript("OnLeave", function(frame)
            if frame.SetBackdropBorderColor then
                frame:SetBackdropBorderColor(0.28, 0.26, 0.22, 0.85)
            end
        end)
        row:SetScript("OnMouseDown", function(frame, button)
            if button == "LeftButton" and frame.spellID then
                CDR:StartWatchedDrag(frame.spellID)
                frame:SetAlpha(0.72)
            end
        end)
        row:SetScript("OnMouseUp", function()
            CDR:FinishWatchedDrag()
        end)

        UI.watchedRows[index] = row
    end
end

function CDR:CreateSettingsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    UI.settingsPanel = panel
    panel:SetPoint("TOPLEFT", 34, -62)
    panel:SetPoint("BOTTOMRIGHT", -34, 58)

    local labelX = 28
    local controlX = 164
    local rightColumnX = 292
    local leftCheckboxLabelWidth = 220
    local rightCheckboxLabelWidth = 230

    local monitoringCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    UI.monitoringCheck = monitoringCheck
    monitoringCheck:SetPoint("TOPLEFT", 22, -18)
    monitoringCheck:SetScript("OnClick", function(button)
        CDR:SetMonitoringEnabled(button:GetChecked())
    end)

    local monitoringLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    monitoringLabel:SetPoint("LEFT", monitoringCheck, "RIGHT", 3, 0)
    monitoringLabel:SetWidth(leftCheckboxLabelWidth)
    monitoringLabel:SetJustifyH("LEFT")
    monitoringLabel:SetWordWrap(false)
    UI.monitoringLabel = monitoringLabel

    local titleCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    UI.showTitleCheck = titleCheck
    titleCheck:SetPoint("TOPLEFT", monitoringCheck, "BOTTOMLEFT", 0, -14)
    titleCheck:SetScript("OnClick", function(button)
        CDR.db.reminder.showTitle = button:GetChecked()
        CDR:RefreshReminderAlerts()
    end)

    local titleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleLabel:SetPoint("LEFT", titleCheck, "RIGHT", 3, 0)
    titleLabel:SetWidth(leftCheckboxLabelWidth)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetWordWrap(false)
    UI.showTitleLabel = titleLabel

    local soundCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    UI.soundCheck = soundCheck
    soundCheck:SetPoint("TOPLEFT", titleCheck, "BOTTOMLEFT", 0, -14)
    soundCheck:SetScript("OnClick", function(button)
        CDR.db.sound.enabled = button:GetChecked()
    end)

    local soundLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    soundLabel:SetPoint("LEFT", soundCheck, "RIGHT", 3, 0)
    soundLabel:SetWidth(leftCheckboxLabelWidth)
    soundLabel:SetJustifyH("LEFT")
    soundLabel:SetWordWrap(false)
    UI.soundLabel = soundLabel

    local topMostCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    UI.topMostCheck = topMostCheck
    topMostCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", rightColumnX, -18)
    topMostCheck:SetScript("OnClick", function(button)
        CDR:SetReminderTopMost(button:GetChecked())
    end)

    local topMostLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    topMostLabel:SetPoint("LEFT", topMostCheck, "RIGHT", 3, 0)
    topMostLabel:SetWidth(rightCheckboxLabelWidth)
    topMostLabel:SetJustifyH("LEFT")
    topMostLabel:SetWordWrap(false)
    UI.topMostLabel = topMostLabel

    local loadMessageCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    UI.loadMessageCheck = loadMessageCheck
    loadMessageCheck:SetPoint("TOPLEFT", topMostCheck, "BOTTOMLEFT", 0, -14)
    loadMessageCheck:SetScript("OnClick", function(button)
        CDR.db.ui.showLoadMessage = button:GetChecked()
    end)

    local loadMessageLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    loadMessageLabel:SetPoint("LEFT", loadMessageCheck, "RIGHT", 3, 0)
    loadMessageLabel:SetWidth(rightCheckboxLabelWidth)
    loadMessageLabel:SetJustifyH("LEFT")
    loadMessageLabel:SetWordWrap(false)
    UI.loadMessageLabel = loadMessageLabel

    local soundDropdownLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    soundDropdownLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", labelX, -146)
    soundDropdownLabel:SetWidth(controlX - 12)
    soundDropdownLabel:SetJustifyH("LEFT")
    UI.soundDropdownLabel = soundDropdownLabel

    local soundDropdown = CreateFrame("Frame", "CooldownReminderSoundDropdown", panel, "UIDropDownMenuTemplate")
    UI.soundDropdown = soundDropdown
    soundDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", controlX - 22, -142)
    UIDropDownMenu_SetWidth(soundDropdown, 200)
    UIDropDownMenu_Initialize(soundDropdown, function(_, level)
        CDR:PopulateSoundDropdown(level)
    end)

    local soundTest = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    UI.soundTestButton = soundTest
    soundTest:SetSize(118, 24)
    soundTest:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -28, -142)
    soundTest:SetScript("OnClick", function()
        CDR:PlaySelectedSound(true)
    end)

    local languageLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    languageLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", labelX, -190)
    languageLabel:SetWidth(controlX - 12)
    languageLabel:SetJustifyH("LEFT")
    UI.languageLabel = languageLabel

    local languageDropdown = CreateFrame("Frame", "CooldownReminderLanguageDropdown", panel, "UIDropDownMenuTemplate")
    UI.languageDropdown = languageDropdown
    languageDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", controlX - 22, -186)
    UIDropDownMenu_SetWidth(languageDropdown, 200)
    UIDropDownMenu_Initialize(languageDropdown, function(_, level)
        CDR:PopulateLanguageDropdown(level)
    end)

    local layoutLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    layoutLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", labelX, -234)
    layoutLabel:SetWidth(controlX - 12)
    layoutLabel:SetJustifyH("LEFT")
    UI.layoutDropdownLabel = layoutLabel

    local layoutDropdown = CreateFrame("Frame", "CooldownReminderLayoutDropdown", panel, "UIDropDownMenuTemplate")
    UI.layoutDropdown = layoutDropdown
    layoutDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", controlX - 22, -230)
    UIDropDownMenu_SetWidth(layoutDropdown, 200)
    UIDropDownMenu_Initialize(layoutDropdown, function(_, level)
        CDR:PopulateLayoutDropdown(level)
    end)

    local slider = CreateFrame("Slider", "CooldownReminderScaleSlider", panel, "OptionsSliderTemplate")
    UI.scaleSlider = slider
    slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 54, -294)
    slider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -54, -294)
    slider:SetMinMaxValues(0.6, 2)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetScript("OnValueChanged", function(_, value)
        CDR:SetReminderScale(value)
    end)

    local actionBar = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate")
    UI.actionBar = actionBar
    actionBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 22, 10)
    actionBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 10)
    actionBar:SetHeight(54)
    U.CreateBackdrop(actionBar, 0.22)

    local reset = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    UI.resetButton = reset
    reset:SetSize(174, 24)
    reset:SetPoint("LEFT", actionBar, "LEFT", 18, 0)
    reset:SetScript("OnClick", function()
        CDR:ResetReminderLayout()
    end)

    local test = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    UI.testButton = test
    test:SetSize(146, 24)
    test:SetPoint("LEFT", reset, "RIGHT", 12, 0)
    test:SetScript("OnClick", function()
        CDR:TestReminder()
    end)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", actionBar, "TOPLEFT", 0, 10)
    hint:SetPoint("RIGHT", actionBar, "RIGHT", 0, 0)
    hint:SetJustifyH("LEFT")
    UI.settingsHint = hint
end

function CDR:CreateConfigWindow()
    local frame = CreateFrame("Frame", "CooldownReminderConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    UI.config = frame

    frame:SetSize(640, 540)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(config)
        config:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(config)
        config:StopMovingOrSizing()
    end)
    frame:SetScript("OnMouseUp", function()
        CDR:FinishWatchedDrag()
    end)
    frame:SetScript("OnHide", function()
        CDR:FinishWatchedDrag()
    end)
    frame:Hide()

    if frame.TitleText then
        frame.TitleText:ClearAllPoints()
        frame.TitleText:SetPoint("TOP", frame, "TOP", 0, -6)
        frame.TitleText:SetJustifyH("CENTER")
        frame.TitleText:SetText("CooldownReminder")
    else
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", frame, "TOP", 0, -6)
        title:SetJustifyH("CENTER")
        title:SetText("CooldownReminder")
        UI.configTitle = title
    end

    local tab1 = self:CreateTab(frame, 1, "")
    UI.spellsTab = tab1
    tab1:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 28, 4)

    local tab2 = self:CreateTab(frame, 2, "")
    UI.settingsTab = tab2
    tab2:SetPoint("LEFT", tab1, "RIGHT", 2, 0)

    self:CreateSpellsPanel(frame)
    self:CreateSettingsPanel(frame)
    self:SetActiveTab(1)
    self:RefreshConfigTexts()
    self:RefreshConfig()
end

function CDR:RegisterSettingsCategory()
    if self.settingsCategory or not Settings or not Settings.RegisterCanvasLayoutCategory then
        return
    end

    local panel = CreateFrame("Frame", "CooldownReminderBlizzardSettingsPanel")
    panel.name = "CooldownReminder"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 24, -24)
    title:SetText("CooldownReminder")

    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    text:SetPoint("RIGHT", panel, "RIGHT", -32, 0)
    text:SetJustifyH("LEFT")
    text:SetText(L("BLIZZ_OPTIONS_HINT"))
    panel.hintText = text

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(180, 24)
    open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -18)
    open:SetText(L("OPEN_CDR_OPTIONS"))
    open:SetScript("OnClick", function()
        CDR:ToggleConfig()
    end)
    panel.openButton = open

    panel.refresh = function(settingsPanel)
        settingsPanel.hintText:SetText(CDR:L("BLIZZ_OPTIONS_HINT"))
        settingsPanel.openButton:SetText(CDR:L("OPEN_CDR_OPTIONS"))
    end

    local category = Settings.RegisterCanvasLayoutCategory(panel, "CooldownReminder")
    if Settings.RegisterAddOnCategory then
        Settings.RegisterAddOnCategory(category)
    end
    self.settingsCategory = category
end

function CDR:RefreshConfigTexts()
    if not UI.config then
        return
    end

    if UI.config.TitleText then
        UI.config.TitleText:SetText("CooldownReminder")
    elseif UI.configTitle then
        UI.configTitle:SetText("CooldownReminder")
    end

    UI.spellsTab:SetText(L("TAB_SPELLS"))
    UI.settingsTab:SetText(L("TAB_SETTINGS"))
    self:RefreshTabStyles()
    UI.spellsIntro:SetText(L("SPELLS_INTRO"))
    UI.searchLabel:SetText(L("SEARCH"))
    UI.refreshButton:SetText(L("REFRESH"))
    UI.searchResultsTitle:SetText(L("SEARCH_RESULTS"))
    UI.searchEmpty:SetText(L("SEARCH_HINT"))
    UI.watchedTitle:SetText(L("WATCHED_SPELLS"))
    UI.watchedHint:SetText(L("WATCHED_HINT"))
    UI.emptyWatched:SetText(L("EMPTY_WATCHED"))
    UI.monitoringLabel:SetText(L("ENABLE_MONITORING"))
    UI.showTitleLabel:SetText(L("SHOW_TITLE"))
    UI.soundLabel:SetText(L("ENABLE_SOUND"))
    UI.topMostLabel:SetText(L("REMINDER_TOPMOST"))
    UI.loadMessageLabel:SetText(L("SHOW_LOAD_MESSAGE"))
    UI.soundDropdownLabel:SetText(L("SOUND"))
    UI.soundTestButton:SetText(L("TEST_SOUND"))
    UI.languageLabel:SetText(L("LANGUAGE"))
    UI.layoutDropdownLabel:SetText(L("REMINDER_LAYOUT"))
    UI.resetButton:SetText(L("RESET_POSITION"))
    UI.testButton:SetText(L("TEST_REMINDER"))
    UI.settingsHint:SetText(L("SETTINGS_HINT"))

    local sliderName = UI.scaleSlider:GetName()
    if _G[sliderName .. "Low"] then
        _G[sliderName .. "Low"]:SetText("60%")
    end
    if _G[sliderName .. "High"] then
        _G[sliderName .. "High"]:SetText("200%")
    end
    if _G[sliderName .. "Text"] then
        _G[sliderName .. "Text"]:SetText(L("REMINDER_SCALE"))
    end

    for _, row in ipairs(UI.watchedRows or {}) do
        row.remove:SetText(L("REMOVE"))
    end

    if UI.soundDropdown then
        UIDropDownMenu_SetText(UI.soundDropdown, U.GetSoundLabel(self.db.sound.id))
    end
    if UI.languageDropdown then
        UIDropDownMenu_SetText(UI.languageDropdown, U.GetLanguageLabel(self.db.language))
    end
    if UI.layoutDropdown then
        UIDropDownMenu_SetText(UI.layoutDropdown, U.GetReminderLayoutLabel(self.db.reminder.layout))
    end
    if _G.CooldownReminderBlizzardSettingsPanel and _G.CooldownReminderBlizzardSettingsPanel.refresh then
        _G.CooldownReminderBlizzardSettingsPanel.refresh(_G.CooldownReminderBlizzardSettingsPanel)
    end
end

function CDR:GetSpellCooldownText(spell)
    local longestCooldown = tonumber(spell.forcedCooldown or 0) or 0
    local hasCharges = false

    for _, spellID in ipairs(spell.aliases or { spell.id }) do
        local baseCooldown = U.GetSpellBaseCooldownCompat(spellID)
        if baseCooldown and baseCooldown > longestCooldown then
            longestCooldown = baseCooldown
        end

        local _, maxCharges = U.GetSpellChargesCompat(spellID)
        if U.IsGreaterThan(maxCharges, 1) then
            hasCharges = true
        end
    end

    for _, slot in ipairs(spell.actionSlots or {}) do
        if GetActionCooldown then
            local _, duration = GetActionCooldown(slot)
            if U.IsGreaterThan(duration, longestCooldown) then
                longestCooldown = duration
            end
        end

        if GetActionCharges then
            local maxCharges = select(2, GetActionCharges(slot))
            if U.IsGreaterThan(maxCharges, 1) then
                hasCharges = true
            end
        end
    end

    if longestCooldown > CONST.GCD_IGNORE_SECONDS then
        return U.SecondsText(longestCooldown)
    end
    if hasCharges then
        return L("CHARGES")
    end
    return ""
end

function CDR:ShowSpellGridTooltip(button)
    if not button or not button.spell then
        return
    end

    local spell = button.spell
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")

    local usedSpellTooltip = false
    if GameTooltip.SetSpellByID then
        usedSpellTooltip = pcall(GameTooltip.SetSpellByID, GameTooltip, spell.id)
    end

    if not usedSpellTooltip then
        GameTooltip:SetText(spell.name, 1, 1, 1)
    end

    local cooldownText = self:GetSpellCooldownText(spell)
    if cooldownText and cooldownText ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("COOLDOWN") .. ": " .. cooldownText, 1, 0.82, 0.2)
    end
    GameTooltip:AddLine(L("CLICK_TO_MONITOR"), 0.72, 0.72, 0.66, true)
    GameTooltip:Show()
end

function CDR:RefreshSearchResults()
    if not UI.spellGridButtons then
        return
    end

    local results = self:GetAvailableSpells()
    local columns = CONST.SPELL_GRID_COLUMNS
    local visibleRows = CONST.SPELL_GRID_ROWS
    local rowHeight = CONST.SPELL_GRID_ICON_SIZE + CONST.SPELL_GRID_ICON_SPACING
    local totalRows = math.ceil(#results / columns)
    local rowOffset = 0

    if UI.spellGridScrollFrame then
        FauxScrollFrame_Update(UI.spellGridScrollFrame, totalRows, visibleRows, rowHeight)
        rowOffset = FauxScrollFrame_GetOffset(UI.spellGridScrollFrame)
    end

    if #results == 0 then
        UI.searchEmpty:SetText(L("NO_COOLDOWN_SPELLS"))
        UI.searchEmpty:Show()
    else
        UI.searchEmpty:Hide()
    end

    for index, button in ipairs(UI.spellGridButtons) do
        local spell = results[(rowOffset * columns) + index]
        if spell then
            button.spell = spell
            button.icon:SetTexture(spell.icon)
            button:Show()
        else
            button.spell = nil
            button:Hide()
        end
    end
end

function CDR:PopulateSoundDropdown(level)
    if level ~= 1 then
        return
    end

    for _, option in ipairs(CDR.SOUND_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = U.GetSoundLabel(option.id)
        info.checked = self.db.sound.id == option.id
        info.arg1 = option.id
        info.func = function(_, arg1)
            CDR.db.sound.id = arg1
            UIDropDownMenu_SetText(UI.soundDropdown, U.GetSoundLabel(arg1))
            CDR:PlaySelectedSound(true)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

function CDR:PopulateLanguageDropdown(level)
    if level ~= 1 then
        return
    end

    for _, option in ipairs(CDR.LANGUAGE_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = U.GetLanguageLabel(option.id)
        info.checked = self.db.language == option.id
        info.arg1 = option.id
        info.func = function(_, arg1)
            CDR.db.language = arg1
            CDR:ApplyLocale()
            CDR:RefreshConfigTexts()
            CDR:RefreshConfig()
            CDR:RefreshReminderAlerts()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

function CDR:PopulateLayoutDropdown(level)
    if level ~= 1 then
        return
    end

    for _, option in ipairs(CDR.REMINDER_LAYOUT_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = U.GetReminderLayoutLabel(option.id)
        info.checked = self.db.reminder.layout == option.id
        info.arg1 = option.id
        info.func = function(_, arg1)
            CDR:SetReminderLayout(arg1)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

function CDR:RefreshConfig()
    if not UI.config then
        return
    end

    self:RefreshSearchResults()

    local watched = self:GetWatchedList()
    local offset = 0
    if UI.watchedScrollFrame then
        FauxScrollFrame_Update(UI.watchedScrollFrame, #watched, CONST.WATCHED_ROWS, CONST.WATCHED_ROW_HEIGHT + 6)
        offset = FauxScrollFrame_GetOffset(UI.watchedScrollFrame)
    end

    UI.emptyWatched:SetShown(#watched == 0)

    for index = 1, CONST.WATCHED_ROWS do
        local row = UI.watchedRows[index]
        local spell = watched[offset + index]
        if spell then
            local onCooldown, remaining = self:GetWatchedCooldownStatus(spell.id)
            row.spellID = spell.id
            row.icon:SetTexture(spell.icon)
            row.name:SetText(spell.name)
            if onCooldown then
                row.status:SetText(U.SecondsText(remaining))
                row.status:SetTextColor(0.78, 0.72, 0.62)
            else
                row.status:SetText(L("READY"))
                row.status:SetTextColor(0.45, 1, 0.48)
            end
            row.remove:SetText(L("REMOVE"))
            row:SetAlpha(self.draggedWatchedSpellID == spell.id and 0.72 or 1)
            row:Show()
        else
            row.spellID = nil
            row:SetAlpha(1)
            row:Hide()
        end
    end

    if UI.showTitleCheck then
        UI.showTitleCheck:SetChecked(self.db.reminder.showTitle)
    end
    if UI.monitoringCheck then
        UI.monitoringCheck:SetChecked(self.db.monitoringEnabled ~= false)
    end
    if UI.soundCheck then
        UI.soundCheck:SetChecked(self.db.sound.enabled)
    end
    if UI.topMostCheck then
        UI.topMostCheck:SetChecked(self.db.reminder.topMost == true)
    end
    if UI.loadMessageCheck then
        UI.loadMessageCheck:SetChecked(self.db.ui.showLoadMessage)
    end
    if UI.scaleSlider then
        UI.scaleSlider:SetValue(self.db.reminder.scale or 1)
    end
    if UI.soundDropdown then
        UIDropDownMenu_SetText(UI.soundDropdown, U.GetSoundLabel(self.db.sound.id))
    end
    if UI.languageDropdown then
        UIDropDownMenu_SetText(UI.languageDropdown, U.GetLanguageLabel(self.db.language))
    end
    if UI.layoutDropdown then
        UIDropDownMenu_SetText(UI.layoutDropdown, U.GetReminderLayoutLabel(self.db.reminder.layout))
    end
end

function CDR:ToggleConfig()
    if not UI.config then
        return
    end

    if UI.config:IsShown() then
        UI.config:Hide()
    else
        self:BuildPlayerSpellList()
        self:RefreshConfigTexts()
        self:RefreshConfig()
        UI.config:Show()
    end
end

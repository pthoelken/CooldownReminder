local CDR = CooldownReminder
local UI = CDR.UI
local U = CDR.Utils
local CONST = CDR.CONST

local function L(key)
    return CDR:L(key)
end

local ACE_OPTIONS_NAME = "CooldownReminder"

local function GetAceLibrary(name)
    if type(LibStub) ~= "table" or type(LibStub.GetLibrary) ~= "function" then
        return nil
    end

    local ok, library = pcall(LibStub.GetLibrary, LibStub, name, true)
    if ok then
        return library
    end
end

local function BuildSoundValues()
    local values = {}
    for _, option in ipairs(CDR.SOUND_OPTIONS) do
        values[option.id] = U.GetSoundLabel(option.id)
    end
    return values
end

local function BuildLanguageValues()
    local values = {}
    for _, option in ipairs(CDR.LANGUAGE_OPTIONS) do
        values[option.id] = U.GetLanguageLabel(option.id)
    end
    return values
end

local function BuildLayoutValues()
    local values = {}
    for _, option in ipairs(CDR.REMINDER_LAYOUT_OPTIONS) do
        values[option.id] = U.GetReminderLayoutLabel(option.id)
    end
    return values
end

local function BuildModeValues()
    local values = {}
    for _, option in ipairs(CDR.REMINDER_MODE_OPTIONS) do
        values[option.id] = U.GetReminderModeLabel(option.id)
    end
    return values
end

local function BuildExpertTimingAceArgs()
    local args = {
        warning = {
            type = "description",
            name = function()
                return CDR:L("EXPERT_WARNING")
            end,
            fontSize = "medium",
            width = "full",
            order = 1,
        },
        reset = {
            type = "execute",
            name = function()
                return CDR:L("RESET_TO_DEFAULTS")
            end,
            func = function()
                CDR:ResetExpertTimingSettings()
                CDR:RefreshConfig()
            end,
            order = 2,
        },
    }

    for index, option in ipairs(CDR.EXPERT_TIMING_OPTIONS) do
        local key = option.key
        local labelKey = option.labelKey
        local descKey = option.descKey
        args[key] = {
            type = "range",
            name = function()
                return CDR:L(labelKey)
            end,
            desc = function()
                return CDR:L(descKey)
            end,
            min = option.min,
            max = option.max,
            step = option.step,
            get = function()
                return CDR.CONST[key]
            end,
            set = function(_, value)
                CDR:SetExpertTimingValue(key, value)
                CDR:RefreshConfig()
            end,
            width = "full",
            order = 10 + index,
        }
    end

    return args
end

local function CreateSectionDivider(parent, anchor)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    divider:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    divider:SetHeight(1)
    U.SetTextureColor(divider, 0.43, 0.38, 0.28, 0.72)
    return divider
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

function CDR:CreateCategoryButton(parent, id, labelKey)
    local button = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    button:SetID(id)
    button:SetHeight(34)
    button:SetPoint("LEFT", parent, "LEFT", 8, 0)
    button:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    button:RegisterForClicks("LeftButtonUp")
    button.labelKey = labelKey
    U.CreateBackdrop(button, 0.12)

    local selectedFill = button:CreateTexture(nil, "ARTWORK")
    selectedFill:SetPoint("TOPLEFT", 1, -1)
    selectedFill:SetPoint("BOTTOMRIGHT", -1, 1)
    U.SetTextureColor(selectedFill, 0.16, 0.13, 0.04, 0.76)
    button.selectedFill = selectedFill

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 14, 0)
    label:SetPoint("RIGHT", -10, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    button.label = label

    button:SetScript("OnClick", function(clickedButton)
        CDR:SetActiveTab(clickedButton:GetID())
    end)
    button:SetScript("OnEnter", function(hoveredButton)
        if hoveredButton.SetBackdropBorderColor then
            hoveredButton:SetBackdropBorderColor(0.72, 0.58, 0.18, 0.95)
        end
        hoveredButton.label:SetTextColor(1, 0.86, 0.25)
    end)
    button:SetScript("OnLeave", function()
        CDR:RefreshTabStyles()
    end)

    return button
end

function CDR:CreateCategoryNavigation(parent)
    local nav = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    UI.categoryNav = nav
    nav:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -42)
    nav:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 14, 14)
    nav:SetWidth(242)
    U.CreateBackdrop(nav, 0.72)

    local header = nav:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    UI.categoryHeader = header
    header:SetPoint("TOPLEFT", 22, -22)
    header:SetPoint("RIGHT", -12, 0)
    header:SetJustifyH("LEFT")
    header:SetTextColor(1, 0.95, 0.82)

    UI.categoryButtons = {
        self:CreateCategoryButton(nav, 1, "TAB_SPELLS"),
        self:CreateCategoryButton(nav, 2, "TAB_SETTINGS"),
        self:CreateCategoryButton(nav, 3, "TAB_EXPERT"),
        self:CreateCategoryButton(nav, 4, "TAB_ABOUT"),
    }

    UI.categoryButtons[1]:SetPoint("TOP", header, "BOTTOM", 0, -20)
    for index = 2, #UI.categoryButtons do
        UI.categoryButtons[index]:SetPoint("TOP", UI.categoryButtons[index - 1], "BOTTOM", 0, -2)
    end

    local slider = CreateFrame("Slider", "CooldownReminderScaleSlider", nav, "OptionsSliderTemplate")
    UI.scaleSlider = slider
    slider:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 22, 126)
    slider:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -22, 126)
    slider:SetMinMaxValues(0.6, 2)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetScript("OnValueChanged", function(_, value)
        CDR:SetReminderScale(value)
    end)

    local reset = CreateFrame("Button", nil, nav, "UIPanelButtonTemplate")
    UI.resetButton = reset
    reset:SetSize(196, 24)
    reset:SetPoint("BOTTOM", nav, "BOTTOM", 0, 68)
    reset:SetScript("OnClick", function()
        CDR:ResetReminderLayout()
    end)

    local test = CreateFrame("Button", nil, nav, "UIPanelButtonTemplate")
    UI.testButton = test
    test:SetSize(196, 24)
    test:SetPoint("TOP", reset, "BOTTOM", 0, -16)
    test:SetScript("OnClick", function()
        CDR:TestReminder()
    end)
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
    if UI.categoryButtons then
        for _, button in ipairs(UI.categoryButtons) do
            local selected = self.activeTab == button:GetID()
            button.selected = selected
            if selected then
                if button.SetBackdropColor then
                    button:SetBackdropColor(0.08, 0.07, 0.035, 0.92)
                    button:SetBackdropBorderColor(0.96, 0.73, 0.16, 1)
                end
                button.label:SetTextColor(1, 0.86, 0.24)
                button.selectedFill:SetAlpha(1)
            else
                if button.SetBackdropColor then
                    button:SetBackdropColor(0.015, 0.015, 0.014, 0.34)
                    button:SetBackdropBorderColor(0.24, 0.22, 0.17, 0.78)
                end
                button.label:SetTextColor(0.72, 0.58, 0.2)
                button.selectedFill:SetAlpha(0)
            end
        end
    elseif UI.spellsTab and UI.settingsTab then
        self:SetTabStyle(UI.spellsTab, self.activeTab == 1)
        self:SetTabStyle(UI.settingsTab, self.activeTab == 2)
    end
end

function CDR:SetActiveTab(tabID)
    self.activeTab = tabID
    UI.spellsPanel:SetShown(tabID == 1)
    UI.settingsPanel:SetShown(tabID == 2)
    if UI.expertPanel then
        UI.expertPanel:SetShown(tabID == 3)
    end
    if UI.aboutPanel then
        UI.aboutPanel:SetShown(tabID == 4)
    end
    self:RefreshTabStyles()
end

function CDR:CreateSpellsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    UI.spellsPanel = panel
    panel:SetPoint("TOPLEFT", 284, -64)
    panel:SetPoint("BOTTOMRIGHT", -28, 42)
    panel:SetScript("OnMouseUp", function()
        CDR:FinishWatchedDrag()
    end)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetPoint("RIGHT", 0, 0)
    title:SetJustifyH("LEFT")
    UI.spellsTitle = title

    title:SetTextColor(1, 0.78, 0.12)

    local divider = CreateSectionDivider(panel, title)

    local intro = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -12)
    intro:SetPoint("RIGHT", 0, 0)
    intro:SetJustifyH("LEFT")
    UI.spellsIntro = intro

    local searchLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -16)
    searchLabel:SetSize(58, 24)
    searchLabel:SetJustifyH("LEFT")
    searchLabel:SetJustifyV("MIDDLE")
    UI.searchLabel = searchLabel

    local search = CreateFrame("EditBox", "CooldownReminderSearchBox", panel, "InputBoxTemplate")
    UI.searchBox = search
    search:SetHeight(24)
    search:SetPoint("LEFT", searchLabel, "RIGHT", 12, 0)
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
    search:SetPoint("RIGHT", refresh, "LEFT", -16, 0)
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
    panel:SetPoint("TOPLEFT", 284, -64)
    panel:SetPoint("BOTTOMRIGHT", -28, 42)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetPoint("RIGHT", 0, 0)
    title:SetJustifyH("LEFT")
    UI.settingsTitle = title

    title:SetTextColor(1, 0.78, 0.12)

    local divider = CreateSectionDivider(panel, title)

    local labelX = 14
    local controlX = 126
    local rightColumnX = 278
    local checkboxLabelRightInset = 16
    local fullDropdownWidth = 414
    local soundDropdownWidth = 292

    local monitoringCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    UI.monitoringCheck = monitoringCheck
    monitoringCheck:SetPoint("TOPLEFT", 0, -48)
    monitoringCheck:SetScript("OnClick", function(button)
        CDR:SetMonitoringEnabled(button:GetChecked())
    end)

    local monitoringLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    monitoringLabel:SetPoint("LEFT", monitoringCheck, "RIGHT", 3, 0)
    monitoringLabel:SetPoint("RIGHT", panel, "LEFT", rightColumnX - 10, 0)
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
    titleLabel:SetPoint("RIGHT", panel, "LEFT", rightColumnX - 10, 0)
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
    soundLabel:SetPoint("RIGHT", panel, "LEFT", rightColumnX - 10, 0)
    soundLabel:SetJustifyH("LEFT")
    soundLabel:SetWordWrap(false)
    UI.soundLabel = soundLabel

    local topMostCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    UI.topMostCheck = topMostCheck
    topMostCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", rightColumnX, -50)
    topMostCheck:SetScript("OnClick", function(button)
        CDR:SetReminderTopMost(button:GetChecked())
    end)

    local topMostLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    topMostLabel:SetPoint("LEFT", topMostCheck, "RIGHT", 3, 0)
    topMostLabel:SetPoint("RIGHT", panel, "RIGHT", -checkboxLabelRightInset, 0)
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
    loadMessageLabel:SetPoint("RIGHT", panel, "RIGHT", -checkboxLabelRightInset, 0)
    loadMessageLabel:SetJustifyH("LEFT")
    loadMessageLabel:SetWordWrap(false)
    UI.loadMessageLabel = loadMessageLabel

    local soundDropdownLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundDropdownLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", labelX, -184)
    soundDropdownLabel:SetWidth(controlX - labelX - 8)
    soundDropdownLabel:SetJustifyH("LEFT")
    UI.soundDropdownLabel = soundDropdownLabel

    local soundDropdown = CreateFrame("Frame", "CooldownReminderSoundDropdown", panel, "UIDropDownMenuTemplate")
    UI.soundDropdown = soundDropdown
    soundDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", controlX - 22, -180)
    UIDropDownMenu_SetWidth(soundDropdown, soundDropdownWidth)
    UIDropDownMenu_Initialize(soundDropdown, function(_, level)
        CDR:PopulateSoundDropdown(level)
    end)

    local soundTest = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    UI.soundTestButton = soundTest
    soundTest:SetSize(118, 24)
    soundTest:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -180)
    soundTest:SetScript("OnClick", function()
        CDR:PlaySelectedSound(true)
    end)

    local languageLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    languageLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", labelX, -238)
    languageLabel:SetWidth(controlX - labelX - 8)
    languageLabel:SetJustifyH("LEFT")
    UI.languageLabel = languageLabel

    local languageDropdown = CreateFrame("Frame", "CooldownReminderLanguageDropdown", panel, "UIDropDownMenuTemplate")
    UI.languageDropdown = languageDropdown
    languageDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", controlX - 22, -234)
    UIDropDownMenu_SetWidth(languageDropdown, fullDropdownWidth)
    UIDropDownMenu_Initialize(languageDropdown, function(_, level)
        CDR:PopulateLanguageDropdown(level)
    end)

    local modeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", labelX, -286)
    modeLabel:SetWidth(controlX - labelX - 8)
    modeLabel:SetJustifyH("LEFT")
    UI.modeDropdownLabel = modeLabel

    local modeDropdown = CreateFrame("Frame", "CooldownReminderModeDropdown", panel, "UIDropDownMenuTemplate")
    UI.modeDropdown = modeDropdown
    modeDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", controlX - 22, -282)
    UIDropDownMenu_SetWidth(modeDropdown, fullDropdownWidth)
    UIDropDownMenu_Initialize(modeDropdown, function(_, level)
        CDR:PopulateModeDropdown(level)
    end)

    local modeDescription = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    modeDescription:SetPoint("TOPLEFT", modeDropdown, "BOTTOMLEFT", 22, -2)
    modeDescription:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
    modeDescription:SetJustifyH("LEFT")
    modeDescription:SetWordWrap(true)
    UI.modeDescription = modeDescription

    local layoutLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    layoutLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", labelX, -376)
    layoutLabel:SetWidth(controlX - labelX - 8)
    layoutLabel:SetJustifyH("LEFT")
    UI.layoutDropdownLabel = layoutLabel

    local layoutDropdown = CreateFrame("Frame", "CooldownReminderLayoutDropdown", panel, "UIDropDownMenuTemplate")
    UI.layoutDropdown = layoutDropdown
    layoutDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", controlX - 22, -372)
    UIDropDownMenu_SetWidth(layoutDropdown, fullDropdownWidth)
    UIDropDownMenu_Initialize(layoutDropdown, function(_, level)
        CDR:PopulateLayoutDropdown(level)
    end)

end

function CDR:CreateExpertTimingRow(parent, option, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -102 - ((index - 1) * 46))
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:SetHeight(44)
    row.option = option

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    label:SetWidth(198)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label

    local desc = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    desc:SetWidth(220)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    row.desc = desc

    local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -1)
    valueText:SetWidth(52)
    valueText:SetJustifyH("RIGHT")
    row.valueText = valueText

    local slider = CreateFrame("Slider", "CooldownReminderExpertTimingSlider" .. option.key, row, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", row, "TOPLEFT", 242, -4)
    slider:SetPoint("TOPRIGHT", valueText, "TOPLEFT", -14, -4)
    slider:SetMinMaxValues(option.min, option.max)
    slider:SetValueStep(option.step)
    slider:SetObeyStepOnDrag(true)
    slider.option = option
    slider:SetScript("OnValueChanged", function(control, value)
        if UI.expertTimingRefreshLocked then
            return
        end

        local normalized = CDR:NormalizeExpertTimingValue(control.option, value)
        if math.abs(normalized - value) > 0.0001 then
            control:SetValue(normalized)
            return
        end

        CDR:SetExpertTimingValue(control.option.key, normalized)
        CDR:RefreshExpertTimingControls()
    end)
    row.slider = slider

    local sliderName = slider:GetName()
    if _G[sliderName .. "Low"] then
        _G[sliderName .. "Low"]:SetText("")
    end
    if _G[sliderName .. "High"] then
        _G[sliderName .. "High"]:SetText("")
    end
    if _G[sliderName .. "Text"] then
        _G[sliderName .. "Text"]:SetText("")
    end

    return row
end

function CDR:CreateExpertPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    UI.expertPanel = panel
    panel:SetPoint("TOPLEFT", 284, -64)
    panel:SetPoint("BOTTOMRIGHT", -28, 42)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetPoint("RIGHT", 0, 0)
    title:SetJustifyH("LEFT")
    UI.expertTitle = title

    title:SetTextColor(1, 0.78, 0.12)

    local divider = CreateSectionDivider(panel, title)

    local warning = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    warning:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -14)
    warning:SetPoint("RIGHT", -118, 0)
    warning:SetJustifyH("LEFT")
    warning:SetWordWrap(true)
    warning:SetTextColor(1, 0.82, 0.26)
    UI.expertWarning = warning

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    UI.expertResetButton = reset
    reset:SetSize(112, 24)
    reset:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -42)
    reset:SetScript("OnClick", function()
        CDR:ResetExpertTimingSettings()
        CDR:RefreshConfig()
    end)

    UI.expertTimingRows = {}
    for index, option in ipairs(CDR.EXPERT_TIMING_OPTIONS) do
        local row = self:CreateExpertTimingRow(panel, option, index)
        UI.expertTimingRows[option.key] = row
    end
end

function CDR:CreateAboutInfoRow(parent, anchor, labelKey, valueProvider)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:SetHeight(26)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(128)
    label:SetJustifyH("LEFT")
    row.label = label
    row.labelKey = labelKey

    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("LEFT", label, "RIGHT", 14, 0)
    value:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    value:SetJustifyH("LEFT")
    value:SetWordWrap(false)
    row.value = value
    row.valueProvider = valueProvider

    return row
end

function CDR:CreateAboutLinkRow(parent, anchor, labelKey, url)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:SetHeight(30)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(128)
    label:SetJustifyH("LEFT")
    row.label = label
    row.labelKey = labelKey

    local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    editBox:SetPoint("LEFT", label, "RIGHT", 14, 0)
    editBox:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    editBox:SetHeight(24)
    editBox:SetAutoFocus(false)
    editBox:SetText(url)
    editBox:SetCursorPosition(0)
    editBox:SetScript("OnEditFocusGained", function(box)
        box:HighlightText()
    end)
    editBox:SetScript("OnMouseUp", function(box)
        box:SetFocus()
        box:HighlightText()
    end)
    editBox:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
    end)
    row.editBox = editBox

    return row
end

function CDR:CreateAboutPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    UI.aboutPanel = panel
    panel:SetPoint("TOPLEFT", 284, -64)
    panel:SetPoint("BOTTOMRIGHT", -28, 42)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetPoint("RIGHT", 0, 0)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1, 0.78, 0.12)
    UI.aboutTitle = title

    local divider = CreateSectionDivider(panel, title)

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -16)
    description:SetPoint("RIGHT", panel, "RIGHT", -6, 0)
    description:SetJustifyH("LEFT")
    description:SetWordWrap(true)
    description:SetTextColor(0.92, 0.88, 0.78)
    UI.aboutDescription = description

    local versionRow = self:CreateAboutInfoRow(panel, description, "ABOUT_VERSION", function()
        return CDR.VERSION or "dev"
    end)
    UI.aboutVersionRow = versionRow

    local curseRow = self:CreateAboutLinkRow(panel, versionRow, "ABOUT_CURSEFORGE", self.CURSEFORGE_URL)
    UI.aboutCurseForgeRow = curseRow

    local githubRow = self:CreateAboutLinkRow(panel, curseRow, "ABOUT_GITHUB", self.GITHUB_URL)
    UI.aboutGitHubRow = githubRow

    local commandsTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    commandsTitle:SetPoint("TOPLEFT", githubRow, "BOTTOMLEFT", 0, -24)
    commandsTitle:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    commandsTitle:SetJustifyH("LEFT")
    UI.aboutCommandsTitle = commandsTitle

    local commands = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    commands:SetPoint("TOPLEFT", commandsTitle, "BOTTOMLEFT", 0, -8)
    commands:SetPoint("RIGHT", panel, "RIGHT", -6, 0)
    commands:SetJustifyH("LEFT")
    commands:SetWordWrap(true)
    commands:SetTextColor(0.78, 0.76, 0.68)
    UI.aboutCommands = commands
end

function CDR:CreateConfigWindow()
    local frame = CreateFrame("Frame", "CooldownReminderConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    UI.config = frame

    frame:SetSize(870, 610)
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

    local contentBg = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
    UI.configContentBg = contentBg
    contentBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -32)
    contentBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    U.CreateBackdrop(contentBg, 0.68)
    contentBg:SetFrameLevel(frame:GetFrameLevel())

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

    self:CreateCategoryNavigation(frame)
    self:CreateSpellsPanel(frame)
    self:CreateSettingsPanel(frame)
    self:CreateExpertPanel(frame)
    self:CreateAboutPanel(frame)
    self:SetActiveTab(1)
    self:RefreshConfigTexts()
    self:RefreshConfig()
end

function CDR:NotifyAceOptionsChanged()
    if not self.aceOptionsRegistered then
        return
    end

    local registry = GetAceLibrary("AceConfigRegistry-3.0")
    if registry and registry.NotifyChange then
        pcall(registry.NotifyChange, registry, ACE_OPTIONS_NAME)
    end
end

function CDR:GetAceOptionsTable()
    return {
        type = "group",
        name = "CooldownReminder",
        args = {
            intro = {
                type = "description",
                name = function()
                    return CDR:L("BLIZZ_OPTIONS_HINT")
                end,
                fontSize = "medium",
                width = "full",
                order = 1,
            },
            open = {
                type = "execute",
                name = function()
                    return CDR:L("OPEN_CDR_OPTIONS")
                end,
                func = function()
                    CDR:ToggleConfig()
                end,
                width = "normal",
                order = 2,
            },
            general = {
                type = "group",
                name = function()
                    return CDR:L("TAB_SETTINGS")
                end,
                inline = true,
                order = 10,
                args = {
                    monitoring = {
                        type = "toggle",
                        name = function()
                            return CDR:L("ENABLE_MONITORING")
                        end,
                        get = function()
                            return CDR.db.monitoringEnabled ~= false
                        end,
                        set = function(_, value)
                            CDR:SetMonitoringEnabled(value, true)
                            CDR:NotifyAceOptionsChanged()
                        end,
                        width = "full",
                        order = 1,
                    },
                    loadMessage = {
                        type = "toggle",
                        name = function()
                            return CDR:L("SHOW_LOAD_MESSAGE")
                        end,
                        get = function()
                            return CDR.db.ui.showLoadMessage ~= false
                        end,
                        set = function(_, value)
                            CDR.db.ui.showLoadMessage = value == true
                            CDR:RefreshConfig()
                            CDR:NotifyAceOptionsChanged()
                        end,
                        width = "full",
                        order = 2,
                    },
                    language = {
                        type = "select",
                        name = function()
                            return CDR:L("LANGUAGE")
                        end,
                        values = BuildLanguageValues,
                        get = function()
                            return CDR.db.language or "auto"
                        end,
                        set = function(_, value)
                            CDR.db.language = value
                            CDR:ApplyLocale()
                            CDR:RefreshConfigTexts()
                            CDR:RefreshConfig()
                            CDR:RefreshReminderAlerts()
                            CDR:NotifyAceOptionsChanged()
                        end,
                        style = "dropdown",
                        width = "double",
                        order = 3,
                    },
                },
            },
            reminder = {
                type = "group",
                name = "Reminder",
                inline = true,
                order = 20,
                args = {
                    showTitle = {
                        type = "toggle",
                        name = function()
                            return CDR:L("SHOW_TITLE")
                        end,
                        get = function()
                            return CDR.db.reminder.showTitle ~= false
                        end,
                        set = function(_, value)
                            CDR.db.reminder.showTitle = value == true
                            CDR:RefreshReminderAlerts()
                            CDR:RefreshConfig()
                            CDR:NotifyAceOptionsChanged()
                        end,
                        width = "full",
                        order = 1,
                    },
                    topMost = {
                        type = "toggle",
                        name = function()
                            return CDR:L("REMINDER_TOPMOST")
                        end,
                        get = function()
                            return CDR.db.reminder.topMost == true
                        end,
                        set = function(_, value)
                            CDR:SetReminderTopMost(value)
                            CDR:RefreshConfig()
                            CDR:NotifyAceOptionsChanged()
                        end,
                        width = "full",
                        order = 2,
                    },
                    layout = {
                        type = "select",
                        name = function()
                            return CDR:L("REMINDER_LAYOUT")
                        end,
                        values = BuildLayoutValues,
                        get = function()
                            return CDR.db.reminder.layout or "vertical"
                        end,
                        set = function(_, value)
                            CDR:SetReminderLayout(value)
                            CDR:NotifyAceOptionsChanged()
                        end,
                        style = "dropdown",
                        width = "double",
                        order = 3,
                    },
                    mode = {
                        type = "select",
                        name = function()
                            return CDR:L("REMINDER_MODE")
                        end,
                        desc = function()
                            return CDR:L("REMINDER_MODE_DESC")
                        end,
                        values = BuildModeValues,
                        get = function()
                            return CDR.db.reminder.mode or "popup"
                        end,
                        set = function(_, value)
                            CDR:SetReminderMode(value)
                            CDR:NotifyAceOptionsChanged()
                        end,
                        style = "dropdown",
                        width = "double",
                        order = 4,
                    },
                    scale = {
                        type = "range",
                        name = function()
                            return CDR:L("REMINDER_SCALE")
                        end,
                        min = 0.6,
                        max = 2,
                        step = 0.05,
                        get = function()
                            return CDR.db.reminder.scale or 1
                        end,
                        set = function(_, value)
                            CDR:SetReminderScale(value)
                            CDR:NotifyAceOptionsChanged()
                        end,
                        width = "full",
                        order = 5,
                    },
                    reset = {
                        type = "execute",
                        name = function()
                            return CDR:L("RESET_POSITION")
                        end,
                        func = function()
                            CDR:ResetReminderLayout()
                            CDR:RefreshConfig()
                            CDR:NotifyAceOptionsChanged()
                        end,
                        order = 6,
                    },
                    test = {
                        type = "execute",
                        name = function()
                            return CDR:L("TEST_REMINDER")
                        end,
                        func = function()
                            CDR:TestReminder()
                        end,
                        order = 7,
                    },
                },
            },
            sound = {
                type = "group",
                name = function()
                    return CDR:L("SOUND")
                end,
                inline = true,
                order = 30,
                args = {
                    enabled = {
                        type = "toggle",
                        name = function()
                            return CDR:L("ENABLE_SOUND")
                        end,
                        get = function()
                            return CDR.db.sound.enabled == true
                        end,
                        set = function(_, value)
                            CDR.db.sound.enabled = value == true
                            CDR:RefreshConfig()
                            CDR:NotifyAceOptionsChanged()
                        end,
                        width = "full",
                        order = 1,
                    },
                    sound = {
                        type = "select",
                        name = function()
                            return CDR:L("SOUND")
                        end,
                        values = BuildSoundValues,
                        get = function()
                            return CDR.db.sound.id
                        end,
                        set = function(_, value)
                            CDR.db.sound.id = U.GetSoundOption(value).id
                            CDR:RefreshConfig()
                            CDR:PlaySelectedSound(true)
                            CDR:NotifyAceOptionsChanged()
                        end,
                        style = "dropdown",
                        width = "double",
                        order = 2,
                    },
                    testSound = {
                        type = "execute",
                        name = function()
                            return CDR:L("TEST_SOUND")
                        end,
                        func = function()
                            CDR:PlaySelectedSound(true)
                        end,
                        order = 3,
                    },
                },
            },
            expert = {
                type = "group",
                name = function()
                    return CDR:L("TAB_EXPERT")
                end,
                inline = true,
                order = 40,
                args = BuildExpertTimingAceArgs(),
            },
        },
    }
end

function CDR:RegisterAceSettingsCategory()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then
        return false
    end

    local aceConfig = GetAceLibrary("AceConfig-3.0")
    local aceDialog = GetAceLibrary("AceConfigDialog-3.0")
    if not aceConfig or not aceDialog then
        return false
    end

    local ok, frame, categoryID = pcall(function()
        if not self.aceOptionsRegistered then
            aceConfig:RegisterOptionsTable(ACE_OPTIONS_NAME, function()
                return CDR:GetAceOptionsTable()
            end)
            self.aceOptionsRegistered = true
        end

        local optionsFrame, optionsCategoryID = aceDialog:AddToBlizOptions(ACE_OPTIONS_NAME, "CooldownReminder")
        if aceDialog.SetDefaultSize then
            aceDialog:SetDefaultSize(ACE_OPTIONS_NAME, 620, 520)
        end
        return optionsFrame, optionsCategoryID
    end)

    if not ok then
        self.aceOptionsRegistered = false
        return false
    end

    self.settingsCategory = frame
    self.settingsCategoryID = categoryID
    return true
end

function CDR:RegisterFallbackSettingsCategory()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then
        return false
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
    return true
end

function CDR:RegisterSettingsCategory()
    if self.settingsCategory then
        return
    end

    if self:RegisterAceSettingsCategory() then
        return
    end

    self:RegisterFallbackSettingsCategory()
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

    if UI.categoryHeader then
        UI.categoryHeader:SetText(L("NAV_HEADER"))
    end
    if UI.categoryButtons then
        for _, button in ipairs(UI.categoryButtons) do
            button.label:SetText(L(button.labelKey))
        end
    elseif UI.spellsTab and UI.settingsTab then
        UI.spellsTab:SetText(L("TAB_SPELLS"))
        UI.settingsTab:SetText(L("TAB_SETTINGS"))
    end
    self:RefreshTabStyles()
    UI.spellsTitle:SetText(L("TAB_SPELLS"))
    UI.spellsIntro:SetText(L("SPELLS_INTRO"))
    UI.searchLabel:SetText(L("SEARCH"))
    UI.refreshButton:SetText(L("REFRESH"))
    UI.searchResultsTitle:SetText(L("SEARCH_RESULTS"))
    UI.searchEmpty:SetText(L("SEARCH_HINT"))
    UI.watchedTitle:SetText(L("WATCHED_SPELLS"))
    UI.watchedHint:SetText(L("WATCHED_HINT"))
    UI.emptyWatched:SetText(L("EMPTY_WATCHED"))
    UI.settingsTitle:SetText(L("TAB_SETTINGS"))
    UI.monitoringLabel:SetText(L("ENABLE_MONITORING"))
    UI.showTitleLabel:SetText(L("SHOW_TITLE"))
    UI.soundLabel:SetText(L("ENABLE_SOUND"))
    UI.topMostLabel:SetText(L("REMINDER_TOPMOST"))
    UI.loadMessageLabel:SetText(L("SHOW_LOAD_MESSAGE"))
    UI.soundDropdownLabel:SetText(L("SOUND"))
    UI.soundTestButton:SetText(L("TEST_SOUND"))
    UI.languageLabel:SetText(L("LANGUAGE"))
    UI.modeDropdownLabel:SetText(L("REMINDER_MODE"))
    UI.modeDescription:SetText(L("REMINDER_MODE_DESC"))
    UI.layoutDropdownLabel:SetText(L("REMINDER_LAYOUT"))
    UI.resetButton:SetText(L("RESET_POSITION"))
    UI.testButton:SetText(L("TEST_REMINDER"))
    if UI.settingsHint then
        UI.settingsHint:SetText(L("SETTINGS_HINT"))
    end
    UI.expertTitle:SetText(L("TAB_EXPERT"))
    UI.expertWarning:SetText(L("EXPERT_WARNING"))
    UI.expertResetButton:SetText(L("RESET_TO_DEFAULTS"))
    UI.aboutTitle:SetText(L("TAB_ABOUT"))
    UI.aboutDescription:SetText(L("ABOUT_DESCRIPTION"))
    UI.aboutCommandsTitle:SetText(L("ABOUT_COMMANDS"))
    UI.aboutCommands:SetText("/cdr\n/cdr toggle\n/cdr test\n/cdr reset")

    for _, row in ipairs({ UI.aboutVersionRow, UI.aboutCurseForgeRow, UI.aboutGitHubRow }) do
        if row and row.labelKey then
            row.label:SetText(L(row.labelKey))
        end
        if row and row.valueProvider then
            row.value:SetText(row.valueProvider())
        end
    end
    if UI.aboutCurseForgeRow then
        UI.aboutCurseForgeRow.editBox:SetText(self.CURSEFORGE_URL)
        UI.aboutCurseForgeRow.editBox:SetCursorPosition(0)
    end
    if UI.aboutGitHubRow then
        UI.aboutGitHubRow.editBox:SetText(self.GITHUB_URL)
        UI.aboutGitHubRow.editBox:SetCursorPosition(0)
    end

    for _, option in ipairs(self.EXPERT_TIMING_OPTIONS) do
        local row = UI.expertTimingRows and UI.expertTimingRows[option.key]
        if row then
            row.label:SetText(L(option.labelKey))
            row.desc:SetText(L(option.descKey))
        end
    end

    local sliderName = UI.scaleSlider:GetName()
    if _G[sliderName .. "Low"] then
        _G[sliderName .. "Low"]:SetText("")
    end
    if _G[sliderName .. "High"] then
        _G[sliderName .. "High"]:SetText("")
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
    if UI.modeDropdown then
        UIDropDownMenu_SetText(UI.modeDropdown, U.GetReminderModeLabel(self.db.reminder.mode))
    end
    if UI.layoutDropdown then
        UIDropDownMenu_SetText(UI.layoutDropdown, U.GetReminderLayoutLabel(self.db.reminder.layout))
    end
    self:RefreshExpertTimingControls()
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

function CDR:PopulateModeDropdown(level)
    if level ~= 1 then
        return
    end

    for _, option in ipairs(CDR.REMINDER_MODE_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = U.GetReminderModeLabel(option.id)
        info.checked = self.db.reminder.mode == option.id
        info.arg1 = option.id
        info.func = function(_, arg1)
            CDR:SetReminderMode(arg1)
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

function CDR:RefreshExpertTimingControls()
    if not UI.expertTimingRows then
        return
    end

    UI.expertTimingRefreshLocked = true
    for _, option in ipairs(self.EXPERT_TIMING_OPTIONS) do
        local row = UI.expertTimingRows[option.key]
        if row then
            local value = self:NormalizeExpertTimingValue(option, CONST[option.key])
            row.slider:SetValue(value)
            row.valueText:SetText(self:FormatExpertTimingValue(option.key))
        end
    end
    UI.expertTimingRefreshLocked = false
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
    if UI.modeDropdown then
        UIDropDownMenu_SetText(UI.modeDropdown, U.GetReminderModeLabel(self.db.reminder.mode))
    end
    if UI.layoutDropdown then
        UIDropDownMenu_SetText(UI.layoutDropdown, U.GetReminderLayoutLabel(self.db.reminder.layout))
    end
    self:RefreshExpertTimingControls()
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

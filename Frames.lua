local version = C_AddOns.GetAddOnMetadata("QuestKeeper", "Version") or "?"

-- Main List Frame
local title = string.format("QuestKeeper (v.%s)", version)
local listFrame = CreateFrame("Frame", "QuestListFrame", UIParent, "BasicFrameTemplateWithInset")
listFrame:SetSize(750, 600); listFrame:SetPoint("CENTER"); listFrame:Hide(); listFrame:SetFrameStrata("MEDIUM")
listFrame:SetMovable(true); listFrame:EnableMouse(true); listFrame:RegisterForDrag("LeftButton")
listFrame:SetScript("OnDragStart", listFrame.StartMoving); listFrame:SetScript("OnDragStop", listFrame.StopMovingOrSizing)
listFrame.TitleText:SetText(title)
tinsert(UISpecialFrames, "QuestListFrame")

-- Search Bar UI (SearchBoxTemplate for def Blizzard look)
local searchBox = CreateFrame("EditBox", "QuestKeeperDBSearchBox", listFrame, "SearchBoxTemplate")
searchBox:SetSize(180, 20)
searchBox:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -50, -32)
searchBox:SetAutoFocus(false)
QuestKeeperDBAddon.searchBox = searchBox

-- Search Results Counter
local searchCount = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
searchCount:SetPoint("LEFT", searchBox, "LEFT", 60, -30)
searchCount:SetSize(120, 20)
searchCount:SetJustifyH("RIGHT")
searchCount:SetTextColor(0.8, 0.8, 0.8)
QuestKeeperDBAddon.searchCount = searchCount

searchBox:SetScript("OnTextChanged", function(self)
    SearchBoxTemplate_OnTextChanged(self)
    QuestKeeperDBAddon.UpdateList()
end)

-- List Scroll Frame
local listScroll = CreateFrame("ScrollFrame", "QuestListScrollFrame", listFrame, "UIPanelScrollFrameTemplate")
listScroll:SetPoint("TOPLEFT", 10, -80)
listScroll:SetPoint("BOTTOMRIGHT", -30, 10)

-- Detail Display Frame
local detailFrame = CreateFrame("Frame", "QuestDetailDisplay", UIParent, "BasicFrameTemplateWithInset")
detailFrame:SetSize(450, 600); detailFrame:SetPoint("LEFT", listFrame, "RIGHT", 10, 0); detailFrame:Hide()
tinsert(UISpecialFrames, "QuestDetailDisplay")

detailFrame.scroll = CreateFrame("ScrollFrame", nil, detailFrame, "UIPanelScrollFrameTemplate")
detailFrame.scroll:SetPoint("TOPLEFT", 15, -35); detailFrame.scroll:SetPoint("BOTTOMRIGHT", -35, 45)
detailFrame.content = CreateFrame("SimpleHTML", nil, detailFrame.scroll)
detailFrame.content:SetSize(380, 100); detailFrame.content:SetFontObject("p", GameFontNormal); detailFrame.content:SetFontObject("h1", GameFontHighlightLarge)
detailFrame.scroll:SetScrollChild(detailFrame.content)

detailFrame.content:SetScript("OnHyperlinkEnter", QuestKeeperDBAddon.HandleHyperlinkEnter)
detailFrame.content:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
detailFrame.content:SetScript("OnHyperlinkClick", function(self, link) HandleModifiedItemClick(link) end)

-- Editor Frame
local editFrame = CreateFrame("Frame", "QuestEditFrame", UIParent, "BasicFrameTemplateWithInset")
editFrame:SetSize(500, 650); editFrame:SetPoint("CENTER"); editFrame:Hide(); editFrame:SetFrameStrata("HIGH")
editFrame.TitleText:SetText("Edit Quest Data")
tinsert(UISpecialFrames, "QuestEditFrame")

local saveBtn = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
saveBtn:SetSize(120, 30); saveBtn:SetPoint("BOTTOM", 0, 20); saveBtn:SetText("Save Changes")
QuestKeeperDBAddon.saveBtn = saveBtn

function QuestKeeperDBAddon.CreateEditField(label, yOffset, height, multi)
    local lbl = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 20, yOffset); lbl:SetText(label)
    local bg = CreateFrame("Frame", nil, editFrame, "BackdropTemplate")
    bg:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    bg:SetBackdropColor(0,0,0,0.5); bg:SetBackdropBorderColor(0.3, 0.3, 0.3)
    bg:SetPoint("TOPLEFT", 20, yOffset - 15); bg:SetSize(460, height or 25)
    local eb = CreateFrame("EditBox", nil, bg)
    eb:SetMultiLine(multi); eb:SetMaxLetters(3000); eb:SetFontObject(GameFontHighlight); eb:SetAutoFocus(false)
    eb:SetPoint("TOPLEFT", 5, -5); eb:SetPoint("BOTTOMRIGHT", -5, 5)
    return eb
end

QuestKeeperDBAddon.eFields = {
    title = QuestKeeperDBAddon.CreateEditField("Title:", -30),
    intro = QuestKeeperDBAddon.CreateEditField("Introduction:", -75, 50, true),
    desc = QuestKeeperDBAddon.CreateEditField("Objectives:", -140, 50, true),
    prog = QuestKeeperDBAddon.CreateEditField("Progress Text:", -205, 30, true),
    comp = QuestKeeperDBAddon.CreateEditField("Completion Text:", -250, 50, true),
    rewards = QuestKeeperDBAddon.CreateEditField("Reward Item IDs (comma):", -315),
    objs = QuestKeeperDBAddon.CreateEditField("Hand-in Item IDs (comma):", -360),
    progItems = QuestKeeperDBAddon.CreateEditField("In Progress Item IDs (comma):", -405),
    xp = QuestKeeperDBAddon.CreateEditField("XP:", -450),
    rep = QuestKeeperDBAddon.CreateEditField("Reputation (Faction:Value):", -495)
}

-- About / GitHub Button
local aboutBtn = CreateFrame("Button", nil, listFrame, "UIPanelButtonTemplate")
aboutBtn:SetSize(60, 22)
aboutBtn:SetPoint("TOPRIGHT", listFrame.CloseButton, "TOPLEFT", -5, 0)
aboutBtn:SetText("About")

aboutBtn:SetScript("OnClick", function()
    StaticPopup_Show("QUESTKEEPER_GITHUB_LINK")
end)

-- Tooltip
aboutBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("QuestKeeper Info")
    GameTooltip:AddLine("Click to view GitHub link and version info.", 1, 1, 1)
    GameTooltip:Show()
end)
aboutBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- About button click event
aboutBtn:SetScript("OnClick", function()
    StaticPopup_Show("QUESTKEEPER_GITHUB_LINK")
end)

StaticPopupDialogs["QUESTKEEPER_GITHUB_LINK"] = {
    text = "QuestKeeper (v." .. (C_AddOns.GetAddOnMetadata("QuestKeeper", "Version") or "?") .. ")\n\nVisit the project on GitHub for more info or support!",
    button1 = "Close",
    hasEditBox = true,
    editBoxWidth = 280,
    OnShow = function(self)
        self.EditBox:SetText("https://github.com/Ivan-825/QuestKeeper")
        self.EditBox:HighlightText()
        self.EditBox:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self)
        StaticPopup_Hide("QUESTKEEPER_GITHUB_LINK")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true, -- Ez engedi az Escape gombot
    enterClicksFirstButton = true, -- Enterre is bezáródik
    preferredIndex = 3,
}
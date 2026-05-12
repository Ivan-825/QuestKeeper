-- Main List Frame
local title = string.format("QuestKeeper (v.%s)", QuestKeeper.version)
local listFrame = CreateFrame("Frame", "QuestListFrame", UIParent, "BasicFrameTemplateWithInset")
listFrame:SetSize(750, 600); listFrame:SetPoint("CENTER"); listFrame:Hide(); listFrame:SetFrameStrata("MEDIUM")
listFrame:SetMovable(true); listFrame:EnableMouse(true); listFrame:RegisterForDrag("LeftButton")
listFrame:SetScript("OnDragStart", listFrame.StartMoving); listFrame:SetScript("OnDragStop", listFrame.StopMovingOrSizing)
listFrame.TitleText:SetText(title)
tinsert(UISpecialFrames, "QuestListFrame")

-- Search Bar UI
local searchBox = CreateFrame("EditBox", "QuestKeeperDBSearchBox", listFrame, "SearchBoxTemplate")
searchBox:SetSize(180, 20)
searchBox:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -50, -32)
searchBox:SetAutoFocus(false)
QuestKeeper.searchBox = searchBox

-- Search Results Counter
local searchCount = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
searchCount:SetPoint("LEFT", searchBox, "LEFT", 60, -30)
searchCount:SetSize(120, 20)
searchCount:SetJustifyH("RIGHT")
searchCount:SetTextColor(0.8, 0.8, 0.8)
QuestKeeper.searchCount = searchCount

searchBox:SetScript("OnTextChanged", function(self)
    SearchBoxTemplate_OnTextChanged(self)
    if QuestKeeper.UpdateList then QuestKeeper.UpdateList() end
end)

-- List Scroll Frame
local listScroll = CreateFrame("ScrollFrame", "QuestListScrollFrame", listFrame, "UIPanelScrollFrameTemplate")
listScroll:SetPoint("TOPLEFT", 10, -80)
listScroll:SetPoint("BOTTOMRIGHT", -30, 10)

-- Detail Display Frame
local detailFrame = CreateFrame("Frame", "QuestDetailDisplay", UIParent, "BasicFrameTemplateWithInset")
detailFrame:SetSize(450, 600); detailFrame:SetPoint("LEFT", listFrame, "RIGHT", 10, 0); detailFrame:Hide()
tinsert(UISpecialFrames, "QuestDetailDisplay")

-- FIXED HEADER (With 40px top margin)
detailFrame.titleText = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
detailFrame.titleText:SetPoint("TOP", 0, -40) -- Increased margin at top
detailFrame.titleText:SetWidth(400)

detailFrame.metaText = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
detailFrame.metaText:SetPoint("TOP", detailFrame.titleText, "BOTTOM", 0, -5)
detailFrame.metaText:SetWidth(400)
detailFrame.metaText:SetJustifyH("CENTER")

-- GOSSIP PAGINATION (Less padding)
detailFrame.gossipHeader = CreateFrame("Frame", nil, detailFrame)
detailFrame.gossipHeader:SetSize(400, 20) -- Reduced height
detailFrame.gossipHeader:SetPoint("TOP", detailFrame.metaText, "BOTTOM", 0, -5) -- Reduced top padding

detailFrame.prevGossip = CreateFrame("Button", nil, detailFrame.gossipHeader, "UIPanelButtonTemplate")
detailFrame.prevGossip:SetSize(26, 18); detailFrame.prevGossip:SetPoint("LEFT", 15, 0); detailFrame.prevGossip:SetText("<")

detailFrame.nextGossip = CreateFrame("Button", nil, detailFrame.gossipHeader, "UIPanelButtonTemplate")
detailFrame.nextGossip:SetSize(26, 18); detailFrame.nextGossip:SetPoint("RIGHT", -15, 0); detailFrame.nextGossip:SetText(">")

detailFrame.gossipPageText = detailFrame.gossipHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
detailFrame.gossipPageText:SetPoint("CENTER", 0, 0)

-- SCROLL AREA (Tightened position)
detailFrame.scroll = CreateFrame("ScrollFrame", nil, detailFrame, "UIPanelScrollFrameTemplate")
detailFrame.scroll:SetPoint("TOPLEFT", 15, -145) -- Moved up as buttons take less space
detailFrame.scroll:SetPoint("BOTTOMRIGHT", -35, 45)

detailFrame.content = CreateFrame("SimpleHTML", nil, detailFrame.scroll)
detailFrame.content:SetSize(380, 100)
detailFrame.content:SetFontObject("p", GameFontNormal)
detailFrame.scroll:SetScrollChild(detailFrame.content)

detailFrame.content:SetScript("OnHyperlinkEnter", QuestKeeper.HandleHyperlinkEnter)
detailFrame.content:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
detailFrame.content:SetScript("OnHyperlinkClick", function(self, link) HandleModifiedItemClick(link) end)

-- Editor Frame
local editFrame = CreateFrame("Frame", "QuestEditFrame", UIParent, "BasicFrameTemplateWithInset")
editFrame:SetSize(500, 650); editFrame:SetPoint("CENTER"); editFrame:Hide(); editFrame:SetFrameStrata("HIGH")
editFrame.TitleText:SetText("Edit Quest Data")
tinsert(UISpecialFrames, "QuestEditFrame")

local saveBtn = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
saveBtn:SetSize(120, 30); saveBtn:SetPoint("BOTTOM", 0, 20); saveBtn:SetText("Save Changes")
QuestKeeper.saveBtn = saveBtn

function QuestKeeper.CreateEditField(label, yOffset, height, multi)
    local lbl = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 20, yOffset); lbl:SetText(label)
    local bg = CreateFrame("Frame", nil, editFrame, "BackdropTemplate")
    bg:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    bg:SetBackdropColor(0,0,0,0.5); bg:SetBackdropBorderColor(0.3, 0.3, 0.3)
    bg:SetPoint("TOPLEFT", 20, yOffset - 15); bg:SetSize(460, height or 25)
    local eb = CreateFrame("EditBox", nil, bg)
    eb:SetMultiLine(multi); eb:SetMaxLetters(5000); eb:SetFontObject(GameFontHighlight); eb:SetAutoFocus(false)
    eb:SetPoint("TOPLEFT", 5, -5); eb:SetPoint("BOTTOMRIGHT", -5, 5)
    return eb
end

QuestKeeper.eFields = {
    title     = QuestKeeper.CreateEditField("Title:", -30),
    intro     = QuestKeeper.CreateEditField("Introduction (Gossip):", -75, 50, true),
    desc      = QuestKeeper.CreateEditField("Description (Story):", -140, 50, true),
    objs      = QuestKeeper.CreateEditField("Objectives:", -205, 50, true), 
    prog      = QuestKeeper.CreateEditField("Progress Text:", -270, 30, true),
    comp      = QuestKeeper.CreateEditField("Completion Text:", -315, 50, true),
    rewards   = QuestKeeper.CreateEditField("Reward Item IDs (comma):", -380),
    handin    = QuestKeeper.CreateEditField("Hand-in Item IDs (comma):", -425),
    progItems = QuestKeeper.CreateEditField("In Progress Item IDs (comma):", -470),
    xp        = QuestKeeper.CreateEditField("XP:", -515),
    money     = QuestKeeper.CreateEditField("Money (Copper):", -560),
    rep       = QuestKeeper.CreateEditField("Reputation (Faction:Value):", -605)
}

-- About Popup
StaticPopupDialogs["QUESTKEEPER_GITHUB_LINK"] = {
    text = "QuestKeeper (v." .. QuestKeeper.version .. ")\n\nVisit the project on GitHub for more info or support!",
    button1 = "Close",
    hasEditBox = true,
    editBoxWidth = 280,
    OnShow = function(self)
        self.EditBox:SetText("https://github.com")
        self.EditBox:HighlightText(); self.EditBox:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self) StaticPopup_Hide("QUESTKEEPER_GITHUB_LINK") end,
    timeout = 0, whileDead = true, hideOnEscape = true, enterClicksFirstButton = true, preferredIndex = 3,
}

-- Pagination Scripts
detailFrame.prevGossip:SetScript("OnClick", function()
    if QuestKeeper.currentGossipIndex > 1 then
        QuestKeeper.currentGossipIndex = QuestKeeper.currentGossipIndex - 1
        if QuestKeeper.UpdateDetailDisplay then QuestKeeper.UpdateDetailDisplay() end
        PlaySound(829)
    end
end)

detailFrame.nextGossip:SetScript("OnClick", function()
    local q = QuestKeeper.GetCurrentQuest and QuestKeeper.GetCurrentQuest()
    if q and q.gossips and QuestKeeper.currentGossipIndex < #q.gossips then
        QuestKeeper.currentGossipIndex = QuestKeeper.currentGossipIndex + 1
        if QuestKeeper.UpdateDetailDisplay then QuestKeeper.UpdateDetailDisplay() end
        PlaySound(829)
    end
end)
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
    if SearchBoxTemplate_OnTextChanged then
        SearchBoxTemplate_OnTextChanged(self)
    elseif InputBoxInstructions_OnTextChanged then
        InputBoxInstructions_OnTextChanged(self)
    end
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

-- HEADER (With 40px top margin)
detailFrame.titleText = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
detailFrame.titleText:SetPoint("TOP", 0, -40)
detailFrame.titleText:SetWidth(400)

detailFrame.metaText = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
detailFrame.metaText:SetPoint("TOP", detailFrame.titleText, "BOTTOM", 0, -5)
detailFrame.metaText:SetWidth(400)
detailFrame.metaText:SetJustifyH("CENTER")

-- GOSSIP PAGINATION (Less padding)
detailFrame.gossipHeader = CreateFrame("Frame", nil, detailFrame)
detailFrame.gossipHeader:SetSize(400, 20)
detailFrame.gossipHeader:SetPoint("TOP", detailFrame.metaText, "BOTTOM", 0, -5)

detailFrame.prevGossip = CreateFrame("Button", nil, detailFrame.gossipHeader, "UIPanelButtonTemplate")
detailFrame.prevGossip:SetSize(26, 20); detailFrame.prevGossip:SetPoint("LEFT", 15, 0); detailFrame.prevGossip:SetText("<")

detailFrame.nextGossip = CreateFrame("Button", nil, detailFrame.gossipHeader, "UIPanelButtonTemplate")
detailFrame.nextGossip:SetSize(26, 20); detailFrame.nextGossip:SetPoint("RIGHT", -15, 0); detailFrame.nextGossip:SetText(">")

detailFrame.gossipPageText = detailFrame.gossipHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
detailFrame.gossipPageText:SetPoint("CENTER", 0, 0)

-- SCROLL AREA (Tightened position)
detailFrame.scroll = CreateFrame("ScrollFrame", nil, detailFrame, "UIPanelScrollFrameTemplate")
detailFrame.scroll:SetPoint("TOPLEFT", 15, -145)
detailFrame.scroll:SetPoint("BOTTOMRIGHT", -35, 45)

detailFrame.content = CreateFrame("SimpleHTML", nil, detailFrame.scroll)
detailFrame.content:SetSize(380, 100)
detailFrame.content:SetFontObject("p", GameFontNormal)
detailFrame.scroll:SetScrollChild(detailFrame.content)

-- Editor Frame
local editFrame = CreateFrame("Frame", "QuestEditFrame", UIParent, "BasicFrameTemplateWithInset")
editFrame:SetSize(500, 650); editFrame:SetPoint("CENTER"); editFrame:Hide(); editFrame:SetFrameStrata("HIGH")
editFrame.TitleText:SetText("Edit Quest Data")
tinsert(UISpecialFrames, "QuestEditFrame")

local saveBtn = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
saveBtn:SetSize(120, 28); saveBtn:SetPoint("BOTTOM", 0, 20); saveBtn:SetText("Save Changes")
QuestKeeper.saveBtn = saveBtn

-- Generates individual, vertically chained edit fields that scale dynamically with text length
function QuestKeeper.CreateEditField(parentScrollChild, multi, previousElement, labelText)
    -- Creates an invisible host frame container to bundle a field title and its matching input block together
    local block = CreateFrame("Frame", nil, parentScrollChild)
    block:SetWidth(450)
    
    -- Chains the current element position directly below the preceding layout block to ensure clean vertical alignment
    if previousElement then
        block:SetPoint("TOPLEFT", previousElement, "BOTTOMLEFT", 0, -12)
    else
        block:SetPoint("TOPLEFT", parentScrollChild, "TOPLEFT", 10, -10)
    end

    -- Configures and displays the field text label at the top of the local block container
    local lbl = block:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetText(labelText)
    lbl:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
    
    -- Visual background texture framing for the text box area with border properties
    local bg = CreateFrame("Frame", nil, block, "BackdropTemplate")
    bg:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    bg:SetBackdropColor(0, 0, 0, 0.6)
    bg:SetBackdropBorderColor(0.25, 0.25, 0.25)
    bg:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -4)
    
    -- Main editable text element embedded directly inside the backdrop frame
    local eb = CreateFrame("EditBox", nil, bg)
    eb:SetMaxLetters(5000)
    eb:SetFontObject(GameFontHighlight)
    eb:SetAutoFocus(false)
    eb:ClearAllPoints()
    eb:SetPoint("TOPLEFT", bg, "TOPLEFT", 5, -5)
    eb:SetTextInsets(5, 5, 0, 0)
    
    -- Handles realtime font size measurement to expand frame heights as text lines multiply
    local function ResizeBlock(self)
        if not self.textMeasurer then
            self.textMeasurer = self:GetParent():CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            self.textMeasurer:SetWidth(440)
            self.textMeasurer:Hide()
        end
        self.textMeasurer:SetText(self:GetText() or "")
        
        local textHeight = self.textMeasurer:GetStringHeight()
        local bgHeight = math.max(25, textHeight + 10)
        
        -- Scales the input element, backdrop, and container frame sizes simultaneously
        self:SetHeight(math.max(15, textHeight))
        bg:SetSize(450, bgHeight)
        block:SetSize(450, bgHeight + 20)
        
        -- Informs the parent scrolling window layer to recalculate total layout bounds
        local containerChild = block:GetParent()
        if QuestKeeper.RepositionEditFields then
            QuestKeeper.RepositionEditFields(containerChild)
        end
    end

    -- Assigns multiline capabilities and text rendering listener loops across all field types
    if multi then
        eb:SetMultiLine(true)
        eb:SetWidth(440)
        eb:SetScript("OnTextChanged", ResizeBlock)
    else
        eb:SetMultiLine(false)
        eb:SetSize(440, 20)
        bg:SetSize(450, 30)
        block:SetSize(450, 42)
        eb:SetScript("OnTextChanged", ResizeBlock)
    end
    
    eb:SetScript("OnEscapePressed", function(self) 
        self:ClearFocus() 
        if QuestEditFrame then QuestEditFrame:Hide() end -- Closes the editor window instantly without triggering save routines
    end)

    -- Intercepts Tab and Shift-Tab keystrokes to shift input focus across elements
    eb:SetScript("OnTabPressed", function(self)
        if IsShiftKeyDown() then
            if self.prevEditBox then self.prevEditBox:SetFocus() end
        else
            if self.nextEditBox then self.nextEditBox:SetFocus() end
        end
    end)

    return eb, block
end

-- Primary setup routine for the standalone database editor menu window frame
if QuestEditFrame then
    QuestEditFrame:SetSize(510, 650)
    
    -- Blocks game clicks from leaking behind the editor window layout layer
    QuestEditFrame:EnableMouse(true)
    
    QuestEditFrame.labels = {}
    QuestKeeper.eFields = {}
    
    -- Establishes a scrolling layout viewport window for long scroll setups
    local mainScroll = CreateFrame("ScrollFrame", "QuestEditScrollFrame", QuestEditFrame, "UIPanelScrollFrameTemplate")
    mainScroll:SetPoint("TOPLEFT", 10, -35)
    mainScroll:SetPoint("BOTTOMRIGHT", -30, 50)
    
    -- The internal target canvas frame hosting the nested edit blocks
    local scrollChild = CreateFrame("Frame", nil, mainScroll)
    scrollChild:SetSize(470, 1)
    mainScroll:SetScrollChild(scrollChild)
    
    -- Memory pointer to maintain sequential linking of the layered layout elements
    local lastBlock = nil

    -- Registers field items and chains input focus references together for keyboard navigation loops
    local lastEditBox = nil
    local function RegisterField(key, label, multi)
        local eb, block = QuestKeeper.CreateEditField(scrollChild, multi, lastBlock, label)
        QuestKeeper.eFields[key] = eb
        lastBlock = block
        
        -- Chain editboxes together sequentially to support forward and backward focus movements
        if lastEditBox then
            lastEditBox.nextEditBox = eb
            eb.prevEditBox = lastEditBox
        end
        lastEditBox = eb
        return eb
    end

    -- Linear declaration of all quest property variables shown in the data layout panel
    RegisterField("title", "Title:", false)
    RegisterField("intro", "Introduction (Gossip):", true)
    RegisterField("desc", "Description (Story):", true)
    RegisterField("objs", "Objectives:", true) 
    RegisterField("prog", "Progress Text:", true)
    RegisterField("comp", "Completion Text:", true)
    RegisterField("rewards", "Reward Item IDs (comma):", false)
    RegisterField("handin", "Hand-in Item IDs (comma):", false)
    RegisterField("progItems", "In Progress Item IDs (comma):", false)
    RegisterField("xp", "XP:", false)
    RegisterField("money", "Money (Copper):", false)
    RegisterField("rep", "Reputation (Faction:Value):", false)
    
    if QuestKeeper.RepositionEditFields then
        QuestKeeper.RepositionEditFields(scrollChild)
    end
    
    -- Sets up the execution logic for the changes storage commit workflow button
    if QuestKeeper.saveBtn then
        QuestKeeper.saveBtn:ClearAllPoints()
        QuestKeeper.saveBtn:SetPoint("BOTTOM", QuestEditFrame, "BOTTOM", 0, 15)
        
        -- Commits user interface input text strings directly into the live storage database table
        QuestKeeper.saveBtn:SetScript("OnClick", function()
            local qID = QuestKeeper.selectedQuestID
            if not qID or not QuestKeeperDB then return end
            if not QuestKeeperDB[qID] then QuestKeeperDB[qID] = {} end
            
            local q = QuestKeeperDB[qID]
            
            -- Cleans out empty inputs by mapping them to nil properties to optimize storage file footprints
            local function SaveTextOrNil(field, value)
                if value and value:gsub("%s+", "") ~= "" then q[field] = value else q[field] = nil end
            end

            q.isEdited = true;
            SaveTextOrNil("title", QuestKeeper.eFields.title:GetText())
            SaveTextOrNil("description", QuestKeeper.eFields.desc:GetText())
            SaveTextOrNil("objectives", QuestKeeper.eFields.objs:GetText())
            SaveTextOrNil("progressText", QuestKeeper.eFields.prog:GetText())
            SaveTextOrNil("completionText", QuestKeeper.eFields.comp:GetText())
            
            -- Converts multi-line introduction layout text blocks back into a standard table array
            local introText = QuestKeeper.eFields.intro:GetText()
            q.gossips = {}
            for line in string.gmatch(introText, "[^\r\n]+") do
                if line ~= "---" and line:gsub("%s+", "") ~= "" then
                    table.insert(q.gossips, line)
                end
            end
            if #q.gossips == 0 then q.gossips = nil end
            
            -- Evaluates and stores text numeric properties if they carry an active value above zero
            local xpNum = tonumber(QuestKeeper.eFields.xp:GetText()) or 0
            q.xp = (xpNum > 0) and xpNum or nil

            local moneyNum = tonumber(QuestKeeper.eFields.money:GetText()) or 0
            q.money = (moneyNum > 0) and moneyNum or nil
            
            -- Parses comma-separated string profiles into clean numeric integer arrays
            local function ParseIDs(text)
                local t = {}
                for id in string.gmatch(text, "([^,]+)") do
                    local num = tonumber(id:match("^%s*(.-)%s*$"))
                    if num then table.insert(t, num) end
                end
                return (#t > 0) and t or nil
            end
            
            q.rewardItems = ParseIDs(QuestKeeper.eFields.rewards:GetText())
            q.handInItems = ParseIDs(QuestKeeper.eFields.handin:GetText())
            q.progItems = ParseIDs(QuestKeeper.eFields.progItems:GetText())
            
            -- Deconstructs formatted reputation text blocks into indexed database object structures
            local repText = QuestKeeper.eFields.rep:GetText()
            q.rep = {}
            for pair in string.gmatch(repText, "([^,]+)") do
                local facName, amtStr = pair:match("^%s*([^:]+):(-?%d+)%s*$")
                if facName and amtStr then
                    local resolvedID = nil
                    if C_Reputation and C_Reputation.GetNumFactions then
                        for i = 1, C_Reputation.GetNumFactions() do
                            local info = C_Reputation.GetFactionDataByIndex(i)
                            if info and info.name == facName:match("^%s*(.-)%s*$") then
                                resolvedID = info.factionID
                                break
                            end
                        end
                    end

                    table.insert(q.rep, {
                        factionID = resolvedID,
                        faction = facName:match("^%s*(.-)%s*$"),
                        amount = tonumber(amtStr) or 0,
                        state = QuestKeeper.REP_STATES and QuestKeeper.REP_STATES.ACTUAL or "ACTUAL"
                    })
                end
            end
            if #q.rep == 0 then q.rep = nil end
            
            -- Hides the dialog overlay window and updates live active view panels with the new parameters
            QuestEditFrame:Hide()
            if QuestKeeper.UpdateDetailDisplay then QuestKeeper.UpdateDetailDisplay() end
            if QuestKeeper.UpdateList then QuestKeeper.UpdateList() end
        end)
    end
end


if QuestDetailDisplay and not QuestDetailDisplay.editBtn then
    local editBtn = CreateFrame("Button", nil, QuestDetailDisplay, "UIPanelButtonTemplate")
    editBtn:SetSize(80, 22)
    editBtn:SetPoint("BOTTOMRIGHT", QuestDetailDisplay, "BOTTOMRIGHT", -15, 12)
    editBtn:SetText("Edit")
    QuestDetailDisplay.editBtn = editBtn
end

function QuestKeeper.OpenEditor(qID)
    local q = QuestKeeperDB and QuestKeeperDB[qID]
    if not q then return end

    -- Reset UI fields cleanly
    for _, eb in pairs(QuestKeeper.eFields) do
        eb:SetText("")
        eb:ClearFocus()
    end

    QuestKeeper.eFields.title:SetText(q.title or "")
    QuestKeeper.eFields.desc:SetText(q.description or "")
    QuestKeeper.eFields.objs:SetText(q.objectives or "")
    QuestKeeper.eFields.prog:SetText(q.progressText or "")
    QuestKeeper.eFields.comp:SetText(q.completionText or "")

    if type(q.gossips) == "table" and #q.gossips > 0 then
        QuestKeeper.eFields.intro:SetText(table.concat(q.gossips, "\n---\n"))
    else
        QuestKeeper.eFields.intro:SetText("")
    end

    QuestKeeper.eFields.xp:SetText(tostring(q.xp or 0))
    QuestKeeper.eFields.money:SetText(tostring(q.money or 0))

    local function FlattenArray(arr)
        if type(arr) ~= "table" or #arr == 0 then return "" end
        return table.concat(arr, ", ")
    end

    QuestKeeper.eFields.rewards:SetText(FlattenArray(q.rewardItems))
    QuestKeeper.eFields.handin:SetText(FlattenArray(q.handInItems))
    QuestKeeper.eFields.progItems:SetText(FlattenArray(q.progItems))

    -- Extract structured database data cleanly into standard Faction:Value display text format
    if type(q.rep) == "table" and #q.rep > 0 then
        local repLines = {}
        for _, repData in ipairs(q.rep) do
            local factionName = repData.faction
            if not factionName and repData.factionID and C_Reputation and C_Reputation.GetFactionDataByID then
                local data = C_Reputation.GetFactionDataByID(repData.factionID)
                factionName = data and data.name
            end
            
            factionName = factionName or "Unknown Faction"
            local amount = tonumber(repData.amount) or 0
            
            table.insert(repLines, string.format("%s:%d", factionName, amount))
        end
        QuestKeeper.eFields.rep:SetText(table.concat(repLines, ", "))
    else
        QuestKeeper.eFields.rep:SetText("")
    end

    if QuestEditFrame then
        QuestEditFrame:Show()
    end
end

if QuestDetailDisplay and QuestDetailDisplay.editBtn then
    QuestDetailDisplay.editBtn:SetScript("OnClick", function()
        if QuestEditFrame and QuestKeeper.OpenEditor then
            QuestKeeper.OpenEditor(QuestKeeper.selectedQuestID)
        end
    end)
end

StaticPopupDialogs["QUESTKEEPER_GITHUB_LINK"] = {
    text = "QuestKeeper (v." .. (QuestKeeper.version or "1.0") .. ")\n\nVisit the project on GitHub for more info or support!",
    button1 = "Close",
    hasEditBox = true,
    editBoxWidth = 280,
    OnShow = function(self)
        self.editBox:SetText("https://github.com")
        self.editBox:HighlightText(); self.editBox:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self) StaticPopup_Hide("QUESTKEEPER_GITHUB_LINK") end,
    timeout = 0, whileDead = true, hideOnEscape = true, enterClicksFirstButton = true, preferredIndex = 3,
}

-- Pagination Scripts
detailFrame.prevGossip:SetScript("OnClick", function()
    if QuestKeeper.currentGossipIndex and QuestKeeper.currentGossipIndex > 1 then
        QuestKeeper.currentGossipIndex = QuestKeeper.currentGossipIndex - 1
        
        if QuestKeeper.UpdateDetailDisplay then 
            QuestKeeper.UpdateDetailDisplay() 
        end
        PlaySound(829)
    end
end)

detailFrame.nextGossip:SetScript("OnClick", function()
    local qID = QuestKeeper.selectedQuestID
    local q = qID and QuestKeeperDB and QuestKeeperDB[qID]
    
    if q and q.gossips and QuestKeeper.currentGossipIndex and QuestKeeper.currentGossipIndex < #q.gossips then
        QuestKeeper.currentGossipIndex = QuestKeeper.currentGossipIndex + 1
        
        if QuestKeeper.UpdateDetailDisplay then 
            QuestKeeper.UpdateDetailDisplay() 
        end
        PlaySound(829)
    end
end)

function QuestKeeper.HandleHyperlinkEnter(self, linkData)
    if linkData:find("^qkrep:") then
        local index = tonumber(linkData:match("qkrep:(%d+)"))
        local qID = QuestKeeper.selectedQuestID
        local q = QuestKeeperDB and QuestKeeperDB[qID]
        if not q or not q.rep or not q.rep[index] then return end

        local repData = q.rep[index]
        local state = repData.state
        local isCompleted = (q.status == "completed")
        local tooltipText = repData.customTooltip

        if not tooltipText and QuestKeeper.REP_STATES then
            if not isCompleted and state == QuestKeeper.REP_STATES.PREDICTION then
                tooltipText = "This is only a predicted value, reputation upon completion may differ."
            elseif isCompleted and state == QuestKeeper.REP_STATES.PREDICTION then
                tooltipText = "This predicted reputation was not received upon completion."
            elseif isCompleted and state == QuestKeeper.REP_STATES.ACTUAL then
                tooltipText = "This is an actual value that was received upon completion."
            elseif not isCompleted and state == QuestKeeper.REP_STATES.ACTUAL then
                tooltipText = "This is an actual value from a previous completion."
            elseif state == QuestKeeper.REP_STATES.UNEXPECTED then
                tooltipText = "This reputation was gained at the time of quest completion, but was not expected."
            end
        end

        if tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(repData.faction or "Reputation Info", 1, 0.64, 0)
            GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end
        return
    end

    if linkData:find("^item:") or linkData:find("^currency:") then
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(linkData)
        GameTooltip:Show()
        return
    end
end

-- Event hooks
detailFrame.content:SetScript("OnHyperlinkEnter", QuestKeeper.HandleHyperlinkEnter)
detailFrame.content:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
detailFrame.content:SetScript("OnHyperlinkClick", function(self, link) HandleModifiedItemClick(link) end)
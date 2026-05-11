local statusMap = {
            discovered = "|cffaaaaaaDiscovered|r",
            inProgress = "|cffffff00In Progress|r",
            completed  = "|cff00ff00Completed|r",
            abandoned  = "|cffff0000Abandoned|r"
        }

function QuestKeeperDBAddon.ValidateDatabase()
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and info.questID and not info.isHeader and not info.isHidden then
            local qID = info.questID
            
            -- For new Quests
            if not QuestKeeperDB[qID] then
                local isDaily = (info.frequency == Enum.QuestFrequency.Daily)
                local isRepeatable = (info.frequency == Enum.QuestFrequency.Repeatable)

                QuestKeeperDB[qID] = { 
                    id = qID,
                    title = info.title or "Unknown", 
                    status = "inProgress", 
                    timestamp = time(), 
                    isImported = false,
                    isDaily = isDaily,
                    isRepeatable = isRepeatable,
                    introduction = "",
                    description = "",
                    progressText = "",
                    completionText = "",
                    discoveredDate = "Unknown", 
                    acceptedDate = QuestKeeperDBAddon.GetDate and QuestKeeperDBAddon.GetDate() or "Unknown", 
                    completedDate = "Unknown",
                    displayDate = "Unknown",
                    xp = 0, 
                    money = 0, 
                    rep = "",
                    rewardItems = {}, 
                    handInItems = {},
                    progItems = {},
                    compItems = {},
                    objItems = {},
                    completionCount = 0,
                    completionHistory = {}
                }
            end

            -- Update details for in-progress quests
            local q = QuestKeeperDB[qID]
            if q.status == "inProgress" and (not q.introduction or q.introduction == "") then
                local questIndex = C_QuestLog.GetLogIndexForQuestID(qID)
                if questIndex then
                    local intro, objectives = GetQuestLogQuestText(questIndex)
                    q.introduction = intro or ""
                    q.description = objectives or ""
                    q.xp = GetQuestLogRewardXP(qID) or 0
                    q.money = GetQuestLogRewardMoney(qID) or 0
                    
                    if info.frequency == 1 then q.isDaily = true
                    elseif info.frequency == 2 then q.isRepeatable = true end
                end
            end
        end
    end

    -- Recover quests that were completed at a time when QuestKeeper was not active
    local allCompleted = C_QuestLog.GetAllCompletedQuestIDs()
    local importCount = 0
    if allCompleted then
        for _, qID in ipairs(allCompleted) do
            if not QuestKeeperDB[qID] then
                importCount = importCount + 1
                QuestKeeperDB[qID] = { 
                    id = qID,
                    title = C_QuestLog.GetTitleForQuestID(qID) or "Imported", 
                    status = "completed", 
                    isImported = true, 
                    timestamp = time(), 
                    isDaily = false,
                    isRepeatable = false,
                    introduction = "N/A (Imported)",
                    description = "N/A (Imported)",
                    progressText = "",
                    completionText = "",
                    discoveredDate = "Unknown", 
                    acceptedDate = "Unknown", 
                    completedDate = "Unknown",
                    displayDate = "Unknown",
                    xp = 0, 
                    money = 0, 
                    rep = "",
                    rewardItems = {}, 
                    handInItems = {},
                    progItems = {},
                    compItems = {},
                    objItems = {},
                    completionCount = 1,
                    completionHistory = {}
                }
            end
        end
    end

    
    if importCount > 0 then
        print("|cff00ff00QuestKeeper:|r Successfully imported |cffffffff" .. importCount .. "|r quests that were completed while the addon was not enabled / installed.")
    end
end

local function CreateHeader(text, width, xOffset, sortKey)
    local h = CreateFrame("Button", nil, QuestListFrame)
    h:SetSize(width, 25)
    h:SetPoint("TOPLEFT", xOffset, -30)
    h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.text:SetPoint("LEFT", 5, 0)
    h.text:SetText(text)
    h.sortKey = sortKey
    h.baseText = text
    h:SetScript("OnClick", function()
        if QuestKeeperDBAddon.currentSort.column == sortKey then
            QuestKeeperDBAddon.currentSort.order = (QuestKeeperDBAddon.currentSort.order == "asc") and "desc" or "asc"
        else
            QuestKeeperDBAddon.currentSort.column = sortKey
            QuestKeeperDBAddon.currentSort.order = "asc"
        end
        QuestKeeperDBAddon.UpdateList()
    end)
    QuestKeeperDBAddon.headers[sortKey] = h
end

function QuestKeeperDBAddon.UpdateList()
    if not QuestListFrame or not QuestListScrollFrame then return end
    
    if not QuestKeeperDBAddon.headers["id"] then
        local function CreateHeader(text, width, xOffset, sortKey)
            local h = CreateFrame("Button", nil, QuestListFrame)
            h:SetSize(width, 25); h:SetPoint("TOPLEFT", xOffset, -58)
            h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            h.text:SetPoint("LEFT", 5, 0); h.text:SetText(text)
            h.sortKey, h.baseText = sortKey, text
            h:SetScript("OnClick", function()
                if QuestKeeperDBAddon.currentSort.column == sortKey then
                    QuestKeeperDBAddon.currentSort.order = (QuestKeeperDBAddon.currentSort.order == "asc" and "desc" or "asc")
                else
                    QuestKeeperDBAddon.currentSort.column, QuestKeeperDBAddon.currentSort.order = sortKey, "asc"
                end
                QuestKeeperDBAddon.UpdateList()
            end)
            QuestKeeperDBAddon.headers[sortKey] = h
        end
        CreateHeader("ID", 60, 20, "id")
        CreateHeader("Quest Name", 350, 80, "title")
        CreateHeader("Status", 100, 430, "status")
        CreateHeader("Last Updated", 150, 530, "timestamp")
    end

    local scrollChild = QuestKeeperDBAddon.listContent
    if not scrollChild then
        scrollChild = CreateFrame("Frame", nil, QuestListScrollFrame)
        QuestKeeperDBAddon.listContent = scrollChild
        QuestListScrollFrame:SetScrollChild(scrollChild)
    end
    scrollChild:SetSize(700, 1)

    for key, h in pairs(QuestKeeperDBAddon.headers) do
        local arrow = (QuestKeeperDBAddon.currentSort.column == key) and (QuestKeeperDBAddon.currentSort.order == "asc" and " [^]" or " [v]") or ""
        h.text:SetText(h.baseText .. arrow)
    end

    for _, b in pairs(QuestKeeperDBAddon.buttons) do b:Hide() end

    local searchText = (QuestKeeperDBAddon.searchBox and QuestKeeperDBAddon.searchBox:GetText() or ""):lower()
    local dataList = {}
    local totalQuests = 0

    -- For date, only use numbers for search
    -- For quest name unchanged input is used for search
    local dateSearchThreshold = searchText:gsub("[%.%-]", "") 

    for id, data in pairs(QuestKeeperDB) do
        totalQuests = totalQuests + 1
        local questID = tostring(id)
        local questName = (data.title or "Unknown"):lower()
        
        local displayDate = (data.status == "completed" or data.status == "abandoned") and (data.completedDate or "Unknown") 
                     or (data.status == "inProgress" and (data.acceptedDate or "Unknown")) or (data.discoveredDate or "Unknown")

        -- Unify dates by removing "." and "-" characters
        local dateOnlyNumbers = displayDate:gsub("[%.%-]", "")

        -- SEARCH LOGIC:
        -- 1. ID Match
        -- 2. Quest name includes text?
        -- 3. Does the date match original, unmodified data?
        -- 4. Does date match unified?
        if searchText == "" or 
           questID:find(searchText, 1, true) or 
           questName:find(searchText, 1, true) or 
           displayDate:lower():find(searchText, 1, true) or
           (dateSearchThreshold ~= "" and dateOnlyNumbers:find(dateSearchThreshold, 1, true)) then
            
            local entry = data
            entry.id = id
            entry.displayDate = displayDate
            table.insert(dataList, entry)
        end
    end
    
    table.sort(dataList, function(a, b)
        if not a or not b then return false end
        local col = QuestKeeperDBAddon.currentSort.column
        local order = QuestKeeperDBAddon.currentSort.order

        -- For timestamps: Unknow should always be at the bottom of the list, no matter if asc or desc ordering
        if col == "timestamp" then
            -- 1. Always put imported(recovered) below a properly tracked quest
            if a.isImported and not b.isImported then return false end
            if not a.isImported and b.isImported then return true end

            -- 2. For same type (both recovered or both tracked)
            local tA, tB = tonumber(a.timestamp) or 0, tonumber(b.timestamp) or 0
            if tA ~= tB then
                if order == "asc" then return tA < tB else return tA > tB end
            end
            -- 3. Use ID if dates match.
            return tostring(a.id) < tostring(b.id)
        end

        -- General sorting logic for all other column
        local valA, valB = a[col] or "", b[col] or ""
        
        -- Numeric ordering for IDs
        if col == "id" then
            local nA, nB = tonumber(valA) or 0, tonumber(valB) or 0
            if nA ~= nB then
                if order == "asc" then return nA < nB else return nA > nB end
            end
        end

        -- For textual values
        local strA, strB = tostring(valA):lower(), tostring(valB):lower()
        if strA ~= strB then
            if order == "asc" then return strA < strB else return strA > strB end
        end

        -- Fallback: ID
        return tostring(a.id) < tostring(b.id)
    end)

    if QuestKeeperDBAddon.searchCount then
        if searchText == "" then
            QuestKeeperDBAddon.searchCount:SetText(string.format("%d/%d", totalQuests, totalQuests))
        else
            QuestKeeperDBAddon.searchCount:SetText(string.format("%d/%d", #dataList, totalQuests))
        end
    end

    for i, data in ipairs(dataList) do
        local b = QuestKeeperDBAddon.buttons[i] or CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
        b:SetSize(690, 25); b:SetPoint("TOPLEFT", 5, -(i-1)*26); b:Show()
        QuestKeeperDBAddon.buttons[i] = b
        if not b.colID then
            b.colID = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.colID:SetPoint("LEFT", 10, 0)
            b.colTitle = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.colTitle:SetPoint("LEFT", 75, 0)
            b.colStatus = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.colStatus:SetPoint("LEFT", 425, 0)
            b.colDate = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.colDate:SetPoint("LEFT", 525, 0)
        end

        local displayStatus = statusMap[data.status] or "Unknown"
        b.colID:SetText(data.id)
        local titleText = data.title or "Unknown"
        if data.isDaily then
            titleText = "|cff00ccff[D] |r" .. titleText
        elseif data.isRepeatable then
            titleText = "|cff00ff00[R] |r" .. titleText
        end
        
        b.colTitle:SetText(titleText .. (data.isEdited and " |cff00ff00 (Edited import)|r" or ""))
        b.colStatus:SetText(displayStatus)
        b.colDate:SetText(data.displayDate or "Unknown")
        
        b:SetScript("OnClick", function()
            -- 1. State update
            QuestKeeperDBAddon.selectedQuestID = data.id
            QuestKeeperDBAddon.currentGossipIndex = 1
            
            -- 2. Call the new formatter
            if QuestKeeperDBAddon.UpdateDetailDisplay then
                QuestKeeperDBAddon.UpdateDetailDisplay()
            end
            
            -- 3. Show the frame
            QuestDetailDisplay:Show()
        end)
    end
    scrollChild:SetHeight(#dataList * 26 + 10)
end
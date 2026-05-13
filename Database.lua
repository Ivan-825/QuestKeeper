local statusMap = {
            discovered = "|cffaaaaaaDiscovered|r",
            inProgress = "|cffffff00In Progress|r",
            completed  = "|cff00ff00Completed|r",
            abandoned  = "|cffff0000Abandoned|r"
        }

function QuestKeeper.ValidateDatabase()
    if QuestKeeperConfig.dbVersion ~= QuestKeeper.LATEST_DB_VERSION then
        QuestKeeper.DB_STATE = QuestKeeper.DB_STATES.LOCKED
        
        -- Lock the table using a metatable
        setmetatable(QuestKeeperDB, {
            __newindex = function(t, k, v)
                -- This function runs whenever someone tries to write: QuestKeeperDB[key] = value
                -- We do nothing, effectively blocking the write
            end
        })
        return
    end
    QuestKeeper.DB_STATE = QuestKeeper.DB_STATES.READY
end

-- Recover quests that were completed at a time when QuestKeeper was not active
function QuestKeeper.ImportCompletedQuests()
    -- Do not import if DB not ready
    if QuestKeeper.DB_STATE ~= QuestKeeper.DB_STATES.READY then return end

    local allCompleted = C_QuestLog.GetAllCompletedQuestIDs()
    local importCount = 0
    if allCompleted then
        for _, qID in ipairs(allCompleted) do
            if not QuestKeeperDB[qID] then
                local q = QuestKeeper.GetOrCreateQuest(qID)

                if q then
                    -- 2. Populate and override only key historical markers (omitting any empty values)
                    q.title = C_QuestLog.GetTitleForQuestID(qID) or "Imported"
                    q.status = "completed"
                    q.isImported = true
                    q.completionCount = 1
                    
                    importCount = importCount + 1
                end
            end
        end
    end

    
    if importCount > 0 then
        print("|cff00ff00QuestKeeper:|r Successfully imported |cffffffff" .. importCount .. "|r quests that were completed while the addon was not enabled / installed.")
    end
end

function QuestKeeper.UpdateActiveQuests()
    if QuestKeeper.DB_STATE ~= QuestKeeper.DB_STATES.READY then return end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and info.questID and not info.isHeader and not info.isHidden then
            local qID = info.questID
            local q = QuestKeeperDB[qID]
            
            -- Only check quests that are tracked as inProgress
            if q and q.status == "inProgress" then
                local questIndex = C_QuestLog.GetLogIndexForQuestID(qID)
                if questIndex then
                    local intro, objectives = GetQuestLogQuestText(questIndex)
                    
                    -- Only save if the text actually exists and is not empty
                    if intro and intro ~= "" then q.introduction = intro end
                    if objectives and objectives ~= "" then q.description = objectives end
                    
                    -- Only save rewards if they are greater than zero
                    local xp = GetQuestLogRewardXP(qID) or 0
                    local money = GetQuestLogRewardMoney(qID) or 0
                    if xp > 0 then q.xp = xp end
                    if money > 0 then q.money = money end
                    
                    -- Setup frequency flags cleanly
                    if info.frequency == Enum.QuestFrequency.Daily then 
                        q.isDaily = true
                    elseif info.frequency == Enum.QuestFrequency.Repeatable then 
                        q.isRepeatable = true 
                    end
                end
            end
        end
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
        if QuestKeeper.currentSort.column == sortKey then
            QuestKeeper.currentSort.order = (QuestKeeper.currentSort.order == "asc") and "desc" or "asc"
        else
            QuestKeeper.currentSort.column = sortKey
            QuestKeeper.currentSort.order = "asc"
        end
        QuestKeeper.UpdateList()
    end)
    QuestKeeper.headers[sortKey] = h
end

function QuestKeeper.UpdateList()
    if not QuestListFrame or not QuestListScrollFrame then return end
    
    if not QuestKeeper.headers["id"] then
        local function CreateHeader(text, width, xOffset, sortKey)
            local h = CreateFrame("Button", nil, QuestListFrame)
            h:SetSize(width, 25); h:SetPoint("TOPLEFT", xOffset, -58)
            h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            h.text:SetPoint("LEFT", 5, 0); h.text:SetText(text)
            h.sortKey, h.baseText = sortKey, text
            h:SetScript("OnClick", function()
                if QuestKeeper.currentSort.column == sortKey then
                    QuestKeeper.currentSort.order = (QuestKeeper.currentSort.order == "asc" and "desc" or "asc")
                else
                    QuestKeeper.currentSort.column, QuestKeeper.currentSort.order = sortKey, "asc"
                end
                QuestKeeper.UpdateList()
            end)
            QuestKeeper.headers[sortKey] = h
        end
        CreateHeader("ID", 60, 20, "id")
        CreateHeader("Quest Name", 350, 80, "title")
        CreateHeader("Status", 100, 430, "status")
        CreateHeader("Last Updated", 150, 530, "timestamp")
    end

    local scrollChild = QuestKeeper.listContent
    if not scrollChild then
        scrollChild = CreateFrame("Frame", nil, QuestListScrollFrame)
        QuestKeeper.listContent = scrollChild
        QuestListScrollFrame:SetScrollChild(scrollChild)
    end
    scrollChild:SetSize(700, 1)

    for key, h in pairs(QuestKeeper.headers) do
        local arrow = (QuestKeeper.currentSort.column == key) and (QuestKeeper.currentSort.order == "asc" and " [^]" or " [v]") or ""
        h.text:SetText(h.baseText .. arrow)
    end

    for _, b in pairs(QuestKeeper.buttons) do b:Hide() end

    local searchText = (QuestKeeper.searchBox and QuestKeeper.searchBox:GetText() or ""):lower()
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
        local col = QuestKeeper.currentSort.column
        local order = QuestKeeper.currentSort.order

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

    if QuestKeeper.searchCount then
        if searchText == "" then
            QuestKeeper.searchCount:SetText(string.format("%d/%d", totalQuests, totalQuests))
        else
            QuestKeeper.searchCount:SetText(string.format("%d/%d", #dataList, totalQuests))
        end
    end

    for i, data in ipairs(dataList) do
        local b = QuestKeeper.buttons[i] or CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
        b:SetSize(690, 25); b:SetPoint("TOPLEFT", 5, -(i-1)*26); b:Show()
        QuestKeeper.buttons[i] = b
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
            QuestKeeper.selectedQuestID = data.id
            QuestKeeper.currentGossipIndex = 1
            
            -- 2. Call the new formatter
            if QuestKeeper.UpdateDetailDisplay then
                QuestKeeper.UpdateDetailDisplay()
            end
            
            -- 3. Show the frame
            QuestDetailDisplay:Show()
        end)
    end
    scrollChild:SetHeight(#dataList * 26 + 10)
end
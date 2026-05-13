local f = CreateFrame("Frame")
local sessionProcessed = {}
local lastCompletedID = nil
local lastCompletedTime = 0
local pendingRepCheck = nil

function QuestKeeper.OnStartup()
    -- 1. MIGRATE
    QuestKeeper.MigrateDatabase()
    
    -- 2. VALIDATE
    if QuestKeeper.DB_STATE ~= QuestKeeper.DB_STATES.LOCKED then
        QuestKeeper.ValidateDatabase()
    end

    -- 3. IMPORT
    if QuestKeeper.DB_STATE == QuestKeeper.DB_STATES.READY then
        QuestKeeper.ImportCompletedQuests()
        QuestKeeper.UpdateActiveQuests()
    end

    -- 4. UI REFRESH
    QuestKeeper.UpdateList()
end

function QuestKeeper.GetOrCreateQuest(qID)
    if QuestKeeper.DB_STATE ~= QuestKeeper.DB_STATES.READY then 
        return nil 
    end
    if not qID or qID <= 0 then return nil end
    if not QuestKeeperDB[qID] then 
        QuestKeeperDB[qID] = { 
            id = qID,
            status = "discovered", 
            discoveredDate = QuestKeeper.GetDate(),
            timestamp = time(),
        } 
    end
    return QuestKeeperDB[qID]
end

local function GetQuestTypeInfo(qID)
    local isDaily, isRepeatable = false, false
    if not qID then return isDaily, isRepeatable end

    -- 1. Check via Tag Info (Most reliable for modern WoW)
    local tagInfo = C_QuestLog.GetQuestTagInfo(qID)
    if tagInfo then
        if tagInfo.tagID == Enum.QuestTag.Daily then
            isDaily = true
        elseif tagInfo.tagID == Enum.QuestTag.Repeatable then
            isRepeatable = true
        end
    end

    -- 2. Fallback via Quest Log info (if quest is accepted)
    if not isDaily and not isRepeatable then
        local questIndex = C_QuestLog.GetLogIndexForQuestID(qID)
        if questIndex then
            local info = C_QuestLog.GetInfo(questIndex)
            if info then
                if info.frequency == Enum.QuestFrequency.Daily then
                    isDaily = true
                elseif info.frequency == Enum.QuestFrequency.Repeatable then
                    isRepeatable = true
                end
            end
        end
    end

    return isDaily, isRepeatable
end

local function SafeGetQuestID()
    local id = GetQuestID()
    if (not id or id <= 0) then
        local title = GetTitleText()
        if title and title ~= "" then
            for i = 1, C_QuestLog.GetNumQuestLogEntries() do
                local info = C_QuestLog.GetInfo(i)
                if info and info.title == title then return info.questID end
            end
        end
    end
    return id
end

local function UpdateRewardData(qID)
    local q = QuestKeeper.GetOrCreateQuest(qID)
    if not q then return end
    
    C_Timer.After(0.4, function()
        -- 1. Identify Quest Type
        local isD, isR = GetQuestTypeInfo(qID)
        if not q.isDaily and not q.isRepeatable then
            q.isDaily, q.isRepeatable = isD, isR
        end
        
        -- 2. Basic Rewards
        q.xp, q.money = GetRewardXP(), GetRewardMoney()
        q.rewardItems, q.handInItems = {}, {}
        
        -- 3. Skill Rewards
        local sName, sTex, sPoints = GetRewardSkillPoints()
        if sName and type(sPoints) == "number" and sPoints > 0 then
            q.skillReward = { name = sName, tex = sTex, amount = sPoints }
        end
        
        -- 4. Currency Rewards
        local currencies = C_QuestLog.GetQuestRewardCurrencies(qID)
        if currencies then
            q.awards = {}
            for _, info in ipairs(currencies) do
                table.insert(q.awards, { id = info.currencyID, name = info.name, amount = info.totalRewardAmount, tex = info.texture })
            end
        end
        
        -- 5. Item Links (Choices, Rewards, and Required)
        local function fetchLinks(num, typeStr, target)
            if not num or num == 0 then return end
            for i=1, num do
                local s, l = pcall(GetQuestItemLink, typeStr, i)
                if s and l then 
                    local itemID = tonumber(l:match("item:(%d+)"))
                    if itemID then table.insert(target, itemID) end
                end
            end
        end
        fetchLinks(GetNumQuestChoices(), "choice", q.rewardItems)
        fetchLinks(GetNumQuestRewards(), "reward", q.rewardItems)
        fetchLinks(GetNumQuestItems(), "required", q.handInItems)
        
        -- 6. Modern Reputation Detection
        -- Do not overwrite if the quest is completed or currently being turned in
        if q.status == "discovered" then
            q.rep = GetPredictedQuestReputationRewards(qID)
        end
        
        if QuestKeeper.UpdateList then QuestKeeper.UpdateList() end
    end)
end

local Handlers = {}

Handlers["GOSSIP_SHOW"] = function()
    local text = ""
    if C_GossipInfo and C_GossipInfo.GetText then
        text = C_GossipInfo.GetText()
    elseif GetGossipText then
        text = GetGossipText()
    end
    
    if text and text ~= "" then 
        f.lastGossip = text 
    end
end

Handlers["QUEST_DETAIL"] = function()
    local qID = SafeGetQuestID()
    local q = QuestKeeper.GetOrCreateQuest(qID)
    if q then
        q.timestamp = time()
        q.status = "discovered"
        q.title = GetTitleText()
        q.description = GetQuestText()
        q.objectives = GetObjectiveText()
        q.discoveredDate, q.timestamp = QuestKeeper.GetDate(), time()

        if not q.gossips then q.gossips = {} end
        
        if f.lastGossip then
            local found = false
            for _, val in ipairs(q.gossips) do
                if val == f.lastGossip then found = true break end
            end
            if not found then table.insert(q.gossips, f.lastGossip) end
        end
        f.lastGossip = nil
        UpdateRewardData(qID)
    end
end

Handlers["QUEST_PROGRESS"] = function()
    C_Timer.After(0.15, function()
        local qID = SafeGetQuestID()
        local q = QuestKeeper.GetOrCreateQuest(qID)
        if q then
            q.timestamp = time()
            local text = GetProgressText()
            if text and text ~= "" then
                q.progressText = text
                q.status = "inProgress"
            end
            q.progItems = {}
            local n = GetNumQuestItems() or 0
            for i = 1, n do 
                local s, l = pcall(GetQuestItemLink, "required", i)
                if s and l then 
                    local itemID = tonumber(l:match("item:(%d+)"))
                    if itemID then table.insert(q.progItems, itemID) end
                end
            end
            if QuestKeeper.UpdateList then QuestKeeper.UpdateList() end
        end
    end)
end

Handlers["QUEST_COMPLETE"] = function()
    local qID = SafeGetQuestID()
    local q = QuestKeeper.GetOrCreateQuest(qID)
    if q then
        -- Save text and rewards, but not don't change the status
        lastCompletedID, lastCompletedTime = qID, GetTime()
        q.completionText = GetRewardText()
        UpdateRewardData(qID)
    end
    pendingRepCheck = nil
end

Handlers["QUEST_TURNED_IN"] = function(qID, xp, money)
    local q = QuestKeeper.GetOrCreateQuest(qID)
    if q then
        q.status = "completed"
        q.timestamp = time()
        q.completedDate = QuestKeeper.GetDate()
        
        -- Overwrite with actual values
        if xp and xp > 0 then q.xp = xp end
        if money and money > 0 then q.money = money end

        -- Detect repeatable / daily quests
        local isD, isR = GetQuestTypeInfo(qID)
        if isD or isR then
            q.completionCount = (q.completionCount or 0) + 1
            if not q.completionHistory then q.completionHistory = {} end
            table.insert(q.completionHistory, q.completedDate)
        end

        -- Single consolidated snapshot mapping baseline values
        pendingRepCheck = {
            questID = qID,
            timestamp = GetTime(),
            factions = {}
        }

        if type(q.rep) == "table" and #q.rep > 0 then
            -- Run expected prediction loops
            for _, repData in ipairs(q.rep) do
                local currentData = C_Reputation.GetFactionDataByID(repData.factionID)
                if currentData then
                    pendingRepCheck.factions[repData.factionID] = {
                        standing = currentData.currentStanding,
                        threshold = currentData.currentReactionThreshold
                    }
                end
            end
        else
            -- Unified global scan fallback loop
            for i = 1, C_Reputation.GetNumFactions() do
                local factionInfo = C_Reputation.GetFactionDataByIndex(i)
                if factionInfo and not factionInfo.isHeader and factionInfo.factionID then
                    pendingRepCheck.factions[factionInfo.factionID] = {
                        standing = factionInfo.currentStanding,
                        threshold = factionInfo.currentReactionThreshold
                    }
                end
            end
        end

        UpdateRewardData(qID)
    end
end

Handlers["QUEST_ACCEPTED"] = function(qID)
    local q = QuestKeeper.GetOrCreateQuest(qID)
    if q then
        q.timestamp = time()
        q.status = "inProgress"
        q.acceptedDate = QuestKeeper.GetDate() 
    end
end

Handlers["QUEST_REMOVED"] = function(qID)
    if not C_QuestLog.IsQuestFlaggedCompleted(qID) then
        local q = QuestKeeper.GetOrCreateQuest(qID)
        if q then 
            q.timestamp = time()
            q.status = "abandoned"
            q.completedDate = QuestKeeper.GetDate() 
        end
    end
end

-- Data-driven handler verifying exact internal memory deltas and unexpected gains
Handlers["UPDATE_FACTION"] = function()
    if pendingRepCheck and (GetTime() - pendingRepCheck.timestamp) < 3 then
        local q = QuestKeeperDB[pendingRepCheck.questID]
        if q then
            if type(q.rep) ~= "table" then q.rep = {} end
            local changesFound = false

            for factionID, snapData in pairs(pendingRepCheck.factions) do
                local freshData = C_Reputation.GetFactionDataByID(factionID)
                if freshData then
                    local delta = 0
                    
                    if freshData.currentStanding >= snapData.standing then
                        -- Handle standard gains or standard reductions inside the same tier rank
                        delta = freshData.currentStanding - snapData.standing
                    else
                        -- Handle Tier Threshold Boundary Crossings (Rank Up or Rank Down)
                        if freshData.currentReactionThreshold ~= snapData.threshold then
                            if freshData.currentReactionThreshold > snapData.threshold then
                                -- Rank Level Up: Add remaining progress of old tier to current progress of new tier
                                delta = (freshData.currentReactionThreshold - snapData.standing) + freshData.currentStanding
                            else
                                -- Rank Derank/Drop: Calculate a negative delta across the tier boundary drop
                                delta = freshData.currentStanding - (snapData.threshold - snapData.standing)
                            end
                        else
                            -- Standard negative value progression inside the same tier
                            delta = freshData.currentStanding - snapData.standing
                        end
                    end

                    -- Update database only if a true difference occurred
                    if delta ~= 0 then
                        local recordFound = false
                        
                        -- Track loop updating existing expected predicted rows
                        for _, repData in ipairs(q.rep) do
                            if repData.factionID == factionID then
                                repData.amount = delta
                                repData.state = QuestKeeper.REP_STATES.ACTUAL
                                recordFound = true
                                break
                            end
                        end

                        -- Single dynamic fallback injecting unexpected global rewards or losses
                        if not recordFound then
                            table.insert(q.rep, {
                                factionID = factionID,
                                faction = freshData.name,
                                amount = delta,
                                state = QuestKeeper.REP_STATES.UNEXPECTED
                            })
                        end
                        changesFound = true
                    end
                end
            end

            if #q.rep == 0 then q.rep = nil end

            local targetQuestID = pendingRepCheck and pendingRepCheck.questID
            pendingRepCheck = nil

            if changesFound then
                if QuestKeeper.UpdateList then 
                    QuestKeeper.UpdateList() 
                end
                if QuestKeeper.selectedQuestID == targetQuestID and QuestKeeper.UpdateDetailDisplay then
                    QuestKeeper.UpdateDetailDisplay()
                end
            end
            pendingRepCheck = nil
        end
    end
end

Handlers["ADDON_LOADED"] = function(name)
    if name == "QuestKeeper" then
        QuestKeeper.OnStartup()
    end
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "QUEST_FINISHED" then sessionProcessed = {} return end
    if Handlers[event] then Handlers[event](...) end
end)

for event in pairs(Handlers) do f:RegisterEvent(event) end
f:RegisterEvent("QUEST_FINISHED")
f:RegisterEvent("UPDATE_FACTION")

local function AttachSounds(frame)
    if not frame then return end
    frame:HookScript("OnShow", function() PlaySound(829) end)
    frame:HookScript("OnHide", function() PlaySound(830) end)
end

AttachSounds(QuestListFrame)
AttachSounds(QuestDetailDisplay)
AttachSounds(QuestEditFrame)

QuestListFrame:HookScript("OnHide", function() 
    QuestDetailDisplay:Hide()
    QuestEditFrame:Hide() 
end)
local f = CreateFrame("Frame")
local sessionProcessed = {}
local lastCompletedID = nil
local lastCompletedTime = 0

local function GetOrCreateQuest(qID)
    if not qID or qID <= 0 then return nil end
    if not QuestKeeperDB[qID] then 
        QuestKeeperDB[qID] = { 
            status="discovered", rewardItems={}, handInItems={}, progItems={}, compItems={}, 
            xp=0, money=0, rep="", discoveredDate="Unknown", acceptedDate="Unknown", 
            completedDate="Unknown", timestamp=time(), completionCount=0, 
            completionHistory={}, isDaily=false, isRepeatable=false, isImported=false,
            gossips = {}, objectives = "", description = "",
        } 
    end
    QuestKeeperDB[qID].isImported = false
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
    local q = GetOrCreateQuest(qID)
    if not q then return end
    
    C_Timer.After(0.4, function()
        -- 1. Identify Quest Type
        local isD, isR = GetQuestTypeInfo(qID)
        q.isDaily, q.isRepeatable = isD, isR
        
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
        
        -- 6. Modern Reputation Detection (Priority)
        if q.status ~= "completed" then
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
    local q = GetOrCreateQuest(qID)
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
        UpdateRewardData(qID)
    end
end

Handlers["QUEST_PROGRESS"] = function()
    C_Timer.After(0.15, function()
        local qID = SafeGetQuestID()
        local q = GetOrCreateQuest(qID)
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
    local q = GetOrCreateQuest(qID)
    if q then
        -- Save text and rewards, but not don't change the status
        lastCompletedID, lastCompletedTime = qID, GetTime()
        q.completionText = GetRewardText()
        UpdateRewardData(qID)
    end
end

Handlers["QUEST_TURNED_IN"] = function(qID, xp, money)
    local q = GetOrCreateQuest(qID)
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
    end
end

Handlers["QUEST_ACCEPTED"] = function(qID)
    local q = GetOrCreateQuest(qID)
    if q then
        q.timestamp = time()
        q.status = "inProgress"
        q.acceptedDate = QuestKeeper.GetDate() 
    end
end

Handlers["QUEST_REMOVED"] = function(qID)
    if not C_QuestLog.IsQuestFlaggedCompleted(qID) then
        local q = GetOrCreateQuest(qID)
        if q then 
            q.timestamp = time()
            q.status = "abandoned"
            q.completedDate = QuestKeeper.GetDate() 
        end
    end
end

Handlers["CHAT_MSG_COMBAT_FACTION_CHANGE"] = function(msg)
    -- Using the correct scope for lastCompletedID/Time
    local lastID = lastCompletedID or QuestKeeper.lastCompletedID
    local lastTime = lastCompletedTime or QuestKeeper.lastCompletedTime

    -- Check if a quest was completed in the last 3 seconds
    if lastID and lastTime and (GetTime() - lastTime) < 3 then
        -- Patterns for different localizations and generic gains
        local p1 = FACTION_STANDING_INCREASED:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
        local p2 = FACTION_STANDING_INCREASED_GENERIC:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
        
        local faction, amount = msg:match(p1) or msg:match(p2)

        if faction and amount then
            local q = QuestKeeperDB[lastID]
            if q then
                local exactRep = faction .. " (+" .. amount .. ")"
                print("Current q.rep: ", q.rep)
                
                if q.rep and q.rep ~= "" then
                    -- Escape faction name for safe pattern matching
                    local safeFaction = faction:gsub("([%^%$%%%.%*%+%-%?%[%]])", "%%%1")
                    
                    -- If the faction exists in the string (as a predicted value)
                    if q.rep:find(faction, 1, true) then
                        -- Escape faction name for safe pattern matching
                        local safeFaction = faction:gsub("([%^%$%%%.%*%+%-%?%[%]])", "%%%1")
                        
                        -- This pattern finds the faction name and everything until a comma or end of string.
                        -- It effectively removes the predicted part like "Faction (+5) (?)" 
                        -- and prepares it to be replaced by the exact value.
                        local pattern = safeFaction .. "[^,]*"
                        q.rep = q.rep:gsub(pattern, exactRep)
                    else
                        -- Faction was not predicted: append with (??)
                        q.rep = q.rep .. ", " .. exactRep .. " (??)"
                    end
                else
                    q.rep = exactRep .. " (??)"
                end

                print("Current q.rep: ", q.rep)

                -- Refresh UI if the selected quest is the one being updated
                if QuestKeeper.selectedQuestID == lastID then
                    QuestKeeper.UpdateDetailDisplay()
                end
            end
        end
    end
end

Handlers["ADDON_LOADED"] = function(name)
    if name == "QuestKeeper" then
        C_Timer.After(2, function() QuestKeeper.ValidateDatabase() end)
    end
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "QUEST_FINISHED" then sessionProcessed = {} return end
    if Handlers[event] then Handlers[event](...) end
end)

for event in pairs(Handlers) do f:RegisterEvent(event) end
f:RegisterEvent("QUEST_FINISHED")

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
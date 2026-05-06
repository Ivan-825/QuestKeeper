local f = CreateFrame("Frame")
f:RegisterAllEvents()
f:RegisterEvent("QUEST_FINISHED")
f:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")

local sessionProcessed = {}
local lastCompletedID = nil
local lastCompletedTime = 0

local function GetQuestType(qID)
    local isDaily, isRepeatable, freq = false, false, 0
    if not qID then return isDaily, isRepeatable, freq end
    
    local numAvailable = GetNumAvailableQuests and GetNumAvailableQuests() or 0
    for i=1, numAvailable do
        local t, _, isD, _, isR = GetAvailableQuestInfo(i)
        if t == GetTitleText() then isDaily, isRepeatable, freq = isD, isR, (isD and 1 or (isR and 2 or 0)) end
    end
    
    local numActive = GetNumActiveQuests and GetNumActiveQuests() or 0
    for i=1, numActive do
        local t, _, isD, _, isR = GetActiveQuestInfo(i)
        if t == GetTitleText() then isDaily, isRepeatable, freq = isD, isR, (isD and 1 or (isR and 2 or 0)) end
    end

    if not isDaily and C_QuestLog then
        if C_QuestLog.IsQuestDaily and C_QuestLog.IsQuestDaily(qID) then isDaily, freq = true, 1 end
        if C_QuestLog.GetQuestTagInfo then
            local tag = C_QuestLog.GetQuestTagInfo(qID)
            if tag then
                if tag.tagID == Enum.QuestTag.Daily then isDaily, freq = true, 1
                elseif tag.tagID == Enum.QuestTag.Repeatable then isRepeatable, freq = true, 2 end
            end
        end
    end
    
    if not isDaily and not isRepeatable and C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local idx = C_QuestLog.GetLogIndexForQuestID(qID)
        if idx then
            local info = C_QuestLog.GetInfo(idx)
            if info then 
                freq = info.frequency or 0
                if freq == 1 then isDaily = true elseif freq == 2 then isRepeatable = true end
            end
        end
    end
    return isDaily, isRepeatable, freq
end

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "QUEST_FINISHED" then sessionProcessed = {} return end

    if event == "ADDON_LOADED" and arg1 == "QuestKeeperDB" then
        C_Timer.After(2, function() QuestKeeperDBAddon.ValidateDatabase() end)
        return
    end

    if event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        if lastCompletedID and (GetTime() - lastCompletedTime) < 2 then
            local msg = arg1
            local p1 = FACTION_STANDING_INCREASED:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
            local p2 = FACTION_STANDING_INCREASED_GENERIC:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
            local faction, amount = msg:match(p1)
            if not faction then faction, amount = msg:match(p2) end
            if faction and amount then
                local q = QuestKeeperDB[lastCompletedID]
                if q then
                    local newRep = faction .. " (+" .. amount .. ")"
                    if not q.rep or q.rep == "" then q.rep = newRep
                    elseif not q.rep:find(faction) then q.rep = q.rep .. ", " .. newRep end
                    if QuestKeeperDBAddon.UpdateList then QuestKeeperDBAddon.UpdateList() end
                end
            end
        end
        return
    end

    local qID = (event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED") and arg1 or GetQuestID()
    if not qID or qID == 0 then return end
    
    if not QuestKeeperDB[qID] then 
        QuestKeeperDB[qID] = { status="discovered", rewardItems={}, handInItems={}, progItems={}, compItems={}, xp=0, money=0, rep="", discoveredDate="Unknown", acceptedDate="Unknown", completedDate="Unknown", timestamp=time(), completionCount=0, completionHistory={}, isDaily=false, isRepeatable=false } 
    end
    
    local q = QuestKeeperDB[qID]
    q.timestamp = time()
    q.isImported = false
    if GetTitleText() and GetTitleText() ~= "" then q.title = GetTitleText() end

    if q.status == "completed" and not q.isDaily and not q.isRepeatable then
        if not sessionProcessed[qID] then
            q.isRepeatable, q.status = true, "discovered"
            sessionProcessed[qID] = true
        end
    end

    if event == "QUEST_DETAIL" or event == "QUEST_COMPLETE" then
        if event == "QUEST_COMPLETE" then lastCompletedID, lastCompletedTime = qID, GetTime() end

        local isD, isR, fVal = GetQuestType(qID)
        if isD then q.isDaily, q.isRepeatable = true, false elseif isR then q.isDaily, q.isRepeatable = false, true end

        C_Timer.After(0.4, function()
            local isD2, isR2 = GetQuestType(qID)
            if isD2 then q.isDaily, q.isRepeatable = true, false elseif isR2 then q.isDaily, q.isRepeatable = false, true end

            if event == "QUEST_DETAIL" then
                q.introduction, q.description, q.discoveredDate = GetQuestText(), GetObjectiveText(), QuestKeeperDBAddon.GetDate()
                q.xp, q.money = GetRewardXP(), GetRewardMoney()
                q.rewardItems, q.handInItems = {}, {}

                local sName, sTex, sPoints = GetRewardSkillPoints()
                if sName and type(sPoints) == "number" and sPoints > 0 then
                    q.skillReward = { name = sName, tex = sTex, amount = sPoints }
                end

                local currencies = C_QuestLog.GetQuestRewardCurrencies(qID)
                if currencies and #currencies > 0 then
                    q.awards = {}
                    for _, info in ipairs(currencies) do
                        table.insert(q.awards, { id = info.currencyID, name = info.name, amount = info.totalRewardAmount, tex = info.texture })
                    end
                end

                local nC = GetNumQuestChoices and GetNumQuestChoices() or 0
                for i=1, nC do local s,l = pcall(GetQuestItemLink,"choice",i) if s and l then table.insert(q.rewardItems, tonumber(strmatch(l,"item:(%d+)"))) end end
                local nR = GetNumQuestRewards and GetNumQuestRewards() or 0
                for i=1, nR do local s,l = pcall(GetQuestItemLink,"reward",i) if s and l then table.insert(q.rewardItems, tonumber(strmatch(l,"item:(%d+)"))) end end
                local nI = GetNumQuestItems and GetNumQuestItems() or 0
                for i=1, nI do local s,l = pcall(GetQuestItemLink,"required",i) if s and l then table.insert(q.handInItems, tonumber(strmatch(l,"item:(%d+)"))) end end
            else
                q.status, q.completedDate = "completed", QuestKeeperDBAddon.GetDate()
                q.xp, q.money = GetRewardXP(), GetRewardMoney()
                if q.isDaily or q.isRepeatable then
                    q.completionCount = (q.completionCount or 0) + 1
                    if not q.completionHistory then q.completionHistory = {} end
                    table.insert(q.completionHistory, QuestKeeperDBAddon.GetDate())
                end
            end
            
            local rData = ""
            local nF = GetNumRewardFactions and GetNumRewardFactions() or 0
            for i=1, nF do 
                local n, _, g = GetRewardFactionInfo(i)
                if n then rData = rData .. n .. " (+" .. g .. "), " end 
            end
            if rData ~= "" then q.rep = rData:sub(1, -3) end

            if QuestKeeperDBAddon.UpdateList then QuestKeeperDBAddon.UpdateList() end
        end)
    elseif event == "QUEST_ACCEPTED" then q.status, q.acceptedDate = "inProgress", QuestKeeperDBAddon.GetDate()
    elseif event == "QUEST_PROGRESS" then 
        q.progressText, q.progItems = GetProgressText(), {}
        local nI = GetNumQuestItems and GetNumQuestItems() or 0
        for i=1, nI do local s, l = pcall(GetQuestItemLink, "required", i) if s and l then table.insert(q.progItems, tonumber(strmatch(l, "item:(%d+)"))) end end
    elseif event == "QUEST_COMPLETE" then
        q.compItems = {}
        local nC = GetNumQuestChoices and GetNumQuestChoices() or 0
        for i=1, nC do local s,l = pcall(GetQuestItemLink,"choice",i) if s and l then table.insert(q.compItems, tonumber(strmatch(l,"item:(%d+)"))) end end
    elseif event == "QUEST_REMOVED" and not C_QuestLog.IsQuestFlaggedCompleted(qID) then q.status, q.completedDate = "abandoned", QuestKeeperDBAddon.GetDate() end
end)

QuestListFrame:SetScript("OnShow", function() PlaySound(829) end)
QuestListFrame:SetScript("OnHide", function() PlaySound(830); QuestDetailDisplay:Hide(); QuestEditFrame:Hide() end)
QuestDetailDisplay:SetScript("OnShow", function() PlaySound(829) end)
QuestDetailDisplay:SetScript("OnHide", function() PlaySound(830) end)
QuestEditFrame:SetScript("OnShow", function() PlaySound(829) end)
QuestEditFrame:SetScript("OnHide", function() PlaySound(830) end)
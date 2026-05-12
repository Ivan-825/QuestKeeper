local statusMap = {
    discovered = "|cffaaaaaaDiscovered|r",
    inProgress = "|cffffff00In Progress|r",
    completed  = "|cff00ff00Completed|r",
    abandoned  = "|cffff0000Abandoned|r"
}

function QuestKeeperDBAddon.UpdateDetailDisplay()
    local qID = QuestKeeperDBAddon.selectedQuestID
    local q = QuestKeeperDB[qID]
    
    if not q then return end

    -- 1. Fixed Header (Title)
    local titleText = q.title or "Unknown Quest"
    if q.isDaily then
        titleText = "|cff00ccff" .. titleText .. " [Daily]|r"
    elseif q.isRepeatable then
        titleText = "|cff00ff00" .. titleText .. " [Repeatable]|r"
    end
    QuestDetailDisplay.titleText:SetText(titleText)
    
    -- 2. Fixed Header (Metadata)
    local statusText = statusMap[q.status] or q.status or "Unknown"
    local cDate = (q.completedDate and q.completedDate ~= "") and q.completedDate or "Unknown"
    local aDate = (q.acceptedDate and q.acceptedDate ~= "") and q.acceptedDate or "Unknown"
    local dDate = (q.discoveredDate and q.discoveredDate ~= "") and q.discoveredDate or "Unknown"
    
    QuestDetailDisplay.metaText:SetText(string.format(
        "ID: %d | Status: %s\n" ..
        "|cffaaaaaaDiscovered:|r %s\n" ..
        "|cffaaaaaaAccepted:|r %s\n" ..
        "|cffaaaaaaCompleted/Abandoned:|r %s", 
        q.id or qID, statusText, dDate, aDate, cDate
    ))

    -- 3. Pagination UI
    local numG = (q.gossips and #q.gossips) or 0
    if numG > 1 then
        QuestDetailDisplay.gossipHeader:Show()
        QuestDetailDisplay.gossipPageText:SetText(string.format("Introduction %d / %d", QuestKeeperDBAddon.currentGossipIndex, numG))
        QuestDetailDisplay.prevGossip:SetEnabled(QuestKeeperDBAddon.currentGossipIndex > 1)
        QuestDetailDisplay.nextGossip:SetEnabled(QuestKeeperDBAddon.currentGossipIndex < numG)
    else
        QuestDetailDisplay.gossipHeader:Hide()
    end

    -- 4. Construct HTML Content
    local currentGossip = (q.gossips and q.gossips[QuestKeeperDBAddon.currentGossipIndex]) or q.introduction or "No introduction recorded."
    
    local html = "<html><body>"
    
    -- INTRODUCTION
    html = html .. "<p>|cff00ff00[Introduction]:|r<br/>" .. Sanitize(currentGossip) .. "</p><br/>"
    
    -- DESCRIPTION
    html = html .. "<p>|cff00ff00[Description]:|r<br/>" .. Sanitize(q.description) .. "</p><br/>"
    
    -- OBJECTIVES
    html = html .. "<p>|cff00ff00[Objectives]:|r<br/>" .. Sanitize(q.objectives) .. "</p>"

    -- Hand-in Items
    if q.handInItems and #q.handInItems > 0 then
        for _, id in ipairs(q.handInItems) do
            html = html .. QuestKeeperDBAddon.GetItemHTML(id, "|cff888888Requires:|r")
        end
    end
    html = html .. "<br/>"

    -- REWARDS SECTION
    if (q.xp and q.xp > 0) or (q.money and q.money > 0) or (q.rewardItems and #q.rewardItems > 0) or (q.rep and q.rep ~= "") then
        html = html .. "<p>|cff00ff00[Rewards]:|r</p>"
        
        if q.xp and q.xp > 0 then 
            html = html .. "<p>" .. "XP: " .. q.xp .. "</p>" 
        end
        
        if q.money and q.money > 0 then 
            html = html .. "<p>" .. "Gold: " .. GetCoinTextureString(q.money) .. "</p>" 
        end
        
        -- Reward Items
        if q.rewardItems then
            for _, id in ipairs(q.rewardItems) do
                html = html .. QuestKeeperDBAddon.GetItemHTML(id, "|cff888888Grants:|r")
            end
        end

        if q.awards then
            for _, info in ipairs(q.awards) do
                html = html .. QuestKeeperDBAddon.GetItemHTML(info.id, "|cff888888Currencies:|r", true)
            end
        end

        if q.skillReward and q.skillReward.amount > 0 then
            local s = q.skillReward
            local skillIcon = string.format("|T%d:16:16:0:0|t", s.tex or 134400)
            html = html .. string.format("<p>|cff888888Skills:|r %s %s (+%d)</p>", skillIcon, s.name, s.amount)
        end

        -- Reputation
        if q.rep and q.rep ~= "" then
            local isCompleted = (q.status == "completed")
            
            -- 1. Format the block: Replace commas with line breaks
            local repHTML = q.rep:gsub(", ", "<br/>")

            -- 2. Apply colors using a function match
            -- This matches each "line" and colors it based on the symbols present
            repHTML = repHTML:gsub("([^<>]+)(<?/?%a*/?>?)", function(line, tag)
                local result = line
                if line:find("%%?%%?") then -- (??) Predicted
                    local color = isCompleted and "|cff888888" or "|cffeee8aa"
                    result = color .. line .. "|r"
                elseif line:find("%%?") then -- (?) Unexpected
                    result = "|cffeee8aa" .. line .. "|r"
                end
                return result .. tag -- Verified (No change)
            end)

            html = html .. "<p>|cffa335ee[Reputation]:|r<br/>" .. repHTML .. "</p>"
        end
    end

    -- IN PROGRESS
    if q.progressText ~= "" or (q.progItems and #q.progItems > 0) then
        html = html .. "<p>|cff00ff00[In Progress]:|r<br/>" .. Sanitize(q.progressText) .. "</p>"
        if q.progItems and #q.progItems > 0 then
            for _, id in ipairs(q.progItems) do
                html = html .. QuestKeeperDBAddon.GetItemHTML(id, "|cff888888Mentions:|r")
            end
        end
        html = html .. "<br/>"
    end
    
    -- COMPLETION
    local compHeader = (q.isDaily or q.isRepeatable) and ("[Completion] (" .. (q.completionCount or 0) .. " times):") or "[Completion]:"
    html = html .. "<p>|cff00ff00" .. compHeader .. "|r<br/>" .. Sanitize(q.completionText) .. "</p>"

    -- HISTORY
    if (q.isDaily or q.isRepeatable) and q.completionHistory and #q.completionHistory > 0 then
        html = html .. "<br/><p>|cffaaaaaaHistory:|r</p>"
        for _, date in ipairs(q.completionHistory) do
            html = html .. "<p>" .. "- " .. date .. "</p>"
        end
    end

    html = html .. "</body></html>"

    -- Render and Scroll update
    QuestDetailDisplay.content:SetHeight(0)
    QuestDetailDisplay.content:SetText(html)
    QuestDetailDisplay.content:SetHeight(QuestDetailDisplay.content:GetContentHeight() + 50)
    
    QuestDetailDisplay:Show()
end
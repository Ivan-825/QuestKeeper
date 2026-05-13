-- Text Sanitization for safe HTML texts
function QuestKeeper.Sanitize(text)
    if not text or text == "" or text == "No data" then return "No data recorded." end
    local clean = text
    
    -- Handle & char
    clean = clean:gsub("&", "&amp;")
    
    -- handle < and >
    clean = clean:gsub("<", "&lt;")
    clean = clean:gsub(">", "&gt;")
    
    -- handle "
    clean = clean:gsub("\"", "&quot;")
    
    -- linebreak
    clean = clean:gsub("\n", "<br/>")
    
    return clean
end

-- Handle both Items and Currencies with asynchronous data pre-loading guards
function QuestKeeper.GetItemHTML(id, label, isCurrency)
    if not id or id == 0 then return "" end
    
    if isCurrency then
        -- Award/Currency handling
        local link = C_CurrencyInfo.GetCurrencyLink(id, 0)
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        local tex = info and info.iconFileID or 134400
        if link then
            return string.format("<p>%s |T%d:16:16:0:0|t %s</p>", label, tex, link)
        end
    else
        -- Cross-version compatibility: Check if data is locally available in client cache
        local _, link, _, _, _, _, _, _, _, tex = GetItemInfo(id)
        
        if link then 
            -- Data is already cached and ready to display instantly
            return string.format("<p>%s |T%s:16:16:0:0|t %s</p>", label, tex, link) 
        else
            -- Data is missing: Safe asynchronous fallback to request item data from server
            if C_Item and C_Item.RequestLoadItemDataByID then
                -- Blizzard automatically fetches the item data into cache upon this call
                C_Item.RequestLoadItemDataByID(id)
                
                -- Dynamic lightweight check loop to redraw the UI once data packet arrives
                C_Timer.After(0.5, function()
                    if QuestKeeper.selectedQuestID and QuestKeeper.UpdateDetailDisplay then
                        QuestKeeper.UpdateDetailDisplay()
                    end
                end)
            end
        end
    end
    
    -- Temporary fluid fallback during initial network frame loads
    return string.format("<p>%s ID: %d (Loading...)</p>", label, id)
end

function GetPredictedQuestReputationRewards(qID)
    local repEntries = {}
    local numRepRewards = GetNumQuestLogRewardFactions and GetNumQuestLogRewardFactions(qID) or 0
    
    -- Build a dynamic lookup table once for fallback name-to-ID matching
    local factionLookup = {}
    if numRepRewards == 0 or (C_Reputation and C_Reputation.GetFactionDataByID) then
        for i = 1, C_Reputation.GetNumFactions() do 
            local factionInfo = C_Reputation.GetFactionDataByIndex(i)
            if factionInfo and factionInfo.name and factionInfo.factionID then
                factionLookup[factionInfo.name] = factionInfo.factionID
            end
        end
    end
    
    if numRepRewards > 0 then
        for i = 1, numRepRewards do
            local factionID, amount = GetQuestLogRewardFactionInfo(i, qID)
            if factionID then
                local factionName
                if C_Reputation and C_Reputation.GetFactionDataByID then
                    local data = C_Reputation.GetFactionDataByID(factionID)
                    factionName = data and data.name
                end

                if factionName and amount and amount > 0 then
                    -- Store structured data including the essential factionID
                    table.insert(repEntries, {
                        factionID = factionID,
                        faction = factionName,
                        amount = amount / 100,
                        state = QuestKeeper.REP_STATES.PREDICTION
                    })
                end
            end
        end
    end

    if #repEntries == 0 then
        local numF = GetNumRewardFactions and GetNumRewardFactions() or 0
        for i = 1, numF do
            local name, _, amount = GetRewardFactionInfo(i)
            if name then 
                local resolvedID = factionLookup[name]
                -- Fallback mechanics for active quest completion windows
                table.insert(repEntries, {
                    factionID = resolvedID,
                    faction = name,
                    amount = amount,
                    state = QuestKeeper.REP_STATES.PREDICTION
                })
            end
        end
    end
    
    -- Returns the structured table
    return repEntries
end
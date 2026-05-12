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
    
    -- de-color
    --clean = clean:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    
    --linebreak
    clean = clean:gsub("\n", "<br/>")
    
    return clean
end

-- Handle both Items and Currencies
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
        -- Standard Item handling
        local info = C_Item.GetItemInfo(id) -- Use C_Item for Midnight compatibility
        local _, link, _, _, _, _, _, _, _, tex = GetItemInfo(id)
        if link then 
            return string.format("<p>%s |T%s:16:16:0:0|t %s</p>", label, tex, link) 
        end
    end
    
    -- Fallback while loading
    return string.format("<p>%s ID: %d (Loading...)</p>", label, id)
end

-- Tooltip handling for all link types
function QuestKeeper.HandleHyperlinkEnter(self, link)
    if not link then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    
    -- Midnight compatibility: ensure currency/item links both work
    local linkType = string.match(link, "(%a+):")
    if linkType == "currency" or linkType == "item" then
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end
end

function GetPredictedQuestReputationRewards(qID)
    local repEntries = {}
    local numRepRewards = GetNumQuestLogRewardFactions and GetNumQuestLogRewardFactions(qID) or 0
    
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
                    -- Keep raw amount for now, we will overwrite with CHAT_MSG later
                    table.insert(repEntries, factionName .. " (+" .. amount/100 .. ")(?)")
                end
            end
        end
    end

    if #repEntries == 0 then
        local numF = GetNumRewardFactions and GetNumRewardFactions() or 0
        for i = 1, numF do
            local name, _, amount = GetRewardFactionInfo(i)
            if name then table.insert(repEntries, name .. " (+" .. amount .. ")(?)") end
        end
    end
    return table.concat(repEntries, ", ")
end
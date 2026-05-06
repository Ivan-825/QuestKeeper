-- Handle both Items and Currencies
function QuestKeeperDBAddon.GetItemHTML(id, label, isCurrency)
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
function QuestKeeperDBAddon.HandleHyperlinkEnter(self, link)
    if not link then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    
    -- Midnight compatibility: ensure currency/item links both work
    local linkType = string.match(link, "(%a+):")
    if linkType == "currency" or linkType == "item" then
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end
end
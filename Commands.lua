SLASH_QUESTKEEPER1 = "/qk"
SLASH_QUESTKEEPER2 = "/questkeeper"
SlashCmdList["QUESTKEEPER"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    
    if cmd == "show" then
        QuestKeeperSettings.MinimapHidden = false
        UpdatePos()
    elseif cmd == "hide" then
        QuestKeeperSettings.MinimapHidden = true
        UpdatePos()
    elseif cmd == "reset" then
        QuestKeeperSettings.MinimapPos = 45
        QuestKeeperSettings.MinimapHidden = false
        UpdatePos()
    elseif cmd == "delete" then
        local qID = tonumber(arg) 
        
        if qID then
            if QuestKeeperDB[qID] then
                local questTitle = QuestKeeperDB[qID].title or "Ismeretlen"
                
                QuestKeeperDB[qID] = nil 
                
                print("|cffabd473QuestKeeper:|r Quest " .. questTitle .. " deleted from database. (ID: " .. qID .. ")")
                if QuestListFrame:IsShown() then 
                    QuestKeeperDBAddon.UpdateList() 
                end
            else
                print("|cffabd473QuestKeeper:|r Quest with id " .. qID .. " does not exist or is not present in the database.")
            end
        else
            print("|cffabd473QuestKeeper:|r Invalid quest id!")
        end

    else
        if QuestListFrame:IsShown() then QuestListFrame:Hide() else QuestKeeperDBAddon.UpdateList(); QuestListFrame:Show() end
    end
end
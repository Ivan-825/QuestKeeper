if not QuestKeeperDB then QuestKeeperDB = {} end
if type(QuestKeeperDBMinimapIconPos) ~= "number" then QuestKeeperDBMinimapIconPos = 45 end

QuestKeeper = {
    currentSort = { column = "timestamp", order = "desc" },
    headers = {},
    buttons = {},
    version = C_AddOns.GetAddOnMetadata("QuestKeeper", "Version") or "?",
    LATEST_DB_VERSION = 2
}

if not QuestKeeperConfig then 
    QuestKeeperConfig = { 
        dbVersion = QuestKeeper.LATEST_DB_VERSION
    } 
end

function QuestKeeper.GetDate() return date("%y-%m-%d %H:%M:%S") end
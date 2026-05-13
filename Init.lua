if not QuestKeeperDB then QuestKeeperDB = {} end
if type(QuestKeeperDBMinimapIconPos) ~= "number" then QuestKeeperDBMinimapIconPos = 45 end

QuestKeeper = {
    -- Constants
    LATEST_DB_VERSION = 2,

    currentSort = { column = "timestamp", order = "desc" },
    headers = {},
    buttons = {},

    -- Metadata
    version = C_AddOns.GetAddOnMetadata("QuestKeeper", "Version") or "?"
}

if not QuestKeeperConfig then 
    QuestKeeperConfig = { 
        dbVersion = 1
    } 
end

QuestKeeper.DB_STATES = {
    LOADING = 1,
    MIGRATING = 2,
    READY = 3,
    LOCKED = 4,
    ERROR = 5
}
QuestKeeper.DB_STATE = QuestKeeper.DB_STATES.LOADING

function QuestKeeper.GetDate() return date("%y-%m-%d %H:%M:%S") end

QuestKeeper.REP_STATES = {
    PREDICTION = 1,  -- Marked with (?) in UI
    UNEXPECTED = 2,  -- Marked with (??) in UI
    ACTUAL = 3       -- Confirmed and verified reward
}
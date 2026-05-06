if not QuestKeeperDB then QuestKeeperDB = {} end
if type(QuestKeeperDBMinimapIconPos) ~= "number" then QuestKeeperDBMinimapIconPos = 45 end

QuestKeeperDBAddon = {
    currentSort = { column = "timestamp", order = "desc" },
    headers = {},
    buttons = {}
}

function QuestKeeperDBAddon.GetDate() return date("%y-%m-%d %H:%M:%S") end

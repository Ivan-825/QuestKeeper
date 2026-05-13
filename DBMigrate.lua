function QuestKeeper.MigrateDatabase()
    if not QuestKeeperConfig then QuestKeeperConfig = {dbVersion = 1} end
    
    local current = QuestKeeperConfig.dbVersion
    local target = QuestKeeper.LATEST_DB_VERSION

    if not (current or target) then
        print("|cffff4d4d[CRITICAL] QuestKeeper:|r Failed to migrate database due to missing db version metadata. Functionality is going to degrade overtime unless fixed.")
        print("|cffabd473Find help here:|r |cff00ccffhttps://github.com/Ivan-825/QuestKeeper|r")
        return
    end

    if current >= target then return end

    QuestKeeper.DB_STATE = QuestKeeper.DB_STATES.MIGRATING

    print("|cffabd473QuestKeeper:|r Starting database migration (v" .. current .. " -> v" .. target .. ")...")

    -- Sequential execution of local migration functions
    if current < 2 then
        --Migrate_v1_to_v2()
        current = 2
    end

    --QuestKeeperConfig.dbVersion = current
    print("|cffabd473QuestKeeper:|r Migration complete. Now at v" .. current)
end






-- Documenting: Converts legacy string reputation to structured tables and applies sparse data principles
local function Migrate_v1_to_v2()
    --print("|cffabd473QuestKeeper:|r Step 1: Parsing reputation records and cleaning legacy databases...")
    
    for qID, data in pairs(QuestKeeperDB) do
        if type(data) == "table" then
            -- 1. Initialize the modern reputation structure
            local reputation = {}

            -- 2. Process legacy string format: "Faction Name (+Amount)(?)"
            if type(data.rep) == "string" and data.rep ~= "" then
                for faction, amount, status in data.rep:gmatch("([^,%(]+)%s*%(%+(%d+%.?%d*)%)%s*%((%?*)%)") do
                    -- Determine the strict enum state based on the punctuation marks
                    local repState = QuestKeeper.REP_STATES.ACTUAL
                    if status == "?" then
                        repState = QuestKeeper.REP_STATES.PREDICTION
                    elseif status == "??" then
                        repState = QuestKeeper.REP_STATES.UNEXPECTED
                    end
                    table.insert(reputation, {
                        faction = faction:gsub("^%s*", ""):gsub("%s*$", ""), -- Trim white spaces
                        amount = tonumber(amount) or 0,
                        state = repState
                    })
                end
            end

            -- 3. Overwrite the old string field with our new table (or nil if empty to enforce Sparse Data)
            data.rep = reputation
           
            -- 3. SPARSE DATA CLEANUP: Drop empty structures to reduce disk footprint and load times
            if data.rep and #data.rep == 0 then data.rep = nil end
            if data.gossips and #data.gossips == 0 then data.gossips = nil end
            if data.rewardItems and #data.rewardItems == 0 then data.rewardItems = nil end
            if data.handInItems and #data.handInItems == 0 then data.handInItems = nil end
            if data.progItems and #data.progItems == 0 then data.progItems = nil end
            if data.compItems and #data.compItems == 0 then data.compItems = nil end
            if data.objItems and #data.objItems == 0 then data.objItems = nil end
            if data.completionHistory and #data.completionHistory == 0 then data.completionHistory = nil end

            -- Drop empty metadata strings or defaults that carry no actual information
            if data.introduction == "" or data.introduction == "N/A (Imported)" then data.introduction = nil end
            if data.description == "" or data.description == "N/A (Imported)" then data.description = nil end
            if data.objectives == "" then data.objectives = nil end
            if data.progressText == "" then data.progressText = nil end
            if data.completionText == "" then data.completionText = nil end
            
            -- Keep numbers or booleans only if they deviate from default state
            if data.xp == 0 then data.xp = nil end
            if data.money == 0 then data.money = nil end
            if data.completionCount == 0 then data.completionCount = nil end
            if data.isDaily == false then data.isDaily = nil end
            if data.isRepeatable == false then data.isRepeatable = nil end
            if data.isImported == false then data.isImported = nil end
        end
    end
end

-- Documenting: Main orchestration entry point for incremental, safe updates
function QuestKeeper.MigrateDatabase()
    if not QuestKeeperConfig then QuestKeeperConfig = { dbVersion = 1 } end
    
    local current = QuestKeeperConfig.dbVersion
    local target = QuestKeeper.LATEST_DB_VERSION

    if not current or not target then
        QuestKeeper.DB_STATE = QuestKeeper.DB_STATES.LOCKED
        print("|cffff4d4d[CRITICAL] QuestKeeper:|r Failed to migrate database due to missing db version metadata. Functionality is going to degrade overtime unless fixed.")
        print("|cffabd473Find help here:|r |cff00ccffhttps://github.com/Ivan-825/QuestKeeper|r")
        return
    end

    if current >= target then return end

    QuestKeeper.DB_STATE = QuestKeeper.DB_STATES.MIGRATING
    print("|cffabd473QuestKeeper:|r Starting database migration (v" .. current .. " -> v" .. target .. ")...")

    -- Sequential execution of local migration functions
    if current < 2 then
        Migrate_v1_to_v2()
        current = 2
    end

    -- Future hooks go here cleanly:
    -- if current < 3 then Migrate_v2_to_v3() current = 3 end

    QuestKeeperConfig.dbVersion = current
    print("|cffabd473QuestKeeper:|r Migration complete. Now at v" .. current)
end
if type(QuestKeeperSettings) ~= "table" then QuestKeeperSettings = {} end
if type(QuestKeeperSettings.MinimapPos) ~= "number" then QuestKeeperSettings.MinimapPos = 45 end
if type(QuestKeeperSettings.MinimapHidden) ~= "boolean" then QuestKeeperSettings.MinimapHidden = false end

local mBtn = CreateFrame("Button", "QuestKeeperMinimapButton", Minimap)
mBtn:SetSize(31, 31)
mBtn:SetFrameLevel(10)
mBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = mBtn:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Book_08")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 0)

local border = mBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT", 0, 0)

-- Menu init
local menuFrame = CreateFrame("Frame", "QuestKeeperMinimapMenu", UIParent, "UIDropDownMenuTemplate")

local function InitializeMenu(self, level)
    local info = UIDropDownMenu_CreateInfo()
    info.text = "QuestKeeper"
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
    
    info = UIDropDownMenu_CreateInfo()
    info.text = "Hide Icon"
    info.notCheckable = true
    info.func = function() 
        QuestKeeperSettings.MinimapHidden = true
        mBtn:Hide()
        print("|cffabd473QuestKeeper:|r Minimap button hidden. Use '/qk show' commands to restore icon.")
    end
    UIDropDownMenu_AddButton(info, level)
end

function UpdatePos()
    local angle = rad(QuestKeeperSettings.MinimapPos)
    mBtn:SetPoint("CENTER", Minimap, "CENTER", cos(angle)*80, sin(angle)*80)
    if QuestKeeperSettings.MinimapHidden then mBtn:Hide() else mBtn:Show() end
end

mBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mBtn:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        UIDropDownMenu_Initialize(menuFrame, InitializeMenu, "MENU")
        ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
    else
        if QuestListFrame:IsShown() then 
            QuestListFrame:Hide() 
        else 
            QuestKeeperDBAddon.UpdateList()
            QuestListFrame:Show() 
        end 
    end
end)

mBtn:RegisterForDrag("LeftButton")
mBtn:SetScript("OnDragStart", function(self) 
    self:SetScript("OnUpdate", function()
        local x, y = GetCursorPosition()
        local mx, my = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        QuestKeeperSettings.MinimapPos = deg(atan2(y - my*scale, x - mx*scale))
        UpdatePos()
    end) 
end)

mBtn:SetScript("OnDragStop", function(self) 
    self:SetScript("OnUpdate", nil)
end)

C_Timer.After(1, UpdatePos)
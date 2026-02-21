-- TurtleRestedXP - Draggable rested XP progress bar for Turtle WoW
-- Auto-shows when entering a resting zone, hides when leaving.
-- WoW 1.12 API: handlers use globals `event` / `arg1`, not parameters.

local ADDON_NAME = "TurtleRestedXP"
local userClosed = false

local defaults = { x = 0, y = -200 }

local function GetRestedPercent()
    local exhaustion = GetXPExhaustion()
    local maxXP = UnitXPMax("player")
    if not maxXP or maxXP <= 0 then return nil end
    if not exhaustion or exhaustion <= 0 then return 0 end
    return math.min((exhaustion / (maxXP * 1.5)) * 100, 100)
end

-- Frame
local mainFrame = CreateFrame("Frame", "TurtleRestedXPFrame", UIParent)
mainFrame:SetWidth(200)
mainFrame:SetHeight(30)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:Hide()

local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(mainFrame)
bg:SetTexture(0, 0, 0, 0.65)

mainFrame:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
mainFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

-- Label
local label = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 4, -2)
label:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -18, -2)
label:SetJustifyH("LEFT")
label:SetTextColor(1, 1, 1, 1)
label:SetText("Rested: -")

-- Status bar
local bar = CreateFrame("StatusBar", nil, mainFrame)
bar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 2, -14)
bar:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -2, 2)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetMinMaxValues(0, 100)
bar:SetValue(0)
bar:SetStatusBarColor(0.0, 0.55, 1.0, 1.0)

local barBg = bar:CreateTexture(nil, "BACKGROUND")
barBg:SetAllPoints(bar)
barBg:SetTexture(0.08, 0.08, 0.08, 0.9)

-- Close button
local closeBtn = CreateFrame("Button", nil, mainFrame)
closeBtn:SetWidth(14)
closeBtn:SetHeight(14)
closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -2, -1)

local closeTex = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
closeTex:SetAllPoints(closeBtn)
closeTex:SetJustifyH("CENTER")
closeTex:SetText("|cffff6060x|r")

closeBtn:SetScript("OnEnter", function()
    closeTex:SetText("|cffff2020x|r")
    GameTooltip:SetOwner(closeBtn, "ANCHOR_RIGHT")
    GameTooltip:SetText("Close rested bar", 1, 0.4, 0.4)
    GameTooltip:Show()
end)
closeBtn:SetScript("OnLeave", function()
    closeTex:SetText("|cffff6060x|r")
    GameTooltip:Hide()
end)
closeBtn:SetScript("OnClick", function()
    mainFrame:Hide()
    userClosed = true
end)

-- Update bar values and color
local function UpdateBar()
    local pct = GetRestedPercent()
    if pct == nil then
        bar:SetValue(0)
        bar:SetStatusBarColor(0.45, 0.45, 0.45, 1.0)
        label:SetText("Rested: N/A")
    elseif pct <= 0 then
        bar:SetValue(0)
        bar:SetStatusBarColor(0.45, 0.45, 0.45, 1.0)
        label:SetText("Rested: 0%")
    else
        bar:SetValue(pct)
        bar:SetStatusBarColor(0.0, 0.4 + (pct / 100) * 0.4, 1.0 - (pct / 100) * 0.5, 1.0)
        label:SetText(string.format("Rested: %.1f%%", pct))
    end
end

-- Dragging
mainFrame:SetScript("OnDragStart", function()
    mainFrame:StartMoving()
end)
mainFrame:SetScript("OnDragStop", function()
    mainFrame:StopMovingOrSizing()
    local _, _, _, x, y = mainFrame:GetPoint()
    if TurtleRestedXPDB then
        TurtleRestedXPDB.x = x
        TurtleRestedXPDB.y = y
    end
end)

-- Tooltip
mainFrame:SetScript("OnEnter", function()
    GameTooltip:SetOwner(mainFrame, "ANCHOR_TOP")
    GameTooltip:SetText("Rested XP", 0.0, 0.75, 1.0)
    local pct = GetRestedPercent()
    if pct and pct > 0 then
        local pool = GetXPExhaustion()
        GameTooltip:AddLine(string.format("%.1f%% rested", pct), 1, 1, 1)
        if pool then
            GameTooltip:AddLine(string.format("%d XP in pool", pool), 0.75, 0.75, 0.75)
        end
    else
        GameTooltip:AddLine("No rested XP", 0.75, 0.75, 0.75)
    end
    GameTooltip:AddLine("|cffaaaaaa(Drag to move)|r")
    GameTooltip:Show()
end)
mainFrame:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("UPDATE_EXHAUSTION")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    UpdateBar()
    if event == "PLAYER_UPDATE_RESTING" or event == "PLAYER_ENTERING_WORLD" then
        if IsResting() and not userClosed then
            mainFrame:Show()
        elseif not IsResting() then
            mainFrame:Hide()
            userClosed = false
        end
    end
end)

-- Saved variables: restore position on load
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function()
    if arg1 ~= ADDON_NAME then return end
    if not TurtleRestedXPDB then TurtleRestedXPDB = {} end
    for k, v in pairs(defaults) do
        if TurtleRestedXPDB[k] == nil then TurtleRestedXPDB[k] = v end
    end
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", TurtleRestedXPDB.x, TurtleRestedXPDB.y)
end)

-- RicksMLC_ShowIsoRegionsWindow.lua
-- Created under commission from Rozzler 7 June 2024.
-- 
-- Original Specification:
-- Hi, I was looking for a mod to be developed which would mimic the functionality of the IsoRegion Debug
-- menu from the debug mode but with **only** the functionality of showing collision in its UI view. It
-- also needs to run **outside** of debug mode, so it can be used in regular play.
-- This mod needs to work in multiplayer but I would hope it could work without needing to run on the server.

-- Implementation: 
--  [+] Added a menu option to allow the debug IsoRegionWindow to open when running non-debug.
--  [+] The IsoRegionWindow does not allow editing in non-debug.
--  [+] Multiplayer Tested
-- Additional:
--  [+] Moodles display the Enclosed/Not Enclosed status. (requires MoodleFramework)
--  [+] New menu option shows the player location Enclosed status.
--  [+] Moodle compatible with the "Moodle Quarters" mod
--  [+] The IsoRegions window menu option (ie: all functionalty) can be disabled in modoptions if the user does not wish to see it.
--  [+] The IsoRegions window menu option can be removed using the Sandbox setting "Allow debug window".  The "Is Enabled" moodle toggle is still available.
--  [+] (MP) The IsoRegions window menu option can be visible to Admin only via the sandbox setting "Allow Admin debug window"
--
-- Provides ability to show the IsoRegions Debug Window when running non-debug sessions of Project Zomboid.
-- The IsoRegionsWindow shows the known bounaries (eg walls) of each region and chunk on the map.  
-- This is important to know if you are running a high population game with respawn, and need to "wall-off"
-- sections to prevent respawn.  In the game you can construct a wall and if there is a "pillar" object
-- connecting the walls they will appear to be joined, but in the IsoRegionsWindow it will show a gap.
--
-- This mod therefore is a tool to identify the gaps and take action (usually removing the wooden pillar)
--------------------------------------------------------
if isServer() then return end

RicksMLC_ShowIsoRegionsWindow = {}

RicksMLC_ShowIsoRegionsWindow.settings = RicksMLC_ShowIsoRegionsWindow.settings or {}

RicksMLC_ShowIsoRegionsWindow.settings.ShowMoodle = false

-- B42 : Change to PZAPI.ModOptions
local LocalModOptions = {
    options = nil,
    ShowMenuItem = nil
}

LocalModOptions.init = function()
    --DebugLog.log(DebugType.Mod, "RicksMLC_ShowIsoRegionsWindow LocalModOptions:init()")
    options = PZAPI.ModOptions:create("RicksMLC_ShowIsoRegionsWindow", "Rick's MLC Show IsoRegionsWindow")
    ShowMenuItem = options:addTickBox("0", getText("UI_RicksMLCShowIsoRegionsWindow_Options_ShowMenuItem"), true, getText("UI_RicksMLCShowIsoRegionsWindow_Options_ShowMenuItem_ToolTip"))
end

function LocalModOptions.IsShowMenuItem()
    local options = PZAPI.ModOptions:getOptions("RicksMLC_ShowIsoRegionsWindow")
    local option = options:getOption("0")
    return option:getValue()
end


require "MF_ISMoodle"

local RicksMLC_EnclosedMoodle = "RicksMLC_Enclosed"
if MF then
    MF.createMoodle(RicksMLC_EnclosedMoodle)
end

function RicksMLC_ShowIsoRegionsWindow.GetEnclosedStatus(plr)
    local plrX = plr:getX()
    local plrY = plr:getY()
    local plrZ = math.floor(plr:getZ())
    local isoWorldRegion = IsoRegions.getIsoWorldRegion(plrX, plrY, plrZ)
    if isoWorldRegion then
        return isoWorldRegion:isEnclosed()
    end
    return false
end

function RicksMLC_ShowIsoRegionsWindow.SetMoodleValue(value)
    if not MF then return end
    local moodle = MF.getMoodle(RicksMLC_EnclosedMoodle, getPlayer():getPlayerNum())
    moodle:setValue(value)
end

function RicksMLC_ShowIsoRegionsWindow.UpdateEnclosedMoodle()
    if RicksMLC_ShowIsoRegionsWindow.GetEnclosedStatus(getPlayer()) then
        RicksMLC_ShowIsoRegionsWindow.SetMoodleValue(0.6) -- float 0.6 is default good level 1
        return
    end
    RicksMLC_ShowIsoRegionsWindow.SetMoodleValue(0.4) -- float 0.4 is default bad level 1.
end

function RicksMLC_ShowIsoRegionsWindow.InitShowMoodleAtStart()
    local modData = getPlayer():getModData()["RicksMLC_ShowIsoRegionsWindow"]
    if not modData then
        getPlayer():getModData()["RicksMLC_ShowIsoRegionsWindow"] = {ShowMoodleAtStart = RicksMLC_ShowIsoRegionsWindow.settings.ShowMoodle}
    else
        RicksMLC_ShowIsoRegionsWindow.settings.ShowMoodle = modData.ShowMoodleAtStart
    end
end

function RicksMLC_ShowIsoRegionsWindow.UpdateShowMoodleAtStart()
    getPlayer():getModData()["RicksMLC_ShowIsoRegionsWindow"]["ShowMoodleAtStart"] = RicksMLC_ShowIsoRegionsWindow.settings.ShowMoodle
end


function RicksMLC_ShowIsoRegionsWindow.ToggleMoodle()
    RicksMLC_ShowIsoRegionsWindow.settings.ShowMoodle = not RicksMLC_ShowIsoRegionsWindow.settings.ShowMoodle
    RicksMLC_ShowIsoRegionsWindow.RefreshShowMoodleState()
    RicksMLC_ShowIsoRegionsWindow.UpdateShowMoodleAtStart()
end

function RicksMLC_ShowIsoRegionsWindow.CreateMoodleToggleMenuItem(optionOwner, worldObjects, playerObj)
    local option = optionOwner:addOption(getText("ContextMenu_RicksMLCToggleIsEnclosedMoodle"), worldObjects, RicksMLC_ShowIsoRegionsWindow.ToggleMoodle) -- Toggle Moodle
    local tooltip = ISWorldObjectContextMenu:addToolTip()
    tooltip.description = getText("ContextMenu_RicksMLCToggleIsEnclosedMoodle_tooltip")
    option.toolTip = tooltip
    if RicksMLC_ShowIsoRegionsWindow.GetEnclosedStatus(playerObj) then
        option.iconTexture = getTexture("media/ui/RicksMLC_Enclosed-Menu-Green.png")
    else
        option.iconTexture = getTexture("media/ui/RicksMLC_Enclosed-Menu-Red.png")
    end
    return option
end

function RicksMLC_ShowIsoRegionsWindow.IsShowWindowPermitted() 
    return  SandboxVars.RicksMLC_ShowIsoRegionsWindow.AllowShowWindow 
            or (isClient() and (   (SandboxVars.RicksMLC_ShowIsoRegionsWindow.AllowAdminShowWindow and isAdmin())
                                or (SandboxVars.RicksMLC_ShowIsoRegionsWindow.AllowObserverShowWindow and (   isAccessLevel("observer")
                                                                                                           or isAccessLevel("gm") 
                                                                                                           or isAccessLevel("moderator"))
                                   )
                               )
                )
end

function RicksMLC_ShowIsoRegionsWindow.DoContextMenu(player, context, worldobjects, test)
    if not LocalModOptions.IsShowMenuItem() then return end    

    local playerObj = getSpecificPlayer(player)
    if RicksMLC_ShowIsoRegionsWindow.IsShowWindowPermitted() then

        local subMenu = context:getNew(context)
        local option = subMenu:addOption(getText("ContextMenu_RicksMLCShowIsoRegionWindow"), worldobjects, function() IsoRegionsWindow.OnOpenPanel() end, player) -- "Show IsoRegions Debug Window"
        local tooltip = ISWorldObjectContextMenu:addToolTip()
        tooltip.description = getText("ContextMenu_RicksMLCShowIsoRegionWindow_tooltip") .. tostring(RicksMLC_ShowIsoRegionsWindow.GetEnclosedStatus(playerObj))
        option.toolTip = tooltip

        local moodleToggleMenuItem = RicksMLC_ShowIsoRegionsWindow.CreateMoodleToggleMenuItem(subMenu, worldObjects, playerObj)

        local subMenuOption = context:addOption(getText("ContextMenu_RicksMLCIsoRegionsDebug"), nil, nil)
        context:addSubMenu(subMenuOption, subMenu)
    else
        local moodleToggleMenuItem = RicksMLC_ShowIsoRegionsWindow.CreateMoodleToggleMenuItem(context, worldObjects, playerObj)
    end
end

function RicksMLC_ShowIsoRegionsWindow.TurnOnMoodle()
    Events.OnPlayerMove.Remove(RicksMLC_ShowIsoRegionsWindow.UpdateEnclosedMoodle)
    Events.OnPlayerMove.Add(RicksMLC_ShowIsoRegionsWindow.UpdateEnclosedMoodle)
    RicksMLC_ShowIsoRegionsWindow.UpdateEnclosedMoodle()
end

function RicksMLC_ShowIsoRegionsWindow.RefreshShowMoodleState()
    if RicksMLC_ShowIsoRegionsWindow.settings.ShowMoodle then
        RicksMLC_ShowIsoRegionsWindow.TurnOnMoodle()
    else
        RicksMLC_ShowIsoRegionsWindow.SetMoodleValue(0.5) -- neutral value
        Events.OnPlayerMove.Remove(RicksMLC_ShowIsoRegionsWindow.UpdateEnclosedMoodle)
    end
end



local minuteCount = 0
function RicksMLC_ShowIsoRegionsWindow.OnEveryOneMinute()
    minuteCount = minuteCount + 1
    if minuteCount < 1 then return end

    RicksMLC_ShowIsoRegionsWindow.RefreshShowMoodleState()
    Events.EveryOneMinute.Remove(RicksMLC_ShowIsoRegionsWindow.OnEveryOneMinute)
    minuteCount = 0
end

LocalModOptions.init()
function RicksMLC_ShowIsoRegionsWindow.Init()
    DebugLog.log(DebugType.Mod, "RicksMLC_ShowIsoRegionsWindow.Init()")

    
    RicksMLC_ShowIsoRegionsWindow.InitShowMoodleAtStart()
    Events.EveryOneMinute.Add(RicksMLC_ShowIsoRegionsWindow.OnEveryOneMinute)
end

Events.OnGameTimeLoaded.Add(RicksMLC_ShowIsoRegionsWindow.Init)
Events.OnFillWorldObjectContextMenu.Add(RicksMLC_ShowIsoRegionsWindow.DoContextMenu)

---------------------------------------------------------------------------
-- Overrides for IsoRegionsWindow to remove edit tools for non-debug runs
-- ie: not isDebugEnabled()
require "DebugUIs/DebugMenu/IsoRegions/IsoRegionsWindow"

local override_IsoRegionsWindow_onMapRightMouseUp = IsoRegionsWindow.onMapRightMouseUp
function IsoRegionsWindow.onMapRightMouseUp(self, x, y)
    if isDebugEnabled() then
       override_IsoRegionsWindow_onMapRightMouseUp(self, x, y)
    else
       RicksMLC_ShowIsoRegionsWindow.CutDownNonDebug_onMapRightMouseUp(self, x, y)
    end
end

-- This is a copy of the vanilla code, with the edit options removed for non-debug play
function RicksMLC_ShowIsoRegionsWindow.CutDownNonDebug_onMapRightMouseUp(self, x, y)
    self.panning = false
    if not self.mouseMoved then
        local playerNum = 0
        local cellX = self.renderer:uiToWorldX(x) / 300
        local cellY = self.renderer:uiToWorldY(y) / 300
        cellX = math.floor(cellX)
        cellY = math.floor(cellY)
        local context = ISContextMenu.get(playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY())
        --context:addOption("Clear Zombies", cellX, zpopClearZombies, cellY)
        --context:addOption("Spawn Time To Zero", cellX, zpopSpawnTimeToZero, cellY)
        --context:addOption("Spawn Now", cellX, zpopSpawnNow, cellY)
        local worldX = self.renderer:uiToWorldX(x)
        local worldY = self.renderer:uiToWorldY(y)
        if (not self.renderer:isEditingEnabled()) and self.renderer:hasChunkRegion(worldX, worldY) then
            context:addOption("Square Details", self.parent, IsoRegionsWindow.onSquareDetails, worldX, worldY)
        end
        if self.renderer:isHasSelected() then
            context:addOption("Unset selection", self.parent, IsoRegionsWindow.onUnsetSelect, worldX, worldY)
        end

        local subMenu = context:getNew(context)
        for i=1,self.renderer:getZLevelOptionCount() do
            local debugOption = self.renderer:getZLevelOptionByIndex(i-1)
            local option = subMenu:addOption(debugOption:getName(), self.parent, IsoRegionsWindow.onChangeZLevelOption, debugOption)
            if debugOption:getType() == "boolean" then
                subMenu:setOptionChecked(option, debugOption:getValue())
            end
        end
        local subMenuOption = context:addOption("zLevel", nil, nil)
        context:addSubMenu(subMenuOption, subMenu)

        local subMenu = context:getNew(context)
        for i=1,self.renderer:getOptionCount() do
            local debugOption = self.renderer:getOptionByIndex(i-1)
            local option = subMenu:addOption(debugOption:getName(), self.parent, IsoRegionsWindow.onChangeOption, debugOption)
            if debugOption:getType() == "boolean" then
                subMenu:setOptionChecked(option, debugOption:getValue())
            end
        end
        local subMenuOption = context:addOption("Display", nil, nil)
        context:addSubMenu(subMenuOption, subMenu)

        -- Removed the "Other" menu as the actions do not work in non-debug mode.
    end
    return true
end

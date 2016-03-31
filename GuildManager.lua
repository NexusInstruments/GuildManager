------------------------------------------------------------------------------------------------
--  GuildManager ver. @project-version@
--  Build @project-hash@
--  Copyright (c) NexusInstruments. All rights reserved
--
--  https://github.com/NexusInstruments/GuildManager
------------------------------------------------------------------------------------------------
-- GuildManager.lua
------------------------------------------------------------------------------------------------

require "Window"
require "Item"
require "GameLib"

-----------------------------------------------------------------------------------------------
-- GuildManager Definition
-----------------------------------------------------------------------------------------------
local GuildManager= {}
local Utils = Apollo.GetPackage("SimpleUtils").tPackage
local PixiePlot = Apollo.GetPackage("Drafto:Lib:PixiePlot-1.4").tPackage

-----------------------------------------------------------------------------------------------
-- GuildManager constants
-----------------------------------------------------------------------------------------------
local Major, Minor, Patch, Suffix = 1, 0, 0, 0
local AddonName = "GuildManager"
local GUILDMANAGER_CURRENT_VERSION = string.format("%d.%d.%d%s", Major, Minor, Patch, Suffix)

local tDefaultSettings = {
  version = GUILDMANAGER_CURRENT_VERSION,
  user = {
    debug = false
  },
  positions = {
    main = nil
  }
}

local tDefaultState = {
  isOpen = false,

  windows = {           -- These store windows for lists
    main = nil
  },
  listItems = {
    sortingCmpFn = {},
    tabsInfo = {},
    allRosters = {}
  }
}

-----------------------------------------------------------------------------------------------
-- GuildManager Constructor
-----------------------------------------------------------------------------------------------
function GuildManager:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self

  -- Saved and Restored values are stored here.
  o.settings = deepcopy(tDefaultSettings)
  -- Volatile values are stored here. These are impermanent and not saved between sessions
  o.state = deepcopy(tDefaultState)

  return o
end


-----------------------------------------------------------------------------------------------
-- GuildManager Init
-----------------------------------------------------------------------------------------------
function GuildManager:Init()
  local bHasConfigureFunction = true
  local strConfigureButtonText = AddonName
  local tDependencies = {
    -- "UnitOrPackageName",
  }
  Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)

  self.settings = deepcopy(tDefaultSettings)
  -- Volatile values are stored here. These are impermanent and not saved between sessions
  self.state = deepcopy(tDefaultState)
end

-----------------------------------------------------------------------------------------------
-- GuildManager OnLoad
-----------------------------------------------------------------------------------------------
function GuildManager:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("GuildManager.xml")
  self.xmlDoc:RegisterCallback("OnDocLoaded", self)

  Apollo.RegisterEventHandler("Generic_GuildManager", "OnToggleGuildManager", self)
  Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)

  Apollo.RegisterSlashCommand("guildm", "OnSlashCommand", self)

  Apollo.RegisterEventHandler("GuildRoster", "OnGuildRoster", self)
  Apollo.RegisterEventHandler("GuildMemberChange", "OnGuildMemberChange", self) -- General purpose update method
  Apollo.RegisterEventHandler("GuildChange", "OnGuildChanged", self) -- notification that a guild was added / removed.
  Apollo.RegisterEventHandler("GuildName", "OnGuildChanged", self) -- notification that the guild name has changed.
  Apollo.RegisterEventHandler("GuildInvite", "OnGuildInvite", self) -- notification you got a guild/circle invite

  Apollo.RegisterEventHandler("GuildLoaded", "OnGuildLoaded", self) -- notification that your guild or a society has loaded.
  Apollo.RegisterEventHandler("GuildFlags", "OnGuildFlags", self) -- notification that your guild's flags have changed.
  Apollo.RegisterEventHandler("GuildName", "OnGuildName", self) -- notification that the guild name has changed.

  Apollo.GetPackage("Json:Utils-1.0").tPackage:Embed(self)
end

-----------------------------------------------------------------------------------------------
-- GuildManager OnDocLoaded
-----------------------------------------------------------------------------------------------
function GuildManager:OnDocLoaded()
  if self.xmlDoc == nil then
    return
  end

  self.state.windows.main = Apollo.LoadForm(self.xmlDoc, "MainWindow", nil, self)
  self.state.windows.main:Show(false)

  -- Restore positions and junk
  --self:RefreshUI()
end

-----------------------------------------------------------------------------------------------
-- GuildManager OnInterfaceMenuListHasLoaded
-----------------------------------------------------------------------------------------------
function GuildManager:OnInterfaceMenuListHasLoaded()
  Event_FireGenericEvent("InterfaceMenuList_NewAddOn", AddonName, {"Generic_ToggleAddon", "", nil})

  -- Report Addon to OneVersion
  Event_FireGenericEvent("OneVersion_ReportAddonInfo", AddonName, Major, Minor, Patch, Suffix, false)
end

-----------------------------------------------------------------------------------------------
-- GuildManager OnSlashCommand
-----------------------------------------------------------------------------------------------
-- Handle slash commands
function GuildManager:OnSlashCommand(cmd, params)
  args = params:lower():split("[ ]+")

  if args[1] == "debug" then
    self:ToggleDebug()
  elseif args[1] == "show" then
    self:OnToggleGuildManager()
  elseif args[1] == "defaults" then
    self:LoadDefaults()
  else
    Utils:cprint("GuildManager v" .. self.settings.version)
    Utils:cprint("Usage:  /sample <command>")
    Utils:cprint("====================================")
    Utils:cprint("   show           Open Rules Window")
    Utils:cprint("   debug          Toggle Debug")
    Utils:cprint("   defaults       Loads defaults")
  end
end

-----------------------------------------------------------------------------------------------
-- Save/Restore functionality
-----------------------------------------------------------------------------------------------
function GuildManager:OnSave(eType)
  if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end

  return deepcopy(self.settings)
end

function GuildManager:OnRestore(eType, tSavedData)
  if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end

  if tSavedData and tSavedData.user then
    -- Copy the settings wholesale
    self.settings = deepcopy(tSavedData)

    -- Fill in any missing values from the default options
    -- This Protects us from configuration additions in the future versions
    for key, value in pairs(tDefaultSettings) do
      if self.settings[key] == nil then
        self.settings[key] = deepcopy(tDefaultSettings[key])
      end
    end

    -- This section is for converting between versions that saved data differently

    -- Now that we've turned the save data into the most recent version, set it
    self.settings.version = GuildManager_CURRENT_VERSION

  else
    self.settings = deepcopy(tDefaultSettings)
  end
end

-----------------------------------------------------------------------------------------------
-- Utility functionality
-----------------------------------------------------------------------------------------------
function GuildManager:ToggleDebug()
  if self.settings.user.debug then
    self:PrintDB("Debug turned off")
    self.settings.user.debug = false
  else
    self.settings.user.debug = true
    self:PrintDB("Debug turned on")
  end
end

function GuildManager:PrintDB(str)
  if self.settings.user.debug then
    Utils:debug(string.format("[%s]: %s", AddonName, str))
  end
end

function GuildManager:LoadDefaults()
  -- Load Defaults here
  self:RefreshUI()
end

-----------------------------------------------------------------------------------------------
-- GuildManager functionality
-----------------------------------------------------------------------------------------------
function GuildManager:OnGuildRoster(guildCurr, tRoster) -- Event from CPP
local currGID = self:GuildTabID(guildCurr)

if self.state.AllRosters[currGID] == nil then
    self.state.AllRosters[currGID] = {}
    self:UpdateRelations(tRoster, currGID)
end

self:DEBUG("OnGuildRoster Got Data Event from CPP: " .. guildCurr:GetName())

if not self:needRosterUpdate(guildCurr) then return end

self:SetNewRosterForGrid(tRoster, currGID)
end


function GuildManager:OnGuildMemberChange(guildCurr)
    self:DEBUG("OnGuildMemberChange Got Data: " .. guildCurr:GetName())

    --Updating tooltip anyway

    for k, v in pairs(self.state.tabsInfo) do
        if self:isSameGuild(v.sName, v.nType, guildCurr:GetName(), guildCurr:GetType()) then
            self:UpdateOnlineCountFor(v, guildCurr:GetOnlineMemberCount(), guildCurr:GetMemberCount())
        end
    end

    if not self:needRosterUpdate(guildCurr) then return end


    self.kCurrGuild:RequestMembers()
end

function GuildManager:needRosterUpdate(guildCurr)
    if not self:IsVisible() then return false end
    if self.kCurrGuild then
        return self:isSameGuild(self.kCurrGuild:GetName(),
            self.kCurrGuild:GetType(),
            guildCurr:GetName(),
            guildCurr:GetType())
    end

    return false
end

function GuildManager:GuildTabID(guildCurr)
    if guildCurr == nil then return nil end

    for k, v in pairs(self.state.tabsInfo) do
        if self:isSameGuild(v.sName, v.nType, guildCurr:GetName(), guildCurr:GetType()) then
            return k
        end
    end

    return nil
end

function GuildManager:isSameGuild(strName1, nType1, strName2, nType2)
    return strName1 == strName2 and nType1 == nType2
end

function GuildManager:UpdateGuildAndCircleLists()
    -- need this to take rosters for guilds and circles into memory
    -- to show correct common social groups
    local guilds = GuildLib.GetGuilds() or {}
    for key, guildCurr in pairs(guilds) do
        if guildCurr:GetType() == GuildLib.GuildType_Circle
                or guildCurr:GetType() == GuildLib.GuildType_Guild then
            guildCurr:RequestMembers()
        end
    end
end

function GuildManager:UpdateRelations(tRoster, nTabID)
    if nTabID == ViragsSocial.TabGuild or (nTabID >= ViragsSocial.TabCircle1 and nTabID <= ViragsSocial.TabCircle5) then --circle or guild
    for k, v in pairs(tRoster) do
        local resultRel = self.ktRelationsDB[v.strName]
        if resultRel == nil then
            resultRel = {}
            self.ktRelationsDB[v.strName] = resultRel
        end
        resultRel[nTabID] = true
    end
    end
end
-----------------------------------------------------------------------------------------------
-- GuildManagerInstance
-----------------------------------------------------------------------------------------------
local GuildManagerInst = GuildManager:new()
GuildManagerInst:Init()

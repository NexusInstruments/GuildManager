------------------------------------------------------------------------------------------------
-- GuildManager.lua
------------------------------------------------------------------------------------------------
require "Window"

-----------------------------------------------------------------------------------------------
-- GuildManager Definition
-----------------------------------------------------------------------------------------------
local GuildManager= {}
--local Utils = Apollo.GetPackage("SimpleUtils-1.0").tPackage

-----------------------------------------------------------------------------------------------
-- GuildManager constants
-----------------------------------------------------------------------------------------------
local Major, Minor, Patch, Suffix = 1, 0, 0, 0
local AddonName = "GuildManager"
local GUILDMANAGER_CURRENT_VERSION = string.format("%d.%d.%d%s", Major, Minor, Patch)

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
  o.settings = shallowcopy(tDefaultSettings)
  -- Volatile values are stored here. These are impermanent and not saved between sessions
  o.state = shallowcopy(tDefaultState)

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

  self.settings = shallowcopy(tDefaultSettings)
  -- Volatile values are stored here. These are impermanent and not saved between sessions
  self.state = shallowcopy(tDefaultState)
end

-----------------------------------------------------------------------------------------------
-- GuildManager OnLoad
-----------------------------------------------------------------------------------------------
function GuildManager:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("GuildManager.xml")
  self.xmlDoc:RegisterCallback("OnDocLoaded", self)

  Apollo.RegisterEventHandler("Generic_GuildManager", "OnToggleGuildManager", self)
  Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)

  Apollo.RegisterSlashCommand("sample", "OnSlashCommand", self)
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
  self:RefreshUI()
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
    self.tConfig = deepcopy(tDefaultOptions)
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

---------------------------------------------------------------------------------------------------
-- GuildManager General UI Functions
---------------------------------------------------------------------------------------------------
function GuildManager:OnToggleGuildManager()
  if self.state.isOpen == true then
    self.state.isOpen = false
    self:SaveLocation()
    self:CloseMain()
  else
    self.state.isOpen = true
    self.state.windows.main:Invoke() -- show the window
  end
end

function GuildManager:SaveLocation()
  self.settings.positions.main = self.state.windows.main:GetLocation():ToTable()
end

function GuildManager:CloseMain()
  self.state.windows.main:Close()
end

function GuildManager:OnGuildManagerClose( wndHandler, wndControl, eMouseButton )
  self.state.isOpen = false
  self:SaveLocation()
  self:CloseMain()
end

function GuildManager:OnGuildManagerClosed( wndHandler, wndControl )
  self:SaveLocation()
  self.state.isOpen = false
end

---------------------------------------------------------------------------------------------------
-- GuildManager RefreshUI
---------------------------------------------------------------------------------------------------
function GuildManager:RefreshUI()
  -- Location Restore
  if self.settings.positions.main ~= nil and self.settings.positions.main ~= {} then
    locSavedLoc = WindowLocation.new(self.settings.positions.main)
    self.state.windows.main:MoveToLocation(locSavedLoc)
  end
end

function GuildManager:LoadDefaults()
  -- Load Defaults here
  self:RefreshUI()
end
-----------------------------------------------------------------------------------------------
-- GuildManagerInstance
-----------------------------------------------------------------------------------------------
local GuildManagerInst = GuildManager:new()
GuildManagerInst:Init()

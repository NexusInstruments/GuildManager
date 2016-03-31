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

local GuildManager = Apollo.GetAddon("GuildManager")
local Info = Apollo.GetAddonInfo("GuildManager")

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

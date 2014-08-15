-----------------------------------------------------------------------------------------------
-- Client Lua Script for EventManager
-- Wildstar Copyright (c) NCsoft. All rights reserved
-- EventsManager written by Thoughtcrime.  All rights reserved
-- Contribution for whitelist usecase credited to Feyed
-----------------------------------------------------------------------------------------------
 
require "Window"
require "ICCommLib"
 
-----------------------------------------------------------------------------------------------
-- EventManager Module Definition
-----------------------------------------------------------------------------------------------
local EventManager = {}    
tEvents = {}
tEventsBacklog = {}
local tEventHolder = {}
local tMetaData = {nLatestUpdate = 0 ,SyncChannel = "" ,Passphrase = "",tSecurity = {},RequireSecureEvents = false}
local TankRoleStatus = 0	
local HealerRoleStatus = 0
local DPSRoleStatus = 0
local MetaData = ""
local EventsChan = ""
local tSecurity = {}
local setmetatable = setmetatable
local Apollo = Apollo
local GameLib = GameLib
local XmlDoc = XmlDoc
local ApolloTimer = ApolloTimer
local ICCommLib = ICCommLib
local Print = Print
local pairs = pairs
local ipairs = ipairs
local table = table
local tonumber = tonumber
local string = string
local os = os
local Event_FireGenericEvent = Event_FireGenericEvent
local nEventId = ""
local ChatSystemLib = ChatSystemLib
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressedFlyby")
local kcrNormalText = ApolloColor.new("UI_BtnTextHoloNormal")

local function SortEventsByDate(a,b)
	return a.nEventSortValue < b.nEventSortValue
end 

local function SortListItems(a,b)
	local aEvent = a:GetData() 
	local bEvent = b:GetData() 
	return aEvent.nSortEventDate < bEvent.nSortEventDate 
end
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function EventManager:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.tItems = {} -- keep track of all the list items
	o.wndSelectedListItem = nil -- keep track of which list item is currently selected

    return o
end

function EventManager:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

function EventManager:OnSave(eLevel)
 if (eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character) then
		return
	end
	local tEvents = self.tEvents
	local tEventsBacklog = self.tEventsBacklog
	local tMetaData = self.tMetaData
	local tSecurity = self.tSecurity	-- added by Feyde

	local tSave = {}
	
	tSave = {tMetaData = tMetaData, tEvents = tEvents, tEventsBacklog = tEventsBacklog, Security = tSecurity}

	return tSave
	
end

function EventManager:OnRestore(eLevel,tSavedData)
	if (eLevel == GameLib.CodeEnumAddonSaveLevel.Character) then
		if tSavedData.tMetaData ~= nil  then
			tMetaData = tSavedData.tMetaData
		end
		if tSavedData.tEvents ~= nil then 
			tEvents = tSavedData.tEvents
		end
		if tSavedData.Security ~= nil then 
			tSecurity = tSavedData.tSecurity
		end	
		if tSavedData.tEventsBacklog ~= nil then
			tEventsBacklog = tSavedData.tEventsBacklog
		end


	end
end	


-----------------------------------------------------------------------------------------------
-- EventManager OnLoad
-----------------------------------------------------------------------------------------------
function EventManager:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("EventManager.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- EventManager OnDocLoaded
-----------------------------------------------------------------------------------------------
function EventManager:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "EventManagerForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
		-- item list
		self.wndItemList = self.wndMain:FindChild("ItemList")
	    self.wndMain:Show(false, true)
		-- New event form
		self.wndNewEvent = Apollo.LoadForm(self.xmlDoc,"NewEventForm",self.wndMain,self)
		self.wndNewEvent:Show(false)
		
		-- Event Signup Form
		self.wndSignUp = Apollo.LoadForm(self.xmlDoc,"SignUpForm",self.wndMain,self)
		self.wndSignUp:Show(false)
		
		-- Options Form
		self.wndOptions = Apollo.LoadForm(self.xmlDoc,"OptionsForm",self.wndMain,self)
		self.wndOptions:Show(false)
		
		-- Delete Confirmation Warning Form
		self.wndDeleteConfirm = Apollo.LoadForm(self.xmlDoc,"DeleteEventConfirmationWarning",nil,self)
		self.wndDeleteConfirm:Show(false)
		
		-- Selected Item Detailed Info Form
		self.wndSelectedListItemDetail = Apollo.LoadForm(self.xmlDoc,"EventDetailForm",self.wndMain,self)
		self.wndSelectedListItemDetail:Show(false)

		self.wndEditEvent = Apollo.LoadForm(self.xmlDoc,"EditEventForm", self.wndMain,self)
		self.wndEditEvent:Show(false)
		
		-- start add by Feyde
		-- Security Form
		self.wndSecurity = Apollo.LoadForm(self.xmlDoc,"SecurityForm",self.wndOptions,self)
		self.wndSecurity:Show(false)
		-- end add by Feyde
	
		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("events",							"OnEventManagerOn",self)
		--Apollo.RegisterSlashCommand("events", 							"OnEventManagerOn", self)
		Apollo.RegisterEventHandler("WindowManagementReady", 			"OnWindowManagementReady", self)
		Apollo.RegisterEventHandler("WindowMove",						"OnWindowMove", self)
		self.timerDelay = ApolloTimer.Create(1, false, "OnDelayTimer", self)


		-- Do additional Addon initialization here
		if tMetaData ~= nil then
			self.tMetaData = tMetaData
			self.tMetaData.nLatestUpdate = self.tMetaData.nLatestUpdate
			if self.tMetaData.SyncChannel ~= "" then 
				EventsChan = ICCommLib.JoinChannel(self.tMetaData.SyncChannel, "OnEventManagerMessage", self)
				Print("Events Manager: Joined sync channel "..self.tMetaData.SyncChannel)
			end
			
		else
			self.tMetaData = {}
			self.tMetaData.nLatestUpdate = 0
		end
		if tEvents ~= nil then
			self.tEvents = tEvents
			for key, EventId in pairs(self.tEvents) do
				if EventId.Detail.tNotAttending == nil then
					self.tEvents[key].Detail.tNotAttending = {{Name = nil}}
				end
			end 
		else self.tEvents = {}
		end

		if tEventsBacklog ~= nil then 
			self.tEventsBacklog = tEventsBacklog
		end
		
		-- start add by Feyde
		if tSecurity ~= nil then
			self.tSecurity = tSecurity
		else
			self.tSecurity = {}
		end
		-- end add by Feyde
		
	end
 local SecurityList = self.tSecurity
end


-----------------------------------------------------------------------------------------------
-- EventManager General Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here
function EventManager:OnDelayTimer()
	if GameLib.GetPlayerUnit() then 
		self.timerDelay = nil 
		--table.sort(tEvents,SortEventsByDate)
		if self.tMetaData.SyncChannel ~= "" then
		self:EventsMessenger()
	end

	
	else self.timerDelay:Start()
	end
end

-- on SlashCommand "/em"
function EventManager:OnEventManagerOn()
	self.wndMain:Invoke() -- show the window
	for key, EventId in pairs(self.tEvents) do
		if EventId.nEventSortValue < tonumber(os.time())-3600 then
			self.tEvents[key] = nil
		end
	end
	-- sort event entries
	--table.sort(self.tEvents,SortEventsByDate)
	--table.sort(self.tEventsBacklog, SortEventsByDate)

		-- populate the item list
	self:PopulateItemList(tEvents)
	
	-- start add by Feyde
	-- populate the security list
	self:PopulateSecurityList()
	-- end add by Feyde
end

function EventManager:OnTankRoleChecked(wndHandler, wndControl, eMouseButton)
	self.TankRoleStatus = 1

end

function EventManager:OnTankRoleUnChecked(wndHandler, wndControl, eMouseButton)
	self.TankRoleStatus = 0
end

function EventManager:OnHealerRoleChecked(wndHandler, wndControl, eMouseButton)
	self.HealerRoleStatus = 1
end

function EventManager:OnHealerRoleUnChecked(wndHandler, wndControl, eMouseButton)
	self.HealerRoleStatus = 0
end

function EventManager:OnDPSRoleChecked(wndHandler, wndControl, eMouseButton)
	self.DPSRoleStatus = 1
end

function EventManager:OnDPSRoleUnChecked(wndHandler, wndControl, eMouseButton)
	self.DPSRoleStatus = 0
end

function EventManager:OnSecurityChecked(wndHandler, wndControl, eMouseButton)
	self.tMetaData.SecurityRequired = true
	if self.wndOptions:IsVisible() == true then
		if self.wndOptions:FindChild("ShowSecurityWhitelist"):IsVisible() == false then
			self.wndOptions:FindChild("ShowSecurityWhitelist"):Show(true)
		end	
	end
	self.wndSecurity:Show(true)
		
end

function EventManager:OnSecurityUnChecked(wndHandler, wndControl, eMouseButton)
	self.tMetaData.SecurityRequired = false
	if self.wndOptions:IsVisible() == true then
		if self.wndOptions:FindChild("ShowSecurityWhitelist"):IsVisible() == true then
			self.wndOptions:FindChild("ShowSecurityWhitelist"):Show(false)
		end
	end
	self.wndSecurity:Show(false)
end

function EventManager:OnSecurityChecked(wndHandler, wndControl, eMouseButton)
	self.tMetaData.SecurityRequired = true
end

function EventManager:OnSecurityWhitelistShow(wndHandler, wndControl, eMouseButton)
	if self.wndSecurity:IsShown() == false then
		self.wndSecurity:Show(true)
	else
		self.wndSecurity:Show(false)
	end
end

function EventManager:CreateSortValue(tEventDetail)
	local Year = tEventDetail.Year
	local Month = tEventDetail.Month
	local Day = tEventDetail.Day
	local Hour = tEventDetail.Hour
	local Minute = tEventDetail.Minute
	local AmPm = tEventDetail.AmPm
	if AmPm == "pm" then
		if Hour == 12 then 
		else Hour = Hour + 12
		end
	else
		if Hour == 12 then
			Hour = 0
		end
	end
	local nOSDate = tonumber(os.date(os.time{year = Year, month = Month, day = Day, hour = Hour, min = Minute,}))
	return nOSDate
end

function EventManager:get_timezone_offset(ts)
	local utcdate   = os.date("!*t", ts)
	local localdate = os.date("*t", ts)
	localdate.isdst = false -- this is the trick
	return tonumber(os.difftime(os.time(utcdate),os.time(localdate)))
end

function EventManager:TableLength(T)
	local count = 0
	for idx, name in pairs(T) do 
		if T[idx].Name ~= "" then 
			count = count + 1 
		end
	end
  return count
end

function EventManager:RoleCount(T)
	local nTankCount = 0
	local nHealerCount = 0
	local nDPSCount = 0
	for idx, role in pairs(T) do 
		if T[idx].Roles.Tank == 1 then 
			nTankCount = nTankCount + 1
		end
		if T[idx].Roles.Healer == 1 then
			nHealerCount = nHealerCount + 1
		end
		if T[idx].Roles.DPS == 1 then
			nDPSCount = nDPSCount + 1
		end
	end
  return nTankCount, nHealerCount, nDPSCount
end

function EventManager:GetSelectedRoles(bTankRole,bHealerRole,bDPSRole)
	local nTankRole = 0
	local nHealerRole = 0
	local nDPSRole = 0
	if bTankRole == true then
		nTankRole = 1
	end
	if bHealerRole == true then
		nHealerRole = 1
	end
	if bDPSRole == true then
		nDPSRole = 1
	end
	local SelectedRoles = {Tank = nTankRole, Healer = nHealerRole, DPS = nDPSRole}
	return {Tank = nTankRole, Healer = nHealerRole, DPS = nDPSRole}
end

function EventManager:CreateAttendeeInfo(Creator,time,Roles)
	local Roles = Roles
	local Creator = Creator
	local time = time
	local tCurrentAttendees = {}
	if not Roles.Tank and Roles.Healer and Roles.DPS then
		tCurrentAttendees = {{Name = "", nSignUpTime = "", Roles = {},}}
	else
		tCurrentAttendees = {{Name = Creator,nSignUpTime = time,
							Roles = Roles}}		
	end
	return tCurrentAttendees
end	

function EventManager:OnEventManagerMessage(channel, tMsg, strSender)		--changed by Feyde.
	local MyEvents = {}
	local DuplicateEvent = false
	tEventHolder = nil
	tMsgReceived = tMsg
	if tMsg == nil then return end
	if self.tMetaData.SecurityRequired ~= nil and self.tMetaData.SecurityRequired == true then 
		if not self:AuthSender(strSender) then return end
		if tMsg.tMetaData.Passphrase ~= self.tMetaData.Passphrase then
			--Print("Passphrase mismatch. You are not authorized to received messages on this channel.")
			return
		end
	end



	if tMsg.tEventsBacklog == nil then
		Print("Backlog Msg empty") 

		for i = #tMsgReceived.tEventsBacklog, 1, -1 do
			Print(tMsgReceived.tEventsBacklog[i].Detail.Creator)
			if not tMsgReceived.tEventsBacklog[i].Detail then
				tMsg.tEventsBacklog[i] = nil
				Print("Backlog Msg Detail empty")
			
			elseif tMsgReceived.tEventsBacklog[i].Detail.Creator == GameLib.GetPlayerUnit():GetName() then
				tEventHolder[#tEventHolder + 1] = tMsgReceived.TeventsBacklog[i]
				--tMsg.tEventsBacklog[i] = nil
				Print("Backlog Msg processed")
				
				--MyEvents = self:ProcessBacklog(tEventHolder)

			end
		Print("Backlog for event not processed.  Event owned by "..tMsg.tEventsBacklog[i].Detail.Creator)
		end
	tBackloggedEvents = tEventHolder
	end



	if tMsg.tEvents == nil or tMsg.tMetaData.nLatestUpdate == nil or tMsg.tMetaData.nLatestUpdate < self.tMetaData.nLatestUpdate then
		Print("Event received is older than your local events")
		--self:EventsMessenger() 
		return
	end
	
	-- tMsgReceived = tMsg (not needed anymore as it was verification of incoming messages)
	
	--if tMsg.tEvents == nil or tMsg.tMetaData.nLatestUpdate == nil then return end
	
	
				
	for MsgKey, MsgEventId in pairs(tMsg.tEvents) do
		DuplicateEvent = false
		for key, EventId in pairs(self.tEvents) do
			if tMsg.tEvents[MsgKey].EventId == self.tEvents[key].EventId then 
				if tMsg.tEvents[MsgKey].Detail.EventModified <= 	self.tEvents[key].Detail.EventModified and EventId.tCurrentAttendees == tMsg.tEvents[MsgKey].Detail.tCurrentAttendees and 
																event.tNotAttending == tMsg.tEvents[MsgKey].Detail.tNotAttending then
					DuplicateEvent = true
					--Print("Duplicate event ignored.")
				else
					self.tEvents[key] = tMsg.tEvents[MsgKey]
					self.tEvents[key].Detail.EventModified = os.time()
					DuplicateEvent = true
				end
			end	
		end
		if DuplicateEvent == false then
			tMsg.tEvents[MsgKey].Detail.EventModified = os.time()
			table.insert(self.tEvents, tMsg.tEvents[MsgKey])
			Print("Events Manager: New Events received from sync channel.")
		end
	end
			
	self.tMetaData.nLatestUpdate = os.time()

	table.sort(self.tEvents,SortEventsByDate)
	self:PopulateItemList(self.tEvents)
	if self.tMetaData.nLatestUpdate ~= tMsg.tMetaData.nLatestUpdate then
		self:EventsMessenger()
	end
	--self:EventsMessenger()
end

function EventManager:EventsMessenger()
	self.tMetaData = self.tMetaData
   	local tEvents = self.tEvents
   	tEventsBacklog = self.tEventsBacklog
    

    -- prepare our message to send to other users
    local t = {}
    t.tMetaData = self.tMetaData
    t.tEvents = tEvents
    t.tEventsBacklog = tEventsBacklog
    
    -- send the message to other users
	if EventsChan == nil then
		Print("Events Manager Error: Cannot send sync data unless sync channel has been selected")
		self:PopulateItemList(self.tEvents)
	else
	    EventsChan:SendMessage(t)
		--Print("Events Manager: Event update sent to sync'd users.")
	    -- here we "send" the message to ourselves by calling OnEventManagerMessage directly
	    self:OnEventManagerMessage(nil, t, GameLib.GetPlayerUnit():GetName())
	end
end

function EventManager:CleanListToPopulate()
	for key, EventId in pairs(self.tEvents) do
		if self.tEvents[key].nEventSortValue < tonumber(os.time())-3600 then
			self.tEvents[key] = nil
		end
	end
	return self.tEvents
end


-----------------------------------------------------------------------------------------------
-- EventManagerForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function EventManager:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function EventManager:OnCancel(wndHandler, wndControl, eMouseButton)
	wndControl:GetParent():Close() -- hide the window
end


function EventManager:OnNewEventOn( wndHandler, wndControl, eMouseButton )
	local wnd = self.wndNewEvent
	local tNewDate = os.date("*t",os.time())
	wnd:FindChild("EventMonthBox"):SetText(string.format("%02d",tNewDate.month))
	wnd:FindChild("EventDayBox"):SetText(string.format("%02d",tNewDate.day))
	wnd:FindChild("EventYearBox"):SetText(tNewDate.year)
	if tNewDate.hour == 00 then
		wnd:FindChild("EventHourBox"):SetText("00")
	elseif
		tNewDate.hour >= 12 then
		wnd:FindChild("EventHourBox"):SetText(string.format("%02d",tNewDate.hour-12))
	else
		wnd:FindChild("EventHourBox"):SetText(string.format("%02d",tNewDate.hour))
	end
	wnd:FindChild("EventMinuteBox"):SetText(string.format("%02d",tNewDate.min))
	if tNewDate.hour >= 12 then
		wnd:FindChild("EventAmPmBox"):SetText("pm")
	else
		wnd:FindChild("EventAmPmBox"):SetText("am")
	end
	
	self.wndNewEvent:Show(true)
end

function EventManager:OnOptionsWindowShow (wndHandler, wndControl, eMouseButton)
	if self.tMetaData.SyncChannel ~= nil or self.tMetaData.Passphrase ~= nil or self.tMetaData.SecurityRequired ~= nil then
		self.wndOptions:FindChild("SyncChannelBox"):SetText(self.tMetaData.SyncChannel)
		self.wndOptions:FindChild("PassphraseBox"):SetText(self.tMetaData.Passphrase)

	end
	if self.tMetaData.SecurityRequired == true then
	self.wndOptions:FindChild("EnableSecureEventsButton"):SetCheck(true)
	--self.wndOptions:FindChild("ShowSecurityWhitelist"):Show(true)
	else
	self.wndOptions:FindChild("EnableSecureEventsButton"):SetCheck(false)
	--self.wndOptions:FindChild("ShowSecurityWhitelist"):Show(false)
	end
	self.wndOptions:Show(true)
end

function EventManager:OnOptionsSubmit (wndHandler, wndControl, eMouseButton)
	self.wndOptions = wndControl:GetParent()
	local strSyncChannel = self.wndOptions:FindChild("SyncChannelBox"):GetText()
	self.tMetaData.nLatestUpdate = 0
	self.tMetaData.SyncChannel = strSyncChannel
	self.tMetaData.Passphrase = self.wndOptions:FindChild("PassphraseBox"):GetText()
	self.tMetaData.SecurityRequired = self.wndOptions:FindChild("EnableSecureEventsButton"):IsChecked()
	EventsChan = ICCommLib.JoinChannel(strSyncChannel, "OnEventManagerMessage", self)
	Print("Events Manager: Joined sync channel "..strSyncChannel)
	wndControl:GetParent():Show(false)
	self:EventsMessenger()
end

function EventManager:OnSignUpForm (wndHandler, wndControl, eMouseButton)
	if self.wndSelectedListItemDetail:IsShown() then
		self.wndSelectedListItemDetail:Show(false)
	end
	self.wndSignUp:Show(true)
	local wndSelectedEvent = wndControl
	local SelectedEvent = wndSelectedEvent:GetParent():GetData()
	self:OnSignUpFormShow(SelectedEvent)
end

function EventManager:OnSignUpFormShow (SelectedEvent)
	self.wndSignUp:FindChild("TankRoleButton"):SetCheck(false)
	self.wndSignUp:FindChild("HealerRoleButton"):SetCheck(false)
	self.wndSignUp:FindChild("DPSRoleButton"):SetCheck(false)
	local EventId = SelectedEvent.EventId
	local EventName = SelectedEvent.Detail.EventName
	local EventDescription = SelectedEvent.Detail.Description
	local EventSignUpHeader = EventName.."\n"..string.format("%02d",SelectedEvent.Detail.Month).."/"..string.format("%02d",SelectedEvent.Detail.Day)..
							"/"..SelectedEvent.Detail.Year..", "..string.format("%02d",SelectedEvent.Detail.Hour)..":"..
							string.format("%02d",SelectedEvent.Detail.Minute).." "..SelectedEvent.Detail.AmPm
	self.wndSignUp:FindChild("SignUpFormHeader"):SetText(EventSignUpHeader)
	self.wndSignUp:FindChild("SignUpDescriptionBox"):SetText(EventDescription)
	self.wndSignUp:SetData(SelectedEvent)
end

function EventManager:OnSignUpSubmit(wndHandler, wndControl, eMouseButton)
	local SelectedEvent = wndControl:GetParent():GetData()
	local SelectedEventId = SelectedEvent.EventId
	local EventName = SelectedEvent.Detail.EventName
	local bSignUpTank = self.wndSignUp:FindChild("TankRoleButton"):IsChecked()
	local bSignUpHealer = self.wndSignUp:FindChild("HealerRoleButton"):IsChecked()
	local bSignUpDPS = self.wndSignUp:FindChild("DPSRoleButton"):IsChecked()
	local NewAttendeeInfo = {["Name"] = GameLib.GetPlayerUnit():GetName(),["nSignUpTime"] = os.time(), 
							["Roles"] = self:GetSelectedRoles(bSignUpTank ,bSignUpHealer ,bSignUpDPS )}
	for key, EventId in pairs(self.tEvents) do
	local CurrentAttendees = self.tEvents[key].Detail.tCurrentAttendees
	local CurrentDeclined = self.tEvents[key].Detail.tNotAttending
		if self.tEvents[key].EventId == SelectedEventId then
			table.insert(CurrentAttendees, NewAttendeeInfo)
			for idx, name in pairs(CurrentDeclined) do
				if CurrentDeclined[idx].Name == GameLib.GetPlayerUnit():GetName() then
					table.remove(self.tEvents[key].Detail.tNotAttending,idx)
				end
			end
			self.tEvents[key].Detail.EventModified = os.time()
		end
	end
	
	Print("Sign Up Completed for "..EventName)
	self:PopulateItemList(self.tEvents.EventId)
	self.wndSignUp:Show(false)
	self.tMetaData.nLatestUpdate = os.time()
	self:EventsMessenger()
end

function EventManager:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "Event Manager"})
end

function EventManager:OnSaveNewEvent(wndHandler, wndControl, eMouseButton)
	self.wndNew = wndControl:GetParent()
	NewEventEntry = nil
	NewBacklogEvent = {}
	
	NewEventEntry = {
		EventId = GameLib.GetRealmName()..os.time(),
		nEventSortValue = os.time(),
		strEventStatus = "Active",
		Detail  = {
			EventName = self.wndNew:FindChild("EventNameBox"):GetText(),
			Month = tonumber(self.wndNew:FindChild("EventMonthBox"):GetText()),
			Day = tonumber(self.wndNew:FindChild("EventDayBox"):GetText()),
			Year = tonumber(self.wndNew:FindChild("EventYearBox"):GetText()),
			Hour = tonumber(self.wndNew:FindChild("EventHourBox"):GetText()),
			Minute = tonumber(self.wndNew:FindChild("EventMinuteBox"):GetText()),
			AmPm = string.lower(self.wndNew:FindChild("EventAmPmBox"):GetText()),
			TimeZone = string.lower(os.date("%Z")),
			MaxAttendees = tonumber(self.wndNew:FindChild("EventMaxAttendeesBox"):GetText()),
			MaxTanks = tonumber(self.wndNew:FindChild("EventMaxTanksBox"):GetText()),
			MaxHealers = tonumber(self.wndNew:FindChild("EventMaxHealersBox"):GetText()),
			MaxDps = tonumber(self.wndNew:FindChild("EventMaxDPSBox"):GetText()),
			Description = self.wndNew:FindChild("EventDescriptionBox"):GetText(),
			Creator = GameLib.GetPlayerUnit():GetName(),
			--CreatorRoles = self:GetSelectedRoles(bCreatorTank,bCreatorHealer,bCreatorDPS),
			bTankRole = self.wndNewEvent:FindChild("TankRoleButton"):IsChecked(),
			bHealerRole = self.wndNewEvent:FindChild("HealerRoleButton"):IsChecked(),
			bDPSRole = self.wndNewEvent:FindChild("DPSRoleButton"):IsChecked(),
			tCurrentAttendees = {{Name = GameLib.GetPlayerUnit():GetName(),nSignUpTime = os.time(),
							Roles = self:GetSelectedRoles(self.wndNewEvent:FindChild("TankRoleButton"):IsChecked()
														 ,self.wndNewEvent:FindChild("HealerRoleButton"):IsChecked()
														 ,self.wndNewEvent:FindChild("DPSRoleButton"):IsChecked() )}},	
			strRealm = GameLib.GetRealmName(),
			EventModified = os.time(),
			tNotAttending = {},

			
		},
		
	}
	
	if NewEventEntry.Detail.Hour > 12 then
		NewEventEntry.Detail.Hour = NewEventEntry.Detail.Hour - 12
		NewEventEntry.AmPm = "pm"
	end

	NewEventEntry.nEventSortValue = self:CreateSortValue(NewEventEntry.Detail)
	local CurrentLocalTime = os.time()
	NewEventEntry.EventModified = os.time()
	if NewEventEntry.nEventSortValue < CurrentLocalTime then
		Print("Event Manager Error: New events cannot be created in the past.")
		NewEventEntry = nil
	end

	if NewEventEntry ~= nil then
		self.tEvents[GameLib.GetRealmName()..os.time()] = NewEventEntry
	
		NewBacklogEvent = {		
		nEventSortValue = NewEventEntry.nEventSortValue,
		EventId = NewEventEntry.EventId,
		strEventStatus = NewEventEntry.strEventStatus,
		Detail  = {
			Creator = NewEventEntry.Detail.Creator,
			--CreatorRoles = self:GetSelectedRoles(bCreatorTank,bCreatorHealer,bCreatorDPS),
			tCurrentAttendees = NewEventEntry.Detail.tCurrentAttendees,	
			EventModified = NewEventEntry.Detail.EventModified,
			tNotAttending = NewEventEntry.Detail.tNotAttending	
		},}
	end


	self.tEventsBacklog[NewEventEntry.EventId] = NewBacklogEvent
			
	--table.sort(self.tEvents,SortEventsByDate)
	--table.sort(self.tEventsBacklog, SortEventsByDate)
	self.wndNew:Show(false)
	self:PopulateItemList(tEvents)
	self.tMetaData.nLatestUpdate = os.time()
	self:EventsMessenger()
end

function EventManager:OnEventDeclined (wndHandler, wndControl, eMouseButton)
  local tEvent = wndControl:GetParent():GetData()
  self.wndSelectedListItem = wndControl:GetParent()
  local nEventID = tEvent.EventId
  local tEventInfo = tEvent.Detail
  local tEventAttendees = tEventInfo.tCurrentAttendees
  local tNotAttending = tEventInfo.tNotAttending
  local PlayerFound = false
 
  for key, Event in pairs(self.tEvents) do
    if Event == nEventID then
      for idx, attendee in pairs (tEventInfo.tCurrentAttendees) do
        if attendee.Name == GameLib.GetPlayerUnit():GetName() then
 
          table.remove(Event.Detail.tCurrentAttendees, idx)
          -- Since you are using insert/remove you can get this attendeeCount by: #tEventInfo.tCurrentAttendees
          table.insert(Event.Detail.tNotAttending, {["Name"] = GameLib.GetPlayerUnit():GetName()})
          self.wndSelectedListItemDetail:Show(true)
          tEventInfo.EventModified = os.time()
          PlayerFound = true
        end
      end
 
      if not PlayerFound then
        for idx2, player in pairs(tEventInfo.tNotAttending) do
          if player.Name == GameLib.GetPlayerUnit():GetName() then
            Print("You have already declined this event.")
            return
          else
            Print("You have declined the event.")
            self.tEvents[idx2].Detail.tNotAttending = {["Name"] = GameLib.GetPlayerUnit():GetName()}
            Print("Not Attending table updated")
            tEventInfo.EventModified = os.time()
            wndControl:GetParent():FindChild("DeclineButton"):Show(false)  
          end
        end
      end
    end
  end
  self:PopulateItemList(self.tEvents)
  self.tMetaData.nLatestUpdate = os.time()
  self:EventsMessenger()
end

function EventManager:OnEventCancel(wndHandler, wndControl, eMouseButton)
	if self.wndSelectedListItem == nil then
		Print("Events Manager Error: You must select an event from the list before pressing the cancel button.")
		return
	else
		local SelectedEvent = self.wndSelectedListItem:GetData()
		local nEventID = SelectedEvent.EventId
		self:OnEventCancelWarning(SelectedEvent,nEventId)
	end
end

function EventManager:OnEventCancelWarning(SelectedEvent,nEventId)
	
	local tEventInfo = SelectedEvent.Detail	
	local strEventInfo = 	tEventInfo.EventName..", with "..tEventInfo.nEventAttendeeCount.."/"..tEventInfo.MaxAttendees.."  attendees on: "..
							string.format("%02d",tEventInfo.Month).."/"..string.format("%02d",tEventInfo.Day).."/"..tEventInfo.Year..", at "..
							string.format("%02d",tEventInfo.Hour)..":"..string.format("%02d",tEventInfo.Minute).." "..tEventInfo.AmPm..
							" "..string.lower(tEventInfo.TimeZone)
	self.wndDeleteConfirm:FindChild("DeleteConfirmationWarning"):SetText("You have chosen to delete the following event:\n \n"..strEventInfo..
																	". \n \nPlease press \"Confirm\" ONLY if you are sure you want to delete this event.")
	self.wndDeleteConfirm:Show(true)
	self.wndDeleteConfirm:SetData(SelectedEvent)
end

function EventManager:OnDeleteConfirmation(wndHandler, wndControl, eMouseButton)
	local SelectedEvent = wndControl:GetParent():GetData()
	local nEventId = SelectedEvent.EventId	
	for key, event in pairs(self.tEvents) do
		if event.EventId == nEventId then
			if event.Detail.Creator == GameLib.GetPlayerUnit():GetName() then
				event.strEventStatus = "Canceled"
				Print("Events Manager: The event has been removed.")
			else
				Print("Events Manager Error: Only the creator of an event may cancel an event.")
				self.wndDeleteConfirm:Show(false)
				return				
			end
		end
	end
self.wndDeleteConfirm:Show(false)
self:EventsMessenger()
self.tMetaData.nLatestUpdate = os.time()
self:PopulateItemList(self.tEvents)


end

--------------------------------------------------------------------------------------------------------------
--Editing Events
--------------------------------------------------------------------------------------------------------------

function EventManager:OnEditEventFormOn(wndHandler, wndControl, eMouseButton)
	self.wndSelectedListItemDetail:Show(false)
	local SelectedEventData = wndControl:GetParent():GetData()
	local SelectedEventId = SelectedEventData.EventId
	local tEventDetail = SelectedEventData.Detail
	local wnd = self.wndEditEvent
	local ThisEvent = nil
	wnd:FindChild("EventNameBox"):SetText(SelectedEventData.Detail.EventName)
	wnd:FindChild("EventMonthBox"):SetText(string.format("%02d",SelectedEventData.Detail.Month))
	wnd:FindChild("EventDayBox"):SetText(string.format("%02d",SelectedEventData.Detail.Day))
	wnd:FindChild("EventYearBox"):SetText(SelectedEventData.Detail.Year)
	wnd:FindChild("EventHourBox"):SetText(string.format("%02d",SelectedEventData.Detail.Hour))
	wnd:FindChild("EventMinuteBox"):SetText(string.format("%02d",SelectedEventData.Detail.Minute))
	wnd:FindChild("EventAmPmBox"):SetText(SelectedEventData.Detail.AmPm)
	wnd:FindChild("EventMaxAttendeesBox"):SetText(SelectedEventData.Detail.MaxAttendees)
	wnd:FindChild("EventMaxTanksBox"):SetText(SelectedEventData.Detail.MaxTanks)
	wnd:FindChild("EventMaxHealersBox"):SetText(SelectedEventData.Detail.MaxHealers)
	wnd:FindChild("EventMaxDPSBox"):SetText(SelectedEventData.Detail.MaxDps)
	wnd:FindChild("EventDescriptionBox"):SetText(SelectedEventData.Detail.Description)

	if SelectedEventData.Detail.bTankRole == true then
		wnd:FindChild("TankRoleButton"):SetCheck(true)
	end
	if SelectedEventData.Detail.bHealerRole == true then
		wnd:FindChild("HealerRoleButton"):SetCheck(true)
	end
	if SelectedEventData.Detail.bDPSRole == true then
		wnd:FindChild("DPSRoleButton"):SetCheck(true)
	end
	
	self.wndEditEvent:SetData(SelectedEventData)
	
	self.wndEditEvent:Show(true)

end

function EventManager:OnEventEditSubmit(wndHandler,wndControl,eMouseButton)
	local EditedEvent = wndControl:GetParent():GetData()
	local wndEdit = wndControl:GetParent()
	--EditEvent = {}
	for key, event in pairs(self.tEvents) do
		if EditedEvent.EventId == event.EventId then
			event.Detail = {
			EventName = wndEdit:FindChild("EventNameBox"):GetText(),
			Month = tonumber(wndEdit:FindChild("EventMonthBox"):GetText()),
			Day = tonumber(wndEdit:FindChild("EventDayBox"):GetText()),
			Year = tonumber(wndEdit:FindChild("EventYearBox"):GetText()),
			Hour = tonumber(wndEdit:FindChild("EventHourBox"):GetText()),
			Minute = tonumber(wndEdit:FindChild("EventMinuteBox"):GetText()),
			AmPm = string.lower(wndEdit:FindChild("EventAmPmBox"):GetText()),
			TimeZone = event.Detail.TimeZone,
			MaxAttendees = tonumber(wndEdit:FindChild("EventMaxAttendeesBox"):GetText()),
			MaxTanks = tonumber(wndEdit:FindChild("EventMaxTanksBox"):GetText()),
			MaxHealers = tonumber(wndEdit:FindChild("EventMaxHealersBox"):GetText()),
			MaxDps = tonumber(wndEdit:FindChild("EventMaxDPSBox"):GetText()),
			Description = wndEdit:FindChild("EventDescriptionBox"):GetText(),
			Creator = event.Detail.Creator,
			bTankRole = wndEdit:FindChild("TankRoleButton"):IsChecked(),
			bHealerRole = wndEdit:FindChild("HealerRoleButton"):IsChecked(),
			bDPSRole = wndEdit:FindChild("DPSRoleButton"):IsChecked(),
			tCurrentAttendees = event.Detail.tCurrentAttendees,	
			strRealm = event.Detail.strRealm,
			EventModified = os.time(),
			tNotAttending = event.Detail.tNotAttending,
			
			}
			event.EventId = event.EventId
			event.strEventStatus = event.strEventStatus
			event.EventModified = os.time()
			if event.Detail.Hour > 12 then 
				event.Detail.Hour = event.Detail.Hour - 12
				event.Detail.AmPm = "pm"
			end
			event.nEventSortValue = self:CreateSortValue(event.Detail)
			if event.nEventSortValue < os.time() then
				Print("Event Manager error: Events cannot be edited to occur in the past.")
				event = EditedEvent
			end	
			
		end
		for idx2, name in pairs (self.tEvents[key].Detail.tCurrentAttendees) do
			if self.tEvents[key].Detail.tCurrentAttendees[idx2].Name == GameLib.GetPlayerUnit():GetName() then
				self.tEvents[key].Detail.tCurrentAttendees[idx2].Roles = 	{self:GetSelectedRoles(wndEdit:FindChild("TankRoleButton"):IsChecked(),
																			wndEdit:FindChild("HealerRoleButton"):IsChecked(),
																			wndEdit:FindChild("DPSRoleButton"):IsChecked())}
			end
		end
    end
	self.wndEditEvent:Show(false)
	self:EventsMessenger()
	self.tMetaData.nLatestUpdate = os.time()
	self:PopulateItemList(self.tEvents)	
end


-----------------------------------------------------------------------------------------------
-- ItemList Functions
-----------------------------------------------------------------------------------------------
-- populate item list
function EventManager:PopulateItemList(list)
	-- make sure the item list is empty to start with
	self:DestroyItemList()
	
	list = self:CleanListToPopulate()
	if list == nil then return
	else 
	    -- add 20 items
		for k,v in pairs(list) do
			self:AddItem(k)
	        
		end
		
		-- now all the item are added, call ArrangeChildrenVert to list out the list items vertically
		self.wndItemList:ArrangeChildrenVert(0,SortListItems)
	end

end

-- clear the item list
function EventManager:DestroyItemList()
	-- destroy all the wnd inside the list
	for idx,wnd in ipairs(self.tItems) do
		wnd:Destroy()
	end

	-- clear the list item array
	self.tItems = {}
	self.wndSelectedListItem = nil
end

-- add an item into the item list
function EventManager:AddItem(i)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "ListItem", self.wndItemList, self)
	local wndSelectedItemHighlight = wnd:FindChild("SelectedListItemHighlight"):Show(false)
	local SignUpButton = wnd:FindChild("SignUpButton")
	local DeclineButton = wnd:FindChild("DeclineButton")
	local strEventInfo = ""
	
	-- keep track of the window item created
	self.tItems[i] = wnd
	local tEvent = self.tEvents[i]
	local tEventInfo = tEvent.Detail
	local tEventAttendees = tEventInfo.tCurrentAttendees
	local tEventRoles = tEventInfo.tCurrentAttendees
	local PlayerAttending = false
	tEventInfo.nCurrentTanks = 0
	tEventInfo.nCurrentHealers = 0
	tEventInfo.nCurrentDPS = 0
	for idx, name in pairs(tEventInfo.tCurrentAttendees) do
		if tEventAttendees[idx].Name == GameLib.GetPlayerUnit():GetName() then
			PlayerAttending = true
		end
	end
	if PlayerAttending == true then 
		SignUpButton:Show(false)
		DeclineButton:Show(true)
	else
		for idx2, name in pairs(tEventInfo.tNotAttending) do
			if tEventInfo.tNotAttending[idx2].Name == GameLib.GetPlayerUnit():GetName() then
				SignUpButton:Show(true)
				DeclineButton:Show(false)
			else
				SignUpButton:Show(true)
				DeclineButton:Show(true)
			end
		end
	end
			
	if not tEventAttendees then
		tEventInfo.nEventAttendeeCount = 0 
	else tEventInfo.nEventAttendeeCount = self:TableLength(tEventAttendees)
	end
	if tEventRoles then
		--tEventInfo.nCurrentTanks = 0
		--tEventInfo.nCurrentHealers = 0
		--tEventInfo.nCurrentDPS = 0
	--else
		tEventInfo.nCurrentTanks, tEventInfo.nCurrentHealers, tEventInfo.nCurrentDPS = self:RoleCount(tEventRoles)
	end
	if tEvent.strEventStatus == "Canceled" then
		strEventInfo = "The event, "..tEventInfo.EventName.." scheduled for "..string.format("%02d",tEventInfo.Month).."/"..string.format("%02d",tEventInfo.Day).."/"..tEventInfo.Year..", at\n"..
						string.format("%02d",tEventInfo.Hour)..":"..string.format("%02d",tEventInfo.Minute).." "..tEventInfo.AmPm.." "..
						string.upper(tEventInfo.TimeZone).."\nhas been cancelled by "..tEventInfo.Creator
						
		SignUpButton:Show(false)
		DeclineButton:Show(false)
	else
		strEventInfo = 	tEventInfo.EventName..".  Attendees: "..tEventInfo.nEventAttendeeCount.."/"..tEventInfo.MaxAttendees..". \n"..
								string.format("%02d",tEventInfo.Month).."/"..string.format("%02d",tEventInfo.Day).."/"..tEventInfo.Year..", "..
								string.format("%02d",tEventInfo.Hour)..":"..string.format("%02d",tEventInfo.Minute).." "..tEventInfo.AmPm..
								" "..string.upper(tEventInfo.TimeZone).."\nAttendees by Role: (tank/healer/dps)  "..tEventInfo.nCurrentTanks.."/"..
								tEventInfo.nCurrentHealers.."/"..tEventInfo.nCurrentDPS
	end
	-- give it a piece of data to refer to 
	local wndItemText = wnd:FindChild("Text")
	if wndItemText then -- make sure the text wnd exist
		wndItemText:SetText(strEventInfo) -- set the item wnd's text to "item i"
		wndItemText:SetTextColor(kcrNormalText)
	end
	local AttendeeList = {"Signed up for Event: \n \n"}
	for key, name in pairs(tEventInfo.tCurrentAttendees) do
		AttendeeList = {tEventInfo.tCurrentAttendees[key].Name}
	end
	wnd:SetTooltip(table.concat(AttendeeList, '\n'))
	wnd:SetData(tEvent)
end

-- when a list item is selected
function EventManager:OnListItemSelected(wndHandler, wndControl)
	if self.wndEditEvent:IsVisible() == true then
		self.wndEditEvent:Show(false)
	end
	local SelectedEventData = wndControl:GetData()
    -- make sure the wndControl is valid
    if wndHandler ~= wndControl then
        return
    end
    
    -- change the old item's text color back to normal color
    local wndItemText
    if self.wndSelectedListItem then
        wndItemText = self.wndSelectedListItem:FindChild("Text")
        wndItemText:SetTextColor(kcrNormalText)
		local wndSelectedItemHighlight = self.wndSelectedListItem:FindChild("SelectedListItemHighlight"):Show(false)
    end
    
	-- wndControl is the item selected - change its color to selected
	self.wndSelectedListItem = wndControl
	
	wndItemText = self.wndSelectedListItem:FindChild("Text")
    wndItemText:SetTextColor(kcrSelectedText)
	local wndSelectedItemHighlight = self.wndSelectedListItem:FindChild("SelectedListItemHighlight"):Show(true)

    local selectedItemText = self.wndSelectedListItem:GetData().Detail
    local SelectedEvent = self.wndSelectedListItem:GetData()
   	self.wndSelectedListItemDetail:SetData(SelectedEventData)
	local tAttendingSelectedItem = {}
	local tNotAttendingSelectedItem = {}
	for key, name in pairs(selectedItemText.tCurrentAttendees) do
		tAttendingSelectedItem = {selectedItemText.tCurrentAttendees[key].Name.." ("
					..selectedItemText.tCurrentAttendees[key].Roles.Tank.."/"..selectedItemText.tCurrentAttendees[key].Roles.Healer.."/"
					..selectedItemText.tCurrentAttendees[key].Roles.DPS..")"}
	end
	for key, name in pairs(selectedItemText.tNotAttending) do
		tNotAttendingSelectedItem = {Name = selectedItemText.tNotAttending[key].Name}
	end
	for key, event in pairs(self.tEvents) do
		if SelectedEvent.Detail.Creator == event.Detail.Creator then --GameLib.GetPlayerUnit():GetName() then
			self.wndSelectedListItemDetail:FindChild("EditEventButton"):Show(true)
		else
			self.wndSelectedListItemDetail:FindChild("EditEventButton"):Show(false)
		end
	end
	self.wndSelectedListItemDetail:FindChild("SelectedEventDescriptionBox"):SetText(selectedItemText.Description)
	self.wndSelectedListItemDetail:FindChild("EventDetailsWindow"):SetText(selectedItemText.EventName.. ", created by: "..selectedItemText.Creator..
											"\nScheduled for: "..string.format("%02d",selectedItemText.Month).."/"..
											string.format("%02d",selectedItemText.Day).."/"..selectedItemText.Year.." at "..
											string.format("%02d",selectedItemText.Hour)..":"..string.format("%02d",selectedItemText.Minute)..
											" "..string.upper(selectedItemText.TimeZone).."\n \nThere are currently "..selectedItemText.nCurrentTanks.."/"..
											selectedItemText.MaxTanks.." Tanks, "..selectedItemText.nCurrentHealers.."/"..selectedItemText.MaxHealers..
											" Healers, and "..selectedItemText.nCurrentDPS.."/"..selectedItemText.MaxDps.." DPS signed up.")
	self.wndSelectedListItemDetail:FindChild("DetailsAttendingBox"):SetText("Attending \n(Role(s) Selected: tank/healer/dps):\n \n"..table.concat(tAttendingSelectedItem,'\n')
											.."\n \nNot Attending: \n \n"..table.concat(tNotAttendingSelectedItem, '\n'))
	if SelectedEvent.strEventStatus ~= "Canceled" then
			self.wndSelectedListItemDetail:Show(true)
		else
			self.wndSelectedListItemDetail:Show(false)
		
	end
											
end


--start add by Feyde
---------------------------------------------------------------------------------------------------
-- SecurityForm Functions
---------------------------------------------------------------------------------------------------
function EventManager:OnSecurityNameDeleteClick( wndHandler, wndControl, eMouseButton )
	local UserName = self.wndSecurity:FindChild("SecurityNameText"):GetText()
	if string.len(self:Trim(UserName)) == 0 then	-- do not allow empty strings
		self.wndSecurity:FindChild("SecurityNameText"):SetText("")	-- ensure no empty spaces
		self.wndSecurity:FindChild("SecurityNameText"):SetFocus()	-- refocus to text box
		return
	end
	for idx,name in pairs(self.tSecurity) do
		if name == UserName then
			table.remove(self.tSecurity,idx)
		end
	end
	self:PopulateSecurityList()
	self.wndSecurity:FindChild("SecurityNameText"):SetText("")
	self.wndSecurity:FindChild("SecurityNameText"):SetFocus()
end

function EventManager:OnSecurityNameAddClick( wndHandler, wndControl, eMouseButton )
	self:AddSecurityNameToList()
end

function EventManager:PopulateSecurityList()
	if self.tSecurity == nil then
		return
	else
		local wndGrid = self.wndSecurity:FindChild("SecurityNamesGrid")
		wndGrid:DeleteAll()
		table.sort(self.tSecurity)
		for idx,name in pairs(self.tSecurity) do
			self:Debug(string.format("EM:Adding %s to list.",name))
			local i = wndGrid:AddRow(name)
		end
	end
end

function EventManager:AddSecurityNameToList()
	local UserName = self.wndSecurity:FindChild("SecurityNameText"):GetText()
	if string.len(self:Trim(UserName)) == 0 then	--do not allow empty strings
		self.wndSecurity:FindChild("SecurityNameText"):SetText("")	-- ensure no empty spaces
		self.wndSecurity:FindChild("SecurityNameText"):SetFocus()	-- refocus to text box
		return
	end
	self:Debug(string.format("EM:AddUserName: %s",UserName))
	
	local foundUser = false
	
	for idx,name in pairs(self.tSecurity) do
		if name == UserName then
			foundUser = true
			self:Debug(string.format("EM:User already exists: %s",UserName))

		end
	end
	
	if not foundUser then
		self:Debug(string.format("EM:User does not exist: %s",UserName))
		table.insert(self.tSecurity,UserName)
		self:PopulateSecurityList()
	end
	self.wndSecurity:FindChild("SecurityNameText"):SetText("")
	self.wndSecurity:FindChild("SecurityNameText"):SetFocus()
end

function EventManager:OnSecurityNameTextReturn( wndHandler, wndControl, strText )
	self:AddSecurityNameToList()
end

function EventManager:Debug(strText)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Debug, strText, "")
end

function EventManager:OnSecurityNamesGridClick( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
	local wndGrid = self.wndMain:FindChild("SecurityNamesGrid") 
	local row = wndGrid:GetCurrentRow()
	if row ~= nil and row <= wndGrid:GetRowCount() then
		local name = wndGrid:GetCellText(row)
		self.wndSecurity:FindChild("SecurityNameText"):SetText(name)
	end
end

function EventManager:Trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function EventManager:AuthSender(UserName)
	if #self.tSecurity > 0 then
		local AuthSender = false
		for idx,name in pairs(self.tSecurity) do
			if string.lower(name) == string.lower(UserName) then
				AuthSender = true
			end
		end
		return AuthSender
	else
		return true
	end
end
--end add by Feyde

-----------------------------------------------------------------------------------------------
-- EventManager Instance
-----------------------------------------------------------------------------------------------
local EventManagerInst = EventManager:new()
EventManagerInst:Init()
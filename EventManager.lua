-----------------------------------------------------------------------------------------------
-- Client Lua Script for EventManager
-- Wildstar Copyright (c) NCsoft. All rights reserved
-- EventsManager written by Thoughtcrime.  All rights reserved
-- Contribution for whitelist usecase credited to Feyed
-----------------------------------------------------------------------------------------------

require "Window"
require "ICCommLib"
require "ChatSystemLib"

-----------------------------------------------------------------------------------------------
-- EventManager Module Definition
-----------------------------------------------------------------------------------------------
local EventManager = {}    
local tEvents = {}
local tEventsBacklog = {}
local tMetaData = {nLatestUpdate = 0 ,SyncChannel = "" ,Passphrase = "",tSecurity = {},RequireSecureEvents = false}
local TankRoleStatus = 0	
local HealerRoleStatus = 0
local DPSRoleStatus = 0
local MetaData = ""
local EventsChan = nil
local tSecurity = {}
local BacklogId = ""
local nSignUpTime = 0
local nBacklogCreationTime = 0
local ProcessDupe = false
local nEventId = nil
local count = 0
MsgTrigger = ""
local MajorVersionRewrite = false
local ShowMajorVersionWarning = false
local MessageToSend = false
local GeminiTimer
local timerCount = 0

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
local ChatSystemLib = ChatSystemLib



-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressedFlyby")
local kcrNormalText = ApolloColor.new("UI_BtnTextHoloNormal")

local function SortArray(a,b)
	return (a.v or 0) < (b.v or 0)
end 

local function SortEventsByDate(a,b)
	return a.nEventSortValue < b.nEventSortValue
end 

local function SortListItems(a,b)
	local aEvent = a:GetData() 
	local bEvent = b:GetData() 
	return (aEvent.nEventSortValue or 0) < (bEvent.nEventSortValue or 0)
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
	local tSave = {}

	if (eLevel == GameLib.CodeEnumAddonSaveLevel.Character) then
		local tEvents = tEvents
		local tEventsBacklog = tEventsBacklog
		local tMetaData = tMetaData
		local MajorVersionRewrite = MajorVersionRewrite
		local tSecurity = self.tSecurity	-- added by Feyde

		
		
		tSave = {tMetaData = tMetaData, tEvents = tEvents, tEventsBacklog = tEventsBacklog, Security = tSecurity, MajorVersionRewrite = MajorVersionRewrite}

		return tSave
	end
	
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
			--SendVarToRover("tEventsBacklog",tEventsBacklog)
		end

		if tSavedData.MajorVersionRewrite ~= nil then
			MajorVersionRewrite = tSavedData.MajorVersionRewrite
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

	-- Edit Item Form
	self.wndEditEvent = Apollo.LoadForm(self.xmlDoc,"EditEventForm", self.wndMain,self)
	self.wndEditEvent:Show(false)

	-- Major Version Warning Form
	self.wndMajorVersionWarning = Apollo.LoadForm(self.xmlDoc,"MajorVersionWarning", nil, self)
	self.wndMajorVersionWarning:Show(false)
	
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
	self.tTimer = ApolloTimer.Create(30, true, "OnMsgTimer", self)



	-- Do additional Addon initialization here
	if MajorVersionRewrite ~= nil then
		if MajorVersionRewrite ~= true or ShowMajorVersionWarning == true then
			self.wndMajorVersionWarning:Show(true)
		end
	end


	if tMetaData ~= nil then
		tMetaData = tMetaData
		tMetaData.nLatestUpdate = tMetaData.nLatestUpdate
		if tMetaData.SyncChannel ~= "" or {} then 
			EventsChan = ICCommLib.JoinChannel(tMetaData.SyncChannel, "OnEventManagerMessage", self)
			----Print("Events Manager: Joined sync channel "..tMetaData.SyncChannel)
		end
		
	else
		tMetaData = {nLatestUpdate = 0 ,SyncChannel = "" ,Passphrase = "",tSecurity = {},RequireSecureEvents = false}
	end
	if tEvents ~= nil then
		tEvents = tEvents
	else tEvents = {}
	end

	if tEventsBacklog ~= nil then 
		tEventsBacklog = tEventsBacklog
	else 
		tEventsBacklog = {}
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
	timerCount = 0
end


-----------------------------------------------------------------------------------------------
-- EventManager General Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here


-- on SlashCommand "/em"
function EventManager:OnEventManagerOn()
	MsgTrigger = "init"
	self:EventsMessenger(MsgTrigger)
	self.wndMain:Invoke() -- show the window
	tMetaData.nLatestUpdate = 0
	for key, Event in pairs(tEvents) do
		if Event.nEventSortValue < tonumber(os.time())-3600 then
			tEvents[key] = nil
		end
	end
	self:PopulateItemList(tEvents)

	
	-- start add by Feyde
	-- populate the security list
	self:PopulateSecurityList()
	-- end add by Feyde
end

function EventManager:OnMsgTimer()
	--SendVarToRover("sync time value",timerCount+1)
	timerCount = timerCount + 1
  	if timerCount % 2 == 0 then
  		MsgTrigger = "Timer-triggered Sync"
    	self:EventsMessenger(MsgTrigger)
  	end
end

function EventManager:OnEventManagerMessage(channel, tMsg, strSender)		--changed by Feyde.
	local MyEvents = {}
	local DuplicateEvent = false
	local tMsgReceived = tMsg
	local BacklogEvent = {}
	local MessageToSend = false
	local ModifiedTime = 0
	local count = 0
	--SendVarToRover("MsgReceived",tMsgReceived)

	if tMsg == nil then 
		return
	elseif not tMsg.MajorVersionRewrite or tMsg.MajorVersionRewrite == nil then
		ChatSystemLib.Command("/w"..strSender..", your Event Manager Client is out of date. Please visit http://wildstar.curseforge.com/ws-addons/223228-eventmanager to update.")
		return
		elseif tMetaData.SyncChannel == tMsg.tMetaData.SyncChannel and tMsg.tMetaData.Passphrase ~= tMetaData.Passphrase then
			----Print ("Your passphrase does not match the passphrase for this channel, please verify your information is correct.")
			return
		else 
			if tMetaData.SecurityRequired ~= nil and tMetaData.SecurityRequired == true then 
				if not self:AuthSender(strSender) then 
				return
			end 
		end
	end

	if tMsg.tMetaData.nLatestUpdate == 0 then --and tMetaData.nLatestUpdate > 0 then
		
		MsgTrigger = "New Channel User Ping Reply."
		if strSender == GameLib.GetPlayerUnit():GetName() then
			tMetaData.nLatestUpdate = os.time()
		end
		self:EventsMessenger(MsgTrigger)
		return
	end


	self:ProcessLiveEvents(tMsg)
	self:CleanApplicationsList(tEvents)
	self:ImportBacklogEvents(tMsg)
	self:ProcessBacklogEvents(tEventsBacklog)
	self:ProcessMyBacklog(tEventsBacklog)

	MessageToSend = MessageToSend
	Print(inspect(MessageToSend))



	--SendVarToRover("tEvents",tEvents)
	--SendVarToRover("tMetaData",tMetaData)
	--SendVarToRover("tEventsBacklog", tEventsBacklog)
	--SendVarToRover("UpdateComparison",tMetaData.nLatestUpdate - tMsg.tMetaData.nLatestUpdate)
	--SendVarToRover("MessageFlag", MessageToSend

	
		tMetaData.nLatestUpdate = os.time()
	if MessageToSend == true then
		self:PopulateItemList(tEvents)
		MsgTrigger = MsgTrigger
		self:EventsMessenger(MsgTrigger)
	end
	----Print("Incoming Message Processing Complete")

	MessageToSend = false

end




function EventManager:EventsMessenger(strTrigger)
	local MessengerTrigger = strTrigger
	--SendVarToRover("Message Trigger",MessengerTrigger)
	tMetaData = tMetaData
	local tEvents = tEvents
	local tEventsBacklog = tEventsBacklog
	

   -- prepare our message to send to other users
   local t = {}
   --SendVarToRover("Message to Send", t)
   --SendVarToRover("EventsChan",EventsChan)
  	t.tMetaData = tMetaData
   t.tEvents = tEvents
   t.tEventsBacklog = tEventsBacklog
   t.MajorVersionRewrite = MajorVersionRewrite
    
    -- send the message to other users
   if EventsChan == nil then
    	----Print("Events Manager Error: Cannot send sync data unless sync channel has been selected")
    	self:PopulateItemList(tEvents)
   else
    	self:PopulateItemList(tEvents)
    	EventsChan:SendMessage(t)

	    -- here we "send" the message to ourselves by calling OnEventManagerMessage directly
	   self:OnEventManagerMessage(nil, t, GameLib.GetPlayerUnit():GetName())
	end
end

function EventManager:CleanTable()
	LocalEvents = {}
	for key, Event in pairs(tEvents) do
		--SendVarToRover("CleaningKey", key)
		--SendVarToRover("CleaningValue", EventId)
		if Event.nEventSortValue < tonumber(os.time())-3600 then
			LocalEvents[key] = nil
		end
		if Event.EventSyncChannel == tMetaData.SyncChannel then
			LocalEvents[Event.EventId] = Event
		end
	end
	return LocalEvents
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

-----------------------------------------------------------------------------------------------
-- Creating New Event & Backlog
-----------------------------------------------------------------------------------------------
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

function EventManager:OnSaveNewEvent(wndHandler, wndControl, eMouseButton)
	self.wndNew = wndControl:GetParent()
	local NewEventEntry = nil
	local NewBacklogEvent = {}
	nSignUpTime = os.time()
	local NewEventId = GameLib.GetRealmName()..GameLib.GetPlayerUnit():GetName()..os.time()
	
	NewEventEntry = {
	EventId = NewEventId,
	Owner = GameLib.GetPlayerUnit():GetName(),
	nEventSortValue = os.time(),
	strEventStatus = "Active",
	EventSyncChannel = tMetaData.SyncChannel,
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

	--OwnerRoles = self:GetSelectedRoles(bCreatorTank,bCreatorHealer,bCreatorDPS),
	bTankRole = self.wndNewEvent:FindChild("TankRoleButton"):IsChecked(),
	bHealerRole = self.wndNewEvent:FindChild("HealerRoleButton"):IsChecked(),
	bDPSRole = self.wndNewEvent:FindChild("DPSRoleButton"):IsChecked(),
	tCurrentAttendees = {{ Name = GameLib.GetPlayerUnit():GetName(),nSignUpTime = nSignUpTime,Status = "Attending",
	Roles = self:GetSelectedRoles(self.wndNewEvent:FindChild("TankRoleButton"):IsChecked(),self.wndNewEvent:FindChild("HealerRoleButton"):IsChecked(),self.wndNewEvent:FindChild("DPSRoleButton"):IsChecked()) }},	
	strRealm = GameLib.GetRealmName(),
	EventModified = nSignUpTime,
	tApplicationsProcessed = {}
	},
	}
		
	if NewEventEntry.Detail.Hour > 12 then
		NewEventEntry.Detail.Hour = NewEventEntry.Detail.Hour - 12
		NewEventEntry.AmPm = "pm"
	end

	NewEventEntry.nEventSortValue = self:CreateSortValue(NewEventEntry.Detail)
	local CurrentLocalTime = os.time()
	NewEventEntry.EventModified = nSignUpTime
	if NewEventEntry.nEventSortValue < CurrentLocalTime - 3600 then
		--Print("Event Manager Error: New events cannot be created in the past.")
		NewEventEntry = nil
	end
	--SendVarToRover("NewEventBacklogkey", NewEventEntry.EventId)
	--SendVarToRover("NewEventvalue", NewEvent)
	--SendVarToRover("NewEventBacksort", NewEventEntry.nEventSortValue)
	--SendVarToRover("NewEventEntry", NewEventEntry)
	if NewEventEntry ~= nil then
		tEvents[NewEventId] = NewEventEntry
		MsgTrigger = "New Event Created, Creating Backlog Event for Event Owner"
		BacklogId = GameLib.GetRealmName()..GameLib.GetPlayerUnit():GetName()..os.time()
		for NewEventId, NewEvent in pairs(NewEventEntry) do
			
			tEventsBacklog[BacklogId] = {		
			EventId = NewEventEntry.EventId,
			EventName = NewEventEntry.Detail.EventName,
			strEventStatus = NewEventEntry.strEventStatus,
			EventSyncChannel = NewEventEntry.EventSyncChannel,
			BacklogID = BacklogId,
			BacklogOwner = GameLib.GetPlayerUnit():GetName(),
			BacklogOwnerStatus = "Attending",
			BacklogOwnerRoles = self:GetSelectedRoles(self.wndNewEvent:FindChild("TankRoleButton"):IsChecked()
				,self.wndNewEvent:FindChild("HealerRoleButton"):IsChecked()
				,self.wndNewEvent:FindChild("DPSRoleButton"):IsChecked()),
			nBacklogCreationTime = nSignUpTime,
			nBacklogExpirationTime = NewEventEntry.nEventSortValue,
		}


		MsgTrigger = "NewBacklogCreated"
		--SendVarToRover("NewEventBacklogDetail", tEventsBacklog[NewEventEntry.EventId])
		--SendVarToRover("NewEventBacklog", tEventsBacklog[NewEventEntry.EventId])
		end
		
	end
	--SendVarToRover("NewEventBacklogkey", NewEventId)

	self.wndNew:Show(false)
	self:PopulateItemList(tEvents)
	MsgTrigger = MsgTrigger
	self:EventsMessenger(MsgTrigger)
	tMetaData.nLatestUpdate = os.time()
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

	for idx, player in pairs(tEvents[SelectedEventId].Detail.tCurrentAttendees) do
		if player.Name == GameLib.GetPlayerUnit():GetName() then
			if player.Roles.Tank == 1 then
				wnd:FindChild("TankRoleButton"):SetCheck(true)
			end
			if player.Roles.Healer == 1 then
				wnd:FindChild("HealerRoleButton"):SetCheck(true)
			end
			if player.Roles.DPS == 1 then
				wnd:FindChild("DPSRoleButton"):SetCheck(true)
			end
		end
		
	end

	self.wndEditEvent:SetData(SelectedEventData)
	self.wndEditEvent:Show(true)

end

function EventManager:OnEventEditSubmit(wndHandler,wndControl,eMouseButton)
	local EditedEvent = wndControl:GetParent():GetData()
	local EditedId = EditedEvent.EventId
	--SendVarToRover("EditedEvent",EditedEvent)
	local wndEdit = wndControl:GetParent()
	if EditedEvent.EventId == tEvents[EditedId].EventId then
		tEvents[EditedId].Detail = {
		EventName = wndEdit:FindChild("EventNameBox"):GetText(),
		Month = tonumber(wndEdit:FindChild("EventMonthBox"):GetText()),
		Day = tonumber(wndEdit:FindChild("EventDayBox"):GetText()),
		Year = tonumber(wndEdit:FindChild("EventYearBox"):GetText()),
		Hour = tonumber(wndEdit:FindChild("EventHourBox"):GetText()),
		Minute = tonumber(wndEdit:FindChild("EventMinuteBox"):GetText()),
		AmPm = string.lower(wndEdit:FindChild("EventAmPmBox"):GetText()),
		TimeZone = EditedEvent.Detail.TimeZone,
		MaxAttendees = tonumber(wndEdit:FindChild("EventMaxAttendeesBox"):GetText()),
		MaxTanks = tonumber(wndEdit:FindChild("EventMaxTanksBox"):GetText()),
		MaxHealers = tonumber(wndEdit:FindChild("EventMaxHealersBox"):GetText()),
		MaxDps = tonumber(wndEdit:FindChild("EventMaxDPSBox"):GetText()),
		Description = wndEdit:FindChild("EventDescriptionBox"):GetText(),
		bTankRole = wndEdit:FindChild("TankRoleButton"):IsChecked(),
		bHealerRole = wndEdit:FindChild("HealerRoleButton"):IsChecked(),
		bDPSRole = wndEdit:FindChild("DPSRoleButton"):IsChecked(),
		tCurrentAttendees = EditedEvent.Detail.tCurrentAttendees,	
		strRealm = EditedEvent.Detail.strRealm,
		EventModified = os.time(),
		tApplicationsProcessed = EditedEvent.Detail.tApplicationsProcessed,
	}	

		tEvents[EditedId].strEventStatus = EditedEvent.strEventStatus
		tEvents[EditedId].EventModified = os.time()
		if tEvents[EditedId].Detail.Hour > 12 then 
			tEvents[EditedId].Detail.Hour = tEvents[EditedId].Detail.Hour - 12
			tEvents[EditedId].Detail.AmPm = "pm"
		end
		tEvents[EditedId].nEventSortValue = self:CreateSortValue(tEvents[EditedId].Detail)
		if tEvents[EditedId].nEventSortValue < os.time() then
			--Print("Event Manager error: Events cannot be edited to occur in the past.")
			tEvents[EditedId] = EditedEvent
		end	
		
		for idx, player in pairs (EditedEvent.Detail.tCurrentAttendees) do
			if player.Name == GameLib.GetPlayerUnit():GetName() then
				player.Roles = self:GetSelectedRoles(wndEdit:FindChild("TankRoleButton"):IsChecked(),
					wndEdit:FindChild("HealerRoleButton"):IsChecked(),
					wndEdit:FindChild("DPSRoleButton"):IsChecked())
			end
		end
	end
	self.wndEditEvent:Show(false)
	MsgTrigger = "Event Edited by owner"
	self:EventsMessenger(MsgTrigger)
	tMetaData.nLatestUpdate = os.time()
	self:PopulateItemList(tEvents)	
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
	local EventId = SelectedEvent
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
	--SendVarToRover("SignUpSubmitSelectedEvent",SelectedEvent)
	--SendVarToRover("SignUpSubmitInitBacklog",tEventsBacklog)
	local SelectedEventId = SelectedEvent.EventId
	local SelectedEventDetail = SelectedEvent.Detail
	local EventName = SelectedEvent.Detail.EventName
	nSignUpTime = os.time()
	local tNewAttendeeInfo = {{Name = GameLib.GetPlayerUnit():GetName(),Status = "Attending", nSignUpTime = nSignUpTime, 
	Roles = self:GetSelectedRoles(bSignUpTank ,bSignUpHealer ,bSignUpDPS )}}
	BacklogId = GameLib.GetRealmName()..GameLib.GetPlayerUnit():GetName()..os.time()

	tEventsBacklog[BacklogId] = {		
	EventId = SelectedEvent.EventId,
	strEventStatus = SelectedEvent.strEventStatus,
	EventName = SelectedEvent.Detail.EventName,
	EventSyncChannel = SelectedEvent.EventSyncChannel,
	BacklogID = BacklogId,
	BacklogOwner = GameLib.GetPlayerUnit():GetName(),
	BacklogOwnerStatus = "Attending",
	BacklogOwnerRoles = self:GetSelectedRoles(self.wndSignUp:FindChild("TankRoleButton"):IsChecked()
		,self.wndSignUp:FindChild("HealerRoleButton"):IsChecked()
		,self.wndSignUp:FindChild("DPSRoleButton"):IsChecked()),
	nBacklogCreationTime = nSignUpTime,
	nBacklogExpirationTime = SelectedEvent.nEventSortValue}
	MsgTrigger = "Player added new sign up backlog for this event."
	
	
	--SendVarToRover("Sign Up Backlog created",tEventsBacklog[SelectedEvent])
	MsgTrigger = "New attendee added to backlog for this event."

	--Print("Sign Up request sent for "..EventName)
	self:PopulateItemList(tEvents)
	self.wndSignUp:Show(false)
	
	MsgTrigger = MsgTrigger
	self:EventsMessenger(MsgTrigger)
end


function EventManager:OnEventDeclined (wndHandler, wndControl, eMouseButton)
	local tEvent = wndControl:GetParent():GetData()
	--self.wndSelectedListItem = wndControl:GetParent()
	local nDeclinedEventId = tEvent.EventId
	local tEventInfo = tEvent.Detail
	local tEventAttendees = tEventInfo.tCurrentAttendees
	local tNotAttending = tEventInfo.tNotAttending
	local strPlayerName = GameLib.GetPlayerUnit():GetName()
	local tPlayerRoles  = self:GetSelectedRoles( 0, 0, 0 )
	local DeclinedBacklogId = GameLib.GetRealmName()..GameLib.GetPlayerUnit():GetName()..os.time()
	nSignUpTime = os.time()
	--SendVarToRover("EventDecliningId", nDeclinedEventId)
	--SendVarToRover("EventDecliningInfo", tEvent.Detail)
	--SendVarToRover("EventDecliningData",tEvent)
	--SendVarToRover("tEventsBacklog",tEventsBacklog[DeclinedBacklogId])

	
	tEventsBacklog[DeclinedBacklogId] = {		
	EventId = nDeclinedEventId,
	EventName = tEvents[nDeclinedEventId].Detail.EventName,
	strEventStatus = tEvents[nDeclinedEventId].strEventStatus,
	EventSyncChannel = tEvents[nDeclinedEventId].EventSyncChannel,
	BacklogID = DeclinedBacklogId,
	BacklogOwner = GameLib.GetPlayerUnit():GetName(),
	BacklogOwnerStatus = "Declined",
	BacklogOwnerRoles = tPlayerRoles,
	nBacklogCreationTime = nSignUpTime,
	nBacklogExpirationTime = tEvents[nDeclinedEventId].nEventSortValue,
}


	MsgTrigger = "New Declined Event Backlog Created for "..tEvents[nDeclinedEventId].Detail.EventName




	self:PopulateItemList(tEvents)

	self:EventsMessenger(MsgTrigger)
end 

function EventManager:OnEventCancel(wndHandler, wndControl, eMouseButton)
	if self.wndSelectedListItem == nil then
		--Print("Events Manager Error: You must select an event from the list before pressing the cancel button.")
		return
	else
		local SelectedEvent = self.wndSelectedListItem:GetData()
		--SendVarToRover("SelectedEvent",SelectedEvent)
		local nCanceledEventId = SelectedEvent.EventId
		self:OnEventDeleteWarning(SelectedEvent,nEventId)
	end
end

function EventManager:OnEventDeleteWarning(SelectedEvent,nEventId)
	
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
	for key, event in pairs(tEvents) do
		if event.EventId == nEventId then
			if event.Owner == GameLib.GetPlayerUnit():GetName() then
				event.strEventStatus = "Canceled"
				--Print("Events Manager: The event has been canceled.")
			else
				--Print("Events Manager Error: Only the creator of an event may cancel an event.")
				self.wndDeleteConfirm:Show(false)
				return				
			end
		end
	end
	self.wndDeleteConfirm:Show(false)
	MsgTrigger = "EventCancelConfirmed"
	self:EventsMessenger(MsgTrigger)
	tMetaData.nLatestUpdate = os.time()
	self:PopulateItemList(tEvents)
end

-----------------------------------------------------------------------------------------------
-- ItemList Functions
-----------------------------------------------------------------------------------------------
-- populate item list
function EventManager:PopulateItemList(list)
	-- make sure the item list is empty to start with
	self.wndItemList:DestroyChildren()
	self.wndSelectedListItem = nil
	
	list = self:CleanTable()
	if list == nil then return
	else 
    -- add 20 items
    for Event, EventId in pairs(list) do
    	self:AddItem(Event)
    	
    end
    self.wndItemList:ArrangeChildrenVert(0,SortListItems)
 end

end


-- add an item into the item list
function EventManager:AddItem(i)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "ListItem", self.wndItemList, self)
	local wndSelectedItemHighlight = wnd:FindChild("SelectedListItemHighlight"):Show(false)
	local SignUpButton = wnd:FindChild("SignUpButton")
	local DeclineButton = wnd:FindChild("DeclineButton")
	local PendingImage = wnd:FindChild("PendingImage")
	local strEventInfo = ""
	local PlayerAttending = false
	
	-- keep track of the window item created
	self.tItems[i] = wnd

	-- Build text for display in list item
	local tEvent = tEvents[i]
	
	local tEventInfo = tEvent.Detail
	local tEventAttendees = tEventInfo.tCurrentAttendees
	local tEventRoles = tEventInfo.tCurrentAttendees
	local PlayerAttending = false
	tEventInfo.nCurrentTanks = 0
	tEventInfo.nCurrentHealers = 0
	tEventInfo.nCurrentDPS = 0
	--SendVarToRover("Populated Items", tEvent)
		for idx, player in pairs(tEventInfo.tCurrentAttendees) do
		if player.Name == GameLib.GetPlayerUnit():GetName() then	
			if player.Status == "Attending" then
				PlayerAttending = true
				if player.Roles.Tank == 1 then 
					tEventInfo.nCurrentTanks = tEventInfo.nCurrentTanks + 1
				end
				if player.Roles.Healer == 1 then
					tEventInfo.nCurrentHealers = tEventInfo.nCurrentHealers + 1
				end
				if player.Roles.DPS == 1 then 
					tEventInfo.nCurrentDPS = tEventInfo.nCurrentDPS + 1
				end
			elseif player.Status == "Declined" then
				PlayerAttending = false
			elseif player.Status == "Pending" then
				PlayerAttending = "Pending"
			else PlayerAttending = "unknown"
			end
		end
	end

	if PlayerAttending == true then 
		SignUpButton:Show(false)
		DeclineButton:Show(true)
		PendingImage:Show(false)
	elseif PlayerAttending == false then
		SignUpButton:Show(true)
		DeclineButton:Show(false)
		PendingImage:Show(false)
	else
		SignUpButton:Show(true)
		DeclineButton:Show(true)
		PendingImage:Show(false)
	end
	tEventInfo = tEventInfo
	tEventAttendees = tEventInfo.tCurrentAttendees

		if not tEventAttendees then
			tEventInfo.nEventAttendeeCount = self:ProcessAttendingCount(tEventAttendees)
		else tEventInfo.nEventAttendeeCount = self:TableLength(tEventAttendees)
		end

		if not tEventRoles then
			tEventInfo.nCurrentTanks = 0
			tEventInfo.nCurrentHealers = 0
			tEventInfo.nCurrentDPS = 0
		else
			tEventInfo.nCurrentTanks, tEventInfo.nCurrentHealers, tEventInfo.nCurrentDPS = self:RoleCount(tEventInfo.tCurrentAttendees)
		end
		if tEvent.strEventStatus == "Canceled" then
			strEventInfo = "The event, "..tEventInfo.EventName..", scheduled for "..string.format("%02d",tEventInfo.Month).."/"..string.format("%02d",tEventInfo.Day).."/"..tEventInfo.Year..", at\n"..
			string.format("%02d",tEventInfo.Hour)..":"..string.format("%02d",tEventInfo.Minute).." "..tEventInfo.AmPm.." "..
			string.upper(tEventInfo.TimeZone).."\nhas been cancelled by "..tEvent.Owner

			SignUpButton:Show(false)
			DeclineButton:Show(false)
			PendingImage:Show(false)
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
				table.insert(AttendeeList,tEventInfo.tCurrentAttendees[key].Name)
			end
		wnd:SetData(tEvent)
		wnd:SetTooltip(table.concat(AttendeeList, '\n'))
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

   	-- if new selected item is canceled, dump and hold for new item selection
   if SelectedEvent.strEventStatus == "Canceled" then
   	self.wndSelectedListItemDetail:Show(false)
   	return
   end
	-- else continue populating item data.
	local tAttendingSelectedItem = {}
	local tNotAttendingSelectedItem = {}
	for key, player in pairs(selectedItemText.tCurrentAttendees) do
		if selectedItemText.tCurrentAttendees[key].Status == "Attending" then
			table.insert(tAttendingSelectedItem, player.Name.." ("
			..player.Roles.Tank.."/"..player.Roles.Healer.."/"
			..player.Roles.DPS..")")
		elseif player.Status == "Declined" then
			table.insert(tNotAttendingSelectedItem, player.Name)
		end
	end

	--SendVarToRover("tAttendingSelectedItem",tAttendingSelectedItem)
	--SendVarToRover("tNotAttendingSelectedItem",tNotAttendingSelectedItem)
	local AttendingSection = "Attending \n(Role(s) Selected: tank/healer/dps):\n \n"..table.concat(tAttendingSelectedItem,'\n').."\n \n"
	local NotAttendingSection = "Not Attending:\n \n"..table.concat(tNotAttendingSelectedItem, '\n')
	local DetailsAttendingText = ""									
	if #tAttendingSelectedItem == 0 then
		AttendingSection = ""
	end
	if #tNotAttendingSelectedItem == 0 then 
		NotAttendingSection = ""
	end
	if #tAttendingSelectedItem + #tNotAttendingSelectedItem == 0 then
		DetailsAttendingText = "Still waiting for attendance responses for this event."
	else
		DetailsAttendingText = AttendingSection..NotAttendingSection
	end


	--SendVarToRover("SelectedEvent",SelectedEvent)
	for key, event in pairs(tEvents) do
		if SelectedEvent.Owner == GameLib.GetPlayerUnit():GetName() then
			self.wndSelectedListItemDetail:FindChild("EditEventButton"):Show(true)
		else
			self.wndSelectedListItemDetail:FindChild("EditEventButton"):Show(false)
		end

		local ShowSignUpButton = true
		for idx, player in pairs(SelectedEvent.Detail.tCurrentAttendees) do
			if player.Name == GameLib.GetPlayerUnit():GetName() and player.Status == "Attending" then --GameLib.GetPlayerUnit():GetName() then
				ShowSignUpButton = false
			end
		end
		if ShowSignUpButton == true then
			self.wndSelectedListItemDetail:FindChild("SignUpButton"):Show(true)
		end
	end

	self.wndSelectedListItemDetail:FindChild("SelectedEventDescriptionBox"):SetText(selectedItemText.Description)
	self.wndSelectedListItemDetail:FindChild("EventDetailsWindow"):SetText(selectedItemText.EventName.. ", created by: "..SelectedEvent.Owner..
		"\nScheduled for: "..string.format("%02d",selectedItemText.Month).."/"..
		string.format("%02d",selectedItemText.Day).."/"..selectedItemText.Year.." at "..
		string.format("%02d",selectedItemText.Hour)..":"..string.format("%02d",selectedItemText.Minute).." "..selectedItemText.AmPm..
		" "..string.upper(selectedItemText.TimeZone).."\n \nThere are currently "..selectedItemText.nCurrentTanks.."/"..
		selectedItemText.MaxTanks.." Tanks, "..selectedItemText.nCurrentHealers.."/"..selectedItemText.MaxHealers..
		" Healers, and "..selectedItemText.nCurrentDPS.."/"..selectedItemText.MaxDps.." DPS signed up.")

	self.wndSelectedListItemDetail:FindChild("DetailsAttendingBox"):SetText(DetailsAttendingText)
	if SelectedEvent.strEventStatus ~= "Canceled" then
		self.wndSelectedListItemDetail:Show(true)
	else
		self.wndSelectedListItemDetail:Show(false)
	end
	--SendVarToRover("SelectedEventData",SelectedEvent)										
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
-- Helper functions
-----------------------------------------------------------------------------------------------
function EventManager:OnDelayTimer()
	if GameLib.GetPlayerUnit() then 
		self.timerDelay = nil 
		--
		if tMetaData.SyncChannel ~= "" then
			MsgTrigger = "InitTimerEnded"
			self:EventsMessenger(MsgTrigger)
		end

		
		else self.timerDelay:Start()
		end
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
	for k, v in pairs(T) do 
		if v.Status == "Attending" then 
		count = count + 1 
	end
end
return count
end

function EventManager:RoleCount(T)
	--SendVarToRover("roles table", T)
	local nTankCount = 0
	local nHealerCount = 0
	local nDPSCount = 0
	if not T then return nTankCount,nHealerCount,nDPSCount
	else
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
	end
	return nTankCount, nHealerCount, nDPSCount
end

function EventManager:GetSelectedRoles(bTankRole,bHealerRole,bDPSRole)
	--SendVarToRover("Roles",{bTankRole,bHealerRole,bDPSRole})
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

function EventManager:CreateAttendeeInfo(Owner,time,Roles)
	local Roles = Roles
	local Owner = Owner
	local time = time
	local tCurrentAttendees = {}
	if not Roles.Tank and Roles.Healer and Roles.DPS then
		tCurrentAttendees = {{Name = "", nSignUpTime = "", Roles = {},}}
	else
		tCurrentAttendees = {{Name = Owner,nSignUpTime = time,
		Roles = Roles}}		
	end
	return tCurrentAttendees
end	

function EventManager:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "Event Manager"})
end

function EventManager:ProcessLiveEvents(tMsg)
	local bNewMessages = false
	local nEventChanged = 0
	local ProcessedCount = 0
	local tMsg = tMsg
	local LiveCopy 
	local MessageToSend = false

	
	for IncomingId, IncomingEvent in pairs(tMsg.tEvents) do
		LiveCopy = false
		if not tEvents[IncomingId] then 
			tEvents[IncomingId] = IncomingEvent
			MessageToSend = true
			MessageTrigger = "Added another player's event to live event."
		end
	end
	ProcessedCount = ProcessedCount + 1
	--SendVarToRover("Processed tEvents", ProcessedCount)
	return
end


function EventManager:ImportBacklogEvents(tMsg)
	if not tMsg.tEventsBacklog then return end
	for IncomingId, IncomingEvent in pairs(tMsg.tEventsBacklog) do
		if not tEventsBacklog[IncomingId] then
				tEventsBacklog[IncomingId] = IncomingEvent
		end
	end
end

function EventManager:ProcessBacklogEvents(tMsg)
	local bNewMessages = false
	local nEventChanged = 0
	local KnownAttendee
	local AttendeeIdx
	local ProcessedCount = 0
	local DuplicateApp
	local LogCopy
	local tNeedsRemoval = {}
	MessageToSend = false

	for LiveEventId, LiveEvent in pairs(tEvents) do
		--SendVarToRover("LiveEvent", LiveEvent)
		if LiveEvent.Owner ~= GameLib.GetPlayerUnit():GetName() then
		else
			if not tMsg then return end
			for PendingId, PendingEvent in pairs(tMsg) do
				DuplicateApp = false
				if LiveEventId == PendingEvent.EventId then
				--SendVarToRover("PendingEvent",PendingEvent)
				-- compare processed apps with pending apps
					for idx, App in pairs(LiveEvent.Detail.tApplicationsProcessed) do
						--SendVarToRover("App", App)
						if App == PendingId then
							DuplicateApp = true
							break
							-- event has been processed before
						end
					end

					if DuplicateApp == false then
						--check known attendees to see if new attendee or role/status change
						KnownAttendee = false
						for idx,attendee in pairs(LiveEvent.Detail.tCurrentAttendees) do
							if attendee.Name == PendingEvent.BacklogOwner then
								KnownAttendee = true
								AttendeeIdx = idx
								break
							end
						end
						--Print ("Attendee Known?"..tostring(KnownAttendee))
						--SendVarToRover("KnownAttendee",KnownAttendee)
						-- attendee known, check status	
						if KnownAttendee == true then
							local attendee = LiveEvent.Detail.tCurrentAttendees[AttendeeIdx]
							--SendVarToRover("Attendee",attendee)
							if attendee.Status ~= PendingEvent.BacklogOwnerStatus then 
								--Print("Status changed")
							 	if PendingEvent.nBacklogCreationTime >= attendee.nSignUpTime then
							 		--Print("New Sign up time: "..PendingEvent.nBacklogCreationTime)
							 		--Print("Old Sign up time: "..attendee.nSignUpTime)
									--SendVarToRover("ApplicantStatusChanged", attendee.Status)
									-- Applicant status/role change
									attendee.Status = PendingEvent.BacklogOwnerStatus
									attendee.Roles = PendingEvent.BacklogOwnerRoles
									attendee.nSignUpTime = PendingEvent.nBacklogCreationTime+1
									--Print("Status, Roles, SignUpTimeSet")
									table.insert(LiveEvent.Detail.tApplicationsProcessed, PendingId)
									--Print("Record of processed event saved")
									LiveEvent.EventModified = os.time()
									--Print("EventModified time updated")
									ProcessedCount = ProcessedCount + 1
									--Print("Apps Processed: "..ProcessedCount)
									MessageToSend = true
									MsgTrigger = "Applicant's status changed."
								else
									--Print("Backlog has old sign up time")
								end
							end
						else
						if KnownAttendee == false then
							--SendVarToRover("NewAttendee",PendingEvent.BacklogOwner)
							-- New Applicant, insert record
							table.insert(LiveEvent.Detail.tCurrentAttendees,
								{Name = PendingEvent.BacklogOwner,
								nSignUpTime = PendingEvent.nBacklogCreationTime,
								Status = PendingEvent.BacklogOwnerStatus,
								Roles = PendingEvent.BacklogOwnerRoles})
							LiveEvent.EventModified = os.time()
							table.insert(LiveEvent.Detail.tApplicationsProcessed, PendingId)
							MessageToSend = true
							ProcessedCount = ProcessedCount + 1
							MsgTrigger = "New Attendee added to event"
						end
					end
				end
				--SendVarToRover("DuplicateAppStatus",tostring(DuplicateApp))
			end
		end
	end
	--SendVarToRover("Processed Backlog Events", ProcessedCount)	
	end
	self:ProcessMyBacklog(tEventsBacklog)
	if MessageToSend == true then
		self:EventsMessenger(MsgTrigger)
	end
end

function EventManager:CleanApplicationsList()
	local Dupes ={}  
	local t2 = {};
	if tEvents.Detail then  
		for key, app in pairs(tEvents.Detail.tApplicationsProcessed) do
			for i,v in pairs(app) do
			    if(t2[v] ~= nil) then
			        table.insert(Dupes,v)
			    end
			    t2[v] = i
			end
		end
		--SendVarToRover("AppDupes",Dupes)
	end

end

function EventManager:CleanBacklogList(t)
	local Dupes ={}  
	local t2 = {};
	if tEvents.Detail then  
		for key, entry in pairs(tEvents.Detail.tApplicationsProcessed) do
			for i,v in pairs(entry) do
			    if(t2[v] ~= nil) then
			        table.insert(Dupes,v)
			    end
			    t2[v] = i
			end
		end
		--SendVarToRover("AppDupes",Dupes)
	end

end


 
function EventManager:ProcessMyBacklog(tMsg)
	local bNewMessages = false
	local nEventChanged = 0
	local MyLogs = {}
	local tNeedsRemoval = {}
	MessageToSend = false
	
	for LogId, log in pairs(tMsg) do
		if log.BacklogOwner == GameLib.GetPlayerUnit():GetName() then
			MyLogs[LogId] = log
				self:CleanApplicationsList(MyLogs)
			
			for PendingId, PendingEvent in pairs(MyLogs) do
				--SendVarToRover("My Pending Log", PendingEvent)
				--SendVarToRover("My Pending Log ID", PendingId)
				if PendingEvent.nBacklogExpirationTime > os.time() then
					for EventId, Event in pairs(tEvents) do
						--SendVarToRover("My Pending Log Event",Event)
						--SendVarToRover("My Pending Log EventId",EventId)
						for ProcessedId, ProcessedApp in pairs(Event.Detail.tApplicationsProcessed) do
							--SendVarToRover("My Pending Processed App",ProcessedApp)
							--SendVarToRover("My Pending Processed AppId", ProcessedId)
							if ProcessedApp == PendingId then 
								table.insert(tNeedsRemoval,PendingId)

								--SendVarToRover("Needs Removal",tNeedsRemoval)
							end
						end
						for idx, player in pairs(Event.Detail.tCurrentAttendees) do
							if player.Name == GameLib.GetPlayerUnit():GetName() then
								table.insert(tNeedsRemoval, PendingId)
							end
						end
					end
				else
					table.insert(tNeedsRemoval,PendingId)
					MessageToSend = true
					MsgTrigger = "Removed expired log."
				end
			end
		end		
	end
	if #tNeedsRemoval > 0 then 
		--SendVarToRover("My Removal Table", tNeedsRemoval)
		MsgTrigger = "Removed my backlogged events"
		MessageToSend = true
		for idx, id in ipairs(tNeedsRemoval) do
			local i = 1
			tEventsBacklog[id] = nil
			--Print(i.." events processed from your backlog.")
		end
	end
	if MessageToSend == true then
		self:EventsMessenger(MsgTrigger)
	end
end



function EventManager:OnMajorVersionConfirmation(wndHandler,wndControl,eMouseButton)
	MajorVersionRewrite = true
	ShowMajorVersionWarning = false
	tEvents = {}
	tEventsBacklog = {}
	tMetaData = {nLatestUpdate = 0 ,SyncChannel = "" ,Passphrase = "",tSecurity = {},RequireSecureEvents = false}
	RequestReloadUI(true)
end

function EventManager:ProcessAttendingCount(t)
	local nAttendeesCount = 0
	if t.Status == "Attending" then
		nAttendeesCount = nAttendeesCount + 1
	elseif t.Status == "Declined" then
		nAttendeesCount = nAttendeesCount - 1
	end
	return nAttendeesCount
end



-----------------------------------------------------------------------------------------------
-- Form Check & Options Functions
-----------------------------------------------------------------------------------------------
function EventManager:OnOptionsWindowShow (wndHandler, wndControl, eMouseButton)
	if tMetaData.SyncChannel ~= nil or tMetaData.Passphrase ~= nil or tMetaData.SecurityRequired ~= nil then
		self.wndOptions:FindChild("SyncChannelBox"):SetText(tMetaData.SyncChannel)
		self.wndOptions:FindChild("PassphraseBox"):SetText(tMetaData.Passphrase)

	end
	if tMetaData.SecurityRequired == true then
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
	tMetaData.nLatestUpdate = 0
	tMetaData.SyncChannel = strSyncChannel
	tMetaData.Passphrase = self.wndOptions:FindChild("PassphraseBox"):GetText()
	tMetaData.SecurityRequired = self.wndOptions:FindChild("EnableSecureEventsButton"):IsChecked()
	EventsChan = ICCommLib.JoinChannel(strSyncChannel, "OnEventManagerMessage", self)
	----Print("Events Manager: Joined sync channel "..strSyncChannel)
	wndControl:GetParent():Show(false)
	MsgTrigger = "OptionsSubmitted"
	self:EventsMessenger(MsgTrigger)
end

function EventManager:OnSecurityChecked(wndHandler, wndControl, eMouseButton)
	tMetaData.SecurityRequired = true
	if self.wndOptions:IsVisible() == true then
		if self.wndOptions:FindChild("ShowSecurityWhitelist"):IsVisible() == false then
			self.wndOptions:FindChild("ShowSecurityWhitelist"):Show(true)
		end	
	end
	self.wndSecurity:Show(true)
	
end

function EventManager:OnSecurityUnChecked(wndHandler, wndControl, eMouseButton)
	tMetaData.SecurityRequired = false
	if self.wndOptions:IsVisible() == true then
		if self.wndOptions:FindChild("ShowSecurityWhitelist"):IsVisible() == true then
			self.wndOptions:FindChild("ShowSecurityWhitelist"):Show(false)
		end
	end
	self.wndSecurity:Show(false)
end

function EventManager:OnSecurityChecked(wndHandler, wndControl, eMouseButton)
	tMetaData.SecurityRequired = true
end


-----------------------------------------------------------------------------------------------
-- EventManager Instance
-----------------------------------------------------------------------------------------------
local EventManagerInst = EventManager:new()
EventManagerInst:Init()
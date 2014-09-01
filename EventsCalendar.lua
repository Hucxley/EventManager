-----------------------------------------------------------------------------------------------
--[[ Calendar Package for NCSoft's Wildstar.  
-- Generates procedural calendars without relying on days of the month tables typically used in
-- lua calendars.

	usage: local calendar = Apollo.GetPackage("TC:WSCalendar-1.0").tPackage

]]--
-----------------------------------------------------------------------------------------------
local MAJOR, MINOR = "TC:WSCalendar-1.0",1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
	return -- no upgrade is needed
end
local LibCalendar = APkg and APkg.tPackage or {}

require "Window"
 
-----------------------------------------------------------------------------------------------
-- LibCalendar Module Definition
-----------------------------------------------------------------------------------------------
local LibCalendar = {}
local usermonth
local oldcolumn = 1
local monthdayscount
local deaddays = {}
local CalArray = {value = 1, epochtime = 0, GridType = ""}
local CalDisplay = {}
local calcmonth
local column
local row
local ndisplay
local leadingdays
local epochtime
local newepoch
local leadingcolumns
local correction
local tCurrentDay ={}
local trailingdays
local ViewingMonth = {}
local tDisplayedMonth = {}
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressedFlyby")
local kcrNormalText = ApolloColor.new("UI_BtnTextHoloNormal")
local kcrDeadDaysText = ApolloColor.new("darkgray")
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function LibCalendar:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.tItems = {} -- keep track of all the list items
	o.wndSelectedListItem = nil -- keep track of which list item is currently selected

    return o
end

function LibCalendar:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- LibCalendar OnLoad
-----------------------------------------------------------------------------------------------
function LibCalendar:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("EventsCalendar.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- LibCalendar OnDocLoaded
-----------------------------------------------------------------------------------------------
function LibCalendar:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "LibCalendarForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
		-- item list
		self.wndItemList = self.wndMain:FindChild("ItemList")
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("calendar", "OnLibCalendarOn", self)



		tCurrentDay = os.date("*t",os.time())
		tDisplayedMonth = os.date("*t",os.time({year = tCurrentDay.year, month = tCurrentDay.month, day = 15, hour, 00}))
		ViewingMonth = {strMonth = os.date("%B", os.time(tDisplayedMonth)), nYear = os.date("%Y", os.time(tDisplayedMonth))}
		self:BuildCalendarTable(tDisplayedMonth)

	end
end

-----------------------------------------------------------------------------------------------
-- LibCalendar Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/horztest"
function LibCalendar:OnLibCalendarOn()
	self.wndMain:Invoke() -- show the window

	-- populate the item list
	self:ConstructCalendarGrid(CalArray)
end





-----------------------------------------------------------------------------------------------
-- LibCalendarForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function LibCalendar:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function LibCalendar:OnCancel()
	self.wndMain:Close() -- hide the window
end

function LibCalendar:BuildCalendarTable(tDisplayedMonth)
SendVarToRover("Displayed Month",tDisplayedMonth)
usermonth = tDisplayedMonth.month
oldcolumn = 1
monthdayscount = 1
deaddays = {}
CalArray = {}
CalDisplay = {}
newepoch  = 0
trailingdays = 0

usermonth = tDisplayedMonth.month


    column = tonumber(os.date("%w",os.time({year = tDisplayedMonth.year, month = usermonth, day = 1})) + 1)
    epochtime = os.time({year = tDisplayedMonth.year, month = usermonth, day = 1})



    if column > 1 then
      leadingcolumns = column - 1
      newepoch = epochtime
        for k = leadingcolumns, 1, -1 do
          newepoch = epochtime
          newepoch = newepoch - 86400*(leadingcolumns)
          correction = os.date("%d",newepoch)
          print(correction)
          table.insert(CalArray, {value = correction, epoch = newepoch, GridType = "Inactive"})
          if leadingcolumns > 1 then
            leadingcolumns = leadingcolumns - 1
          end         
        end
    end
  
  for j = 1, 32, 1 do 
    calcmonth = tonumber(os.date("%m", os.time({year = tDisplayedMonth.year, month = usermonth, day = j})))
  
      if not calcmonth then return
      else
        if calcmonth == usermonth then
          monthdayscount = monthdayscount + 1
        end
      end
      end

    



  for i = 1, monthdayscount-1, 1 do 
    column = tonumber(os.date("%w",os.time({year = tDisplayedMonth.year, month = usermonth, day = i})) + 1)
  		epochtime = os.time({year = tDisplayedMonth.year, month = usermonth, day = i})
    ndisplay = i
    print(ndisplay)
    if i < monthdayscount then
      table.insert(CalArray,{value = ndisplay, epoch = epochtime, GridType = "Active"})
     
    end
    --Print(tonumber(column))
  end
  if column < 7 then 
  	trailingdays = 7-column
  	--Print(trailingdays)
  	newepoch = epochtime
  	for m = 1, trailingdays, 1 do
  		newepoch = newepoch + (86400)
  		correction = os.date("%d", newepoch)
  		table.insert(CalArray, {value = correction, epoch = newepoch, GridType = "Inactive"})
  	end
  end
  return CalArray
end




-----------------------------------------------------------------------------------------------
-- ItemList Functions
-----------------------------------------------------------------------------------------------
-- populate item list
function LibCalendar:ConstructCalendarGrid(list)
	-- make sure the item list is empty to start with

	-- make sure the item list is empty to start with
	self.wndItemList:DestroyChildren()
	self.wndSelectedListItem = nil

	if list == nil then return
	else 

		for i = 1,#CalArray do
	        self:AddCalendarItem(i)
		end
	
		-- now all the item are added, call ArrangeChildrenVert to list out the list items vertically
		self.wndItemList:ArrangeChildrenTiles()
		self.wndMain:FindChild("MonthYearDisplay"):SetText(ViewingMonth.strMonth..", "..ViewingMonth.nYear)
	end
end


function LibCalendar:AddCalendarItem(i)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "CalendarItem", self.wndItemList, self)
	local wndSelectedItemHighlight = wnd:FindChild("SelectedDayHighlight"):Show(false)
	
	-- keep track of the window item created
	--self.CalendarItems[i] = wnd

	-- give it a piece of data to refer to 
	local wndDateText = wnd:FindChild("Text")
	if wndDateText then -- make sure the text wnd exist
		wndDateText:SetText(CalArray[i].value) -- set the item wnd's text to "item i"
		if CalArray[i].GridType == "Active" then
			wndDateText:SetTextColor(kcrNormalText)
		else
			wndDateText:SetTextColor(kcrDeadDaysText)
		wnd:FindChild("SelectedDayHighlight"):Show(false)

		end
		wnd:SetData(CalArray[i])
	end
end

-- when a list item is selected
function LibCalendar:OnListItemSelected(wndHandler, wndControl)
	SendVarToRover("selected list item",self.wndSelectedListItem)
    -- make sure the wndControl is valid
    if wndHandler ~= wndControl then
        return
    end
    
    -- change the old item's text color back to normal color
    local wndDateText
    if self.wndSelectedListItem ~= nil then
       wndDateText = self.wndSelectedListItem:FindChild("Text")
		local wndSelectedDay = self.wndSelectedListItem:FindChild("SelectedDayHighlight")
		if self.wndSelectedListItem:GetData().GridType == "Active" then
        wndDateText:SetTextColor(kcrNormalText)
      elseif self.wndSelectedListItem:GetData().GridType == "Inactive" then
      	wndDateText:SetTextColor(kcrDeadDaysText)
      end
      wndSelectedDay:Show(false)
    end
    
	-- wndControl is the item selected - change its color to selected
	self.wndSelectedListItem = wndControl
	wndDateText = self.wndSelectedListItem:FindChild("Text")
    wndDateText:SetTextColor(kcrSelectedText)
   local wndSelectedDay = self.wndSelectedListItem:FindChild("SelectedDayHighlight")
	wndSelectedDay:Show(true)
    
	Print( os.date("%x",self.wndSelectedListItem:GetData().epoch) .. " is selected.")
end

-----------------------------------------------------------------------------------------------
-- Button Functions
-----------------------------------------------------------------------------------------------
function LibCalendar:OnNextMonthButton(wndHandler,wndControl, eMouseButton)
local month = tDisplayedMonth.month
month = month + 1
if month > 12 then
	month = month - 12
	tDisplayedMonth.year = tDisplayedMonth.year + 1
end
tDisplayedMonth.month = month
ViewingMonth = {strMonth = os.date("%B", os.time(tDisplayedMonth)), nYear = os.date("%Y", os.time(tDisplayedMonth))}
self:BuildCalendarTable(tDisplayedMonth)
self:ConstructCalendarGrid(CalArray)
end

function LibCalendar:OnLastMonthButton(wndHandler,wndControl, eMouseButton)
local month = tDisplayedMonth.month
month = month - 1
if month < 1 then
	month = month + 12
	tDisplayedMonth.year = tDisplayedMonth.year - 1
end
tDisplayedMonth.month = month
ViewingMonth = {strMonth = os.date("%B", os.time(tDisplayedMonth)), nYear = os.date("%Y", os.time(tDisplayedMonth))}
self:BuildCalendarTable(tDisplayedMonth)
self:ConstructCalendarGrid(CalArray)
end


-----------------------------------------------------------------------------------------------
-- LibCalendar Instance
-----------------------------------------------------------------------------------------------
local LibCalendarInst = LibCalendar:new()
LibCalendarInst:Init()

Apollo.RegisterPackage(LibCalendar, MAJOR, MINOR, {})

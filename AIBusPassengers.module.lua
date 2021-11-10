local Enabled = true -- Quickly turn all AI passengers off.


--[[



Script version:		1.0.10 (10th Nov 2021)

--Changelog
-------------------------
Fixed bugs / badly documented things. Please report any issues to me!

Added ticketing. I still need to do passengers putting coins on the table, fines and unpaid fare reports,
plus their associated behaviours.



This module creates and manages AI passengers that can ride buses. It could also easily be adapted for other vehicles.
This is the additional documentation that describes every function in detail such that people can contribute to improving the code.
If you're just using this module, you only need to read the shorter documentation in the Config script parented to this script.
If you are adding to the code, read that as well, as it has information on bus and stop layout, etc.
This documentation isn't very formal, like Roblox's documentation. Maybe that's worse? Who knows...

A note on dependencies:
This module uses regiLibrary, which is just some assorted functions. It is open source so you can look at it.

--Function List
-------------------------
This is a complete list of every function in the module described in detail.
They are sorted into sections both here and in the code itself, denoted by headers such as the one above.
It may actually make more sense to read from the bottom up, as the systems the above functions run on are described there.

--Getters
-------------------------
The getter functions (with names starting 'Get'...) serve to fetch objects of buses based on how the game organises them.
They are initialised from Config, so start out as empty scripts.
How they are used is described more in the short docs, but in brief, they use two functions: GetStopLocation and GetBusLocation.
These take a bus and number as parameters and use the number and a table to determine what to return.

--Ticketing
-------------------------
This module doesn't come with a native ticketing system, because I haven't yet written one.
However, all ticketing is done through the BoardBus function. 
This takes a passenger, bus and stop as parameters, handles ticketing and returns a boolean for if it was successful.
If it was, the passenger will sit down - otherwise, they will get off again.
This fires when the passenger reaches the InsideBoardingPoint outside the cab.

--Data Fetchers
-------------------------
Data fetchers are like the getters, but they don't directly get data. However, many use the getters. 
As such, they don't have the 'Get' prefix.

The RouteIndexOf function finds a given route string in the Config.Routes table.
It then returns its index.

The PassengersAtStop function returns a table of all passengers at a stop.
It does this using the WaitingStop value in PassengerData, NOT the waiting area.

The RandomStopSpawn function provides a random point in a stop's waiting area to spawn a passenger.
It uses some complex CFrame stuff, and handles both position and orientation.

The IsOnRoute function checks if a stop is on a route.

The IsBus function is used to check if a vehicle is a bus. It returns true by default.
It only needs to handle things within the bus folder, and is intended for people who store buses in workspace, not a subfolder.
*COUGH* Apsley. (Update: And all other games, apparently. Whyyyyyyyyyyyyy)

The IsFull function returns whether a bus is full.

The GetDriver function gets the driving seat of a bus, then uses that to return a driver or nil.
It needs to check a lot of things to do this - not just GetPlayerFromCharacter(DrivingSeat.Occupant)

The CurrentStop function returns the stop a bus is at, or nil if not any.
It uses the stop detector and bus trigger, so isn't 100% accurate.

The FindSeat function finds a passenger a seat or standing space on a bus.
This uses random numbers for semi-realism.
Obviously, it would be better to 'prioritise' certain seats - I'll do it one day...

BoardingQueueFromBus and AlightingQueueFromBus return a table.
These queues are stored in tables, which in turn are in two larger tables.
They also have events tied to them (with references in the tables).
I'm not too proud of this, so help improving the system would be appreciated.

The CanBoard function checks the route of a bus to see if it goes to a passenger's destination.

The CanMoveTo function checks various properties to see if a passenger can move to waiting outside bus doors, or get on, yet.
It's quite broken.

--GUI
-------------------------
SetDriverGUI is the only GUI function. It takes a GUI from elsewhere and turns it on.
I want to make this more modular in future so you can customise how the GUIs work from this function alone.

--Animations & Seating
-------------------------
The GetATracks function returns a table of passenger animation tracks.
I... don't really know what this does, to be honest. Sorry.

The AnimatePassenger function plays animations. This is complex, and I'm bad at it, so there's a custom function.
Probably very laggy etc.

The Unseat and Seat functions either remove a passenger from a seat or put them into one.
They're quite short and simple.

The TeleportToPosition function teleports a passenger by :SetPrimaryPartCFrame().
It checks how far they are and won't teleport very short distances.
This helps with performance.

The MoveTo function has a passenger walk to a part.
It doesn't handle animations - that has to be done manually when calling it (allowing for doing multiple at once)
It uses Humanoid:MoveTo() so handles part movement. However, as it doesn't use pathfinding, it's not the best.
If you think you could make this module use pathfinding, your help would be greatly appreciated - I've tried twice.

The MoveToPosition function is a wrapper for the above that creates and destroys a part.

--Boarding & Alighting
-------------------------
The RingBell function rings the bell. It prevents duplicate ringing, ringing when doors open, etc.
If it breaks, check for 'Failed to load sound rbxassetid://[ID]: Unable to download sound data' errors in output.
Sorry, this a Roblox issue.

The Alight function waits for the bus to stop, then has a passenger get off.
It doesn't check if a passenger is at their destination.
This prevents passengers getting stuck on buses and so on. After ringing the bell, they get off at the next stop.

The BusArrivedAtStop function is a key function that contains all of the boarding logic
I may separate it out in future, as it's about 200 lines long.
It goes from when a bus is detected right up to calling Alight() after getting on.
Hopefully you can get a better understanding of how it works by reading it.

--Time & Peaking
-------------------------
The IsPeriod function checks to see if it's a certain period. 
A period is morning peak, evening peak, daytime or night. It determines peaking.

The CurrentTimePeriod function uses the above to get the period, and uses the date to get a better version.
There are 8 types, with two extra day and night types for both weekend days.

The CurrentMultiplier function returns how much passenger spawn numbers at a stop should be multipled by.
It takes a stop within a route table, as well as whether to multiply boarding or alighting numbers.
It uses the CurrentTimePeriod function.

--Miscellaneous
-------------------------
The SpawnPassenger function... spawns a passenger at a set stop to get a set route.
It's worth noting that the route is only used to decide destination: passengers board any bus to where they're going.
This has to do many tasks to set the passenger up.

The SetupBus function sets up a bus with its BusData for use by passengers.
It also manages GUI changes and events.
It's not very well optimised and uses a coroutine-embedded-while loop. Events were worse.

Finally, the Passengers.Start function is the module's only global (public) function.
It takes a Config table as a parameter and does an assortment of things.
Most of it is 'for every x, do this' stuff. It also handles passenger spawning



]]



local Passengers = {}



--You can alternatively install this manually by going to https://roblox.com/library/6113306211
local regiLibrary = require(6113306211)

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local ContextActionService = game:GetService('ContextActionService')
local Rnd = Random.new()

local Config = {}

local Avatars = {}
local Pavements = {}
local BoardingQueues = {}
local AlightingQueues = {}
local BusMovementTweenInfos = {}
local PassengerATracks = {}
local CurrentGuis = {}



--Data Fetchers
--------------------------------------------------
--------------------------------------------------

--Routes
-------------------------

--find route Route in Config.Routes
local function RouteIndexOf(Route)
	for i, ArrayRoute in ipairs(Config.Routes) do
		if ArrayRoute[1][1] == Route then
			return i
		else
		end
	end

	return nil --if the route wasn't found
end



--Stops
-------------------------

--get a table of passengers at a stop
local function PassengersAtStop(Stop, Route)
	local t = {}

	--loop through all passengers
	for _, Passenger in ipairs(game.Workspace.LoadedPassengers:GetChildren()) do
		if Passenger.PassengerData.WaitingStop.Value == Stop then
			if Route == nil or Route == Passenger.PassengerData.RouteCode.Value then
				table.insert(t, Passenger)
			end
		end
	end

	return t
end



--get a random spawn point CFrame within a stop's waiting area
local function RandomStopSpawn(Stop)
	local PositionPart = Config.GetStopLocation(Stop, 'WaitingArea')
	local SpawnPosition = regiLibrary.vect_randomCoordInPart(PositionPart, 'randomFloat')
	local SpawnOrientation = regiLibrary.vect_randomOrientation('randomFloat')
	
	-- Don't randomise Y position, X/Z orientation
	local PositionCFrame = CFrame.new(Vector3.new(SpawnPosition.X, PositionPart.Position.Y, SpawnPosition.Z))
	local AngleCFrame = CFrame.Angles(PositionPart.Orientation.X, SpawnOrientation.Y, PositionPart.Orientation.Z)
	return PositionCFrame * AngleCFrame	
end



--check if a stop is on a route, and returns its index if so
local function IsOnRoute(Stop, Route)
	--firstly, find the route
	local RouteTable = Config.Routes[RouteIndexOf(Route)]

	--now, check its stops
	if RouteTable ~= nil then
		for count = 2, #RouteTable do
			if RouteTable[count][1] == Stop then
				return count
			end
		end
	end

	return nil --if we never found it
end



--Buses
-------------------------

--check if a bus is full
local function IsFull(Bus)	
	local Seats = Config.GetBusLocation(Bus, 'Seats'):GetChildren()
	local SSpaces = Config.GetBusLocation(Bus, 'StandingSpaces'):GetChildren()

	--repeat this loop for both, by combining
	for _, a in ipairs(Seats, SSpaces) do
		if a.Taken.Value == nil then
			return false --there's at least 1 free space
		end
	end

	return true --no spaces found
end



--get the driver of a bus
local function GetDriver(Bus)
	local DSeat = Config.GetBusLocation(Bus, 'DrivingSeat')
	local Driver = DSeat.Occupant
	if Driver == nil then
		return nil
	else
		return Players:GetPlayerFromCharacter(Driver.Parent) --.Parent to get the model, not the humanoid
	end
end



--get whether the bus is currently at a stop
local function CurrentStop(Bus)
	local Trigger = Config.GetBusLocation(Bus, 'Trigger')

	for _, Part in ipairs(Trigger:GetTouchingParts()) do --loop through all parts looking for stop detectors
		if Part.Name == Config.DetectorName then
			--found our detector - now we need to get its stop
			return Config.GetStopLocation(Part, 'FromDetector')
		end
	end

	--if we didn't find it
	return nil
end



--find a passenger a seat on a bus
local function FindSeat(Bus)
	--get the Seats folder, get its children and shuffle the table
	local Seats = regiLibrary.table_shuffle(Config.GetBusLocation(Bus, 'Seats'):GetChildren())
	local StandingSpaces = Config.GetBusLocation(Bus, 'StandingSpaces'):GetChildren()

	--first, try seats
	if Config.UseSeatCheckLimit == false then
		for _, s in ipairs(Seats) do
			if s.Taken.Value == nil then
				return { s, false } --found one!
			end
		end
	else
		--only try the specified amount
		for count = 1, Config.Movement.MaxSeatChecks do
			if Seats[count].Taken.Value == nil then
				return { Seats[count], false }
			end
		end
	end

	--now try standing spaces
	for _, s in ipairs(StandingSpaces) do
		if s.Taken.Value == nil then
			return { s, true }
		end
	end

	--all taken, but try seats one last time if we can
	if Config.CheckAllSeatsIfFull == true then
		for _, s in ipairs(Seats) do
			if s.Taken.Value == nil then
				return { s, false }
			end
		end		
	end

	--nothing :(
	return nil
end



--get the boarding queue table of a bus
local function BoardingQueueFromBus(Bus)
	for _, Queue in ipairs(BoardingQueues) do
		if Queue[1] == Bus then --Queue[1] is the bus reference
			return Queue
		end
	end
end



--get the alighting queue table of a bus
local function AlightingQueueFromBus(Bus)
	for _, Queue in ipairs(AlightingQueues) do
		if Queue[1] == Bus then --Queue[1] is the bus reference
			return Queue
		end
	end
end



--Ticketing
-------------------------
-------------------------

-- Allow passengers to talk
local function CreateSpeechBubble(Passenger, Content, Lifetime)
	-- Create a speech bubble above the passenger
	local BillboardGui = Instance.new('BillboardGui')
	BillboardGui.Adornee = Passenger.Head
	BillboardGui.Size = UDim2.fromOffset(150, 50)
	BillboardGui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)

	-- The label itself
	local TextLabel = Instance.new('TextLabel')
	TextLabel.Size = UDim2.fromScale(1, 1)
	TextLabel.TextScaled = true
	TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	TextLabel.BorderSizePixel = 0
	TextLabel.Font = Enum.Font.Arial
	TextLabel.Text = Content

	-- Add a UICorner for good measure
	local UICorner = Instance.new('UICorner')
	UICorner.CornerRadius = UDim.new(0.1, 0)
	UICorner.Parent = TextLabel

	TextLabel.Parent = BillboardGui
	BillboardGui.Parent = Passenger.Head

	task.wait(Lifetime)
	BillboardGui:Destroy()
end



-- Date manipulation
local function SubtractDays(Day, Month, Year, ToSubtract)
	local DaysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

	Day -= ToSubtract
	if Day <= 0 then
		Month -= 1
		Day += DaysInMonth[Month]
		if Month == 0 then
			Year -= 1
			Month = 12
		end
	end

	return Day, Month, Year
end



-- Master ticketing function: handle then return true to board or false to get off again
local function BoardBus(Passenger, Bus, Stop) 
	-- Get the bus driver
	local Humanoid = Config.GetBusLocation(Bus, 'DrivingSeat').Occupant
	if Humanoid == nil then
		return true
	end

	local Driver = Players:GetPlayerFromCharacter(Humanoid.Parent)
	if Driver == nil then
		return true
	end

	-- Lay out the GUI
	local StuffToDestroy = {}
	local StuffToDisconnect = {}
	local Ticketing = script.Ticketing:Clone()
	table.insert(StuffToDestroy, Ticketing)

	-- Allow the driver to accept or reject
	local Accepted = nil

	local function Accept()
		Accepted = true
	end

	local function Deny()
		Accepted = false
	end

	-- Fill in fields in the ticket machine
	local CurrentKeypressEvent = nil -- We want to disconnect this whenever we connect a new one
	local PreviousOfferTime = 0
	local RequestedTicket = {
		Name = nil,
		Destination = nil
	}

	local function CheckDebounce()
		local IsAllowed = PreviousOfferTime + Config.Ticketing.Machine.ClickDebounce < tick()
		PreviousOfferTime = tick()
		return IsAllowed
	end

	local function SkipDebounce()
		PreviousOfferTime = 0
	end

	local function OfferChildren(Parent)
		if CheckDebounce() == false then return end

		-- Really bad code time
		-- For some odd reason, Ticketing:FindFirstChild('Machine') doesn't exist sometimes when this is called
		-- However, those calls don't appear to be needed anyway, so I'm just scrapping them
		if Ticketing:FindFirstChild('Machine') == nil then
			return
		end

		-- Start by making them all blank, in case they're not overwritten
		for _, Button in ipairs(Ticketing.Machine:GetChildren()) do
			if Button.Name ~= 'Header' then
				Button.Text = Button.Name .. ' > '
			end
		end

		local Keys = {
			[Enum.KeyCode.Zero] = 0,
			[Enum.KeyCode.One] = 1,
			[Enum.KeyCode.Two] = 2,
			[Enum.KeyCode.Three] = 3,
			[Enum.KeyCode.Four] = 4,
			[Enum.KeyCode.Five] = 5,
			[Enum.KeyCode.Six] = 6,
			[Enum.KeyCode.Seven] = 7,
			[Enum.KeyCode.Eight] = 8,
			[Enum.KeyCode.Nine] = 9
		}

		-- Check if it's a ticket instead of a folder (has __Cost value)
		if Parent:FindFirstChild('__Cost') ~= nil then
			-- We may need to select a destination
			if Parent:FindFirstChild('__EndLocation') ~= nil then
				-- Create some dummy instances.
				local DummyParent = Parent:Clone() -- Don't modify the ticket UI objects
				DummyParent:ClearAllChildren()

				-- Find fare stages on the route
				local FareStages = {}
				local RouteTable = Config.Routes[RouteIndexOf(Bus.BusData.Route.Value)]
				local CurrentIndex = 0

				for Index, RouteStop in ipairs(RouteTable) do
					if Index == 1 then continue end -- Route description row

					-- Set CurrentIndex if this is our stop
					if RouteStop[1] == Stop then
						CurrentIndex = Index
					end

					-- Get its fare stage, and add it if it's not already there
					local FareStage = Config.Stops[RouteStop[1]][2]
					if FareStages[FareStage] == nil then
						-- Calculate a price
						local IndexDifference = Index - CurrentIndex

						-- As PricePerStop is not in ones, multiply by 100
						FareStages[FareStage] = IndexDifference * Config.Ticketing.Pricing.PricePerStop * 100
					end
				end

				for FareStage, Price in pairs(FareStages) do
					local Folder = Instance.new('Folder')
					Folder.Name = FareStage
					Folder.Parent = DummyParent

					local Cost = Instance.new('IntValue')
					Cost.Name = '__Cost'
					Cost.Parent = Folder

					-- If it's a return, increase the cost
					if string.find(Parent.Name, 'Return') ~= nil then
						Price *= Config.Ticketing.Pricing.ReturnMultiplier
					end

					-- And round the fare
					local RoundToNearest = Config.Ticketing.Pricing.PriceRounding * 100

					Price /= RoundToNearest -- Bring it down to round to nearest 1
					Price = math.round(Price)
					Price *= RoundToNearest

					-- Set value
					Cost.Value = Price
				end

				-- Go again
				SkipDebounce()
				OfferChildren(DummyParent)
			else
				local Events = {}

				-- Display options to dispense or return, and the cost
				Ticketing.Machine['0'].Text = '0 > Dispense'
				Ticketing.Machine['1'].Text = '1 > Return'

				local Cost = Parent.__Cost.Value
				local Hundreds = tostring(math.floor(Cost / 100))
				local Ones = tostring(Cost % 100)

				-- Prevent Ones < 10 e.g. '23.4' = '23.04' (could be mistaken as 23.40)
				if string.len(Ones) == 1 then Ones = '0' .. Ones end

				Ticketing.Machine['4'].Text = '4 > Cost: ' .. Hundreds .. '.' .. Ones

				local function Return()
					if CheckDebounce() == false then return end

					-- Disconnect all those pesky events
					for _, Event in ipairs(Events) do
						Event:Disconnect()
					end

					SkipDebounce() -- As we just debounced (7 lines up)
					OfferChildren(script.Tickets)
				end

				-- The passenger should walk off happily
				local function Dispense()
					if CheckDebounce() == false then return end

					SkipDebounce()
					Return()

					-- Check this is the correct ticket
					if Parent.Name == RequestedTicket.Name or Parent.Name == RequestedTicket.Destination then
						local ThankText = Config.Ticketing.ThankTexts[Rnd:NextInteger(1, #Config.Ticketing.ThankTexts)]
						Accept()
						CreateSpeechBubble(Passenger, ThankText, 1)
					else
						local UnhappyText = 'What?! That isn\'t what I wanted!'
						CreateSpeechBubble(Passenger, UnhappyText, 3)
					end
				end

				-- Put them all into the table to disconnect later
				Events = {
					Ticketing.Machine['0'].MouseButton1Down:Connect(Dispense),
					Ticketing.Machine['1'].MouseButton1Down:Connect(Return),
					Config.Misc.KeypressEvent.OnServerEvent:Connect(function(Player, Key)
						if Player == Driver then
							if Keys[Key] == 0 then
								Dispense()
							elseif Keys[Key] == 1 then
								Return()
							end
						end
					end)
				}
			end
		else
			local Count = 0
			local Buttons = {}

			for _, Option in ipairs(Parent:GetChildren()) do
				-- Set the Count button to this
				local Button = Ticketing.Machine:FindFirstChild(tostring(Count))
				if Button == nil then
					error('Too many ticket options in one parent!')
				end

				Button.Text = tostring(Count) .. ' > ' .. Option.Name

				local Connection
				Connection = Button.MouseButton1Down:Connect(function() 
					if CheckDebounce() == true then -- Otherwise, we don't want to disconnect
						Connection:Disconnect()
						OfferChildren(Option) 
					end
				end)
				Buttons[Count] = Option -- To connect it to one global key event, rather than one per button

				Count += 1
			end

			-- Listen for clicks
			if CurrentKeypressEvent ~= nil then
				CurrentKeypressEvent:Disconnect()
			end

			CurrentKeypressEvent = Config.Misc.KeypressEvent.OnServerEvent:Connect(function(Player, Key)
				if Player == Driver and Keys[Key] ~= nil then
					-- Keys[Key] is the number of the option we want to use
					if Buttons[Keys[Key]] ~= nil then -- It could be an unused button
						OfferChildren(Buttons[Keys[Key]]) -- The value in the Buttons table is the next option, not the button
					end
				end
			end)
		end
	end

	OfferChildren(script.Tickets)

	-- Decide whether to give a ticket, or buy one
	if Rnd:NextNumber() > Config.Ticketing.PurchaseChance then
		-- Greet the driver
		if Rnd:NextNumber() < Config.Ticketing.Greetings.Probability then
			-- Decide on what text to display
			local Texts = {
				'Hello!',
				'G\'day!',
				'Hi there!',
				'Hey.',
				'Sup'
			}

			coroutine.wrap(function() -- As this is asynchronous
				CreateSpeechBubble(Passenger, Texts[Rnd:NextInteger(1, #Texts)], 1)
			end)()
		end

		-- Decide if this ticket is going to be invalid in any way
		local InvalidProbs = Config.Ticketing.InvalidTickets.Probabilities

		local Expired = Rnd:NextNumber() < InvalidProbs.Expired
		local FalseChild = Rnd:NextNumber() < InvalidProbs.FalseChild and true -- (Children can't be false children)
		local FalseAdult = Rnd:NextNumber() < InvalidProbs.FalseAdult and false
		local InvalidReturn = Rnd:NextNumber() < InvalidProbs.InvalidReturn
		local Forged = Rnd:NextNumber() < InvalidProbs.Forged

		-- Get a random ticket
		local Tickets = {}
		for _, d in ipairs(script.Tickets:GetDescendants()) do
			if d:IsA('Frame') then
				table.insert(Tickets, d)
			end
		end

		local Ticket = Tickets[Rnd:NextInteger(1, #Tickets)]:Clone()
		table.insert(StuffToDestroy, Ticket)

		-- Set any values on the ticket
		local CurrentTime = Config.Ticketing.GetCurrentTime()

		for _, Value in ipairs(Ticket:GetChildren()) do
			if string.sub(Value.Name, 0, 2) == '__' and Value:IsA('TextLabel') then
				local ValueType = string.sub(Value.Name, 3)

				Value.Text = '' -- Catch anywhere where it fails to set

				-- Set according to what it is
				if ValueType == 'TicketID' then
					if Forged == true and Rnd:NextNumber() < InvalidProbs.ForgedPerField then
						Value.Text = '0'
						continue
					end

					Value.Text = tostring(Rnd:NextInteger(100000, 999999))

				elseif ValueType == 'DutyID' then
					if Forged == true and Rnd:NextNumber() < InvalidProbs.ForgedPerField then
						Value.Text = '0'
						continue
					end

					Value.Text = tostring(Rnd:NextInteger(1, 999))

				elseif ValueType == 'IssueTime' or ValueType == 'IssueTimeToday' then
					if Forged == true and Rnd:NextNumber() < InvalidProbs.ForgedPerField then
						-- Have incorrect hours or minutes
						local InvalidType = Rnd:NextNumber()
						local Hour
						local Minute

						if InvalidType < 0.33 then
							-- Just the hour
							Hour = Rnd:NextInteger(24, 99)
							Minute = Rnd:NextInteger(0, 59)
						elseif InvalidType > 0.67 then
							-- Just the minute
							Hour = Rnd:NextInteger(0, 23)
							Minute = Rnd:NextInteger(60, 99)						
						else
							-- Do both!
							Hour = Rnd:NextInteger(24, 99)
							Minute = Rnd:NextInteger(60, 99)
						end

						local StrHour = tostring(Hour)
						local StrMinute = tostring(Minute)

						-- Maybe bother with leading zeroes, but ticket forgers are lazy sometimes
						if Rnd:NextNumber() < 0.5 then
							if string.len(StrHour) == 1 then StrHour = '0' .. StrHour end
							if string.len(StrMinute) == 1 then StrMinute = '0' .. StrMinute end
						end

						Value.Text = StrHour .. StrMinute

						continue
					end

					-- An hour and minute component is needed
					local Hour
					local Minute

					-- If the ticket's expired or not today, just be random
					if Expired == true or ValueType == 'IssueTime' then
						Hour = Rnd:NextInteger(0, 23)
						Minute = Rnd:NextInteger(0, 59)
					else
						Hour = Rnd:NextInteger(0, CurrentTime.Hour)
						-- If the time is 10:39 and Hour = 10, Minute must < 39
						-- Actually, I've decided on < 24 (- 15 mins) for realism
						Minute = nil

						if Hour == CurrentTime.Hour then
							if CurrentTime.Minute >= 15 then
								Minute = Rnd:NextInteger(0, CurrentTime.Minute - 15)
							else
								Hour -= 1 -- Can't do the above in this hour (10:05 -> 09:50)
								Minute = Rnd:NextInteger(0, CurrentTime.Minute + 45) -- +45 as +60 (another hour up)
								-- As we know CurrentTime.Minute < 15, CurrentTime.Minute + 45 < 60
							end
						else
							-- Do whatever
							Minute = Rnd:NextInteger(0, 59)
						end
					end

					-- Parse it into a string
					-- But first, add leading zeroes (10:5 -> 10:05)
					local StrHour = tostring(Hour)
					local StrMinute = tostring(Minute)
					if string.len(StrHour) == 1 then StrHour = '0' .. StrHour end
					if string.len(StrMinute) == 1 then StrMinute = '0' .. StrMinute end

					Value.Text = StrHour .. StrMinute -- The lack of separators (:) is deliberate

				elseif ValueType == 'CurrentDate' or ValueType == 'RecentDate' or 
					ValueType == 'DateInPastWeek' or ValueType == 'DateInPastMonth' then
					-- Work out how many days back we can go
					local BackwardsRange = nil
					if ValueType == 'CurrentDate' then
						BackwardsRange = 0 -- Can't go back at all
					elseif ValueType == 'RecentDate' then
						-- It's variable
						BackwardsRange = 0

						while Rnd:NextNumber() < Config.Ticketing.InvalidTickets.ExpiryDateChance do
							BackwardsRange += 1
							if Ticket:FindFirstChild('__IssueTimeToday') then -- A massive bodge!
								Ticket.__IssueTimeToday.Name = '__IssueTime'
							end
						end
					elseif ValueType == 'DateInPastWeek' then
						BackwardsRange = 6
					else
						BackwardsRange = 27
					end

					-- Change the current time to go back a bit
					local BackwardsDays = Rnd:NextInteger(0, BackwardsRange)

					CurrentTime.Day, CurrentTime.Month, CurrentTime.Year = SubtractDays(
						CurrentTime.Day, CurrentTime.Month, CurrentTime.Year, BackwardsDays
					)

					if Forged == true then
						-- Any of the three can be invalid
						local Day = CurrentTime.Day
						local Month = CurrentTime.Month
						local Year = CurrentTime.Year % 100

						if Rnd:NextNumber() < InvalidProbs.ForgedPerField then
							-- Fake day
							Day = Rnd:NextInteger(32, 99)
						end

						if Rnd:NextNumber() < InvalidProbs.ForgedPerField then
							-- Fake month
							Month = Rnd:NextInteger(13, 99)
						end

						if Rnd:NextNumber() < InvalidProbs.ForgedPerField then
							-- Fake year
							Year = Rnd:NextInteger(0, 99)
						end

						-- Might need to give the year a leading zero
						local StrYear = tostring(Year)
						if Rnd:NextNumber() < 0.5 then
							if string.len(StrYear) == 1 then StrYear = '0' .. StrYear end
						end

						Value.Text = tostring(Day) .. tostring(Month) .. StrYear

						continue
					end

					-- Unless expired, leave it as today's date
					if Expired == true then
						-- Set any date in the past.
						-- Each date should have a certain likelihood - say, 0.5
						-- This would mean yesterday is 50%, the day before is 25%, then 12.5%, etc.
						-- As every day back, a ticket has to 'survive' more randomisations (half of all tickets go on day 1)
						local RandomNumber = 1 -- So it never throws the first time
						local DaysBack = BackwardsRange - BackwardsDays -- Start from the minimum

						while RandomNumber > Config.Ticketing.InvalidTickets.ExpiryDateChance do
							DaysBack += 1
							RandomNumber = Rnd:NextNumber()
						end

						-- After breaking out of the loop, go back DaysBack days
						CurrentTime.Day, CurrentTime.Month, CurrentTime.Year = SubtractDays(
							CurrentTime.Day, CurrentTime.Month, CurrentTime.Year, DaysBack
						)
					end

					-- Actually parse it
					local StrDay = tostring(CurrentTime.Day)
					local StrMonth = tostring(CurrentTime.Month)
					local StrYear = tostring(CurrentTime.Year)

					-- Day and month get leading zeroes, year gets its first two digits (20) cropped off
					if string.len(StrDay) == 1 then StrDay = '0' .. StrDay end
					if string.len(StrMonth) == 1 then StrMonth = '0' .. StrMonth end
					StrYear = string.sub(StrYear, 3, -1)

					Value.Text = StrDay .. StrMonth .. StrYear

				elseif ValueType == 'CurrentRoute' or ValueType == 'AnyRoute' then
					if Forged == true and Rnd:NextNumber() < InvalidProbs.ForgedPerField then
						-- Random string of numbers
						local Str = ''
						for _ = 1, 5 do
							Str = Str .. tostring(Rnd:NextInteger(0, 9))
						end

						Value.Text = Str
						continue
					end

					if ValueType == 'CurrentRoute' then
						Value.Text = Bus.BusData.Route.Value
					else
						-- Pick a random route
						local Route = Config.Routes[Rnd:NextInteger(1, #Config.Routes)]
						Value.Text = Route[1][1]					
					end	

				elseif ValueType == 'EndLocation' then
					if InvalidReturn == false and Forged == false then
						-- The current stop
						Value.Text = Config.Stops[Stop][2]
					else
						-- Pick a random stop from the bus stop folder
						local Children = Config.Folders.Stops:GetChildren()
						local Count = Rnd:NextInteger(1, #Children)
						for _, RndStop in ipairs(Children) do
							Count -= 1
							if Count == 0 then
								-- Use this one!
								Value.Text = Config.Stops[RndStop][2]
							end
						end
					end

				elseif ValueType == 'StartLocation' then
					if InvalidReturn == false and Forged == false then
						-- The stop this passenger is going to
						Value.Text = Config.Stops[Passenger.PassengerData.EndStop.Value][2]
					else
						-- Pick a random stop from the bus stop folder
						local Count = Rnd:NextInteger(1, #Config.Folders.Stops:GetChildren())
						for _, RndStop in pairs(Config.Stops) do
							Count -= 1
							if Count == 0 then
								-- Use this one!
								Value.Text = RndStop[2]
							end
						end
					end

				end
			end
		end

		-- Place it on the table
		Ticket.Parent = Driver.PlayerGui.AIBusPassengers
	else
		-- Ask for a ticket
		-- But first, decide what we want
		local Tickets = {}

		for _, c0 in ipairs(script.Tickets:GetChildren()) do
			for _, c1 in ipairs(c0:GetChildren()) do
				table.insert(Tickets, c1)
			end
		end

		local Ticket = Tickets[Rnd:NextInteger(1, #Tickets)]
		local TicketText = Config.Ticketing.PurchaseTexts[Rnd:NextInteger(1, #Config.Ticketing.PurchaseTexts)]
		local TicketName = Ticket.Name .. ' ticket'

		-- Change requested ticket data
		RequestedTicket.Name = Ticket.Name

		-- If there are any other fields, fill them in
		if Ticket:FindFirstChild('__EndLocation') then
			TicketName = TicketName .. ' to ' .. Config.Stops[Passenger.PassengerData.EndStop.Value][1]
			RequestedTicket.Destination = Config.Stops[Passenger.PassengerData.EndStop.Value][2] -- The fare stage name
		end

		coroutine.wrap(function()
			CreateSpeechBubble(Passenger, string.gsub(TicketText, '__TicketName', TicketName), 5)
		end)()
	end

	-- Place it into PlayerGui
	Ticketing.Parent = Driver.PlayerGui.AIBusPassengers

	-- Events for accepting and rejecting
	local AcceptButton = Ticketing.Accept.MouseButton1Down:Connect(Accept)
	local DenyButton = Ticketing.Deny.MouseButton1Down:Connect(Accept)
	local KeypressEvent = Config.Misc.KeypressEvent.OnServerEvent:Connect(function(Player, Key)
		if Player == Driver then
			if Key == Config.Keybinds.AcceptTicket then
				Accept()
			elseif Key == Config.Keybinds.DenyTicket then
				Deny()
			end
		end
	end)

	table.insert(StuffToDisconnect, AcceptButton)
	table.insert(StuffToDisconnect, DenyButton)
	table.insert(StuffToDisconnect, KeypressEvent)

	-- I really don't like this, but not sure there's an alternative
	while RunService.Heartbeat:Wait() do
		if Accepted ~= nil then
			-- One of the above events fired
			for _, thing in ipairs(StuffToDestroy) do
				thing:Destroy() -- Bye bye
			end

			-- Disconnect everything
			for _, thing in ipairs(StuffToDisconnect) do
				thing:Disconnect()
			end

			-- And return whether the passenger is allowed on
			return Accepted
		end
	end
end



--Passengers
-------------------------
-------------------------


--if a bus goes where a passenger is going
local function CanBoard(Passenger, Route)	
	local Stops = Config.Routes[RouteIndexOf(Route)] 
	local startIndices = {}
	local endIndices = {}

	--go through all the Stops bar Stops[1] (as it's the metadata index)
	if Stops ~= nil then
		for count = 2, #Stops, 1 do
			if Stops[count][1] == Passenger.PassengerData.StartStop.Value then
				table.insert(startIndices, count)
			elseif Stops[count][1] == Passenger.PassengerData.EndStop.Value then
				table.insert(endIndices, count)
			end
		end
	end	

	--if we've found both of them
	if #startIndices ~= 0 and #endIndices ~= 0 then
		--AND if the last end is after the first start
		--(in case a stop is served multiple times)
		if endIndices[#endIndices] > startIndices[1] then
			return true
		end
	end

	--if we didn't return true...
	return false
end



--check if we can move to either OBP or IBP
local function CanMoveTo(Bus, BP, WaitIfFalse, Timeout)
	if BP == 'OBP' then
		BP = Config.Movement.OBPMovementReq --convenience
	elseif BP == 'IBP' then
		BP = Config.Movement.IBPMovementReq
	end --otherwise, a raw value e.g. 'CompleteStop' can be passed

	local DSeat = Config.GetBusLocation(Bus, 'DrivingSeat')
	local DoorsOpen = Config.GetBusLocation(Bus, 'FrontDoorsOpen')

	if BP == 'CompleteStop' and DoorsOpen.Value == false then --no point repeatedly running a while true do unless needed
		if WaitIfFalse == false then
			return false --we can't wait
		end

		DoorsOpen.Changed:Wait()
	end

	local function CheckForStop() --effectively a wrapper for waiting
		if BP == 'CompleteStop' then
			return DSeat.Velocity.Magnitude < Config.Movement.MaxBoardingVelocity and DoorsOpen.Value == true
		elseif BP == 'VelocityOnly' then
			return DSeat.Velocity.Magnitude < Config.Movement.MaxBoardingVelocity --only bother checking velocity
		else
			return true
		end
	end

	if CheckForStop() == true then
		return true --we're stopped!
	else
		if WaitIfFalse == false then
			return false --can't wait to return, so return now
		else
			local TimePassed = 0
			if Timeout == nil then Timeout = math.huge end

			while CheckForStop() == false do
				task.wait(0.1)
				TimePassed += 0.1
				if TimePassed > Timeout then
					return false --took too long
				end
			end

			--if the loop ended, CheckForStop() returned true
			return true
		end
	end
end



--GUI
-------------------------

--show (or hide) a driver GUI object
local function SetDriverGUI(Bus, Name, hide)
	local Driver = GetDriver(Bus)
	if Driver == nil then
		return --no driver to show GUIs to
	end

	--if we're not just hiding all GUIs, find the GUI we want
	if Name ~= 'all' then
		local Gui
		if Driver.PlayerGui:FindFirstChild('AIBusPassengers') ~= nil then
			Gui = Driver.PlayerGui.AIBusPassengers[Name]
		else
			Gui = Bus.BusData.AIBusPassengers[Name]
		end

		if hide == nil then hide = false end --prevent the line below from behaving incorrectly
		if Gui.Visible ~= hide then 
			return --GUI already as it should be, so no need to do anything
		end

		--now, actually show/hide GUIs
		if hide == true then
			Gui.Visible = false
			CurrentGuis[Driver.Name] = nil
		else
			if CurrentGuis[Driver.Name] ~= nil then
				CurrentGuis[Driver.Name].Visible = false
			end

			Gui.Visible = true
			CurrentGuis[Driver.Name] = Gui
		end
	else --passing Name as 'all' hides all Guis
		for _, Gui in ipairs(Driver.PlayerGui.AIBusPassengers:GetChildren()) do
			Gui.Visible = false
		end

		CurrentGuis[Driver.Name] = nil
	end
end



--Animations, Seating & Physics
-------------------------

--anchor or unanchor a passenger
local function AnchorPassenger(Passenger, Direction)
	--only need to do the root part for this to work
	local rootpart = Passenger:FindFirstChild('HumanoidRootPart')
	if rootpart then rootpart.Anchored = Direction end
end



--gets the ATracks table for a passenger
local function GetATracks(p)
	for _, ATracks in ipairs(PassengerATracks) do
		if ATracks[1] == p then
			return ATracks
		end
	end

	--if there wasn't one
	local NewATracks = { p }
	table.insert(PassengerATracks, NewATracks)
	return NewATracks
end



--enable/disable an animation on a passenger
local function AnimatePassenger(Passenger, Animation, direction)
	local ATracks = GetATracks(Passenger)

	--find the requested track
	local Requested
	for count = 2, #ATracks do
		if ATracks[count].Animation == Animation then
			Requested = ATracks[count]
		end
	end

	--if we haven't loaded this track yet
	if Requested == nil then
		Requested = Passenger.Humanoid.Animator:LoadAnimation(Animation)
		table.insert(ATracks, Requested) --add to table
	end

	--play it
	if direction == true or direction == nil then
		Requested:Play()
	else
		Requested:Stop()
	end
end



--remove a passenger from their seat
local function Unseat(Passenger)
	-- -- Alternative implementation with WeldConstraints -- --

	----return to the passenger folder
	--Passenger.Parent = workspace.LoadedPassengers

	----unanimate the passenger
	--AnimatePassenger(Passenger, Passenger.Animate.sit.SitAnim, false)

	----anchor us again
	--AnchorPassenger(Passenger, true)

	-- -- Implementation with the native Seat system -- --
	if Passenger.Humanoid.Sit == false then
		return --they're already sat down
	end

	Passenger.Humanoid.Sit = false

	local Seat = Passenger.Humanoid.SeatPart

	if Seat ~= nil then
		local Weld = Seat:FindFirstChild('SeatWeld') 
		if Weld ~= nil then
			Weld:Destroy() 
		end		
	end

	-- Anchor us again
	if Passenger.PrimaryPart.Anchored == false then
		AnchorPassenger(Passenger, true)
	end

	Passenger.Humanoid.Sit = false
	Passenger.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
	AnimatePassenger(Passenger, Passenger.Animate.sit.SitAnim, false)
end



--sit a passenger in the specified seat. Buggy :|
local function Seat(Passenger, SeatPart, Animate)
	if Animate == nil then Animate = true end

	Passenger.PrimaryPart.Anchored = false -- So we can move

	if Animate == true then
		AnimatePassenger(Passenger, Passenger.Animate.sit.SitAnim, true) -- A function to play anims
	end

	SeatPart:Sit(Passenger.Humanoid)
	Passenger.Humanoid:ChangeState(Enum.HumanoidStateType.Seated)
end



--Movement
-------------------------

--teleport a passenger using :SetPrimaryPartCFrame()
local function TeleportToPosition(Passenger, Position)
	Unseat(Passenger) --if they're sat down, :SetPrimaryPartCFrame doesn't work
	local PassengerNoY = Vector3.new(Passenger.HumanoidRootPart.Position.X, 0, Passenger.HumanoidRootPart.Position.Z)
	local PositionNoY = Vector3.new(Position.X, 0, Position.Z) --remove Y values as they're irrelevant and cause false negatives
	if math.abs((PassengerNoY - PositionNoY).Magnitude) > Config.Movement.SignificantDistance then
		Passenger:SetPrimaryPartCFrame(CFrame.new(Position.X, Position.Y + 3, Position.Z) * 
			CFrame.Angles(Passenger.HumanoidRootPart.Orientation.X, Passenger.HumanoidRootPart.Orientation.Y, 
				Passenger.HumanoidRootPart.Orientation.Z)) --if it's actually worth our time
	end
end



-- Have a passenger walk somewhere
local function MoveTo(Passenger, Position, IncreaseYCoord)
	if Passenger.PrimaryPart == nil then
		return
	end

	-- Move the passengers up a bit
	if IncreaseYCoord == nil or IncreaseYCoord == true then
		Position = Vector3.new(Position.X, Position.Y + 3, Position.Z)
	end

	-- Before anything else, check we need to bother
	-- Ignore the Y coord, as weird behaviours have been seen with it
	-- (Pax trying to go directly up / down)
	local CurrentNoY = Vector3.new(Passenger.PrimaryPart.Position.X, 0, Passenger.PrimaryPart.Position.Z)
	local TargetNoY = Vector3.new(Position.X, 0, Position.Z)

	local Distance = math.abs((TargetNoY - CurrentNoY).Magnitude)
	if Distance < Config.Movement.SignificantDistance then
		return
	end

	-- Make sure they're stood up
	Unseat(Passenger)

	-- Animate the walking
	local WalkAnimation = Passenger.Animate.walk.WalkAnim
	local Animator = Passenger:FindFirstChildOfClass('Humanoid').Animator
	local LoadedAnimation = Animator:LoadAnimation(WalkAnimation)
	LoadedAnimation:Play()

	-- Set their orientation to face towards the destination
	-- I can't think of an easy way to tween this without problems, as CFrame and Position are linked-ish
	Passenger.PrimaryPart.CFrame = CFrame.new(Passenger.PrimaryPart.Position, Position)

	-- Prevent silly behaviour
	local O = Passenger.PrimaryPart.Orientation
	Passenger.PrimaryPart.Orientation = Vector3.new(math.clamp(O.X, -30, 30), O.Y, math.clamp(O.Z, -30, 30))

	-- And tween them
	local Time = Distance / Config.Movement.Speed
	Time *= Rnd:NextNumber(0.6, 1.4) -- Variety!

	local Info = TweenInfo.new(Time, Enum.EasingStyle.Linear)
	local Properties = { ['Position'] = Position }

	local Tween = TweenService:Create(Passenger.PrimaryPart, Info, Properties)
	Tween:Play()

	-- Stop animating when it finishes
	Tween.Completed:Wait()
	LoadedAnimation:Stop()
end



--Boarding and Alighting
-------------------------

--ring the bell on a bus, after checking if it has already been rung etc
local function RingBell(Bus)
	local BellRung = Bus.BusData.BellRung
	local BellSound = Bus.BusData.BellSound:Clone()
	local DoorsOpen = Config.GetBusLocation(Bus, 'RearDoorsOpen')

	if BellRung.Value == false then --if it hasn't already been pressed
		if DoorsOpen.Value == false then
			BellRung.Value = true
			BellSound.Parent = Config.GetBusLocation(Bus, 'DrivingSeat')
			BellSound:Play()

			-- Destroy the sound when done
			local Connection
			Connection = BellSound.Ended:Connect(function()
				BellSound:Destroy()
				Connection:Disconnect()
			end)
		end
	end
end



--get off a bus! (regardless of whether we are at a stop)
local function Alight(Passenger)
	local Bus = Passenger.PassengerData.CurrentBus.Value

	--tell the driver
	local BVal = regiLibrary.Instantiate(nil, 'BoolValue', Bus.BusData.PassengersAlighting)

	local BellRung = Bus.BusData.BellRung
	BellRung.Value = false --doors must be open, so disable the bell

	local FinalAP = Config.GetBusLocation(Bus, 'FinalAlighting')
	local InsideAP = Config.GetBusLocation(Bus, 'InsideAlighting')
	local OutsideAP = Config.GetBusLocation(Bus, 'OutsideAlighting')

	--wait for the queue (we join the queue before calling this function)
	local Queue = AlightingQueueFromBus(Bus)
	while table.find(Queue, Passenger) ~= 3 do
		Queue[2].Event:Wait()
	end

	--get up from our seat
	Passenger.Humanoid.SeatPart.Taken.Value = nil
	Unseat(Passenger)

	--teleport to the final boarding point
	TeleportToPosition(Passenger, FinalAP.Position) 
	coroutine.wrap(function() --wait to leave the queue - in a coroutine so we can start moving before
		task.wait(Config.Movement.AlightingInterval())

		table.remove(Queue, 3)
		Queue[2]:Fire()
	end)()
	AnimatePassenger(Passenger, Passenger.Animate.walk.WalkAnim,true)
	MoveTo(Passenger, InsideAP.Position)
	MoveTo(Passenger, OutsideAP.Position)

	--we're off, so the bus can leave (and is also no longer full)
	BVal:Destroy()

	local Stop = CurrentStop(Bus)
	if Stop ~= nil then --as the function can return nil
		MoveTo(Passenger, RandomStopSpawn(Stop).p, false) --.p as RandomStopSpawn returns a CFrame
	end

	AnimatePassenger(Passenger, Passenger.Animate.walk.WalkAnim, false)
	Passenger:Destroy() --we're done!
end



--if an object is detected at a stop, and it is a bus, potentially board, sit down, etc. (~200 lines long!)
local function BusArrivedAtStop(Passenger, Stop, Bus, Connection)
	--first, some error checking:
	local PassengerData = Passenger:FindFirstChild('PassengerData')
	if PassengerData == nil then
		Connection:Disconnect() --so the 'ghost passenger' doesn't keep calling
		return false
	elseif PassengerData.CurrentBus.Value ~= nil then
		Connection:Disconnect()
		return false --already on a bus
	end

	local Driver = Config.GetBusLocation(Bus, 'DrivingSeat').Occupant
	if not Driver then return false end

	local DriverP = Players:GetPlayerFromCharacter(Driver.Parent)
	if DriverP == nil or DriverP.AIBusPassengers.Enabled.Value == false then 
		return false --the driver doesn't exist or has AI off
	end

	--check route
	local Route = Config.GetBusLocation(Bus, 'RouteCode')
	if CanBoard(Passenger, Route.Value) == false then
		return false
	end

	--and check fullness
	if IsFull(Bus) == true then
		return false --already full
	end

	local PassengerSeat = FindSeat(Bus)
	if PassengerSeat == nil then
		return false
	end

	--final check on this before we begin
	if Passenger:FindFirstChild('PassengerData') == nil or Passenger:FindFirstChildOfClass('Humanoid') == nil 
		or Passenger:FindFirstChild('HumanoidRootPart') == nil then
		Connection:Disconnect()
		return false
	end

	--otherwise, get on!
	local OutsideBoardingPoint = Config.GetBusLocation(Bus, 'OutsideBoarding')
	local InsideBoardingPoint = Config.GetBusLocation(Bus, 'InsideBoarding')
	local FinalBoardingPoint = Config.GetBusLocation(Bus, 'FinalBoarding')
	local Seats = Config.GetBusLocation(Bus, 'Seats')
	local StandingSpaces = Config.GetBusLocation(Bus, 'StandingSpaces')
	local WaitingPoint = Passenger.HumanoidRootPart.Position
	local DSeat = Config.GetBusLocation(Bus, 'DrivingSeat')
	local BoardingQueue = BoardingQueueFromBus(Bus)

	--but first, tell the driver
	local BVal = regiLibrary.Instantiate(nil, 'BoolValue', Bus.BusData.PassengersBoarding)

	PassengerData.WaitingStop.Value = nil
	PassengerData.CurrentBus.Value = Bus

	local Humanoid = Passenger.Humanoid

	--and the seat
	PassengerSeat[1].Taken.Value = Passenger

	--and move to the OBP
	local function MoveToOBP()
		AnimatePassenger(Passenger, Passenger.Animate.walk.WalkAnim, true)
		MoveTo(Passenger, OutsideBoardingPoint.Position)
		AnimatePassenger(Passenger, Passenger.Animate.walk.WalkAnim, false)
	end

	--if we're sat down, get up
	Unseat(Passenger)

	--and make sure we don't sit back down again (silly passengers)
	local SeatDetection = Humanoid.Seated:Connect(function()
		Unseat(Passenger)
	end)

	--wait for the bus to stop, potentially timing out or giving up, and make sure it's still the correct route
	local WStart = tick()

	while task.wait(0.1) do
		local QueuePos = table.find(BoardingQueue, Passenger)
		local Distance = math.abs((OutsideBoardingPoint.Position - Passenger.HumanoidRootPart.Position).Magnitude)

		if CanMoveTo(Bus, 'IBP', false) == true and CanBoard(Passenger, Route.Value) == true and QueuePos == 3 and 
			(Config.Movement.WaitForAlighters == false or 
				(#Bus.BusData.PassengersAlighting:GetChildren() == 0 and Bus.BusData.BellRung.Value == false)) then
			break --so we can continue
		else
			if (Distance > Config.Movement.MaxBoardingDistance) or ((tick() - WStart) > Config.Movement.CanMoveToTimeout) then
				--give up
				MoveTo(Passenger, WaitingPoint, false)
				BVal:Destroy()

				local InTable = table.find(BoardingQueue, Passenger)
				if InTable ~= nil then
					table.remove(BoardingQueue, InTable)
					BoardingQueue[2]:Fire()
				end

				PassengerData.WaitingStop.Value = Stop
				PassengerData.CurrentBus.Value = nil
				PassengerSeat[1].Taken.Value = nil

				return false	
			end

			if Distance > Config.Movement.SignificantDistance and CanMoveTo(Bus, 'OBP', false) == true then
				MoveToOBP()
			end

			if QueuePos == nil then
				--we need to join the queue
				table.insert(BoardingQueue, Passenger)
			end
		end
	end

	AnimatePassenger(Passenger, Passenger.Animate.walk.WalkAnim, true)
	MoveTo(Passenger, InsideBoardingPoint.Position)
	AnimatePassenger(Passenger, Passenger.Animate.walk.WalkAnim, false)

	local success = BoardBus(Passenger, Bus, Stop) --this yields, allowing ticket selling etc in a modular fashion
	table.remove(BoardingQueue, 3) --leave the queue
	BoardingQueue[2]:Fire() --fire the event so the next passenger moves forward

	if success == false then --if BoardBus returned false for whatever reason
		AnimatePassenger(Passenger, Passenger.Animate.walk.WalkAnim, true)
		MoveTo(Passenger, OutsideBoardingPoint.Position)
		MoveTo(Passenger, WaitingPoint, false) 
		AnimatePassenger(Passenger, Passenger.Animate.walk.WalkAnim, false)

		PassengerData.WaitingStop.Value = Stop
		PassengerData.CurrentBus.Value = nil
		PassengerSeat[1].Taken.Value = nil

		BVal:Destroy()
		return false
	end

	--if we didn't return, set the CurrentBus value & leave the queue and PassengersBoarding list
	BVal:Destroy()

	AnimatePassenger(Passenger, Passenger.Animate.walk.WalkAnim,true)
	MoveTo(Passenger, FinalBoardingPoint.Position)
	AnimatePassenger(Passenger, Passenger.Animate.walk.WalkAnim,false)

	--and sit down
	SeatDetection:Disconnect()

	if PassengerSeat[2] == false then
		Seat(Passenger, PassengerSeat[1], true)
	else
		Seat(Passenger, PassengerSeat[1], false)
	end

	Connection:Disconnect() --don't need this anymore

	--now, wait to get off
	while task.wait(1) do
		local distance = math.abs((Passenger.HumanoidRootPart.Position - 
			Config.GetStopLocation(Passenger.PassengerData.EndStop.Value, 'Detector').Position).Magnitude)
		if distance < Config.Movement.BellRingDistance then
			--first, confirm that this is the closest stop
			local RouteTable = Config.Routes[RouteIndexOf(Route.Value)]
			local closest = true

			if RouteTable == nil then
				continue -- Can't do this right now
			end

			for count = 2, #RouteTable do
				local difference = distance - math.abs((Passenger.HumanoidRootPart.Position - 
					Config.GetStopLocation(RouteTable[count][1], 'Detector').Position).Magnitude)
				if difference > 0 then
					--this stop is closer
					closest = false
					break
				end
			end

			--if it was closest
			if closest == true then
				--ring the bell
				RingBell(Bus)

				--join the alighting queue (this is done in advance so one boarding passenger can't sneak on before Alight is called)
				local AlightingQueue = AlightingQueueFromBus(Bus)
				table.insert(AlightingQueue, Passenger)

				--and when the bus stops, alight
				--NOTE: this does not check whether the doors have opened at the stop, as opposed to somewhere else.
				--I thought of a good reason for this, but now I've forgotten it.
				CanMoveTo(Bus, 'IBP', true, math.huge)
				Alight(Passenger)

				--and return (as we're now done)
				return true
			end
		end
	end
end



--Time & Peaking
-------------------------

--some basic maths to tell if an hour time is between p_start and p_end (including if overnight, i.e. 1 is between 23 and 3)
local function IsPeriod(hours, p_start, p_end)
	if p_end < p_start then
		if hours > p_start or hours < p_end then
			return true
		end
	else
		if hours > p_start and hours < p_end then
			return true
		end
	end

	return false --as we haven't returned true already
end



--get the current time period (i.e. how busy it should be)
local function CurrentTimePeriod()
	--0 = mpeak, 1 = epeak, 2 = mon-fri day, 3 = sat day, 4 = sun day, 5 = mon-fri night, 6 = sat night, 7 = sun night
	local OSTimestamp = os.time()
	local OSTable = os.date('*t', OSTimestamp)

	--DayTimes: 0 = mpeak, 1 = day, 2 = epeak, 3 = night
	local DayTime

	local hour = OSTable['hour']
	local minute = OSTable['min']

	hour += (minute/60)

	if IsPeriod(hour, Config.Peaking.MorningStart, Config.Peaking.MorningEnd) then
		DayTime = 0
	elseif IsPeriod(hour, Config.Peaking.EveningStart, Config.Peaking.EveningEnd) then
		DayTime = 2
	elseif IsPeriod(hour, Config.Peaking.NightStart, Config.Peaking.NightEnd) then
		DayTime = 3
	else
		DayTime = 1
	end

	if OSTable['wday'] == 7 then --saturday
		if DayTime == 3 then
			return 6
		else
			return 3
		end

	elseif OSTable['wday'] == 1 then --sunday
		if DayTime == 3 then
			return 7
		else
			return 4
		end		

	else --mon-fri
		if DayTime == 0 then --morning peak
			return 0
		elseif DayTime == 2 then --evening peak
			return 1
		elseif DayTime == 1 then --daytime
			return 2
		else --night
			return 5
		end

	end
end



--the above, but with a route array
local function CurrentMultiplier(Stop, Off)
	local Period = CurrentTimePeriod() + 1 --+1 as the Multipliers table is 1-indexed

	local Multipliers
	if Off == false or Off == nil then
		Multipliers = {
			Stop[4],
			Stop[5],
			1,
			Stop[7],
			Stop[8],
			Stop[6],
			Stop[7] * Stop[6],
			Stop[8] * Stop[6]
		}

		return Multipliers[Period] * Config.Misc.GlobalModifier
	else
		Multipliers = {
			Stop[9],
			Stop[10],
			1,
			Stop[12],
			Stop[13],
			Stop[11],
			Stop[12] * Stop[11],
			Stop[13] * Stop[11]			
		}

		return Multipliers[Period]
	end
end



--Miscellaneous
-------------------------

--spawn a passenger at a certain stop to get a certain route (although the latter is only used to choose destination)
local function SpawnPassenger(Stop, Route)
	local Passenger =(Avatars[regiLibrary.math_rand(1, #Avatars, 'randomInt')]):Clone() --get a random avatar
	Passenger.Parent = game.Workspace.LoadedPassengers
	Passenger.Name = 'Passenger_' .. tostring(Rnd:NextInteger(1000, 9999))

	--anchor and position
	AnchorPassenger(Passenger, true)
	Passenger:SetPrimaryPartCFrame(RandomStopSpawn(Stop))

	--set some values
	Passenger.PassengerData.StartStop.Value = Stop
	Passenger.PassengerData.WaitingStop.Value = Stop
	Passenger.PassengerData.RouteCode.Value = Route[1][1]

	--now, decide the destination stop
	--first, find the index of the current stop
	local StopIndex

	for count = 2, #Route, 1 do
		if Route[count][1] == Stop then
			StopIndex = count
		end
	end

	if StopIndex == nil then
		warn('Passenger could not find spawn stop in route array.')
		Passenger:Destroy()
		return
	end

	--then loop through all the stops AFTER the current one
	for count = StopIndex + 1, #Route, 1 do
		local StopArray = Route[count]
		local AlightingPercentage = StopArray[3] --note this is a 0 to 1 value
		local Multiplier = CurrentMultiplier(StopArray)	

		AlightingPercentage *= Multiplier --used to divide the difference, but that was broken
		--so doing this, in want of something better

		--disregard the global modifier, as it's not meant to be used for this
		AlightingPercentage /= Config.Misc.GlobalModifier

		if AlightingPercentage < 0 then AlightingPercentage = 0 end
		if AlightingPercentage > 1 then AlightingPercentage = 1	end

		if regiLibrary.math_rand(0, 1, 'randomFloat') < AlightingPercentage then
			Passenger.PassengerData.EndStop.Value = StopArray[1]
			break --prevent it being overwritten later
		end
	end

	if Passenger.PassengerData.EndStop.Value == nil then
		warn('Passenger did not have a set alighting stop. Make sure the Off value for the last stop of a route is always 100!')
		print(Passenger.PassengerData.StartStop.Value, Passenger.PassengerData.RouteCode.Value)
		Passenger:Destroy()
		return
	end

	--next: bus arrival handling
	local Detector = Config.GetStopLocation(Stop, 'Detector')
	local Connection
	local RegisteredBuses = {}

	local function DetectorTouched(otherPart)
		local Bus

		--when a bus has arrived or changed
		local function CallBusArrived()
			if BusArrivedAtStop(Passenger, Stop, Bus, Connection) == false then
				--wait for the bus to leave, then unregister it so we can retry
				local Connection2
				Connection2 = Detector.TouchEnded:Connect(function(hit)
					if hit == Config.GetBusLocation(Bus, 'Trigger') then --if it's this bus' trigger
						table.remove(RegisteredBuses, table.find(RegisteredBuses, Bus))
						Connection2:Disconnect()
					end
				end)
			end					
		end

		if otherPart.Name == Config.TriggerName then
			Bus = Config.GetBusLocation(otherPart, 'FromTrigger')
			if table.find(RegisteredBuses, Bus) ~= nil then
				return --we already know about this bus
			else
				table.insert(RegisteredBuses, Bus)

				--set up some events
				Config.GetBusLocation(Bus, 'RouteCode').Changed:Connect(CallBusArrived)
				Bus.BusData.PassengersAlighting.ChildRemoved:Connect(CallBusArrived) --if someone's done getting off, a space might have cleared
			end
		else
			return --not a bus
		end

		CallBusArrived()
	end

	Connection = Detector.Touched:Connect(DetectorTouched)

	--in case a bus has already arrived
	for _, Part in ipairs(Detector:GetTouchingParts()) do
		DetectorTouched(Part)
	end
end



--sets up a newly spawned bus
local function SetupBus(Bus)
	--in case it needs other scripts to set it up first, wait a bit.
	if Config.Misc.SetupDelay > 0 then --if it's 0, don't bother
		task.wait(Config.Misc.SetupDelay)
	end

	--firstly, check if it's actually a bus
	if Config.Folders.IsBus(Bus) == false then 
		return
	end

	--set up BusData
	local BusData = regiLibrary.Instantiate('BusData', 'Folder', Bus)

	regiLibrary.Instantiate('BellSound', 'Sound', BusData).SoundId = Config.Sounds.Bell -- The fourth param is being broken :(
	local BellRung = regiLibrary.Instantiate('BellRung', 'BoolValue', BusData, { Value = false })
	local Route = regiLibrary.Instantiate('Route', 'StringValue', BusData)
	local PassengersBoarding = regiLibrary.Instantiate('PassengersBoarding', 'Folder', BusData)
	local PassengersAlighting = regiLibrary.Instantiate('PassengersAlighting', 'Folder', BusData)

	--then before doing anything else, check compatibility if needed
	if Config.Misc.CheckCompatibility == true then
		local success, message = pcall(function()
			--if any of these error due to the thing not being present, we'll know about it
			Config.GetBusLocation(Bus, 'RouteCode') --they all need to be loaded when calling GetBusLocation anyway
		end)

		if success == false then
			warn(message)
			task.wait(0) --without this, a warning occurs:
			--'Something tried to set the parent of [bus] to [iConfig.Folders.Buses] while setting the parent of [bus] to [Config.Folders.Buses]'
			--and the parent isn't set. RunService.Heartbeat:Wait() may be preferable, but haven't tried
			Bus.Parent = Config.Folders.IncompatibleBuses --move it here to prevent errors later
			return --(effectively make it invisible to the module)
		end
	end

	--add seat and standing space Taken values (attributes in future) and set collisions etc
	for _, s in ipairs(Config.GetBusLocation(Bus, 'Seats'):GetChildren()) do
		s.Anchored = true
		s.CanCollide = true
		s.Disabled = false

		regiLibrary.Instantiate('Taken', 'ObjectValue', s)
	end

	for _, s in ipairs(Config.GetBusLocation(Bus, 'StandingSpaces'):GetChildren()) do
		s.Anchored = true
		s.CanCollide = false
		s.Disabled = true

		regiLibrary.Instantiate('Taken', 'ObjectValue', s)
	end

	--get things
	local Trigger = Config.GetBusLocation(Bus, 'Trigger')
	Trigger.Touched:Connect(function() end) --create a TouchInterest
	local DSeat = Config.GetBusLocation(Bus, 'DrivingSeat')
	local DoorsOpen = Config.GetBusLocation(Bus, 'FrontDoorsOpen')

	--give the bus its GUI
	local InfoGui = script.InfoGui:Clone()
	InfoGui.Name = 'AIBusPassengers'
	InfoGui.Parent = BusData

	--check GUI changes
	--I tried events: it was very buggy and it got called tons anyway
	coroutine.wrap(function()
		local ServedStop = false --decides whether to show DoneLabel or SkipLabel
		local OnRoute = false

		--function for stops being touched/touchended
		--the events were really buggy, so it uses a table to listen for changes to :GetTouchingParts()
		local AtStop = false

		local function CheckAtStop()
			AtStop = false
			for _, Part in ipairs(Trigger:GetTouchingParts()) do --loop through all parts looking for stops
				if Part.Name == Config.DetectorName then --if we're touching ANY detector
					local Stop = Config.GetStopLocation(Part, 'FromDetector')
					AtStop = IsOnRoute(Stop, Config.GetBusLocation(Bus, 'RouteCode').Value) ~= nil --if the stop's on our route
				end
			end

		end

		--and set up a connection for correctly parenting the InfoGui
		DSeat:GetPropertyChangedSignal('Occupant'):Connect(function()
			if DSeat.Occupant ~= nil then
				local Player = Players:GetPlayerFromCharacter(DSeat.Occupant.Parent) --(Occupant is a humanoid, not the model)
				InfoGui.Parent = Player.PlayerGui
			else
				InfoGui.Parent = BusData
			end		
		end)

		--main loop
		while false do -- !!! was task.wait(0.1), but this is disabled rn until core rewrite
			--before doing anything, make sure AI is actually enabled
			if DSeat.Occupant then
				local p = Players:GetPlayerFromCharacter(DSeat.Occupant.Parent)
				if p and p.AIBusPassengers.Enabled.Value == true then
					--see if we're at a stop
					CheckAtStop()

					if AtStop == false then
						SetDriverGUI(Bus, 'all', true) --hide everything, then don't do anything else
						ServedStop = false --but reset this
					else
						--check if we're stopped
						local Stopped = 2 --1 = true, 2 = false (for using the table)
						if Config.Movement.IBPMovementReq == 'VelocityOnly' then
							if DSeat.Velocity.Magnitude < Config.Movement.MaxBoardingVelocity then
								Stopped = 1
							end
						else
							if DoorsOpen.Value == true then
								Stopped = 1
							end
						end

						--now, check for passengers getting on and off
						local Boarding = false
						local Alighting = false
						if #PassengersBoarding:GetChildren() ~= 0 then
							Boarding = true
							ServedStop = true
						end
						if #PassengersAlighting:GetChildren() ~= 0  or BellRung.Value == true then
							Alighting = true
							ServedStop = true
						end

						--finally, use this information to determine what to show
						local Guis = {
							{ 'AlightingLabel', 'DualStopLabel' },
							{ 'BoardingLabel', 'PickUpLabel' },
							{ 'AlightingLabel', 'DropOffLabel' }
						}

						if Boarding == true and Alighting == true then
							SetDriverGUI(Bus, Guis[1][Stopped])
						elseif Boarding == true and Alighting == false then
							SetDriverGUI(Bus, Guis[2][Stopped])				
						elseif Boarding == false and Alighting == true then
							SetDriverGUI(Bus, Guis[3][Stopped])
						else
							if IsFull(Bus) == true then
								SetDriverGUI(Bus, 'FullLabel')
							else
								if ServedStop == true then
									SetDriverGUI(Bus, 'DoneLabel')
								else
									SetDriverGUI(Bus, 'SkipLabel')
								end
							end
						end	
					end
				end
			end 
		end
	end)()

	-- create queues to get on and off - the queues are arrays like { {Bus, BindableEvent}, Passenger, Passenger...}
	table.insert(BoardingQueues, { Bus, regiLibrary.Instantiate(nil, 'BindableEvent', script.BoardingQueueEvents) })
	table.insert(AlightingQueues, { Bus, regiLibrary.Instantiate(nil, 'BindableEvent', script.AlightingQueueEvents) })
end



--starts the system up - call this from ServerScriptService ASAP when running
function Passengers.Start(config)
	if Enabled == false then return end

	Config = config --apply

	--configuration
	if Config == nil then
		error('No config passed!')
	end

	--send players Config when they ask for it
	local Transferrer = regiLibrary.Instantiate('AIBusPassengersConfigTransferrer', 'RemoteFunction', game.ReplicatedStorage)
	function Transferrer.OnServerInvoke()
		return Config
	end

	--create queue event folders and passenger folders
	regiLibrary.Instantiate('AlightingQueueEvents', 'Folder', script)
	regiLibrary.Instantiate('BoardingQueueEvents', 'Folder', script)
	regiLibrary.Instantiate('LoadedPassengers', 'Folder', game.Workspace)
	regiLibrary.Instantiate('UnloadedPassengers', 'Folder', game.ReplicatedStorage)

	--format Config.Peaking.Presets
	for _, Preset in pairs(Config.Peaking.Presets) do --pairs as dictionary
		for _, v in ipairs(Preset) do
			v *= 0.01
		end
	end

	for _, Route in ipairs(Config.Routes) do
		--fill in Config.Peaking.Presets
		for _, Stop in ipairs(Route) do
			if type(Stop[4]) == 'string' then
				local Preset = Config.Peaking.Presets[Stop[4]]
				if Preset == nil then error('Invalid preset!', Route[1][1], Stop[1]) end
				Preset = regiLibrary.table_clone(Preset) --so we don't alter the data at all

				Stop[5] *= 0.01
				local PresetMultiplier = Stop[5]

				--apply the multiplier
				if PresetMultiplier ~= 1 then --if it's 1, don't bother
					for _, v in ipairs(Preset) do
						local d = 100 - v
						d *= PresetMultiplier
						v = 100 - d
					end
				end

				--finally, fill in the data!
				table.remove(Stop, 4) --no need for the PeakingPreset string anymore
				table.remove(Stop, 4) --nor the multiplier (which is now index 4)

				for _, v in ipairs(Preset) do --(tried table.unpack, didn't work)
					table.insert(Stop, v)
				end
			end
		end

		--format route data: for example, percentages need to be converted to decimals

		--fill in useless data for the final index to prevent issues
		local tEnd = #Route
		Route[tEnd][2] = 0

		for count = 3, 13, 1 do
			Route[tEnd][count] = 100 --4 to 8 can be anything, but we may as well use 100
			--3 has to be 100 such that all passengers get off
		end

		if Config.Misc.FrequenciesInSeconds == false then
			Route[1][2] *= 60 --convert frequency to seconds
		end

		--now, convert Off and multipliers to decimals
		if Config.Misc.MultipliersInDecimal == false then
			--go through the route's table, but skip the first index as it's metadata
			for count = 2, tEnd, 1 do --skip Route[1] as that is metadata
				for c = 3, 13, 1 do
					Route[count][c] *= 0.01
					if Route[count][c] == 0 and c ~= 3 then
						warn('Modifier value of 0 found at index ' .. tostring(c) .. 
							' at stop ' .. tostring(Route[count][1]) .. 
							' on route ' .. tostring(Route[1][1]))
						print('This could cause performance issues, because task.wait(x/0) evaluates to task.wait(0).' ..
							'Hence, a very small value, such as 0.000001, is generally recommended.')
					end
				end
			end
		end
	end
	
	if Config.Misc.MultipliersInDecimal == false then
		Config.Misc.GlobalModifier *= 0.01
	end

	--tabulate and set up avatars
	for _, des in ipairs(Config.Folders.Avatars:GetDescendants()) do
		local Humanoid = des:FindFirstChildOfClass('Humanoid')
		if des:IsA('Model') and Humanoid ~= nil then
			--found one			
			table.insert(Avatars, des)

			--create a PassengerData folder for this passenger
			local PassengerData = regiLibrary.Instantiate('PassengerData', 'Folder', des)
			regiLibrary.Instantiate('Visible', 'BoolValue', PassengerData)
			regiLibrary.Instantiate('Walking', 'BoolValue', PassengerData)
			regiLibrary.Instantiate('StartStop', 'ObjectValue', PassengerData)
			regiLibrary.Instantiate('CurrentBus', 'ObjectValue', PassengerData)
			regiLibrary.Instantiate('WaitingStop', 'ObjectValue', PassengerData)
			regiLibrary.Instantiate('AtStop', 'BoolValue', PassengerData)
			regiLibrary.Instantiate('RouteCode', 'StringValue', PassengerData)
			regiLibrary.Instantiate('EndStop', 'ObjectValue', PassengerData)

			--delete name tags (not sure if the second line is needed)
			Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			Humanoid.NameOcclusion = Enum.NameOcclusion.OccludeAll

			for _, d in ipairs(des:GetDescendants()) do
				if d:IsA('BasePart') then
					d.CollisionGroupId = Config.Movement.PassengerCollisionGroupId
					d.Anchored = false 	--although we initially anchor, we should give physics a minute first
					--for example, if we've spawned floating, we need to drop down first
					d.Massless = true

					if d.Name == 'HumanoidRootPart' then
						d.CanCollide = true
					else
						d.CanCollide = false
					end
				end
			end

			--now, disable all unneeded states for optimisation
			local States = Enum.HumanoidStateType:GetEnumItems()
			table.remove(States, table.find(States, Enum.HumanoidStateType.Running)) 	--remove the two we need
			table.remove(States, table.find(States, Enum.HumanoidStateType.Seated))
			table.remove(States, table.find(States, Enum.HumanoidStateType.None))		--throws an error if set

			for _, State in ipairs(States) do
				Humanoid:SetStateEnabled(State, false)
			end
		end
	end

	--set up all existing buses, as well as any new ones
	for _, Bus in ipairs(Config.Folders.Buses:GetChildren()) do
		SetupBus(Bus)
	end

	Config.Folders.Buses.ChildAdded:Connect(function(Bus)
		SetupBus(Bus)
	end)

	--and for every stop	
	for _, Stop in ipairs(Config.Folders.Stops:GetChildren()) do 
		if Stop:IsA('Model') or Stop:IsA('Folder') then
			--set up collisions etc
			local Detector = Config.GetStopLocation(Stop, 'Detector')
			Detector.Touched:Connect(function() end) --create a TouchInterest
			Detector.Transparency = 1
		end
	end

	--player management
	local function InitialisePlayer(p)
		--create the required values
		local f = regiLibrary.Instantiate('AIBusPassengers', 'Folder', p)
		local a
		a = regiLibrary.Instantiate('MinRenderDistance', 'NumberValue', f)
		a.Value = Config.Rendering.LoadIn
		a = regiLibrary.Instantiate('MaxRenderDistance', 'NumberValue', f)
		a.Value = Config.Rendering.LoadOut
		a = regiLibrary.Instantiate('RenderCycleLength', 'NumberValue', f)
		a.Value = Config.Rendering.CycleLength
		a = regiLibrary.Instantiate('MaxRenderCycles', 'IntValue', f)
		a.Value = Config.Rendering.MaxOpsPerCycle
		a = regiLibrary.Instantiate('Enabled', 'BoolValue', f)
		a.Value = Config.Rendering.EnabledByDefault
	end

	Players.PlayerAdded:Connect(InitialisePlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		InitialisePlayer(p) --in case any joined before this script ran
	end

	--finally: manage passenger spawning, WITHOUT coroutines using a simple loop

	--starting sets of passengers
	local Spawns = {}

	for _, Route in ipairs(Config.Routes) do
		for i = 2, #Route do --go through all stops
			local On = Route[i][2] * CurrentMultiplier(Route[i])

			--mass spawn the first set
			if On >= 1 then
				for j = 2, On do
					SpawnPassenger(Route[i][1], Route)
				end
			end

			--then calculate interval
			local Freq = Route[1][2]
			local Interval = Freq / On

			--and add to the table
			table.insert(Spawns, { Route, i, math.round(Interval / Config.Misc.PassengerSpawningInterval) }) 
			--round to approximate cycle count
		end
	end

	--dummy keypress event
	Config.Misc.KeypressEvent.OnServerEvent:Connect(function() end)

	--continuous spawning
	--NOTE: This is very bad!! This is because it bulk spawns passengers each cycle, instead of spreading.
	--I would rather calculate a wait time, but I don't know how to prevent spilling due to calculation time.
	--This would cause spawning to slow down.
	local CyclesDone = 0

	while task.wait(Config.Misc.PassengerSpawningInterval) do
		CyclesDone += 1
		for _, SpawnData in ipairs(Spawns) do
			if CyclesDone % SpawnData[3] == 0 then --if the cycle count is a multiple of SpawnData[3]
				local Route = SpawnData[1]
				local Stop = Route[SpawnData[2]]
				local StopLocation = Stop[1]
				SpawnPassenger(StopLocation, Route)

				--recalculate intervals (should this be outside the if statement?)
				local On = Stop[2] * CurrentMultiplier(Stop) 
				local Freq = Route[1][2]
				local Interval = Freq / On
				SpawnData[3] = math.round(Interval / Config.Misc.PassengerSpawningInterval)
			end
		end
	end
end



return Passengers

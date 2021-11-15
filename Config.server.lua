--[[

Script version:		1.0.11 (15th Nov 2021)

This module creates and manages AI passengers that can ride buses. It could also easily be adapted for other vehicles.
This is the short documentation that only goes through how to use this module, not how it works.
If you want to edit the code or make contributions, you'll need to read the additional documentation in the main module too.
But if you're just using this module, you're in the right place - read on!
This documentation isn't very formal, like Roblox's documentation. Maybe that's worse? Who knows...

Before we start, you're going to need to do a few things. Make sure you have this script in ServerScriptService, 
the main ModuleScript in either ServerScriptService or ServerStorage, and the ClientRenderer script in StarterPlayerScripts. 
You also need to set up all your buses and all your stops:

	A bus needs many parts. Note that two doors are supported - if you only have one, use the same objects for both variables.
	- A route code. This should be a value object you reference in the route section.
		- These should be UNIQUE.
	- BoolValues for whether the front and rear doors are open.
		- Use the same value for both if you only have one door.
	- A model/folder containing seats and standing spaces.
		- These are both just Seat objects, all directly parented to the folder.
		- No other parts should be inside, but can be parented to the seats.
	- A trigger. This should be an invisible, non-collision part at the front.
		- Make sure it's large enough so that it is always picked up.
	- Finally, Outside, Inside and Outside boarding and alighting points.
		- Outside is outside the door, Inside is by the cab, Final is where they despawn (boarding) / spawn (alighting).
		- From the final point, they go to their seats.
		- Boarding passengers go Outside Boarding -> Inside Boarding -> Final Boarding.
		- Alighting passengers go the reverse, with the alighting points instead.
		- Again, for single door buses, just reference the same parts twice.

	To set up a stop, you need two parts inside a model/folder: a detector and a waiting area.
	The detector is the FULL area that a bus trigger can be in for its bus to count as being 'stopped' there.
	Therefore, make it the full size of the stop (or larger, in case buses trail back)
	The waiting area is where passengers stand around until their bus arrives. They spawn at a random point within it.
	
	As of 1.0.9, you also need to add stops to the Stops table. A stop looks like this:
	[s.UniversityStand3] = { 'the uni', 'University' }
	The key (first value) is a reference to the stop.
	The secod value is what passengers will call it ('a single to [the uni]')
	The third value is the name of the fare stage.

I'm going to talk about the things you need to do within this table itself, as they appear.
If a comment is in (brackets) it's something you don't *need* to change, but might want to.

-- Something you need to set for the module to work.
-- (An option you can ignore if you wish.)

PLEASE LOOK AT ALL ITEMS WITHOUT BRACKETS IN THEIR COMMENTS! e.g.
Thing	=	7,	-- You have to look at and set this appropriately!
Thing2	=	12,	-- (This one isn't as important)

I think this is easier both for you and for me in certain ways - however, you might get confused by some of it.
If you need help with any of this, don't hesitate to contact me so I can help you out with it.
-regibus361



]]



local Module = game.ServerScriptService.AIBusPassengers								-- Where you're keeping the main ModuleScript.
local s = game.Workspace.BusStops										-- The folder you keep all your bus stops in. 
														-- By 'bus stops' I mean detectors and waiting areas,
														-- although the folder can be shared with the stop models themselves.
														-- Has to be defined outside so we can reference within.

local Config = {
	Folders = {
		Stops						=	s,					-- Folder in Workspace containing all bus stops.
														-- This doesn't actually need to include the stops,
														-- it just needs the two parts described above.
		
		Avatars 					= 	game.ServerStorage.AIPassengerAvatars,	-- A folder in ServerStorage containing avatars.
														-- I recommend using R6 for optimisation.
														-- However, the module is fine with all types.
		
		Buses 						= 	game.Workspace.Buses,			-- Where your buses are in the workspace.
		IsBus						=	function(_)				-- If there are other objects in the above location,
			return true										-- use this function to check if one is a bus.
		end,												-- For example, if your buses' names end '_bus':
														-- return string.sub(Object.Name, -4) == '_bus'
		
		IncompatibleBuses				=	game.Workspace				-- Backup folder for buses that aren't set up properly.
	},													-- (You'll get a warning in output if a bus isn't.)
	
	
	GetBusLocation = function(Bus, Location)
		if Location == 'FromTrigger' then
			return 						Bus.Parent.Parent			-- The location of a bus, where 'Bus' is the trigger
		end
		
		local Locations = {
			Main					=	Bus.Main,				-- Main area
			
			RouteCode 				= 	Bus.Values.destn,			-- RouteCode object in a bus.
														-- Your dest system needs to change this.
														-- RouteCodes must be unique to each route.
														-- Do NOT include the .Value!
			
			FrontDoorsOpen 				= 	Bus.Main.hDoor.hdoor,			-- A BoolValue for if the FRONT doors are open.
			RearDoorsOpen				=	Bus.Main.hDoor.hdoor,			-- And the rear doors.
			
			Seats 					= 	Bus.Main.seats,				-- A model or folder containing your seats.
														-- This should be Seat objects only.
														-- Parts and so on for seat models cannot be here.
														-- However, they can be INSIDE the Seat objects.
			
			StandingSpaces 				= 	Bus.Main.StandingSpaces,		-- Standing spaces are Seats too, but for standing in.
														-- The module makes them invisible and non-collide.
														-- The seat animation isn't played in these seats.
														-- They should be about 3 studs off the ground.
														-- You may have to test to find the right height.
			
			OutsideBoarding 			= 	Bus.Main.one,				-- Invisible, non-collide part outside the doors.
														-- Passengers stand here when waiting to board.
														-- The top of this part should be at their feet.
			
			InsideBoarding 				= 	Bus.Main.two,				-- Part by the driver's cab.
			
			FinalBoarding 				= 	Bus.Main.three,				-- Passengers walk here from the IBP.
														-- From here, the passengers teleport to their seats.
			
			OutsideAlighting			=	Bus.Main.one,				-- Reverse points for the above.
														-- For single door buses, use the same parts.
														-- Slightly confusing - you START from Final alighting
			InsideAlighting				=	Bus.Main.two,
			
			FinalAlighting				=	Bus.Main.three,			
			
			Trigger 				= 	Bus.Main.maintrig,			-- The trigger part at the front of the bus.
			
			DrivingSeat 				= 	Bus.DriveSeat,				-- The driving seat. Need I say more?
		}
		return Locations[Location]
	end,
	
	
	GetStopLocation = function(Stop, Location)
		if Location == 'FromDetector' then
			return 						Stop.Parent				-- The stop, where Stop is a detector.
		end
		local Locations = {
			Detector 				= 	Stop.detector,				-- The detector's location in a stop.
														-- This should cover the whole stop area!
			
			WaitingArea 				= 	Stop.waitarea,				-- The area passengers wait in.
		}
		return Locations[Location]
	end,
	
	
	TriggerName 						= 	'BusTriggerPart',			-- The NAME of bus triggers.
														-- Make sure this is unique!
														-- i.e. no other parts should be named this.
	
	DetectorName 						= 	'BusDetector',				-- Name of detectors. Also unique.
	
	
	Movement = {
		SignificantDistance		 		= 	0.15,					-- (Minimum distance passengers respond to.)
														-- (Also the minimum teleport distance.)
		
		MaxBoardingDistance 				= 	30,					-- (Maximum distance before passengers give up.)
		MaxBoardingVelocity 				= 	4,					-- (Maximum speed for the below two options.)
		OBPMovementReq 					= 	'VelocityOnly',				-- (Requirement to move to the OBP.)
														-- ('VelocityOnly' = must be slower than the above.)
														-- ('CompleteStop' = doors must also be open.)
		IBPMovementReq 					= 	'CompleteStop',				-- (Above for the IBP.)
		WaitForAlighters 				= 	true,					-- (Wait for alighting passengers before boarding.)
		
		AlightingInterval = function()
			return 						math.random(0.4, 1.5)			-- (Get a time between two passengers alighting.)
		end,
		
		BellRingDistance 				= 	40,					-- (Passengers ring the bell when their stop is:)
														-- (below this distance away and,)
														-- (the closest stop on their bus' route.)
		
		MaxSeatChecks 					= 	47,					-- (After this many randomly chosen seats are taken,)
														-- (stand, as passengers don't use all seats.)
		UseSeatCheckLimit 				= 	false,					-- (False if you want them to check all seats.)
		CheckAllSeatsIfFull 				= 	true,					-- (If standing spaces are full too, check again?)
		
		PassengerCollisionGroupId 			= 	1,					-- Collision group ID for passengers.
														-- Must have ALL COLLISIONS OFF!

		Speed 						= 	6,					-- (In studs / sec)
		
		CanMoveToTimeout 				= 	300
	},
	
	
	Ticketing = {
		PurchaseChance					=	0,					-- (Likelihood of buying instead of showing.)
		
		Pricing = {
			PricePerStop				=	0.45,					-- (Fare stage prices are for the first stop.)	
			ReturnMultiplier			=	1.5,					-- (Increased price from a single.)
			PriceRounding				=	0.05,					-- (What to round fares to.)
		},
		
		Greetings = {
			Probability				=	0.7,					-- (The chance (0-1) of passengers greeting the driver)
														-- (Note this is non-purchasing passengers only)
			
			Texts 					= 	{					-- (What the passengers might say.)
				'Hello!',
				'G\'day!',
				'Hi there!',
				'Hey.',
				'Sup'
			}
		},
		
		PurchaseTexts = {
			'I want a __TicketName!',
			'Can I have a __TicketName please?',
			'Wassup, gimme a __TicketName',
			'I\'d like a __TicketName please.',
			'__TicketName, now!', -- no comment
			'You! I DEMAND a __TicketName right this second!!!'
		},
		
		ThankTexts = {
			'Thank you!',
			'Thanks driver!',
			'Cool, thanks',
			'Cheers bro',
			'Thank youuuuuuuu'
		},
		
		InvalidTickets = {
			Probabilities = {
				Expired				=	0.002,					-- (Using an expired ticket.)
				FalseChild			=	0.005,					-- (An adult using a child ticket.)
				FalseAdult			=	0.001,					-- (A child using an adult ticket.)
				InvalidReturn			=	0.007,					-- (Returning from the wrong location.)
				Forged				=	0.0002,					-- (Invalid field data.)
				ForgedPerField			=	30					-- (Chance of a forgery manifesting in a field.)
			},
			
			ExpiryDateChance			=	50					-- (When finding a date for an expired ticket,)
		},												-- (the chance of each day back being picked.)
														-- (Higher = expired tickets are more recent.)
		
		Machine = {
			ClickDebounce				=	0.1					-- (Prevent going through multiple menus at once.)
		},
		
		GetCurrentTime = function()
			return DateTime.now():ToUniversalTime()							-- How to get the current DateTime.
		end
	},
	
	
	-- These values can be changed from the server: 
	-- Player.AIBusPassengers.[Enabled/RenderCycleLength/MinRenderDistance/MaxRenderDistance/MaxRenderCycles].Value
	Rendering = {
		EnabledByDefault				=	true,					-- (Whether to enable the passengers on the client.)
		CycleLength 					= 	1,					-- (Length of one render cycle.)
		LoadIn 						= 	1000,					-- (Passengers within this radius are loaded in.)
		LoadOut 					= 	1500,					-- (Passengers outside this radius are loaded out.)
		MaxOpsPerCycle 					= 	250,					-- (Max queues/loads per render cycle.)
		StatsBox					=	false					-- (Display a debug box in the bottom left.)
														-- (Breaks in some games.)
	},
	
	
	Keybinds = {
		AcceptTicket = Enum.KeyCode.Q,
		DenyTicket = Enum.KeyCode.E
	},
	
	
	Misc = {
		KeypressEvent					=	game.ReplicatedStorage.Keypress,	-- An event that fires on every keypress.
														-- With one parameter (Enum.KeyCode.whatever)
		SetupDelay					=	2,					-- (How long to wait before setting a bus up.)
		FrequenciesInSeconds 				= 	false,					-- (If you would prefer to use seconds to configure.)
		MultipliersInDecimal 				= 	false,					-- (As above.)
		CheckCompatibility				=	false,					-- (Check bus compatibility.)
		PassengerSpawningInterval 			= 	10,					-- (Lower = more accurate spawning time, laggier.)
		GlobalModifier 					= 	100					-- (Modifies all spawn amounts.)
	},


	Sounds = {
		Bell 						= 	'rbxassetid://6044527717'		-- Sound ID for the bell.
	},
	
	
	-- A dictionary of bus stops.
	-- The first entry is the name passengers use in conversation, the second is the fare stage.
	Stops = {
		[s.stop1] = {'the first stop', 'STOP 1'},
		[s.stop2] = {'the second stop', 'STOP 2'},
		[s.stop3] = {'the last stop', 'STOP 3'}
	},
	
	
	Peaking = {
		MorningStart 					= 	7,					-- (Period start/end times.)
		MorningEnd 					= 	10,					-- (As hours on the 24 hour clock)
		EveningStart 					= 	16,
		EveningEnd 					= 	19,
		NightStart 					= 	21,
		NightEnd 					= 	6,
		
		--[[
		
		Routes Setup
		
		Routes in this system are tables.
		Each has a metadata subtable, then another subtable for each stop.
		The metadata table contains the route's code, then its frequency.
		The code is used with the RouteCode value in a bus to determine if a bus is on that route.
		The frequency is how long it takes for passengers to regenerate at stops on the route.
		
		The remaining subtables each represent a stop.
		You have the stop's location (s.[path]). This is the model containing the detector and waiting area.
		Then you have the NUMBER of passengers boarding there, under normal conditions.
		Next, the PERCENTAGE of passengers on the bus at this point that get off here.
		Note that this causes some weird mechanics: if two consecutive stops have 50, half will get off at the second stop.
		This is because there are half as many passengers on the bus. This may seem obvious, but is easy to forget.
		
		For each route, the first line is just {
		Each other line is contained within {} and separated with commas, and with a comma after, like so:
		{ item_1, item_2, item_3 },
		The final line is then },
		
		This is a table - more info on them: developer.roblox.com/en-us/articles/Table
		
		After this, you have the peaking data. This consists of 10 numbers (the examples below don't - bear with me).
		The first five are how the PERCENTAGE of passengers getting ON changes in five periods:
		- morning peak
		- evening peak
		- nighttime
		- saturdays
		- sundays
		The next five are how the PERCENTAGE of passengers getting OFF changes.
		An example: {MyStop, 20, 0, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100} doesn't modify at all
		If you want to use decimals (0-1) instead of percentages, set Misc.MultipliersInDecimal = true
		As this sounds like a lot, you can use a preset instead.
		You have the name of the preset, followed by the 'likeness' to that preset.
		50 = variation is halved, so 140% becomes 120%, 70% becomes 85%, etc.
		Not too happy with this system, but it's more effective than the alternatives I thought of.
		
		Four presets are included below: you can add or remove them as you wish.
		
		]]
		
		Presets = {
			CityCentreOut 			= {	070,	130,	025,	075,	050,			100,	100,	110,	120,	120	},
			CityCentreIn 			= {	130,	070,	035,	105,	075,			100,	100,	100,	100,	100	},
			SuburbsOut			= {	110,	095,	010,	140,	110,			100,	100,	125,	110,	110	},
			SuburbsIn 			= {	130,	090,	015,	110,	080,			100,	100,	105,	115,	115	}
		}
	},
	
	
	Routes = {
		{
			{ "101", 	15 	},
			{ s.stop1,	23,	0, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100},
			{ s.stop2,	24,	0, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100},
			{ s.stop3		}
		},
	}
}

--transfer to client as requested
game.ReplicatedStorage.AIBusPassengersConfigTransferrer.OnServerInvoke = function()
	return Config
end

--leave this line alone
require(Module).Start(Config)

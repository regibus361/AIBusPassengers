--[[

Script version:		1.0.12 (19th Dec 2021)

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
	The second value is what passengers will call it ('a single to [the uni]')
	The third value is the name of the fare stage.

I'm going to talk about the things you need to do within this table itself, as they appear.
If a comment is in (brackets) it's something you don't *need* to change, but might want to.

-- Something you need to set for the module to work.
-- (An option you can ignore if you wish.)

I think this is easier both for you and for me in certain ways - however, you may get confused.
If you need help with any of this, don't hesitate to contact me and I'll be happy to explain.
-regibus361



]]



local Rnd = Random.new()
local Module = script.Parent			-- Where you're keeping the main ModuleScript.
local s = game.Workspace.BusStops		-- The folder you keep all your bus stops in. 
-- By 'bus stops' I mean detectors and waiting areas,
-- although the folder can be shared with the stop models themselves.
-- Has to be defined outside so we can reference within.

local Config = {
	Folders = {
		Assets						=	script.Parent.Assets,					-- Folder containing ticket images etc.
		
		Stops						=	s,										-- Folder in Workspace containing all bus stops.
		-- This doesn't actually need to include the stops,
		-- it just needs the two parts described above.

		Avatars 					= 	game.ServerStorage.AIPassengerAvatars,	-- A folder in ServerStorage containing avatars.
		-- I recommend using R6 for optimisation.
		-- However, the module is fine with all types.

		Buses 						= 	game.Workspace.Buses,					-- Where your buses are in the workspace.
		IsBus						=	function(_)								-- If there are other objects in the above location,
			return true															-- use this function to check if one is a bus.
		end,																	-- For example, if your buses' names end '_bus':
		-- return string.sub(Object.Name, -4) == '_bus'

		IncompatibleBuses			=	game.Workspace							-- Backup folder for buses that aren't set up.
	},																			-- (You'll get a warning in output if a bus isn't.)


	GetBusLocation = function(Bus, Location)
		if Location == 'FromTrigger' then
			return 						Bus.Parent.Parent						-- The location of a bus, where 'Bus' is the trigger
		end

		local Locations = {
			Main					=	Bus.Main,								-- Main area

			RouteCode 				= 	Bus.BusData.Route,						-- RouteCode object in a bus.
			-- Your dest system needs to change this.
			-- RouteCodes must be unique to each route.

			FrontDoorsOpen 			= 	Bus.Main.Doors.Front.IsOpen,			-- A BoolValue for if the FRONT doors are open.
			RearDoorsOpen			=	Bus.Main.Doors.Back.IsOpen,				-- And the rear doors.
																				-- (If single-door, use the same for both)

			Seats 					= 	Bus.Main.Seats,							-- A model or folder containing your seats.
			-- This should be Seat objects only.
			-- Parts and so on for seat models cannot be here.
			-- However, they can be INSIDE the Seat objects.

			StandingSpaces 			= 	Bus.Main.StandingSpaces,				-- Standing spaces are Seats too, but for standing in.
			-- The module makes them invisible and non-collide.
			-- The seat animation isn't played in these seats.
			-- They should be about 3 studs off the ground.
			-- You may have to test to find the right height.

			OutsideBoarding 		= 	Bus.Main.BoardingPoints.Outside,		-- Invisible, non-collide part outside the doors.
			-- Passengers stand here when waiting to board.

			InsideBoarding 			= 	Bus.Main.BoardingPoints.Inside,			-- Part by the driver's cab.
			-- Note that THIS MUST BE A SEAT! I get it's odd, it's just so passengers 'sit' there when buying a ticket.
			-- They will therefore stay there if any unscrupulous drivers start moving whilst doing so

			FinalBoarding 			= 	Bus.Main.BoardingPoints.Final,			-- Passengers walk here from the IBP.
			-- From here, the passengers teleport to their seats.

			OutsideAlighting		=	Bus.Main.AlightingPoints.Outside,		-- Reverse points for the above.
			-- For single door buses, use the same parts.
			
			InsideAlighting			=	Bus.Main.AlightingPoints.Inside,		-- This needn't be a seat, but it can be.

			FinalAlighting			=	Bus.Main.AlightingPoints.Final,			

			Trigger 				= 	Bus.Main.BusTriggerPart,				-- The trigger part at the front of the bus.

			DrivingSeat 			= 	Bus.DriveSeat,							-- The driving seat. Need I say more?
		}
		return Locations[Location]
	end,


	GetStopLocation = function(Stop, Location)
		if Location == 'FromDetector' then
			return 						Stop.Parent								-- The stop, where Stop is a detector.
		end
		local Locations = {
			Detector 				= 	Stop.BusDetector,						-- The detector's location in a stop.
			-- This should cover the whole stop area!

			WaitingArea 			= 	Stop.WaitingArea,						-- The area passengers wait in.
		}
		return Locations[Location]
	end,


	TriggerName 					= 	'BusTriggerPart',						-- The NAME of bus triggers.
	-- Make sure this is unique!
	-- i.e. no other parts should be named this.

	DetectorName 					= 	'BusDetector',							-- Name of detectors. Also unique.


	Movement = {
		SignificantDistance		 	= 	0.15,									-- (Minimum distance passengers respond to.)
		-- (Also the minimum teleport distance.)

		MaxDistance 				= 	100,									-- (Maximum distance before passengers give up.)
		
		MaxBusVelocity		 		= 	5,										-- (Maximum speed of buses to walk inside.)
		-- (If this is exceeded, the passenger will teleport instead)
		
		OBPMovementReq				=	'None',									-- ('CompleteStop', 'VelocityOnly' or 'None')
		IBPMovementReq				=	'CompleteStop',							-- (The former includes doors.)
		
		WaitForAlighters 			= 	false,									-- (Wait for alighting passengers before boarding.)

		AlightingInterval = function()
			return 						Rnd:NextNumber(1, 2.5)				-- (Get a time between two passengers alighting.)
		end,

		BellRingDistance 			= 	2000,									-- (Passengers ring the bell when their stop is:)
		-- (below this distance away and,)
		-- (the closest stop on their bus' route.)
		
		BellRingCheckInterval		=	6,										-- (Check whether to ring every [this] seconds.)

		MaxSeatChecks 				= 	3,										-- (After this many randomly chosen seats are taken,)
		-- (stand, as passengers don't use all seats.)
		
		UseSeatCheckLimit 			= 	true,									-- (False if you want them to check all seats.)
		
		CheckAllSeatsIfFull 		= 	true,									-- (If standing spaces are full too, check again?)

		PassengerCollisionGroupId 	= 	3,										-- Collision group ID for passengers.
		-- Must have ALL COLLISIONS OFF!

		Speed 						= 	4,										-- (In studs / sec)
		Height						=	2.5										-- How many studs up the root part is.
	},


	Ticketing = {
		Enabled						=	true,									-- (Whether to use ticketing at all.)
		
		PurchaseChance				=	0.6,									-- (Likelihood of buying instead of showing.)

		Pricing = {
			PricePerStop			=	0.35,									-- (Fare stage prices are for the first stop.)	
			ReturnMultiplier		=	1.5,									-- (Increased price from a single.)
			PriceRounding			=	0.05,									-- (What to round fares to.)
		},

		Greetings = {
			Probability				=	0.7,									-- (The chance (0-1) of passengers greeting the driver)
			-- (Note this is non-purchasing passengers only)

			Texts 					= 	{										-- (What the passengers might say.)
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
			'__TicketName, now!' -- no comment
		},

		ThankTexts = {
			'Thank you!',
			'Thanks driver!',
			'Cool, thanks',
			'Cheers bro'
		},

		InvalidTickets = {
			Probabilities = {
				Expired				=	0.05,									-- (Using an expired ticket.)
				FalseChild			=	0.1,									-- (An adult using a child ticket.)
				FalseAdult			=	0.1,									-- (A child using an adult ticket.)
				InvalidReturn		=	0.1,									-- (Returning from the wrong location.)
				Forged				=	0.01,									-- (Invalid field data.)
				ForgedPerField		=	0.2										-- (Chance of a forgery manifesting in a field.)
			},

			ExpiryDateChance		=	0.3										-- (When finding a date for an expired ticket,)
		},																		-- (the chance of each day back being picked.)
		-- (Higher = expired tickets are more recent.)

		Machine = {
			ClickDebounce			=	0.1										-- (Prevent going through multiple menus at once.)
		},

		GetCurrentTime = function()
			return DateTime.now():ToUniversalTime()								-- How to get the current DateTime.
		end
	},


	-- These values can be changed from the server: 
	-- Player.AIBusPassengers.[Enabled/RenderCycleLength/MinRenderDistance/MaxRenderDistance/MaxRenderCycles]
	Rendering = {
		EnabledByDefault			=	true,									-- (Whether to enable the passengers on the client.)
		
		CycleLength 				= 	1,										-- (Length of one render cycle.)
		
		LoadIn 						= 	1000,									-- (Passengers within this radius are loaded in.)
		
		LoadOut 					= 	1500,									-- (Passengers outside this radius are loaded out.)
		
		MaxOpsPerCycle 				= 	250,									-- (Max queues/loads per render cycle.)
		
		StatsBox					=	false									-- (Display a debug box in the bottom left.)
		-- (Breaks in some games.)
	},


	Keybinds = {
		AcceptTicket = Enum.KeyCode.Q,
		DenyTicket = Enum.KeyCode.E
	},


	Misc = {
		KeypressEvent				=	game.ReplicatedStorage.Keypress,		-- An event that fires on every keypress.
		-- With one parameter (Enum.KeyCode.whatever)
		
		SetupDelay					=	0,										-- (How long to wait before setting a bus up.)
		
		FrequenciesInSeconds 		= 	false,									-- (If you would prefer to use seconds to configure.)
		
		MultipliersInDecimal 		= 	false,									-- (As above.)
		
		CheckCompatibility			=	false,									-- (Check bus compatibility.)
		
		PassengerSpawningInterval 	= 	15,										-- (Lower = more accurate spawning time, laggier.)
		
		GlobalModifier 				= 	100										-- (Modifies all spawn amounts.)
	},


	Sounds = {
		Bell 						= 	'rbxassetid://6044527717'				-- Sound ID for the bell.
	},


	-- A dictionary of bus stops.
	-- The first entry is the name passengers use in conversation, the second is the fare stage.
	Stops = {
		[s.AirportBridgeE] = {'the petrol station', 'Keir Hardie'},
		[s.AirportBridgeW] = {'opposite the petrol station', 'Keir Hardie'},
		[s.AirportSouthE] = {'outside the airport', 'Airport'},
		[s.AirportSouthW] = {'opposite the airport', 'Airport'},
		[s.AirportWestN] = {'outside the airport', 'Airport'},
		[s.AirportWestS] = {'opposite the airport', 'Airport'},
		[s.AppletonSuperstore] = {'the Appleton superstore', 'Appleton'},
		[s.AppletonVillageN] = {'Appleton', 'Appleton'},
		[s.AppletonVillageS] = {'Appleton', 'Appleton'},
		[s.BusStation] = {'the bus station', 'Canterbury'},
		[s.CentralBridgeE] = {'the central bridge', 'Canterbury'},
		[s.CentralBridgeW] = {'the central bridge', 'Canterbury'},
		[s.CentralDepotN] = {'the bus depot', 'Canterbury'},
		[s.CentralDepotS] = {'opposite the bus depot', 'Canterbury'},
		[s.CityParkSouthE] = {'the central park', 'Canterbury'},
		[s.EastHadlowE] = {'Hadlow', 'Hadlow'},
		[s.EastHadlowW] = {'Hadlow', 'Hadlow'},
		[s.EastKeirHardieN] = {'Keir Hardie', 'Keir Hardie'},
		[s.EastKeirHardieS] = {'Keir Hardie', 'Keir Hardie'},
		[s.HighSchoolN] = {'opposite the high school', 'Airport'},
		[s.HighSchoolS] = {'the high school', 'Airport'},
		[s.HospitalWestN] = {'opposite the hospital', 'Hospital'},
		[s.HospitalWestS] = {'the hospital', 'Hospital'},
		[s.IndustrialEstateE] = {'the central estate', 'Industrial'},
		[s.IndustrialEstateW] = {'the central estate', 'Industrial'},
		[s.MarbleStreetE] = {'Marble Street', 'Airport'},
		[s.MarbleStreetW] = {'Marble Street', 'Airport'},
		[s.MiddleAppletonRoadN] = {'the superstore roundabout', 'Superstore'},
		[s.MiddleAppletonRoadS] = {'the superstore roundabout', 'Superstore'},
		[s.NorthKeirHardieE] = {'Keir Hardie', 'Keir Hardie'},
		[s.NorthKeirHardieW] = {'Keir Hardie', 'Keir Hardie'},
		[s.ParkAndRideIn] = {'Canterbury Park and Ride', 'Park and Ride'},
		[s.ParkAndRideOut] = {'the Park and Ride', 'Park and Ride'},
		[s.SchoolRoadE] = {'the School Road', 'Canterbury'},
		[s.SchoolRoadW] = {'the School Road', 'Canterbury'},
		[s.SouthKeirHardieN] = {'Keir Hardie', 'Keir Hardie'},
		[s.SouthKeirHardieS] = {'Keir Hardie', 'Keir Hardie'},
		[s.SuperstoreTerminusE] = {'opposite the superstore', 'Superstore'},
		[s.SuperstoreTerminusW] = {'the superstore', 'Superstore'},
		[s.UpperAppletonRoadN] = {'Appleton Road', 'Hadlow'},
		[s.UpperAppletonRoadS] = {'Appleton Road', 'Hadlow'},
		[s.UpperNewDoverRdE] = {'New Dover Road', 'New Dover Rd'},
		[s.UpperNewDoverRdW] = {'New Dover Road', 'New Dover Rd'},
		[s.WestHadlowE] = {'Hadlow', 'Hadlow'},
		[s.WestHadlowW] = {'Hadlow', 'Hadlow'},
		[s.WesternFlatsN] = {'the central flats', 'Industrial'},
		[s.WesternFlatsN] = {'opposite the central flats', 'Industrial'}
	},


	Peaking = {
		MorningStart 				= 	7,										-- (Period start/end times.)
		MorningEnd 					= 	10,
		EveningStart 				= 	16,
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
		The first five are how the number of passengers getting ON changes in five periods:
		- morning peak
		- evening peak
		- nighttime
		- saturdays
		- sundays
		The next five are how the percentage of passengers getting OFF changes.
		As this sounds like a lot, you can use a preset instead.
		You have the name of the preset, followed by the 'likeness' to that preset.
		50 = variation is halved, so 140% becomes 120%, 70% becomes 85%, etc.
		Not too happy with this system, but it's more effective than the alternatives I thought of.
		
		Four presets are included below: you can add or remove them as you wish.
		
		]]

		Presets = {
			CityCentreOut 			= {	070,	130,	025,	075,	050,			100,	100,	110,	120,	120	},
			CityCentreIn 			= {	130,	070,	035,	105,	075,			100,	100,	100,	100,	100	},
			SuburbsOut			 	= {	110,	095,	010,	140,	110,			100,	100,	125,	110,	110	},
			SuburbsIn 				= {	130,	090,	015,	110,	080,			100,	100,	105,	115,	115	}
		}
	},


	Routes = {
		{
			{ "00101", 	15 },
			{ s.BusStation,				15,		0,			"CityCentreOut",	125	},
			{ s.CityParkSouthE,			12,		1,			"CityCentreOut",	090	},
			{ s.CentralDepotN,			5,		3,			"CityCentreOut",	110	},
			{ s.SchoolRoadW,			2,		6,			"CityCentreOut",	050	},
			{ s.HighSchoolN,			3,		7.5,		085,	750,	025,	115,	095,			750,	100,	125,	110,	110	},
			{ s.AirportWestN,			6,		12.5,		100,	125,	067,	075,	050,			100,	100,	125,	125,	125	},
			{ s.EastHadlowW,			4,		20,			"SuburbsOut",		120	},
			{ s.WestHadlowW,			5,		40,			"SuburbsOut",		150	},
			{ s.MiddleAppletonRoadS,	0,		33,			"SuburbsOut",		075	},
			{ s.SuperstoreTerminusW		}
		},

		{
			{ "00102",		15 },
			{ s.SuperstoreTerminusE,	10,		0,			110,	125,	030,	075,	060,			100,	100,	100,	100,	100	},
			{ s.MiddleAppletonRoadN,	4,		0.1,		"SuburbsIn",		075	},
			{ s.WestHadlowE,			12,		7.5,		"SuburbsIn",		150	},
			{ s.EastHadlowE,			7,		5,			"SuburbsIn",		120	},
			{ s.AirportWestS,			5,		15,			125,	100,	067,	075,	050,			100,	100,	110,	135,	135	},
			{ s.HighSchoolS,			3,		22.5,		085,	750,	030,	120,	100,			750,	100,	105,	115,	115	},
			{ s.SchoolRoadE,			6,		6,			"CityCentreIn",		050	},
			{ s.CentralDepotS,			1,		12.5,		"CityCentreIn",		110	},
			{ s.BusStation				}
		},

		{
			{ "00103",	30	},
			{ s.BusStation,				10,		0,			"CityCentreOut",	080	},
			{ s.CityParkSouthE,			12,		1.5,		"CityCentreOut",	067	},
			{ s.CentralBridgeE,			3,		2.5,		"CityCentreOut",	050	},
			{ s.SouthKeirHardieS,		2,		6,			"SuburbsOut",		085	},
			{ s.HospitalWestN,			14,		40,			090,	167,	045,	105,	100,			180,	100,	225,	100,	100	},
			{ s.EastKeirHardieN,		4,		10,			"SuburbsOut",		100	},
			{ s.NorthKeirHardieW,		5,		12,			"SuburbsOut",		100	},
			{ s.AirportBridgeW,			1,		2,			"SuburbsOut",		075	},
			{ s.AirportSouthW,			3,		20,			125,	100,	067,	075,	050,			100,	100,	110,	135,	135	},
			{ s.MarbleStreetW,			1,		40,			"SuburbsOut",		080	},
			{ s.SuperstoreTerminusW		}
		},

		{
			{ "00104",	30	},
			{ s.SuperstoreTerminusW,	6,		0,			110,	125,	030,	075,	060,			100,	100,	100,	100,	100	},
			{ s.MarbleStreetE,			8,		3,			"SuburbsIn",		080	},
			{ s.AirportSouthE,			5,		10,			125,	100,	067,	075,	050,			100,	100,	110,	135,	135	},
			{ s.AirportBridgeE,			1,		1,			"SuburbsIn",		075	},
			{ s.NorthKeirHardieE,		8,		12,			"SuburbsIn",		100	},
			{ s.EastKeirHardieS,		7,		10,			"SuburbsIn",		100	},
			{ s.HospitalWestS,			14,		60,			090,	167,	045,	105,	100,			180,	100,	225,	100,	100	},
			{ s.SouthKeirHardieN,		5,		7,			"SuburbsIn",		085	},
			{ s.CentralBridgeW,			1,		12,			"CityCentreIn",		050	},
			{ s.BusStation				}
		},

		{
			{ "01403",	20	},
			{ s.BusStation,				40,		0,			"CityCentreOut",	150	},
			{ s.UpperNewDoverRdW,		5,		30,			"SuburbsOut",		120	},
			{ s.SuperstoreTerminusE,	12,		40,			080,	135,	025,	075,	060,			150,	075,	120,	110,	110	},
			{ s.ParkAndRideOut,			3,		82,			"SuburbsOut",		100	},
			{ s.AppletonSuperstore		}
		},

		{
			{ "01404",	20	},
			{ s.AppletonSuperstore,		4,		0,			"SuburbsIn",		110	},
			{ s.ParkAndRideIn,			26,		7,			"SuburbsIn",		100	},
			{ s.SuperstoreTerminusW,	13,		33,			130,	145,	025,	075,	060,			080,	100,	120,	110,	110	},
			{ s.UpperNewDoverRdE,		17,		5,			"SuburbsIn",		120	},
			{ s.BusStation				}
		},

		{
			{ "02401",	30	},
			{ s.BusStation,				6,		0,			"CityCentreOut",	050	},
			{ s.WesternFlatsN,			10,		67,			"CityCentreOut",	080	},
			{ s.IndustrialEstateW,		22,		15,			"CityCentreOut",	100	},
			{ s.UpperNewDoverRdW,		2,		25,			"SuburbsOut",		120 },
			{ s.SuperstoreTerminusE,	6,		12,			080,	150,	025,	075,	060,			115,	090,	110,	105,	105	},
			{ s.MarbleStreetE,			12,		15,			"SuburbsOut",		075	},
			{ s.AirportWestN,			16,		10,			100,	130,	067,	075,	050,			100,	100,	125,	125,	125	},
			{ s.EastHadlowW,			8,		25,			"SuburbsOut",		130	},
			{ s.WestHadlowW,			10,		50,			"SuburbsOut",		175	},
			{ s.UpperAppletonRoadN,		3,		20,			"SuburbsOut",		110	},
			{ s.ParkAndRideOut,			2,		33,			"SuburbsOut",		100	},
			{ s.AppletonVillageN,		3,		90,			"SuburbsOut",		067	},
			{ s.AppletonSuperstore		}
		},

		{
			{ "02402",	30	},
			{ s.AppletonSuperstore,		8,		0,			"SuburbsIn",		110	},
			{ s.AppletonVillageS,		12,		25,			"SuburbsIn",		067	},
			{ s.ParkAndRideIn,			9,		35,			"SuburbsIn",		100	},
			{ s.UpperAppletonRoadS,		7,		12,			"SuburbsIn",		110	},
			{ s.WestHadlowE,			21,		7,			"SuburbsIn",		175	},
			{ s.EastHadlowE,			15,		10,			"SuburbsIn",		130	},
			{ s.AirportWestS,			6,		40,			110,	105,	067,	075,	050,			100,	100,	110,	135,	135	},
			{ s.MarbleStreetW,			7,		22,			"SuburbsIn",		075	},
			{ s.SuperstoreTerminusW,	5,		33,			110,	115,	025,	075,	060,			080,	100,	120,	110,	110	},
			{ s.UpperNewDoverRdE,		8,		10,			"SuburbsIn",		120	},
			{ s.IndustrialEstateW,		2,		82,			"CityCentreIn",		100	},
			{ s.WesternFlatsS,			5,		25,			"CityCentreIn",		080	},
			{ s.BusStation				}
		}
	}
}

--leave this line alone
require(Module)(Config)

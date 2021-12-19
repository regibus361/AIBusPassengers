--[[ 

Parent this to StarterPlayerScripts!


Script version:		1.0.12 (19th Dec 2021)

This script deals with streaming on the client to reduce lag.
(It also passes keypresses to the server)
This is because it is inefficient to have all passengers loaded, even those far away.
It has two main aspects to itself: queueing and rendering.
Every render cycle (1 sec by default, in config), this script both renders and queues.

Queueing finds passengers that are loaded (in the workspace) but far away, and queues them to be unloaded (moved to replicatedstorage)
It also does the opposite - finding unloaded but nearby passengers to queue up for loading.
Rendering is the actual movement from the front of the queue.
It is throttled based on frame rate, which a simple system is used to approximate (badly).
This is why queues are used - otherwise, too many could be processed at once, which is very laggy!

The settings used in this script can be changed during gameplay. To do so, edit Value objects in:
Player.AIBusPassengers.[MinRenderDistance/MaxRenderDistance/RenderCycleLength/MaxRenderCycles/Enabled]
IMPORTANT note! The Enabled value needs to be changed from the server, or players will continue seeing GUIs!
If passengers are 'disabled' then this script just queues out all passengers it sees that are loaded.
Note that it has to manually queue out all new passengers that spawn in.
The performance impact of on and disabled client-side vs off altogether is unknown.



]]

--services
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local CharacterHRP = Character:WaitForChild('HumanoidRootPart')

--if the player respawns
Player.CharacterAdded:Connect(function(c)
	Character = c
	CharacterHRP = Character:WaitForChild('HumanoidRootPart')
end)

--start by getting config
local Config = game.ReplicatedStorage:WaitForChild('AIBusPassengersConfigTransferrer'):InvokeServer()

--constants
local PassengerFolder = game.Workspace:WaitForChild('LoadedPassengers', math.huge) -- silence infinite yield warnings
local PassengerStore = game.ReplicatedStorage:WaitForChild('UnloadedPassengers')
local MinRenderDistance = Config.Rendering.LoadIn
local MaxRenderDistance = Config.Rendering.LoadOut
local CycleTime = Config.Rendering.CycleLength
local MaxLPS = Config.Rendering.MaxOpsPerCycle
local DisplayDebug = Config.Rendering.StatsBox

--variables
local LPS = 0 --loads per second (passengers loaded, rather)
local CurrentFrame
local PreviousFrame = tick()
local FrameLength
local FPS = 0
local Enabled = true
local QueuedPassengers
local MicrocycleTime
local MicrocycleCount
local CurrentPassenger

--tables
local Passengers = {}
local InQueue = {}
local OutQueue = {}

--display debug GUI
local DebugGUI = script.RendererHealthDebug
if DisplayDebug == true then
	DebugGUI.Parent = Player:WaitForChild('PlayerGui')
end

--sort out value objects (spaghetti code alert)

--in case they don't exist yet
local F = Player:WaitForChild('AIBusPassengers')

--and create connections
F.MinRenderDistance.Changed:Connect(function(v)
	MinRenderDistance = v
end)
F.MaxRenderDistance.Changed:Connect(function(v)
	MaxRenderDistance = v
end)
F.RenderCycleLength.Changed:Connect(function(v)
	CycleTime = v
end)
F.MaxRenderCycles.Changed:Connect(function(v)
	MaxLPS = v
end)
F.Enabled.Changed:Connect(function(v)
	Enabled = v
end)

--cleaning up tables
local function CleanTable(t)
	for i, v in ipairs(t) do
		if v == nil then
			table.remove(t, i)
		end
	end
end

local function CleanTables()
	CleanTable(Passengers)
	CleanTable(InQueue)
	CleanTable(OutQueue)
end

--handle passengers being added and deleted
local function PassengerAdded(Passenger)
	table.insert(Passengers, Passenger)
end

local function PassengerRemoved(Passenger)
	--table.remove(Passengers, table.find(Passengers, Passenger))
	CleanTables()
end

--queues
local function JoinQueue(Passenger, Direction)
	--this doesn't need to check whether the passenger's already there, nor whether they're in the other queue
	--that's done before calling this function
	if Direction == true then
		table.insert(InQueue, Passenger)
	else
		table.insert(OutQueue, Passenger)			
	end
end

local function LeaveQueue(Passenger, Direction)
	if Direction == true then
		local IIndex = table.find(InQueue, Passenger)
		if IIndex then --if they're in either, leave it
			table.remove(InQueue, IIndex)
		end
	else
		local OIndex = table.find(InQueue, Passenger)
		if OIndex then --if they're in either, leave it
			table.remove(InQueue, OIndex)
		end		
	end
end

--PassengerAdded event
PassengerFolder.ChildAdded:Connect(PassengerAdded)

--in case any passengers spawned before this script ran
for _, c in ipairs(PassengerFolder:GetChildren()) do
	PassengerAdded(c)
end

--FPS handler
RunService.Heartbeat:Connect(function()
	CurrentFrame = tick()
	FrameLength = CurrentFrame - PreviousFrame --in seconds
	PreviousFrame = CurrentFrame
	FPS = 1 / FrameLength
	if FPS > 60 then
		FPS = 60 --assume people aren't using unlockers
	end
	
	--LPS adjustment
	LPS = (FPS * MaxLPS) / 60
	if LPS > MaxLPS then
		LPS = MaxLPS
	end
end)

--loop operations: queueing and rendering
local function QueuePassengers()
	QueuedPassengers = 0
	MicrocycleTime = CycleTime / #Passengers
	
	for _, Passenger in ipairs(Passengers) do
		if Passenger == nil then
			PassengerRemoved(Passenger) --remove it from the system
		elseif Passenger:FindFirstChild('HumanoidRootPart') then --if it isn't here yet, skip this passenger
			local Distance = math.abs((Passenger.HumanoidRootPart.Position - CharacterHRP.Position).Magnitude)
			
			if Distance > MaxRenderDistance then
				--if it needs to move and it's not already queueing, move it
				if table.find(OutQueue, Passenger) == nil and Passenger.Parent == PassengerFolder then
					QueuedPassengers += 1
					LeaveQueue(Passenger, true)
					JoinQueue(Passenger, false)
				end
			elseif Distance < MinRenderDistance then
				if table.find(InQueue, Passenger) == nil and Passenger.Parent == PassengerStore then
					QueuedPassengers += 1
					LeaveQueue(Passenger, false)
					JoinQueue(Passenger, true)
				end
			else
				QueuedPassengers += 1
				LeaveQueue(Passenger, true)
				LeaveQueue(Passenger, false)
			end	
			
			if QueuedPassengers >= LPS then
				break --too much queueing in one iteration
			end
		end
		
		wait(MicrocycleTime)
	end
end

local function RenderPassengers()
	--make the number of microcycles the current maximum or total queued passengers, whichever is less
	if LPS > #InQueue + #OutQueue then
		MicrocycleCount = #InQueue + #OutQueue
	else
		MicrocycleCount = LPS
	end
	
	MicrocycleTime = CycleTime / MicrocycleCount
	
	for count = 1, MicrocycleCount do
		if #InQueue > 0 then
			CurrentPassenger = InQueue[1]
			--CurrentPassenger.Parent = Config.GetBusLocation(CurrentPassenger.PassengerData.CurrentBus.Value, 'Main')
			CurrentPassenger.Parent = PassengerFolder
			table.remove(InQueue, 1)
		elseif #OutQueue > 0 then
			CurrentPassenger = OutQueue[1]
			CurrentPassenger.Parent = PassengerStore
			table.remove(OutQueue, 1)	
		end
		
		wait(MicrocycleTime)
	end
end

--connect keys
UserInputService.InputBegan:Connect(function(input, processed)
	if processed == false and input.UserInputType == Enum.UserInputType.Keyboard then
		--fire the event
		game.ReplicatedStorage.Keypress:FireServer(input.KeyCode)
	end
end)

--main loop
while wait(CycleTime) do
	if LPS ~= 0 then --if it is, we're dropping frames, so take a break
		if Enabled then
			coroutine.wrap(QueuePassengers)()
			coroutine.wrap(RenderPassengers)()
			
			if DisplayDebug == true then
				DebugGUI.InQueue.Text = 			'InQueue: ' .. tostring(#InQueue)
				DebugGUI.OutQueue.Text = 			'OutQueue: ' .. tostring(#OutQueue)
				DebugGUI.EstimatedFPS.Text = 		'Estimated FPS: ' .. tostring(FPS)
				DebugGUI.LPS.Text = 				'Max ops / cycle: ' .. tostring(LPS)
				DebugGUI.PassengersLoaded.Text = 	'Loaded: ' .. tostring(#PassengerFolder:GetChildren())
				DebugGUI.PassengersUnloaded.Text = 	'Stored: ' .. tostring(#PassengerStore:GetChildren())
			end
		else
			--it's disabled - queue out all passengers
			local ToQueue = PassengerFolder:GetChildren()
			
			if #ToQueue ~= 0 then
				for _, Passenger in ipairs(PassengerFolder:GetChildren()) do
					if table.find(OutQueue, Passenger) == nil then
						JoinQueue(Passenger, false) --any loaded AND unqueued passengers join outqueue
					end
				end
				RenderPassengers() --actually load out the passengers we've just queued
				--note the lack of coroutine means this will actually take 2 x cycle length per cycle
				--realistically though, nobody's gonna care
			elseif #OutQueue ~= 0 then
				RenderPassengers() --we still have a backlog
			end
		end
	end
end

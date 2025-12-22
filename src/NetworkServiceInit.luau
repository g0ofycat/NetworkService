--!strict

local NetworkService = {}

--=======================
-- // VARIABLES
--=======================

-- // Modules that are meant to serve this module
NetworkService.Modules = {
	EventCreator = require("./EventCreator"),
	Events = require("./Events/EventsInit"),
	Config = require("./Config/ConfigInit")
}

-- // Data Compression Modules that are integrated into this module
NetworkService.DataCompression = {
	Base64 = require("./Dependencies/Base64/Base64Init"),
	Bitpacker = require("./Dependencies/Bitpacker/BitpackerInit")
}

-- // References to anything
NetworkService.References = {
	Instances = script.Parent.Instances
}

-- // All services
NetworkService.Services = {
	Players = game:GetService("Players"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	RunService = game:GetService("RunService")
}

-- // Current Run-State of the script
NetworkService.RunState = {
	IS_SERVER = NetworkService.Services.RunService:IsServer(),
	IS_CLIENT = NetworkService.Services.RunService:IsClient()
}

-- // Used if Config.RateLimits.UseRateLimiting is on; Tracks all Remotes and the Players UserId
NetworkService.RateLimitTable = {} :: { [string]: { [number]: { LastCall: number, CallCount: number } } }

-- // Used if Config.RateLimits.UseRateLimiting is on; Tracks all Remotes
NetworkService.GlobalRateLimitTable = {} :: { [string]: { LastCall: number, CallCount: number } }

--=======================
-- // INIT
--=======================

if NetworkService.RunState.IS_SERVER then
	NetworkService.Modules.EventCreator.Init()
end

--=======================
-- // HELPER FUNCTIONS
--=======================

-- CleanupRateLimits(): Cleanups the RateLimit table
-- @param player: The player to cleanup
local function CleanupRateLimits(player: Player): ()
	for eventName, eventTable in NetworkService.RateLimitTable do
		eventTable[player.UserId] = nil
		if next(eventTable) == nil then
			NetworkService.RateLimitTable[eventName] = nil
		end
	end
end

-- tryCompress(): Tries to compress a string
-- @data: The table to compress
-- @return (boolean, string?)
local function tryCompress(data: any): (boolean, string?)
	if not NetworkService.Modules.Config.Main.DataCompression then
		return true, data
	end

	local success, compressed = pcall(function()
		local packed = NetworkService.DataCompression.Bitpacker.Pack(data)

		if NetworkService.Modules.Config.Main.SerializeData then
			return NetworkService.DataCompression.Base64.Encode(packed)
		end

		return packed
	end)

	if not success then
		warn("[NetworkService] Compression failed for data:", data)
		return false, nil
	end

	local rawSize = NetworkService.DataCompression.Bitpacker.GetCurrentSize(data)
	local packedSize = NetworkService.DataCompression.Bitpacker.GetPackedSize(data)

	if NetworkService.Modules.Config.Main.SerializeData then
		packedSize = math.ceil(packedSize / 3) * 4
	end

	if packedSize >= rawSize then
		return true, data
	end

	return true, compressed
end

-- tryDecompress(): Tries to decompress a Buffer String
-- @data: The string to decompress
-- @return (boolean, any?)
local function tryDecompress(data: string): (boolean, any?)
	if not NetworkService.Modules.Config.Main.DataCompression then
		return true, data
	end

	local success, decompressed = pcall(function()
		if NetworkService.Modules.Config.Main.SerializeData then
			local decoded = NetworkService.DataCompression.Base64.Decode(data)
			return NetworkService.DataCompression.Bitpacker.Unpack(decoded)
		end

		return NetworkService.DataCompression.Bitpacker.Unpack(data)
	end)

	if not success then
		warn("[NetworkService] Decompression failed for data:", data)
		return false, nil
	end

	return true, decompressed
end

--=======================
-- // PRIVATE FUNCTIONS
--=======================

-- FireEvents(): A helper function to fire an event
-- @param remoteEvent: The RemoteEvent instance
-- @param data: A table containing the data that you want to compress
-- @param remoteType: "Single" | "All". Only affects: Server -> Client
-- @param targetPlayer: Required only if remoteType is "Single" from the server; ignored on client
local function FireEvents(remoteEvent: RemoteEvent, data: any, remoteType: "Single" | "All", targetPlayer: Player?): ()	
	if NetworkService.RunState.IS_CLIENT then
		local success, err = pcall(function()
			remoteEvent:FireServer(data)
		end)

		if not success then
			warn("[FireEvents] Failed to fire server:", err)
		end
	elseif NetworkService.RunState.IS_SERVER then
		if remoteType == "Single" then
			if targetPlayer then
				local success, err = pcall(function()
					remoteEvent:FireClient(targetPlayer, data)
				end)

				if not success then
					warn("[FireEvents] Failed to fire client:", err)
				end
			else
				warn("[FireEvents] targetPlayer is required when using 'Single' on the server.")
			end
		elseif remoteType == "All" and not targetPlayer then
			local success, err = pcall(function()
				remoteEvent:FireAllClients(data)
			end)

			if not success then
				warn("[FireEvents] Failed to fire all clients:", err)
			end
		else
			warn("[FireEvents] Invalid remoteType -", remoteType)
		end
	end
end

-- FireFunction(): A helper function to invoke a RemoteFunction
-- @param remoteFunction: The RemoteFunction instance
-- @param data: A table or any data you want to pass (will be compressed if applicable)
-- @param remoteType: "Single" | "All". Used only on the server to determine how clients are targeted
-- @param targetPlayer: Required only if remoteType is "Single" from the server; ignored on client
-- @return result: any | { [Player]: any } | nil
local function FireFunction(remoteFunction: RemoteFunction, data: any, remoteType: "Single" | "All", targetPlayer: Player?): any
	local RunService = NetworkService.Services.RunService

	if RunService:IsClient() then
		local success, result = pcall(function()
			return remoteFunction:InvokeServer(data)
		end)

		if not success then
			warn("[FireFunction] Failed to invoke server:", result)
			return nil
		end

		return result
	elseif RunService:IsServer() then
		if remoteType == "Single" then
			if not targetPlayer then
				warn("[FireFunction] targetPlayer is required for 'Single' invocation from server.")
				return nil
			end

			local success, result = pcall(function()
				return remoteFunction:InvokeClient(targetPlayer, data)
			end)

			if not success then
				warn("[FireFunction] Failed to invoke client:", result)
				return nil
			end

			return result
		elseif remoteType == "All" then
			local results = {}

			for _, player in NetworkService.Services.Players:GetPlayers() do
				local success, result = pcall(function()
					return remoteFunction:InvokeClient(player, data)
				end)

				if success then
					results[player] = result
				else
					warn("[FireFunction] Failed to invoke client for", player.Name, ":", result)
					results[player] = nil
				end
			end

			return results
		else
			warn("[FireFunction] Invalid remoteType:", remoteType)
			return nil
		end
	end

	return nil
end

-- isRateLimited(): Returns a boolean based on whether or not the current event is Rate-Limited (Per-Event, Per-Player)
-- @param player: The player
-- @param eventName: The name of the Event
-- @return boolean: Whether or not the current event is Rate-Limited for the player
local function isRateLimited(player: Player, eventName: string): boolean	
	if not NetworkService.Modules.Config.RateLimits.UseRateLimiting then
		return false
	end

	local now = os.clock()
	local debounce = NetworkService.Modules.Config.RateLimits.DebouncePerRemote
	local limit = NetworkService.Modules.Config.RateLimits.LimitPerRemote
	local userId = player.UserId

	NetworkService.RateLimitTable[eventName] = NetworkService.RateLimitTable[eventName] or {}
	local state = NetworkService.RateLimitTable[eventName][userId]

	if not state then
		NetworkService.RateLimitTable[eventName][userId] = { LastCall = now, CallCount = 1 }
		return false
	end

	local elapsed = now - state.LastCall

	if elapsed > debounce then
		state.LastCall = now
		state.CallCount = 1
		return false
	end

	state.CallCount += 1

	if state.CallCount > limit then
		return true
	end

	return false
end

-- isGlobalRateLimited(): Returns a boolean based on whether or not the current event is Rate-Limited (Per-Event)
-- @param eventName: The name of the Event
-- @return boolean: Whether or not the current event is Rate-Limited
local function isGlobalRateLimited(eventName: string): boolean	
	if not NetworkService.Modules.Config.RateLimits.UseGlobalRateLimiting then
		return false
	end

	local now = os.clock()
	local debounce = NetworkService.Modules.Config.RateLimits.GlobalDebouncePerRemote
	local limit = NetworkService.Modules.Config.RateLimits.GlobalLimitPerRemote

	local state = NetworkService.GlobalRateLimitTable[eventName]

	if not state then
		state = { LastCall = now, CallCount = 1 }
		NetworkService.GlobalRateLimitTable[eventName] = state
		return false
	end

	local elapsed = now - state.LastCall

	if elapsed > debounce then
		state.LastCall = now
		state.CallCount = 1
		return false
	end

	state.CallCount += 1

	if state.CallCount > limit then
		return true
	end

	return false
end

--=======================
-- // PUBLIC FUNCTIONS
--=======================

-- FireEvent(): Fires a event based on the valid event name. Having no targetPlayer will trigger FireAllClients when calling this event from Server -> Client
-- @param eventName: The name of the event
-- @param data: A table containing the data that you want to transfer and compress if DataCompression is on
-- @param targetPlayer?: Only needed if you're calling this from Server -> Client; No targetPlayer will trigger :FireAllClients()
function NetworkService.FireEvent(eventName: string, data: any, targetPlayer: Player?): ()
	if NetworkService.Modules.Config.DataLimits.UseDataLimiting then
		local packedSize = NetworkService.DataCompression.Bitpacker.GetPackedSize(data)
		if packedSize > NetworkService.Modules.Config.DataLimits.MaxBytes then
			warn("[DataLimits] Your data exceeded the maximum byte limit. (Bytes: " .. packedSize .. ")")
			return
		end
	end

	if targetPlayer and isRateLimited(targetPlayer, eventName) then
		warn("[RateLimit] Player", targetPlayer.Name, "exceeded rate limit for", eventName)
		return
	end

	if NetworkService.RunState.IS_SERVER and isGlobalRateLimited(eventName) then
		warn("[RateLimit] Server global rate limit exceeded for", eventName)
		return
	end

	local RemoteEvent = NetworkService.References.Instances.RemoteEvents:FindFirstChild(eventName)

	if not RemoteEvent then
		if NetworkService.RunState.IS_CLIENT then
			RemoteEvent = NetworkService.References.Instances.RemoteEvents:WaitForChild(eventName, 10)
			if not RemoteEvent then
				error("[FireEvent] RemoteEvent '" .. eventName .. "' failed to replicate from server")
				return
			end
		else
			error("[FireEvent] RemoteEvent '" .. eventName .. "' does not exist. Add it to ValidEvents in EventsInit.")
			return
		end
	end

	local finalData = data

	if NetworkService.Modules.Config.Main.DataCompression and type(data) == "string" and type(data) == "table" then
		local success, BufferString = tryCompress(data)

		if not success or not BufferString then 
			warn("[FireEvent] Compression failed for event:", eventName)
			return
		end

		finalData = BufferString
	end

	FireEvents(RemoteEvent, finalData, (targetPlayer and "Single" or "All") :: ("Single" | "All"), targetPlayer)
end

-- InvokeFunction(): Fires a Function based on the valid event name. Having no targetPlayer will trigger FireAllClients when calling this event from Server -> Client
-- @param functionName: The name of the event
-- @param data: A table containing the data that you want to transfer and compress if DataCompression is on
-- @param targetPlayer?: Only needed if you're calling this from Server -> Client
-- @return result: any
function NetworkService.InvokeFunction(functionName: string, data: any, targetPlayer: Player?): any
	if NetworkService.Modules.Config.DataLimits.UseDataLimiting then
		local packedSize = NetworkService.DataCompression.Bitpacker.GetPackedSize(data)
		if packedSize > NetworkService.Modules.Config.DataLimits.MaxBytes then
			warn("[DataLimits] Your data exceeded the maximum byte limit. (Bytes: " .. packedSize .. ")")
			return
		end
	end

	if targetPlayer and isRateLimited(targetPlayer, functionName) then
		warn("[RateLimit] Player", targetPlayer.Name, "exceeded rate limit for", functionName)
		return
	end

	if NetworkService.RunState.IS_SERVER and isGlobalRateLimited(functionName) then
		warn("[RateLimit] Server global rate limit exceeded for", functionName)
		return
	end

	local RemoteFunction = NetworkService.References.Instances.RemoteFunctions:FindFirstChild(functionName)

	if not RemoteFunction then
		if NetworkService.RunState.IS_CLIENT then
			RemoteFunction = NetworkService.References.Instances.RemoteFunctions:WaitForChild(functionName, 10)
			if not RemoteFunction then
				error("[InvokeFunction] RemoteFunction '" .. functionName .. "' failed to replicate from server")
				return
			end
		else
			error("[InvokeFunction] RemoteFunction '" .. functionName .. "' does not exist. Add it to ValidFunctions in EventsInit.")
			return
		end
	end

	local finalData = data

	if NetworkService.Modules.Config.Main.DataCompression and type(data) == "string" and type(data) == "table" then
		local success, BufferString = tryCompress(data)

		if not success or not BufferString then
			warn("[InvokeFunction] Compression failed for function:", functionName)
			return
		end

		finalData = BufferString
	end

	return FireFunction(RemoteFunction, finalData, (targetPlayer and "Single" or "All") :: ("Single" | "All"), targetPlayer)
end

-- ListenToEvent(): Creates a listener for a specific event with a callback function. The 'player' callback is nil when Listening on the client
-- @param eventName: The name of the event
-- @param callback: The function to call when the event is received (data, player)
-- @return RBXScriptConnection: The connection object that can be used to disconnect the listener
function NetworkService.ListenToEvent(eventName: string, callback: (data: any, player: Player?) -> ()): RBXScriptConnection?
	local RemoteEventsFolder = NetworkService.References.Instances.RemoteEvents

	local RemoteEvent = RemoteEventsFolder:FindFirstChild(eventName)

	if not RemoteEvent then
		if NetworkService.RunState.IS_CLIENT then
			RemoteEvent = RemoteEventsFolder:WaitForChild(eventName, 10)
			if not RemoteEvent then
				error("[ListenToEvent] RemoteEvent '" .. eventName .. "' failed to replicate from server")
				return
			end
		else
			error("[ListenToEvent] RemoteEvent missing: " .. eventName)
		end
	end

	local connection: RBXScriptConnection

	if NetworkService.RunState.IS_CLIENT then
		connection = RemoteEvent.OnClientEvent:Connect(function(data: any)

			if isGlobalRateLimited(eventName) then
				warn(`[RateLimit] Global rate limit exceeded for '{eventName}'`)
				return
			end

			local finalData = data

			if NetworkService.Modules.Config.Main.DataCompression and type(data) == "string" then
				local success, decompressedData = tryDecompress(data)

				if success then
					finalData = decompressedData
				else
					warn(`[NetworkService] Failed to decompress data for event: {eventName}`)
					return
				end
			end

			local success, result = pcall(function()
				callback(finalData, nil)
			end)

			if not success then
				if string.find(result, "attempt to index nil") and string.find(result, "player") then
					warn(`[NetworkService] Client-side callback for event '{eventName}' tried to access player parameter.`)
				else
					warn(`[NetworkService] Error in callback for event '{eventName}':`, result)
				end
			end
		end)
	elseif NetworkService.RunState.IS_SERVER then
		connection = RemoteEvent.OnServerEvent:Connect(function(player: Player, data: any)
			if player and isRateLimited(player, eventName) then
				warn("[RateLimit] Player", player.Name, "exceeded rate limit for", eventName)
				return
			end

			if isGlobalRateLimited(eventName) then
				warn("[RateLimit] Global rate limit exceeded for", eventName)
				return
			end

			local finalData = data

			local playerName = player and player.Name or "UnknownPlayer"

			if NetworkService.Modules.Config.Main.DataCompression and type(data) == "string" then
				local success, decompressedData = tryDecompress(data)

				if success then
					finalData = decompressedData
				else
					warn("[NetworkService] Failed to decompress data from player:", playerName, "for event:", eventName)
					return
				end
			end

			local success, result = pcall(function()
				callback(finalData, player)
			end)

			if not success then
				warn("[NetworkService] Error in server callback for event '" .. eventName .. "' from player " .. playerName .. ":", result)
			end
		end)
	else
		error("[NetworkService] Unable to determine execution context (neither client nor server).")
	end

	return connection
end

-- ListenToFunction(): Creates a listener for a specific RemoteFunction with a callback
-- @param functionName: The name of the function
-- @param callback: The function to call when the remote function is invoked (data, player)
-- @return RemoteFunction: The RemoteFunction instance (you can call :Destroy or remove .OnXInvoke to disconnect)
function NetworkService.ListenToFunction(functionName: string, callback: (data: any, player: Player?) -> any): RemoteFunction?
	local RemoteFunctionsFolder = NetworkService.References.Instances.RemoteFunctions

	local RemoteFunction = RemoteFunctionsFolder:FindFirstChild(functionName)

	if not RemoteFunction then
		if NetworkService.RunState.IS_CLIENT then
			RemoteFunction = RemoteFunctionsFolder:WaitForChild(functionName, 10)
			if not RemoteFunction then
				error("[ListenToFunction] RemoteFunction '" .. functionName .. "' failed to replicate from server")
				return
			end
		else
			error("[ListenToFunction] RemoteFunction missing: " .. functionName)
		end
	end

	if NetworkService.RunState.IS_SERVER then
		RemoteFunction.OnServerInvoke = function(player: Player, data: any)
			if isRateLimited(player, functionName) then
				warn("[RateLimit] Player", player.Name, "exceeded rate limit for", functionName)
				return
			end

			if isGlobalRateLimited(functionName) then
				warn("[RateLimit] Global rate limit exceeded for", functionName)
				return
			end

			local finalData = data

			if NetworkService.Modules.Config.Main.DataCompression and type(data) == "string" then
				local success, decompressed = tryDecompress(data)

				if success then
					finalData = decompressed
				else
					warn("[NetworkService] Failed to decompress data from player", player.Name, "for function:", functionName)
					return
				end
			end

			local success, result = pcall(function()
				return callback(finalData, player)
			end)

			if not success then
				warn("[NetworkService] Error in server callback for function '" .. functionName .. "' from player " .. player.Name .. ":", result)
				return nil
			end

			return result
		end
	elseif NetworkService.RunState.IS_CLIENT then
		RemoteFunction.OnClientInvoke = function(data: any)
			if isGlobalRateLimited(functionName) then
				warn("[RateLimit] Global rate limit exceeded for", functionName)
				return
			end

			local finalData = data

			if NetworkService.Modules.Config.Main.DataCompression and type(data) == "string" then
				local success, decompressed = tryDecompress(data)

				if success then
					finalData = decompressed
				else
					warn("[NetworkService] Failed to decompress data for function:", functionName)
					return
				end
			end

			local success, result = pcall(function()
				return callback(finalData, nil)
			end)

			if not success then
				if string.find(result, "attempt to index nil") and string.find(result, "player") then
					warn("[NetworkService] Client-side callback for function '" .. functionName .. "' tried to access player parameter.")
					warn("[NetworkService] Player parameter is only available on the server side.")
				else
					warn("[NetworkService] Error in client callback for function '" .. functionName .. "':", result)
				end
				return nil
			end

			return result
		end
	else
		error("[NetworkService] Unable to determine execution context (neither client nor server).")
	end

	return RemoteFunction
end

--=======================
-- // CLEANUP
--=======================

game.Players.PlayerRemoving:Connect(function(player)
	CleanupRateLimits(player)
end)

return NetworkService
--!strict

local EventCreator = {}

--======================
-- // IMPORTS
--======================

local EventsInit = require("./Events/EventsInit")

--======================
-- // REFERENCES
--======================

local InstancesFolder = script.Parent.Instances

local RemoteEventsFolder = InstancesFolder.RemoteEvents

local RemoteFunctionsFolder = InstancesFolder.RemoteFunctions

--=======================
-- // PUBLIC API
--=======================

-- Init(): Initializes the RemoteEvent and RemoteFunction folders
function EventCreator.Init(): ()
	for _, eventName in EventsInit.ValidEvents do
		local existingEvent = RemoteEventsFolder:FindFirstChild(eventName)

		if not existingEvent then
			local remoteEvent = Instance.new("RemoteEvent")

			remoteEvent.Name = eventName
			remoteEvent.Parent = RemoteEventsFolder
		end
	end

	for _, functionName in EventsInit.ValidFunctions do
		local existingFunction = RemoteFunctionsFolder:FindFirstChild(functionName)

		if not existingFunction then
			local remoteFunction = Instance.new("RemoteFunction")

			remoteFunction.Name = functionName
			remoteFunction.Parent = RemoteFunctionsFolder
		end
	end
end

return EventCreator
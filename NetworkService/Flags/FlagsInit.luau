--!strict

--=======================
-- // IMPORTS & MAIN
--=======================

local Types = require(script.Parent.Types)

local Flags = {} :: Types.Flags

--=======================
-- // PUBLIC TABLES
--=======================

Flags.ValidEvents = {
	["TestEvent"] = true
}

Flags.ValidFunctions = {
	["TestFunction"] = true
}

return Flags
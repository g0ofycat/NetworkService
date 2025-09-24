--!strict

--=======================
-- // TYPES
--=======================

export type Flags = {
	ValidEvents: ValidEvents,
	ValidFunctions: ValidFunctions
}

export type ValidEvents = { [string]: boolean }

export type ValidFunctions = { [string]: boolean }

return nil
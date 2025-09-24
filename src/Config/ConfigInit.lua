--!strict

--=======================
-- // IMPORTS & MAIN
--=======================

local Types = require(script.Parent.Types)

local Config = {} :: Types.Config

--=======================
-- // PUBLIC TABLES
--=======================

Config.Main = {
	DataCompression = false, -- // true: Turns data compression on, reducing the bandwidth on both the server and the client. Sometimes, the raw data may be bigger than the compressed data. In that case, it will send the raw data instead
	SerializeData = false, -- // true: Serializes data if DataCompression is on so not invalid UTF-8 gets transmitted. Although Remotes handle serialization, there (may) be a rare chance that it fails. Turning this on makes data have a few extra bytes since this uses Base64
	SafeFlags = false -- // true: Turns on safe flags. When firing functions or events, their names must be in the Flags module
}

Config.RateLimits = {
	UseRateLimiting = false, -- // true: Throttle how often a player can fire remotes (No Rate-Limiting for OnClientEvent since client can easily bypass Rate-Limiting)
	UseGlobalRateLimiting = false, -- // true: Throttle how often a remote can be fired. (Affects all communications)
	LimitPerRemote = 100, -- // number: How many times per second a Remote can be fired before it gets rejected (Per-Remote, Per-Player)
	DebouncePerRemote = 1, -- // number: The cooldown before LimitPerRemote gets reset (Per-Remote, Per-Player)
	GlobalLimitPerRemote = 50, -- // number: How many times per second a Remote can be fired before it gets rejected (Per-Remote)
	GlobalDebouncePerRemote = 1 -- // number: The cooldown before GlobalLimitPerRemote gets reset (Per-Remote)
}

Config.DataLimits = {
	UseDataLimiting = false, -- // true: The amount of data will now be limited
	MaxBytes = 4096 -- // number: The maximum amount of bytes the data can be before getting rejected
}

table.freeze(Config)

return Config
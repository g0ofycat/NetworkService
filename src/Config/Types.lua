--!strict

--=======================
-- // TYPES
--=======================

export type Config = {
	Main: MainConfig,
	RateLimits: RateLimitConfig,
	DataLimits: DataLimitConfig
}

export type MainConfig = {
	DataCompression: boolean,
	SerializeData: boolean,
	SafeFlags: boolean
}

export type RateLimitConfig = {
	UseRateLimiting: boolean,
	UseGlobalRateLimiting: boolean,
	LimitPerRemote: number,
	DebouncePerRemote: number,
	GlobalLimitPerRemote: number,
	GlobalDebouncePerRemote: number
}

export type DataLimitConfig = {
	UseDataLimiting: boolean,
	MaxBytes: number
}

return nil
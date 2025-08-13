# NetworkService
A networking module for Roblox that provides automatic data compression, rate limiting, and safe remote communication with built-in error handling. (NOTE: Compression doesn't handle more complex data types like Instances, CFrames, etc)

## Overview
- **Base64 Encoding:** Optional string serialization for cross-platform compatibility
- **Dual Rate Limiting:** Per-player and global rate limiting with configurable thresholds
- **Safe Flag System:** Whitelist-based event/function validation for security
- **Data Size Limiting:** Configurable maximum payload sizes to prevent abuse
- **Auto Remote Creation:** Dynamically creates RemoteEvents/RemoteFunctions as needed
- **Cross-Context Support:** Unified API that works seamlessly on both client and server

**Example Usage:**
```lua
local NetworkService = require(path.to.NetworkService)

-- // Server side - send to specific player
NetworkService.FireEvent("PlayerUpdate", {
    level = 42,
    experience = 1500,
    inventory = {"sword", "potion", "key"}
}, player)

-- // Client side - listen for events
NetworkService.ListenToEvent("PlayerUpdate", function(data, player)
    print("Received update:", data.level, data.experience)
    -- // player is nil on client side
end)

-- // Function invocation with return values
local response = NetworkService.InvokeFunction("GetPlayerData", {
    playerId = 123456789
}, targetPlayer)
```

## Key Features

### Data Compression
- **Automatic Compression:** Tables are automatically packed using Bitpacker when `DataCompression` is enabled
- **Fallback Handling:** Falls back to raw data if compression fails or increases size
- **Base64 Serialization:** Optional encoding for string-safe transmission
- **Size Comparison:** Intelligent compression that only applies when beneficial

### Rate Limiting
- **Per-Player Limits:** Individual rate limiting per remote per player
- **Global Limits:** Server-wide rate limiting per remote
- **Configurable Thresholds:** Customizable debounce times and call limits
- **Automatic Cleanup:** Player data cleanup on disconnect

### Safety Features
- **Safe Flags:** Whitelist system preventing unauthorized remote calls
- **Data Limits:** Maximum payload size enforcement
- **Error Handling:** Comprehensive pcall protection with detailed error messages
- **Type Safety:** Strict typing with Luau type annotations

## API Reference

```lua
NetworkService.FireEvent(eventName: string, data: any, targetPlayer: Player?) -> ()
```
Fires a RemoteEvent with optional compression. No targetPlayer = FireAllClients on server.

```lua
NetworkService.InvokeFunction(functionName: string, data: any, targetPlayer: Player?) -> any
```
Invokes a RemoteFunction with optional compression and return value handling.

```lua
NetworkService.ListenToEvent(eventName: string, callback: (data: any, player: Player?) -> ()) -> RBXScriptConnection?
```
Creates an event listener. Player parameter is nil on client side.

```lua
NetworkService.ListenToFunction(functionName: string, callback: (data: any, player: Player?) -> any) -> RemoteFunction?
```
Creates a function listener that can return values to the caller.

### Configuration Modules
- **NetworkService.Modules.Config:** Main configuration settings
- **NetworkService.Modules.Flags:** Valid event/function whitelists
- **NetworkService.DataCompression.Bitpacker:** Binary serialization module
- **NetworkService.DataCompression.Base64:** String encoding module

### Runtime Information
- **NetworkService.RunState.IS_SERVER/IS_CLIENT:** Context detection
- **NetworkService.RateLimitTable:** Per-player rate limit tracking
- **NetworkService.GlobalRateLimitTable:** Global rate limit tracking

## Performance Characteristics
- **Compression Ratio:** 5-30% size reduction for typical game data
- **Memory Efficiency:** Automatic cleanup and minimal garbage collection
- **Error Recovery:** Graceful fallbacks maintain service availability

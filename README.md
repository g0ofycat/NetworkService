# NetworkService

**NetworkService** is a Roblox module for streamlined **RemoteEvent** and **RemoteFunction** communication between **Server** and **Client**.

It provides built-in **data compression** and **rate limiting**, making remote calls secure and efficient.

Key features:

- Static Creation / Management of `RemoteEvent` and `RemoteFunction`
- Optional bitpacking + Base64 compression
- Per-player and global rate limiting

## How to Use

### Firing an Event

```lua
local NetworkService = require(path.to.NetworkService)

game.Players.PlayerAdded:Wait() -- // Needed for the client side listeners to load

-- // Fire to all clients
NetworkService.FireEvent("ChatMessage", { text = "Hello World!" })

-- // Fire to a single client
NetworkService.FireEvent("PrivateNotice", { text = "Hi!" }, player)
```

### Invoking a Function

```lua
game.Players.PlayerAdded:Wait() -- // Needed for the client side listeners to load

-- // Client -> Server
local result = NetworkService.InvokeFunction("GetData", { id = 123 })

print(result)

-- // Server -> Single Client
local data = NetworkService.InvokeFunction("RequestClientInfo", {}, player)
```

### Listening for Events

```lua
-- // Client side
NetworkService.ListenToEvent("ChatMessage", function(data)
    print("Received:", data.text)
end)

-- // Server side
NetworkService.ListenToEvent("PrivateNotice", function(data, player)
    print(player.Name, "got", data.text)
end)
```

### Listening for Functions

```lua
-- // Server side
NetworkService.ListenToFunction("GetData", function(data, player)
    return { status = "ok", user = player.UserId }
end)

-- // Client side
NetworkService.ListenToFunction("RequestClientInfo", function()
    return { fps = 60 }
end)
```

## API Reference

```lua
export type NetworkService = {
    FireEvent: (eventName: string, data: any, targetPlayer: Player?) -> (),
    InvokeFunction: (functionName: string, data: any, targetPlayer: Player?) -> any,
    ListenToEvent: (eventName: string, callback: (data: any, player: Player?) -> ()) -> RBXScriptConnection?,
    ListenToFunction: (functionName: string, callback: (data: any, player: Player?) -> any) -> RemoteFunction?,

    Modules: {
        Flags: any,
        Config: any
    },

    DataCompression: {
        Base64: any,
        Bitpacker: any
    },

    References: {
        Instances: Folder
    },

    Services: {
        Players: Players,
        ReplicatedStorage: ReplicatedStorage,
        RunService: RunService
    },

    RunState: {
        IS_SERVER: boolean,
        IS_CLIENT: boolean
    },

    RateLimitTable: { [string]: { [number]: { LastCall: number, CallCount: number } } },
    GlobalRateLimitTable: { [string]: { LastCall: number, CallCount: number } }
}
```
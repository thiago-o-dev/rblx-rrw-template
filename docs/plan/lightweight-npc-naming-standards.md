# Lightweight NPC System - Naming Standards & Code Refactoring Plan

## 1. Compliance Mapping against `docs/naming-table.md`

All Luau scripts in `LightweightNpcs/` must be refactored to align with [naming-table.md](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/naming-table.md):

| Category | Current Symbol (Non-Compliant) | Target Symbol (Compliant) | Rule Description |
| :--- | :--- | :--- | :--- |
| **Module Table** | `local lightweightNpcsServerModule = {}` | `local NpcServerManager = {}` | Module tables must be `PascalCase` |
| **Module Table** | `local lightweightNpcsClientModule = {}` | `local NpcClientController = {}` | Module tables must be `PascalCase` |
| **Local Constant** | `local config = { ... }` | `local DEFAULT_CONFIG = { ... }` | Local constants must be `UPPER_SNAKE_CASE` |
| **Type Alias** | `type npcRecordType = { ... }` | `export type NpcRecord = { ... }` | Type aliases must be `PascalCase` |
| **Type Alias** | `type npcRecordInternal = { ... }` | `export type NpcInternal = { ... }` | Type aliases must be `PascalCase` |
| **Type Alias** | `type npcRecordConfiguration` | `export type NpcConfig = { ... }` | Type aliases must be `PascalCase` |
| **Type Alias** | `type playerRecordType = { ... }` | `export type PlayerRecord = { ... }` | Type aliases must be `PascalCase` |
| **Module Method** | `npcRecord:PlayAnimation(...)` | `npcRecord:playAnimation(...)` | Object/Instance methods (`:`) must be `camelCase` |
| **Module Method** | `npcRecord:AddClientEvent(...)` | `npcRecord:addClientEvent(...)` | Object/Instance methods (`:`) must be `camelCase` |
| **Module Method** | `npcRecord:SetPlayerVisibleFlag(...)` | `npcRecord:setPlayerVisibleFlag(...)` | Object/Instance methods (`:`) must be `camelCase` |
| **Module Method** | `npcRecord:GetPlayerVisibleFlag(...)` | `npcRecord:getPlayerVisibleFlag(...)` | Object/Instance methods (`:`) must be `camelCase` |
| **Module Method** | `npcRecord:ForceReplicate(...)` | `npcRecord:forceReplicate(...)` | Object/Instance methods (`:`) must be `camelCase` |
| **Module Method** | `npcRecord:Move(...)` / `Jump(...)` | `npcRecord:move(...)` / `jump(...)` | Object/Instance methods (`:`) must be `camelCase` |
| **Static Function**| `MathUtils:AngleAbs(...)` | `MathUtils.angleAbs(...)` | Static functions without `self` must use `.` and `camelCase` |
| **Static Function**| `MathUtils:FlatVec(...)` | `MathUtils.flatVec(...)` | Static functions without `self` must use `.` and `camelCase` |
| **Static Function**| `MathUtils:GroundAccelerate(...)` | `MathUtils.groundAccelerate(...)` | Static functions without `self` must use `.` and `camelCase` |

---

## 2. Refactored Type Definitions Schema

```lua
-- src/shared/Types/NpcTypes.luau
local Signal = require(game.ReplicatedStorage.Shared.Core.Signal)

export type NpcState = "Idle" | "Walking" | "Falling" | "Dead"

export type NpcInternal = {
    timeOfNextReplicate: number,
    forceReplicate: boolean,
    forceThink: boolean,
    timeOfNextThink: number,
    timeOfLastThink: number,
    timeOfNextCullingCheck: number,
    deleteFlag: boolean,
    pendingAnimationChanges: { [number]: number },
    playerReplicationVisible: { [Player]: boolean },
    playerVisibleFlag: { [Player]: boolean },
}

export type NpcConfig = {
    maximumStepHeight: number,
    maximumSlopeAngle: number,
    templateInstance: Model,
    replicationHzRate: number,
    thinkHzRate: number,
    motionSize: Vector3,
    animations: { [string]: any },
    walkSpeed: number,
    walkAccel: number,
    turnSpeed: number,
    maxHitPoints: number,
    gravity: Vector3,
    jumpPower: number,
}

export type NpcRecord = {
    npcId: number,
    instance: Model?,
    hitBox: Part,
    internal: NpcInternal,
    configuration: NpcConfig,
    npcState: NpcState,
    hitPoints: number,
    position: Vector3,
    angle: number,
    targetAngle: number,
    velocity: Vector3,
    isOnGround: boolean,
    motionVector: Vector3,
    jump: boolean,

    playAnimation: (self: NpcRecord, animName: string, forceRestart: boolean, channel: number, speedMultiplier: number) -> (),
    addClientEvent: (self: NpcRecord, event: any) -> (),
    setPlayerVisibleFlag: (self: NpcRecord, player: Player, visible: boolean) -> (),
    getPlayerVisibleFlag: (self: NpcRecord, player: Player) -> boolean,
    forceReplicate: (self: NpcRecord) -> (),
    move: (self: NpcRecord, motionVector: Vector3) -> (),
    jump: (self: NpcRecord) -> (),

    onThink: Signal.Signal,
    onFellOffMap: Signal.Signal,
    onDeath: Signal.Signal,
    onCleanup: Signal.Signal,
    onBumpIntoWall: Signal.Signal,
    onCrashland: Signal.Signal,
    onCullCheck: Signal.Signal,

    data: { [string]: any },
}
```

---
*Related Documents*:
- [Architecture Plan](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/plan/lightweight-npc-architecture-plan.md)
- [Bug Analysis](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/plan/lightweight-npc-bugs-analysis.md)
- [Networking & Performance Plan](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/plan/lightweight-npc-networking-performance.md)

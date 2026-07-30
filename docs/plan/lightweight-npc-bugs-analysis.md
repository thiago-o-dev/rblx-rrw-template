# Lightweight NPC System - Bugs, Edge Cases & Defect Analysis

## 1. Overview
This document contains a comprehensive breakdown of all critical bugs, memory leaks, synchronization issues, and edge cases discovered during the deep analysis of `LightweightNpcs/`.

---

## 2. Detailed Bug Catalog

### 1. Animation Broadcast Loop Clearing Bug (Critical Network Defect)
- **Source File**: `LightweightNpcs/server/Code/LightweightNpcsServerModule.luau` (lines 549–576)
- **Code Snippet**:
  ```lua
  for _, playerRecord in self.playerRecords do
      local count = 0
      local player = playerRecord.player
      for npcId, npcRecord in self.npcRecords do
          if npcRecord.internal.playerVisibleFlag[player] == true then
              for channel, animIndex in npcRecord.internal.pendingAnimationChanges do
                  -- Pack animation into buffer
              end
              npcRecord.internal.pendingAnimationChanges = {} -- BUG: Clears for ALL players on iteration #1!
          end
      end
  end
  ```
- **Root Cause**: `pendingAnimationChanges` is emptied inside the player loop during the processing of the first player.
- **Consequence**: When multiple players are connected to the server, only the first player in `self.playerRecords` receives animation change events. All other players fail to receive animation updates.
- **Remediation**: Defer clearing `pendingAnimationChanges` until after packets have been constructed for all connected players, or maintain per-player pending animation queues.

---

### 2. Visibility Flag Evaluation Default Mismatch
- **Source File**: `LightweightNpcs/server/Code/LightweightNpcsServerModule.luau` & `NpcTypes.luau`
- **Code Snippet**:
  ```lua
  -- In NpcTypes.luau / module functions:
  local function GetPlayerVisibleFlag(self: NpcTypes.npcRecordType, player: Player): boolean
      return self.internal.playerVisibleFlag[player] or true
  end

  -- In Heartbeat loop:
  if npcRecord.internal.playerVisibleFlag[player] == true then -- BUG!
  ```
- **Root Cause**: The API specifies that uninitialized player visibility flags (`nil`) mean visible by default. However, the replication loop directly checks `== true`. In Lua, `nil == true` evaluates to `false`.
- **Consequence**: Newly spawned NPCs or joining players never replicate positions or animations unless `SetPlayerVisibleFlag` is explicitly called for every player-NPC pair.
- **Remediation**: Use `npcRecord:getPlayerVisibleFlag(player)` or initialize `playerVisibleFlag[player] = true` on `PlayerAdded`.

---

### 3. Player Disconnect Memory Leak & Rejoin Crash
- **Source File**: `LightweightNpcs/server/Code/LightweightNpcsServerModule.luau` (lines 77–117)
- **Code Snippet**:
  ```lua
  local function PlayerConnected(player: Player)
      assert(lightweightNpcsServerModule.playerRecords[player] == nil)
      ...
  end

  local function PlayerDisconnected(player: Player)
      local playerRecord = lightweightNpcsServerModule.playerRecords[player]
      if playerRecord then
          playerRecord.ready = false
          -- Missing: lightweightNpcsServerModule.playerRecords[player] = nil
      end
  end
  ```
- **Root Cause**: `playerRecords[player]` is retained when a player disconnects.
- **Consequence**: Memory leak on player leave, and `PlayerConnected` throws an assertion error when the same player rejoins the server.
- **Remediation**: Cleanly set `lightweightNpcsServerModule.playerRecords[player] = nil` inside `PlayerDisconnected`.

---

### 4. Deprecated Engine Time API (`tick()`)
- **Source File**: `LightweightNpcsServerModule.luau`, `LightweightNpcsClientModule.luau`
- **Root Cause**: Usage of `tick()` for server-client clock offset and frame deltas.
- **Consequence**: `tick()` is deprecated in modern Luau. It relies on device local time which suffers from clock drift between server and client.
- **Remediation**: Replace clock calculations with `workspace:GetServerTimeNow()` for networked timestamps and `os.clock()` for local frame delta benchmarking.

---

### 5. Shared `RaycastParams` Object Mutation Risk
- **Source File**: `LightweightNpcs/server/Code/NpcMover.luau` (lines 12–14)
- **Root Cause**: `castParams` is declared as a single file-level local variable and reused across all `Blockcast` calls.
- **Consequence**: Modifying `castParams` parameters dynamically for specific NPC types or collision groups will mutate physics queries globally for all NPCs across concurrent simulation ticks.
- **Remediation**: Instantiate collision parameters per NPC configuration or pass explicit `RaycastParams` parameters into movement sweeps.

---
*Related Documents*:
- [Architecture Plan](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/plan/lightweight-npc-architecture-plan.md)
- [Naming & Coding Standards Plan](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/plan/lightweight-npc-naming-standards.md)
- [Networking & Performance Plan](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/plan/lightweight-npc-networking-performance.md)

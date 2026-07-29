# This is the naming table in accordance to roblox published code guidelines

| Declaration                | Naming                                  | Example                                   |
| -------------------------- | --------------------------------------- | ----------------------------------------- |
| Local variable             | `camelCase`                             | `player`, `health`, `inventory`           |
| Local constant             | `UPPER_SNAKE_CASE`                      | `MAX_SPEED`, `DEFAULT_DAMAGE`             |
| Module table               | `PascalCase`                            | `Inventory`, `Weapon`, `PlayerController` |
| Local helper function      | `camelCase`                             | `calculateDamage()`, `getTarget()`        |
| Module function (`.`)      | `camelCase`                             | `Inventory.load()`, `Math.round()`        |
| Module method (`:` / self) | `camelCase`                             | `weapon:reload()`, `player:takeDamage()`  |
| Constructor                | `new()`                                 | `Weapon.new()`, `Player.new()`            |
| Metatable field            | `__index`, `__tostring`, etc.           | `Weapon.__index = Weapon`                 |
| Type alias                 | `PascalCase`                            | `type PlayerData = {}`                    |
| Generic type               | `PascalCase` (single letter if generic) | `type Signal<T>`                          |
| ModuleScript name          | `PascalCase`                            | `Inventory`, `PlayerService`              |
| File/Script name           | `PascalCase`                            | `RoundManager`, `NPCController`           |

Example:

```lua
local Players = game:GetService("Players")

local Weapon = {}
Weapon.__index = Weapon

local DEFAULT_DAMAGE = 25

local function calculateDamage(baseDamage, multiplier)
    return baseDamage * multiplier
end

function Weapon.new()
    local self = setmetatable({}, Weapon)
    return self
end

function Weapon:reload()
    -- self method
end

function Weapon.createDefault()
    -- static module function
end

return Weapon
```

This is essentially all the declaration-level cases Luau has. Things like `Players`, `RunService`, `inventory`, `weapon`, etc. are all just **local variables**—their meaning doesn't affect the casing. The only distinctions that actually matter are whether something is a local, constant, module table, static function, method (`:`), constructor, or type.

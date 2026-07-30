local module = {}

local NpcAnimationTypes = require(game.ReplicatedFirst.LightweightNpcsClient.Code.NpcAnimationTypes)

function module:GetDefaultAnimations(): NpcAnimationTypes.FinalAnimTable
	--Extra fields supported:
	--speed (defaults to 1) - scales up the animation
	--characterWalkSpeed - whatever walk speed animation is tuned for in studs per second.

	local animNames: NpcAnimationTypes.SourceAnimTable = {
		["idle"] = {
			{ id = "http://www.roblox.com/asset/?id=507766666", weight = 1 },
			{ id = "http://www.roblox.com/asset/?id=507766951", weight = 1 },
			{ id = "http://www.roblox.com/asset/?id=507766388", weight = 9 },
		},
		["walk"] = {
			{ id = "http://www.roblox.com/asset/?id=507777826", weight = 10, characterWalkSpeed = 8 },
		},
		["run"] = {
			{ id = "http://www.roblox.com/asset/?id=507767714", weight = 10, characterWalkSpeed = 16 },
		},

		["jump"] = {
			{ id = "http://www.roblox.com/asset/?id=507765000", weight = 10 },
		},
		["fall"] = {
			{ id = "http://www.roblox.com/asset/?id=507767968", weight = 10 },
		},
	}

	return NpcAnimationTypes:BuildFinalAnimationTable(animNames)
end

return module

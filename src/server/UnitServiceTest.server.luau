local ServerScriptService = game:GetService("ServerScriptService")

local UnitService = require(ServerScriptService.Server.Game.Unit.UnitService)

local maxNpcs = 30

local npcCullRadius = 500

local npcs = {}

for j = 1, maxNpcs do
	local box = 50 + j
	local unitId =
		UnitService.createUnit("Player", CFrame.new(Vector3.new(math.random(-box, box), 10, math.random(-box, box))))

	print(unitId)
end

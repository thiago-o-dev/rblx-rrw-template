--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Net_UnitServer = require(ServerScriptService.Server.Network.Generated.Net_UnitServer)
local UnitTypes = require(game:GetService("ReplicatedStorage").Shared.Types.UnitTypes)

local UnitNetworkServer = {}

function UnitNetworkServer.sendInitialState(player: Player, unit: UnitTypes.UnitRecord)
	Net_UnitServer.InitialUnitState.fire(player, {
		unitId = unit.unitId,
		templateModel = unit.templateModel,
		replicationHz = unit.config.replicationHz,
		position = vector.create(unit.position.X, unit.position.Y, unit.position.Z),
		angle = unit.facingAngle,
	})
end

function UnitNetworkServer.sendDespawn(unitId: number)
	Net_UnitServer.UnitDespawn.fireAll({
		unitId = unitId,
	})
end

function UnitNetworkServer.broadcastPositionBatch(
	units: { [number]: UnitTypes.UnitRecord },
	players: { [Player]: UnitTypes.PlayerRecord },
	serverTime: number
)
	for player, playerRecord in players do
		if not playerRecord.isReady then
			continue
		end

		local transformList = {}
		for _, unit in units do
			-- Check spatial visibility flag (defaults to true if nil)
			local isVisible = unit.internal.playerVisibleMap[player]
			if isVisible == nil or isVisible == true then
				if serverTime >= unit.internal.timeOfNextReplicate or unit.internal.forceReplicate then
					table.insert(transformList, {
						unitId = unit.unitId,
						position = vector.create(unit.position.X, unit.position.Y, unit.position.Z),
						angle = unit.facingAngle,
					})
				end
			end
		end

		if #transformList > 0 then
			Net_UnitServer.UnitPositionBatch.fire(player, {
				serverTime = serverTime,
				transforms = transformList,
			})
		end
	end

	-- Reset forceReplicate flags after broadcasting to all players
	for _, unit in units do
		unit.internal.forceReplicate = false
	end
end

function UnitNetworkServer.broadcastAnimationBatch(
	units: { [number]: UnitTypes.UnitRecord },
	players: { [Player]: UnitTypes.PlayerRecord },
	serverTime: number
)
	for player, playerRecord in players do
		if not playerRecord.isReady then
			continue
		end

		local animList = {}
		for _, unit in units do
			local isVisible = unit.internal.playerVisibleMap[player]
			if isVisible == nil or isVisible == true then
				for channel, animIndex in unit.internal.pendingAnimations do
					table.insert(animList, {
						unitId = unit.unitId,
						channel = channel,
						animIndex = animIndex,
					})
				end
			end
		end

		if #animList > 0 then
			Net_UnitServer.UnitAnimationBatch.fire(player, {
				serverTime = serverTime,
				animations = animList,
			})
		end
	end

	-- Defer clearing pending animations until ALL player packets are compiled
	for _, unit in units do
		table.clear(unit.internal.pendingAnimations)
	end
end

return UnitNetworkServer

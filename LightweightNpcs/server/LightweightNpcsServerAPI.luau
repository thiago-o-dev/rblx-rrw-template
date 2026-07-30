local module = {}

local defaultAnims = require(script.Parent.Code.DefaultAnims)
local lightweightNpcsServerModule = require(script.Parent.Code.LightweightNpcsServerModule)

type customNpcsServerAPIType = {
	SpawnNPC: (self: customNpcsServerAPIType, template: Model, position: Vector3, angleRad: number) -> (),
}

function module:CreateConfig()
	return {
		animations = defaultAnims:GetDefaultAnimations(),
		hitBoxSize = Vector3.new(3, 6, 3),
		motionSize = Vector3.new(3, 6, 3),
		collisionGroup = "Default",
		canCollide = true,
		groundTolerance = 0.5,
		maximumStepHeight = 3,
		replicationHzRate = 10, -- This is complicated. Higher values are more responsive for motion, and cost more bandwidth
		thinkHzRate = 10, --How frequently this NPC runs its simulation
		maxHitPoints = 100,
		walkSpeed = 14, --Same as roblox
		walkAccel = 20, --Roblox is really high, like 20. 3-4 is much more natural looking
		turnSpeed = math.rad(270), --In radians per second
		gravity = Vector3.new(0, -game.Workspace.Gravity, 0),
		jumpPower = 60,
	}
end

function module:SpawnNpc(template: Model, configuration: any, position: Vector3, angleRad: number)
	if configuration.thinkHzRate < configuration.replicationHzRate then
		warn("Setting your thinkHzRate lower than your replication rate will cause stuttering")
	end

	local npcRecord = lightweightNpcsServerModule:CreateNpc(template, configuration, position, angleRad)
	return npcRecord
end

function module:GetNpcByHitbox(hitbox: BasePart)
	return lightweightNpcsServerModule:GetNpcByHitBox(hitbox)
end

return module

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitTypes = require(script.Parent.Parent.Types.UnitTypes)

-- Assumes folder rigs exists
local DEFAULT_RIGS = ReplicatedStorage.Assets.Rigs

local UnitDefinitions = {}

local DEFINITIONS: { [string]: UnitTypes.UnitConfig } = {
	Player = {
		unitType = "Player",
		templateModel = DEFAULT_RIGS:WaitForChild("Robert") :: Model,
		thinkHz = 10,
		replicationHz = 10,
		hitboxSize = Vector3.new(3, 6, 3),
		walkSpeed = 16,
		walkAccel = 20,
		turnSpeed = math.rad(360),
		jumpPower = 50,
		gravity = Vector3.new(0, -workspace.Gravity, 0),
		stepHeight = 2.5,
		groundTolerance = 0.5,
		canCollide = true,
		animations = { Idle = 1, Walk = 2, Run = 3 },
	},
	Goalkeeper = {
		unitType = "Goalkeeper",
		templateModel = DEFAULT_RIGS:WaitForChild("Robert") :: Model,
		thinkHz = 15,
		replicationHz = 10,
		hitboxSize = Vector3.new(3, 6, 3),
		walkSpeed = 14,
		walkAccel = 25,
		turnSpeed = math.rad(450),
		jumpPower = 65,
		gravity = Vector3.new(0, -workspace.Gravity, 0),
		stepHeight = 2.5,
		groundTolerance = 0.5,
		canCollide = true,
		animations = { Idle = 1, DiveLeft = 4, DiveRight = 5 },
	},
	Spectator = {
		unitType = "Spectator",
		templateModel = DEFAULT_RIGS:WaitForChild("Bob") :: Model,
		thinkHz = 2,
		replicationHz = 2,
		hitboxSize = Vector3.new(2, 5, 2),
		walkSpeed = 0,
		walkAccel = 0,
		turnSpeed = math.rad(90),
		jumpPower = 0,
		gravity = Vector3.new(0, -workspace.Gravity, 0),
		stepHeight = 1.0,
		groundTolerance = 0.5,
		canCollide = false,
		animations = { Sit = 10, Cheer = 11 },
	},
}

function UnitDefinitions.getDefinition(unitType: string): UnitTypes.UnitConfig?
	return DEFINITIONS[unitType]
end

return UnitDefinitions

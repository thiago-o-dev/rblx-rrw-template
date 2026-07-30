local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LemonSignal = require(ReplicatedStorage.Packages.LemonSignal)

export type UnitId = number

export type UnitState = {
	position: Vector3,
	velocity: Vector3,
	facingAngle: number,
	animationChannelState: { [number]: number },
	-- isOnGround: boolean,
}

-- export type Partial_UnitState = {
-- 	position: Vector3?,
-- 	velocity: Vector3?,
-- 	facingAngle: number?,
-- 	animationChannelState: { [number]: number }?,
-- }

export type UnitConfig = {
	unitType: string,
	templateModel: Model,
	thinkHz: number,
	replicationHz: number,
	hitboxSize: Vector3,
	walkSpeed: number,
	walkAccel: number,
	turnSpeed: number,
	jumpPower: number,
	gravity: Vector3,
	stepHeight: number,
	groundTolerance: number,
	canCollide: boolean,
	animations: { [string]: number },
}

export type UnitInternal = {
	timeOfNextThink: number,
	timeOfNextReplicate: number,
	timeOfNextCullCheck: number,
	forceReplicate: boolean,
	deleteFlag: boolean,
	pendingAnimations: { [number]: number },
	playerVisibleMap: { [Player]: boolean },
}

export type UnitRecord = {
	unitId: UnitId,
	hitBox: Part,
	templateModel: Model,
	config: UnitConfig,
	internal: UnitInternal,
	position: Vector3,
	targetPosition: Vector3,
	facingAngle: number,
	targetAngle: number,
	velocity: Vector3,
	motionVector: Vector3,
	isOnGround: boolean,
	jumpRequested: boolean,
	playingAnimations: { [number]: number },
	data: { [string]: any },
	onThink: LemonSignal.Signal<UnitRecord>,
	onDeath: LemonSignal.Signal<UnitRecord>,
	onCleanup: LemonSignal.Signal<UnitRecord>,
}

export type PlayerRecord = {
	player: Player,
	isReady: boolean,
	visibleUnits: { [UnitId]: boolean },
}

export type ClientUnitRecord = {
	unitId: UnitId,
	model: Model,
	animator: Animator?,
	timeline: any, -- RingBuffer instance
	eventline: { [number]: { timestamp: number, animIndex: number, channel: number } },
	currentCFrame: CFrame,
	isPlaced: boolean,
	isLoaded: boolean,
	replicationHz: number,
	invHz: number,
}

export type TimelineSnapshot = {
	timestamp: number,
	cframe: CFrame,
}

return {}

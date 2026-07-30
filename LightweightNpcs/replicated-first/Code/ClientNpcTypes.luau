local module = {}

local SignalModule = require(game.ReplicatedFirst.LightweightNpcsClient.Utils.Signal)
local NpcAnimationTypes = require(game.ReplicatedFirst.LightweightNpcsClient.Code.NpcAnimationTypes)

export type clientNpcRecordType = {
	npcId: number,
	timeline: { any },
	eventline: { any },
	instance: Model,
	hz: number,
	invHz: number,
	placed: boolean,
	cframe: CFrame,
	animations: { [number]: NpcAnimationTypes.AnimEntry },
	playingAnimations: { [number]: NpcAnimationTypes.AnimEntry? },
	animator: Animator?,
	loaded: boolean,
	onCustomEvent: SignalModule.Signal,
}

return module

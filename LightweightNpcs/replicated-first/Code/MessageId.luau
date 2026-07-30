local MessageId = {
	InitialState = 1,
	Welcome = 2,
	PositionBuffer = 3,
	AnimationBuffer = 4,
	Cleanup = 5,
	CustomClientEvent = 6,
	ConfirmedServerFrame = 7, --Client to server
} :: { [string]: number }

export type MessageId = typeof(MessageId)

return MessageId

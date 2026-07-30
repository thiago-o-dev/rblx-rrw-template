local PositionBits = {
	Teleport = 1,
	Position = 2,
	Angle = 4,
	CompressionOrigin = 8,
} :: { [string]: number }

export type PositionBits = typeof(PositionBits)

return PositionBits

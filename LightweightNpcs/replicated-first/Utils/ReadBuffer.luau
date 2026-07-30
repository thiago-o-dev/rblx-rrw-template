local module: ReadBuffer = {} :: ReadBuffer
module.__index = module

export type ReadBuffer = {
	__index: any,
	offset: number,
	buf: buffer,
	new: (buf: buffer) -> ReadBuffer,
	ResetReadPos: (self: ReadBuffer) -> (),
	ReadI8: (self: ReadBuffer) -> number,
	ReadU8: (self: ReadBuffer) -> number,
	ReadI16: (self: ReadBuffer) -> number,
	ReadU16: (self: ReadBuffer) -> number,
	ReadU32: (self: ReadBuffer) -> number,
	ReadVector3: (self: ReadBuffer) -> Vector3,
	ReadDouble: (self: ReadBuffer) -> number,
	ReadAxisAngle: (self: ReadBuffer) -> (Vector3, number),
	ReadFloat16: (self: ReadBuffer) -> number,
	ReadFloat32: (self: ReadBuffer) -> number,
}

function module.new(buf: buffer)
	local self = setmetatable({
		offset = 0,
		buf = buf,
	}, module)
	return self :: ReadBuffer
end

function module:ResetReadPos()
	self.offset = 0
end

function module:ReadI8()
	local data = buffer.readi8(self.buf, self.offset)
	self.offset += 1
	return data
end

function module:ReadU8()
	local data = buffer.readu8(self.buf, self.offset)
	self.offset += 1
	return data
end

function module:ReadI16()
	local data = buffer.readi16(self.buf, self.offset)
	self.offset += 2
	return data
end

function module:ReadU16()
	local data = buffer.readu16(self.buf, self.offset)
	self.offset += 2
	return data
end

function module:ReadU32()
	local data = buffer.readu32(self.buf, self.offset)
	self.offset += 4
	return data
end

function module:ReadFloat32()
	local data = buffer.readf32(self.buf, self.offset)
	self.offset += 4
	return data
end

function module:ReadVector3()
	local x, y, z
	x = buffer.readf32(self.buf, self.offset)
	self.offset += 4
	y = buffer.readf32(self.buf, self.offset)
	self.offset += 4
	z = buffer.readf32(self.buf, self.offset)
	self.offset += 4
	return Vector3.new(x, y, z)
end

function module:ReadDouble()
	local data = buffer.readf64(self.buf, self.offset)
	self.offset += 8
	return data
end

function module:ReadAxisAngle()
	local scaledX = buffer.readi8(self.buf, self.offset)
	self.offset += 1
	local scaledY = buffer.readi8(self.buf, self.offset)
	self.offset += 1
	local scaledZ = buffer.readi8(self.buf, self.offset)
	self.offset += 1
	local scaledAngle = buffer.readi16(self.buf, self.offset)
	self.offset += 2

	-- Scale the signed bytes back to the original values
	local axis = Vector3.new(scaledX / 127, scaledY / 127, scaledZ / 127)
	local angle = scaledAngle * (math.pi / 32767) -- Scale by pi divided by 127

	return axis, angle
end

function module:ReadFloat16()
	local b0 = buffer.readu8(self.buf, self.offset)
	self.offset += 1
	local b1 = buffer.readu8(self.buf, self.offset)
	self.offset += 1

	local sign = bit32.btest(b0, 128)
	local exponent = bit32.rshift(bit32.band(b0, 127), 2)
	local mantissa = bit32.lshift(bit32.band(b0, 3), 8) + b1

	if exponent == 31 then --2^5-1
		if mantissa ~= 0 then
			return (0 / 0)
		else
			return (sign and -math.huge or math.huge)
		end
	elseif exponent == 0 then
		if mantissa == 0 then
			return 0
		else
			return (sign and -math.ldexp(mantissa / 1024, -14) or math.ldexp(mantissa / 1024, -14))
		end
	end

	mantissa = (mantissa / 1024) + 1

	return (sign and -math.ldexp(mantissa, exponent - 15) or math.ldexp(mantissa, exponent - 15))
end

return module

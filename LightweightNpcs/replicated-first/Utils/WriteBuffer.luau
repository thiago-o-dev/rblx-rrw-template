local module: WriteBuffer = {} :: WriteBuffer
module.__index = module

export type WriteBuffer = {
	__index: any,
	buf: buffer,
	offset: number,
	currentSize: number,
	startSize: number,
	stepSize: number,

	new: (startSize: number) -> WriteBuffer,
	GetBuffer: (self: WriteBuffer) -> buffer,
	CheckSize: (self: WriteBuffer, add: number) -> (),
	WriteI8: (self: WriteBuffer, number) -> (),
	WriteU8: (self: WriteBuffer, number) -> (),
	WriteI16: (self: WriteBuffer, number) -> (),
	WriteU16: (self: WriteBuffer, number) -> (),
	WriteU32: (self: WriteBuffer, number) -> (),
	WriteVector3: (self: WriteBuffer, Vector3) -> (),
	WriteDouble: (self: WriteBuffer, number) -> (),
	WriteAxisAngle: (self: WriteBuffer, Vector3, number) -> (),
	WriteFloat16: (self: WriteBuffer, number) -> (),
	WriteFloat32: (self: WriteBuffer, number) -> (),
}

function module.new(startSize: number)
	if startSize == nil then
		startSize = 0
	else
		startSize = math.max(startSize, 0)
	end

	local self = setmetatable({
		offset = 0,
		currentSize = 0,
		startSize = startSize,
		stepSize = 128,
		buf = nil,
	}, module)
	return self :: WriteBuffer
end

function module:GetBuffer()
	if buffer.len(self.buf) == self.offset then
		return self.buf
	end

	local finalBuffer = buffer.create(self.offset)
	self.currentSize = self.offset

	buffer.copy(finalBuffer, 0, self.buf, 0, self.offset)
	self.buf = finalBuffer
	return finalBuffer
end

function module:CheckSize(add: number)
	local checkSize = self.offset + add
	if self.buf == nil or checkSize > self.currentSize then
		if self.buf == nil then
			self.currentSize = math.max(self.startSize, add)
		else
			self.currentSize += math.max(self.stepSize, add)
		end
		local newBuf = buffer.create(self.currentSize)
		if self.buf then
			buffer.copy(newBuf, 0, self.buf, 0, self.offset)
		end
		self.buf = newBuf
	end
end

function module:WriteI8(byte: number)
	self:CheckSize(1)
	buffer.writei8(self.buf, self.offset, byte)
	self.offset += 1
end

function module:WriteU8(byte: number)
	self:CheckSize(1)
	buffer.writeu8(self.buf, self.offset, byte)
	self.offset += 1
end

function module:WriteI16(u16: number)
	self:CheckSize(2)
	buffer.writei16(self.buf, self.offset, u16)
	self.offset += 2
end

function module:WriteU16(u16: number)
	self:CheckSize(2)
	buffer.writeu16(self.buf, self.offset, u16)
	self.offset += 2
end

function module:WriteU32(u32: number)
	self:CheckSize(4)
	buffer.writeu32(self.buf, self.offset, u32)
	self.offset += 4
end

function module:WriteFloat32(n)
	self:CheckSize(4)
	buffer.writef32(self.buf, self.offset, n)
	self.offset += 4
end

function module:WriteVector3(vec: Vector3)
	self:CheckSize(12)
	buffer.writef32(self.buf, self.offset, vec.X)
	self.offset += 4
	buffer.writef32(self.buf, self.offset, vec.Y)
	self.offset += 4
	buffer.writef32(self.buf, self.offset, vec.Z)
	self.offset += 4
end

function module:WriteDouble(n)
	self:CheckSize(8)
	buffer.writef64(self.buf, self.offset, n)
	self.offset += 8
end

function module:WriteAxisAngle(axis: Vector3, angle: number)
	self:CheckSize(5)
	-- Scale the values to fit within the range of signed bytes (-128 to 127)
	local scaledX = math.floor(axis.X * 127)
	local scaledY = math.floor(axis.Y * 127)
	local scaledZ = math.floor(axis.Z * 127)
	local scaledAngle = math.floor(angle * (32767 / math.pi)) -- Scale by 127 divided by pi

	buffer.writei8(self.buf, self.offset, scaledX)
	self.offset += 1
	buffer.writei8(self.buf, self.offset, scaledY)
	self.offset += 1
	buffer.writei8(self.buf, self.offset, scaledZ)
	self.offset += 1
	buffer.writei16(self.buf, self.offset, scaledAngle)
	self.offset += 2
end

function module:WriteFloat16(value: number)
	self:CheckSize(2)
	local sign = value < 0
	value = math.abs(value)

	local mantissa, exponent = math.frexp(value)

	if value == math.huge then
		if sign then
			buffer.writeu8(self.buf, self.offset, 252) -- 11111100
			self.offset += 1
		else
			buffer.writeu8(self.buf, self.offset, 124) -- 01111100
			self.offset += 1
		end
		buffer.writeu8(self.buf, self.offset, 0) -- 00000000
		self.offset += 1
		return
	elseif value ~= value or value == 0 then
		buffer.writeu8(self.buf, self.offset, 0)
		self.offset += 1
		buffer.writeu8(self.buf, self.offset, 0)
		self.offset += 1
		return
	elseif exponent + 15 <= 1 then -- Bias for halfs is 15
		mantissa = math.floor(mantissa * 1024 + 0.5)
		if sign then
			buffer.writeu8(self.buf, self.offset, (128 + bit32.rshift(mantissa, 8))) -- Sign bit, 5 empty bits, 2 from mantissa
			self.offset += 1
		else
			buffer.writeu8(self.buf, self.offset, (bit32.rshift(mantissa, 8)))
			self.offset += 1
		end
		buffer.writeu8(self.buf, self.offset, bit32.band(mantissa, 255)) -- Get last 8 bits from mantissa
		self.offset += 1
		return
	end

	mantissa = math.floor((mantissa - 0.5) * 2048 + 0.5)

	-- The bias for halfs is 15, 15-1 is 14
	if sign then
		buffer.writeu8(self.buf, self.offset, (128 + bit32.lshift(exponent + 14, 2) + bit32.rshift(mantissa, 8)))
		self.offset += 1
	else
		buffer.writeu8(self.buf, self.offset, (bit32.lshift(exponent + 14, 2) + bit32.rshift(mantissa, 8)))
		self.offset += 1
	end
	buffer.writeu8(self.buf, self.offset, bit32.band(mantissa, 255))
	self.offset += 1
end

return module

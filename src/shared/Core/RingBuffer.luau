--!strict
local RingBuffer = {}
RingBuffer.__index = RingBuffer

export type RingBuffer<T> = {
	data: { T },
	capacity: number,
	head: number,
	tail: number,
	count: number,
	push: (self: RingBuffer<T>, item: T) -> (),
	pop: (self: RingBuffer<T>) -> T?,
	get: (self: RingBuffer<T>, index: number) -> T?,
	clear: (self: RingBuffer<T>) -> (),
}

function RingBuffer.new<T>(capacity: number): RingBuffer<T>
	local self = setmetatable({
		data = table.create(capacity),
		capacity = capacity,
		head = 1,
		tail = 1,
		count = 0,
	}, RingBuffer)
	return (self :: any) :: RingBuffer<T>
end

function RingBuffer.push<T>(self: RingBuffer<T>, item: any)
	self.data[self.tail] = item
	self.tail = (self.tail % self.capacity) + 1
	if self.count < self.capacity then
		self.count += 1
	else
		self.head = (self.head % self.capacity) + 1 -- Overwrite oldest
	end
end

function RingBuffer.pop<T>(self: RingBuffer<T>): any?
	if self.count == 0 then
		return nil
	end
	local item = self.data[self.head]
	self.data[self.head] = nil
	self.head = (self.head % self.capacity) + 1
	self.count -= 1
	return item
end

function RingBuffer.get<T>(self: RingBuffer<T>, index: number): any?
	if index < 1 or index > self.count then
		return nil
	end
	local actualIndex = ((self.head + index - 2) % self.capacity) + 1
	return self.data[actualIndex]
end

function RingBuffer.clear<T>(self: RingBuffer<T>)
	table.clear(self.data)
	self.head = 1
	self.tail = 1
	self.count = 0
end

return RingBuffer

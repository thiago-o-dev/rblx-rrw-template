--!strict

-- Signal.lua
local Signal = {}
Signal.__index = Signal

export type PackedArgs = { [number]: any, n: number }

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> (),
	Fire: (self: Signal, ...any) -> (),
	Wait: (self: Signal) -> ...any,
	Destroy: (self: Signal) -> (),
	HasConnections: (self: Signal) -> boolean,
}

type Node = {
	fn: (...any) -> (),
	connected: boolean,
	next: Node?,
	prev: Node?,
}

function Signal.new(): Signal
	local self = setmetatable({}, Signal)

	self._head = nil :: Node?
	self._tail = nil :: Node?
	self._destroyed = false

	return (self :: any) :: Signal
end

function Signal:_removeNode(node: Node)
	if node.prev then
		node.prev.next = node.next
	else
		self._head = node.next
	end

	if node.next then
		node.next.prev = node.prev
	else
		self._tail = node.prev
	end

	node.next = nil
	node.prev = nil
end

function Signal:Connect(fn: (...any) -> ()): Connection
	assert(not self._destroyed, "Cannot connect to destroyed Signal")
	assert(type(fn) == "function", "Signal:Connect expects a function")

	local node: Node = {
		fn = fn,
		connected = true,
		next = nil,
		prev = self._tail,
	}

	if self._tail then
		self._tail.next = node
	else
		self._head = node
	end

	self._tail = node

	local selfSignal = self

	local connection: Connection = {
		Connected = true,
		Disconnect = function(selfConn: Connection)
			if not selfConn.Connected then
				return
			end

			selfConn.Connected = false

			if node.connected then
				node.connected = false
				selfSignal:_removeNode(node)
			end
		end,
	}

	return connection
end

function Signal:Once(fn: (...any) -> ())
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
end

function Signal:Fire(...: any)
	if self._destroyed then
		return
	end

	local node = self._head
	while node do
		local nextNode = node.next
		if node.connected then
			node.fn(...)
		end
		node = nextNode
	end
end

function Signal:Wait(): ...any
	assert(not self._destroyed, "Cannot wait on destroyed Signal")

	local thread = coroutine.running()
	assert(thread, "Signal:Wait must be called from a coroutine")

	local args: PackedArgs? = nil
	local connection: Connection

	connection = self:Connect(function(...)
		args = table.pack(...)
		connection:Disconnect()
		task.spawn(thread)
	end)

	coroutine.yield()

	local packed = args
	assert(packed ~= nil, "Signal:Wait resumed without args")
	return table.unpack(packed, 1, packed.n)
end

function Signal:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true

	local node: Node? = self._head
	while node do
		node.connected = false
		local nextNode = node.next
		node.next = nil
		node.prev = nil
		node = nextNode
	end

	self._head = nil
	self._tail = nil
end

function Signal:HasConnections()
	return self._head ~= nil
end

return Signal

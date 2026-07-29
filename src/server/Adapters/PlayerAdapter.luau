local PlayerAdapter = {}

function PlayerAdapter.freezePlayer(player: Player)
	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0

		humanoid.AutoRotate = false
	end

	if rootPart and rootPart:IsA("BasePart") then
		rootPart.Anchored = true
	end

	player:SetAttribute("IsFrozen", true)
end

function PlayerAdapter.unfreezePlayer(player)
	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if rootPart and rootPart:IsA("BasePart") then
		rootPart.Anchored = false
	end

	if humanoid then
		humanoid.WalkSpeed = 16 -- default walkspeed
		humanoid.JumpHeight = 7.2 -- default jump height

		humanoid.AutoRotate = true
	end

	player:SetAttribute("IsFrozen", false)
end

return PlayerAdapter

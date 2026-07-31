--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitTypes = require(ReplicatedStorage.Shared.Types.UnitTypes)

local CULL_OFFSCREEN_CFRAME = CFrame.new(0, -9999, 0)
local UNIT_CONTAINER_NAME = "Units"

local UnitRenderer = {}

local function getUnitsFolder(): Folder
	local folder = workspace:FindFirstChild(UNIT_CONTAINER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = UNIT_CONTAINER_NAME
		folder.Parent = workspace
	end

	return folder :: Folder
end

function UnitRenderer.renderCFrame(unit: UnitTypes.ClientUnitRecord, targetCFrame: CFrame)
	if not unit.isPlaced then
		unit.isPlaced = true
		unit.model.Parent = getUnitsFolder()
		unit.model:PivotTo(targetCFrame)
		unit.currentCFrame = targetCFrame
		return
	end

	-- Update PivotTo only if model moved meaningfully (delta > 0.01 studs or rotation change)
	if
		(unit.currentCFrame.Position - targetCFrame.Position).Magnitude > 0.01
		or unit.currentCFrame.LookVector:Dot(targetCFrame.LookVector) < 0.9999
	then
		unit.model:PivotTo(targetCFrame)
		unit.currentCFrame = targetCFrame
	end
end

function UnitRenderer.setCulled(unit: UnitTypes.ClientUnitRecord, isCulled: boolean)
	if isCulled and unit.isPlaced then
		-- Hide off-screen without reparenting to avoid scene-graph rebuild hitches
		unit.model:PivotTo(CULL_OFFSCREEN_CFRAME)
		unit.isPlaced = false
	end
end

function UnitRenderer.despawnModel(unit: UnitTypes.ClientUnitRecord)
	if unit.model then
		unit.model:Destroy()
	end
end

return UnitRenderer

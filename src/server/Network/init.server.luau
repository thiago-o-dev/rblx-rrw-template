local Generated = script.Generated

local NetworkModulesFound = {}

for _, moduleScript in ipairs(Generated:GetChildren()) do
	if moduleScript:IsA("ModuleScript") then
		NetworkModulesFound[moduleScript.Name] = require(moduleScript)
	end
end

-- Example usage
-- print(NetworkModulesFound)

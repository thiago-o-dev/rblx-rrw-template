local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Janitor = require(Packages.Janitor)

export type JanitorType = typeof(Janitor.new())

return {}

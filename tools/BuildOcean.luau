--!strict
-- One-shot generator. Fills the open sea with terrain water over a sand floor, and keeps the tank
-- footprint clear so the rising pillars never touch terrain. Run once in Studio, then save the place.

local terrain = workspace.Terrain
local SIZE = 1024

terrain:Clear()
terrain:FillBlock(CFrame.new(0, -32, 0), Vector3.new(SIZE, 8, SIZE), Enum.Material.Sand)
task.wait()
terrain:FillBlock(CFrame.new(0, -16, 0), Vector3.new(SIZE, 24, SIZE), Enum.Material.Water)
task.wait()
terrain:FillBlock(CFrame.new(0, -60, 0), Vector3.new(96, 200, 96), Enum.Material.Air)
terrain.WaterColor = Color3.fromHex("1E90E0")
terrain.WaterTransparency = 0.6
terrain.WaterWaveSize = 0.2
terrain.WaterWaveSpeed = 8
terrain.WaterReflectance = 0.4

print("BuildOcean: sea filled")

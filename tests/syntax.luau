-- Compiles every .luau under a directory (default src) with the Luau compiler, so Roblox-side scripts the
-- tests cannot load still get a syntax check: `lune run tests/syntax.luau src`.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local bad = 0

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.sub(name, -5) == ".luau" then
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				bad += 1
				print("SYNTAX " .. path .. ": " .. tostring(err))
			end
		end
	end
end

walk(process.args[1] or "src")
print(bad .. " syntax errors")
if bad > 0 then
	process.exit(1)
end

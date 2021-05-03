local args, options = require("shell").parse(...)
local component = require("component")
local filesystem = require("filesystem")
local term = require("term")

if not component.isAvailable("internet") then
    io.stderr:write("This program requires an internet card to run.")
end

local files = {
    {"https://github.com/BrightYC/GUI/blob/main/doubleBuffering.lua", "/lib/doubleBuffering.lua"},
    {"https://github.com/BrightYC/GUI/blob/main/GUI.lua", "/lib/GUI.lua"},
    {"https://github.com/BrightYC/GUI/blob/main/image.lua", "/lib/image.lua"},
    {"https://github.com/BrightYC/GUI/blob/main/color.lua", "/lib/color.lua"}
}

local wgetPattern = "wget %s %s %s"

for i = 1, #files do
    if filesystem.exists(files[i][2]) then
        if (options.f or options.force) then
            print("Downloading " .. files[i][2] .. "...")
            os.execute(
                wgetPattern:format("-f", files[i][1], files[i][2])
            )
        else
            print("Skipping " .. files[i][2])
        end
    else
        print("Downloading " .. files[i][2] .. "...")
        os.execute(
            wgetPattern:format("-fq", files[i][1], files[i][2])
        )
    end
end

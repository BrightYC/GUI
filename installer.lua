local args, options = require("shell").parse(...)
local component = require("component")
local filesystem = require("filesystem")

if not component.isAvailable("internet") then
    io.stderr:write("This program requires an internet card to run.")
end

local files = {
    {"https://raw.githubusercontent.com/BrightYC/GUI/main/doubleBuffering.lua", "/lib/doubleBuffering.lua"},
    {"https://raw.githubusercontent.com/BrightYC/GUI/main/GUI.lua", "/lib/GUI.lua"},
    {"https://raw.githubusercontent.com/BrightYC/GUI/main/image.lua", "/lib/image.lua"},
    {"https://raw.githubusercontent.com/BrightYC/GUI/main/color.lua", "/lib/color.lua"}
}

local wgetPattern = "wget %s %s %s"

for i = 1, #files do
    if filesystem.exists(files[i][2]) then
        if (options.f or options.force) then
            print("Downloading " .. files[i][2] .. "...")
            os.execute(
                wgetPattern:format("-fq", files[i][1], files[i][2])
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

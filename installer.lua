if not require("component").isAvailable("internet") then
    io.stderr:write("This program requires an internet card to run.")
end

local files = {
    {"https://raw.githubusercontent.com/BrightYC/GUI/main/doubleBuffering.lua", "/lib/doubleBuffering.lua"},
    {"https://raw.githubusercontent.com/BrightYC/GUI/main/GUI.lua", "/lib/GUI.lua"},
    {"https://raw.githubusercontent.com/BrightYC/GUI/main/image.lua", "/lib/image.lua"},
    {"https://raw.githubusercontent.com/BrightYC/GUI/main/color.lua", "/lib/color.lua"}
}

for i = 1, #files do
    print("Downloading " .. files[i][2] .. "...")
    os.execute(
        ("wget -fq %s %s"):format(files[i][1], files[i][2])
    )
end
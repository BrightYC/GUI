if not require("component").isAvailable("internet") then
    io.stderr:write("This program requires an internet card to run.")
end

local files = {
    {"https://raw.githubusercontent.com/BrightYC/GUI/main/buffer.lua", "/usr/lib/UI/buffer.lua"},
    {"https://raw.githubusercontent.com/BrightYC/GUI/main/GUI.lua", "/usr/lib/UI/GUI.lua"},
    {"https://raw.githubusercontent.com/BrightYC/GUI/main/image.lua", "/usr/lib/UI/image.lua"},
    {"https://raw.githubusercontent.com/BrightYC/GUI/main/color.lua", "/usr/lib/UI/color.lua"}
}

for i = 1, #files do
    print("Downloading " .. files[i][2] .. "...")
    os.execute(
        ("wget -fq %s %s"):format(files[i][1], files[i][2])
    )
end
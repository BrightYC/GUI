local color = require("color")

local unicode = require("unicode")
local computer = require("computer")
local bit32 = require("bit32")

--------------------------------------------------------------------------------

local image = {}

local OCIFSignature = "OCIF"
local encodingMethodsLoad = {}
local encodingMethodsSave = {}

--------------------------------------------------------------------------------

local function readBytes(file, count, littleEndian)
	if count == 1 then
		local data = file:read(1)
		if data then
			return string.byte(data)
		end

		return nil
	else
		local bytes, result = {string.byte(file:read(count) or "\x00", 1, 8)}, 0

		if littleEndian then
			for i = #bytes, 1, -1 do
				result = bit32.bor(bit32.lshift(result, 8), bytes[i])
			end
		else
			for i = 1, #bytes do
				result = bit32.bor(bit32.lshift(result, 8), bytes[i])
			end
		end

		return result
	end
end

local function readUnicodeChar(file)
	local byteArray = {string.byte(file:read(1))}

	local nullBitPosition = 0
	for i = 1, 7 do
		if bit32.band(bit32.rshift(byteArray[1], 8 - i), 0x1) == 0x0 then
			nullBitPosition = i
			break
		end
	end

	for i = 1, nullBitPosition - 2 do
		table.insert(byteArray, string.byte(file:read(1)))
	end

	return string.char(table.unpack(byteArray))
end

local function write(file, ...)
	local data = {...}
	for i = 1, #data do
		data[i] = tostring(data[i])
	end
	data = table.concat(data)
	write(file, data)
end

local function writeBytes(file, ...)
	return write(file, string.char(...))
end

--------------------------------------------------------------------------------

local function group(picture, compressColors)
	local groupedPicture, x, y, background, foreground = {}, 1, 1

	for i = 3, #picture, 4 do
		if compressColors then
			background, foreground = color.to8Bit(picture[i]), color.to8Bit(picture[i + 1])

			if i % 603 == 0 then
				computer.pullSignal(0)
			end
		else
			background, foreground = picture[i], picture[i + 1]
		end

		groupedPicture[picture[i + 2]] = groupedPicture[picture[i + 2]] or {}
		groupedPicture[picture[i + 2]][picture[i + 3]] = groupedPicture[picture[i + 2]][picture[i + 3]] or {}
		groupedPicture[picture[i + 2]][picture[i + 3]][background] = groupedPicture[picture[i + 2]][picture[i + 3]][background] or {}
		groupedPicture[picture[i + 2]][picture[i + 3]][background][foreground] = groupedPicture[picture[i + 2]][picture[i + 3]][background][foreground] or {}
		groupedPicture[picture[i + 2]][picture[i + 3]][background][foreground][y] = groupedPicture[picture[i + 2]][picture[i + 3]][background][foreground][y] or {}

		table.insert(groupedPicture[picture[i + 2]][picture[i + 3]][background][foreground][y], x)

		x = x + 1

		if x > picture[1] then
			x, y = 1, y + 1
		end
	end

	return groupedPicture
end

encodingMethodsSave[5] = function(file, picture)
	writeBytes(file, 
		bit32.rshift(picture[1], 8),
		bit32.band(picture[1], 0xFF)
	)

	writeBytes(file, 
		bit32.rshift(picture[2], 8),
		bit32.band(picture[2], 0xFF)
	)

	for i = 3, #picture, 4 do
		writeBytes(file, 
			color.to8Bit(picture[i]),
			color.to8Bit(picture[i + 1]),
			math.floor(picture[i + 2] * 255)
		)

		write(file, picture[i + 3])
	end
end

encodingMethodsLoad[5] = function(file, picture)
	picture[1] = readBytes(file, 2)
	picture[2] = readBytes(file, 2)

	for i = 1, image.getWidth(picture) * image.getHeight(picture) do
		table.insert(picture, color.to24Bit(readBytes(file, 1)))
		table.insert(picture, color.to24Bit(readBytes(file, 1)))
		table.insert(picture, readBytes(file, 1) / 255)
		table.insert(picture, readUnicodeChar(file))
	end
end

local function loadOCIF67(file, picture, mode)
	picture[1] = readBytes(file, 1)
	picture[2] = readBytes(file, 1)

	local currentAlpha, currentSymbol, currentBackground, currentForeground, currentY

	for alpha = 1, readBytes(file, 1) + mode do
		currentAlpha = readBytes(file, 1) / 255
		
		for symbol = 1, readBytes(file, 2) + mode do
			currentSymbol = readUnicodeChar(file)
			
			for background = 1, readBytes(file, 1) + mode do
				currentBackground = color.to24Bit(readBytes(file, 1))
				
				for foreground = 1, readBytes(file, 1) + mode do
					currentForeground = color.to24Bit(readBytes(file, 1))
					
					for y = 1, readBytes(file, 1) + mode do
						currentY = readBytes(file, 1)
						
						for x = 1, readBytes(file, 1) + mode do
							image.set(
								picture,
								readBytes(file, 1),
								currentY,
								currentBackground,
								currentForeground,
								currentAlpha,
								currentSymbol
							)
						end
					end
				end
			end
		end
	end
end

local function saveOCIF67(file, picture, mode)
	local function getGroupSize(t)
		local size = mode == 1 and -1 or 0
		
		for key in pairs(t) do
			size = size + 1
		end
    
		return size
	end
	
	-- Grouping picture by it's alphas, symbols and colors
	local groupedPicture = group(picture, true)

	-- Writing 1 byte per image width and height
	writeBytes(file, 
		picture[1],
		picture[2]
	)

	-- Writing 1 byte for alphas array size
	writeBytes(file, getGroupSize(groupedPicture))

	local symbolsSize

	for alpha in pairs(groupedPicture) do
		symbolsSize = getGroupSize(groupedPicture[alpha])

		writeBytes(file, 
			-- Writing 1 byte for current alpha value
			math.floor(alpha * 255),
			-- Writing 2 bytes for symbols array size
			bit32.rshift(symbolsSize, 8),
			bit32.band(symbolsSize, 0xFF)
		)

		for symbol in pairs(groupedPicture[alpha]) do
			-- Writing current unicode symbol value
			write(file, symbol)
			-- Writing 1 byte for backgrounds array size
			writeBytes(file, getGroupSize(groupedPicture[alpha][symbol]))

			for background in pairs(groupedPicture[alpha][symbol]) do
				writeBytes(file, 
					-- Writing 1 byte for background color value (compressed by color)
					background,
					-- Writing 1 byte for foregrounds array size
					getGroupSize(groupedPicture[alpha][symbol][background])
				)

				for foreground in pairs(groupedPicture[alpha][symbol][background]) do
					writeBytes(file, 
						-- Writing 1 byte for foreground color value (compressed by color)
						foreground,
						-- Writing 1 byte for y array size
						getGroupSize(groupedPicture[alpha][symbol][background][foreground])
					)
					
					for y in pairs(groupedPicture[alpha][symbol][background][foreground]) do
						writeBytes(file, 
							-- Writing 1 byte for current y value
							y,
							-- Writing 1 byte for x array size
							#groupedPicture[alpha][symbol][background][foreground][y] - mode
						)

						for x = 1, #groupedPicture[alpha][symbol][background][foreground][y] do
							writeBytes(file, groupedPicture[alpha][symbol][background][foreground][y][x])
						end
					end
				end
			end
		end
	end
end

encodingMethodsSave[6] = function(file, picture)
	saveOCIF67(file, picture, 0)
end

encodingMethodsLoad[6] = function(file, picture)
	loadOCIF67(file, picture, 0)
end

encodingMethodsSave[7] = function(file, picture)
	saveOCIF67(file, picture, 1)
end

encodingMethodsLoad[7] = function(file, picture)
	loadOCIF67(file, picture, 1)
end

--------------------------------------------------------------------------------

function image.getIndex(x, y, width)
	return 4 * (width * (y - 1) + x) - 1
end

function image.create(width, height, background, foreground, alpha, symbol, random)
	local picture = {width, height}

	for i = 1, width * height do
		table.insert(picture, random and math.random(0x0, 0xFFFFFF) or (background or 0x0))
		table.insert(picture, random and math.random(0x0, 0xFFFFFF) or (foreground or 0x0))
		table.insert(picture, alpha or 0x0)
		table.insert(picture, random and string.char(math.random(65, 90)) or (symbol or " "))
	end

	return picture
end

function image.copy(picture)
	local newPicture = {}
	
	for i = 1, #picture do
		newPicture[i] = picture[i]
	end

	return newPicture
end

function image.save(path, picture, encodingMethod)
	encodingMethod = encodingMethod or 6
	
	local file, reason = io.open(path, "wb")
	if file then	
		if encodingMethodsSave[encodingMethod] then
			write(file, OCIFSignature, string.char(encodingMethod))

			local result, reason = xpcall(encodingMethodsSave[encodingMethod], debug.traceback, file, picture)
			
			file:close()

			if result then
				return true
			else
				return false, "Failed to save OCIF image: " .. tostring(reason)
			end
		else
			file:close()
			return false, "Failed to save OCIF image: encoding method \"" .. tostring(encodingMethod) .. "\" is not supported"
		end
	else
		return false, "Failed to open file for writing: " .. tostring(reason)
	end
end

function image.load(path)
	local file, reason = io.open(path, "rb")
	if file then
		local readedSignature = file:read(#OCIFSignature)
		if readedSignature == OCIFSignature then
			local encodingMethod = readBytes(file, 1)
			if encodingMethodsLoad[encodingMethod] then
				local picture = {}
				local result, reason = xpcall(encodingMethodsLoad[encodingMethod], debug.traceback, file, picture)
				
				file:close()

				if result then
					return picture
				else
					return false, "Failed to load OCIF image: " .. tostring(reason)
				end
			else
				file:close()
				return false, "Failed to load OCIF image: encoding method \"" .. tostring(encodingMethod) .. "\" is not supported"
			end
		else
			file:close()
			return false, "Failed to load OCIF image: binary signature \"" .. tostring(readedSignature) .. "\" is not valid"
		end
	else
		return false, "Failed to open file \"" .. tostring(path) .. "\" for reading: " .. tostring(reason)
	end
end

-------------------------------------------------------------------------------

function image.toString(picture)
	local charArray = {
		string.format("%02X", picture[1]),
		string.format("%02X", picture[2])
	}
	
	for i = 3, #picture, 4 do
		table.insert(charArray, string.format("%02X", color.to8Bit(picture[i])))
		table.insert(charArray, string.format("%02X", color.to8Bit(picture[i + 1])))
		table.insert(charArray, string.format("%02X", math.floor(picture[i + 2] * 255)))
		table.insert(charArray, picture[i + 3])

		if i % 603 == 0 then
			computer.pullSignal(0)
		end
	end

	return table.concat(charArray)
end

function image.fromString(pictureString)
	local picture = {
		tonumber("0x" .. unicode.sub(pictureString, 1, 2)),
		tonumber("0x" .. unicode.sub(pictureString, 3, 4)),
	}

	for i = 5, unicode.len(pictureString), 7 do
		table.insert(picture, color.to24Bit(tonumber("0x" .. unicode.sub(pictureString, i, i + 1))))
		table.insert(picture, color.to24Bit(tonumber("0x" .. unicode.sub(pictureString, i + 2, i + 3))))
		table.insert(picture, tonumber("0x" .. unicode.sub(pictureString, i + 4, i + 5)) / 255)
		table.insert(picture, unicode.sub(pictureString, i + 6, i + 6))
	end

	return picture
end

--------------------------------------------------------------------------------

function image.set(picture, x, y, background, foreground, alpha, symbol)
	local index = image.getIndex(x, y, picture[1])
	picture[index], picture[index + 1], picture[index + 2], picture[index + 3] = background, foreground, alpha, symbol

	return picture
end

function image.get(picture, x, y)
	local index = image.getIndex(x, y, picture[1])
	return picture[index], picture[index + 1], picture[index + 2], picture[index + 3]
end

function image.getSize(picture)
	return picture[1], picture[2]
end

function image.getWidth(picture)
	return picture[1]
end

function image.getHeight(picture)
	return picture[2]
end

function image.transform(picture, newWidth, newHeight)
	local newPicture, stepWidth, stepHeight, background, foreground, alpha, symbol = {newWidth, newHeight}, picture[1] / newWidth, picture[2] / newHeight
	
	local x, y = 1, 1
	for j = 1, newHeight do
		for i = 1, newWidth do
			background, foreground, alpha, symbol = image.get(picture, math.floor(x), math.floor(y))
			table.insert(newPicture, background)
			table.insert(newPicture, foreground)
			table.insert(newPicture, alpha)
			table.insert(newPicture, symbol)

			x = x + stepWidth
		end

		x, y = 1, y + stepHeight
	end

	return newPicture
end

function image.crop(picture, fromX, fromY, width, height)
	if fromX >= 1 and fromY >= 1 and fromX + width - 1 <= picture[1] and fromY + height - 1 <= picture[2] then
		local newPicture, background, foreground, alpha, symbol = {width, height}
		
		for y = fromY, fromY + height - 1 do
			for x = fromX, fromX + width - 1 do
				background, foreground, alpha, symbol = image.get(picture, x, y)
				table.insert(newPicture, background)
				table.insert(newPicture, foreground)
				table.insert(newPicture, alpha)
				table.insert(newPicture, symbol)
			end
		end

		return newPicture
	else
		return false, "Failed to crop image: target coordinates are out of source range"
	end
end

function image.flipHorizontally(picture)
	local newPicture, background, foreground, alpha, symbol = {picture[1], picture[2]}
	
	for y = 1, picture[2] do
		for x = picture[1], 1, -1 do
			background, foreground, alpha, symbol = image.get(picture, x, y)
			table.insert(newPicture, background)
			table.insert(newPicture, foreground)
			table.insert(newPicture, alpha)
			table.insert(newPicture, symbol)
		end
	end

	return newPicture
end

function image.flipVertically(picture)
	local newPicture, background, foreground, alpha, symbol = {picture[1], picture[2]}
	
	for y = picture[2], 1, -1 do
		for x = 1, picture[1] do
			background, foreground, alpha, symbol = image.get(picture, x, y)
			table.insert(newPicture, background)
			table.insert(newPicture, foreground)
			table.insert(newPicture, alpha)
			table.insert(newPicture, symbol)
		end
	end

	return newPicture
end

function image.expand(picture, fromTop, fromBottom, fromLeft, fromRight, background, foreground, alpha, symbol)
	local newPicture = image.create(picture[1] + fromRight + fromLeft, picture[2] + fromTop + fromBottom, background, foreground, alpha, symbol)

	for y = 1, picture[2] do
		for x = 1, picture[1] do
			image.set(newPicture, x + fromLeft, y + fromTop, image.get(picture, x, y))
		end
	end

	return newPicture
end

function image.blend(picture, blendColor, transparency)
	local newPicture = {picture[1], picture[2]}

	for i = 3, #picture, 4 do
		table.insert(newPicture, color.blend(picture[i], blendColor, transparency))
		table.insert(newPicture, color.blend(picture[i + 1], blendColor, transparency))
		table.insert(newPicture, picture[i + 2])
		table.insert(newPicture, picture[i + 3])
	end

	return newPicture
end

--------------------------------------------------------------------------------

return image
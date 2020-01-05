--[[
@author n0ne
@version 0.7.0
@noindex
--]]

function jReadSettings(file_name)
    -- Reads variables from a ini style text file
    -- Format for text file is: varname=value, lines starting with // are ignored and can be used for commenting
    -- Every varname will we a TABLE in the returned table, this way one variable can have multiple values
	local settingsData = {}
	if not io.open(file_name, "r") then
		msg("No settingsfile found: " .. file_name)
		return false
	end

	for line in io.lines(file_name) do
		-- Skips lines that start with //
		--if not line:match("^//.+") then
		local lineClean = jStringExplode(line, "//")
			local name = lineClean[1]:match("(.+)=.-")
			if name then
				local value = lineClean[1]:match(".+=(.+)")
                value = _jReadSettingsProcessValue(value)
				-- msg(name .. ": " .. tostring(value) .. ", type: " .. type(value))

				if settingsData[name] then
					settingsData[name][#settingsData[name]+1] = value
				else
					settingsData[name] = {value}
				end
			end	
		--end
	end

	-- tablePrint(settingsData)
	return settingsData
end

function jSettingsCreate(file_name, default_file, content)
	local default_file = default_file or false
    local content = content or ""
    
    if not io.open(file_name, "r") then
		local file = io.open(file_name, "w")
		if default_file then
			local file_to_read = io.open(default_file, "r")
			if not file_to_read then
				msg("jSettingsCreate(): Default file sepcified but could not open: " .. default_file)
				return false
			end
			content = file_to_read:read("a")
		end

		file:write(content)
		file:close()
		return true -- New file created
	else
		return false -- settingsfile already exists
    end
end

function _jReadSettingsProcessValue(value)
	value = jStringTrim(value)
    if value == "true" then
        value = true
    elseif value == "false" then
		value = false
	elseif jStringIsInt(value) then
		value = math.tointeger(value)
    end

    return value
end

function jSettingsGet(t, name, typeCheck)
	local value = t[name]
	if value == nil then
		msg("jSettingsGet(): Trying to read an empty setting: " .. name)
		return nil
	end

	
	if typeCheck == "table" then
		if type(value) ~= typeCheck then
			msg("jSettingsGet(): setting type does not match for: " .. name .. ". Wanted: " .. typeCheck .. ", got: " .. type(value))
		end
		return value
	else
		if type(value[1]) ~= typeCheck then
			msg("jSettingsGet(): setting type does not match for: " .. name .. ". Wanted: " .. typeCheck .. ", got: " .. type(value[1]))
		end
		return value[1]
	end
end
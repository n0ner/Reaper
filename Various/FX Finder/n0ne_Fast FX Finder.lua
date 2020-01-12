--[[
@description Fast FX Finder
@author n0ne
@about
	# Fast VST/FX Rack/Template Finder

	A little window that allows for quick searching of FX (can be VST, templates or fxrack).

	The script stores how often you select a certain FX and orders the list by how many times something is used.
@version 0.7.17
@changelog
	+ Allow resizing of GUI and change number of results
	+ Store window position
	+ Scroll down list with tab and arrow keys
	+ Add setting to open FX in chain
	+ Fix searching in hidden filename parts
	+ Add support for searching with tags: @fx, @chain, @temp, @i, @vst3, @vst
	+ Improve format of ini file. Backwards compatible but recommended to update (see REQ/ settings default)
@provides
	REQ/j_file_functions.lua
	REQ/JProjectClass.lua
	REQ/JProjectClassReq.lua
	REQ/j_tables.lua
	REQ/JGui.lua
	REQ/JGuiColors.lua
	REQ/JGuiControls.lua
	REQ/JGuiFunctions.lua
	REQ/j_trackstatechunk_functions.lua
	REQ/j_settings_functions.lua
	REQ/j_string_functions.lua
	REQ/jKeyboard.lua
	REQ/mouse.lua
	REQ/fx-finder-settings-default.ini
--]]

local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"

require ('REQ.j_file_functions')
require ('REQ.JProjectClass')
require ('REQ.j_tables')
require ('REQ.jGui')
require ('REQ.j_trackstatechunk_functions')
require ('REQ.j_settings_functions')

-- SOME SETUP
SETTINGS_BASE_FOLDER = script_path
SETTINGS_INI_FILE = script_path .. "fx-finder-settings.ini"
SETTINGS_DEFAULT_FILE = script_path .. "REQ/fx-finder-settings-default.ini"


function msg(m)
  return reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

function jWriteVstData(file_name, t)
	-- Write extended vst usage data
	local sContent = ""
	
	for i, l in ipairs(t) do
		sContent = sContent .. l.name .. "," .. l.rating .. "\n"
	end
	
	local file = io.open(file_name, "w")
	file:write(sContent)
	file:close()
end

function jReadVstData(file_name)
	-- Reads extended vst usage data
	local vstData = {}
	-- if the file doesnt exist create it
	if not io.open(file_name, "r") then
		local file = io.open(file_name, "w")
		file:close()
	end
	for line in io.lines(file_name) do
		local vstName = line:match("(.+),.-")
		local vstRating = line:match(".+,(.+)")
		vstData[vstName] = {rating = vstRating}
	end
	return vstData
end

function jReadVstIni(ini_file_name, tRatingsData)
	local i = 0
	local tResult = {}
	local tLookup = {}
	for line in io.lines(ini_file_name) do
		-- Safety checking the first line
		if i == 0 then
			if line ~= "[vstcache]" then return false end
		else
			local sName = line:match(".-,.-,(.+)") or false

			
			if sName and sName ~= "<SHELL>" then
				local skip = false
				for _, skipName in ipairs(PLUGIN_BLACKLIST) do
					if sName:find(skipName) then
						skip = true
						break
					end
				end
				
				if not skip then
					-- Get rating
					local iRating = 0
					if tRatingsData[sName] then
						iRating = math.floor(tRatingsData[sName].rating)
					end
					
					local bInstrument = nil
					if line:find(".+!!!VSTi") then
						bInstrument = true
						-- sName = sName:sub(1,-8)
					end
					
					local sTypePart = line:match("(.+)=.+")
					local bDll = nil
					local bVst3 = nil
					local bVst = nil
					if sTypePart:find("dll") then
						bDll = true
					elseif sTypePart:find("vst3") then
						bVst3 = true
					elseif sTypePart:find("vst$") or sTypePart:find("vst.") then
						bVst = true
					end
				
					if not tLookup[sName] then
						table.insert(tResult, {name = sName, line = i, instrument = bInstrument, dll = bDll, vst3 = bVst3, vst=bVst, rating = iRating})
						tLookup[sName] = #tResult
					elseif bDll then -- also found dll version
						tResult[tLookup[sName]].dll = true
					elseif bVst3 then -- also found vst3 version
						tResult[tLookup[sName]].vst3 = true
					elseif bVst then -- also found vst version (mac)
						tResult[tLookup[sName]].vst = true
					end
				end
			end
		end
		i = i + 1
	end
	
	return tResult
end

function getTemplates(tDirs, sRootDir, tRatingsData)
	local tResult = {}
	for i, v in ipairs(tDirs) do
		tResult = getFilesRecursive(sRootDir .. "/".. v[1], not v[2], tResult)
	end

	-- return tResult
	local tTemplatesData = {}
	local count = 1
	for i, v in ipairs(tResult) do
		if _jIsTemplate(v[1]) then
			local sName = v[1] .. " (" .. v[2]:gsub(sRootDir, "") .. ")"
			-- Get rating
			local iRating = 0
			if tRatingsData[sName] then
				iRating = math.floor(tRatingsData[sName].rating)
			end
			tTemplatesData[count] = {	name = sName,
									filename = v[1],
									path = v[2],
									tracktemplate = true,
									rating = iRating
								}
			count = count + 1
		end

	end
	return tTemplatesData
end

function _jIsTemplate(filename)
	return filename:lower():find("%.rtracktemplate$")
end

function _jIsFxChain(filename)
	return filename:lower():find("%.rfxchain$")
end

function getFXChains(tDirs, sRootDir, tRatingsData)
	local tResult = {}
	for i, v in ipairs(tDirs) do
		tResult = getFilesRecursive(sRootDir .. "/" .. v[1], not v[2], tResult)
	end
	-- return tResult
	local tFXChainData = {}
	local count = 1
	for i, v in ipairs(tResult) do
		if _jIsFxChain(v[1]) then
			local sName = v[1] .. " (" .. v[2]:gsub(sRootDir, "") .. ")"
			-- Get rating
			local iRating = 0
			if tRatingsData[sName] then
				iRating = math.floor(tRatingsData[sName].rating)
			end
			tFXChainData[count] = {		name = sName,
									filename = v[1],
									path = v[2],
									fxchain = true,
									rating = iRating
								}
			count = count + 1
		end
	end
	return tFXChainData
end

function findVst(vstTable, sPattern, iInstance, iMaxResults, find_plain)
	local iInstance = iInstance or false
	local find_plain = find_plain or true
	local iMaxResults = iMaxResults or false

	local tResult = {}
    local iCount = 0

	if type(iInstance) == "number" and iInstance <= 0 then 
		jError("findVst(), instance <= 0. First instance is 1! iInstance: " .. tostring(iInstance), J_ERROR_ERROR) 
		return false
	end	

	for i, t in ipairs(vstTable) do
		bMatch = true
		-- Look for every word in the string
		for token in string.gmatch(sPattern, "[^%s]+") do
			-- local name = t.name
			local name = _makeFxNameSearchable(t.name)
			if token == "@fx" or token == "@vst" then 
				if not t.dll and not t.vst and not t.vst3 then
					bMatch = false
					break
				end
			elseif token == "@temp" then 
				if not t.tracktemplate then
					bMatch = false
					break
				end
			elseif token == "@chain" then 
				if not t.fxchain then
					bMatch = false
					break
				end
			elseif token == "@vst3" then 
				if not t.vst3 then
					bMatch = false
					break
				end
			elseif token == "@i" then 
				if not t.instrument then
					bMatch = false
					break
				end
			elseif not name:lower():find(token:lower(), 1, find_plain) then
				bMatch = false
				break
			end
		end

		if bMatch then
			iCount = iCount + 1
            if iInstance == false then
			t.id = i -- keep track of position in main table
                tResult[#tResult + 1] = t
				if iMaxResults ~= false then
					if #tResult >= iMaxResults then -- check if we already heave enough results
						return tResult
					end
				end
            elseif iInstance == iCount then
                return t
            end
        end
	end

    if not iInstance then
        -- return table
        if #tResult == 0 then
            return {} -- Used to return false but should be empty table
        else
            return tResult
        end
    else
        -- instance not found
        return false
    end
end

jGuiHighlightControl = jGuiControl:new({highlight = {}, color_highlight = {1, .9, 0, .2},})

function jGuiHighlightControl:_drawLabel()
	-- msg(self.label)
	
	gfx.setfont(1, self.label_font, self.label_fontsize)
	self:__setLabelXY()

	if self.highlight and #self.highlight > 0 then
		for _, word in pairs(self.highlight) do
			if word and word ~= "" then
				local parts, r = jStringExplode(self.label, word, true)
				local totalX = 0
				if #parts>1 then
					local highLightW, highLightH = gfx.measurestr(word)
					for i = 1, #parts - 1 do -- do all but the last
						local noLightW, noLightH = gfx.measurestr(parts[i])
						-- Draw highlight
						self:__setGfxColor(self.color_highlight)
						gfx.rect(gfx.x + totalX + noLightW, gfx.y, highLightW + 1, highLightH, 1)

						totalX = totalX + noLightW + highLightW
					end
					-- tablePrint(parts)
				end
			end
		end
	end

	self:_setStateColor()
	gfx.drawstr(tostring(self.label))
end

function _jScroll(amount)
	SCROLL_RESULTS = SCROLL_RESULTS + amount
	local maxScroll = RESULT_COUNT - RESULTS_PER_PAGE
	if SCROLL_RESULTS > maxScroll then SCROLL_RESULTS = maxScroll end
	if SCROLL_RESULTS < 0 then SCROLL_RESULTS = 0 end
	UPDATE_RESULTS = true
end

function createResultButtons(gui, tControls, n, height, y_start)
	local x_start = 10
	local y_space = 0
	local n_to_remove = 0
	
	for i = 1, math.max(#tControls, n) do
		if i > #tControls and i <= n then
			local c = jGuiHighlightControl:new()
			c.height = height
			c.label_fontsize = height - 2
			c.label_align = "l"
			c.label_font = "Calibri"
			c.border = false
			c.focus_index = i+1 --gui:getFocusIndex()
			c.border_focus = true

			c.x = x_start
			c.y = y_start + (i-1) * (c.height + y_space)
			
			local info = jGuiText:new()
			info.width = 40
			info.height = height
			info.label_fontsize = math.tointeger( (height-2) / 2 + 3)
			c.label_font = "Calibri"
			info.label_align = "r"
			info.label_valign = "m"
			info.border = false
			info.y = c.y
			
			function c:onMouseClick()
				selectFx(i + SCROLL_RESULTS)

				gui:setFocus(textBox)
				UPDATE_RESULTS = true
				if not gui.kb.shift() then
					self.parentGui:exit()
				end
			end

			function c:onMouseWheel(mw) -- it looks like SCROLL_RESULTS can be a value between 0 and 1, should be a whole number?
				_jScroll(mw/120 * -1)
			end

			function c:onArrowDown()
				return c:onTab()
			end

			function c:onArrowUp()
				return c:onShiftTab()
			end

			function c:onShiftTab()
				if i == 1 and SCROLL_RESULTS~= 0 then
					_jScroll(-1)
					return false
				end
				return true -- else
			end

			function c:onTab()
				if i == #tControls then
					_jScroll(1)
					return false
				end
				return true -- else
			end
			
			-- tControls[i] = {gui:controlAdd(c), gui:controlAdd(info)}
			gui:controlAdd(c)
			gui:controlAdd(info)
			tControls[i] = {c, info}
		elseif i > n then
			-- msg("-: " .. i .. "/" .. (#gui.controls - 2)/2 .. "/" .. #tControls .. " n: " .. n)
			-- if tControls[i][1] == nil or tControls[i][2] == nil then
			-- 	msg("last one was nil in table!")
			-- end
			-- if tControls[i] == nil then
			-- 	for k,v in ipairs(tControls) do
			-- 		msg(k .. " => " .. tostring(v))
			-- 	end
			-- end
			-- msg("1: " .. tostring(tControls))
			-- msg("2: " .. tostring(tControls[i]))
			-- msg("3: " .. tostring(tControls[i][1]))
			local b = tControls[i][1]
			local info = tControls[i][2]
			-- if b == nil or info == nil then
			-- 	msg("last one was nil in controls!")
			-- end
			gui:controlDelete(b)
			gui:controlDelete(info)
			-- gui:controlDeleteId(tControls[i][1])
			n_to_remove = n_to_remove + 1
		end

		if i <= #tControls and i <= n then
			-- msg("u: " .. i .. "/" .. (#gui.controls - 2)/2 .. "/" .. #tControls)
			local b = tControls[i][1]
			local info = tControls[i][2]

			b.width = gui.width - 20
			info.x = 10 + b.width - info.width
		end
	end

	for i = 1, n_to_remove do
		-- msg("removing: " .. i .. "/" .. n_to_remove)
		table.remove(tControls, #tControls)
	end

	-- msg("End # controls in table: " .. #tControls)

end

function _round(inValue)
	return math.floor(inValue+0.5)
end

function showSearchResults(tButtons, tResults)	
	for i, cIds in ipairs(tButtons) do
		local b = cIds[1]
		local info = cIds[2]
		local iStart = _round(i + SCROLL_RESULTS)
		local highlights = jStringExplode(textBox.value, " ")

		local showing
		if iStart <= #tResults then showing = iStart else showing = #tResults end
		LABEL_STATS.label = "(" .. showing  .. "/" .. #tResults .. ")"

		if tResults and iStart <= #tResults then
			local fx = tResults[iStart]
			b.label = _makeFxLabel(fx.name)
			b.visible = true
			info.visible = true
			b.highlight = highlights

			local tTypes = {}
			if fx.instrument then
				if fx.vst3 then
					tTypes[#tTypes+1] = "VST3i"
				elseif fx.dll or fx.vst then
					tTypes[#tTypes+1] = "VSTi"
				end
			else
				if fx.vst3 then
					tTypes[#tTypes+1] = "VST3"
				end
				if fx.dll then
					tTypes[#tTypes+1] = "VST"
				end
				if fx.vst then
					tTypes[#tTypes+1] = "VST"
				end
			end

			if fx.tracktemplate then
				tTypes[#tTypes+1] = "TEMP"
			end

			if fx.fxchain then
				tTypes[#tTypes+1] = "FXCHAIN"
			end

			local sTypes = ""
			for _, sT in ipairs(tTypes) do
				sTypes = sTypes .. " " .. sT
			end

			info.label = sTypes --.. "\n" .. fx.rating
		else
			b.visible = false
			info.visible = false
		end
	end
end

function sortByRating(a, b)
	if a.rating > b.rating then
		return true
	elseif a.rating == b.rating then
		return a.name < b.name
	else
		return false
	end
end

function selectFx(i)
	if not tSearchResults then return false end -- results is empty
	local fx = tSearchResults[i]
	if not fx then return false end -- no such result

	tVstData[fx.id].rating = tVstData[fx.id].rating + 1

	reaper.Undo_BeginBlock2(p:getId())
	
	if fx.tracktemplate then
		-- This is a template, insert it
		reaper.Main_openProject(fx.path .. fx.filename)
	elseif fx.fxchain then
		if not GUI.kb.control() then -- Control not held, insert on tracks
			-- Adds an FXCHAIN to a track. If there are no FX on the track an empty chain will be created first
			local selectedTracks = p:selectedTracks(0, 0, true)
			local bCreatedChain = false
			
			for _, t in pairs(selectedTracks) do
				if t.fxcount == 0 then
					p:unselectAllTracks()
					t.selected = 1
					jCreateTrackChainForSelectedTracks()
					bCreatedChain = true
				end
			end

			for _, t in pairs(selectedTracks) do
				if bCreatedChain then
					t.selected = 1
				end
				jFxChainAdd(t, jReadFxChainFromFile(fx.path .. fx.filename))
			end

			if TRACK_SHOW_FLAG == 1 then -- added for people using the fxchain window so the fx will show
				local focusTrack = selectedTracks[1]
				if focusTrack then
					focusTrack:getFx(focusTrack.fxcount - 1):show(TRACK_SHOW_FLAG)
				end
			end

		-- else -- control held, try to add chain to items
			-- reaper.ClearConsole()
			-- for i in p:selectedItems() do
			-- 	local take = i:getActiveTake()
			-- 	local chunk = i:getStateChunk()
			-- 	local takeNumber = math.tointeger(take.number)
			-- 	-- msg(chunk)
			-- 	-- msg("---")

			-- 	msg(math.tointeger( takeNumber))
			-- 	local fxChunk = ultraschall.GetFXStateChunk(chunk, takeNumber)
			-- 	msg(fxChunk)
			-- 	msg("after: ")
			-- 	local fxString = jReadFxChainFromFile(fx.path .. fx.filename)
			-- 	if not fxChunk then
			-- 		-- No fx yet, create chunk:
			-- 		msg("create new chunk...")
			-- 		fxChunk = " <TAKEFX\n" .. fxString .. "\n  >"
			-- 		takeNumber = 0
			-- 	else
			-- 		fxChunk =  fxChunk:gsub(">$", '') -- remove closing ">"
			-- 		fxChunk = fxChunk .. "\n" .. fxString .. "\n>"
			-- 	end
			-- 	msg("fxChunk:")
			-- 	msg(fxChunk)
			-- 	msg("Chunk:")
			-- 	msg(chunk)
			-- 	local r, newChunk = ultraschall.SetFXStateChunk(chunk, fxChunk, takeNumber)
			-- 	-- msg(newChunk)
			-- 	-- i:setStateChunk(newChunk)

			-- end
		end
	else
		-- this is a vst
		local typeInfo = ""
		if tVstData[fx.id].vst3 and PREFER_VST3 then -- prefer VST3 where available
			typeInfo = "VST3:"
		end
		if not GUI.kb.control() then -- Control not held, insert on tracks
			for t in p:selectedTracks() do
				local r = t:addFx(typeInfo .. _removeVstiString(tVstData[fx.id].name))
				if r then
					r:show(TRACK_SHOW_FLAG)
				end
			end
		else -- Control held, insert on items
			for i in p:selectedItems() do
				local take = i:getActiveTake()
				local r = take:addFx(typeInfo .. _removeVstiString(tVstData[fx.id].name))
				if r >= 0 then
					reaper.TakeFX_Show(take:getReaperTake(), r, ITEM_SHOW_FLAG) -- show FX
				end
			end
		end
	end
	reaper.Undo_EndBlock2(p:getId(), "FAST FX FINDER: Add Fx", 0)

	UPDATE_RATINGS = true
	return true

end

function _removeVstiString(s)
	return s:gsub("!!!VSTi", "")
end

function _makeFxLabel(s)
	s = _removeVstiString(s) -- remove !!!VSTi indicator
	s = s:gsub(".RTrackTemplate", "") -- remove tracktemplate extention
	s = s:gsub(".RfxChain", "") -- remove tracktemplate extention
--	s = s:gsub("\\%)", ")") -- remove ugly trailing slash from template folders
	return s
end

function _makeFxNameSearchable(s)
	s = _removeVstiString(s) -- remove !!!VSTi indicator
	s = s:gsub(".RTrackTemplate", "") -- remove tracktemplate extention
	s = s:gsub(".RfxChain", "") -- remove tracktemplate extention
--	s = s:gsub("\\%)", ")") -- remove ugly trailing slash from template folders
	return s
end

function init()
	-- reaper.ClearConsole()

	p = JProject:new()

	UPDATE_RATINGS = false
	UPDATE_RESULTS = false
	SCROLL_RESULTS = 0
	RESULT_COUNT = 0

	if not loadSettings() then
		msg("Something went wrong with loading of settings, aborting. Please check your settings file: \n" .. SETTINGS_INI_FILE)
		return false
	end

	tRatingData = jReadVstData(DATA_INI_FILE)
	tVstData = jReadVstIni(VST_INI_FILE, tRatingData)

	tTemplates = getTemplates(TEMPLATE_SUB_DIRS, TEMPLATE_ROOT_DIR, tRatingData)
	tVstData = jTablesGlue(tTemplates, tVstData)
	
	tFXChains = getFXChains(FXCHAIN_SUB_DIRS, FXCHAIN_ROOT_DIR, tRatingData)
	tVstData = jTablesGlue(tFXChains, tVstData)

	table.sort(tVstData, sortByRating)

	-- Create the GUI
	GUI = jGui:new({title = "Fast FX Finder", width = WINDOW_WIDTH, height = WINDOW_HEIGHT, x=WINDOW_X, y=WINDOW_Y, dockstate=WINDOW_DOCK_STATE})

	tResultButtons = {}

	textBox = jGuiTextInput:new()
	textBox.x = 10
	textBox.y = 10
	textBox.width = 480
	textBox.height = math.tointeger( GUI_SIZE * 1.5 )
	textBox.label_fontsize = math.tointeger( GUI_SIZE * 1.5 )
	textBox.label_align = "l"
	textBox.label_font = "Calibri"
	textBox.focus_index = GUI:getFocusIndex()
	textBox.label_padding = 3
	
	function textBox:onEnter() 
		
		if selectFx(1) then
			GUI:exit()
		end
		textBox.value = ""
	end
	
	GUI:controlAdd(textBox)

	LABEL_STATS = jGuiControl:new()
	LABEL_STATS.width = 50
	LABEL_STATS.x = GUI.width - LABEL_STATS.width - 12
	LABEL_STATS.y = 10
	LABEL_STATS.label_fontsize = math.tointeger( GUI_SIZE * 0.75 )
	LABEL_STATS.label_align = "r"
	LABEL_STATS.border = false

	GUI:controlAdd(LABEL_STATS)
	
	BUTTON_Y_START = GUI_SIZE * 1.5 + 15
	-- createResultButtons(GUI, tResultButtons, RESULTS_PER_PAGE, GUI_SIZE, BUTTON_Y_START)
	
	GUI:setFocus(textBox)

	function GUI:onResize()
		textBox.width = self.width - 20
		LABEL_STATS.x = GUI.width - LABEL_STATS.width - 12

		local buttonsSpaceH = GUI.height - BUTTON_Y_START - 4
		RESULTS_PER_PAGE = math.tointeger(buttonsSpaceH // GUI_SIZE)
		-- msg(buttonsSpaceN)
		createResultButtons(GUI, tResultButtons, RESULTS_PER_PAGE, GUI_SIZE, BUTTON_Y_START)
		UPDATE_RESULTS = true
		self:controlInitAll()
	end

	GUI:init()

	function GUI:update()
		if lastSearch ~= textBox.value then
			SCROLL_RESULTS = 0 -- reset scrollbar on search update
		end

		if(lastSearch ~= textBox.value or UPDATE_RESULTS) then
			-- search changed, update results
			UPDATE_RESULTS = false
			table.sort(tVstData, sortByRating)
			tSearchResults = findVst(tVstData, textBox.value, false, MAX_RESULTS)
			RESULT_COUNT = #tSearchResults
			showSearchResults(tResultButtons, tSearchResults)
			lastSearch = textBox.value
		end
	end
	
	function GUI:onExit()
		if UPDATE_RATINGS then
			table.sort(tVstData, sortByRating)
			jWriteVstData(DATA_INI_FILE, tVstData)
		end

		if WINDOW_SAVE_STATE then
			local dockstate, wx, wy, ww, wh = gfx.dock(-1, 0, 0, 0, 0)
			local dockstr = string.format("%d", dockstate)
			jSettingsWriteToFileMultiple(SETTINGS_INI_FILE, {	{"gui", "window_x", math.tointeger(wx)}, 
																{"gui", "window_y", math.tointeger(wy)},
																{"gui", "window_width", math.tointeger(ww)},
																{"gui", "window_height", math.tointeger(wh)},
																{"gui", "window_dock_state", dockstr} }, true)
		end
	end


	return true
end

function loop()
	if GUI:loop() then 
		reaper.defer(loop)
	end
end

function _joinSettingsTables(t1, t2)
	local tResult = {}
	for k, v in ipairs(t1) do
		tResult[k] = {v, t2[k]}
	end
	return tResult
end

function loadSettings()
	jSettingsCreate(SETTINGS_INI_FILE, SETTINGS_DEFAULT_FILE)
	SETTINGS = assert(jSettingsReadFromFile(SETTINGS_INI_FILE), "Could not open settings file.")

	-- new settings since 0.7.16, will be created if not present
	if not SETTINGS['window_save_state'] then
		jSettingsWriteToFile(SETTINGS_INI_FILE, "gui", "window_save_state", "true", true)
		SETTINGS['window_save_state'] = {true}
	end

	if not SETTINGS['window_dock_state'] then
		jSettingsWriteToFile(SETTINGS_INI_FILE, "gui", "window_dock_state", "0", true)
		SETTINGS['window_dock_state'] = {0}
	end

	if not SETTINGS['gui_size'] then
		jSettingsWriteToFile(SETTINGS_INI_FILE, "gui", "gui_size", "20", true)
		SETTINGS['gui_size'] = {20}
	end

	if not SETTINGS['track_show_flag'] then
		jSettingsWriteToFile(SETTINGS_INI_FILE, "fx", "track_show_flag", "3 ; 0 hidechain, 1 show chain, 2 hide floating, 3 for show floating window (default)", true)
		SETTINGS['track_show_flag'] = {3}
	end

	if not SETTINGS['item_show_flag'] then
		jSettingsWriteToFile(SETTINGS_INI_FILE, "fx", "item_show_flag", "3", true)
		SETTINGS['item_show_flag'] = {3}
	end

	-- if not SETTINGS['ultraschall_api_file'] then
	-- 	jSettingsWriteToFile(SETTINGS_INI_FILE, "files", "ultraschall_api_file", "UserPlugins/ultraschall_api.lua")
	-- 	SETTINGS['ultraschall_api_file'] = {"UserPlugins/ultraschall_api.lua"}
	-- end

	
	-- if true then return false end

	VST_INI_FILE = 		reaper.GetResourcePath() .. "/" .. jSettingsGet(SETTINGS, 'vst_ini_file', "string")
	DATA_INI_FILE = SETTINGS_BASE_FOLDER .. "/" .. jSettingsGet(SETTINGS, 'fx_finder_data_file', "string")
	-- ULTRASCHALL_API_FILE = reaper.GetResourcePath() .. "/" .. jSettingsGet(SETTINGS, 'ultraschall_api_file', "string")

	PREFER_VST3 = 		jSettingsGet(SETTINGS, 'prefer_vst3', "boolean")
	ITEM_SHOW_FLAG = jSettingsGet(SETTINGS, 'item_show_flag', "number")
	TRACK_SHOW_FLAG = jSettingsGet(SETTINGS, 'track_show_flag', "number")


	TEMPLATE_ROOT_DIR = reaper.GetResourcePath() .. "/" .. jSettingsGet(SETTINGS, 'template_root_dir', "string")
	FXCHAIN_ROOT_DIR = 	reaper.GetResourcePath() .. "/" .. jSettingsGet(SETTINGS, 'fxchain_root_dir', "string")
	
	PLUGIN_BLACKLIST_ENABLE = 	jSettingsGet(SETTINGS, 'plugin_blacklist_enable', "boolean")
	TEMPLATE_SUBDIRS_ENABLE = 	jSettingsGet(SETTINGS, 'template_subdirs_enable', "boolean")
	FXCHAIN_SUBDIRS_ENABLE = 	jSettingsGet(SETTINGS, 'fxchain_subdirs_enable', "boolean")
	
	-- RESULTS_PER_PAGE = jSettingsGet(SETTINGS, 'results_per_page', "number")
	MAX_RESULTS = jSettingsGet(SETTINGS, 'max_results', "number")

	WINDOW_WIDTH = jSettingsGet(SETTINGS, 'window_width', "number")
	WINDOW_HEIGHT = jSettingsGet(SETTINGS, 'window_height', "number")
	WINDOW_X = jSettingsGet(SETTINGS, 'window_x', "number")
	WINDOW_Y = jSettingsGet(SETTINGS, 'window_y', "number")
	WINDOW_SAVE_STATE = jSettingsGet(SETTINGS, 'window_save_state', "boolean")
	WINDOW_DOCK_STATE = jSettingsGet(SETTINGS, 'window_dock_state', "number")
	GUI_SIZE = jSettingsGet(SETTINGS, 'gui_size', "number")
	

	if PLUGIN_BLACKLIST_ENABLE then
		PLUGIN_BLACKLIST = jSettingsGet(SETTINGS, 'plugin_blacklist_regex', "table")
	else
		PLUGIN_BLACKLIST = {}
	end

	if TEMPLATE_SUBDIRS_ENABLE then
		TEMPLATE_SUB_DIRS = 	_joinSettingsTables(	jSettingsGet(SETTINGS, 'template_subdirs_dir', "table"), 
														jSettingsGet(SETTINGS, 'template_subdirs_rec', "table")
													)
	else
		TEMPLATE_SUB_DIRS = {{"", true}}
	end
	
	if FXCHAIN_SUBDIRS_ENABLE then
		FXCHAIN_SUB_DIRS = 		_joinSettingsTables(	jSettingsGet(SETTINGS, 'fxchain_subdirs_dir', "table"), 
														jSettingsGet(SETTINGS, 'fxchain_subdirs_rec', "table")
													)
	else
		FXCHAIN_SUB_DIRS = {{"", true}}
	end

	-- -- Load Ultraschall Api if available
	-- ULTRASCHALL_API_ENABLED = reaper.file_exists(ULTRASCHALL_API_FILE)
	-- if ULTRASCHALL_API_ENABLED then
	-- 	dofile(ULTRASCHALL_API_FILE)
	-- end

	return true
end

if init() then
	loop()
end

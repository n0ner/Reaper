--[[
@author n0ne
@version 0.7.1
@noindex
--]]

jGuiColors = {}

function jGuiColors:get(sColor, opacity)
	opacity = opacity or 1
	
	local myColors = {
		white 			= 	    {	1,		1, 		1		},
		black 			= 	    {	0, 		0, 		0		},
		red 			=    	{	1, 		0, 		0		},
		green 			= 	    {	0, 		1, 		0		},
		blue 			=    	{	0,	 	0, 		1		},
		yellow			=		{	1,		1,		0		}
	} 
	
	if not myColors[sColor] then
		msg("Unknown color: " .. sColor)
		return false
	end
	local res = {table.unpack(myColors[sColor])}
	res[4] = opacity
	return res
end

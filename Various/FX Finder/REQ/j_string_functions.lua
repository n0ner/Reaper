--[[
@author n0ne
@version 0.7.0
@noindex
--]]

function jStringExplode(s, sep)
    -- Explode a string by seperator
    -- Returns #1: Table with parts
    -- Returns #2: Amount of times the seperator can be found
    -- If the seperator is NOT found it will return a table with 1 element and 0.
    local tResult = {}
    local i = 0
    
    -- Check if the seperator  is found
    -- if not s:find(sep, 1, true) then
    --     table.insert(tResult, s)
    --     return tResult, i
    -- end


    local run = true
    local start = 1
    while run do
        local begin, fin = s:find(sep, start, true)
        if begin then
            table.insert(tResult, s:sub(start, fin - #sep))
            start = fin + 1
            i = i + 1
        else
            table.insert(tResult, s:sub(start, s:len()))
            run = false
        end
    end


    return tResult, i
end


function jStringExplodeOld(s, sep)
    -- Explode a string by seperator
    -- Returns #1: Table with parts
    -- Returns #2: Amount of times the seperator can be found
    -- If the seperator is NOT found it will return a table with 1 element and 0.
    local tResult = {}
    local i = 0
    
    -- Check if the seperator  is found
    if not s:find(sep, 1, true) then
        table.insert(tResult, s)
        return tResult, i
    end

    for st in string.gmatch(s, "(.-)" .. sep) do
        table.insert(tResult, st)
        i = i + 1
    end
    for st in string.gmatch(s, sep .. "(.+)$") do
        i = i + 1
        table.insert(tResult, st)
    end

    return tResult, i
end

function jStringTrim(s)
    return s:match "^%s*(.-)%s*$"
end

function jStringIsInt(s)
    local r = s:match("^(%d+)$")
    return r ~= nil
end
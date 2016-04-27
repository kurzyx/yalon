--[[
    
    Copyright (c) 2016 Kevin G
        aka Kurtzalead https://github.com/kurtzalead
    Licensed under MIT (https://github.com/kurtzalead/yalon/blob/master/LICENSE.md)
    
    ----------------------------------------------------------------------------
    
    YALON 1.00.00
    Yet Another Lua Object Notation
    
]]

yalon = {}

local error = function(message)
    error(debug.traceback("YALON: "..message, 2))
end

local pairs = pairs
local ipairs = ipairs
local type = type

local string_find = string.find
local string_sub = string.sub

local table_concat = table.concat

-- Serialize
do
    
    local
        valueSerializers,
        typeSerializers
    
    valueSerializers = {
        ["string"] = function()
            
            local escapedChars = {
                ["\""] = "\\\"",
                ["\\"] = "\\\\",
                ["\b"] = "\\b",
                ["\f"] = "\\f",
                ["\n"] = "\\n",
                ["\r"] = "\\r",
                ["\t"] = "\\t"
            }
            
            local escapedCharsNum = {}
            for k, v in pairs(escapedChars) do
                escapedCharsNum[#escapedCharsNum + 1] = k
            end
            
            local pattern = "["
            for k, v in pairs(escapedChars) do
                pattern = pattern..k
            end
            pattern = pattern.."]"
            
            --[[
            - @arg table t The table we store all strings in
            - @arg number i The table's current index
            - @arg string v The value we need to serialize
            - @retur number
            ]]
            return function(t, i, v)
                
                local b, e, bt = 1, 1, nil
                
                i = i + 1
                t[i] = "\""
                
                while true do
                    
                    -- TODO: Try to optimize this better
                    
                    e = #v + 1
                    
                    for x=1, #escapedCharsNum do
                        bt = string_find(v, escapedCharsNum[x], b, true)
                        if bt ~= nil and bt < e then
                            e = bt
                        end
                    end
                    
                    if e == #v + 1 then
                        i = i + 1
                        t[i] = string_sub(v, b, #v)
                        break
                    end
 
                    t[i + 1] = string_sub(v, b, e - 1)
                    i = i + 2
                    t[i] = escapedChars[string_sub(v, e, e)]
                    
                    b = e + 1

                end
                
                i = i + 1
                t[i] = "\""
                
                return i
            end
        end,
        ["number"] = function()
        
            --[[
            - @arg table t The table we store all strings in
            - @arg number i The table's current index
            - @arg number v The value we need to serialize
            - @retur number
            ]]
            return function(t, i, v)
                
                i = i + 1
                
                -- As simple as that
                t[i] = v
                
                return i
            end
        end,
        ["boolean"] = function()
            
            --[[
            - @arg table t The table we store all strings in
            - @arg number i The table's current index
            - @arg bool v The value we need to serialize
            - @retur number
            ]]
            return function(t, i, v)
                
                i = i + 1
                if v == true then
                    t[i] = "true"
                else
                    t[i] = "false"
                end
                
                return i
            end
        end,
        ["table"] = function()
            
            local function isSequential(t)
                local i = 0
                for _ in pairs(t) do
                    i = i + 1
                    if t[i] == nil then return false end
                end
                return true
            end
            
            --[[
            - @arg table t The table we store all strings in
            - @arg number i The table's current index
            - @arg table v The value we need to serialize
            - @arg table tc The table cache for reference
            - @retur number
            ]]
            return function(t, i, v, tc)
                
                if tc[v] == nil then
                    
                    -- Reserve an index for reference
                    i = i + 1
                    t[i] = ""
                    
                    -- Table refers to the reserved index
                    tc[v] = i
                    
                else
                    
                    local ti = tc[v]
                    
                    -- Set the declaring reference if not set (This is always if the table is used for the second time)
                    if t[ti] == "" then
                        tc[1] = tc[1] + 1
                        t[ti] = "&"..tc[1].."="
                    end
                    
                    i = i + 1
                    t[i] = string_sub(t[ti], 1, #t[ti] - 1)
                    
                    return i -- And return because we don't have to declare the table again
                end
                
                -- Numeric
                if isSequential(v) then
                    
                    i = i + 1
                    t[i] = "["
                    
                    local l = i
                    
                    -- Iterrate through each value
                    for _, _v in ipairs(v) do
                        
                        i = typeSerializers[type(_v)](t, i, _v, tc)
                        
                        i = i + 1
                        t[i] = ","
                        
                    end
                    
                    -- Remove last comma if there is at least one value in the table
                    if l == i then
                        i = i + 1
                        t[i] = "]"
                    else
                        t[i] = "]"
                    end
                
                -- Generic
                else
                    
                    i = i + 1
                    t[i] = "{"
                    
                    local l = i
                    
                    -- Iterrate through each value
                    for _k, _v in pairs(v) do
                        
                        i = typeSerializers[type(_k)](t, i, _k, tc) -- Key
                        
                        i = i + 1
                        t[i] = ":"
                        
                        i = typeSerializers[type(_v)](t, i, _v, tc) -- Value
                        
                        i = i + 1
                        t[i] = ","
                        
                    end
                    
                    -- Remove last comma if there is at least one value in the table
                    if l == i then
                        i = i + 1
                        t[i] = "}"
                    else
                        t[i] = "}"
                    end
                    
                end
                
                return i
            end
        end
    }
    
    typeSerializers = {
        
        ["string"] = valueSerializers["string"](),
        ["boolean"] = valueSerializers["boolean"](),
        ["table"] = valueSerializers["table"](),
        ["number"] = valueSerializers["number"](),
        
        -- On unsupported type
        __index = function(self, t)
            return function(s, i, v)
                error(("Unsupported type '%s' can not be serialized."):format(t))
            end
        end
        
    }
    setmetatable(typeSerializers, typeSerializers)
    
    --[[
    - @arg any v The value to serialize
    - @return string
    ]]
    function yalon.serialize(v)
        
        -- The table all strings will be put in to be concatenated
        local t = {}
        
        -- Any supported value is allowed
        typeSerializers[type(v)](t, 0, v, {[1] = 0})
        
        -- Return the concatenated table
        return table_concat(t)
    end
    
end

-- Deserialize
do
    
    local whitespacing = {
        [' '] = true,
        ['  '] = true,
        ['\n'] = true,
        ['\r'] = true
    }
    
    local
        valueDeserializers,
        characterDeserializers
    
    valueDeserializers = {
        ["string"] = function()
            
            local escapedChars = {
                ["\""] = "\"",
                ["\\"] = "\\",
                ["b"] = "\b",
                ["f"] = "\f",
                ["n"] = "\n",
                ["r"] = "\r",
                ["t"] = "\t"
            }
            
            --[[
            - @arg string s The string we are parsing
            - @arg number i The index of the string we are currently at
            - @return number, string
            ]]
            return function(s, i)
                
                local c, v = nil, ""
                local p1, p2
                
                i = i + 1
                
                while true do
                    
                    -- Faster than patterns
                    p1 = string_find(s, "\"", i, true)
                    p2 = string_find(s, "\\", i, true)
                    
                    if p1 == nil then
                        error("Unexpected end of string while parsing string.")
                    end
                    
                    if p2 ~= nil and p2 < p1 then
                        
                        p2 = p2 + 1
                        c = string_sub(s, p2, p2)
                        
                        if escapedChars[c] ~= nil then
                            v = v..string_sub(s, i, p2 - 2)..escapedChars[c]
                            i = p2 + 1
                        else
                            error(("Invalid escaped character '%s' at index %d."):format(c, p2))
                        end
                        
                    else
                        return p1, v..string_sub(s, i, p1 - 1)
                    end
                    
                end
                
            end
        end,
        ["number"] = function()
            
            --[[
            - @arg string s The string we are parsing
            - @arg number i The index of the string we are currently at
            - @return number, number
            ]]
            return function(s, i)
                local b, e = string_find(s, "^%-?%d*%.?%d+", i)
                if e == nil then
                    error(("Unexpected end of number at index %d."):format(i - 1))
                end
                return e, tonumber(string_sub(s, b, e))
            end
        end,
        ["boolean"] = function(bool)
            
            --[[
            - @arg string s The string we are parsing
            - @arg number i The index of the string we are currently at
            - @return number, bool
            ]]
            if bool == true then
                return function(s, i)
                    
                    -- Cache the next character
                    local c = string_sub(s, i, i + 3)
                    
                    if c == "true" then
                        return i + 3, true
                    end
                    
                    if c == "" then -- End of string
                        error("Unexpected end of string while parsing boolean.")
                    else
                        error(("Unexpected end of boolean for character '%s' at index %d."):format(c, i))
                    end
                    
                end
            else
                return function(s, i)
                    
                    -- Cache the next character
                    local c = string_sub(s, i, i + 4)
                    
                    if c == "false" then
                        return i + 4, false
                    end
                    
                    if c == "" then -- End of string
                        error("Unexpected end of string while parsing boolean.")
                    else
                        error(("Unexpected end of boolean for character '%s' at index %d."):format(c, i))
                    end
                    
                end
            end
            
        end,
        ["table-numeric"] = function()
            
            local EXPECT_VALUE = 1
            local EXPECT_END = 2
            
            --[[
            - @arg string s The string we are parsing
            - @arg number i The index of the string we are currently at
            - @arg table tc The table cache for reference
            - @arg table|nil t The new table to use (may be nil)
            - @return number, table
            ]]
            return function(s, i, tc, t)
                
                local c = nil
                
                if t == nil then
                    t = {}
                end

                -- What to expect next
                local expect = EXPECT_VALUE

                -- Loop through characters
                while true do

                    -- Cache the next character
                    i = i + 1
                    c = string_sub(s, i, i)
                    
                    -- Whitespacing
                    if whitespacing[c] then
                        -- Continue to the next character

                    -- Expect value or end of table
                    elseif expect == EXPECT_VALUE then

                        -- End of table is also possible
                        if c == "]" then
                            return i, t
                        end

                        i, t[#t + 1] = characterDeserializers[c](s, i, tc)
                        expect = EXPECT_END

                    -- Expect end of table or value seperator
                    elseif c == "," then
                        expect = EXPECT_VALUE
                    elseif c == "]" then
                        return i, t

                    -- Error on unexpected end of table
                    else
                        if c == "" then -- End of string
                            error("Expected end of numeric table instead of end of string.")
                        else
                            error(("Expected end of numeric table instead of character '%s' at index %d."):format(c, i))
                        end
                    end

                end

            end
        end,
        ["table-generic"] = function()
            
            local EXPECT_KEY = 1
            local EXPECT_KEY_VALUE_SEPERATOR = 2
            local EXPECT_VALUE = 3
            local EXPECT_END = 4

            --[[
            - @arg string s The string we are parsing
            - @arg number i The index of the string we are currently at
            - @arg table tc The table cache for reference
            - @arg table|nil t The new table to use (may be nil)
            - @return number, table
            ]]
            return function(s, i, tc, t)
                
                local c = nil
                
                if t == nil then
                    t = {}
                end

                -- The last parsed key
                local key

                -- What to expect next
                local expect = EXPECT_KEY

                -- Loop through characters
                while true do

                    -- Cache the next character
                    i = i + 1
                    c = string_sub(s, i, i)

                    -- Whitespacing
                    if whitespacing[c] then
                        -- Continue to the next character

                    -- Expect key or end of table
                    elseif expect == EXPECT_KEY then

                        -- End of table is also possible
                        if c == "}" then
                            return i, t
                        end

                        i, key = characterDeserializers[c](s, i, tc)
                        expect = EXPECT_KEY_VALUE_SEPERATOR

                    -- Expect value
                    elseif expect == EXPECT_VALUE then

                        i, t[key] = characterDeserializers[c](s, i, tc)
                        expect = EXPECT_END

                    -- Expect key value seperator
                    elseif expect == EXPECT_KEY_VALUE_SEPERATOR then

                        -- Expect key value seperator
                        if c == ":" then
                            expect = EXPECT_VALUE
                        else
                            if c == "" then -- End of string
                                error("Expected key value seperator ':' instead of end of string while parsing generic table.")
                            else
                                error(("Expected key value seperator ':' instead of character '%s' at index %d while parsing generic table."):format(c, i))
                            end
                        end

                    -- Expect end of table or value seperator
                    elseif c == "," then
                        expect = EXPECT_KEY
                    elseif c == "}" then
                        return i, t

                    -- Error on unexpected end of table
                    else
                        if c == "" then -- End of string
                            error("Expected end of generic table instead of end of string.")
                        else
                            error(("Expected end of generic table instead of character '%s' at index %d."):format(c, i))
                        end
                    end

                end

            end
        end,
        ["table-reference"] = function()
            
            --[[
            - @arg string s The string we are parsing
            - @arg number i The index of the string we are currently at
            - @arg table tc The table cache for reference
            - @return number, table
            ]]
            return function(s, i, tc)
                
                -- Get the reference id
                local b, i, ri = string_find(s, "^&(%w+)", i)
                
                if i == nil then
                    error("Unexpected end of string while parsing reference.")
                end
                
                local declaring = false
                
                -- Loop through characters
                while true do

                    -- Cache the next character
                    i = i + 1
                    c = string_sub(s, i, i)
                    
                    -- Whitespacing
                    if whitespacing[c] then
                        -- Continue to the next character
                    
                    -- Reference declaration
                    elseif declaring == false and c == "=" then
                        declaring = true
                    
                    elseif c == "" then

                        -- End of string?
                        error("Unexpected end of string while parsing reference.")

                    else
                        
                        if declaring == true then
                            
                            local v = {}
                            
                            -- Cache the reference before parsing the table
                            -- This means we don't have to declare the reference
                            -- In the most inner table if needed
                            tc[ri] = v
                            
                            i, v = characterDeserializers[c](s, i, tc, v)
                            tc[ri] = v -- References may not be tables
                            
                            return i, v
                        else
                            
                            if tc[ri] == nil then
                                error(("Undeclared reference '%s' at index %d."):format(ri, i))
                            end
                            
                            return i - 1, tc[ri]
                        end
                        
                    end

                end
                
            end
        end,
    }
    
    characterDeserializers = {
        
        -- String
        ["\""] = valueDeserializers["string"](),
        
        -- Table
        ["["] = valueDeserializers["table-numeric"](),
        ["{"] = valueDeserializers["table-generic"](),
        
        -- Reference
        ["&"] = valueDeserializers["table-reference"](),
        
        -- Boolean
        ["t"] = valueDeserializers["boolean"](true),
        ["f"] = valueDeserializers["boolean"](false),
        
        -- Numbers
        ["0"] = valueDeserializers["number"](),
        ["1"] = valueDeserializers["number"](),
        ["2"] = valueDeserializers["number"](),
        ["3"] = valueDeserializers["number"](),
        ["4"] = valueDeserializers["number"](),
        ["5"] = valueDeserializers["number"](),
        ["6"] = valueDeserializers["number"](),
        ["7"] = valueDeserializers["number"](),
        ["8"] = valueDeserializers["number"](),
        ["9"] = valueDeserializers["number"](),
        ["-"] = valueDeserializers["number"](),
        
        -- On undefined character
        __index = function(self, c)
            return function(s, i)
                if c == "" then
                    error(("Unexpected end of string while trying to parse a value."):format(c, i))
                else
                    error(("Can't find use for character '%s' at index %d."):format(c, i))
                end
            end
        end
        
    }
    setmetatable(characterDeserializers, characterDeserializers)
    
    --[[
    - @arg string s The string to deserialize
    - @return any
    ]]
    function yalon.deserialize(s)
        
        local i, v = 0, nil
        
        -- Loop through characters
        while true do

            -- Cache the next character
            i = i + 1
            c = string_sub(s, i, i)
            
            -- Whitespacing
            if whitespacing[c] then
                -- Continue to the next character
            
            elseif c == "" then
                
                -- Empty string?
                error("Can not parse an empty string.")
                
            else
                
                -- We can parse any value that is supported
                i, v = characterDeserializers[c](s, i, {})
                
                return v
            end
            
        end
        
    end
    
end

-- Version of YALON
yalon.version = "1.00.00"
yalon.version_nr = 10000

return yalon
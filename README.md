# YALON
**Y**et **A**nother **L**ua **O**bject **N**otation

## Example
```Lua
local dataString = [[
  {
    "format" : [1, 2, 4, 8, 16, 32, 64, 128],
    "data" : {
      1 : "Some data at index 1",
      2 : "Some data at index 2",
      4 : "Some data at index 4",
      8 : "Some data at index 8",
      16 : "Some data at index 16",
      32 : "Some data at index 32",
      64 : "Some data at index 64",
      128 : "Some data at index 128"
    }
  }
]]

local table = yalon.deserialize(dataString)
local format, data = table.format, table.data

local _1 = data[format[1]]
local _2 = data[format[2]]
local _3 = data[format[3]]
local _4 = data[format[4]]
local _5 = data[format[5]]
local _6 = data[format[6]]
local _7 = data[format[7]]
local _8 = data[format[8]]

print(_1, _2, _3, _4, _5, _6, _7, _8)
-- out: Some data at index 1  Some data at index 2  Some data at index 4  ...
```

##### References
```Lua
local dataString = [[
  {
    "reference" : &a = ["This is a string."],
    &a : "You got it!"
  }
]]

local table = yalon.deserialize(dataString)

local reference = table.reference

print(table[reference])
-- out: You got it!
```

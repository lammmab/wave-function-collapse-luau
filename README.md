# Wave Function Collapse

## Description
Wave function collapse is an algorithm that describes the transition of a quantum particle from superposition to a collapsed state.
This is what WaveFunctionCollapse.luau aims to replicate, as performantly as I can get it.

## Disclaimer:
Do not expect very good implementation.

## Usage
```lua
local WFC = require("./WaveFunctionCollapse")
local WIDTH = 4
local HEIGHT = 4

-- rules
local tileset = {
    tiles = { "STRAIGHT_H", "STRAIGHT_V", "CURVE_NE", "CURVE_NW", "EMPTY" },
    rules = {
        STRAIGHT_H = {
            N = {"EMPTY", "CURVE_NE", "CURVE_NW"},
            E = {"STRAIGHT_H", "CURVE_NE", "CURVE_NW"},
            S = {"EMPTY", "CURVE_NE", "CURVE_NW"},
            W = {"STRAIGHT_H", "CURVE_NE", "CURVE_NW"},
        },
        STRAIGHT_V = {
            N = {"STRAIGHT_V", "CURVE_NE", "CURVE_NW"},
            E = {"EMPTY", "CURVE_NE", "CURVE_NW"},
            S = {"STRAIGHT_V", "CURVE_NE", "CURVE_NW"},
            W = {"EMPTY", "CURVE_NE", "CURVE_NW"},
        },
        CURVE_NE = {
            N = {"STRAIGHT_V", "CURVE_NW"},
            E = {"STRAIGHT_H", "CURVE_NW"},
            S = {"EMPTY"},
            W = {"EMPTY"},
        },
        CURVE_NW = {
            N = {"STRAIGHT_V", "CURVE_NE"},
            E = {"EMPTY"},
            S = {"EMPTY"},
            W = {"STRAIGHT_H", "CURVE_NE"},
        },
        EMPTY = {
            N = {"*"},
            E = {"*"},
            S = {"*"},
            W = {"*"},
        },
    }
}

-- Create 4x4 WFC
local WaveFunctionCollapse = WFC.new(tileset, WIDTH, HEIGHT)

-- Run the WFC
local result = WaveFunctionCollapse:Run()

-- Print a structured map
if result then
    for y = 1, #result[1] do
        local row = {}
        for x = 1, #result do
            table.insert(row, result[x][y])
        end
        print(table.concat(row, "\t"))
    end
else
    print("WFC failed to generate a map.")
end


```

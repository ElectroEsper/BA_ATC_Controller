API.Print("ATC :: Grid Manager")

if not _G.initialized then
    
    _G.CELL_SIZE = 500 -- (meters)
    _G.initialized = true
end


function UpdateGrid()
    DebugMsg("Grid Manager :: Begin Grid Update")
    local grid = {}
    -- Player Support
    if input_1 and input_1.Count > 0 then
        DebugMsg("Grid Manager :: " .. input_1.Count .. " player support unit(s)")
        local list = input_1.GetList
        for i = 1, input_1.Count do
            local group = input_1.Clone()
            group.Clear()
            group.Add(list[i])
            local unit = API.ConvertToLuaUnit(group)
            if unit == nil then
                DebugMsg("Warning: Nil unit after ConvertToLuaUnit at index " .. tostring(i))
            else
                local pos = unit.GetPosition()
                local x, y = GetCell(pos[0], pos[2])
                --EnsureCell(grid, x, y)["player_support"]
                table.insert(EnsureCell(grid, x, y)["player_support_unit"], unit.UID)
            end
        end
    else
        DebugMsg("Grid Manager :: No player support unit")
    end

    -- Player Combat
    if input_2 and input_2.Count > 0 then
        DebugMsg("Grid Manager :: " .. input_2.Count .. " player combat unit(s)")
        local list = input_2.GetList
        for i = 1, input_2.Count do
            local group = input_2.Clone()
            group.Clear()
            group.Add(list[i])
            local unit = API.ConvertToLuaUnit(group)
            if unit == nil then
                DebugMsg("Warning: Nil unit after ConvertToLuaUnit at index " .. tostring(i))
            else
                local pos = unit.GetPosition()
                local x, y = GetCell(pos[0], pos[2])
                --EnsureCell(grid, x, y)["player_combat"] = EnsureCell(grid, x, y)["player_combat"] + 1
                table.insert(EnsureCell(grid, x, y)["player_combat_unit"], unit.UID)
                --EnsureCell(grid, x, y)["diff_cnt"] = EnsureCell(grid, x, y)["diff_cnt"] + 1
            end
        end
    else
        DebugMsg("Grid Manager :: No player combat unit")
    end

    -- AI Combat
    if input_3 and input_3.Count > 0 then
        DebugMsg("Grid Manager :: " .. input_3.Count .. " AI combat unit(s)")
        local list = input_3.GetList
        for i = 1, input_3.Count do
            local group = input_3.Clone()
            group.Clear()
            group.Add(list[i])
            local unit = API.ConvertToLuaUnit(group)
            if unit == nil then
                DebugMsg("Warning: Nil unit after ConvertToLuaUnit at index " .. tostring(i))
            else
                local pos = unit.GetPosition()
                local x, y = GetCell(pos[0], pos[2])
                --EnsureCell(grid, x, y)["ai_combat"] = EnsureCell(grid, x, y)["ai_combat"] + 1
                table.insert(EnsureCell(grid, x, y)["ai_combat_unit"], unit.UID)
                --EnsureCell(grid, x, y)["diff_cnt"] = EnsureCell(grid, x, y)["diff_cnt"] - 1
            end
        end
    else
        DebugMsg("Grid Manager :: No AI combat unit")
    end

    local air_contacts = {}
    if input_4 and input_4.Count > 0 then
        DebugMsg("Grid Manager :: " .. input_4.Count .. " Player Aircraft(s)")
        local list = input_4.GetList
        for i = 1, input_4.Count do
            local group = input_4.Clone()
            group.Clear()
            group.Add(list[i])
            local unit = API.ConvertToLuaUnit(group)
            if unit == nil then
                DebugMsg("Warning: Nil unit after ConvertToLuaUnit at index " .. tostring(i))
            else
                table.insert(air_contacts,unit.UID)
            end
        end
    else
        DebugMsg("Grid Manager :: No Player Aircraft")
    end



    DebugMsg("Grid Manager :: Grid Update Complete")
    DebugMsg(json.serialize(grid))
    DebugMsg(json.serialize(air_contacts))
    output_1 = json.serialize(grid)
    output_2 = json.serialize(air_contacts)
    output_5 = 1

    --CompleteWithOutput()
end

-- HELPER FUNCTIONS
--- Ensure the grid exists at a given x,y
function EnsureCell(grid, x, y)
    if not grid[tostring(x)] then grid[tostring(x)] = {} end
    if not grid[tostring(x)][tostring(y)] then
        grid[tostring(x)][tostring(y)] = {
            ["ai_combat_unit"] = {},
            ["player_combat_unit"] = {},
            ["player_support_unit"] = {}
        }
    end
    return grid[tostring(x)][tostring(y)]
end

--- Convert world position to grid coordinates
function GetCell(x, z)
    local grid_x = math.floor(x / CELL_SIZE)
    local grid_y = math.floor(z / CELL_SIZE)
    return grid_x, grid_y
end

---
function DebugMsg(message)
    API.Print(message)
end





if not _G.initialized then
    _G.scheduled_strikes = {}
    _G.initialized = true
end


function Evaluator()
    local task = input_5
    output_1 = nil
    output_2 = nil
    output_5 = 0

    if task ~= 1 then return end
    local grid = json.parse(input_1)
    local air_grid = json.parse(input_2)
    local candidates = {}

    -- Sends Air contact dirrectly to Coordinator
    --DebugMsg("Evaluator :: Air target received => " .. input_2)
    --output_2 = input_2

    for x, col in pairs(grid) do
        for y, cell in pairs(col) do
            if ShouldCallStrike(cell) then
                table.insert(candidates, {["x"] = x, ["y"] = y, ["target_uid"] = cell["player_combat_unit"]})
            end
        end
    end

    if #candidates > 0 then
        DebugMsg("Evaluator :: " .. #candidates .. " candidates found")
        DebugMsg("Evaluator :: " .. json.serialize(candidates))
        output_1 = json.serialize(candidates)
        output_5 = 1
        CompleteWithOutput()
    else
        DebugMsg("Evaluator :: No candidates found")

    end
    
    if #air_grid > 0 then
        DebugMsg("Evaluator :: " .. #air_grid .. " bandit found")
        DebugMsg("Evaluator :: " .. json.serialize(air_grid))
        output_2 = input_2
        output_5 = 1
    else
        DebugMsg("Evaluator :: No bandit found")

    end

end

function ShouldCallStrike(cell)
    local player_units, ai_units
    local score = 0
    --DebugMsg(#cell["ai_combat_unit"])
    local ai_units = #cell["ai_combat_unit"]
    local player_units = #cell["player_combat_unit"]
    local diff = player_units - ai_units

    -- Enemy density
    --score = score + player_units

    -- Diff
    score = score + diff

    return score >= 5
end


-- HELPER
function DebugMsg(message)
    API.Print(message)
end
function GetCell(x, z)
    local grid_x = math.floor(x / CELL_SIZE)
    local grid_y = math.floor(z / CELL_SIZE)
    return grid_x, grid_y
end
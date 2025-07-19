if not _G.initialized then
    _G.fragged_cells = {}
    _G.fragged_air_targets = {}
    _G.initialized = true
    _G.userdata = nil
end


function Coordinator()
    if _G.userdata == nil then
        SetEmptyUserData()
    end

    output_1 = nil
    output_5 = 0

    DebugMsg("Flight Coordinator :: Begin")
    local task = input_5
    if task == 0 then
        DebugMsg("Flight Coordinator :: No candidates, exiting")
        CleanupFragged({})
        CleanupFraggedAir({}, _G.fragged_air_targets)
        output_1 = nil
        output_5 = 0
        return
    elseif task == 1 then

        local target_list = {}

        if type(input_1) == "string" then
            target_list = json.parse(input_1) or {}
        else
            DebugMsg("Flight Coordinator :: No input target")
        end

        CleanupFragged(target_list)

        for _, cell in ipairs(target_list) do
            local x = cell["x"]
            local y = cell["y"]
            local target_uid = cell["target_uid"]

            -- Initialize column if missing
            if not _G.fragged_cells[x] then
                _G.fragged_cells[x] = {}
            end

            -- Skip if already fragged...
            if not _G.fragged_cells[x][y] then
                DebugMsg("Flight Coordinator :: Assigning strike to cell [" .. tonumber(x) .. "," .. tonumber(y) .. "]")

                _G.fragged_cells[x][y] = true

                local cell_being_fragged = { x = tonumber(x), y = tonumber(y), ["target_uid"] = target_uid}
                
                DebugMsg("Flight Coordinator :: Sending fragged cell")
                
                output_1 = json.serialize(cell_being_fragged)
                output_5 = 1 -- strike request
                CompleteWithOutput()
                DebugMsg("Flight Coordinator :: Fragged cell sent")
            else
                DebugMsg("Flight Coordinator :: Skipped already fragged")
                output_1 = nil
                output_5 = 0
                CompleteWithOutput()
            end

        end
        DebugMsg("Flight Coordinator :: No unfragged target found")


        -- ================ CAP HANDLING ================ --

        local air_targets = {}

        if type(input_2) == "string" then
            air_targets = json.parse(input_2) or {}
        else
            DebugMsg("Flight Coordinator :: input_2 is not a valid string (nil or wrong type)")
            return
        end

        CleanupFraggedAir(air_targets, _G.fragged_air_targets)

        for _, uid in ipairs(air_targets) do
            if not _G.fragged_air_targets[uid] then
                DebugMsg("Flight Coordinator :: Assigning CAP against UID " .. uid)
                _G.fragged_air_targets[uid] = true

                output_1 = json.serialize({ uid })
                output_5 = 2 -- Task CAP
                DebugMsg("Flight Coordinator :: CAP data sent")
                return -- Only one CAP assigned per tick
            end
        end
        
        DebugMsg("Flight Coordinator :: Ended without new tasking")
    end
end    


function CleanupFragged(target_list)
    -- If a fragged cell is not in the target list, it should be removed, as we can assume it isn't relevant anymore...
    DebugMsg("Flight Coordinator :: Cleaning up fragged cells")

    -- Build a quick-lookup set of valid target keys
    local valid_targets = {}
    for _, cell in ipairs(target_list) do
        local x = cell["x"]
        local y = cell["y"]
        if not valid_targets[x] then
            valid_targets[x] = {}
        end
        valid_targets[x][y] = true
    end

    -- Iterate through current fragged_cells and remove those not in valid_targets
    for x, col in pairs(_G.fragged_cells) do
        for y, _ in pairs(col) do
            if not (valid_targets[x] and valid_targets[x][y]) then
                DebugMsg("Flight Coordinator :: Removing stale fragged cell [" .. x .. "," .. y .. "]")
                _G.fragged_cells[x][y] = nil
            end
        end
        -- Clean up empty column
        if next(_G.fragged_cells[x]) == nil then
            _G.fragged_cells[x] = nil
        end
    end
end

function CleanupFraggedAir(air_targets, fragged_air)
    DebugMsg("Coordinator :: Cleaning fragged CAP targets")
    local valid = {}
    for _, uid in ipairs(air_targets) do
        valid[uid] = true
    end

    for uid, _ in pairs(fragged_air) do
        if not valid[uid] then
            DebugMsg("Coordinator :: Removing stale CAP target UID " .. uid)
            fragged_air[uid] = nil
        end
    end
end
-- Helper
function SetEmptyUserData()
    local unit = input_4.Clone()
    unit.Clear()
    _G.userdata = unit
end

function DebugMsg(message)
    API.Print(message)
end

function GetUnitFromId(uid)
end
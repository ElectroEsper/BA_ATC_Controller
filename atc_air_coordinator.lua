if not _G.initialized then
    _G.fragged_cells = {}
    _G.fragged_air_targets = {}
    _G.initialized = true
    _G.userdata = nil
end

function Coordinator()
    if _G.userdata == nil then SetEmptyUserData() end

    output_1 = nil
    output_5 = 0

    DebugMsg("Flight Coordinator :: Begin")
    local task = input_5

    if task == 0 then
        DebugMsg("Flight Coordinator :: No candidates, exiting")
        CleanupFragged({})
        CleanupFraggedAir({}, _G.fragged_air_targets)
        return

    elseif task == 1 then
        HandleStrikeTargets()
        HandleAirTargets()
        DebugMsg("Flight Coordinator :: Ended without new tasking")
    end
end

function HandleStrikeTargets()
    local target_list = {}
    if type(input_1) == "string" then
        target_list = json.parse(input_1) or {}
    else
        DebugMsg("Flight Coordinator :: No input target")
    end

    CleanupFragged(target_list)

    for _, cell in ipairs(target_list) do
        local x, y = tonumber(cell["x"]), tonumber(cell["y"])
        local target_uid = cell["target_uid"]

        if not _G.fragged_cells[x] then _G.fragged_cells[x] = {} end

        if not _G.fragged_cells[x][y] then
            DebugMsg("Flight Coordinator :: Assigning strike to cell [" .. x .. "," .. y .. "]")
            _G.fragged_cells[x][y] = true

            local cell_being_fragged = { x = x, y = y, target_uid = target_uid }
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
end

function HandleAirTargets()
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
end

function CleanupFragged(target_list)
    DebugMsg("Flight Coordinator :: Cleaning up fragged cells")
    local valid_targets = {}
    for _, cell in ipairs(target_list) do
        local x, y = cell["x"], cell["y"]
        if not valid_targets[x] then valid_targets[x] = {} end
        valid_targets[x][y] = true
    end

    for x, col in pairs(_G.fragged_cells) do
        for y, _ in pairs(col) do
            if not (valid_targets[x] and valid_targets[x][y]) then
                DebugMsg("Flight Coordinator :: Removing stale fragged cell [" .. x .. "," .. y .. "]")
                _G.fragged_cells[x][y] = nil
            end
        end
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
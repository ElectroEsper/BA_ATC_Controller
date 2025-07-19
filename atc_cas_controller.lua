-- CAS Controller
-- Handles tasking of CAS planes, strike execution, and rearming cycles

if not _G.initialized then
    _G.initialized = true
    _G.targets = {}                -- Active target cells being engaged
    _G.plane_tasking = {}         -- Maps plane UID to target grid
    _G.assets = {
        ready = 1,
        busy = 0,
        rearming = 0,
        rearming_timer = {},
        regen_timer = {},
        tasked = {}
    }
    _G.target_queue = {
        head = 1,
        tail = 1,
        max = 20,
        targets = {}
    }
    _G.awaiting_plane_spawn = false
    _G.rearming_time = 5 -- seconds
    _G.regen_time = 10 -- seconds

    _G.userdata = nil
end

function Controller()
    if _G.userdata == nil then
        SetEmptyUserData()
    end

    local task = input_5
    output_1 = nil
    output_2 = nil
    output_5 = 0

    UpdateRearmTimer()
    UpdateRegenTimer()
    DebugMsg("CAS Controller :: " .. #_G.assets.tasked .. " Plane(s) in AO")
    TryAssignPlaneFromQueue()

    

    if task == 1 then
        ReceiveData()
    elseif task == 2 then
        AssignPlaneToTarget()
    elseif task == 3 then
        HandleStrikeComplete()
    elseif task == 4 then
        HandleRearming()
    elseif task == 5 then
        HandleDeath()
    end

    input_5 = nil
end

function TryAssignPlaneFromQueue()
    if _G.assets.ready > 0 and QueueSize() > 0 and not _G.awaiting_plane_spawn then
        DebugMsg("CAS Controller :: Conditions met to spawn a plane (task 1)")
        _G.awaiting_plane_spawn = true
        output_5 = 1
    else
        DebugMsg("CAS Controller :: Conditions not met")
        DebugMsg("CAS Controller :: Condition; Asset ready? => " .. tostring(_G.assets.ready > 0))
        DebugMsg("CAS Controller :: Condition; IsQueueNotEmpty? => " .. tostring(QueueSize() > 0))
        DebugMsg("CAS Controller :: Condition; Plane already being spawned? => " .. tostring(_G.awaiting_plane_spawn))
    end
end

function ReceiveData()
    DebugMsg("CAS Controller :: Receiving external target")
    local target_cell = json.parse(input_1)
    if not target_cell then return end

    local x = target_cell["x"]
    local y = target_cell["y"]
    local uids = target_cell["target_uid"]
    if not x or not y or not uids then return end

    -- Filter dead units
    local alive_uids = {}
    for _, uid in ipairs(uids) do
        if IsUnitAlive(uid) then
            table.insert(alive_uids, uid)
        end
    end

    if #alive_uids == 0 then
        DebugMsg("CAS Controller :: Skipping dead target cell ["..x..","..y.."]")
        return
    end

    AddToQueue(x, y, alive_uids)
    DebugMsg("CAS Controller :: There is " .. QueueSize() .. " target(s) in queue")
end

function AssignPlaneToTarget()
    local plane = API.ConvertToLuaUnit(input_2)
    local pid = plane.UID

    local cell = GetFromQueue()
    if not cell then
        DebugMsg("CAS Controller :: No targets in queue for assignment.")
        return
    end

    local x = cell.x
    local y = cell.y
    local uids = cell.targets_uids

    if not _G.targets[x] then _G.targets[x] = {} end
    _G.targets[x][y] = { targets_uids = uids }
    _G.plane_tasking[pid] = { x = x, y = y }

    local unit_output = _G.userdata.Clone()
    unit_output.Clear()
    for _, uid in ipairs(uids) do
        unit_output.Add(uid)
    end

    _G.assets.tasked[pid] = {true}

    output_1 = unit_output
    output_2 = GetUnitFromId(pid)
    output_5 = 2
    _G.assets.ready = _G.assets.ready - 1
    _G.assets.busy = _G.assets.busy + 1
    _G.awaiting_plane_spawn = false
    DebugMsg("CAS Controller :: Plane #" .. pid .. " assigned to target [" .. x .. "," .. y .. "]")
end

function HandleStrikeComplete()
    local plane = API.ConvertToLuaUnit(input_2)
    local pid = plane.UID
    local tasking = _G.plane_tasking[pid]
    if not tasking then return end

    local x = tasking.x
    local y = tasking.y

    DebugMsg("CAS Controller :: Plane #" .. pid .. " completed strike at [" .. x .. "," .. y .. "]")

    _G.targets[x][y] = nil
    _G.plane_tasking[pid] = nil
end

function HandleRearming()
    DebugMsg("CAS Controller :: Plane RTB, starting rearming")
    local plane = input_2
    if not plane then
        DebugMsg("CAS Controller :: ERROR - Could not convert returning unit")
        return
    end
    local pid = plane.GetList[1]
    DebugMsg("CAS Controller :: PID set")
    _G.assets.busy = _G.assets.busy - 1
    DebugMsg("CAS Controller :: -1 Plane Busy")
    _G.assets.rearming = _G.assets.rearming + 1
    DebugMsg("CAS Controller :: +1 Plane Rearming")
    _G.assets.tasked[pid] = nil
    DebugMsg("CAS Controller :: Cleared Plane from Assets.Tasked")
    SetRearmTimer()
    DebugMsg("CAS Controller :: Set timer")
end

function HandleDeath()
    local dead_plane = input_2
    
    --DebugMsg(input_2.GetList[1])
    --local dead_plane = input_2.Clone()
    --dead_plane = dead_plane.First()
    --local input_clone = input_2.Clone()
    if not dead_plane then
        DebugMsg("CAS Controller :: ERROR - Could not convert dead unit")
        return
    end

    local pid = dead_plane.GetList[1]
    --local pid = dead_plane.UID

    if not _G.assets.tasked[pid] then
        DebugMsg("CAS Controller :: Plane #" .. pid .. " is not a CAS asset, ignoring")
        return
    end

    DebugMsg("CAS Controller :: CAS Plane #" .. pid .. " was destroyed")

    if _G.plane_tasking[pid] then
        local x, y = _G.plane_tasking[pid].x, _G.plane_tasking[pid].y
        local alive_uids = _G.targets[x][y].targets_uids
        DebugMsg("CAS Controller :: Cleaning up task for destroyed plane at [" .. x .. "," .. y .. "]")

        local alive_uids_updated = {}
        for _, uid in ipairs(alive_uids) do
            if IsUnitAlive(uid) then
                table.insert(alive_uids_updated, uid)
            end
        end

        if #alive_uids_updated > 0 then
            AddToQueue(x, y, alive_uids_updated)
        end

        _G.targets[x][y] = nil
    end

    _G.plane_tasking[pid] = nil
    _G.assets.busy = _G.assets.busy - 1
    SetRegenTimer()
    DebugMsg("CAS Controller :: Death Handler is done")
end

function UpdateRearmTimer()
    local now = input_4
    local new_timers = {}
    for _, t in ipairs(_G.assets.rearming_timer) do
        if now - t >= _G.rearming_time then
            _G.assets.rearming = _G.assets.rearming - 1
            _G.assets.ready = _G.assets.ready + 1
            DebugMsg("CAS Controller :: 1 Plane finished rearming")
        else
            table.insert(new_timers, t)
        end
    end
    _G.assets.rearming_timer = new_timers
    DebugMsg("CAS Controller :: " .. #_G.assets.rearming_timer .. " Plane(s) rearming")
end
function UpdateRegenTimer()
    if _G.regen_time == -1 then
        return
    end
    local now = input_4
    local new_timers = {}
    for _, t in ipairs(_G.assets.regen_timer) do
        if now - t >= _G.regen_time then
            _G.assets.ready = _G.assets.ready + 1
            DebugMsg("CAS Controller :: 1 Plane was delivered")
        else
            table.insert(new_timers, t)
        end
    end
    _G.assets.regen_timer = new_timers
    DebugMsg("CAS Controller :: " .. #_G.assets.regen_timer .. " Plane(s) on the way")
end


function SetEmptyUserData()
    local ref = input_3.Clone()
    ref.Clear()
    _G.userdata = ref
end

function SetRearmTimer()
    table.insert(_G.assets.rearming_timer, input_4)
end
function SetRegenTimer()
    table.insert(_G.assets.regen_timer, input_4)
end

function DebugMsg(msg)
    API.Print(msg)
end

function IsUnitAlive(uid)
    local unit = GetUnitFromId(uid)
    local type = type(unit)
    --DebugMsg("IsUnitAlive : " .. type)
    local unit_lua = API.ConvertToLuaUnit(unit)
    --DebugMsg("Unit ID: " .. unit_lua.UID)
    local isAlive, _ = pcall(function()
        unit_lua.GetHealPercentage()
    end)
    return isAlive
end

function GetUnitFromId(uid)
    local empty_unit = _G.userdata.Clone()
    empty_unit.Add(uid)
    return empty_unit
end

function AddToQueue(x, y, unit_id)
    local q = _G.target_queue
    local next_tail = (q.tail % q.max) + 1
    if next_tail == q.head then
        DebugMsg("CAS Controller :: Target Queue Full - dropping target")
        return
    end

    q.targets[q.tail] = {["x"] = x, ["y"] = y, targets_uids = unit_id }
    q.tail = next_tail
end

function GetFromQueue()
    local q = _G.target_queue
    if q.head == q.tail then return nil end
    local cell = q.targets[q.head]
    q.targets[q.head] = nil
    q.head = (q.head % q.max) + 1
    return cell
end

function IsQueueNotEmpty()
    local q = _G.target_queue
    return q.head ~= q.tail
end

function QueueSize()
    local q = _G.target_queue
    if q.tail >= q.head then
        return q.tail - q.head
    else
        return q.max - (q.head - q.tail)
    end
end

function CleanupTargets()
    DebugMsg("CAS Controller :: Cleaning up targets")
    for x, col in pairs(_G.targets) do
        for y, cell in pairs(col) do
            local alive = false
            for _, uid in ipairs(cell.targets_uids) do
                if IsUnitAlive(uid) then
                    alive = true
                    break
                end
            end
            if not alive then
                DebugMsg("CAS Controller :: Removing stale target at [" .. x .. "," .. y .. "]")
                _G.targets[x][y] = nil
            end
        end
    end
end
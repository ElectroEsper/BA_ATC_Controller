if not _G.initialized then
    _G.rearming_time = 240
    _G.regen_time = 600

    _G.assets = {
        ready = 2,
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
    _G.userdata = nil

    _G.active_targets = {}        -- tid -> {uids = {}, assigned = bool}
    _G.plane_tasking = {}         -- pid -> tid
    _G.initialized = true
end

function Controller()
    if _G.userdata == nil then SetEmptyUserData() end

    local task = input_5
    output_1, output_2, output_5 = nil, nil, 0

    CheckStrikerDistance()
    UpdateRearmTimer()
    UpdateRegenTimer()

    TryAssignPlaneFromQueue()

    if task == 1 then ReceiveData()
    elseif task == 2 then AssignPlaneToTarget()
    elseif task == 3 then HandleStrikeComplete()
    elseif task == 4 then HandleRearming()
    elseif task == 5 then HandleDeath()
    end

    input_5 = nil
end

function ReceiveData()
    DebugMsg("CAS Controller :: Receiving external target")
    local cell = json.parse(input_1)
    if not cell then return end

    local uids = cell["target_uid"]
    if not uids then return end

    local alive_uids = {}
    for _, uid in ipairs(uids) do
        if IsUnitAlive(uid) then table.insert(alive_uids, uid) end
    end
    if #alive_uids == 0 then return end

    local tid = GenerateTargetId(alive_uids)
    if not _G.active_targets[tid] then
        DebugMsg("CAS Controller :: Registering new target group " .. tid)
        _G.active_targets[tid] = {uids = alive_uids, assigned = false}
        AddToQueue(tid)
    else
        DebugMsg("CAS Controller :: Target group " .. tid .. " already exists")
    end
end

function GenerateTargetId(uid_list)
    table.sort(uid_list)
    return table.concat(uid_list, "-")
end

function AssignPlaneToTarget()
    local plane = API.ConvertToLuaUnit(input_2)
    local pid = plane.UID
    local tid = GetFromQueue()
    if not tid then return end

    local uids = _G.active_targets[tid].uids
    local unit_output = _G.userdata.Clone()
    unit_output.Clear()
    for _, uid in ipairs(uids) do unit_output.Add(uid) end

    _G.assets.tasked[pid] = {true, false}
    _G.plane_tasking[pid] = tid
    _G.active_targets[tid].assigned = true

    output_1 = unit_output
    output_2 = GetUnitFromId(pid)
    output_5 = 2

    _G.assets.ready = _G.assets.ready - 1
    _G.assets.busy = _G.assets.busy + 1
    _G.awaiting_plane_spawn = false

    DebugMsg("CAS Controller :: Plane #" .. pid .. " assigned to target group " .. tid)
end

function CheckStrikerDistance()
    for pid, tid in pairs(_G.plane_tasking) do
        if not _G.assets.tasked[pid][2] then
            DebugMsg("CAS Controller :: Checking distance for plane " .. pid .. " to target group " .. tid)
            local plane = GetUnitFromId(pid)
            local plane_lua = API.ConvertToLuaUnit(plane)
            local pos_total = { [0] = 0, [1] = 0, [2] = 0 }
            local count = 0

            for _, uid in ipairs(_G.active_targets[tid].uids) do
                if IsUnitAlive(uid) then
                    local pos = GetUnitPositionFromId(uid)
                    pos_total[0] = pos_total[0] + pos[0]
                    pos_total[1] = pos_total[1] + pos[1]
                    pos_total[2] = pos_total[2] + pos[2]
                    count = count + 1
                end
            end

            if count > 0 then
                pos_total[0] = pos_total[0] / count
                pos_total[1] = pos_total[1] / count
                pos_total[2] = pos_total[2] / count
                local dist = Distance(plane_lua.GetPosition(), pos_total)
                DebugMsg("CAS Controller :: Plane #" .. pid .. " distance to target group " .. tid .. " is " .. dist .. " meters")
                if dist <= 3000 then AdjustTarget(pid, _G.active_targets[tid].uids) end
            else
                DebugMsg("CAS Controller :: No alive targets for group " .. tid)
            end
        end
    end
end

function AdjustTarget(pid, targets_uids)
    DebugMsg("CAS Controller :: Adjusting aim for plane " .. pid)
    local plane = GetUnitFromId(pid)
    local target_units = _G.userdata.Clone()
    target_units.Clear()
    for _, uid in ipairs(targets_uids) do
        if IsUnitAlive(uid) then
            target_units.Add(uid)
            DebugMsg("CAS Controller :: Adding UID " .. uid .. " to adjustment list")
        end
    end
    if target_units.Count > 0 then
        DebugMsg("CAS Controller :: Sending adjusted strike command for plane " .. pid)
        output_1 = target_units
        output_2 = plane
        output_5 = 3
        CompleteWithOutput()
        _G.assets.tasked[pid][2] = true
    else
        DebugMsg("CAS Controller :: No valid targets left to adjust for plane " .. pid)
    end
end

function HandleStrikeComplete()
    DebugMsg("CAS Controller :: HandleStrikeComplete")
    local plane = API.ConvertToLuaUnit(input_2)
    local pid = plane.UID
    local tid = _G.plane_tasking[pid]
    if not tid then
        DebugMsg("CAS Controller :: HandleStrikeComplete :: No task found for plane " .. pid)
        return
    end

    local alive_uids = {}
    for _, uid in ipairs(_G.active_targets[tid].uids) do
        if IsUnitAlive(uid) then
            table.insert(alive_uids, uid)
            DebugMsg("CAS Controller :: HandleStrikeComplete :: Target UID " .. uid .. " is still alive after strike")
        end
    end

    if #alive_uids > 0 then
        DebugMsg("CAS Controller :: HandleStrikeComplete :: Target group " .. tid .. " survived, requeuing")
        _G.active_targets[tid] = {uids = alive_uids, assigned = false}
        AddToQueue(tid)
    else
        DebugMsg("CAS Controller :: HandleStrikeComplete :: Target group " .. tid .. " eliminated")
        _G.active_targets[tid] = nil
    end

    _G.plane_tasking[pid] = nil
end

function HandleRearming()
    local pid = input_2.GetList[1]
    _G.assets.busy = _G.assets.busy - 1
    _G.assets.rearming = _G.assets.rearming + 1
    _G.assets.tasked[pid] = nil
    SetRearmTimer()
end

function HandleDeath()
    local pid = input_2.GetList[1]
    if not _G.assets.tasked[pid] then return end

    local tid = _G.plane_tasking[pid]
    local alive_uids = {}
    for _, uid in ipairs(_G.active_targets[tid].uids) do
        if IsUnitAlive(uid) then table.insert(alive_uids, uid) end
    end
    if #alive_uids > 0 then
        _G.active_targets[tid] = {uids = alive_uids, assigned = false}
        AddToQueue(tid)
    else
        _G.active_targets[tid] = nil
    end

    _G.plane_tasking[pid] = nil
    _G.assets.busy = _G.assets.busy - 1
    SetRegenTimer()
end

function TryAssignPlaneFromQueue()
    DebugMsg("CAS Controller :: TryAssignPlaneFromQueue")
    DebugMsg("CAS Controller :: TryAssignPlaneFromQueue :: Ready Assets >> " .. _G.assets.ready)
    DebugMsg("CAS Controller :: TryAssignPlaneFromQueue :: Queue Size >> " .. QueueSize())
    DebugMsg("CAS Controller :: TryAssignPlaneFromQueue :: Plane waiting to spawn? >> " .. tostring(_G.awaiting_plane_spawn))
    if _G.assets.ready > 0 and QueueSize() > 0 and not _G.awaiting_plane_spawn then
        DebugMsg("CAS Controller :: TryAssignPlaneFromQueue :: Got targets and ready planes")
        _G.awaiting_plane_spawn = true
        output_5 = 1
    end
end

function AddToQueue(tid)
    local q = _G.target_queue
    local next_tail = (q.tail % q.max) + 1
    if next_tail == q.head then return end
    q.targets[q.tail] = tid
    q.tail = next_tail
end

function GetFromQueue()
    local q = _G.target_queue
    if q.head == q.tail then return nil end
    local tid = q.targets[q.head]
    q.targets[q.head] = nil
    q.head = (q.head % q.max) + 1
    return tid
end

function QueueSize()
    local q = _G.target_queue
    if q.tail >= q.head then return q.tail - q.head
    else return q.max - (q.head - q.tail) end
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

function UpdateRearmTimer()
    local now = input_4
    local new_timers = {}
    for _, t in ipairs(_G.assets.rearming_timer) do
        if now - t >= _G.rearming_time then
            _G.assets.rearming = _G.assets.rearming - 1
            _G.assets.ready = _G.assets.ready + 1
        else
            table.insert(new_timers, t)
        end
    end
    _G.assets.rearming_timer = new_timers
end

function UpdateRegenTimer()
    if _G.regen_time == -1 then return end
    local now = input_4
    local new_timers = {}
    for _, t in ipairs(_G.assets.regen_timer) do
        if now - t >= _G.regen_time then
            _G.assets.ready = _G.assets.ready + 1
        else
            table.insert(new_timers, t)
        end
    end
    _G.assets.regen_timer = new_timers
end

function IsUnitAlive(uid)
    local unit = GetUnitFromId(uid)
    local unit_lua = API.ConvertToLuaUnit(unit)
    local isAlive, _ = pcall(function() unit_lua.GetHealPercentage() end)
    return isAlive
end

function GetUnitFromId(uid)
    local u = _G.userdata.Clone()
    u.Add(uid)
    return u
end

function GetUnitPositionFromId(uid)
    local unit = GetUnitFromId(uid)
    local unit_lua = API.ConvertToLuaUnit(unit)
    return unit_lua.GetPosition()
end

function Distance(v1, v2)
    local dx = v1[0] - v2[0]
    local dy = v1[1] - v2[1]
    local dz = (v1[2] or 0) - (v2[2] or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz) * 2
end

function DebugMsg(msg)
    API.Print(msg)
end
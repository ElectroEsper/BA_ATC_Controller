-- CAP Controller
-- Handles tasking of CAS planes, strike execution, and rearming cycles

if not _G.initialized then
    _G.initialized = true
    _G.targets = {}                -- Active target cells being engaged
    --_G.plane_tasked = {}         -- Maps plane UID to target grid
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
    _G.rearming_time = 5
    _G.regen_time = 10
    _G.userdata = nil
end

function Controller()
    if not _G.initialized then return end
    if _G.userdata == nil then
        SetEmptyUserData()
    end

    local task = input_5
    output_1 = nil
    output_2 = nil
    output_5 = 0

    UpdateRearmTimer()
    UpdateRegenTimer()
    --OverlordPicture()
    DebugMsg("CAP Controller :: " .. #_G.assets.tasked .. " Plane(s) in AO")
    

    

    if task == 1 then
        ReceiveData()
    elseif task == 2 then
        DeployInterceptor()
    elseif task == 3 then
        HandleStrikeComplete()
    elseif task == 4 then
        HandleRearming()
    elseif task == 5 then
        HandleDeath()
    end

    OverlordPicture()

    input_5 = nil
end

function OverlordPicture()
    DebugMsg("CAP Controller :: Overlord, Picture...")
    local targets = _G.targets
    local updated_targets = {}
    for _, target in ipairs(targets) do
        if IsUnitAlive(target) then
            table.insert(updated_targets,target)
        end
    end
    
    _G.targets = updated_targets
    if #_G.targets == 0 then
        DebugMsg("CAP Controller :: 0 bandit in airspace, exiting")
        return
    end

    DebugMsg("CAP Controller :: " .. #_G.targets .. " bandit(s) in airspace")

    local ready_assets = _G.assets.ready

    if ready_assets == 0 then
        DebugMsg("CAP Controller :: We have no plane on stand-by, exiting")
        return
    end

    DebugMsg("CAP Controller :: We have " .. ready_assets .. " plane(s) on stand-by")

    local target_cnt = #_G.targets
    local cap_cnt = _G.assets.busy

    if target_cnt > cap_cnt then
        DebugMsg("CAP Controller :: Tasking a plane")
        _G.awaiting_plane_spawn = true
        output_5 = 1
    else
        DebugMsg("CAP Controller :: We have enough planes in the air")
    end
end

function ReceiveData()
    DebugMsg("CAP Controller :: Receiving external target")
    local target_uids = json.parse(input_1)
    if not target_uids then return end
    local uids = target_uids
    if not uids then return end

    -- Filter dead units
    local alive_uids = {}
    for _, uid in ipairs(uids) do
        if IsUnitAlive(uid) then
            table.insert( _G.targets, uid)
        end
    end
end

function DeployInterceptor()
    local plane = API.ConvertToLuaUnit(input_2)
    local pid = plane.UID

    
    _G.assets.tasked[pid] = {true}

    --output_1 = unit_output
    output_2 = GetUnitFromId(pid)
    output_5 = 2
    _G.assets.ready = _G.assets.ready - 1
    _G.assets.busy = _G.assets.busy + 1
    _G.awaiting_plane_spawn = false
    DebugMsg("CAP Controller :: Plane #" .. pid .. " scambled")
end

function HandleRearming()
    DebugMsg("CAP Controller :: Plane RTB, starting rearming")
    local plane = input_2
    if not plane then
        DebugMsg("CAP Controller :: ERROR - Could not convert returning unit")
        return
    end
    local pid = plane.GetList[1]
    DebugMsg("CAP Controller :: PID set")
    _G.assets.busy = _G.assets.busy - 1
    DebugMsg("CAP Controller :: -1 Plane Busy")
    _G.assets.rearming = _G.assets.rearming + 1
    DebugMsg("CAP Controller :: +1 Plane Rearming")
    _G.assets.tasked[pid] = nil
    DebugMsg("CAP Controller :: Cleared Plane from Assets.Tasked")
    SetRearmTimer()
    DebugMsg("CAP Controller :: Set timer")
end

function HandleDeath()
    local dead_plane = input_2
    
    if not dead_plane then
        DebugMsg("CAP Controller :: ERROR - Could not convert dead unit")
        return
    end

    local pid = dead_plane.GetList[1]
    --local pid = dead_plane.UID

    if not _G.assets.tasked[pid] then
        DebugMsg("CAP Controller :: Plane #" .. pid .. " is not a CAS asset, ignoring")
        return
    end

    DebugMsg("CAP Controller :: CAP Plane #" .. pid .. " was destroyed")

    _G.assets.tasked[pid] = nil
    _G.assets.busy = _G.assets.busy - 1
    SetRegenTimer()
    DebugMsg("CAP Controller :: Death Handler is done")
end

function UpdateRearmTimer()
    local now = input_4
    local new_timers = {}
    for _, t in ipairs(_G.assets.rearming_timer) do
        if now - t >= _G.rearming_time then
            _G.assets.rearming = _G.assets.rearming - 1
            _G.assets.ready = _G.assets.ready + 1
            DebugMsg("CAP Controller :: 1 Plane finished rearming")
        else
            table.insert(new_timers, t)
        end
    end
    _G.assets.rearming_timer = new_timers
    DebugMsg("CAP Controller :: " .. #_G.assets.rearming_timer .. " Plane(s) rearming")
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
            DebugMsg("CAP Controller :: 1 Plane was delivered")
        else
            table.insert(new_timers, t)
        end
    end
    _G.assets.regen_timer = new_timers
    DebugMsg("CAP Controller :: " .. #_G.assets.regen_timer .. " Plane(s) on the way")
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

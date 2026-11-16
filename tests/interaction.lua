local function Event()
    local callbacks = {};
    return {Add = function(callback) callbacks[#callbacks + 1] = callback; end,
        Remove = function() end,
        Fire = function(...) for _, callback in ipairs(callbacks) do callback(...); end end};
end

local function Control()
    return setmetatable({CData = {}, values = {}}, {__index = function(control, name)
        if name == "GetChildren" then return function() return {}; end; end
        return function(_, value) control.values[name] = value; end;
    end});
end

local function Fixture(saved)
    local world = {turn = 10, active = true, busy = false, delayed = false, settings = {}, requests = {}, registry = saved or {}};
    Mouse = {eLClick = 1};
    PlayerOperations = {EXECUTE_SCRIPT = 1};
    UnitOperationTypes = {PARAM_X = "x", PARAM_Y = "y"};
    UnitCommandTypes = {PROMOTE = 1}; UnitCommandResults = {PROMOTIONS = "promotions"};
    EspionageResultTypes = {SUCCESS_MUST_ESCAPE = 1, FAIL_MUST_ESCAPE = 2, CAPTURED = 3, KILLED = 4};
    GameInfo = {Units = {[7] = {Spy = true}, [8] = {Spy = false}}, UnitOperations = {}};
    local function Operation(index, name, category)
        local op = {Index = index, Hash = index, OperationType = name, CategoryInUI = category};
        GameInfo.UnitOperations[index], GameInfo.UnitOperations[name] = op, op;
    end
    Operation(45, "UNITOPERATION_SPY_SIPHON_FUNDS", "OFFENSIVESPY");
    Operation(46, "UNITOPERATION_SPY_STEAL_TECH_BOOST", "OFFENSIVESPY");
    Operation(47, "UNITOPERATION_SPY_GAIN_SOURCES", "OFFENSIVESPY");
    Operation(48, "UNITOPERATION_SPY_TRAVEL_TO_CITY", "OTHER");
    local city = {owner = 1, id = 100};
    function city:GetOwner() return self.owner; end
    function city:GetID() return self.id; end
    local plot = {GetIndex = function() return 1000; end, GetX = function() return 5; end, GetY = function() return 6; end};
    world.city = city;
    Map = {GetPlotByIndex = function(id) if id == 1000 then return plot; end end,
        GetPlot = function(x) if x >= 0 then return plot; end end};
    Cities = {GetPlotPurchaseCity = function() return city; end};
    local function Spy(id)
        local unit = {id = id, name = "Spy" .. id, kind = 7, op = 45, ending = 14,
            ready = true, promotion = false, allowed = true, x = 5};
        function unit:GetID() return self.id; end
        function unit:GetOwner() return 0; end
        function unit:GetName() return self.name; end
        function unit:GetType() return self.kind; end
        function unit:GetSpyOperation() return self.op; end
        function unit:GetSpyOperationEndTurn() return self.ending; end
        function unit:GetX() return self.x; end
        function unit:GetY() return 6; end
        function unit:IsReadyToMove() return self.ready; end
        return unit;
    end
    world.a, world.b = Spy(1), Spy(2); world.selected = world.a;
    local units = {world.a, world.b};
    local player = {GetUnits = function() return {FindID = function(_, id) return units[id]; end}; end,
        IsHuman = function() return true; end, IsTurnActive = function() return world.active; end,
        GetProperty = function() return world.registry; end,
        SetProperty = function(_, _, value) world.registry = value; end,
        GetDiplomacy = function() return {GetMission = function() return world.mission; end}; end};
    Players = {[0] = player}; ExposedMembers = {};
    Game = {GetLocalPlayer = function() return 0; end, GetCurrentGameTurn = function() return world.turn; end};
    Events = setmetatable({}, {__index = function(events, name) events[name] = Event(); return events[name]; end});
    GameEvents = {SpyRepeat_Set = Event()};
    Controls = {SpyAction = Control(), SpyToggle = Control(), SpyToggleIcon = Control()};
    Controls.SpyToggle.RegisterCallback = function(_, _, callback) world.click = callback; end;
    local parent = Control();
    ContextPtr = {LookUpControl = function(_, name) if name:find("UnitPanel", 1, true) then return parent; end end,
        SetHide = function() end, SetUpdate = function(_, callback) world.update = callback; end,
        SetInitHandler = function() end, SetShutdown = function() end};
    Locale = {Lookup = function(key) return key; end};
    UI = {GetHeadSelectedUnit = function() return world.selected; end,
        IsGameCoreBusy = function() return world.busy; end,
        RequestPlayerOperation = function(_, _, parameters)
            world.settings[#world.settings + 1] = parameters;
            if not world.delayed then GameEvents.SpyRepeat_Set.Fire(0, parameters); end
        end};
    UnitManager = {CanStartCommand = function(unit) return unit.promotion, {promotions = unit.promotion and {1} or {}}; end,
        CanStartOperation = function(unit) return unit.allowed; end,
        RequestOperation = function(unit, operation)
            world.requests[#world.requests + 1] = {id = unit.id, operation = operation};
            unit.op, unit.ending = operation, world.turn + 4;
        end};
    include = function(name) assert(loadfile("mod/" .. name .. ".lua"))(); end;
    assert(loadfile("mod/SpyRepeat_State.lua"))();
    assert(loadfile("mod/SpyRepeat.lua"))();
    function world:tick(seconds) self.update(seconds or 0.5); end
    function world:enable() self.click(); self:tick(); end
    function world:idle() self.a.op = -1; end
    function world:ack() GameEvents.SpyRepeat_Set.Fire(0, self.settings[#self.settings]); end
    return world;
end

local w = Fixture(); w:enable();
assert(w.registry["1"].Enabled and not w.registry["2"]);
w:idle(); w:tick(); w:tick(); assert(#w.requests == 1);
w:idle(); w:tick(); assert(#w.requests == 1, "same-turn duplicate");
w.click(); w:tick(); assert(not w.registry["1"].Enabled);
w.turn = 11; w:tick(); assert(#w.requests == 1, "disabled spy resumed");
w.selected = w.b; Events.UnitSelectionChanged.Fire(); w:enable();
assert(w.registry["2"].Enabled and not w.registry["1"].Enabled, "selection leaked");
w.selected.kind = 8; Events.UnitSelectionChanged.Fire(); assert(Controls.SpyAction.values.SetHide);

w = Fixture(); w:enable(); w.a.op = 46; w:tick(); w:tick();
assert(w.registry["1"].Operation == "UNITOPERATION_SPY_STEAL_TECH_BOOST");
w.a.op = 48; Events.UnitOperationStarted.Fire(0, 1, 48); w:tick(); w:tick();
assert(not w.registry["1"].Enabled and w.registry["1"].Reason == "CHANGED");
for _, reason in ipairs({"PROMOTION", "UNAVAILABLE", "ESCAPE", "TARGET_CHANGED", "OFF_MAP"}) do
    w = Fixture(); w:enable();
    if reason == "PROMOTION" then w.a.promotion = true;
    elseif reason == "UNAVAILABLE" then w:idle(); w.a.allowed = false;
    elseif reason == "ESCAPE" then w.a.ending = 0;
    elseif reason == "TARGET_CHANGED" then w.city.owner = 2;
    else w.a.x = -1; end
    w:tick(); w:tick();
    assert(not w.registry["1"].Enabled and #w.requests == 0, reason .. " did not pause");
end
w = Fixture(); w.a.op = 47; w:enable();
assert(not w.registry["1"], "Gain Sources was repeated");

-- The same spy must retain its per-turn reservation when a setting changes.
w = Fixture(); w:enable(); w:idle(); w:tick(); w:tick();
local reserved = w.registry["1"].LastRequestTurn;
w.a.op = 46; w:tick(); w:tick();
assert(w.registry["1"].LastRequestTurn == reserved, "manual task change erased same-turn guard");

-- A reservation may be acknowledged during another player's turn. It must
-- dispatch after our turn begins, instead of consuming the guard and going idle.
w = Fixture(); w:enable(); w:idle(); w.delayed = true; w:tick();
w.active = false; w.turn = 11; w:ack(); w:tick(20);
assert(#w.requests == 0);
w.active = true; w.delayed = false; w:tick(); w:tick();
assert(#w.requests == 1, "cross-turn acknowledgement stranded the spy");

w = Fixture(); w:enable(); w:idle(); w.delayed = true; w:tick();
w.active = false; w:ack(); w:tick();
w.turn = 11; w.active = true; w.delayed = false; w:tick(); w:tick();
assert(#w.requests == 1 and w.registry["1"].LastRequestTurn == 11, "delayed dispatch used the previous turn's guard");

-- Engine processing time must not count as a failed settings acknowledgement.
w = Fixture(); w:enable(); w:idle(); w.delayed = true; w:tick();
w.busy = true; w:tick(20); w:ack(); w.busy = false; w:tick();
assert(#w.requests == 1, "busy engine caused a false timeout");

-- A true timeout stops locally and the button must show the same state.
w = Fixture(); w:enable(); w:idle(); w.delayed = true; w:tick(); w:tick(9);
assert(Controls.SpyToggle.values.SetSelected == false, "timed-out spy remained highlighted");
assert(Controls.SpyToggle.values.SetToolTipString:find("LOC_SR_ENABLE", 1, true));
w.delayed = false; w.click(); w:tick();
assert(w.registry["1"].Enabled, "retry button turned off instead of resuming");

w = Fixture(); w:enable(); w:idle(); w:tick(); w:tick();
local saved = w.registry;
w = Fixture(saved); w:idle(); w:tick(); w:tick();
assert(#w.requests == 0, "UI reload lost same-turn reservation");
w.turn = 11; w:tick(); w:tick(); assert(#w.requests == 1);

w = Fixture(); w:enable(); w:idle(); w.delayed = true; w:tick();
w.mission = {Name = w.a.name, InitialResult = EspionageResultTypes.SUCCESS_MUST_ESCAPE};
Events.SpyMissionCompleted.Fire(0, 100); w:ack(); w:tick();
assert(#w.requests == 0 and not w.registry["1"].Enabled and w.registry["1"].Reason == "ESCAPE");
saved = w.registry; w = Fixture(saved); w:idle(); w:tick(); w:tick();
assert(#w.requests == 0 and w.registry["1"].Reason == "ESCAPE", "reload lost escape pause");

print("SpyRepeat interaction regression passed: selection, off, native tasks, manual change, hazards, turn guard, delayed acknowledgement, timeout recovery, saved state, pending escape");

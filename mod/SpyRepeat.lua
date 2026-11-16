include("SpyRepeat_Common");

local pending = {};
local status = {};
local clock = 0;
local elapsed = 0;
local serial = 0;
local urgentPauses = {};
local blocked = {};
local actionParent;
local assignments = {};
local closing = {};
local intents = {};
local presentation;

local function Text(key, ...)
    return Locale.Lookup("LOC_SR_" .. key, ...);
end

local function Player()
    local id = Game.GetLocalPlayer();
    if id == nil or id < 0 then return nil; end
    return Players[id];
end

local function Registry()
    local player = Player();
    return player and player:GetProperty(SpyRepeat.Property) or {};
end

local function ActiveTurn()
    local player = Player();
    return player ~= nil and player:IsTurnActive();
end

local function CurrentOperation(unit)
    local id = unit:GetSpyOperation();
    return id ~= nil and id ~= -1 and GameInfo.UnitOperations[id] or nil;
end

local function AwaitingEscape(unit)
    -- During route selection the native mission is still assigned, but its end
    -- turn is zero. SpyMissionCompleted only arrives after escape resolution.
    local operation = CurrentOperation(unit);
    return SpyRepeat.IsRepeatable(operation) and unit.GetSpyOperationEndTurn ~= nil and
        unit:GetSpyOperationEndTurn() == 0;
end

local function CityAtUnit(unit)
    local plot = Map.GetPlot(unit:GetX(), unit:GetY());
    return plot and Cities.GetPlotPurchaseCity(plot);
end

local function Snapshot(unit)
    local operation = CurrentOperation(unit);
    if not SpyRepeat.IsRepeatable(operation) then return nil; end
    local plot = Map.GetPlot(unit:GetX(), unit:GetY());
    local city = plot and Cities.GetPlotPurchaseCity(plot);
    if city == nil then return nil; end
    return {Operation = operation.OperationType, Plot = plot:GetIndex()};
end

local function Send(id, action, details, after)
    local key = tostring(id);
    if pending[key] ~= nil or not ActiveTurn() then return; end
    serial = serial + 1;
    local token = tostring(Game.GetCurrentGameTurn()) .. ":" .. tostring(clock) .. ":" .. tostring(serial);
    local parameters = {OnStart = "SpyRepeat_Set", UnitID = id, Action = action, Token = token};
    for k, value in pairs(details or {}) do parameters[k] = value; end
    pending[key] = {token = token, action = action, deadline = clock + 8, after = after};
    intents[key] = {action = action, details = details};
    UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT, parameters);
end

local function Pause(id, reason)
    Send(id, "pause", {Reason = reason});
end

local function Target(entry)
    local plot = Map.GetPlotByIndex(entry.Plot);
    local city = plot and Cities.GetPlotPurchaseCity(plot);
    if city == nil or city:GetOwner() ~= entry.CityOwner or city:GetID() ~= entry.CityID then return nil; end
    return plot, city;
end

local function HasPromotion(unit)
    local can, results = UnitManager.CanStartCommand(unit, UnitCommandTypes.PROMOTE, true, true);
    local promotions = results and results[UnitCommandResults.PROMOTIONS];
    return can and promotions ~= nil and #promotions > 0;
end

local function Stop(id)
    local key = tostring(id);
    assignments[key] = nil;
    blocked[key], closing[key] = true, true;
    intents[key] = {action = "off"};
    if pending[key] then pending[key].after = nil;
    elseif Registry()[key] then Send(id, "off");
    else blocked[key], closing[key], intents[key] = nil, nil, nil; status[key] = "OFF"; end
end

local function Enable(id)
    local key = tostring(id);
    local entry = Registry()[key];
    if not ActiveTurn() or pending[key] or closing[key] then return; end
    local unit = Player():GetUnits():FindID(id);
    if not SpyRepeat.IsSpy(unit) then return; end
    if AwaitingEscape(unit) then status[key] = "ESCAPE"; return; end
    local snapshot = Snapshot(unit);
    if snapshot == nil and entry and unit:GetName() == entry.Name and unit:GetType() == entry.UnitType then
        -- Resume the saved assignment only while idle in the original city.
        local _, city = Target(entry);
        local currentCity = CityAtUnit(unit);
        if CurrentOperation(unit) == nil and city and currentCity and
            currentCity:GetOwner() == city:GetOwner() and currentCity:GetID() == city:GetID() then
            snapshot = {Operation = entry.Operation, Plot = entry.Plot};
        end
    end
    if snapshot == nil then status[key] = "ASSIGN_FIRST"; return; end
    if HasPromotion(unit) then status[key] = "PROMOTION"; return; end
    Send(id, "enable", snapshot);
end

local function Toggle(id)
    local key = tostring(id);
    local entry = Registry()[key];
    if intents[key] and intents[key].action == "off" then Stop(id);
    elseif entry and entry.Enabled and not blocked[key] then Stop(id);
    else Enable(id); end
end

local function Parameters(plot)
    local parameters = {};
    parameters[UnitOperationTypes.PARAM_X] = plot:GetX();
    parameters[UnitOperationTypes.PARAM_Y] = plot:GetY();
    return parameters;
end

local function StartReserved(id)
    local key = tostring(id);
    if blocked[key] or closing[key] or assignments[key] or urgentPauses[key] then return; end
    local entry = Registry()[tostring(id)];
    local unit = Player():GetUnits():FindID(id);
    if not ActiveTurn() or not entry or not entry.Enabled or not SpyRepeat.IsSpy(unit) then return; end
    if unit:GetName() ~= entry.Name or unit:GetType() ~= entry.UnitType then Pause(id, "OFF_MAP"); return; end
    -- Re-check after the save-state acknowledgement: the player may have intervened.
    if CurrentOperation(unit) ~= nil or not unit:IsReadyToMove() then return; end
    if HasPromotion(unit) then Pause(id, "PROMOTION"); return; end
    local plot = Target(entry);
    local currentCity = CityAtUnit(unit);
    if not plot or not currentCity or currentCity:GetOwner() ~= entry.CityOwner or
        currentCity:GetID() ~= entry.CityID then Pause(id, "TARGET_CHANGED"); return; end
    local operation = GameInfo.UnitOperations[entry.Operation];
    local parameters = Parameters(plot);
    if not SpyRepeat.IsRepeatable(operation) or
        not UnitManager.CanStartOperation(unit, operation.Hash, plot, parameters) then
        Pause(id, "UNAVAILABLE"); return;
    end
    if entry.LastRequestTurn ~= Game.GetCurrentGameTurn() then
        Send(id, "reserve", nil, function() StartReserved(id); end);
        return;
    end
    UnitManager.RequestOperation(unit, operation.Hash, parameters);
    status[tostring(id)] = "REQUESTED";
    print("[SpyRepeat] Requested " .. entry.Operation .. " for " .. tostring(id));
end

local function Process(id, entry)
    local key = tostring(id);
    if not entry.Enabled or pending[key] or blocked[key] or closing[key] or assignments[key] then return; end
    local unit = Player():GetUnits():FindID(id);
    if not SpyRepeat.IsSpy(unit) or unit:GetName() ~= entry.Name or unit:GetType() ~= entry.UnitType then
        Pause(id, "OFF_MAP"); return;
    end
    if AwaitingEscape(unit) then Pause(id, "ESCAPE"); return; end
    if HasPromotion(unit) then Pause(id, "PROMOTION"); return; end
    local plot = Target(entry);
    local city = CityAtUnit(unit);
    if not plot or not city or city:GetOwner() ~= entry.CityOwner or city:GetID() ~= entry.CityID then
        Pause(id, "TARGET_CHANGED"); return;
    end
    local current = CurrentOperation(unit);
    if current ~= nil then
        if not SpyRepeat.IsRepeatable(current) then Pause(id, "CHANGED"); return; end
        local snapshot = Snapshot(unit);
        if snapshot and (snapshot.Operation ~= entry.Operation or snapshot.Plot ~= entry.Plot) then
            -- A manual assignment in the same city replaces the saved assignment.
            Send(id, "enable", snapshot);
        else status[key] = "RUNNING"; end
        return;
    end
    if not unit:IsReadyToMove() then status[key] = "WAITING"; return; end
    if entry.LastRequestTurn == Game.GetCurrentGameTurn() then return; end
    local operation = GameInfo.UnitOperations[entry.Operation];
    if not SpyRepeat.IsRepeatable(operation) or
        not UnitManager.CanStartOperation(unit, operation.Hash, plot, Parameters(plot)) then
        Pause(id, "UNAVAILABLE"); return;
    end
    -- Persist the guard before dispatch, preventing duplicates even after a UI reload.
    Send(id, "reserve", nil, function() StartReserved(id); end);
end

-- GetMission is a UI-only API. Gameplay asks this read-only bridge for plain
-- strings so it can persist a hazardous result during another player's turn.
local function ReadMissionOutcome(owner, missionID)
    local player = Players[owner];
    if not player then return; end
    local mission = player:GetDiplomacy():GetMission(owner, missionID);
    if type(mission) ~= "table" then return; end
    local result = mission.InitialResult;
    local reason;
    if result == EspionageResultTypes.SUCCESS_MUST_ESCAPE or result == EspionageResultTypes.FAIL_MUST_ESCAPE then
        reason = "ESCAPE";
    elseif result == EspionageResultTypes.CAPTURED or result == EspionageResultTypes.KILLED or
        mission.EscapeResult == EspionageResultTypes.CAPTURED or mission.EscapeResult == EspionageResultTypes.KILLED then
        reason = "OFF_MAP";
    end
    return mission.Name, reason;
end
ExposedMembers.SpyRepeat_ReadMissionOutcome = ReadMissionOutcome;
ContextPtr:SetShutdown(function()
    if presentation then presentation.Shutdown(); end
    if ExposedMembers.SpyRepeat_ReadMissionOutcome == ReadMissionOutcome then
        ExposedMembers.SpyRepeat_ReadMissionOutcome = nil;
    end
end);

local function MissionCompleted(owner, missionID)
    if owner ~= Game.GetLocalPlayer() then return; end
    local name, reason = ReadMissionOutcome(owner, missionID);
    if reason then
        for key, entry in pairs(Registry()) do
            if entry.Name == name then
                -- Also prevents a pending reservation from dispatching after an escape event.
                if pending[key] then pending[key].after = nil; end
                status[key] = reason;
                -- Queue after any outstanding settings acknowledgement.
                urgentPauses[key] = reason;
            end
        end
    end
end

local function OperationStarted(owner, id, operationID)
    if owner ~= Game.GetLocalPlayer() then return; end
    local draft = assignments[tostring(id)];
    if draft then
        local started = GameInfo.UnitOperations[operationID];
        draft.started = started and started.OperationType == draft.Operation;
        if not draft.started then draft.invalid = true; end
    end
    local entry = Registry()[tostring(id)];
    local operation = GameInfo.UnitOperations[operationID];
    if entry and entry.Enabled and operation and
        string.find(operation.OperationType, "UNITOPERATION_SPY_TRAVEL", 1, true) then
        urgentPauses[tostring(id)] = "CHANGED";
        if pending[tostring(id)] then pending[tostring(id)].after = nil; end
    end
end

-- A checkbox edits a draft. Only the native Accept/Counterspy action enters
-- this queue, and only an observed native operation can commit the setting.
local function BeginAssignment(id, operationID, plotIndex, enabled)
    local unit = Player() and Player():GetUnits():FindID(id);
    local operation = GameInfo.UnitOperations[operationID];
    local plot = Map.GetPlotByIndex(plotIndex);
    local city = plot and Cities.GetPlotPurchaseCity(plot);
    if not ActiveTurn() or not SpyRepeat.IsSpy(unit) or not operation or not city then return false; end
    local key = tostring(id);
    local repeatEnabled = enabled == true and SpyRepeat.IsRepeatable(operation);
    if pending[key] then pending[key].after = nil; end
    blocked[key] = true;
    assignments[key] = {Operation = operation.OperationType, Plot = plotIndex,
        Name = unit:GetName(), UnitType = unit:GetType(), CityOwner = city:GetOwner(), CityID = city:GetID(),
        enabled = repeatEnabled, deadline = clock + 8};
    intents[key] = {action = repeatEnabled and "enable" or "off"};
    status[key] = "ASSIGNING";
    return true;
end

local function ProcessAssignments(ready, interval)
    for key, draft in pairs(assignments) do
        if not ready then draft.deadline = draft.deadline + interval; end
        if ready and not pending[key] then
            local unit = Player():GetUnits():FindID(tonumber(key));
            local city = unit and CityAtUnit(unit);
            local current = unit and CurrentOperation(unit);
            local valid = SpyRepeat.IsSpy(unit) and unit:GetName() == draft.Name and unit:GetType() == draft.UnitType and
                city and city:GetOwner() == draft.CityOwner and city:GetID() == draft.CityID;
            if valid and draft.started and current and current.OperationType == draft.Operation then
                assignments[key] = nil;
                if urgentPauses[key] or AwaitingEscape(unit) or HasPromotion(unit) then
                    urgentPauses[key] = urgentPauses[key] or (AwaitingEscape(unit) and "ESCAPE" or "PROMOTION");
                elseif draft.enabled then Send(tonumber(key), "enable", {Operation = draft.Operation, Plot = draft.Plot});
                elseif Registry()[key] then Stop(tonumber(key));
                else blocked[key], intents[key] = nil, nil; status[key] = "OFF"; end
            elseif not valid or draft.invalid or clock >= draft.deadline then
                assignments[key] = nil;
                status[key] = "ASSIGN_FAILED";
                intents[key] = nil;
                if Registry()[key] and Registry()[key].Enabled then urgentPauses[key] = "CHANGED"; end
            end
        end
    end
end

local function Child(parent, id)
    for _, child in ipairs(parent:GetChildren()) do
        if child:GetID() == id then return child; end
    end
end

local function RemoveOverviewControls(native)
    -- Remove controls left by the previous overview integration during UI reload.
    -- Match only our owned subtree; other mods can also use a generic Root ID.
    for _, child in ipairs(native:GetChildren()) do
        if child:GetID() == "Root" and Child(child, "Toggle") and Child(child, "Status") then
            native:DestroyChild(child);
        end
    end
end

local function CleanLegacyOverview()
    if Controls.OpenButton then Controls.OpenButton:SetHide(true); end
    if Controls.Panel then Controls.Panel:SetHide(true); end
    local parent = ContextPtr:LookUpControl("/InGame/EspionageOverview/OperativeTabContainer");
    if parent then
        for _, child in ipairs(parent:GetChildren()) do
            local id = child:GetID();
            local scroll = id == "Panel" and Child(child, "Scroll");
            if (id == "OpenButton" and string.find(child:GetText(), Text("TITLE"), 1, true) == 1) or
                (scroll and Child(scroll, "SpyStack")) then
                parent:DestroyChild(child);
            end
        end
    end
    local stack = ContextPtr:LookUpControl("/InGame/EspionageOverview/OperativeStack");
    if stack then
        for _, native in ipairs(stack:GetChildren()) do
            RemoveOverviewControls(native);
            native:ReprocessAnchoring();
        end
        stack:CalculateSize(); stack:ReprocessAnchoring();
    end
end

local function Refresh()
    if presentation then presentation.Refresh(); return; end
    local selected = UI.GetHeadSelectedUnit();
    local spy = selected and selected:GetOwner() == Game.GetLocalPlayer() and SpyRepeat.IsSpy(selected);
    local parent = ContextPtr:LookUpControl("/InGame/UnitPanel/StandardActionsStack") or ContextPtr:LookUpControl("/InGame/UnitPanel/ActionsStack");
    if parent and (not actionParent or actionParent.CData ~= parent.CData) then
        -- Reparented controls can outlive the XML context during hot reload.
        for _, child in ipairs(parent:GetChildren()) do
            if child:GetID() == "SpyAction" and child.CData ~= Controls.SpyAction.CData and
                Child(child, "SpyToggle") then parent:DestroyChild(child); end
        end
        Controls.SpyAction:ChangeParent(parent); actionParent = parent;
    end
    Controls.SpyAction:SetHide(not spy or parent == nil);
    Controls.SpyToggleIcon:SetIcon("ICON_UNIT_SPY");
    if spy then
        local key = tostring(selected:GetID());
        local entry = Registry()[key];
        local reason = pending[key] and "SAVING" or blocked[key] and "SAVE_FAILED" or
            urgentPauses[key] or (entry and not entry.Enabled and entry.Reason) or
            status[key] or (entry and entry.Enabled and "RUNNING" or "ASSIGN_FIRST");
        local enabled = entry ~= nil and entry.Enabled == true and not blocked[key] and not urgentPauses[key];
        Controls.SpyToggle:SetSelected(enabled == true);
        Controls.SpyToggle:SetToolTipString(Text("TITLE") .. "[NEWLINE]" .. Text(reason) .. "[NEWLINE][NEWLINE]" ..
            Text(enabled and "DISABLE" or "ENABLE") .. "[NEWLINE]" .. Text("HELP"));
        Controls.SpyToggle:SetDisabled(not ActiveTurn() or pending[tostring(selected:GetID())] ~= nil);
    end
    if parent then parent:CalculateSize(); parent:ReprocessAnchoring(); end

end

local function Update(delta)
    clock = clock + delta; elapsed = elapsed + delta;
    if elapsed < 0.5 then return; end
    local interval = elapsed;
    elapsed = 0;
    local ready = ActiveTurn() and not UI.IsGameCoreBusy();
    local registry = Registry();
    for key, request in pairs(pending) do
        if not ready then request.deadline = request.deadline + interval; end
        local entry = registry[key];
        if request.action == "reserve" and entry and not entry.Enabled then
            pending[key] = nil;
            status[key] = nil;
            if not closing[key] and not assignments[key] then blocked[key], intents[key] = nil, nil; end
        elseif (request.action == "remove" and entry == nil) or (entry and entry.Token == request.token) then
            -- Acknowledged reservations can arrive between turns. Keep the
            -- dispatch until the local player can act, then recheck its target.
            if not request.after or ready or urgentPauses[key] then
                pending[key] = nil;
                if request.action == "off" then closing[key] = nil; end
                if not closing[key] and not assignments[key] then blocked[key], intents[key] = nil, nil; end
                status[key] = nil;
                if request.after and not urgentPauses[key] then request.after(); end
            end
        elseif clock >= request.deadline then
            pending[key] = nil; status[key] = "SAVE_FAILED";
            -- No automatic retry loop on a rejected or missing gameplay operation.
            blocked[key] = true;
            closing[key] = nil;
            urgentPauses[key] = nil;
        end
    end
    ProcessAssignments(ready, interval);
    if ready then
        for key in pairs(closing) do
            if not pending[key] then
                if Registry()[key] then Send(tonumber(key), "off");
                else closing[key], blocked[key], intents[key] = nil, nil, nil; end
            end
        end
        for key, reason in pairs(urgentPauses) do
            if not pending[key] then
                local entry = Registry()[key];
                if entry and entry.Enabled then Pause(tonumber(key), reason); end
                urgentPauses[key] = nil;
            end
        end
        for key, entry in pairs(Registry()) do
            if not urgentPauses[key] then Process(tonumber(key), entry); end
        end
    end
    Refresh();
end

local api = {};
api.BeginAssignment = BeginAssignment;
api.IsRepeatable = SpyRepeat.IsRepeatable;
api.Registry = Registry;
api.DefaultRepeat = function(id, plotIndex)
    local entry = Registry()[tostring(id)];
    local unit = Player() and Player():GetUnits():FindID(id);
    local plot = Map.GetPlotByIndex(plotIndex);
    local city = plot and Cities.GetPlotPurchaseCity(plot);
    return entry ~= nil and entry.Enabled and not blocked[tostring(id)] and unit and city and
        unit:GetName() == entry.Name and unit:GetType() == entry.UnitType and
        city:GetOwner() == entry.CityOwner and city:GetID() == entry.CityID or false;
end;
api.Inspect = function(id)
    local key = tostring(id);
    local entry = Registry()[key];
    local unit = Player() and Player():GetUnits():FindID(id);
    local present = SpyRepeat.IsSpy(unit) and unit:GetX() >= 0;
    local reason = assignments[key] and "ASSIGNING" or closing[key] and "STOPPING" or
        (pending[key] and pending[key].action ~= "reserve") and "SAVING" or
        blocked[key] and (status[key] == "ASSIGN_FAILED" and "ASSIGN_FAILED" or "SAVE_FAILED") or
        urgentPauses[key] or (entry and not entry.Enabled and entry.Reason) or status[key] or
        (entry and entry.Enabled and "RUNNING" or "ASSIGN_FIRST");
    local enabled = entry ~= nil and entry.Enabled and not blocked[key] and not urgentPauses[key];
    local operation = present and CurrentOperation(unit);
    local snapshot = present and Snapshot(unit);
    local resumable = snapshot ~= nil;
    if present and not operation and entry and unit:GetName() == entry.Name and unit:GetType() == entry.UnitType then
        local _, target = Target(entry);
        local current = CityAtUnit(unit);
        resumable = target and current and target:GetOwner() == current:GetOwner() and target:GetID() == current:GetID();
    end
    local action = enabled and "DISABLE" or resumable and "ENABLE" or "GO_ASSIGN";
    if reason == "SAVE_FAILED" and intents[key] and intents[key].action == "off" then action = "RETRY_OFF";
    elseif reason == "SAVE_FAILED" then action = "RETRY";
    elseif not present then action = "GO_OVERVIEW"; reason = "OFF_MAP";
    elseif AwaitingEscape(unit) then action = "GO_OVERVIEW"; reason = "ESCAPE";
    elseif HasPromotion(unit) then action = "GO_PROMOTE"; reason = "PROMOTION";
    elseif not enabled and resumable then
        action = entry and "RESUME" or "ENABLE";
        if reason == "PROMOTION" or reason == "ESCAPE" then reason = "READY"; end
    end
    if operation and not SpyRepeat.IsRepeatable(operation) and action == "GO_ASSIGN" then action = "GO_OVERVIEW"; end
    local mission = snapshot and GameInfo.UnitOperations[snapshot.Operation] or entry and GameInfo.UnitOperations[entry.Operation];
    local plot = entry and Map.GetPlotByIndex(entry.Plot) or present and Map.GetPlot(unit:GetX(), unit:GetY());
    local city = plot and Cities.GetPlotPurchaseCity(plot);
    local targetName = city and city.GetName and Locale.Lookup(city:GetName()) or Text("NO_MISSION");
    if plot and plot.GetDistrictType then
        local district = GameInfo.Districts[plot:GetDistrictType()];
        if district then targetName = targetName .. " · " .. Locale.Lookup(district.Name); end
    end
    return {id = id, name = Locale.Lookup(unit and unit:GetName() or entry and entry.Name or Text("AWAY")),
        enabled = enabled == true, reason = reason, action = action,
        canAct = ActiveTurn() and not assignments[key] and not closing[key] and
            (not pending[key] or pending[key].action == "reserve"),
        mission = mission and Locale.Lookup(mission.Description or mission.OperationType) or Text("NO_MISSION"),
        target = targetName, status = Text(reason), actionText = Text(action)};
end;
api.Act = function(id)
    local model = api.Inspect(id);
    if not model.canAct then return; end
    if model.action == "DISABLE" or model.action == "RETRY_OFF" then Stop(id);
    elseif model.action == "ENABLE" or model.action == "RESUME" or model.action == "RETRY" then Enable(id);
    elseif model.action == "GO_OVERVIEW" then LuaEvents.PartialScreenHooks_OpenEspionage();
    else
        local unit = Player():GetUnits():FindID(id);
        if not SpyRepeat.IsSpy(unit) then return; end
        UI.SelectUnit(unit);
        if model.action == "GO_PROMOTE" then LuaEvents.UnitPanel_PromoteUnit();
        elseif unit:IsReadyToMove() then UI.SetInterfaceMode(InterfaceModeTypes.SPY_CHOOSE_MISSION); end
    end
    Refresh();
end;
ExposedMembers.SpyRepeatUI = api;
if Controls.UpdateAnchor then
    include("SpyRepeat_Presentation");
    presentation = SpyRepeat_CreatePresentation(api);
end

Controls.SpyToggle:RegisterCallback(Mouse.eLClick, function()
    local unit = UI.GetHeadSelectedUnit();
    if unit and unit:GetOwner() == Game.GetLocalPlayer() and SpyRepeat.IsSpy(unit) then
        if presentation then api.Act(unit:GetID()); else Toggle(unit:GetID()); end
        Refresh();
    end
end);
Events.UnitSelectionChanged.Add(Refresh);
Events.SpyMissionCompleted.Add(MissionCompleted);
Events.UnitOperationStarted.Add(OperationStarted);
local function StartUpdates()
    CleanLegacyOverview();
    ContextPtr:SetHide(false);
    ContextPtr:SetUpdate(Update);
end
Events.LoadScreenClose.Add(StartUpdates);
ContextPtr:SetInitHandler(StartUpdates);
StartUpdates();
print("[SpyRepeat] UI loaded (0.2.4 native action and chooser guidance)");

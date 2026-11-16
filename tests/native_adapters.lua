local function Control(parent, height)
    local c = {CData = {}, children = {}, hidden = false, height = height or 24, y = 0, parent = parent};
    if parent then parent.children[#parent.children + 1] = c; end
    function c:GetParent() return self.parent; end
    function c:GetChildren() return self.children; end
    function c:SetHide(value) self.hidden = value; end
    function c:IsHidden() return self.hidden; end
    function c:SetCheck(value) self.checked = value; end
    function c:SetDisabled(value) self.disabled = value; end
    function c:RegisterCheckHandler(fn) self.check = fn; end
    function c:RegisterCallback(_, fn) self.click = fn; end
    function c:SetText(value) self.text = value; end
    function c:GetSizeY() return self.height; end
    function c:SetSizeY(value) self.height = value; end
    function c:SetOffsetY(value) self.y = value; end
    function c:GetOffsetY() return self.y; end
    function c:GetParentRelativeSizeY() return self.relativeY; end
    function c:SetParentRelativeSizeY(value)
        self.height = self.height + value - (self.relativeY or 0);
        self.relativeY = value;
    end
    function c:ReprocessAnchoring() end
    function c:CalculateSize() end
    function c:CalculateInternalSize() end
    return c;
end
Mouse = {eLClick = 1};
Locale = {Lookup = function(s) return s; end};
local builds, assignments, bindings = {}, {}, {};
local defaults = false;
local api = {Build = function(name, parent)
    local i = {SRRoot = Control(parent, 62), SRCheck = Control(), SRChoice = Control(), SRHint = Control(), SRLabel = Control()};
    builds[name] = i; return i;
end, DefaultRepeat = function() return defaults; end,
IsRepeatable = function(op) return op.repeatable; end,
BeginAssignment = function(...) assignments[#assignments + 1] = {...}; end,
BindRow = function(owner, instance, id) bindings[#bindings + 1] = {instance = instance, id = id}; end,
ReleaseRows = function() end};
ExposedMembers = {SpyRepeatUI = api};
local spy = {GetID = function() return 17; end, GetOwner = function() return 0; end,
    GetType = function() return 1; end, GetX = function() return 5; end, GetY = function() return 6; end};
local plot = {GetIndex = function() return 501; end};
Game = {GetLocalPlayer = function() return 0; end};
Players = {[0] = {GetUnits = function() return {FindID = function() return spy; end}; end}};
GameInfo = {UnitOperations = {[45] = {repeatable = true}, [47] = {repeatable = false}}, Units = {[1] = {Spy = true}}};
Map = {GetPlot = function() return plot; end};
LuaEvents = {EspionageChooser_ShowMissionBriefing = {Add = function(fn) LuaEvents.show = fn; end, Remove = function() end}};
local frame = Control(nil, 460);
Controls = {MissionTitle = Control(frame), AcceptButton = Control()};
local accepted, closed = 0, 0;
include = function()
    function RefreshStack() end
    function OnShowMissionBriefing() RefreshStack(); end
    function OnAccept() accepted = accepted + 1; Close(); end
    function Close() closed = closed + 1; end
end;
assert(loadfile('mod/SpyRepeat_Briefing.lua'))();
LuaEvents.show(45, 17, plot);
local draft = builds.SRBriefingInstance;
assert(not draft.SRCheck.checked and frame.height == 542);
draft.SRChoice.click(); assert(draft.SRCheck.checked); Close();
assert(#assignments == 0 and frame.height == 460, 'cancel committed a draft or leaked layout');
LuaEvents.show(45, 17, plot); assert(not draft.SRCheck.checked, 'cancelled checkbox carried over');
draft.SRCheck.check(true); Controls.AcceptButton.click();
assert(accepted == 1 and #assignments == 1 and assignments[1][4] == true and frame.height == 460);
LuaEvents.show(47, 17, plot); assert(draft.SRCheck.disabled and draft.SRChoice.disabled and not draft.SRCheck.checked);
Controls.AcceptButton:SetHide(true); RefreshStack(); assert(draft.SRRoot.hidden and frame.height == 460, 'results screen inherited briefing strip');

GameConfiguration = {GetValue = function() return 'RULESET_EXPANSION_2'; end};
local cityOwner = 0;
Cities = {GetPlotPurchaseCity = function() return {GetOwner = function() return cityOwner; end}; end};
UI = {GetHeadSelectedUnit = function() return spy; end};
UnitOperationTypes = {SPY_COUNTERSPY = 101};
local destination = false;
Controls = {MissionPanel = Control(Control()), MissionGrid = Control(), DestinationChooserButtons = Control(), MissionScrollPanel = Control()};
-- The user's UI collection wraps the native panel: its offset is 6, not 133.
Controls.MissionPanel.y = 6;
local nativeCounter = 0;
include = function(name)
    assert(name == 'EspionageChooser_Expansion1');
    function RefreshBottom() Controls.DestinationChooserButtons:SetHide(not destination); Controls.MissionScrollPanel.relativeY = -132; Controls.MissionScrollPanel.height = 600; end
    function OnCounterspySelected(p) assert(p == plot); nativeCounter = nativeCounter + 1; end
    function Close() end
end;
assert(loadfile('mod/SpyRepeat_Chooser.lua'))();
RefreshBottom(); local counter = builds.SRCounterInstance;
assert(not counter.SRCheck.checked and Controls.MissionPanel.y == 88);
assert(counter.SRRoot.y == 6 and Controls.MissionScrollPanel.height == 518);
assert(Controls.MissionScrollPanel.relativeY == -214, 'native parent-relative height was not reduced');
RefreshBottom(); assert(Controls.MissionScrollPanel.height == 518, 'refresh repeatedly shrank scroll area');
counter.SRChoice.click(); assert(counter.SRCheck.checked); OnCounterspySelected(plot);
assert(nativeCounter == 1 and assignments[#assignments][3] == 501 and assignments[#assignments][4]);
Close(); RefreshBottom(); assert(not counter.SRCheck.checked, 'new chooser inherited cancelled intent');
destination = true; RefreshBottom();
assert(not counter.SRRoot.hidden and counter.SRCheck.hidden and counter.SRChoice.disabled);
assert(counter.SRHint.text == 'LOC_SR_DESTINATION_HELP' and Controls.MissionPanel.y == 88);
local committed = #assignments; counter.SRChoice.click(); OnCounterspySelected(plot);
assert(#assignments == committed, 'destination preview committed a repeat assignment');
destination = false; cityOwner = 1; RefreshBottom();
assert(counter.SRHint.text == 'LOC_SR_MISSION_LIST_HELP' and counter.SRCheck.hidden);
Controls.MissionGrid:SetHide(true); RefreshBottom();
assert(counter.SRRoot.hidden and Controls.MissionPanel.y == 6, 'hidden mission grid left guidance visible');

local stack = Control(); local pool = {Control(stack, 115), Control(stack, 70)};
for _, top in ipairs(pool) do
    Control(top, top.height - 8); -- Visible native body, excluding grid padding.
    function top:GetSizeY()
        local measured = self.height;
        for _, child in ipairs(self.children) do measured = math.max(measured, child.y + child.height); end
        return measured; -- Civ grids include hidden children when auto-sizing.
    end
end
local order = { {GetID = function() return 9; end}, {GetID = function() return 3; end} };
local cursor;
Controls = {OperativeStack = stack, OperativeScrollPanel = Control()};
ContextPtr = {SetShutdown = function() end};
include = function(name)
    assert(name == 'EspionageOverview_Expansion1');
    function AddOperative() cursor = cursor + 1; pool[cursor]:SetHide(false); end
    function RefreshOperatives()
        cursor = 0; for _, c in ipairs(pool) do c:SetHide(true); end
        for _, u in ipairs(order) do AddOperative(u); end
    end
    function OnShutdown() end
end;
assert(loadfile('mod/SpyRepeat_Overview.lua'))();
RefreshOperatives();
assert(bindings[1].id == 9 and bindings[2].id == 3);
local first = bindings[1].instance;
order[1], order[2] = order[2], order[1]; RefreshOperatives();
assert(bindings[3].id == 3 and bindings[4].id == 9 and bindings[3].instance == first, 'pooled row retained previous unit identity');
assert(#pool[1].children == 2 and #pool[2].children == 2, 'refresh duplicated controls');
assert(first.SRRoot.y == 115, 'pooled row gained height on refresh');
RefreshOperatives(); assert(first.SRRoot.y == 115, 'repeated refresh kept growing the row');
local function Event()
    local callbacks = {};
    return setmetatable({Add = function(fn) callbacks[fn] = true; end,
        Remove = function(fn) callbacks[fn] = nil; end},
        {__call = function() for fn in pairs(callbacks) do fn(); end end});
end
LuaEvents = {PartialScreenHooks_OpenEspionage = Event(), EspionageChooser_ShowMissionBriefing = Event()};
Controls = {};
for _, id in ipairs({'SpyAction','SpyToggle','SpyToggleIcon'}) do
    Controls[id] = Control();
    Controls[id].SetSelected = function(c, value) c.selected = value; end;
    Controls[id].SetIcon = function(c, value) c.icon = value; end;
    Controls[id].SetColorByName = function(c, value) c.color = value; end;
    Controls[id].SetToolTipString = function(c, value) c.tooltip = value; end;
end
ContextPtr = {LookUpControl = function() end};
SpyRepeat = {IsSpy = function(unit) return unit == spy; end};
include = function(name) assert(name == 'SupportFunctions'); end;
TruncateStringWithTooltip = function(c, width, text) c.truncateWidth = width; c:SetText(text); end;
local view = {name='Name',mission='Mission',target='City',status='Status',reason='RUNNING',actionText='Stop',canAct=true,enabled=true};
api.Inspect = function() return view; end;
assert(loadfile('mod/SpyRepeat_Presentation.lua'))();
local presentation = SpyRepeat_CreatePresentation(api);
presentation.Refresh();
assert(Controls.SpyToggle.selected and Controls.SpyToggleIcon.color == 'OperationChance_Yellow');
assert(Controls.SpyToggleIcon.icon == 'ICON_UNITOPERATION_AUTO_EXPLORE');
assert(Controls.SpyToggle.tooltip:find('Stop',1,true) and Controls.SpyToggle.tooltip:find('Mission · City',1,true));
view.enabled = false; view.canAct = false; presentation.Refresh();
assert(not Controls.SpyToggle.selected and Controls.SpyToggle.disabled and Controls.SpyToggleIcon.color == 'White');
assert(Controls.SpyToggleIcon.icon == 'ICON_UNITOPERATION_AUTO_EXPLORE', 'enabled state changed the action symbol');
presentation.Shutdown();
print('SpyRepeat native adapter regression passed: row click, cancel, accept, preparation, results, counterspy district, destination preview, row pooling, stable heights, identity and direct-action presentation');

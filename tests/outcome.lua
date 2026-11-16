local stored;
local function reset()
    stored = { ["1"]={Enabled=true, Name="A", Reason="RUNNING"},
        ["2"]={Enabled=true, Name="B", Reason="RUNNING"} };
end
local player = {
    GetProperty=function() return stored; end,
    SetProperty=function(_, _, value) stored=value; end,
    GetDiplomacy=function() error("Gameplay must not call the UI-only mission API"); end
};
Players={[0]=player}; ExposedMembers={};
SpyRepeat={Property="SpyRepeat_Registry_v1"};
include=function() end;
GameEvents={SpyRepeat_Set={Add=function() end}};
local completed;
Events={SpyMissionCompleted={Add=function(f) completed=f; end}};
assert(loadfile("mod/SpyRepeat_State.lua"))();
reset(); completed(0,1); assert(stored["1"].Enabled);
ExposedMembers.SpyRepeat_ReadMissionOutcome=function() error("UI shutting down"); end;
completed(0,1); assert(stored["1"].Enabled);
ExposedMembers.SpyRepeat_ReadMissionOutcome=function() return "A",nil; end;
completed(0,1); assert(stored["1"].Enabled);
local old=stored;
ExposedMembers.SpyRepeat_ReadMissionOutcome=function() return "A","ESCAPE"; end;
completed(0,1);
assert(not stored["1"].Enabled and stored["1"].Reason=="ESCAPE");
assert(stored["2"].Enabled and old["1"].Enabled);
reset(); ExposedMembers.SpyRepeat_ReadMissionOutcome=function() return "A","OFF_MAP"; end;
completed(0,1); assert(not stored["1"].Enabled and stored["2"].Enabled);
reset(); ExposedMembers.SpyRepeat_ReadMissionOutcome=function() return "A","INVALID"; end;
completed(0,1); assert(stored["1"].Enabled);
completed(99,1); assert(stored["1"].Enabled);
print("Spy outcome regression passed: missing UI, shutdown, success, escape, capture/death, identity, copy-on-write, invalid outcome");

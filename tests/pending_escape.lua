local source=assert(SPY_REPEAT_SOURCE,'Run scripts/run_regression_checks.py');
local current=assert(source:match('local function CurrentOperation%(unit%)(.-)\nend'));
local awaiting=assert(source:match('local function AwaitingEscape%(unit%)(.-)\nend'));
local process=assert(source:match('local function Process%(id, entry%)(.-)\nend'));
GameInfo={UnitOperations={[45]={OperationType='SIPHON'},[39]={OperationType='COUNTER'}}};
SpyRepeat={IsRepeatable=function(op) return op~=nil;end,IsSpy=function(u)return u~=nil;end};
local unit={op=45,ending=0,GetSpyOperation=function(s)return s.op;end,
    GetSpyOperationEndTurn=function(s)return s.ending;end,
    GetName=function()return 'A';end,GetType=function()return 7;end};
local player={GetUnits=function()return {FindID=function()return unit;end};end};
local stopped;
local check,run=assert(load('local pending,blocked,closing,assignments={},{},{},{};local function Player()return TestPlayer;end; local function Pause(id,reason) TestPause(id,reason);end; local function HasPromotion()error("escape must stop before promotion or dispatch");end; local function CurrentOperation(unit)'..current..'\nend\nlocal function AwaitingEscape(unit)'..awaiting..'\nend\nlocal function Process(id,entry)'..process..'\nend\nreturn AwaitingEscape,Process'))();
TestPlayer=player;TestPause=function(id,reason)stopped={id,reason};end;
assert(check(unit));run(1,{Enabled=true,Name='A',UnitType=7});
assert(stopped[1]==1 and stopped[2]=='ESCAPE');
unit.ending=233;assert(not check(unit),'ongoing assignment must remain eligible');
unit.op=-1;unit.ending=0;assert(not check(unit),'idle spy is not escaping');
unit.op=45;unit.ending=nil;assert(not check(unit));
unit.GetSpyOperationEndTurn=nil;assert(not check(unit),'missing optional UI API must not crash');
assert(source:find('if AwaitingEscape(unit) then status[key] = "ESCAPE"; return; end',1,true),'manual re-enable must also reject pending escape');
print('Spy pending-escape regression passed: native zero deadline, no dispatch, ongoing/idle/missing API, re-enable guard');

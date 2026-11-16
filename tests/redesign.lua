-- Appended to the established fixture by verify.py; executes production code.
local function API() return ExposedMembers.SpyRepeatUI; end
local w = Fixture();
assert(not API().DefaultRepeat(1, 1000));
assert(API().BeginAssignment(1, 45, 1000, true));
w:tick(); assert(not w.registry['1'], 'checkbox committed before native task started');
Events.UnitOperationStarted.Fire(0, 1, 45); w:tick(); w:tick();
assert(w.registry['1'].Enabled and API().DefaultRepeat(1, 1000));
assert(not API().DefaultRepeat(2, 1000), 'draft leaked between spies');
w.city.owner = 2; assert(not API().DefaultRepeat(1, 1000), 'draft carried into another city');

w = Fixture(); API().BeginAssignment(1, 45, 1000, true); w:tick(9);
assert(not w.registry['1'] and API().Inspect(1).reason == 'ASSIGN_FAILED');
assert(#w.requests == 0, 'rejected native mission triggered repeat');

w = Fixture(); w:enable();
API().BeginAssignment(1, 46, 1000, false); w.a.op = 46;
Events.UnitOperationStarted.Fire(0, 1, 46); w:tick(); w:tick();
assert(not w.registry['1'].Enabled and w.a.op == 46, 'unchecked new assignment did not turn repeat off');

w = Fixture(); API().BeginAssignment(1, 45, 1000, true);
w.a.op = 48; Events.UnitOperationStarted.Fire(0, 1, 48); w:tick();
assert(not w.registry['1'] and #w.requests == 0, 'unexpected operation accepted as assignment');

w = Fixture(); API().BeginAssignment(1, 45, 1000, true);
Events.UnitOperationStarted.Fire(0, 1, 45); w.a.name = 'Replacement'; w:tick();
assert(not w.registry['1'], 'replacement unit inherited draft');

w = Fixture(); API().BeginAssignment(1, 45, 1000, true);
w.active = false; w:tick(30); Events.UnitOperationStarted.Fire(0, 1, 45);
w.active = true; w:tick(); w:tick(); assert(w.registry['1'].Enabled, 'turn boundary expired draft');

-- Stop must overtake an in-flight automatic reservation and never invert on retry.
w = Fixture(); w:enable(); w:idle(); w.delayed = true; w:tick();
assert(API().Inspect(1).action == 'DISABLE' and API().Inspect(1).canAct);
API().Act(1); w:ack(); w:tick();
assert(#w.requests == 0 and w.settings[#w.settings].Action == 'off');
w:tick(9); assert(API().Inspect(1).action == 'RETRY_OFF');
w.delayed = false; API().Act(1); w:tick();
assert(not w.registry['1'].Enabled and #w.requests == 0, 'retry off enabled repeat');

w = Fixture(); w:enable(); w.a.promotion = true; w:tick(); w:tick();
assert(API().Inspect(1).action == 'GO_PROMOTE');
w.a.promotion = false; w:idle();
assert(API().Inspect(1).action == 'RESUME' and API().Inspect(1).reason == 'READY');
w:tick(); assert(#w.requests == 0, 'resolved pause resumed without consent');

w = Fixture(); w:enable(); w.a.ending = 0; w:tick();
assert(API().Inspect(1).reason == 'ESCAPE' and API().Inspect(1).action == 'GO_OVERVIEW');

w = Fixture(); API().BeginAssignment(1, 47, 1000, true); w.a.op = 47;
Events.UnitOperationStarted.Fire(0, 1, 47); w:tick();
assert(not w.registry['1'], 'preparation action became repeatable');
print('SpyRepeat redesign regression passed: native acceptance, draft isolation, failed assignment, unchecked assignment, identity, turns, stop race, retry direction, promotion, escape, preparation');

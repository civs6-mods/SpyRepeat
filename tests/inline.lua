-- Regression: native controls can have distinct Lua wrappers for one CData.
local source = assert(SPY_REPEAT_SOURCE, "Run scripts/run_regression_checks.py");
local child = assert(source:match("local function Child%(parent, id%)(.-)\nend"));
local inline = assert(source:match("local function RemoveOverviewControls%(native%)(.-)\nend"));
local find = assert(load("local function Child(parent,id)" .. child ..
    "\nend\nreturn function(native)" .. inline .. "\nend"))();
local serial = 0;
local function node(id, children)
    serial = serial + 1;
    return {id = id, children = children or {}, pointer = serial};
end
local function wrap(n)
    return {
        CData = n.pointer,
        GetID = function() return n.id; end,
        GetChildren = function()
            local result = {};
            for _, c in ipairs(n.children) do result[#result + 1] = wrap(c); end
            return result;
        end,
        DestroyChild = function(_, target)
            for i, c in ipairs(n.children) do
                if c.pointer == target.CData then table.remove(n.children, i); return; end
            end
            error("destroyed a foreign child");
        end
    };
end
local function row() return node("Root", {node("Toggle"), node("Status")}); end
local foreign = node("Root", {node("OtherModButton")});
local kept = row();
local native = node("Top", {node("OperativeName"), foreign, kept});
for _ = 1, 100 do
    find(wrap(native));
    assert(#native.children == 2);
end
for _ = 1, 80 do native.children[#native.children + 1] = row(); end
find(wrap(native));
assert(#native.children == 2, "all injected controls must be removed");
assert(native.children[2] == foreign, "another mod's Root must survive");
native.children = {node("OperativeName"), foreign};
find(wrap(native));
local replacement = row(); native.children[#native.children + 1] = replacement;
find(wrap(native));
assert(#native.children == 2);
print("Spy overview cleanup regression passed: 100 fresh wrappers, 80 duplicates, foreign controls, recycled row");

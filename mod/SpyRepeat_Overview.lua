if GameConfiguration.GetValue("RULESET") == "RULESET_STANDARD" then
    include("EspionageOverview");
else
    include("EspionageOverview_Expansion1");
end

local baseAdd, baseRefresh, baseShutdown = AddOperative, RefreshOperatives, OnShutdown;
local instances = {};
local owner = {}; -- Unique per context; pooled rows are always rebound to a unit ID.
local function API() return ExposedMembers.SpyRepeatUI; end
function RefreshOperatives()
    if API() then API().ReleaseRows(owner); end
    for _, instance in pairs(instances) do
        -- Auto-sized native grids still include hidden children. Reset the
        -- footer offset before measuring, otherwise every refresh grows a row.
        instance.SRRoot:SetOffsetY(0); instance.SRRoot:SetHide(true);
    end
    baseRefresh();
    Controls.OperativeStack:CalculateSize(); Controls.OperativeStack:ReprocessAnchoring();
    Controls.OperativeScrollPanel:CalculateInternalSize();
end
function AddOperative(spy)
    local before = {};
    for _, child in ipairs(Controls.OperativeStack:GetChildren()) do
        if not child:IsHidden() then before[child.CData] = true; end
    end
    baseAdd(spy);
    if not API() then return; end
    local native, count = nil, 0;
    for _, child in ipairs(Controls.OperativeStack:GetChildren()) do
        if not child:IsHidden() and not before[child.CData] then native = child; count = count + 1; end
    end
    -- Never infer identity from a displayed name or an assumed sort order.
    if count ~= 1 then return; end
    local instance = instances[native.CData];
    if instance then instance.SRRoot:SetOffsetY(0); instance.SRRoot:SetHide(true); end
    -- GetSizeY on an auto-sized Grid can retain its previous frame's height.
    -- Measure native visible content directly, excluding our pooled footer.
    local height = 0;
    for _, child in ipairs(native:GetChildren()) do
        if not child:IsHidden() and (not instance or child.CData ~= instance.SRRoot.CData) then
            height = math.max(height, child:GetOffsetY() + child:GetSizeY());
        end
    end
    height = height + 8; -- Native Top has 4 px of padding on each side.
    if not instance then
        instance = API().Build("SROverviewInstance", native); instances[native.CData] = instance;
    end
    instance.SRRoot:SetOffsetY(height);
    instance.SRRoot:SetHide(false);
    API().BindRow(owner, instance, spy:GetID());
    native:SetSizeY(height + instance.SRRoot:GetSizeY() + 8);
    native:ReprocessAnchoring();
end
function OnShutdown()
    if API() then API().ReleaseRows(owner); end
    if baseShutdown then baseShutdown(); end
end
ContextPtr:SetShutdown(OnShutdown);
print("[SpyRepeat] Native operative overview integrated");

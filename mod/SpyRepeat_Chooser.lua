if GameConfiguration.GetValue("RULESET") == "RULESET_STANDARD" then
    include("EspionageChooser");
else
    include("EspionageChooser_Expansion1");
end

local baseRefresh, baseCounterspy, baseClose = RefreshBottom, OnCounterspySelected, Close;
local instance, draftID, draftPlot, enabled;
local baseOffset = Controls.MissionPanel:GetOffsetY();
local function API() return ExposedMembers.SpyRepeatUI; end
function RefreshBottom()
    baseRefresh();
    Controls.MissionPanel:SetOffsetY(baseOffset);
    local spy = UI.GetHeadSelectedUnit();
    local plot = spy and Map.GetPlot(spy:GetX(), spy:GetY());
    local city = plot and Cities.GetPlotPurchaseCity(plot);
    local available = API() and spy and spy:GetOwner() == Game.GetLocalPlayer() and
        GameInfo.Units[spy:GetType()].Spy and not Controls.MissionPanel:IsHidden() and
        (not Controls.MissionGrid or not Controls.MissionGrid:IsHidden());
    if not available then
        if instance then instance.SRRoot:SetHide(true); end
        draftID, draftPlot = nil, nil; return;
    end
    if not instance then
        instance = API().Build("SRCounterInstance", Controls.MissionPanel:GetParent());
        -- UI mods may wrap MissionPanel in a separate grid (offset 6 instead
        -- of the base game's 133). Anchor to the actual native panel location.
        instance.SRRoot:SetOffsetY(baseOffset);
        instance.SRCheck:RegisterCheckHandler(function(checked) enabled = checked; end);
        instance.SRChoice:RegisterCallback(Mouse.eLClick, function()
            if not draftID then return; end
            enabled = not enabled; instance.SRCheck:SetCheck(enabled);
        end);
    end
    local destination = not Controls.DestinationChooserButtons:IsHidden();
    local counterspy = not destination and city and city:GetOwner() == Game.GetLocalPlayer();
    if counterspy then
        if draftID ~= spy:GetID() or draftPlot ~= plot:GetIndex() then
            draftID, draftPlot = spy:GetID(), plot:GetIndex();
            enabled = API().DefaultRepeat(draftID, draftPlot);
        end
    else
        draftID, draftPlot, enabled = nil, nil, false;
    end
    instance.SRRoot:SetHide(false);
    instance.SRCheck:SetHide(not counterspy);
    instance.SRChoice:SetDisabled(not counterspy);
    instance.SRLabel:SetText(Locale.Lookup(counterspy and "LOC_SR_COUNTER_REPEAT" or "LOC_SR_TITLE"));
    instance.SRHint:SetText(Locale.Lookup(counterspy and "LOC_SR_COUNTER_HELP" or
        destination and "LOC_SR_DESTINATION_HELP" or "LOC_SR_MISSION_LIST_HELP"));
    instance.SRCheck:SetCheck(enabled);
    Controls.MissionPanel:SetOffsetY(baseOffset + 82);
    -- Native choosers use parent-relative height. SetSizeY is overwritten at
    -- the next anchoring pass, which would push destination buttons offscreen.
    local scroll = Controls.MissionScrollPanel;
    scroll:SetParentRelativeSizeY(scroll:GetParentRelativeSizeY() - 82);
    Controls.MissionPanel:CalculateSize(); Controls.MissionPanel:ReprocessAnchoring();
end
function OnCounterspySelected(districtPlot)
    local spy = UI.GetHeadSelectedUnit();
    if API() and spy and spy:GetID() == draftID and instance and not instance.SRRoot:IsHidden() then
        API().BeginAssignment(draftID, UnitOperationTypes.SPY_COUNTERSPY, districtPlot:GetIndex(), enabled);
    end
    baseCounterspy(districtPlot);
end
function Close()
    draftID, draftPlot = nil, nil;
    if instance then instance.SRRoot:SetHide(true); end
    Controls.MissionPanel:SetOffsetY(baseOffset);
    baseClose();
end
print("[SpyRepeat] Native counterspy chooser integrated");

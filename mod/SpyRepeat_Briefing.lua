include("EspionagePopup");

local baseShow, baseAccept, baseClose, baseRefresh = OnShowMissionBriefing, OnAccept, Close, RefreshStack;
local draft, instance, frame, baseHeight;
local function API() return ExposedMembers.SpyRepeatUI; end
local function HideDraft()
    if instance then instance.SRRoot:SetHide(true); end
    if frame then frame:SetSizeY(baseHeight); frame:ReprocessAnchoring(); end
end
function RefreshStack()
    baseRefresh();
    if not draft or Controls.AcceptButton:IsHidden() or not API() then HideDraft(); return; end
    if not instance then
        frame = Controls.MissionTitle:GetParent(); baseHeight = frame:GetSizeY();
        instance = API().Build("SRBriefingInstance", frame);
        instance.SRCheck:RegisterCheckHandler(function(checked) if draft then draft.enabled = checked; end end);
        instance.SRChoice:RegisterCallback(Mouse.eLClick, function()
            if draft and API().IsRepeatable(GameInfo.UnitOperations[draft.operation]) then
                draft.enabled = not draft.enabled; instance.SRCheck:SetCheck(draft.enabled);
            end
        end);
    end
    local allowed = API().IsRepeatable(GameInfo.UnitOperations[draft.operation]);
    instance.SRRoot:SetHide(false);
    instance.SRCheck:SetDisabled(not allowed);
    instance.SRChoice:SetDisabled(not allowed);
    instance.SRCheck:SetCheck(allowed and draft.enabled);
    instance.SRHint:SetText(Locale.Lookup(allowed and "LOC_SR_DRAFT_HELP" or "LOC_SR_PREPARATION_HELP"));
    frame:SetSizeY(baseHeight + 82); frame:ReprocessAnchoring();
end
function OnShowMissionBriefing(operationHash, spyID, targetPlot)
    local player = Players[Game.GetLocalPlayer()];
    local spy = player and player:GetUnits():FindID(spyID);
    local plot = targetPlot or spy and Map.GetPlot(spy:GetX(), spy:GetY());
    draft = plot and {id = spyID, operation = operationHash, plot = plot:GetIndex(),
        enabled = API() and API().DefaultRepeat(spyID, plot:GetIndex()) or false} or nil;
    baseShow(operationHash, spyID, targetPlot);
end
function OnAccept()
    if draft and API() then API().BeginAssignment(draft.id, draft.operation, draft.plot, draft.enabled); end
    baseAccept();
end
function Close()
    draft = nil; HideDraft(); baseClose();
end
LuaEvents.EspionageChooser_ShowMissionBriefing.Remove(baseShow);
LuaEvents.EspionageChooser_ShowMissionBriefing.Add(OnShowMissionBriefing);
Controls.AcceptButton:RegisterCallback(Mouse.eLClick, OnAccept);
print("[SpyRepeat] Native mission briefing integrated");

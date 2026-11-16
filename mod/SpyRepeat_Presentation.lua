-- Native controls are built by our XML context, then parented into Firaxis UI.
function SpyRepeat_CreatePresentation(api)
    local result = {};
    local parent;
    local rows = {};
    local function Text(key) return Locale.Lookup("LOC_SR_" .. key); end
    api.Build = function(template, target)
        local instance = {};
        ContextPtr:BuildInstanceForControl(template, instance, target);
        return instance;
    end;
    api.BindRow = function(owner, instance, id)
        rows[instance.SRRoot.CData] = {owner = owner, instance = instance, id = id};
        instance.SRAction:RegisterCallback(Mouse.eLClick, function() api.Act(id); end);
    end;
    api.ReleaseRows = function(owner)
        for key, row in pairs(rows) do if row.owner == owner then rows[key] = nil; end end
    end;
    local function RefreshRow(row)
        local view = api.Inspect(row.id);
        row.instance.SRState:SetText(Text("TITLE") .. " · " .. view.status);
        row.instance.SRState:SetToolTipString(view.mission .. "[NEWLINE]" .. view.target .. "[NEWLINE]" .. view.status);
        row.instance.SRAction:SetText(view.actionText);
        row.instance.SRAction:SetDisabled(not view.canAct);
        row.instance.SRAction:SetToolTipString(view.reason == "ESCAPE" and Text("ESCAPE_HELP") or Text("DETAIL_HELP"));
    end
    result.Refresh = function()
        local selected = UI.GetHeadSelectedUnit();
        local spy = selected and selected:GetOwner() == Game.GetLocalPlayer() and SpyRepeat.IsSpy(selected);
        local target = ContextPtr:LookUpControl("/InGame/UnitPanel/StandardActionsStack") or
            ContextPtr:LookUpControl("/InGame/UnitPanel/ActionsStack");
        if target and (not parent or parent.CData ~= target.CData) then
            for _, child in ipairs(target:GetChildren()) do
                if child:GetID() == "SpyAction" and child.CData ~= Controls.SpyAction.CData then
                    for _, nested in ipairs(child:GetChildren()) do
                        if nested:GetID() == "SpyToggle" then target:DestroyChild(child); break; end
                    end
                end
            end
            Controls.SpyAction:ChangeParent(target); parent = target;
        end
        Controls.SpyAction:SetHide(not spy or target == nil);
        if spy then
            local view = api.Inspect(selected:GetID());
            local color = view.enabled and "OperationChance_Yellow" or "White";
            -- Keep the recognizable native automation icon in both states.
            Controls.SpyToggleIcon:SetIcon("ICON_UNITOPERATION_AUTO_EXPLORE");
            Controls.SpyToggleIcon:SetColorByName(color);
            Controls.SpyToggle:SetSelected(view.enabled);
            Controls.SpyToggle:SetDisabled(not view.canAct);
            Controls.SpyToggle:SetToolTipString(Text("TITLE") .. " · " .. view.actionText ..
                "[NEWLINE]" .. view.status .. "[NEWLINE]" .. view.mission .. " · " .. view.target ..
                "[NEWLINE][NEWLINE]" .. Text(view.reason == "ESCAPE" and "ESCAPE_HELP" or "DETAIL_HELP"));
        end
        for key, row in pairs(rows) do
            local ok = pcall(RefreshRow, row);
            if not ok then rows[key] = nil; end -- A native context may have reloaded.
        end
        if parent then parent:CalculateSize(); parent:ReprocessAnchoring(); end
    end;
    result.Shutdown = function()
        rows = {};
        if ExposedMembers.SpyRepeatUI == api then ExposedMembers.SpyRepeatUI = nil; end
    end;
    return result;
end

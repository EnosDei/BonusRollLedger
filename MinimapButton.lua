-- Small draggable minimap button, no libraries. ns.MinimapButton{ name, icon, db, onClick, tooltip }
-- db is a saved table; the button keeps its angle in db.angle and hides when db.hide is true.
local _, ns = ...

function ns.MinimapButton(o)
    local db = o.db
    db.angle = db.angle or 225
    local b = CreateFrame("Button", o.name .. "MinimapButton", Minimap)
    b:SetSize(31, 31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
    b:RegisterForClicks("AnyUp"); b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20); bg:SetPoint("CENTER"); bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(19, 19); icon:SetPoint("CENTER"); icon:SetTexture(o.icon)
    local mask = b:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon); icon:AddMaskTexture(mask)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53); border:SetPoint("TOPLEFT"); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local function Place()
        local a = math.rad(db.angle)
        local r = (Minimap:GetWidth() / 2) + 5
        b:ClearAllPoints(); b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
    end
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            db.angle = math.deg((math.atan2 or atan2)(cy / s - my, cx / s - mx)) % 360
            Place()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnClick", function(self, btn) o.onClick(btn) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT"); o.tooltip(GameTooltip)
        GameTooltip:AddLine("Drag to move. /" .. o.slash .. " minimap hides this button.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place()
    b:SetShown(not db.hide)
    function b.Toggle() db.hide = not db.hide; b:SetShown(not db.hide) end
    return b
end

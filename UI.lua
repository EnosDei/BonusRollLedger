-- Bonus Roll Ledger panel: character picker, per-boss summary, and the roll list.
local ADDON, ns = ...

local ROW_HEIGHT = 20
local panel, selectedChar

local function ClassColored(key)
    local char = BonusRollLedgerDB.chars[key]
    local color = char and char.class and RAID_CLASS_COLORS[char.class]
    if color then return color:WrapTextInColorCode(key) end
    return key
end

local function SortedChars()
    local list = {}
    for key, char in pairs(BonusRollLedgerDB.chars) do
        if #char.rolls > 0 or key == ns.CharKey() then list[#list + 1] = key end
    end
    table.sort(list)
    return list
end

local function SpecLabel(specID)
    local name, icon = ns.SpecInfo(specID)
    if icon then return ("|T%s:14:14:0:0|t %s"):format(icon, name) end
    return name
end

local function ResultText(roll)
    if roll.itemLink then return roll.itemLink end
    if roll.itemID then
        local _, link = C_Item.GetItemInfo(roll.itemID)
        if link then return link end
        return "item " .. roll.itemID
    end
    if roll.kind == "money" then
        return GetMoneyString and GetMoneyString(roll.quantity or 0) or ((roll.quantity or 0) .. " copper")
    end
    if roll.kind == "currency" then return "currency x" .. (roll.quantity or 0) end
    return "|cff888888nothing|r"
end

-- "Boss (Difficulty): Unholy 3, Blood 1"
local function BuildSummary(rolls)
    local groups, order = {}, {}
    for _, r in ipairs(rolls) do
        local key = ns.BossText(r) .. " (" .. ns.DifficultyText(r) .. ")"
        if not groups[key] then groups[key] = {}; order[#order + 1] = key end
        local spec = r.spec or 0
        groups[key][spec] = (groups[key][spec] or 0) + 1
    end
    table.sort(order)
    local lines = {}
    for _, key in ipairs(order) do
        local parts = {}
        for spec, count in pairs(groups[key]) do
            parts[#parts + 1] = SpecLabel(spec) .. " |cffffffff" .. count .. "|r"
        end
        table.sort(parts)
        lines[#lines + 1] = "|cffffd100" .. key .. "|r:  " .. table.concat(parts, "   ")
    end
    if #lines == 0 then return "|cff888888No bonus rolls recorded for this character yet.|r" end
    return table.concat(lines, "\n")
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local function Col(x, width, justify)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", x, 0)
        fs:SetWidth(width)
        fs:SetJustifyH(justify or "LEFT")
        fs:SetWordWrap(false)
        return fs
    end
    row.date = Col(4, 92)
    row.boss = Col(100, 160)
    row.diff = Col(252, 90)
    row.spec = Col(346, 110)
    row.item = Col(460, 210)
    row:SetScript("OnEnter", function(self)
        if not self.roll then return end
        local link = self.roll.itemLink or (self.roll.itemID and select(2, C_Item.GetItemInfo(self.roll.itemID)))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if link then
            GameTooltip:SetHyperlink(link)
        else
            GameTooltip:SetText(ns.BossText(self.roll))
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
        local link = self.roll and (self.roll.itemLink or (self.roll.itemID and select(2, C_Item.GetItemInfo(self.roll.itemID))))
        if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
    end)
    return row
end

local function Render()
    if not panel or not panel:IsShown() then return end
    if not selectedChar or not BonusRollLedgerDB.chars[selectedChar] then selectedChar = ns.CharKey() end
    local char = ns.EnsureChar(selectedChar)

    panel.charButton:SetText(ClassColored(selectedChar))

    -- Newest first.
    local rolls = {}
    for _, r in ipairs(char.rolls) do rolls[#rolls + 1] = r end
    table.sort(rolls, function(a, b) return (a.ts or 0) > (b.ts or 0) end)

    panel.summary:SetText(BuildSummary(rolls))
    panel.count:SetText(#rolls .. " roll" .. (#rolls == 1 and "" or "s"))

    for i, r in ipairs(rolls) do
        local row = panel.rows[i] or CreateRow(panel.list, i)
        panel.rows[i] = row
        row.roll = r
        row.date:SetText(r.ts and date("%b %d %H:%M", r.ts) or "?")
        row.boss:SetText(ns.BossText(r))
        row.diff:SetText(ns.DifficultyText(r))
        row.spec:SetText(SpecLabel(r.spec))
        row.item:SetText(ResultText(r))
        row:Show()
    end
    for i = #rolls + 1, #panel.rows do panel.rows[i]:Hide() end
    panel.list:SetHeight(math.max(1, #rolls * ROW_HEIGHT))
end
ns.Refresh = Render

-- Item names arrive in bursts; redraw once shortly after.
local refreshQueued
function ns.RefreshSoon()
    if refreshQueued or not panel or not panel:IsShown() then return end
    refreshQueued = true
    C_Timer.After(0.3, function() refreshQueued = false; Render() end)
end

local function OpenCharMenu(owner)
    local chars = SortedChars()
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            for _, key in ipairs(chars) do
                root:CreateRadio(ClassColored(key) .. "  |cff888888(" .. #BonusRollLedgerDB.chars[key].rolls .. ")|r",
                    function() return key == selectedChar end,
                    function() selectedChar = key; Render() end)
            end
        end)
    else
        -- Fallback: cycle through characters.
        for i, key in ipairs(chars) do
            if key == selectedChar then selectedChar = chars[i % #chars + 1]; break end
        end
        Render()
    end
end

local function BuildPanel()
    panel = CreateFrame("Frame", "BonusRollLedgerFrame", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(700, 480)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("HIGH")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetClampedToScreen(true)
    panel:Hide()
    table.insert(UISpecialFrames, "BonusRollLedgerFrame") -- Esc closes it

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.title:SetPoint("TOP", 0, -5)
    panel.title:SetText("Bonus Roll Ledger")

    panel.charButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.charButton:SetSize(240, 22)
    panel.charButton:SetPoint("TOPLEFT", 12, -30)
    panel.charButton:SetScript("OnClick", OpenCharMenu)

    panel.count = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.count:SetPoint("LEFT", panel.charButton, "RIGHT", 10, 0)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPRIGHT", -14, -36)
    hint:SetText("Loot spec decides the bonus roll loot table")

    panel.summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.summary:SetPoint("TOPLEFT", 14, -62)
    panel.summary:SetPoint("RIGHT", -14, 0)
    panel.summary:SetJustifyH("LEFT")
    panel.summary:SetSpacing(3)

    local header = CreateFrame("Frame", nil, panel)
    header:SetHeight(18)
    header:SetPoint("TOPLEFT", panel.summary, "BOTTOMLEFT", -4, -12)
    header:SetPoint("RIGHT", -34, 0)
    for _, col in ipairs({ { 4, "Date" }, { 100, "Boss" }, { 252, "Difficulty" }, { 346, "Loot spec" }, { 460, "Result" } }) do
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", col[1], 0)
        fs:SetText(col[2])
    end

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)
    panel.list = CreateFrame("Frame", nil, scroll)
    panel.list:SetSize(650, 1)
    scroll:SetScrollChild(panel.list)
    scroll:SetScript("OnSizeChanged", function(self, w) panel.list:SetWidth(w) end)
    panel.rows = {}

    panel:SetScript("OnShow", Render)
end

function ns.Toggle()
    if not panel then BuildPanel() end
    if panel:IsShown() then panel:Hide() else selectedChar = selectedChar or ns.CharKey(); panel:Show() end
end

SLASH_BONUSROLLLEDGER1 = "/brl"
SLASH_BONUSROLLLEDGER2 = "/bonusrolls"
SlashCmdList.BONUSROLLLEDGER = function(msg)
    if (msg or ""):lower():match("^%s*minimap") and ns.button then ns.button.Toggle() else ns.Toggle() end
end

local mm = CreateFrame("Frame")
mm:RegisterEvent("PLAYER_LOGIN")
mm:SetScript("OnEvent", function()
    BonusRollLedgerDB = BonusRollLedgerDB or {}
    BonusRollLedgerDB.minimap = BonusRollLedgerDB.minimap or {}
    ns.button = ns.MinimapButton{ name = "BonusRollLedger", icon = "Interface\\AddOns\\BonusRollLedger\\Media\\icon",
        db = BonusRollLedgerDB.minimap, slash = "brl", onClick = function() ns.Toggle() end,
        tooltip = function(tt)
            tt:SetText("Bonus Roll Ledger")
            tt:AddLine("Click to see which boss, difficulty and loot spec you've used bonus rolls on.", 1, 1, 1, true)
        end }
end)

function BonusRollLedger_OnCompartmentClick() ns.Toggle() end
function BonusRollLedger_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("Bonus Roll Ledger")
    GameTooltip:AddLine("Click to see which boss, difficulty and loot spec you've used bonus rolls on.", 1, 1, 1, true)
    GameTooltip:Show()
end
function BonusRollLedger_OnCompartmentLeave() GameTooltip:Hide() end

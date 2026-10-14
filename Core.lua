-- Bonus Roll Ledger: records every bonus roll per character (boss, difficulty,
-- loot spec, result) and shows them in one panel.
local ADDON, ns = ...

local BRL = CreateFrame("Frame")
ns.BRL = BRL

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function CharKey(name, realm)
    name = name or UnitName("player")
    realm = realm or GetRealmName()
    return name .. " - " .. realm
end
ns.CharKey = CharKey

-- Item creation contexts the bonus roll prompt reports.
local CONTEXT_NAMES = {
    [1] = "Dungeon", [2] = "Heroic Dungeon", [3] = "Normal", [4] = "LFR",
    [5] = "Heroic", [6] = "Mythic", [16] = "Mythic+", [23] = "Mythic Dungeon",
}
function ns.DifficultyText(roll)
    if roll.difficulty and roll.difficulty ~= "" then return roll.difficulty end
    local name = CONTEXT_NAMES[roll.context or 0]
    if name and roll.keyLevel and roll.keyLevel > 0 and roll.context == 16 then
        name = name .. " " .. roll.keyLevel
    end
    return name or "?"
end

-- "Nebulous Voidcache: The Coiled Altar" -> "The Coiled Altar"
local function BossFromCacheName(name)
    if not name then return nil end
    return name:match(":%s*(.+)$") or name
end

local function ItemName(itemID)
    if not itemID or itemID == 0 then return nil end
    if C_Item.GetItemNameByID then
        local name = C_Item.GetItemNameByID(itemID)
        if name then return name end
    end
    C_Item.RequestLoadItemDataByID(itemID)
    return nil
end

-- Boss name for a roll; fills it in later for imported rolls once the cache item loads.
function ns.BossText(roll)
    if roll.boss and roll.boss ~= "" then return roll.boss end
    local name = BossFromCacheName(ItemName(roll.source))
    if name then roll.boss = name; return name end
    if roll.encounter then return roll.encounter end
    if roll.source and roll.source ~= 0 then return "|cff888888Loading...|r" end
    return roll.instance or "Unknown boss"
end

-- Ask the game for every cache item we still need a boss name from.
local function PreloadBossNames()
    for _, char in pairs(BonusRollLedgerDB.chars) do
        for _, r in ipairs(char.rolls) do
            if not r.boss and r.source and r.source ~= 0 then ns.BossText(r) end
        end
    end
end

-- Spec name + icon for any spec ID (works for other classes too).
function ns.SpecInfo(specID)
    if not specID or specID == 0 then return "No spec", nil end
    local fn = GetSpecializationInfoByID
        or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID)
    if fn then
        local a, name, _, icon = fn(specID)
        if type(a) == "table" then return a.name or tostring(specID), a.icon end
        if name then return name, icon end
    end
    return "Spec " .. specID, nil
end

local function CurrentLootSpec(fallback)
    if fallback and fallback ~= 0 then return fallback end
    local spec = GetLootSpecialization and GetLootSpecialization()
    if spec and spec ~= 0 then return spec end
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    local index = getSpec and getSpec()
    if index and getInfo then
        local info = getInfo(index)
        if type(info) == "table" then return info.specID or 0 end
        return info or 0
    end
    return 0
end

-- ---------------------------------------------------------------------------
-- Saved data
-- ---------------------------------------------------------------------------

function ns.EnsureChar(key, classFile)
    local db = BonusRollLedgerDB
    db.chars[key] = db.chars[key] or { rolls = {} }
    if classFile then db.chars[key].class = classFile end
    return db.chars[key]
end

local function RollKey(roll)
    return (roll.ts or 0) .. ":" .. (roll.itemID or 0) .. ":" .. (roll.source or 0)
end

local function AddRoll(char, roll)
    char.seen = char.seen or {}
    local key = RollKey(roll)
    if char.seen[key] then return false end
    -- The same roll seen by both this addon and Simulationcraft can differ by a second or two.
    if roll.imported and roll.itemID then
        for _, r in ipairs(char.rolls) do
            if r.itemID == roll.itemID and math.abs((r.ts or 0) - (roll.ts or 0)) <= 10 then
                char.seen[key] = true
                return false
            end
        end
    end
    char.seen[key] = true
    table.insert(char.rolls, roll)
    return true
end

-- One-time (and on every login, deduplicated) copy of Simulationcraft's bonus roll log.
local function ImportSimulationcraft()
    local simc = _G.SimulationCraftDB
    if type(simc) ~= "table" or type(simc.char) ~= "table" then return 0 end
    local added = 0
    for key, data in pairs(simc.char) do
        if type(data) == "table" and type(data.bonusRolls) == "table" and #data.bonusRolls > 0 then
            local char = ns.EnsureChar(key)
            for _, r in ipairs(data.bonusRolls) do
                if type(r) == "table" and r.itemId then
                    local ok = AddRoll(char, {
                        ts = r.ts, itemID = r.itemId, spec = r.spec, source = r.source,
                        context = r.context, keyLevel = r.keyLevel, currency = r.currency,
                        kind = "item", imported = true,
                    })
                    if ok then added = added + 1 end
                end
            end
        end
    end
    return added
end

-- ---------------------------------------------------------------------------
-- Recording
-- ---------------------------------------------------------------------------

local pending       -- filled when the bonus roll prompt appears
local lastEncounter -- last boss killed, as a fallback name

function BRL:SPELL_CONFIRMATION_PROMPT(spellID)
    local prompts = GetSpellConfirmationPromptsInfo and GetSpellConfirmationPromptsInfo()
    if not prompts then return end
    for _, entry in ipairs(prompts) do
        if entry.spellID == spellID then
            local instanceName, _, _, difficultyName = GetInstanceInfo()
            pending = {
                currency = entry.currencyID,
                source = entry.displayItemID,
                context = entry.itemContext,
                keyLevel = entry.treasureContextLevel,
                difficulty = difficultyName,
                instance = instanceName,
                encounter = lastEncounter,
            }
            return
        end
    end
end

function BRL:ENCOUNTER_END(_, encounterName, _, _, success)
    if success == 1 then lastEncounter = encounterName end
end

function BRL:BONUS_ROLL_RESULT(typeIdentifier, itemLink, quantity, specID)
    local p = pending or {}
    pending = nil
    local roll = {
        ts = C_DateAndTime.GetServerTimeLocal(),
        kind = typeIdentifier,
        spec = CurrentLootSpec(specID),
        source = p.source or 0,
        context = p.context,
        keyLevel = p.keyLevel,
        currency = p.currency,
        difficulty = p.difficulty,
        instance = p.instance,
        encounter = p.encounter,
        quantity = quantity,
    }
    if type(itemLink) == "string" then
        roll.itemLink = itemLink
        roll.itemID = tonumber(itemLink:match("|Hitem:(%d+)"))
    end
    if roll.source and roll.source ~= 0 then ns.BossText(roll) end
    local _, classFile = UnitClass("player")
    AddRoll(ns.EnsureChar(CharKey(), classFile), roll)
    if ns.Refresh then ns.Refresh() end
end

function BRL:GET_ITEM_INFO_RECEIVED()
    if ns.RefreshSoon then ns.RefreshSoon() end
end
BRL.ITEM_DATA_LOAD_RESULT = BRL.GET_ITEM_INFO_RECEIVED

function BRL:PLAYER_LOGIN()
    BonusRollLedgerDB = BonusRollLedgerDB or {}
    BonusRollLedgerDB.chars = BonusRollLedgerDB.chars or {}
    local _, classFile = UnitClass("player")
    ns.EnsureChar(CharKey(), classFile)
    local added = ImportSimulationcraft()
    PreloadBossNames()
    if added > 0 then
        print(("|cff33ff99Bonus Roll Ledger|r: imported %d earlier roll(s) from Simulationcraft. Type /brl to open."):format(added))
    end
end

BRL:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
for _, e in ipairs({ "PLAYER_LOGIN", "SPELL_CONFIRMATION_PROMPT", "BONUS_ROLL_RESULT",
                     "ENCOUNTER_END", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT" }) do
    BRL:RegisterEvent(e)
end

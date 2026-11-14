-- WhyHidden.lua — shows which values the client is hiding from addons, and why.
--
-- The Midnight and Forever clients hand addons "secret values": health, identity,
-- casting and combat data become hidden during restricted content so addons cannot
-- act on them for the player. This addon cannot reveal any of that and does not try.
-- It reads the client's own predicate API (C_Secrets) and reports what is hidden
-- for whatever you point it at.

-- Every C_Secrets call is wrapped: the API is tagged AllowedWhenUntainted and the
-- Forever beta moves week to week, so a signature change must degrade to "unknown"
-- rather than throw. A nil return here always means "could not ask", never "visible".
local function isPublic(value)
    return not issecretvalue or not issecretvalue(value)
end

local function ask(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok and isPublic(result) and type(result) == "boolean" then return result end
    return nil
end

local function restrictionStatus()
    if C_Secrets then return ask(C_Secrets.HasSecretRestrictions) end
end

-- What can be hidden about a single unit. The label is what the player sees; keep
-- them plain enough to read in a tooltip at a glance.
local UNIT_CHECKS = {
    { label = "name",          fn = function(u) return C_Secrets.ShouldUnitIdentityBeSecret(u) end },
    { label = "max health",    fn = function(u) return C_Secrets.ShouldUnitHealthMaxBeSecret(u) end },
    { label = "power",         fn = function(u) return C_Secrets.ShouldUnitPowerBeSecret(u) end },
    { label = "power max",     fn = function(u) return C_Secrets.ShouldUnitPowerMaxBeSecret(u) end },
    { label = "stats",         fn = function() return C_Secrets.ShouldUnitStatsBeSecret() end },
    { label = "casting",       fn = function(u) return C_Secrets.ShouldUnitSpellCastingBeSecret(u) end },
}

local function threatHidden(mobUnit)
    return ask(C_Secrets.ShouldUnitThreatValuesBeSecret, "player", mobUnit)
end

-- The cast bar question mark is the most visible symptom of the whole system, so the
-- spell currently being cast or channelled gets its own answer when there is one.
-- UnitCastingInfo returns spellId 9th; UnitChannelInfo 8th (no castID in between).
local function currentSpell(unit, fn, spellIndex)
    local function read(...)
        local name = ...
        if not isPublic(name) then return nil end
        if name == nil then return false end
        local spellID = select(spellIndex, ...)
        if isPublic(spellID) and type(spellID) == "number" then return spellID end
    end
    -- Keep the full return tuple and inspect only public metadata. A secret name
    -- or spell ID means unknown, not permission to infer the hidden cast.
    local ok, spellID = pcall(function() return read(fn(unit)) end)
    if ok then return spellID end
    return nil
end

local function castHidden(unit)
    local spellID = currentSpell(unit, UnitCastingInfo, 9)
    if spellID == false then spellID = currentSpell(unit, UnitChannelInfo, 8) end
    if spellID == false then return false end
    if spellID == nil then return nil end
    return ask(C_Secrets.ShouldUnitSpellCastBeSecret, unit, spellID)
end

-- Location is context, not proof that a particular restriction is active.
local function contextLine()
    local _, instanceType = GetInstanceInfo()
    if instanceType == "arena" then
        return "In an arena: restrictions can hide values from addons."
    elseif instanceType == "pvp" then
        return "In a battleground: restrictions can hide values from addons."
    elseif instanceType == "raid" then
        return "In a raid: restrictions can hide values from addons."
    elseif instanceType == "party" then
        return "In a dungeon: restrictions can hide values from addons."
    end
    return nil
end

local function hiddenList(unit)
    local hidden, unknown = {}, 0
    local function record(label, result)
        if result == true then
            hidden[#hidden + 1] = label
        elseif result == nil then
            unknown = unknown + 1
        end
    end
    for _, check in ipairs(UNIT_CHECKS) do
        record(check.label, ask(check.fn, unit))
    end
    record("current cast", castHidden(unit))
    if UnitCanAttack("player", unit) then
        record("threat", threatHidden(unit))
    end
    return hidden, unknown
end

local ORANGE = "|cffff9a3c"
local GREY = "|cff888888"
local GREEN = "|cff3cc94a"

local function describeUnit(unit, prefix)
    if not UnitExists(unit) then return end
    local ok, name = pcall(UnitName, unit)
    if not ok or not isPublic(name) or type(name) ~= "string" then name = unit end
    local hidden, unknown = hiddenList(unit)
    local summary
    if #hidden == 0 and unknown == 0 then
        summary = GREEN .. "nothing hidden in checked values|r"
    elseif #hidden == 0 then
        summary = GREY .. "unknown (" .. unknown .. ")|r"
    else
        summary = ORANGE .. table.concat(hidden, ", ") .. "|r"
        if unknown > 0 then
            summary = summary .. GREY .. " (+" .. unknown .. " unknown)|r"
        end
    end
    print(prefix .. " " .. name .. ": " .. summary)
end

local function reportGlobal()
    local auras = ask(C_Secrets.ShouldAurasBeSecret)
    local cooldowns = ask(C_Secrets.ShouldCooldownsBeSecret)
    local function word(v)
        if v == true then return ORANGE .. "hidden"
        elseif v == false then return GREEN .. "visible"
        else return GREY .. "unknown" end
    end
    print("  Your auras: " .. word(auras) .. "|r   action cooldowns: " .. word(cooldowns) .. "|r")
end

local function report(unitArg)
    local restrictions = restrictionStatus()
    if restrictions ~= true then
        if restrictions == false then
            print("WhyHidden: this client is not hiding anything. (HasSecretRestrictions is false.)")
        else
            print("WhyHidden: restriction status unknown. The C_Secrets API is unavailable or could not be queried.")
        end
        return
    end
    print("WhyHidden: secret-value restrictions enabled.")
    local context = contextLine()
    if context then print(GREY .. "  " .. context .. "|r") end
    reportGlobal()
    describeUnit("player", "  You")
    local unit = unitArg == "mouse" and "mouseover" or "target"
    local alt = unit == "mouseover" and "target" or "mouseover"
    if not UnitExists(unit) then unit = alt end
    if not UnitExists(unit) then
        print(GREY .. "  Target or mouse over something, then /whh again.|r")
        return
    end
    describeUnit(unit, "  " .. (unit == "mouseover" and "Mouseover" or "Target"))
end

SLASH_WHYHIDDEN1 = "/whh"
SLASH_WHYHIDDEN2 = "/whyhidden"
SlashCmdList.WHYHIDDEN = function(msg)
    local arg = strlower(strtrim(msg or ""))
    if arg == "help" or arg == "?" then
        print("WhyHidden: /whh reports your target (or mouseover if no target).")
        print("  /whh mouse (or /whh m) prefers mouseover; /whyhidden is an alias.")
        print("  Hidden values stay hidden; unavailable queries are reported as unknown.")
        return
    end
    report((arg == "mouse" or arg == "m") and "mouse" or nil)
end

-- Tooltip: one quiet line, only when something is actually hidden for that unit.
-- Tooltips that say nothing new are noise; this stays silent on visible values.
local function annotateTooltip(self)
    if self ~= GameTooltip then return end
    if restrictionStatus() ~= true then return end
    local ok, _, unit = pcall(self.GetUnit, self)
    if not ok or not isPublic(unit) or type(unit) ~= "string" or not UnitExists(unit) then return end
    local hidden, unknown = hiddenList(unit)
    if #hidden > 0 then
        local summary = "Hidden: " .. table.concat(hidden, ", ")
        if unknown > 0 then summary = summary .. " (+" .. unknown .. " unknown)" end
        self:AddLine(summary, 1, 0.6, 0.24, true)
        local _, instanceType = GetInstanceInfo()
        local where = instanceType == "arena" and " · arena"
            or instanceType == "pvp" and " · battleground"
            or instanceType == "raid" and " · raid"
            or instanceType == "party" and " · dungeon"
            or ""
        self:AddLine("WhyHidden" .. where, 0.53, 0.53, 0.53)
    end
end

-- Modern clients removed OnTooltipSetUnit. Register only one path so clients
-- exposing both APIs do not get duplicate annotations.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, annotateTooltip)
elseif GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetUnit") then
    GameTooltip:HookScript("OnTooltipSetUnit", annotateTooltip)
end

-- A client without C_Secrets (Classic flavours) never reaches any of the above in a
-- meaningful way, and the hooks are cheap no-ops when restrictions are off.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    if C_Secrets == nil then return end
    if restrictionStatus() == true then
        print("WhyHidden: secret-value restrictions enabled. " .. GREY .. "/whh|r to ask what is hidden.")
    end
end)

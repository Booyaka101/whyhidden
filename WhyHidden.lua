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
local function ask(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function restrictionsActive()
    return C_Secrets ~= nil and ask(C_Secrets.HasSecretRestrictions) == true
end

-- What can be hidden about a single unit. The label is what the player sees; keep
-- them plain enough to read in a tooltip at a glance.
local UNIT_CHECKS = {
    { label = "name",          fn = function(u) return C_Secrets.ShouldUnitIdentityBeSecret(u) end },
    { label = "health",        fn = function(u) return C_Secrets.ShouldUnitHealthMaxBeSecret(u) end },
    { label = "power",         fn = function(u) return C_Secrets.ShouldUnitPowerBeSecret(u, UnitPowerType(u)) end },
    { label = "power max",     fn = function(u) return C_Secrets.ShouldUnitPowerMaxBeSecret(u, UnitPowerType(u)) end },
    { label = "stats",         fn = function(u) return C_Secrets.ShouldUnitStatsBeSecret(u) end },
    { label = "casting",       fn = function(u) return C_Secrets.ShouldUnitSpellCastingBeSecret(u) end },
}

local function threatHidden(mobUnit)
    return ask(C_Secrets.ShouldUnitThreatValuesBeSecret, "player", mobUnit)
end

-- The cast bar question mark is the most visible symptom of the whole system, so the
-- spell currently being cast gets its own answer when there is one.
local function castHidden(unit)
    local spellId = select(9, UnitCastingInfo(unit))
    if not spellId then return false end
    return ask(C_Secrets.ShouldUnitSpellCastBeSecret, unit, spellId)
end

-- The C_Secrets predicates only answer yes or no; the reason is inferred from where
-- you are. That is honest as long as the wording stays a context, not a claimed cause.
local function contextLine()
    local _, instanceType = GetInstanceInfo()
    if instanceType == "arena" then
        return "In an arena: values are hidden so addons cannot decide for you."
    elseif instanceType == "pvp" then
        return "In a battleground: values are hidden so addons cannot decide for you."
    elseif instanceType == "raid" then
        return "In a raid encounter: values are hidden so addons cannot decide for you."
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
    local name = UnitName(unit)
    local hidden, unknown = hiddenList(unit)
    local summary
    if #hidden == 0 and unknown == 0 then
        summary = GREEN .. "nothing hidden|r"
    elseif #hidden == 0 then
        summary = GREY .. "unknown (" .. unknown .. ")|r"
    else
        summary = ORANGE .. table.concat(hidden, ", ") .. "|r"
        if unknown > 0 then
            summary = summary .. GREY .. " (+" .. unknown .. " unknown)|r"
        end
    end
    print(prefix .. " " .. (name or unit) .. ": " .. summary)
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
    if not restrictionsActive() then
        print("WhyHidden: this client is not hiding anything. (HasSecretRestrictions is false.)")
        return
    end
    print("WhyHidden: restrictions active.")
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
    report((arg == "mouse" or arg == "m") and "mouse" or nil)
end

-- Tooltip: one quiet line, only when something is actually hidden for that unit.
-- Tooltips that say nothing new are noise; this stays silent on visible values.
GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    if not restrictionsActive() then return end
    local ok, _, unit = pcall(self.GetUnit, self)
    if not ok or not unit then return end
    local hidden = hiddenList(unit)
    if #hidden > 0 then
        self:AddLine("Hidden: " .. table.concat(hidden, ", "), 1, 0.6, 0.24, true)
        local _, instanceType = GetInstanceInfo()
        local where = instanceType == "arena" and " · arena"
            or instanceType == "pvp" and " · battleground"
            or instanceType == "raid" and " · raid"
            or ""
        self:AddLine("WhyHidden" .. where, 0.53, 0.53, 0.53)
    end
end)

-- A client without C_Secrets (Classic flavours) never reaches any of the above in a
-- meaningful way, and the hooks are cheap no-ops when restrictions are off.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    if C_Secrets == nil then return end
    if ask(C_Secrets.HasSecretRestrictions) then
        print("WhyHidden: secret restrictions are active. " .. GREY .. "/whh|r to ask what is hidden.")
    end
end)

-- WhyHidden.lua — shows which values the client is hiding from addons, and why.
--
-- The Midnight and Forever clients hand addons "secret values": health, identity,
-- casting and combat data become hidden during restricted content so addons cannot
-- act on them for the player. This addon cannot reveal any of that and does not try.
-- It reads the client's own predicate API (C_Secrets) and reports what is hidden
-- for whatever you point it at.

local ADDON_NAME = ...

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
    { label = "stats",         fn = function(u) return C_Secrets.ShouldUnitStatsBeSecret(u) end },
    { label = "casting",       fn = function(u) return C_Secrets.ShouldUnitSpellCastingBeSecret(u) end },
}

local function threatHidden(mobUnit)
    return ask(C_Secrets.ShouldUnitThreatValuesBeSecret, "player", mobUnit)
end

-- The C_Secrets predicates only answer yes or no; the reason is inferred from where
-- you are. That is honest as long as the wording stays a context, not a claimed cause.
local function contextLine()
    local _, instanceType, difficultyID = GetInstanceInfo()
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
    for _, check in ipairs(UNIT_CHECKS) do
        local result = ask(check.fn, unit)
        if result == true then
            hidden[#hidden + 1] = check.label
        elseif result == nil then
            unknown = unknown + 1
        end
    end
    if UnitCanAttack("player", unit) then
        local result = threatHidden(unit)
        if result == true then
            hidden[#hidden + 1] = "threat"
        elseif result == nil then
            unknown = unknown + 1
        end
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
        summary = GREEN .. "nothing hidden"
    elseif #hidden == 0 then
        summary = GREY .. "unknown (" .. unknown .. ")"
    else
        summary = ORANGE .. table.concat(hidden, ", ")
        if unknown > 0 then
            summary = summary .. GREY .. " (+" .. unknown .. " unknown)"
        end
    end
    print(prefix .. " " .. (name or unit) .. ":|r " .. summary)
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
    describeUnit(unit, "  " .. (unitArg == "mouse" and "Mouseover" or "Target"))
end

SLASH_WHYHIDDEN1 = "/whh"
SLASH_WHYHIDDEN2 = "/whyhidden"
SlashCmdList.WHYHIDDEN = function(msg)
    local arg = strlower(strtrim(msg or ""))
    report(arg == "mouse" and "mouse" or nil)
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
        self:AddLine("WhyHidden", 0.53, 0.53, 0.53)
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

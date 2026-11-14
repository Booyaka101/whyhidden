-- WoW client stubs: enough surface to execute WhyHidden end to end.
local OUT = {}
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    OUT[#OUT + 1] = table.concat(parts, " ")
end

strlower = string.lower
strtrim = function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end

UNITS = {
    player    = { name = "Testself", exists = true, hostile = false, casting = 12345 },
    target    = { name = "Bogbeast", exists = true, hostile = true,  casting = nil },
    mouseover = nil, -- toggled per test
}
UnitExists = function(u) return UNITS[u] ~= nil and UNITS[u].exists == true end
UnitName = function(u) return UNITS[u] ~= nil and UNITS[u].name or nil end
UnitPowerType = function() return 0 end
UnitCanAttack = function(_, b) return UNITS[b] ~= nil and UNITS[b].hostile == true end
UnitCastingInfo = function(u)
    local c = UNITS[u] ~= nil and UNITS[u].casting or nil
    if c then return "Fireball", "Fireball", nil, 0, 1, false, nil, true, c end
    return nil
end
UnitChannelInfo = function(u)
    local c = UNITS[u] ~= nil and UNITS[u].channel or nil
    if c then return "Drain Life", "Drain Life", nil, 0, 1, false, true, c end
    return nil
end

INSTANCE_TYPE = "arena"
GetInstanceInfo = function() return "Nagrand Arena", INSTANCE_TYPE end

-- SECRETS.mode: "all" everything hidden; "none" nothing hidden; "break" one API throws
SECRETS = { mode = "all" }
local function pred()
    if SECRETS.mode == "all" then return true end
    if SECRETS.mode == "none" then return false end
    return true
end
C_Secrets = {
    HasSecretRestrictions = function() return true end,
    ShouldUnitIdentityBeSecret = function() return pred() end,
    ShouldUnitHealthMaxBeSecret = function() return pred() end,
    ShouldUnitPowerBeSecret = function() return pred() end,
    ShouldUnitPowerMaxBeSecret = function() return pred() end,
    ShouldUnitStatsBeSecret = function()
        if SECRETS.mode == "break" then error("signature changed in build 70300") end
        return pred()
    end,
    ShouldUnitSpellCastingBeSecret = function() return pred() end,
    ShouldUnitSpellCastBeSecret = function(_, _) return pred() end,
    ShouldUnitThreatValuesBeSecret = function(_, _) return pred() end,
    ShouldAurasBeSecret = function() return pred() end,
    ShouldCooldownsBeSecret = function()
        if SECRETS.breakCooldowns then error("signature changed in build 70300") end
        return pred()
    end,
}

TOOLTIP_LINES = {}
GameTooltip = {
    AddLine = function(_, text) TOOLTIP_LINES[#TOOLTIP_LINES + 1] = tostring(text) end,
}
local HOOKS = {}
local legacyTooltip = TOOLTIP_MODE == "legacy" or TOOLTIP_MODE == "both"
GameTooltip.HookScript = function(_, name, fn)
    assert(legacyTooltip and name == "OnTooltipSetUnit", "unsupported tooltip script: " .. name)
    assert(not HOOKS[name], "duplicate legacy tooltip registration")
    HOOKS[name] = fn
end
GameTooltip.HasScript = function(_, name) return legacyTooltip and name == "OnTooltipSetUnit" end
if TOOLTIP_MODE == "no-hasscript" then GameTooltip.HasScript = nil end
local POST_CALL
if TOOLTIP_MODE == "modern" or TOOLTIP_MODE == "both" or TOOLTIP_MODE == "no-enum" or TOOLTIP_MODE == "no-postcall" then
    Enum = { TooltipDataType = { Unit = 2 } }
    TooltipDataProcessor = {
        AddTooltipPostCall = function(dataType, fn)
            assert(dataType == Enum.TooltipDataType.Unit, "wrong tooltip data type")
            assert(not POST_CALL, "duplicate modern tooltip registration")
            POST_CALL = fn
        end,
    }
    if TOOLTIP_MODE == "no-enum" then Enum = nil end
    if TOOLTIP_MODE == "no-postcall" then TooltipDataProcessor.AddTooltipPostCall = nil end
end
CURRENT_UNIT = nil
GameTooltip.GetUnit = function() return UNITS[CURRENT_UNIT] and UNITS[CURRENT_UNIT].name, CURRENT_UNIT end

local EVENT_SCRIPTS = {}
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        UnregisterEvent = function() end,
        SetScript = function(_, event, fn) EVENT_SCRIPTS[event] = fn end,
    }
end

SlashCmdList = {}

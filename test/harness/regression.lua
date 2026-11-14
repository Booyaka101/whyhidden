-- Review regressions: strict API arguments and conservative handling of secrets.
local function outputContains(text)
    return table.concat(OUT, "\n"):find(text, 1, true) ~= nil
end

local function runReport(arg)
    OUT = {}
    SlashCmdList.WHYHIDDEN(arg or "")
end

-- Cast takes precedence, and does not query channel information unnecessarily.
local savedTarget = UNITS.target
local savedCasting, savedChannel = UnitCastingInfo, UnitChannelInfo
UNITS.target = { name = "Caster", exists = true, hostile = true, casting = 321, channel = 654 }
UnitChannelInfo = function() error("channel queried while already casting") end
runReport()
expect(outputContains("Target Caster:") and outputContains("current cast"), "cast precedence lost")
expect(not outputContains("unknown"), "valid cast or predicate arguments degraded to unknown")
UnitChannelInfo = savedChannel

-- Name reads may return a secret, nil, or an error. Never stringify secrets.
local savedName = UnitName
for _, readName in ipairs({
    function() return SECRET_VALUE end,
    function() return nil end,
    function() error("name unavailable") end,
}) do
    UnitName = readName
    runReport()
    expect(outputContains("Target target:"), "unreadable name did not fall back to unit token")
end
UnitName = savedName

-- Hidden cast metadata is not inspected or forwarded to predicate APIs.
SECRETS.mode = "none"
for _, readCast in ipairs({
    function() return SECRET_VALUE end,
    function() return "Cast", nil, nil, nil, nil, nil, nil, nil, SECRET_VALUE end,
    function() return "Cast" end,
    function() error("cast API unavailable") end,
}) do
    UnitCastingInfo = readCast
    runReport()
    expect(outputContains("Target Caster: |cff888888unknown (1)"), "unreadable cast must be unknown")
end
UnitCastingInfo = function() return nil end
UnitChannelInfo = function() return "Channel", nil, nil, nil, nil, nil, nil, SECRET_VALUE end
runReport()
expect(outputContains("Target Caster: |cff888888unknown (1)"), "unreadable channel must be unknown")
UnitCastingInfo, UnitChannelInfo = savedCasting, savedChannel
UNITS.target = savedTarget

-- Missing and non-boolean predicates are unknown, never implicitly visible.
local savedStats = C_Secrets.ShouldUnitStatsBeSecret
for _, predicate in ipairs({
    function() return SECRET_VALUE end,
    function() return "true" end,
    function() return nil end,
}) do
    C_Secrets.ShouldUnitStatsBeSecret = predicate
    runReport()
    expect(outputContains("unknown (1)"), "invalid predicate result was not counted as unknown")
end
C_Secrets.ShouldUnitStatsBeSecret = nil
runReport()
expect(outputContains("unknown (1)"), "missing predicate was not counted as unknown")
C_Secrets.ShouldUnitStatsBeSecret = savedStats

-- Build support is tri-state. Missing/failed queries must not claim visibility.
local savedRestrictions = C_Secrets.HasSecretRestrictions
for _, predicate in ipairs({
    function() error("restriction API unavailable") end,
    function() return nil end,
    function() return "true" end,
    function() return SECRET_VALUE end,
}) do
    C_Secrets.HasSecretRestrictions = predicate
    runReport()
    expect(#OUT == 1 and outputContains("restriction status unknown"), "restriction failure reported as visible")
    OUT = {}
    EVENT_SCRIPTS.OnEvent(dummyFrame, "PLAYER_LOGIN")
    expect(#OUT == 0, "unknown restriction status produced login banner")
    if tooltipCallback then
        TOOLTIP_LINES = {}
        tooltipCallback(GameTooltip)
        expect(#TOOLTIP_LINES == 0, "unknown restriction status annotated tooltip")
    end
end
C_Secrets.HasSecretRestrictions = nil
runReport()
expect(outputContains("restriction status unknown"), "missing restriction function reported as visible")
C_Secrets.HasSecretRestrictions = savedRestrictions
local savedSecrets = C_Secrets
C_Secrets = nil
runReport()
expect(outputContains("restriction status unknown"), "missing C_Secrets reported as visible")
SlashCmdList.WHYHIDDEN("help")
expect(outputContains("/whh mouse"), "help unavailable without C_Secrets")
C_Secrets = savedSecrets

-- Help and whitespace/case normalization work without changing report defaults.
runReport("  HeLP  ")
expect(#OUT == 3 and outputContains("/whh mouse"), "help command not normalized")
runReport("?")
expect(#OUT == 3 and outputContains("/whyhidden"), "help shorthand missing")
runReport("  MoUsE  ")
expect(outputContains("Mouseover Lurker:"), "mouse command not normalized")

-- Context is location, not proof of an active encounter.
for _, context in ipairs({
    { "arena", "In an arena:" }, { "pvp", "In a battleground:" },
    { "raid", "In a raid:" }, { "party", "In a dungeon:" },
}) do
    INSTANCE_TYPE = context[1]
    runReport()
    expect(outputContains(context[2]), "missing context for " .. context[1])
end
INSTANCE_TYPE = "none"
runReport()
expect(not outputContains("In a"), "open world received instance context")
INSTANCE_TYPE = "arena"

-- Older clients may have no issecretvalue helper, but public values still work.
local savedIsSecret = issecretvalue
issecretvalue = nil
runReport()
expect(outputContains("nothing hidden"), "public values failed without issecretvalue")
issecretvalue = savedIsSecret

if tooltipCallback then
    CURRENT_UNIT = "target"
    local savedGetUnit = GameTooltip.GetUnit
    for _, getUnit in ipairs({
        function() error("tooltip unit unavailable") end,
        function() return "Name", SECRET_VALUE end,
        function() return "Name", "missingunit" end,
    }) do
        GameTooltip.GetUnit = getUnit
        TOOLTIP_LINES = {}
        tooltipCallback(GameTooltip)
        expect(#TOOLTIP_LINES == 0, "invalid tooltip unit was annotated")
    end
    GameTooltip.GetUnit = savedGetUnit
    SECRETS.mode = "break"
    TOOLTIP_LINES = {}
    tooltipCallback(GameTooltip)
    expect(TOOLTIP_LINES[1]:find("(+1 unknown)", 1, true), "partial tooltip query failure not disclosed")
end

io.write("ALL CHECKS PASSED (" .. TOOLTIP_MODE .. ", " .. assertions .. " assertions)\n")

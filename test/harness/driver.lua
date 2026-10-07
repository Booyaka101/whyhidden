-- Driver: fires the real addon through its real paths and asserts on behaviour.

local function expect(cond, msg)
    if not cond then error("ASSERT FAILED: " .. msg, 0) end
end

local function lastOut(n) return OUT[#OUT - (n or 0)] end

-- 1. PLAYER_LOGIN with restrictions on
local dummyFrame = CreateFrame()
EVENT_SCRIPTS["OnEvent"](dummyFrame, "PLAYER_LOGIN")
expect(OUT[1] and OUT[1]:find("secret restrictions are active", 1, true), "login banner missing: " .. tostring(OUT[1]))
expect(OUT[1]:find("/whh", 1, true), "login banner lacks /whh hint")

-- 2. Tooltip on fully-hidden enemy target
SECRETS.mode = "all"
CURRENT_UNIT = "target"
TOOLTIP_LINES = {}
HOOKS["OnTooltipSetUnit"](GameTooltip)
expect(#TOOLTIP_LINES == 2, "expected 2 tooltip lines, got " .. #TOOLTIP_LINES)
expect(TOOLTIP_LINES[1]:find("name", 1, true), "identity not listed: " .. TOOLTIP_LINES[1])
expect(TOOLTIP_LINES[1]:find("health", 1, true), "health not listed")
expect(TOOLTIP_LINES[1]:find("power max", 1, true), "power max not listed")
expect(TOOLTIP_LINES[1]:find("threat", 1, true), "threat not listed for hostile")
expect(TOOLTIP_LINES[2]:find("WhyHidden · arena", 1, true), "context tag missing: " .. TOOLTIP_LINES[2])

-- 3. Tooltip on a visible unit stays silent
SECRETS.mode = "none"
TOOLTIP_LINES = {}
HOOKS["OnTooltipSetUnit"](GameTooltip)
expect(#TOOLTIP_LINES == 0, "tooltip noisy on visible unit: " .. table.concat(TOOLTIP_LINES, " / "))

-- 4. Signature drift degrades to unknown, never errors
SECRETS.mode = "break"
TOOLTIP_LINES = {}
local ok = pcall(HOOKS["OnTooltipSetUnit"], GameTooltip)
expect(ok, "tooltip hook threw under signature drift")
expect(#TOOLTIP_LINES == 2, "tooltip missing under drift: " .. #TOOLTIP_LINES)

-- 5. /whh full report with target
SECRETS.mode = "all"
OUT = {}
SlashCmdList.WHYHIDDEN("")
expect(#OUT >= 4, "report too short: " .. #OUT)
expect(OUT[1]:find("restrictions active", 1, true), "report header missing")
expect(OUT[2]:find("arena", 1, true), "context line missing")
expect(OUT[3]:find("auras", 1, true) and OUT[3]:find("hidden", 1, true), "globals line missing")
local youLine, targetLine
for _, l in ipairs(OUT) do
    if l:find("You Testself", 1, true) then youLine = l end
    if l:find("Target Bogbeast", 1, true) then targetLine = l end
end
expect(youLine, "player line missing")
expect(youLine:find("current cast", 1, true), "player's own cast not reported")
expect(targetLine, "target line missing")
expect(not targetLine:find("current cast", 1, true), "target not casting, cast should not be listed")

-- 6. /whh m falls back to target when no mouseover
UNITS.mouseover = nil
OUT = {}
SlashCmdList.WHYHIDDEN("m")
local sawTarget = false
for _, l in ipairs(OUT) do if l:find("Target Bogbeast", 1, true) then sawTarget = true end end
expect(sawTarget, "/whh m did not fall back to target")

-- 7. nothing targeted at all -> the hint
UNITS.target = nil
UNITS.mouseover = nil
OUT = {}
SlashCmdList.WHYHIDDEN("")
local hinted = false
for _, l in ipairs(OUT) do if l:find("then /whh again", 1, true) then hinted = true end end
expect(hinted, "no-target hint missing")
UNITS.target = { name = "Bogbeast", exists = true, hostile = true, casting = nil }

-- 8. every printed line with an open color code closes it
SECRETS.mode = "all"
OUT = {}
UNITS.mouseover = { name = "Lurker", exists = true, hostile = true, casting = 999 }
SlashCmdList.WHYHIDDEN("m")
for _, l in ipairs(OUT) do
    local opens = select(2, l:gsub("|cff", ""))
    local closes = select(2, l:gsub("|r", ""))
    expect(opens == closes, "unbalanced colors: opens=" .. opens .. " closes=" .. closes .. " line=" .. l)
end

-- 9. a unit that is channelling reports "current cast" through the channel path
UNITS.target = { name = "Warlocky", exists = true, hostile = true, channel = 777 }
SECRETS.mode = "all"
OUT = {}
SlashCmdList.WHYHIDDEN("")
local channeled = false
for _, l in ipairs(OUT) do
    if l:find("Target Warlocky", 1, true) and l:find("current cast", 1, true) then channeled = true end
end
expect(channeled, "channelled spell not reported as current cast")

-- 10. restrictions off: the report says so and describes nothing
SECRETS.mode = "none"
SECRETS.restrictions = false
C_Secrets.HasSecretRestrictions = function() return false end
OUT = {}
SlashCmdList.WHYHIDDEN("")
expect(#OUT == 1 and OUT[1]:find("not hiding anything", 1, true), "restrictions-off report wrong: " .. table.concat(OUT, " / "))
C_Secrets.HasSecretRestrictions = function() return true end
SECRETS.mode = "all"

-- 11. a client with no C_Secrets at all: login prints nothing, nothing throws
local savedSecrets = C_Secrets
C_Secrets = nil
OUT = {}
local okNil = pcall(function() EVENT_SCRIPTS["OnEvent"](dummyFrame, "PLAYER_LOGIN") end)
expect(okNil, "login threw with C_Secrets missing")
expect(#OUT == 0, "login printed with C_Secrets missing")
C_Secrets = savedSecrets

-- 12. drifted global predicate renders as unknown, not as visible
SECRETS.breakCooldowns = true
OUT = {}
SlashCmdList.WHYHIDDEN("")
local sawUnknown = false
for _, l in ipairs(OUT) do
    if l:find("action cooldowns", 1, true) and l:find("unknown", 1, true) then sawUnknown = true end
end
expect(sawUnknown, "drifted cooldown predicate not shown as unknown")
SECRETS.breakCooldowns = false

-- 13. garbage slash argument behaves like the plain report
OUT = {}
SlashCmdList.WHYHIDDEN("banana")
expect(#OUT >= 3, "garbage arg broke the report: " .. #OUT .. " lines")

io.write("ALL CHECKS PASSED (" .. #OUT .. " lines in final report)\n")
io.write(table.concat(OUT, "\n") .. "\n")

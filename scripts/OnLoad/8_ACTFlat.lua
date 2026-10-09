-- ACT view shares the original Ess runtime; Ess still owns focus and actions.
local Ess = _G.Ess
if not (Ess and Ess.UI and Ess.UI._rtcall) then return end
local G = { menu = nil, helpPanel = nil, shown = false, sent = {} }
_G.ACTFlat = G
local function call(name, args) Ess.UI._rtcall(name, args or {}) end
local function changed(key, value)
    if G.sent[key] == value then return false end
    G.sent[key] = value
    return true
end
local function labelOf(node)
    local label = node and node.label or ""
    if type(label) == "function" then
        local ok, value = pcall(label)
        label = ok and value or ""
    end
    return tostring(label or "")
end
local function rowParts(item)
    if not item then return "", "" end
    local label = tostring(item.label or item.header or "")
    if item._node and item._node.children then return label:gsub("%s+>%s*$", ""), ">" end
    local name, value = label:match("^(.-)%s*<%s*(.-)%s*>%s*$")
    if name and value then return name, "< " .. value .. " >" end
    name, value = label:match("^(.-):%s*(%a+)$")
    if name and (value == "ON" or value == "OFF") then return name, value end
    return label, ""
end
-- Scroll actual text windows in Lua: Scaleform's maxhscroll is not reliable
-- for these dynamic fields. Preserve UTF-8 characters and keep rows stationary.
local function scrollText(key, text, width, size)
    G.scroll = G.scroll or {}
    local state = G.scroll[key]
    if not state or state.text ~= text then
        state = {text=text, start=G.clock or 0, chars={}, widths={}}
        local total = 0
        for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            local factor = char:match("[ilI%.,:!|' ]") and 0.35
                or char:match("[MWmw@%%]") and 0.95 or 0.67
            state.chars[#state.chars+1] = char
            state.widths[#state.widths+1] = size * factor
            total = total + size * factor
        end
        local tail = #state.chars
        local used = state.widths[tail] or 0
        while tail > 1 and used + state.widths[tail-1] <= width do
            tail = tail - 1; used = used + state.widths[tail]
        end
        state.limit = total <= width and 0 or tail - 1
        G.scroll[key] = state
    end
    if state.limit == 0 then return text end
    local travel = state.limit * 0.20
    -- Reveal long text once, then settle back at its beginning.
    local phase = math.min((G.clock or 0) - state.start, travel * 2 + 3)
    local offset = 0
    if phase >= 1.5 and phase < 1.5 + travel then
        offset = math.floor((phase - 1.5) / 0.20)
    elseif phase >= 1.5 + travel and phase < 3 + travel then
        offset = state.limit
    elseif phase >= travel * 2 + 3 then
        offset = 0
    elseif phase >= 3 + travel then
        offset = state.limit - math.floor((phase - 3 - travel) / 0.20)
    end
    local parts, used = {}, 0
    for i=offset+1,#state.chars do
        if used + state.widths[i] > width then break end
        parts[#parts+1] = state.chars[i]; used = used + state.widths[i]
    end
    return table.concat(parts)
end
function G.refresh(menu, animationOnly)
    menu = menu or G.menu
    if not (G.shown and menu and menu:isOpen()) then return end
    local list = menu._rt.list
    if not list then return end
    local state = Ess.State("ACT")
    local t = state.paletteColors or Ess.UI.Theme
    local palette = {t.panelFill, t.rowFill, t.panelBorder, t.textPrimary, t.textDim, t.rowSelected, t.rowSelectedText}
    local stamp = table.concat(palette, ":")
    if changed("palette", stamp) then call("ACTPalette", palette) end
    local root = #menu._stack == 1
    if changed("mode", root) then call("ACTMode", { root }) end
    if root then
        local selected = list._sel - 1
        if changed("selected", selected) then call("ACTSelected", { selected }) end
    else
        local title = scrollText("title", labelOf(menu._stack[#menu._stack]), 252, 14)
        if changed("title", title) then call("ACTSubTitle", { title }) end
        local off = list._off or 0
        for i = 0, 9 do
            local item = list._items[off + i + 1]
            local name, value = rowParts(item)
            if item then
                name = scrollText("name" .. i, name, 180, 12)
                value = scrollText("value" .. i, value, 60, 11)
            else
                -- The native Lua -> Flash callback may drop empty strings.
                -- A space is still a real argument, so stale labels are cleared.
                name, value = " ", " "
            end
            local selected = item and list._sel == off + i + 1 or false
            if changed("row" .. i, name .. "\0" .. value .. "\0" .. tostring(selected)) then
                call("ACTSubSet", { i, name, value, selected })
            end
        end
    end
    -- Hide rendering only. _shown remains true so native focus and input keep working.
    if not animationOnly then
        if list._rtid then call("Show", { list._rtid, false }) end
        if G.helpPanel then G.helpPanel:show() end
    end
end
function G.open(menu, helpPanel)
    G.menu, G.helpPanel, G.shown, G.sent = menu, helpPanel, true, {}
    G.clock, G.scroll = 0, {}
    call("ACTLayout", { Ess.UI.SCALE or 100 })
    G.refresh(menu)
    call("ACTVisible", { true })
    call("ACTProbe")
    Ess.Loop.start("ACTFlat.marquee", 0.10, function()
        if not (G.shown and G.menu and G.menu:isOpen()) then return false end
        G.clock = G.clock + 0.10
        G.refresh(nil, true)
        return true
    end)
    return true
end
function G.close()
    if G.shown then call("ACTVisible", { false }) end
    G.shown = false
    Ess.Loop.stop("ACTFlat.marquee")
end

local KEYVAL = "f4"

local Ess = _G.Ess
if not (Ess and Ess.UI and Ess.UI.Menu and Ess.UI.Panel and Ess.UI.Theme and Ess.State
        and Ess.Player and Ess.Object and Ess.Human) then
    if Loader and Loader.Printf then
        Loader.Printf("[ACT] Ess 0.6.1 non caricato")
    end
    return
end

-- F4 (anche L2+L3 tramite companion) e sempre l'uscita di sicurezza.
if _G.ACTCamera and ACTCamera.active then ACTCamera.stop(); return end

local State = Ess.State("ACT", { invincible = false, infiniteAmmo = false })
local Lang = _G.ACTLang or { current = "it", t = function(value) return tostring(value or "") end }
local Theme = Ess.UI.Theme
local Keys = Ess.UI.KEYS
local paletteSave = Ess.SaveVar and Ess.SaveVar.ns("ACTPalette")
local palettes = {
    { name = "Rosa", colors = { accent = 0xC86A9C, accentText = 0x1B1320,
        panelFill = 0x1A1422, panelBorder = 0x68445F, rowFill = 0x261D2D,
        rowFillAlt = 0x2D2235, rowHover = 0x463049, rowSelected = 0xE6A6C5,
        rowSelectedText = 0x241526, textPrimary = 0xF3EAF2, textDim = 0xB9A9BC,
        textAccent = 0xF0BDD5, textHeader = 0xE6A6C5 } },
    { name = "Blu", colors = { accent = 0x4A9FE2, accentText = 0x091A2A,
        panelFill = 0x101D2D, panelBorder = 0x336184, rowFill = 0x192B40,
        rowFillAlt = 0x20354C, rowHover = 0x2B4F70, rowSelected = 0x8BC8F2,
        rowSelectedText = 0x10253A, textPrimary = 0xEAF4FC, textDim = 0xA3BDD1,
        textAccent = 0xA9DAF8, textHeader = 0x8BC8F2 } },
    { name = "Rosso", colors = { accent = 0xD8666C, accentText = 0x2B1015,
        panelFill = 0x241719, panelBorder = 0x804448, rowFill = 0x321F22,
        rowFillAlt = 0x3B2529, rowHover = 0x61383D, rowSelected = 0xF0A1A2,
        rowSelectedText = 0x301619, textPrimary = 0xF9ECEB, textDim = 0xC9AAAA,
        textAccent = 0xF3B7B7, textHeader = 0xF0A1A2 } },
    { name = "Grigio", colors = { accent = 0xA0A9B4, accentText = 0x171B20,
        panelFill = 0x1C2025, panelBorder = 0x545C66, rowFill = 0x272D33,
        rowFillAlt = 0x2E353D, rowHover = 0x46515C, rowSelected = 0xCDD3DA,
        rowSelectedText = 0x20262B, textPrimary = 0xF0F2F4, textDim = 0xABB2BA,
        textAccent = 0xD2D8DE, textHeader = 0xCDD3DA } },
    { name = "Viola", colors = { accent = 0x9B7BD6, accentText = 0x20162F,
        panelFill = 0x1A1627, panelBorder = 0x5B497C, rowFill = 0x272035,
        rowFillAlt = 0x30273F, rowHover = 0x493B61, rowSelected = 0xCAB3EF,
        rowSelectedText = 0x241A35, textPrimary = 0xF2EEF8, textDim = 0xB5A9C8,
        textAccent = 0xD5C3F2, textHeader = 0xCAB3EF } },
    { name = "Verde", colors = { accent = 0x68B78B, accentText = 0x10281D,
        panelFill = 0x13231D, panelBorder = 0x3D6B54, rowFill = 0x1D3027,
        rowFillAlt = 0x243B30, rowHover = 0x355B46, rowSelected = 0xA4D9B9,
        rowSelectedText = 0x142B20, textPrimary = 0xEDF6F0, textDim = 0xA5BFB0,
        textAccent = 0xB6E3C7, textHeader = 0xA4D9B9 } },
}
local paletteIndex = 1
local savedName = State.paletteName or (paletteSave and paletteSave:get("name", "Rosa")) or "Rosa"
local savedIndex = paletteSave and tonumber(paletteSave:get("index", 0)) or 0
if not State.paletteName and savedIndex and savedIndex >= 1 and savedIndex <= #palettes then
    paletteIndex = savedIndex
else
    for i, palette in ipairs(palettes) do if palette.name == savedName then paletteIndex = i; break end end
end
State.paletteName = palettes[paletteIndex].name
local function persistPalette()
    if paletteSave then
        paletteSave:set("name", palettes[paletteIndex].name)
        paletteSave:set("index", paletteIndex)
    end
end
local function applyPalette()
    local colors = palettes[paletteIndex].colors
    -- Store ACT's palette independently of the temporary global Ess theme.
    State.paletteColors = colors
    for name, value in pairs(colors) do Theme[name] = value end
    Theme.apply()
end
local function changePalette(direction)
    paletteIndex = (paletteIndex - 1 + direction) % #palettes + 1
    State.paletteName = palettes[paletteIndex].name
    persistPalette()
    applyPalette()
end
local privateAccess = _G.ACTPrivateAccess == true
local CONTROLS = "SU/GIU: VOCI    SINISTRA/DESTRA: VALORI"
local ACTIONS = "A/CROCE: OK    B/CERCHIO: INDIETRO    F4 o L2+L3: ACT"

local function entry(builder, label, description, action)
    builder:entry(label, action)
    builder._children[#builder._children].actHelp = description
end
local function category(builder, label, description, build)
    builder:category(label, build)
    builder._children[#builder._children].actHelp = description
end
local function switch(builder, label, description, get, set)
    builder:switch(label, get, set)
    local node = builder._children[#builder._children]
    node.actHelp = description .. "  Usa sinistra/destra."
    node.actCycle = function()
        set(not get(), { hint = function(_, message) Ess.UI.Toast(message) end })
    end
end

-- Gli switch descrivono il personaggio corrente, non un GUID di una sessione precedente.
local function currentCharacter()
    local char = Ess.Player.character(0)
    if char and State.character and State.character ~= char then
        if State.invincible then Ess.Object.setInvincible(State.character, false, "ACT") end
        if State.infiniteAmmo then Ess.Human.setInfiniteAmmo(State.character, false) end
        State.invincible = false
        State.infiniteAmmo = false
    end
    if char then State.character = char end
    return char
end

local function restoreUi()
    if State.savedTheme then
        for name, value in pairs(State.savedTheme) do
            Theme[name] = value ~= false and value or nil
        end
        State.savedTheme = nil
        Theme.apply()
    end
    if State.savedKeys then
        for name, value in pairs(State.savedKeys) do Keys[name] = value end
        State.savedKeys = nil
    end
end

local menu = Ess.UI.Menu{
    title = "ACT",
    id = "ACT",
    key = "F4",
    onClose = function()
        persistPalette()
        if _G.ACTFlat then ACTFlat.close() end
        if State.helpPanel then State.helpPanel:hide() end
        restoreUi()
        if Loader and Loader.Printf then Loader.Printf("[ACT] menu chiuso") end
    end,
}

-- Ess usa lo stesso titolo anche per la seconda riga: cambia solo quella.
menu._root.label = "Amaranth Command Toolkit"

category(menu, "Player", "Vita, risorse, equipaggiamento e hijack.", function(m)
    switch(m, "Invincibilità", "Attiva o disattiva l'invincibilità del giocatore.", function()
        currentCharacter()
        return State.invincible
    end, function(enabled, ctx)
        local char = currentCharacter()
        if not char then return ctx:hint("Giocatore non disponibile") end
        if Ess.Object.setInvincible(char, enabled, "ACT") then
            State.invincible = enabled
            ctx:hint(enabled and "Invincibilità ON" or "Invincibilità OFF")
        else
            ctx:hint("Impossibile cambiare invincibilità")
        end
    end)

    entry(m, "Cura completa", "Ripristina completamente la vita del giocatore.", function(ctx)
        local char = currentCharacter()
        if not char then return ctx:hint("Giocatore non disponibile") end
        Ess.Object.heal(char)
        ctx:hint("Vita ripristinata")
    end)

    switch(m, "Munizioni infinite", "Attiva o disattiva le munizioni infinite.", function()
        currentCharacter()
        return State.infiniteAmmo
    end, function(enabled, ctx)
        local char = currentCharacter()
        if not char then return ctx:hint("Giocatore non disponibile") end
        Ess.Human.setInfiniteAmmo(char, enabled)
        State.infiniteAmmo = enabled
        ctx:hint(enabled and "Munizioni infinite ON" or "Munizioni infinite OFF")
    end)

    entry(m, "Rifornisci munizioni", "Ricarica tutte le armi possedute dal giocatore.", function(ctx)
        local char = currentCharacter()
        if not char then return ctx:hint("Giocatore non disponibile") end
        local weapons = Ess.Human.allWeapons(char)
        if #weapons == 0 then return ctx:hint("Nessuna arma da rifornire") end
        for _, weapon in ipairs(weapons) do Ess.Human.refillAmmo(weapon) end
        Ess.Human.reloadAll(char)
        ctx:hint("Munizioni rifornite")
    end)
    if _G.ACTExtras and ACTExtras.buildPlayerMenu then ACTExtras.buildPlayerMenu(m) end
end)

category(menu, "Support & Rewards", "Supporti, reward e zone d'atterraggio.", function(m)
    if _G.ACTExtras and ACTExtras.buildSupportMenu then ACTExtras.buildSupportMenu(m)
    else entry(m, "Modulo non disponibile", "Controlla il caricamento di ACT Extras.", function(ctx) ctx:hint("Extras non disponibile") end) end
end)

category(menu, "Fun", "Animazioni, fisica veicoli e bombardamenti.", function(m)
    if _G.ACTExtras and ACTExtras.buildFunMenu then ACTExtras.buildFunMenu(m)
    else entry(m, "Modulo non disponibile", "Controlla il caricamento di ACT Extras.", function(ctx) ctx:hint("Extras non disponibile") end) end
end)

category(menu, "Spawn Rapido", "Scegli fazione e ruolo, poi crea un NPC con AI nativa.", function(m)
    if _G.ACTTroops and ACTTroops.buildQuickMenu then
        ACTTroops.buildQuickMenu(m)
    else
        entry(m, "Modulo Truppe non disponibile", "Controlla il caricamento di Ess e riavvia il gioco.",
            function(ctx) ctx:hint("Riavvia il gioco e controlla Ess") end)
    end
end)
if privateAccess then category(menu, "Truppe", "Configura, crea e comanda le squadre ACT.", function(m)
    if _G.ACTTroops and ACTTroops.buildMenu then
        ACTTroops.buildMenu(m)
    else
        entry(m, "Modulo Truppe non disponibile", "Controlla il caricamento di Ess e riavvia il gioco.",
            function(ctx) ctx:hint("Riavvia il gioco e controlla Ess") end)
    end
end) else entry(menu, "Truppe [Bloccato]", "Disponibile nella versione privata di ACT.", function(ctx) ctx:hint("Funzione privata") end) end
if privateAccess then category(menu, "War Creator", "Prepara due schieramenti e avvia una battaglia ACT.", function(m)
    if _G.ACTWar and ACTWar.buildMenu then ACTWar.buildMenu(m)
    else entry(m, "Modulo non disponibile", "Controlla il caricamento di ACT War.", function(ctx) ctx:hint("War Creator non disponibile") end) end
end) else entry(menu, "War Creator [Bloccato]", "Disponibile nella versione privata di ACT.", function(ctx) ctx:hint("Funzione privata") end) end
if privateAccess then category(menu, "Creator Camera", "Telecamera libera per ispezionare e preparare future scene.", function(m)
    if _G.ACTCamera and ACTCamera.buildMenu then ACTCamera.buildMenu(m)
    else entry(m, "Modulo non disponibile", "Controlla il caricamento della camera ACT.", function(ctx) ctx:hint("Creator Camera non disponibile") end) end
end) else entry(menu, "Creator Camera [Bloccato]", "Disponibile nella versione privata di ACT.", function(ctx) ctx:hint("Funzione privata") end) end
category(menu, "Veicoli", "Crea veicoli ACT con equipaggio opzionale.", function(m)
    if _G.ACTTroops and ACTTroops.buildVehicleMenu then ACTTroops.buildVehicleMenu(m)
    else entry(m, "Modulo non disponibile", "Controlla Ess e riavvia il gioco.", function(ctx) ctx:hint("Veicoli non disponibili") end) end
end)
category(menu, "Mondo", "Controlla la popolazione NPC vicina.", function(m)
    if _G.ACTTroops and ACTTroops.buildWorldMenu then ACTTroops.buildWorldMenu(m)
    else entry(m, "Modulo non disponibile", "Controlla Ess e riavvia il gioco.", function(ctx) ctx:hint("Mondo non disponibile") end) end
end)
entry(menu, "Native Dev Menu", "Apre il menu sviluppatore originale, inclusi strumenti missione e debug.", function(ctx)
    if _G.ACTExtras and ACTExtras.openNative then ACTExtras.openNative(ctx)
    else ctx:hint("Native Dev Menu non disponibile") end
end)
category(menu, "Impostazioni", "Gestisci lingua, colori, simboli delle unità comandate e salva ACT.", function(m)
    entry(m, function()
        return "Lingua < " .. (Lang.current == "en" and "English" or "Italiano") .. " >"
    end, "Scegli la lingua del menu ACT. La scelta viene salvata subito.", function(ctx)
        if Lang.set then Lang.set(Lang.current == "en" and "it" or "en") end
        ctx:hint(Lang.current == "en" and "Language: English" or "Lingua: Italiano")
    end)
    m._children[#m._children].actCycle = function()
        if Lang.set then Lang.set(Lang.current == "en" and "it" or "en") end
    end
    category(m, "Come usarlo", "Comandi da tastiera e controller, spawn e gestione ACT.", function(h)
        local pages = {
            {"Aprire e chiudere", "F4 oppure L2 + L3 apre e chiude ACT. In freecam la combinazione esce dalla camera."},
            {"Tastiera: navigazione", "Frecce o tastierino 8/2: su/giu. Tastierino 4/6: cambia valori. Invio o 5: conferma. Backspace o 0: indietro."},
            {"Controller: navigazione", "D-pad o levetta sinistra: naviga. L2 scorre in basso. A/Croce oppure R1/RB conferma. B/Cerchio torna indietro."},
            {"Creare e comandare truppe", "Crea truppe: scegli le opzioni e Spawna. Database Si abilita Gestione Squadre; Database No lascia gli NPC liberi. Seleziona squadra o NPC, poi Ordini squadra."},
            {"Veicoli e preferiti", "Scegli dal catalogo o cerca un nome. Aggiungi ai preferiti salva subito. Spawn rapido veicoli crea con una conferma."},
            {"Freecam: PC", "WASD segue la visuale, mouse ruota. Shift accelera, Spazio sale, C scende. Velocita e croce si impostano prima dell'attivazione."},
            {"Freecam: controller", "Levetta sinistra muove, destra ruota. L3 sale, R3 scende. Nessun boost. F4 o L2+L3 esce."},
            {"Salvare le impostazioni", "Il colore e i preferiti si salvano subito. Salva conserva anche le scelte di spawn. I punti A/B valgono per il mondo corrente."},
        }
        for _, page in ipairs(pages) do
            local title, text = page[1], page[2]
            entry(h, title, text, function(ctx) ctx:hint(Lang.t(text)) end)
        end
    end)
    entry(m, function() return "Palette < " .. palettes[paletteIndex].name .. " >" end,
        "Cambia i colori di ACT con sinistra/destra. La scelta viene salvata subito.", function(ctx)
            changePalette(1)
            ctx:hint("Palette: " .. palettes[paletteIndex].name)
        end)
    m._children[#m._children].actCycle = changePalette
    entry(m, function()
        local enabled = _G.ACTTroops and ACTTroops.markersEnabled and ACTTroops.markersEnabled()
        return "Simbolo sopra truppe: " .. (enabled and "ON" or "OFF")
    end, "Mostra o nasconde i simboli su NPC e squadre comandati.", function(ctx)
        if _G.ACTTroops and ACTTroops.toggleMarkers then ACTTroops.toggleMarkers(ctx)
        else ctx:hint("Modulo Truppe non disponibile") end
    end)
    m._children[#m._children].actCycle = function()
        if _G.ACTTroops and ACTTroops.toggleMarkers then ACTTroops.toggleMarkers() end
    end
    entry(m, "Salva", "Salva le scelte di spawn e il simbolo per il prossimo avvio.", function(ctx)
        persistPalette()
        if _G.ACTTroops and ACTTroops.saveSettings then ACTTroops.saveSettings(ctx)
        else ctx:hint("Modulo Truppe non disponibile") end
    end)
end)
entry(menu, "Chiudi", "Chiude ACT e riprende il gioco.", function(ctx) ctx:close() end)

-- Settings stays at root; F4 / Back already close ACT.
table.remove(menu._root.children, 12)

if Lang.localizeTree then Lang.localizeTree(menu._root) end

local function refreshHelp()
    local list = menu._rt.list
    local item = list and list:selected()
    local node = item and item._node
    local description = Lang.t(node and node.actHelp or "Seleziona una voce del menu ACT.")
    if State.helpPanel then
        State.helpPanel:title(Lang.t("GUIDA ACT"))
        State.helpPanel:clear()
        local lines = Ess.UI.wrap(description, 48)
        State.helpPanel:fit(#lines)
        for i, line in ipairs(lines) do State.helpPanel:line(i - 1, line) end
        State.helpPanel:show()
    end
    if _G.ACTFlat then ACTFlat.refresh(menu) end
end

-- Ess aggiorna la lista dopo ogni azione; aggiorna la guida anche quando il cursore
-- viene ripristinato con list:select(), che non invoca onSelect.
local originalPaint, originalChoose = menu._paint, menu._choose
-- Keep focus by node identity: conditional rows can move an option's index.
local function selectNode(list, node, fallback)
    if not list then return end
    for i, item in ipairs(list._items) do
        if node and item._node == node then list:select(i); return end
    end
    local i = math.max(1, math.min(fallback or 1, #list._items))
    list:select(i)
end
local function installNavigation(list)
    if not list then return end
    -- Own ACT's complete key path; never delegate to Ess's wrapping List handler.
    -- Keep Ess's global bindings unchanged for confirmation and text dialogs.
    local aliases = {[0x68]=0x26, [0x62]=0x28, [0x64]=0x25, [0x66]=0x27,
        [0x65]=0x0D, [0x0C]=0x0D, [0x60]=0x08, [0x2D]=0x08}
    function list:_keyvk(vk)
        vk = aliases[vk] or vk
        if vk == 0x26 or vk == 0x28 or vk == 0x21 or vk == 0x22 then
            local direction = (vk == 0x26 or vk == 0x21) and -1 or 1
            local steps = (vk == 0x21 or vk == 0x22) and 10 or 1
            local selected = self._sel
            local wrapped = false
            for _=1,steps do
                local i = selected + direction
                while i >= 1 and i <= #self._items and self._items[i].header do i=i+direction end
                if i < 1 or i > #self._items then
                    if steps ~= 1 then break end
                    i = direction == 1 and 1 or #self._items
                    while i >= 1 and i <= #self._items and self._items[i].header do i=i+direction end
                    if i < 1 or i > #self._items then break end
                    wrapped = true
                end
                selected = i
            end
            if selected ~= self._sel then self:select(selected); refreshHelp() end
            -- Ess repeats held arrows. After one end-to-end jump, wait for release
            -- so holding a direction cannot spin through the whole menu forever.
            if wrapped and Ess.UI and Ess.UI._S and Ess.UI.KEYS
                and (vk == Ess.UI.KEYS.up or vk == Ess.UI.KEYS.down) then
                Ess.UI._S._repVk, Ess.UI._S._repCd = vk, math.huge
            end
            return
        elseif vk == 0x25 or vk == 0x27 then
            local item, index = self:selected()
            local node = item and item._node
            if node and node.actCycle then
                local ok, err = pcall(node.actCycle, vk == 0x27 and 1 or -1)
                if not ok and Loader and Loader.Printf then Loader.Printf("[ACT] opzione: " .. tostring(err)) end
                menu:_paint()
                selectNode(self, node, index)
                refreshHelp()
            end
            return
        elseif vk == 0x0D then
            local item = self:selected()
            if item and not item.header then menu:_choose(item) end
            return
        elseif vk == 0x08 then
            menu:_back()
            return
        end
    end
end
function menu:_paint()
    local list = self._rt.list
    self._actPositions = self._actPositions or setmetatable({}, {__mode="k"})
    if list and self._actPaintNode then
        local item, index = list:selected()
        self._actPositions[self._actPaintNode] = {
            node=item and item._node, index=index, offset=list._off or 0,
        }
    end
    if _G.ACTTroops and ACTTroops.refreshGroupList then ACTTroops.refreshGroupList() end
    if _G.ACTWar and ACTWar.refreshMenu then ACTWar.refreshMenu() end
    originalPaint(self)
    installNavigation(list)
    local panel = self._stack[#self._stack]
    local previous = self._actPositions[panel]
    if list and previous then
        list._off = math.max(0, math.min(previous.offset, math.max(0, #list._items - 10)))
        selectNode(list, previous.node, previous.index)
    end
    self._actPaintNode = panel
    if self._rt.list then self._rt.list:hint(Lang.t("SU/GIU VOCI  SX/DX VALORI  A/CROCE OK  B/CERCHIO INDIETRO")) end
    refreshHelp()
end
function menu:_choose(item)
    local panel = self._stack[#self._stack]
    originalChoose(self, item)
    if self:isOpen() and self._stack[#self._stack] == panel then
        -- Ess's action handler restores the old numeric index after painting.
        -- Restore the actual option instead when rows have been inserted/removed.
        selectNode(self._rt.list, item and item._node, self._rt.list._sel)
    end
    refreshHelp()
end

local function openLegacy(targetIndex)
currentCharacter()
-- Se la lista e stata nascosta da un cambio UI, ripara lo stato prima del toggle.
if menu:isOpen() and (not menu._rt.list or menu._rt.list._shown == false) then
    menu:close()
end
if not menu:isOpen() then
    State.savedTheme = {}
    for name in pairs(Theme.DEFAULTS) do
        State.savedTheme[name] = Theme[name] == nil and false or Theme[name]
    end
    State.savedKeys = {
        left = Keys.left, right = Keys.right,
        enter = Keys.enter, esc = Keys.esc,
    }

    applyPalette()

    -- ACT handles its own aliases; dialogs retain the standard Ess bindings.
end

if not menu:isOpen() and _G.ACTTroops and ACTTroops.captureTarget then ACTTroops.captureTarget() end
menu:toggle()
if menu:isOpen() then
    if Loader and Loader.Printf then Loader.Printf("[ACT] menu aperto") end
    if not State.helpPanel or State.helpPanel._destroyed then
        State.helpPanel = Ess.UI.Panel{ x = 350, y = 60, w = 360, h = 120, title = "GUIDA ACT" }
    else
        State.helpPanel:show()
    end
    State.helpPanel:fit(3)
    local list = menu._rt.list
    list.onSelect = refreshHelp
    installNavigation(list)
    menu._rt.list:hint(Lang.t("SU/GIU VOCI  SX/DX VALORI  A/CROCE OK  B/CERCHIO INDIETRO"))
    local targetNames = { "Player", "Truppe", "Veicoli", "Mondo", "War Creator", "Impostazioni" }
    local wanted = targetIndex and targetNames[targetIndex + 1]
    if wanted then
        for _, node in ipairs(menu._root.children) do
            local name = type(node.label) == "function" and node.label() or node.label
            if name == Lang.t(wanted) and node.children then
                menu._stack[#menu._stack + 1] = node
                menu:_paint()
                break
            end
        end
    end
    refreshHelp()
    if _G.ACTFlat then ACTFlat.open(menu, State.helpPanel) end
else
    restoreUi()
end
end

openLegacy()

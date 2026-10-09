-- ACT / Truppe. Caricato dopo Ess; ogni GUID rimosso da ACT proviene da Ess.Spawn.
local Ess = _G.Ess
if not (Ess and Ess.SaveVar and Ess.Spawn and Ess.Track and Ess.AIOrders and Ess.Followers
        and Ess.Followers.setMarkersEnabled
        and Ess.Squad and Ess.Squad.Tactics and Ess.Relations and Ess.Raw and Ess.Raw.Relations
        and Ess.Mark and Ess.Probe and Ess.Loop and Ess.Vehicle) then
    if Loader and Loader.Printf then Loader.Printf("[ACT] Truppe: Ess incompleto") end
    return
end

local T = {}
_G.ACTTroops = T

local S = Ess.State("ACTTroops", {
    faction = 1, role = 1, quantity = 3, side = 1,
    spawnPlace = 1, spawnPattern = 1, formation = 1, destination = 1,
    mixed = { rifle = 3, mg = 1, at = 1, sniper = 0 },
    autoDespawn = false, showMarkers = true,
    quickFaction = 1, quickRole = 1, quickQuantity = 1,
})

-- Le coordinate e i GUID valgono solo nel mondo corrente. Non rimuovere vecchi
-- GUID qui: dopo un caricamento potrebbero riferirsi a nuovi NPC del gioco.
S.groups, S.points, S.target, S.selectedId, S.nextId = {}, {}, nil, nil, 0
S.quickGuids, S.pointMarkers, S.vehicles, S.pendingRemovals = {}, {}, {}, {}
S.zeroPopulation, S.vehicleType, S.vehicleCrew, S.vehicleFaction = false, 1, 1, 1
S.vehicleSearch = ""
-- Creation starts with native relations and no database every session.
S.createRelation, S.createDatabase, S.createSlot = 1, false, "No"
S.quickMixed = { rifle = 3, mg = 1, at = 1, sniper = 0 }
local TEAM_SLOTS = { "Alpha", "Beta", "Gamma", "Delta" }
local RELATION_NAMES = { "Come da fazione", "Alleati", "Nemici" }

local NPC_LIMIT = 24
local DESPAWN_DISTANCE = 300
local FACTIONS = {
    { name = "Alleati", rifle = "Allied Soldier", mg = "Allied Heavy (Light MG)", at = "Allied Heavy (AT Rocket)" },
    { name = "Cina", rifle = "Chinese Soldier", mg = "Chinese Heavy (Light MG)", at = "Chinese Heavy (RPG)", sniper = "Chinese Sniper" },
    { name = "Guerriglia", rifle = "Guerilla Soldier", mg = "Guerilla Heavy (Light MG)", at = "Guerilla Heavy (RPG)" },
    { name = "Universal Petroleum", rifle = "OC Soldier", mg = "OC Heavy (Light MG)", at = "OC Heavy (RPG)", sniper = "OC Sniper" },
    { name = "Pirati", rifle = "Pirate Thug", at = "Pirate Thug (RPG)" },
    { name = "VZ", rifle = "VZ Soldier", mg = "VZ Heavy (Light MG)", at = "VZ Heavy (RPG)", sniper = "VZ Sniper" },
}
local ROLES = {
    { key = "rifle", name = "Soldato" }, { key = "mg", name = "Pesante" },
    { key = "at", name = "Lanciarazzi" }, { key = "sniper", name = "Cecchino" },
}
local QUANTITIES = { 1, 2, 3, 5, 8, 12, 16, 24 }
local PLACES = { "Davanti", "Punto A", "Punto B" }
local PATTERNS = { "grid", "line", "circle", "scatter" }
local PATTERN_NAMES = { "Griglia", "Linea", "Cerchio", "Sparsa" }
local FORMATIONS = { "wedge", "column", "line", "diamond" }
local FORMATION_NAMES = { "Cuneo", "Colonna", "Linea", "Diamante" }
local GROUP_NAMES = { "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot" }
local UI_ORDER_CATEGORIES = {
    { name = "Movimento", orders = {
        { "Seguimi", "follow" }, { "Fermati", "hold" },
        { "Vai al punto scelto", "move" }, { "Richiama selezione", "recall" },
    } },
    { name = "Combattimento", orders = {
        { "Difendi questa posizione", "defend" }, { "Mantieni posizione", "holdPosition" },
        { "Attacca bersaglio", "attack" }, { "Pattuglia A/B", "patrol" },
    } },
    { name = "Supporto", orders = {
        { "Formazione selezionata", "formation" }, { "Sali su veicolo mirato", "mount" },
    } },
}
local GROUP_COLORS = {
    { 0x79, 0xCF, 0xA3 }, { 0x86, 0xB7, 0xE8 }, { 0xD8, 0xA0, 0xE7 },
    { 0xF1, 0xBF, 0x79 }, { 0xE9, 0x8F, 0x96 }, { 0x8B, 0xD5, 0xD0 },
}
S.uiMixedRole, S.uiOrderCategory, S.uiOrder = 1, 1, 1
-- Template citati negli esempi installati di Ess. Gli elicotteri richiedono
-- spazio aperto; la Veyron e la scelta predefinita.
local VEHICLES = _G.ACTVehicleCatalog or {
    {name="Veyron", template="Veyron", group="Civilian", height=0},
}
local LEGACY_VEHICLES = {"Veyron", "ZTZ98", "Ambulance", "El Grande", "M35 (Cargo) (VZ)", "UH1 Transport", "AH1Z (Full)", "M151", "Humvee", "Buggy", "Motorcycle", "Sportbike", "Monster Truck", "Van", "Garbage Truck", "Transport Truck", "Guntruck", "M113", "LAV III", "WZ551", "M1A2", "M2A3", "AMX30", "Scorpion90", "Mi35", "Ka29b", "Alouette3 Transport", "Coanda Gunship"}
local vehicleByTemplate = {}
for index, item in ipairs(VEHICLES) do vehicleByTemplate[item.template] = index end
S.vehicleType = vehicleByTemplate.Veyron or 1
local favoriteSave = Ess.SaveVar.ns("ACTVehicleFavorites")
local favorites = {}
for name in tostring(favoriteSave:get("templates", "")):gmatch("[^|]+") do
    if vehicleByTemplate[name] then favorites[name] = true end
end
local function saveFavorites()
    local names = {}
    for name in pairs(favorites) do names[#names+1] = name end
    table.sort(names)
    favoriteSave:set("templates", table.concat(names, "|"))
end


-- Solo preferenze di menu: GUID, squadre e punti del mondo non sono riutilizzabili
-- dopo un caricamento. Il salvataggio avviene esclusivamente da Impostazioni > Salva.
local preferences = Ess.SaveVar.ns("ACT_Troops")
local function savedIndex(key, maximum, fallback)
    local value = tonumber(preferences:get(key, fallback))
    if not value or value % 1 ~= 0 or value < 1 or value > maximum then return fallback end
    return value
end
if preferences:flag("saved") then
    S.faction = savedIndex("faction", #FACTIONS, 1)
    S.role = savedIndex("role", #ROLES, 1)
    S.quantity = savedIndex("quantity", #QUANTITIES, 3)
    S.side = savedIndex("side", 2, 1) -- legacy vehicle/adapter preference
    -- Una posizione A/B non viene conservata, per evitare coordinate di un altro mondo.
    S.spawnPlace = 1
    S.spawnPattern = savedIndex("spawnPattern", #PATTERNS, 1)
    S.formation = savedIndex("formation", #FORMATIONS, 1)
    S.destination = 1
    for _, role in ipairs(ROLES) do
        local n = tonumber(preferences:get("mixed_" .. role.key, S.mixed[role.key]))
        if n and n % 1 == 0 and n >= 0 and n <= 8 then S.mixed[role.key] = n end
        local q = tonumber(preferences:get("quickMixed_" .. role.key, S.quickMixed[role.key]))
        if q and q % 1 == 0 and q >= 0 and q <= 10 then S.quickMixed[role.key] = q end
    end
    S.autoDespawn = preferences:flag("autoDespawn")
    S.showMarkers = preferences:flag("showMarkers")
    S.quickFaction = savedIndex("quickFaction", #FACTIONS, S.faction)
    S.quickRole = savedIndex("quickRole", #ROLES, S.role)
    S.quickQuantity = savedIndex("quickQuantity", 10, 1)
    local name = preferences:get("vehicleTemplate", "")
    if name == "" then name = LEGACY_VEHICLES[tonumber(preferences:get("vehicleType", 1)) or 1] end
    S.vehicleType = vehicleByTemplate[name] or vehicleByTemplate.Veyron or 1
    S.vehicleFaction = savedIndex("vehicleFaction", #FACTIONS, S.faction)
    S.vehicleCrew = tonumber(preferences:get("vehicleCrew", 0)) or 0
    if S.vehicleCrew < 0 or S.vehicleCrew > 4 or S.vehicleCrew % 1 ~= 0 then S.vehicleCrew = 0 end
end
if not FACTIONS[S.quickFaction][ROLES[S.quickRole].key] then S.quickRole = 1 end
for _, role in ipairs(ROLES) do
    if not FACTIONS[S.quickFaction][role.key] then S.quickMixed[role.key] = 0 end
end
-- Ess.Followers marca anche il bersaglio degli ordini e usa colori diversi per
-- ogni follower. ACT gestisce i propri simboli per mostrare solo unità gestite
-- e usare un colore identico per tutta la squadra.
Ess.Followers.setMarkersEnabled(false)

function T.saveSettings(ctx)
    local ok, err = pcall(function()
        preferences:set("faction", S.faction)
        preferences:set("role", S.role)
        preferences:set("quantity", S.quantity)
        preferences:set("side", S.side)
        preferences:set("spawnPattern", S.spawnPattern)
        preferences:set("formation", S.formation)
        for _, role in ipairs(ROLES) do
            preferences:set("mixed_" .. role.key, S.mixed[role.key] or 0)
            preferences:set("quickMixed_" .. role.key, S.quickMixed[role.key] or 0)
        end
        preferences:setFlag("autoDespawn", S.autoDespawn)
        preferences:setFlag("showMarkers", S.showMarkers)
        preferences:set("quickFaction", S.quickFaction)
        preferences:set("quickRole", S.quickRole)
        preferences:set("quickQuantity", S.quickQuantity)
        preferences:set("vehicleType", S.vehicleType)
        preferences:set("vehicleTemplate", VEHICLES[S.vehicleType].template)
        preferences:set("vehicleFaction", S.vehicleFaction)
        preferences:set("vehicleCrew", S.vehicleCrew)
        preferences:setFlag("saved", true)
    end)
    if ctx then ctx:hint(ok and "Preferenze ACT salvate" or "Salvataggio ACT non riuscito") end
    if not ok and Loader and Loader.Printf then Loader.Printf("[ACT] Salva: " .. tostring(err)) end
    return ok
end

local function hint(ctx, message)
    if ctx then ctx:hint(message) elseif Ess.UI and Ess.UI.Toast then Ess.UI.Toast(message) end
end

local function cycle(field, maximum, direction)
    S[field] = ((S[field] - 1 + (direction or 1)) % maximum) + 1
end

local function liveGuids(group)
    local live = {}
    for _, guid in ipairs(group.guids) do
        if Ess.Object.alive(guid) then live[#live + 1] = guid end
    end
    return live
end

local function trackedCount()
    local total = 0
    for _, group in ipairs(S.groups) do
        if group.active then total = total + #liveGuids(group) end
    end
    for i = #S.pendingRemovals, 1, -1 do
        if Ess.Object.alive(S.pendingRemovals[i].guid) then
            if S.pendingRemovals[i].counts ~= false then total = total + 1 end
        else table.remove(S.pendingRemovals, i) end
    end
    return total
end
function T.activeCount() return trackedCount() end
local function warCount()
    return _G.ACTWar and ACTWar.activeCount and ACTWar.activeCount() or 0
end

local function selectedGroup()
    if S.selectedId then
        for _, group in ipairs(S.groups) do
            if group.id == S.selectedId then return group end
        end
    end
    return S.groups[#S.groups]
end

local function groupLabel(group)
    if not group then return "Nessuna" end
    local label = group.isTeam and group.name or
        (group.name .. (group.managed and " (segue)" or " (libero)"))
    return label .. " (#" .. group.id .. ", " .. #liveGuids(group) .. "/" .. #group.guids .. " vive)"
end

local function setGroupMarkers(group, enabled)
    group.markers = group.markers or {}
    if not enabled or not group.managed then
        for key, marker in pairs(group.markers) do
            Ess.Mark.clear(marker)
            group.markers[key] = nil
        end
        return
    end
    for _, guid in ipairs(liveGuids(group)) do
        local key = tostring(guid)
        if not group.markers[key] then
            local marker = Ess.Mark.object(guid, {
                radar = false, pda = false, world = true, kind = "generic",
                rgb = group.color,
                size = 24, dist = 125,
            })
            if marker and marker.worldHandle then group.markers[key] = marker end
        end
    end
end

function T.toggleMarkers(ctx)
    S.showMarkers = not S.showMarkers
    Ess.Followers.setMarkersEnabled(false)
    for _, group in ipairs(S.groups) do setGroupMarkers(group, S.showMarkers) end
    hint(ctx, S.showMarkers and "Simboli truppe ACT: ON" or "Simboli truppe ACT: OFF")
end

function T.markersEnabled() return S.showMarkers end

local function removeGroup(group)
    if not group or not group.active then return false end
    group.active = false
    if group.readyLoop then Ess.Loop.stop(group.readyLoop) end
    setGroupMarkers(group, false)
    if group.managed and group.side == "ally" then
        if group.isTeam then
            Ess.Squad.clearFormation(group.teamKey)
            Ess.Squad.cancelQueue(group.teamKey)
        end
        for _, guid in ipairs(group.guids) do Ess.Followers.dismiss(guid) end
    end
    if group.orderTracker then group.orderTracker:closeAll() end
    for _, guid in ipairs(group.guids) do
        local ok, vehicle = Ess.Safe.quiet(Vehicle.GetFromRider, guid)
        if ok and vehicle then Ess.Vehicle.exit(vehicle, guid) end
    end
    group.tracker:closeAll()
    -- Object.Remove e differito: conserva i GUID finche l'engine non conferma
    -- che sono spariti, evitando di contare come liberi slot ancora occupati.
    for _, guid in ipairs(group.guids) do
        if Ess.Object.alive(guid) then
            S.pendingRemovals[#S.pendingRemovals + 1] = { guid = guid, tries = 0 }
        end
    end
    for i = #S.groups, 1, -1 do
        if S.groups[i] == group then table.remove(S.groups, i); break end
    end
    if S.selectedId == group.id then S.selectedId = nil end
    return true
end

local function prepareOrder(group, ctx)
    if not group then hint(ctx, "Nessun NPC o squadra ACT"); return nil end
    if not group.ready then hint(ctx, "Squadra in preparazione"); return nil end
    group.managed = true
    setGroupMarkers(group, S.showMarkers)
    local guids = liveGuids(group)
    if #guids == 0 then hint(ctx, "Nessuna unità viva"); return nil end
    if group.side == "ally" then
        if group.isTeam then
            Ess.Squad.clearFormation(group.teamKey)
            if #Ess.Squad.team(group.teamKey) == 0 then
                hint(ctx, "Squadra alleata non pronta"); return nil
            end
        elseif not Ess.Followers.isFollower(guids[1]) then
            hint(ctx, "NPC non ancora arruolato"); return nil
        end
    else
        for _, guid in ipairs(guids) do
            Ess.Safe.quiet(Ai.RemoveGoal, { AIGuid = guid, Handle = 0 })
        end
        group.orderTracker:closeAll()
        group.orderTracker = Ess.Track.new()
    end
    return guids
end

local function issue(behavior, opts, ctx)
    local group = selectedGroup()
    local guids = prepareOrder(group, ctx)
    if not guids then return false end
    local ok
    if group.side == "ally" then
        Ess.Followers.setMarkersEnabled(false)
        if group.isTeam then
            ok = Ess.Squad.orderTeam(group.teamKey, behavior, opts or {})
        else
            ok = Ess.Followers._orderScoped(group.teamKey, guids, behavior, opts or {})
        end
        if ok then
            group.autoCombat = behavior == "follow"
            group.autoTarget = nil
        end
    else
        ok = Ess.AIOrders.command(guids, behavior, opts or {}, group.orderTracker)
    end
    hint(ctx, ok and (group.name .. ": " .. behavior) or "Ordine non applicato")
    return ok
end

local function followSelected(ctx)
    local group = selectedGroup()
    if not group then hint(ctx, "Nessun NPC o squadra ACT"); return end
    if not group.ready then hint(ctx, "Squadra in preparazione"); return end
    if group.side == "ally" and group.managed then
        issue("follow", {}, ctx)
        return
    end
    local player = Ess.Player.character(0)
    if not player then hint(ctx, "Giocatore non disponibile"); return end
    local live = liveGuids(group)
    if #live == 0 then hint(ctx, "Nessuna unità viva"); return end
    group.orderTracker:closeAll()
    Ess.Followers.setMarkersEnabled(false)
    local recruited = 0
    for _, guid in ipairs(live) do
        -- Only the explicit Follow order allies these individual NPCs.
        Ess.Relations.setFeeling(guid, player, 100)
        if Ess.Followers.recruit(guid, { target = player }) then recruited = recruited + 1 end
    end
    if recruited ~= #live then
        for _, guid in ipairs(live) do Ess.Followers.dismiss(guid) end
        hint(ctx, "Ordine non applicato")
        return
    end
    group.managed, group.side, group.autoCombat = true, "ally", true
    if group.isTeam then
        Ess.Squad.createTeam(group.teamKey, live)
        if group.formation then Ess.Squad.setFormation(group.teamKey, group.formation, { spacing = 3 }) end
    end
    setGroupMarkers(group, S.showMarkers)
    hint(ctx, group.name .. ": follow")
end

local function spawnOptions(ctx, count, formationSpawn, placeIndex)
    local opts = {
        pattern = formationSpawn and "grid" or PATTERNS[S.spawnPattern],
        spacing = 4, columns = math.max(1, math.ceil(math.sqrt(count))),
        minDist = 2, maxDist = 7, snapToGround = true, max = NPC_LIMIT,
    }
    placeIndex = placeIndex or S.spawnPlace
    if placeIndex == 1 then
        if not Ess.Player.character(0) then hint(ctx, "Giocatore non disponibile"); return nil end
        opts.ahead = 14
    else
        local key = placeIndex == 2 and "A" or "B"
        if not S.points[key] then hint(ctx, "Punto " .. key .. " non salvato"); return nil end
        opts.at = S.points[key]
        opts.yaw = S.points[key].yaw
    end
    return opts
end

local function spawnRoster(roster, formationSpawn, ctx, sideIndex, placeIndex, asTeam)
    if #roster == 0 then hint(ctx, "Scegli almeno una unità"); return end
    if trackedCount() + warCount() + #roster > NPC_LIMIT then
        hint(ctx, "Limite ACT: " .. (trackedCount() + warCount()) .. "/" .. NPC_LIMIT .. " NPC. Rimuovi uno spawn")
        return
    end
    local opts = spawnOptions(ctx, #roster, formationSpawn, placeIndex)
    if not opts then return end
    local tracker = Ess.Track.new()
    opts.tracker = tracker
    local guids = Ess.Spawn.many(roster, nil, opts)
    if #guids == 0 then tracker:closeAll(); hint(ctx, "Spawn fallito: controlla template/posizione"); return end

    S.nextId = S.nextId + 1
    local id = S.nextId
    local group = {
        id = id, name = asTeam and GROUP_NAMES[((id - 1) % #GROUP_NAMES) + 1] or ("NPC " .. id),
        teamKey = "ACT_Team_" .. id, guids = guids, tracker = tracker,
        orderTracker = Ess.Track.new(), side = (sideIndex or S.side) == 1 and "ally" or "enemy",
        active = true, ready = not asTeam, isTeam = asTeam == true, managed = asTeam == true,
        autoCombat = asTeam == true and (sideIndex or S.side) == 1,
        color = GROUP_COLORS[((id - 1) % #GROUP_COLORS) + 1],
        formation = formationSpawn and FORMATIONS[S.formation] or nil,
    }
    S.groups[#S.groups + 1] = group
    S.selectedId = nil -- per impostazione predefinita, l'ultimo spawn

    -- Spawn singolo e Spawn Rapido mantengono fazione e AI native: nessun
    -- arruolamento, marker, ordine o rapporto individuale viene imposto.
    if asTeam then
        -- Ai.Get/SetFeeling su un NPC appena creato può essere stale nello stesso tick.
        group.readyLoop = "ACTTroops.ready." .. id
        Ess.Loop.start(group.readyLoop, 0.5, function()
            if not group.active then return false end
            local current = Ess.Player.character(0)
            if not current then return true end
            local live = liveGuids(group)
            for _, guid in ipairs(live) do
                Ess.Relations.setFeeling(guid, current, group.side == "ally" and 100 or -100)
            end
            if group.side == "ally" then
                Ess.Followers.setMarkersEnabled(false)
                for _, guid in ipairs(live) do Ess.Followers.recruit(guid, { target = current }) end
                Ess.Squad.createTeam(group.teamKey, live)
                if group.formation then Ess.Squad.setFormation(group.teamKey, group.formation, { spacing = 3 }) end
            else
                Ess.AIOrders.command(live, "attack", { target = current }, group.orderTracker)
            end
            group.ready = true
            if S.showMarkers then setGroupMarkers(group, true) end
            return false
        end)
    end
    local sideName = not asTeam and "liberi" or (group.side == "ally" and "alleati" or "nemici")
    local formationNote = formationSpawn and group.side == "enemy" and "; griglia statica" or ""
    hint(ctx, (asTeam and group.name or ("NPC #" .. id)) .. ": " .. #guids .. " NPC " .. sideName .. formationNote)
    return group
end

local function spawnQuick(ctx)
    local faction, role = FACTIONS[S.quickFaction], ROLES[S.quickRole]
    local template = faction[role.key]
    if not template then hint(ctx, "Ruolo non disponibile per " .. faction.name); return end
    local opts = spawnOptions(ctx, S.quickQuantity, false, 1)
    if not opts then return end
    -- Niente tracker o gruppo: l'engine puo eliminare questi NPC normalmente.
    local guids = Ess.Spawn.many(template, S.quickQuantity, opts)
    for _, guid in ipairs(guids) do S.quickGuids[tostring(guid)] = guid end
    hint(ctx, #guids .. "/" .. S.quickQuantity .. " NPC rapidi creati (fuori dal limite di 24)")
end

local function spawnUniform(count, formationSpawn, ctx, factionIndex, roleIndex, sideIndex, placeIndex, asTeam)
    local faction = FACTIONS[factionIndex or S.faction]
    local role = ROLES[roleIndex or S.role]
    local template = faction[role.key]
    if not template then hint(ctx, role.name .. " non disponibile per " .. faction.name); return end
    local roster = {}
    for i = 1, count do roster[i] = template end
    return spawnRoster(roster, formationSpawn, ctx, sideIndex, placeIndex, asTeam)
end

local function spawnVehicle(ctx, quick)
    local crewCount = quick and 0 or S.vehicleCrew
    if not Ess.Player.character(0) then hint(ctx, "Giocatore non disponibile"); return end
    if crewCount > 0 and trackedCount() + warCount() + crewCount > NPC_LIMIT then
        hint(ctx, "Limite equipaggi: " .. (trackedCount() + warCount()) .. "/" .. NPC_LIMIT); return
    end
    local choice = VEHICLES[S.vehicleType]
    local vehicle = Ess.Object.spawnAhead(choice.template, 25, choice.height)
    if not vehicle then hint(ctx, "Spawn veicolo non riuscito"); return end
    local record = { guid = vehicle, crew = nil }
    S.vehicles[#S.vehicles + 1] = record
    if crewCount == 0 then hint(ctx, choice.name .. " creata senza equipaggio"); return end
    local crew = spawnUniform(crewCount, false, nil, S.vehicleFaction, S.role, nil, 1, false)
    if not crew then hint(ctx, "Veicolo creato; equipaggio non disponibile"); return end
    record.crew = crew
    local loopId = "ACTTroops.board." .. crew.id
    local attempts = 0
    Ess.Loop.start(loopId, 0.75, function()
        attempts = attempts + 1
        if not Ess.Object.alive(vehicle) or not crew.active then return false end
        local seated = 0
        for _, guid in ipairs(liveGuids(crew)) do
            if not Ess.Vehicle.seatOf(guid) then Ess.Vehicle.enterBestSeat(guid, vehicle) end
            if Ess.Vehicle.seatOf(guid) then seated = seated + 1 end
        end
        if seated == #liveGuids(crew) or attempts >= 4 then
            hint(nil, seated .. "/" .. #liveGuids(crew) .. " membri equipaggio saliti su " .. choice.name)
            return false
        end
        return true
    end)
    hint(ctx, choice.name .. " e " .. #crew.guids .. " NPC creati; salita in corso")
end

local function removeLastVehicle(ctx)
    local record = table.remove(S.vehicles)
    if not record then hint(ctx, "Nessun veicolo ACT"); return end
    if record.crew and record.crew.active then removeGroup(record.crew) end
    if Ess.Object.alive(record.guid) then Ess.Object.remove(record.guid) end
    hint(ctx, "Veicolo ACT rimosso")
end

local function spawnMixed(ctx)
    local faction = FACTIONS[S.faction]
    local roster = {}
    for _, role in ipairs(ROLES) do
        local count = S.mixed[role.key] or 0
        if count > 0 and not faction[role.key] then
            hint(ctx, role.name .. " non disponibile per " .. faction.name)
            return
        end
        for _ = 1, count do roster[#roster + 1] = faction[role.key] end
    end
    spawnRoster(roster, false, ctx, nil, nil, true)
end

function T.captureTarget()
    local target = Ess.Player.targetUnderReticle(0)
    local player = Ess.Player.character(0)
    S.target = target and target ~= player and Ess.Object.valid(target) and target or nil
end

local function savePoint(key, ctx)
    local x, y, z, yaw = Ess.Player.pose(0)
    if not x then hint(ctx, "Giocatore non disponibile"); return end
    S.points[key] = { x = x, y = y, z = z, yaw = yaw }
    local marker = Ess.Mark.zone(x, y, z, 3, {
        world = true, radar = false, pda = false, icon = true,
        rgb = key == "A" and { 0x50, 0xD6, 0xA0 } or { 0xF2, 0xA6, 0x5A },
        discAlpha = 0.55, size = 26, dist = 200,
    })
    if S.pointMarkers[key] then Ess.Mark.clear(S.pointMarkers[key]) end
    S.pointMarkers[key] = marker
    hint(ctx, marker and ("Punto " .. key .. " salvato: cerchio " .. (key == "A" and "verde" or "arancione"))
        or ("Punto " .. key .. " salvato, ma marker non disponibile"))
end

local function destination(ctx)
    local key = S.destination == 1 and "A" or "B"
    local point = S.points[key]
    if not point then hint(ctx, "Punto " .. key .. " non salvato") end
    return point
end

local function attackTarget(ctx)
    local target = S.target
    if not target or not Ess.Object.alive(target) then
        hint(ctx, "Mira a un bersaglio prima di aprire ACT")
        return
    end
    local group = selectedGroup()
    if group then
        for _, guid in ipairs(group.guids) do
            if guid == target then hint(ctx, "Bersaglio appartenente alla squadra"); return end
        end
    end
    issue("attack", { target = target }, ctx)
end

local function groupCentre(group)
    local live = liveGuids(group)
    local sx, sy, sz, n = 0, 0, 0, 0
    for _, guid in ipairs(live) do
        local x, y, z = Ess.Object.pos(guid)
        if x then sx, sy, sz, n = sx + x, sy + y, sz + z, n + 1 end
    end
    if n > 0 then return { x = sx / n, y = sy / n, z = sz / n } end
end

local function selectNextGroup(ctx)
    if #S.groups == 0 then hint(ctx, "Nessun NPC o squadra ACT"); return end
    if not S.selectedId then S.selectedId = S.groups[1].id
    else
        local nextId
        for i, group in ipairs(S.groups) do
            if group.id == S.selectedId then
                nextId = S.groups[i + 1] and S.groups[i + 1].id
                break
            end
        end
        S.selectedId = nextId
    end
    hint(ctx, S.selectedId and groupLabel(selectedGroup()) or "Selezione: ultimo spawn")
end

local function renameGroup(name, ctx)
    local group = selectedGroup()
    if not group then hint(ctx, "Nessuna squadra ACT"); return end
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then hint(ctx, "Nome vuoto"); return end
    group.name = name:sub(1, 24)
    hint(ctx, "Squadra rinominata: " .. group.name)
end

local function presetRename(ctx)
    local group = selectedGroup()
    if not group then hint(ctx, "Nessuna squadra ACT"); return end
    local nextName = GROUP_NAMES[1]
    for i, name in ipairs(GROUP_NAMES) do
        if group.name == name then nextName = GROUP_NAMES[(i % #GROUP_NAMES) + 1]; break end
    end
    renameGroup(nextName, ctx)
end

local function recall(ctx)
    local x, y, z = Ess.Player.pose(0)
    if not x then hint(ctx, "Giocatore non disponibile"); return end
    issue("move", { at = { x = x, y = y, z = z } }, ctx)
end

local function setFormation(ctx)
    local group = selectedGroup()
    if not group or not group.isTeam or group.side ~= "ally" then
        hint(ctx, "Formazione: serve una squadra alleata"); return
    end
    if not group.ready then hint(ctx, "Squadra in preparazione"); return end
    local ok = Ess.Squad.setFormation(group.teamKey, FORMATIONS[S.formation], { spacing = 3 })
    hint(ctx, ok and (group.name .. ": formazione " .. FORMATION_NAMES[S.formation]) or "Formazione non applicata")
end

local function mountVehicle(ctx)
    local group = selectedGroup()
    if not group or not group.isTeam or group.side ~= "ally" then
        hint(ctx, "Veicolo: serve una squadra alleata"); return
    end
    if not group.ready then hint(ctx, "Squadra in preparazione"); return end
    if not S.target or not Ess.Object.valid(S.target) then
        hint(ctx, "Mira al veicolo prima di aprire ACT"); return
    end
    local hasSeat = false
    for _, role in ipairs({ "d", "g", "p", "c" }) do
        local ok, seat = Ess.Safe.quiet(Vehicle.GetSeatByType, S.target, role, true)
        if ok and seat then hasSeat = true; break end
    end
    if not hasSeat then hint(ctx, "Bersaglio senza posti liberi o non veicolo"); return end
    Ess.Squad.clearFormation(group.teamKey)
    local ok = Ess.Squad.Tactics.mountUp(S.target, group.teamKey, { timeout = 20 })
    if ok then group.autoCombat = false; group.autoTarget = nil end
    hint(ctx, ok and "Ordine di salita inviato (servono posti liberi)" or "Salita non disponibile")
end

local function resetOrders(ctx)
    local group = selectedGroup()
    if not group then hint(ctx, "Nessuna squadra ACT"); return end
    if group.isTeam then
        Ess.Squad.clearFormation(group.teamKey)
        Ess.Squad.cancelQueue(group.teamKey)
    end
    for _, guid in ipairs(liveGuids(group)) do
        Ess.Followers.dismiss(guid)
        Ess.Safe.quiet(Ai.RemoveGoal, { AIGuid = guid, Handle = 0 })
    end
    group.orderTracker:closeAll()
    group.orderTracker = Ess.Track.new()
    group.autoCombat, group.autoTarget, group.side = false, nil, "native"
    -- Restore the individual feeling captured before any override/follow.
    local player = Ess.Player.character(0)
    if player then
        for _, guid in ipairs(liveGuids(group)) do
            local original = (group.nativeFeelings or {})[tostring(guid)]
            if type(original) == "number" then Ess.Relations.setFeeling(guid, player, original) end
        end
    end
    hint(ctx, "Ordini AI azzerati")
end

local function autoDespawnTick()
    for i = #S.groups, 1, -1 do
        local group = S.groups[i]
        if group.ready and #liveGuids(group) == 0 then removeGroup(group) end
    end
    trackedCount() -- elimina dal registro le rimozioni confermate dall'engine
    if not S.autoDespawn then return true end
    local player = Ess.Player.character(0)
    if not player then return true end
    local px, _, pz = Ess.Object.pos(player)
    if not px then return true end
    for i = #S.groups, 1, -1 do
        local group = S.groups[i]
        local live = liveGuids(group)
        local far = true
        for _, guid in ipairs(live) do
            local x, _, z = Ess.Object.pos(guid)
            if x and (x - px) ^ 2 + (z - pz) ^ 2 <= DESPAWN_DISTANCE ^ 2 then
                far = false; break
            end
        end
        if #live == 0 or far then removeGroup(group) end
    end
    return true
end
Ess.Loop.start("ACTTroops.autoDespawn", 5, autoDespawnTick)

Ess.Loop.start("ACTTroops.cleanup", 1, function()
    for i = #S.pendingRemovals, 1, -1 do
        local item = S.pendingRemovals[i]
        if not Ess.Object.alive(item.guid) then
            table.remove(S.pendingRemovals, i)
        else
            item.tries = item.tries + 1
            if item.tries <= 5 then Ess.Object.remove(item.guid)
            elseif item.tries == 6 then Ess.Object.kill(item.guid) end
        end
    end
    return true
end)

-- Intervento locale sul mondo caricato: OFF ferma la pulizia, ma gli NPC gia
-- rimossi non possono essere ricreati da Ess. I GUID ACT sono esclusi.
Ess.Loop.start("ACTTroops.zeroPopulation", 4, function()
    for key, guid in pairs(S.quickGuids) do
        if not Ess.Object.alive(guid) then S.quickGuids[key] = nil end
    end
    if not S.zeroPopulation then return true end
    local x, y, z = Ess.Player.pose(0)
    if not x then return true end
    local protected = {}
    for key in pairs(S.quickGuids) do protected[key] = true end
    for _, group in ipairs(S.groups) do
        for _, guid in ipairs(group.guids) do protected[tostring(guid)] = true end
    end
    if _G.ACTWar and ACTWar.allGuids then
        for _, guid in ipairs(ACTWar.allGuids()) do protected[tostring(guid)] = true end
    end
    local removed = 0
    for _, guid in ipairs(Ess.Probe.nearby(x, y, z, 90, "humans")) do
        if removed >= 40 then break end
        if not protected[tostring(guid)] and Ess.Object.alive(guid) then
            Ess.Object.remove(guid)
            removed = removed + 1
        end
    end
    return true
end)

function T.buildVehicleMenu(m)
    local function entry(label, description, action, cycleAction)
        m:entry(label, action)
        local node = m._children[#m._children]
        node.actHelp, node.actCycle = description, cycleAction
    end
    local function selected() return VEHICLES[S.vehicleType] end
    local function vehicleCycle(d) cycle("vehicleType", #VEHICLES, d) end
    local function crewCycle(d) S.vehicleCrew = (S.vehicleCrew + d) % 5 end
    local function factionCycle(d) cycle("vehicleFaction", #FACTIONS, d) end
    local lists = {}
    local function populate(node, filter, quick, backSteps)
        for i=#node.children,1,-1 do table.remove(node.children,i) end
        for index, vehicle in ipairs(VEHICLES) do
            if filter(vehicle) then
                local choice = index
                node.children[#node.children+1] = {
                    label = function() return (favorites[VEHICLES[choice].template] and "* " or "") .. VEHICLES[choice].name end,
                    action = function(ctx)
                        S.vehicleType = choice
                        if quick then spawnVehicle(ctx, true)
                        else
                            hint(ctx, "Veicolo scelto: " .. selected().name)
                            if ctx._menu then for _=1,(backSteps or 1) do ctx._menu:_back() end end
                        end
                    end,
                    actHelp = quick and "Spawna subito un veicolo; nessun equipaggio ACT aggiunto." or "Seleziona il veicolo per lo spawn; * indica un preferito.",
                }
            end
        end
        if #node.children == 0 then node.children[1] = {label="Nessun risultato", action=function(ctx) hint(ctx,"Nessun veicolo in questo elenco") end} end
    end
    local function addList(builder, label, filter, quick, backSteps)
        builder:category(label, function() end)
        local node = builder._children[#builder._children]
        lists[#lists+1] = {node=node, filter=filter, quick=quick, backSteps=backSteps}
        populate(node, filter, quick, backSteps)
    end
    local function rebuild()
        for _, list in ipairs(lists) do populate(list.node, list.filter, list.quick, list.backSteps) end
    end
    local vehicleFactions = {
        {label="Alleati", group="Allied Nations"}, {label="Cina", group="China"},
        {label="Guerriglia", group="PLAV"}, {label="Universal Petroleum", group="Universal Petroleum"},
        {label="Pirati", group="Pirates"}, {label="VZ", group="Venezuelan Army"},
        {label="PMC", group="PMC"}, {label="Civili", group="Civilian"},
    }
    local function vehicleGroup(v)
        if v.group=="Sports Car" or v.group=="Truck" then return "Civilian" end
        if v.template=="UH1 Transport (PMC)" then return "PMC" end
        return v.group
    end
    local function factionLists(builder, quick)
        builder:category("Fazione",function(c)
            for _, faction in ipairs(vehicleFactions) do
                local group=faction.group
                addList(c,faction.label,function(v) return vehicleGroup(v)==group end,quick,2)
            end
        end)
        builder._children[#builder._children].actHelp = "Apri una fazione per vedere soltanto i suoi veicoli."
        -- Mounted guns are not vehicles and stay in their own catalog.
        builder:category("Armi fisse",function(c)
            addList(c,"Senza operatore",function(v) return v.group=="Emplaced Weapons" end,quick,2)
            addList(c,"Con operatore",function(v) return v.group=="Emplaced Weapons (Manned)" end,quick,2)
        end)
    end
    m:category("Spawn rapido veicoli", function(q)
        q:entry(function() return "Veicolo < " .. selected().name .. " >" end, function() vehicleCycle(1) end)
        q._children[#q._children].actCycle = vehicleCycle
        q:entry("Spawna", function(ctx) spawnVehicle(ctx,true) end)
        q._children[#q._children].actHelp = "Crea subito un veicolo davanti a te, senza equipaggio ACT aggiunto."
        factionLists(q,true)
        addList(q,"Preferiti - spawn immediato",function(v) return favorites[v.template] end,true)
    end)
    entry(function() return "Veicolo < " .. selected().name .. " >" end,
        "Sinistra/destra cambia veicolo. Per barche usa acqua aperta; per elicotteri spazio libero.", function() vehicleCycle(1) end, vehicleCycle)
    entry(function() return favorites[selected().template] and "Rimuovi dai preferiti" or "Aggiungi ai preferiti" end,
        "Salva o rimuove il veicolo selezionato dai preferiti, subito e anche per il prossimo avvio.",
        function(ctx)
            local name = selected().template
            favorites[name] = not favorites[name] or nil
            saveFavorites(); rebuild(); hint(ctx, favorites[name] and "Preferito salvato" or "Preferito rimosso")
        end)
    addList(m,"Preferiti",function(v) return favorites[v.template] end,false)
    factionLists(m,false)
    entry(function() return "Cerca veicolo: " .. (S.vehicleSearch ~= "" and S.vehicleSearch or "[tutti]") end,
        "Scrivi parte del nome, poi apri Risultati ricerca.", function(ctx)
            ctx:ask("Cerca veicolo",function(value)
                S.vehicleSearch=tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1,40)
                rebuild();if ctx._menu and ctx._menu:isOpen() then ctx._menu:_paint() end
            end)
        end)
    addList(m,"Risultati ricerca",function(v) return v.name:lower():find(S.vehicleSearch:lower(),1,true)~=nil end,false)
    entry(function() return "NPC a bordo < " .. S.vehicleCrew .. " >" end,
        "Da 0 a 4 NPC ACT aggiuntivi; le varianti Full/Driver hanno gia equipaggio nativo.",function() crewCycle(1) end,crewCycle)
    entry(function() return "Fazione equipaggio < " .. FACTIONS[S.vehicleFaction].name .. " >" end,
        "Scegli la fazione degli NPC ACT aggiunti al veicolo.",function() factionCycle(1) end,factionCycle)
    entry("Spawna veicolo","Crea il veicolo con l'equipaggio ACT configurato.",function(ctx) spawnVehicle(ctx,false) end)
    entry("Rimuovi ultimo veicolo ACT","Rimuove l'ultimo veicolo registrato e il suo equipaggio ACT.",removeLastVehicle)
end

function T.buildWorldMenu(m)
    m:entry(function() return "Zero popolazione vicina: " .. (S.zeroPopulation and "ON" or "OFF") end,
        function(ctx)
            S.zeroPopulation = not S.zeroPopulation
            hint(ctx, S.zeroPopulation and "Pulizia NPC entro 90 m attiva" or "Pulizia NPC fermata")
        end)
    local node = m._children[#m._children]
    node.actHelp = "Rimuove ogni 4 s gli NPC vicini non creati da ACT. Può toccare NPC di missione; OFF non li ripristina."
    node.actCycle = function() S.zeroPopulation = not S.zeroPopulation end
end

-- Il ruolo Follow usato da Ess ha priorità alta e disattiva la LivingWorld AI:
-- senza un ordine esplicito la recluta può seguire il giocatore senza sparare.
-- Cerca solo NPC ostili nelle vicinanze e applica l'ostilità alla coppia
-- soldato ACT -> bersaglio, senza cambiare i rapporti globali tra fazioni.
local function autoCombatTick()
    for _, group in ipairs(S.groups) do
        for key, marker in pairs(group.markers or {}) do
            if not Ess.Object.alive(marker.uGuid) then
                Ess.Mark.clear(marker)
                group.markers[key] = nil
            end
        end
    end
    local hasFollowers = false
    for _, group in ipairs(S.groups) do
        if group.active and group.ready and group.side == "ally" and group.autoCombat
                and #liveGuids(group) > 0 then
            hasFollowers = true
            break
        end
    end
    if not hasFollowers then return true end
    local player = Ess.Player.character(0)
    if not player then return true end
    local px, py, pz = Ess.Object.pos(player)
    if not px then return true end
    local _, playerFaction = Ess.Safe.quiet(MrxUtil.GetFaction, player)
    local actUnits = {}
    for _, group in ipairs(S.groups) do
        for _, guid in ipairs(group.guids) do actUnits[tostring(guid)] = true end
    end
    local hostiles = {}
    for _, candidate in ipairs(Ess.Probe.nearby(px, py, pz, 90, "humans")) do
        if not actUnits[tostring(candidate)] and Ess.Object.alive(candidate) then
            local hostile = Ess.Relations.getFeeling(candidate, player) < 0
            if not hostile and playerFaction then
                local _, faction = Ess.Safe.quiet(MrxUtil.GetFaction, candidate)
                if faction and faction ~= playerFaction then
                    local relation = Ess.Raw.Relations.snapshot(faction, playerFaction)
                    hostile = relation.ok and type(relation.val) == "number" and relation.val < 0
                end
            end
            if hostile then hostiles[#hostiles + 1] = candidate end
        end
    end
    for _, group in ipairs(S.groups) do
        if group.active and group.ready and group.side == "ally" and group.autoCombat then
            local target = group.autoTarget
            if target and Ess.Object.alive(target) then
                local tx, _, tz = Ess.Object.pos(target)
                if tx and (tx - px) ^ 2 + (tz - pz) ^ 2 > 100 ^ 2 then
                    group.autoTarget = nil
                    if not group.isTeam then
                        Ess.Followers._orderScoped(group.teamKey, liveGuids(group), "follow", {})
                    elseif #Ess.Squad.team(group.teamKey) > 0 then
                        Ess.Squad.orderTeam(group.teamKey, "follow", {})
                    else
                        Ess.AIOrders.command(liveGuids(group), "follow", { target = player })
                    end
                end
            else
                group.autoTarget = nil
            end
            if not group.autoTarget then
                local centre = groupCentre(group)
                local closest, best = nil, 65 ^ 2
                if centre then
                    for _, candidate in ipairs(hostiles) do
                        local x, _, z = Ess.Object.pos(candidate)
                        if x then
                            local d = (x - centre.x) ^ 2 + (z - centre.z) ^ 2
                            if d < best then closest, best = candidate, d end
                        end
                    end
                end
                if closest then
                    for _, guid in ipairs(liveGuids(group)) do
                        Ess.Relations.setFeeling(guid, closest, -100)
                    end
                    local ordered
                    Ess.Followers.setMarkersEnabled(false)
                    if not group.isTeam then
                        ordered = Ess.Followers._orderScoped(group.teamKey, liveGuids(group),
                            "attack", { target = closest })
                    elseif #Ess.Squad.team(group.teamKey) > 0 then
                        ordered = Ess.Squad.orderTeam(group.teamKey, "attack", { target = closest })
                    else
                        ordered = Ess.AIOrders.command(liveGuids(group), "attack",
                            { target = closest }, group.orderTracker)
                    end
                    if ordered then
                        group.autoTarget = closest
                        if Loader and Loader.Printf then
                            Loader.Printf("[ACT] " .. group.name .. " attacca bersaglio " .. tostring(closest))
                        end
                    end
                end
            end
        end
    end
    return true
end
Ess.Loop.start("ACTTroops.autoCombat", 3, autoCombatTick)

-- The named slot is separate from the display name, so renaming cannot free it.
local function availableSlots()
    local occupied, names = {}, { "No" }
    for _, group in ipairs(S.groups) do
        if group.active and #liveGuids(group) > 0 then
            occupied[group.slot or (group.isTeam and group.name) or ""] = true
        end
    end
    for _, name in ipairs(TEAM_SLOTS) do
        if not occupied[name] then names[#names + 1] = name end
    end
    return names
end

local function currentSlot()
    if not S.createDatabase then S.createSlot = "No"; return "No" end
    for _, name in ipairs(availableSlots()) do
        if S.createSlot == name then return name end
    end
    S.createSlot = "No"
    return "No"
end

local function cycleSlot(d)
    if not S.createDatabase then return end
    local names, current = availableSlots(), currentSlot()
    for i, name in ipairs(names) do
        if current == name then S.createSlot = names[((i - 1 + d) % #names) + 1]; return end
    end
end

local function createConfigured(ctx)
    local faction, role = FACTIONS[S.faction], ROLES[S.role]
    local template = faction[role.key]
    if not template then hint(ctx, role.name .. " non disponibile per " .. faction.name); return end
    local count, slot, relation = QUANTITIES[S.quantity], currentSlot(), S.createRelation
    if S.createDatabase and trackedCount() + warCount() + count > NPC_LIMIT then
        hint(ctx, "Limite ACT: " .. (trackedCount() + warCount()) .. "/" .. NPC_LIMIT .. " NPC. Rimuovi uno spawn")
        return
    end
    local opts = spawnOptions(ctx, count, false)
    if not opts then return end
    local guids = Ess.Spawn.many(template, count, opts)
    if #guids == 0 then hint(ctx, "Spawn fallito: controlla template/posizione"); return end
    local created = {}
    local function register(units, isTeam)
        S.nextId = S.nextId + 1
        local id = S.nextId
        local group = {
            id = id, name = isTeam and slot or ("NPC " .. id), slot = isTeam and slot or nil,
            guids = units, teamKey = "ACT_Team_" .. id, tracker = Ess.Track.new(),
            orderTracker = Ess.Track.new(), nativeFeelings = {},
            side = "native", active = true, ready = false, managed = false, isTeam = isTeam,
            formation = isTeam and FORMATIONS[S.formation] or nil,
            color = GROUP_COLORS[((id - 1) % #GROUP_COLORS) + 1],
        }
        for _, guid in ipairs(units) do group.tracker:guid(guid) end
        S.groups[#S.groups + 1], created[#created + 1] = group, group
        return group
    end
    if S.createDatabase then
        if slot ~= "No" then register(guids, true)
        else for _, guid in ipairs(guids) do register({ guid }, false) end end
        S.selectedId = created[#created].id
        S.createSlot = "No"
    else
        for _, guid in ipairs(guids) do S.quickGuids[tostring(guid)] = guid end
    end
    if not S.createDatabase and relation == 1 then
        hint(ctx, #guids .. " NPC creati - Database: No")
        return
    end
    -- Fresh AI feelings are not reliable in the same spawn tick.
    local loopId = "ACTTroops.create." .. tostring(guids[1])
    Ess.Loop.start(loopId, 0.5, function()
        if #created > 0 then
            local active = false
            for _, group in ipairs(created) do if group.active then active = true; break end end
            if not active then return false end
        end
        local player = Ess.Player.character(0)
        if not player then return true end
        for _, group in ipairs(created) do
            if group.active then
                for _, guid in ipairs(liveGuids(group)) do
                    local ok, val = Ess.Safe.quiet(Ai.GetFeeling, guid, player)
                    if ok and type(val) == "number" then group.nativeFeelings[tostring(guid)] = val end
                end
                group.ready = true
            end
        end
        if relation ~= 1 then
            local eligible = guids
            if #created > 0 then
                eligible = {}
                for _, group in ipairs(created) do
                    if group.active then for _, guid in ipairs(liveGuids(group)) do eligible[#eligible+1] = guid end end
                end
            end
            for _, guid in ipairs(eligible) do
                if Ess.Object.alive(guid) then Ess.Relations.setFeeling(guid, player, relation == 2 and 100 or -100) end
            end
        end
        -- Native relation: no SetFeeling, no recruit, no forced orders.
        return false
    end)
    hint(ctx, #guids .. " NPC creati - Database: " .. (S.createDatabase and "Si" or "No"))
end

local function quickMixedSpawn(ctx)
    local roster, faction = {}, FACTIONS[S.quickFaction]
    for _, role in ipairs(ROLES) do
        local count = S.quickMixed[role.key] or 0
        if count > 0 and not faction[role.key] then hint(ctx, role.name .. " non disponibile per " .. faction.name); return end
        for _ = 1, count do roster[#roster + 1] = faction[role.key] end
    end
    if #roster == 0 then hint(ctx, "Scegli almeno una unità"); return end
    local opts = spawnOptions(ctx, #roster, false, 1)
    if not opts then return end
    opts.max = 40 -- four roles, at most ten each; no managed database slots
    local guids = Ess.Spawn.many(roster, #roster, opts)
    for _, guid in ipairs(guids) do S.quickGuids[tostring(guid)] = guid end
    hint(ctx, #guids .. "/" .. #roster .. " NPC rapidi creati (fuori dal limite di 24)")
end

local function removeNearby(ctx)
    local x, y, z = Ess.Player.pose(0)
    if not x then hint(ctx, "Giocatore non disponibile"); return end
    local player, player2 = Ess.Player.character(0), Ess.Player.character(1)
    local removed, count = {}, 0
    for _, guid in ipairs(Ess.Probe.nearby(x, y, z, 30, "humans")) do
        local gx, gy, gz = Ess.Object.pos(guid)
        local key = tostring(guid)
        if guid ~= player and guid ~= player2 and not removed[key] and gx
                and (gx-x)^2 + (gy-y)^2 + (gz-z)^2 <= 30^2 and Ess.Object.valid(guid) then
            Ess.Followers.dismiss(guid)
            local ok, vehicle = Ess.Safe.quiet(Vehicle.GetFromRider, guid)
            if ok and vehicle then Ess.Vehicle.exit(vehicle, guid) end
            Ess.Object.remove(guid)
            removed[key], S.quickGuids[key], count = true, nil, count + 1
            S.pendingRemovals[#S.pendingRemovals + 1] = {guid=guid, tries=0, counts=false}
        end
    end
    for i = #S.groups, 1, -1 do
        local group, remaining = S.groups[i], {}
        for _, guid in ipairs(group.guids) do
            if not removed[tostring(guid)] then remaining[#remaining+1] = guid end
        end
        if #remaining < #group.guids then
            setGroupMarkers(group, false)
            group.guids = remaining
            -- Spawn trackers contain only GUID disposers. Replace their list instead
            -- of closing it, which would remove the units outside the requested radius.
            group.tracker = Ess.Track.new()
            for _, guid in ipairs(remaining) do group.tracker:guid(guid) end
            if #remaining == 0 then removeGroup(group)
            else
                if group.isTeam and group.side == "ally" then Ess.Squad.createTeam(group.teamKey, liveGuids(group)) end
                setGroupMarkers(group, S.showMarkers)
            end
        end
    end
    hint(ctx, count .. " NPC rimossi entro 30 metri")
end

local function menuHelpers()
    local function entry(m, label, description, action)
        m:entry(label, action)
        m._children[#m._children].actHelp = description
    end
    local function option(m, label, description, action)
        entry(m, label, description .. "  Usa sinistra/destra.", function() action(1) end)
        m._children[#m._children].actCycle = action
    end
    local function category(m, label, description, fn)
        m:category(label, fn)
        m._children[#m._children].actHelp = description
    end
    return entry, option, category
end

function T.buildQuickMenu(m)
    local entry, option, category = menuHelpers()
    local function factionOption(c)
        option(c, function() return "Fazione < " .. FACTIONS[S.quickFaction].name .. " >" end,
            "Scegli la fazione dei prossimi NPC rapidi.", function(d)
                cycle("quickFaction", #FACTIONS, d)
                if not FACTIONS[S.quickFaction][ROLES[S.quickRole].key] then S.quickRole = 1 end
                for _, role in ipairs(ROLES) do
                    if not FACTIONS[S.quickFaction][role.key] then S.quickMixed[role.key] = 0 end
                end
            end)
    end
    factionOption(m)
    option(m, function() return "Ruolo < " .. ROLES[S.quickRole].name .. " >" end,
        "Scegli un ruolo disponibile per la fazione.", function(d)
            repeat cycle("quickRole", #ROLES, d) until FACTIONS[S.quickFaction][ROLES[S.quickRole].key]
        end)
    option(m, function() return "Numero < " .. S.quickQuantity .. " >" end,
        "Crea da 1 a 10 NPC per volta.", function(d) cycle("quickQuantity", 10, d) end)
    entry(m, "Spawna NPC rapidi", "Crea NPC liberi con AI nativa, fuori dal limite di 24.", spawnQuick)
    entry(m, "Elimina tutti gli NPC nel raggio di 30 metri",
        "Rimuove tutti gli NPC entro 30 metri, anche ACT; esclude i giocatori.", removeNearby)
    category(m, "Crea gruppo", "Crea un gruppo misto libero, senza database o ordini ACT.", function(c)
        factionOption(c)
        for _, role in ipairs(ROLES) do
            local key, name = role.key, role.name
            option(c, function()
                return name .. " < " .. (FACTIONS[S.quickFaction][key] and tostring(S.quickMixed[key]) or "Non disponibile") .. " >"
            end, "Quantita da 0 a 10; i ruoli non disponibili restano esclusi.", function(d)
                if not FACTIONS[S.quickFaction][key] then S.quickMixed[key] = 0; return end
                S.quickMixed[key] = (S.quickMixed[key] + d) % 11
            end)
        end
        entry(c, "CREA", "Crea i quattro ruoli nelle quantita scelte, con rapporti e AI della fazione.", quickMixedSpawn)
    end)
end

function T.buildMenu(m)
    local entry, option, category = menuHelpers()
    category(m, "Crea truppe", "Configura le truppe e premi Spawna. Database No lascia gli NPC al mondo di gioco.", function(c)
        option(c, function() return "Fazione < " .. FACTIONS[S.faction].name .. " >" end,
            "Fazione delle prossime truppe; conserva i rapporti presenti nel gioco.", function(d)
                cycle("faction", #FACTIONS, d)
                if not FACTIONS[S.faction][ROLES[S.role].key] then S.role = 1 end
            end)
        option(c, function() return "Ruolo < " .. ROLES[S.role].name .. " >" end,
            "Tipo di soldato; vengono mostrati solo i ruoli disponibili.", function(d)
                repeat cycle("role", #ROLES, d) until FACTIONS[S.faction][ROLES[S.role].key]
            end)
        option(c, function() return "Numero < " .. QUANTITIES[S.quantity] .. " >" end,
            "Numero di NPC da creare; il database ha un limite condiviso di 24.", function(d) cycle("quantity", #QUANTITIES, d) end)
        option(c, function() return "Rapporto < " .. RELATION_NAMES[S.createRelation] .. " >" end,
            "Come da fazione e il valore iniziale: non forza amicizia o ostilita. VZ conserva la sua ostilita.", function(d) cycle("createRelation", 3, d) end)
        category(c, function() return "Luogo < " .. PLACES[S.spawnPlace] .. " >" end,
            "Sinistra/destra sceglie il luogo; conferma apre il salvataggio dei punti A/B.", function(p)
                option(p, function() return "Luogo < " .. PLACES[S.spawnPlace] .. " >" end,
                    "Davanti al giocatore oppure nel punto A/B salvato.", function(d) cycle("spawnPlace", #PLACES, d) end)
                entry(p, "Salva Punto A qui", "Salva la tua posizione nel punto A e mostra il cerchio verde.", function(ctx) savePoint("A", ctx); S.spawnPlace = 2 end)
                entry(p, "Salva Punto B qui", "Salva la tua posizione nel punto B e mostra il cerchio arancione.", function(ctx) savePoint("B", ctx); S.spawnPlace = 3 end)
            end)
        c._children[#c._children].actCycle = function(d) cycle("spawnPlace", #PLACES, d) end
        option(c, function() return "Schema < " .. PATTERN_NAMES[S.spawnPattern] .. " >" end,
            "Disposizione iniziale al suolo; gli NPC sono distanziati di quattro metri.", function(d) cycle("spawnPattern", #PATTERNS, d) end)
        option(c, function() return "Formazione AI < " .. FORMATION_NAMES[S.formation] .. " >" end,
            "Formazione usata dalla squadra dopo l'ordine Seguimi; non forza ordini allo spawn.", function(d) cycle("formation", #FORMATIONS, d) end)
        option(c, function() return "Database < " .. (S.createDatabase and "Si" or "No") .. " >" end,
            "No: NPC liberi che il gioco puo eliminare. Si: NPC registrati e controllabili in Gestione Squadre.", function()
                S.createDatabase = not S.createDatabase
                if not S.createDatabase then S.createSlot = "No" end
            end)
        option(c, function() return "Assegnazione squadra < " .. currentSlot() .. " >" end,
            "Richiede Database Si. No registra singoli NPC; Alpha/Beta/Gamma/Delta assegnano una squadra libera.", cycleSlot)
        entry(c, "Spawna", "Crea le truppe con tutte le scelte di questa schermata.", createConfigured)
    end)
    category(m, "Gestione Squadre", "Seleziona una squadra o un NPC del database, poi rinomina, rimuovi o dai ordini.", function(g)
        entry(g, function() return "Squadra selezionata: " .. groupLabel(selectedGroup()) end,
            "Mostra la selezione e il numero di membri vivi; usa gli elenchi qui sotto per cambiarla.", function(ctx) hint(ctx, groupLabel(selectedGroup())) end)
        category(g, "Seleziona squadra", "Elenca solo le squadre registrate e ancora presenti.", function() end)
        T.teamListNode = g._children[#g._children]
        category(g, "Seleziona NPC", "Elenca solo gli NPC nel database senza una squadra assegnata.", function() end)
        T.npcListNode = g._children[#g._children]
        entry(g, "Rinomina squadra (solo tastiera)", "Scrivi il nuovo nome con la tastiera; lo slot assegnato resta occupato.", function(ctx)
            local group = selectedGroup()
            if not group or not group.isTeam then hint(ctx, "Seleziona prima una squadra"); return end
            ctx:ask("Nome squadra", function(name) if group.active then S.selectedId=group.id; renameGroup(name) end end)
        end)
        entry(g, "Rimuovi squadra/NPC", "Elimina solo la selezione e libera la relativa voce nel database.", function(ctx) T.uiAction("removeSelected", ctx) end)
        category(g, "Ordini squadra", "Gli ordini si applicano alla squadra o al singolo NPC selezionati.", function(o)
            entry(o, "Seguimi", "Arruola la selezione come alleata e la fa seguire il giocatore.", followSelected)
            entry(o, "Fermati", "Ferma la selezione nel punto in cui si trova.", function(ctx) issue("hold", {}, ctx) end)
            entry(o, "Difendi questa posizione", "Difende l'area entro 15 metri dalla tua posizione.", function(ctx)
                local x,y,z=Ess.Player.pose(0)
                if not x then hint(ctx,"Giocatore non disponibile"); return end
                issue("defend", {at={x=x,y=y,z=z},radius=15}, ctx)
            end)
            option(o, function() return "Destinazione ordine < " .. (S.destination == 1 and "A" or "B") .. " >" end,
                "Punto usato da Vai al punto scelto; salvalo in Crea truppe > Luogo.", function(d) cycle("destination",2,d) end)
            entry(o, "Vai al punto scelto", "Sposta la selezione al punto A o B salvato.", function(ctx) local at=destination(ctx); if at then issue("move",{at=at},ctx) end end)
            entry(o, "Attacca bersaglio", "Attacca l'NPC mirato prima di aprire ACT.", attackTarget)
            entry(o, "Pattuglia A/B", "Pattuglia tra i due punti salvati in Crea truppe > Luogo.", function(ctx)
                if not S.points.A or not S.points.B then hint(ctx,"Salva prima Punto A e B"); return end
                issue("patrol",{points={S.points.A,S.points.B},loop=true},ctx)
            end)
            entry(o, "Mantieni posizione", "Difende entro tre metri dal centro della selezione.", function(ctx)
                local group=selectedGroup();local at=group and groupCentre(group)
                if not at then hint(ctx,"Squadra non disponibile"); return end
                issue("defend",{at=at,radius=3},ctx)
            end)
            entry(o, "Richiama selezione", "Manda la selezione verso la tua posizione attuale.", recall)
            entry(o, "Formazione selezionata", "Applica la formazione scelta a una squadra che ti segue.", setFormation)
            entry(o, "Sali su veicolo mirato", "Fa salire una squadra che ti segue, se ci sono posti liberi.", mountVehicle)
            entry(o, "Reset ordini AI", "Annulla gli ordini, interrompe il seguito e ripristina il rapporto originario.", resetOrders)
        end)
        option(g, function() return "Elimina dopo 300m < " .. (S.autoDespawn and "Si" or "No") .. " >" end,
            "Rimuove dal database i gruppi quando tutti i loro membri sono oltre 300 metri da te.", function() S.autoDespawn = not S.autoDespawn end)
    end)
    T.refreshGroupList()
end

function T.refreshGroupList()
    for _, info in ipairs({{T.teamListNode,true},{T.npcListNode,false}}) do
        local node, isTeam = info[1], info[2]
        if node then
            local children = node.children
            for i=#children,1,-1 do table.remove(children,i) end
            for _, group in ipairs(S.groups) do
                if group.active and #liveGuids(group)>0 and group.isTeam == isTeam then
                    local g=group
                    children[#children+1]={label=function()
                        local label=groupLabel(g)
                        return _G.ACTLang and ACTLang.t(label) or label
                    end, actHelp="Seleziona questa unita o squadra, poi apri Ordini squadra.", action=function(ctx)
                        S.selectedId=g.id;g.managed=true;setGroupMarkers(g,S.showMarkers)
                        hint(ctx,"Selezionata: " .. groupLabel(g))
                    end}
                end
            end
            if #children==0 then children[1]={label="Nessuna",actHelp="Nessuna unita presente in questo elenco.",action=function(ctx)hint(ctx,"Nessun NPC o squadra ACT")end} end
        end
    end
end

-- Adapter per la UI ACT: espone dati e azioni senza duplicare la logica di spawn.
function T.uiSnapshot()
    local groups = {}
    for i = #S.groups, 1, -1 do
        local group = S.groups[i]
        if group.active then
            groups[#groups + 1] = {
                id = group.id, name = group.name, live = #liveGuids(group),
                total = #group.guids, side = group.side,
                isTeam = group.isTeam, managed = group.managed,
            }
        end
    end
    local chosen = selectedGroup()
    local orderCategory = UI_ORDER_CATEGORIES[S.uiOrderCategory]
    local order = orderCategory.orders[S.uiOrder]
    local mix = S.mixed
    return {
        faction = FACTIONS[S.faction].name, role = ROLES[S.role].name,
        quantity = QUANTITIES[S.quantity],
        side = RELATION_NAMES[S.createRelation],
        place = PLACES[S.spawnPlace],
        groups = groups, npcCount = trackedCount(), npcLimit = NPC_LIMIT,
        selectedId = chosen and chosen.id or nil,
        selectedName = chosen and chosen.name or "Nessuna",
        selectedLive = chosen and (#liveGuids(chosen) .. "/" .. #chosen.guids) or "0/0",
        pattern = PATTERN_NAMES[S.spawnPattern], formation = FORMATION_NAMES[S.formation],
        mixedRole = ROLES[S.uiMixedRole].name,
        mixedCount = mix[ROLES[S.uiMixedRole].key] or 0,
        mixedSummary = "S" .. (mix.rifle or 0) .. " P" .. (mix.mg or 0)
            .. " L" .. (mix.at or 0) .. " C" .. (mix.sniper or 0),
        pointA = S.points.A and "Salvato" or "Da salvare",
        pointB = S.points.B and "Salvato" or "Da salvare",
        destination = S.destination == 1 and "A" or "B",
        target = S.target and Ess.Object.alive(S.target) and "Acquisito" or "Nessuno",
        orderCategory = orderCategory.name, order = order[1],
        markers = S.showMarkers and "ON" or "OFF",
        autoDespawn = S.autoDespawn and "ON" or "OFF",
        lastName = S.groups[#S.groups] and S.groups[#S.groups].name or "Nessuno",
    }
end

function T.uiCycle(field, direction)
    direction = direction or 1
    if field == "faction" then cycle("faction", #FACTIONS, direction)
    elseif field == "role" then cycle("role", #ROLES, direction)
    elseif field == "quantity" then cycle("quantity", #QUANTITIES, direction)
    elseif field == "side" then cycle("side", 2, direction)
    elseif field == "place" then cycle("spawnPlace", #PLACES, direction)
    elseif field == "pattern" then cycle("spawnPattern", #PATTERNS, direction)
    elseif field == "formation" then cycle("formation", #FORMATIONS, direction)
    elseif field == "mixedRole" then cycle("uiMixedRole", #ROLES, direction)
    elseif field == "mixedCount" then
        local key = ROLES[S.uiMixedRole].key
        S.mixed[key] = ((S.mixed[key] or 0) + direction) % 9
    elseif field == "destination" then cycle("destination", 2, direction)
    elseif field == "orderCategory" then
        cycle("uiOrderCategory", #UI_ORDER_CATEGORIES, direction)
        S.uiOrder = 1
    elseif field == "order" then
        cycle("uiOrder", #UI_ORDER_CATEGORIES[S.uiOrderCategory].orders, direction)
    elseif field == "group" then selectNextGroup()
    elseif field == "markers" then T.toggleMarkers()
    elseif field == "autoDespawn" then S.autoDespawn = not S.autoDespawn
    else return false end
    return true
end

function T.uiAction(action, ctx)
    if action == "spawnSquad" then
        return spawnUniform(QUANTITIES[S.quantity], false, ctx, nil, nil, nil, nil, true)
    elseif action == "spawnSingle" then
        return spawnUniform(1, false, ctx, nil, nil, nil, nil, false)
    elseif action == "spawnFormation" then
        return spawnUniform(QUANTITIES[S.quantity], true, ctx, nil, nil, nil, nil, true)
    elseif action == "spawnMixed" then return spawnMixed(ctx)
    elseif action == "saveA" then return savePoint("A", ctx)
    elseif action == "saveB" then return savePoint("B", ctx)
    elseif action == "captureTarget" then
        T.captureTarget()
        hint(ctx, S.target and "Bersaglio salvato" or "Nessun bersaglio mirato")
    elseif action == "executeOrder" then
        local order = UI_ORDER_CATEGORIES[S.uiOrderCategory].orders[S.uiOrder][2]
        if order == "follow" then return followSelected(ctx)
        elseif order == "hold" then return issue("hold", {}, ctx)
        elseif order == "move" then
            local point = destination(ctx)
            if point then return issue("move", { at = point }, ctx) end
        elseif order == "recall" then return recall(ctx)
        elseif order == "defend" then
            local x, y, z = Ess.Player.pose(0)
            if not x then hint(ctx, "Giocatore non disponibile"); return end
            return issue("defend", { at = { x = x, y = y, z = z }, radius = 15 }, ctx)
        elseif order == "holdPosition" then
            local group = selectedGroup()
            local at = group and groupCentre(group)
            if not at then hint(ctx, "Squadra non disponibile"); return end
            return issue("defend", { at = at, radius = 3 }, ctx)
        elseif order == "attack" then return attackTarget(ctx)
        elseif order == "patrol" then
            if not S.points.A or not S.points.B then hint(ctx, "Salva prima Punto A e B"); return end
            return issue("patrol", { points = { S.points.A, S.points.B }, loop = true }, ctx)
        elseif order == "formation" then return setFormation(ctx)
        elseif order == "mount" then return mountVehicle(ctx) end
    elseif action == "resetOrders" then return resetOrders(ctx)
    elseif action == "renamePreset" then return presetRename(ctx)
    elseif action == "removeSelected" then
        local group = selectedGroup()
        if not group then hint(ctx, "Nessun NPC o squadra ACT"); return false end
        local name = group.name
        removeGroup(group)
        hint(ctx, name .. " rimossa")
        return true
    elseif action == "removeLast" then
        local group = S.groups[#S.groups]
        if not group then hint(ctx, "Nessun NPC o squadra ACT"); return false end
        local name = group.name
        removeGroup(group)
        hint(ctx, name .. " rimossa")
        return true
    elseif action == "removeAll" then
        local count = #S.groups
        for i = #S.groups, 1, -1 do removeGroup(S.groups[i]) end
        hint(ctx, count .. " gruppi ACT rimossi")
        return true
    elseif action == "toggleMarkers" then return T.toggleMarkers(ctx)
    elseif action == "toggleAutoDespawn" then
        S.autoDespawn = not S.autoDespawn
        hint(ctx, S.autoDespawn and "Auto despawn attivo" or "Auto despawn disattivo")
        return true
    end
    return false
end

function T.uiRename(name, ctx) return renameGroup(name, ctx) end

function T.uiSelectGroup(id)
    for _, group in ipairs(S.groups) do
        if group.active and group.id == id then
            S.selectedId = id
            return true
        end
    end
    return false
end

if Loader and Loader.Printf then Loader.Printf("[ACT] Truppe pronto, limite " .. NPC_LIMIT) end

-- Funzioni aggiuntive ACT. OnLoad dopo Ess; nessuna patch diretta di memoria.
local Ess = _G.Ess
if not (Ess and Ess.Player and Ess.UI and Ess.Loop and Ess.Impulse and Ess.Support) then
    if Loader and Loader.Printf then Loader.Printf("[ACT] Extras: Ess incompleto") end
    return
end
local X = {}
_G.ACTExtras = X
local S = Ess.State("ACTExtras", {
    hijack = false, speed = false, lowrider = false, bombard = false, hop = false,
})
S.wardrobeUnlocked = false
local function hint(ctx, message)
    if ctx then ctx:hint(message) else Ess.UI.Toast(message) end
end
local function add(builder, label, description, action, change)
    builder:entry(label, action)
    local node = builder._children[#builder._children]
    node.actHelp, node.actCycle = description, change
end
local function toggle(builder, label, description, field)
    local function change()
        S[field] = not S[field]
        hint(nil, label .. ": " .. (S[field] and "ON" or "OFF"))
    end
    add(builder, function() return label .. ": " .. (S[field] and "ON" or "OFF") end,
        description .. " Sinistra/destra cambia ON/OFF.", change, change)
end
local function currentVehicle()
    local vehicle = Ess.Player.inVehicle(0)
    if vehicle and Ess.Object.alive(vehicle) then return vehicle end
    return nil
end

-- Override documentato nel sample HijackAutoSuccess; OFF passa all'originale.
local hijackReady = false
pcall(function()
    import("MrxActionHijack")
    import("MrxGuiHudActionHijack")
    if MrxActionHijack and MrxActionHijack.OnMinigameStart then
        local installed = Ess.Override.wrap(MrxActionHijack, "OnMinigameStart", function(original, self)
            if not S.hijack then
                local a, b, c, d = original(self)
                return a, b, c, d
            end
            local step = self and self[self.nCurrent]
            if not step then return end
            step._buttonPressed, step.bSuccess = true, true
            pcall(MrxGuiHudActionHijack.HideButton, self._hijackerPlayer)
            pcall(Sound.CueSound, 0, "ui_HUD_Minigame_Press_Button")
            if step.nReactiveLoop ~= nil and not step.bMinigameDone then
                step.bMinigameDone = true
                MrxActionHijack.DeleteAllEvents(self)
                MrxActionHijack.DoSuccessAnimation(self)
            end
        end)
        if installed then MrxActionHijack._actHijackWrapped = true end
        hijackReady = installed or MrxActionHijack._actHijackWrapped or false
    end
end)

local function unlockCostumes(ctx)
    local ok, err = pcall(function()
        import("WifPmcInterior")
        local wardrobe = WifPmcInterior and WifPmcInterior._tOutfits
        if not wardrobe then error("guardaroba non disponibile") end
        if WifPmcInterior._actWardrobe then S.wardrobeUnlocked = true; return end
        local merged = {}
        for _, list in pairs(wardrobe) do
            for _, outfit in ipairs(list) do merged[#merged + 1] = outfit end
        end
        if #merged == 0 then error("nessun costume disponibile") end
        for hero in pairs(wardrobe) do wardrobe[hero] = merged end
        WifPmcInterior.GetAvailableCostumes = function() return #merged end
        WifPmcInterior._actWardrobe = true
        S.wardrobeUnlocked = true
    end)
    hint(ctx, ok and "Costumi disponibili nel guardaroba HQ fino al riavvio" or ("Costumi: " .. tostring(err)))
end
function X.buildPlayerMenu(m)
    add(m, "+ $1.000.000", "Aggiunge un milione ai soldi del giocatore.", function(ctx)
        Ess.Player.giveCash(1000000); hint(ctx, "Soldi aggiunti")
    end)
    add(m, "Riempi carburante", "Aggiunge solo il carburante mancante fino alla capacita attuale.", function(ctx)
        local current, cap = Ess.Player.fuel()
        if not current or not cap then hint(ctx, "Carburante non disponibile"); return end
        Ess.Player.giveFuel(math.max(0, cap - current)); hint(ctx, "Carburante pieno")
    end)
    add(m, "Sblocca costumi", "Mostra i costumi dei protagonisti nel guardaroba HQ per questa sessione.", unlockCostumes)
    add(m, "Sblocca rampino", "Aggiunge l'equipaggiamento GrapplingHook.", function(ctx)
        Ess.Easy.Player.giveGrapplingHook(); hint(ctx, "Rampino sbloccato")
    end)
    local function changeHijack()
        if not hijackReady then hint(nil, "Override hijack non disponibile in questo caricamento"); return end
        S.hijack = not S.hijack
        hint(nil, "Hijack automatico: " .. (S.hijack and "ON" or "OFF"))
    end
    add(m, function() return "Hijack sempre riuscito: " .. (S.hijack and "ON" or "OFF") end,
        "Salta i QTE di hijack. Sinistra/destra cambia ON/OFF.", changeHijack, changeHijack)
end

local function supportModule()
    local ok = pcall(function() import("MrxSupportData"); import("MrxPmc") end)
    return ok and MrxSupportData and MrxSupportData.tSupportData and MrxPmc
end
local function giveSupport(kind, amount, exclude, ctx)
    if not supportModule() then hint(ctx, "Catalogo supporti non disponibile"); return end
    local n = 0
    for key, data in pairs(MrxSupportData.tSupportData) do
        local matches = (kind == "Vehicle" and data.sType ~= "Supply" and data.sType ~= "Airstrike")
            or data.sType == kind
        if matches and key ~= exclude then
            local ok = pcall(MrxPmc.AddSupportQty, key, amount)
            if ok then n = n + 1 end
        end
    end
    hint(ctx, n .. " tipi di supporto riforniti")
end
function X.buildSupportMenu(m)
    add(m, "Tutti gli airstrike (senza nuke)", "Aggiunge una carica per ogni airstrike del catalogo.",
        function(ctx) giveSupport("Airstrike", 1, "nuke", ctx) end)
    add(m, "Tutti i rifornimenti", "Aggiunge una carica per ogni supply del catalogo.",
        function(ctx) giveSupport("Supply", 1, nil, ctx) end)
    add(m, "Tutti i veicoli supporto x25", "Aggiunge 25 cariche per ogni veicolo richiamabile.",
        function(ctx) giveSupport("Vehicle", 25, nil, ctx) end)
    add(m, "Nuke x25", "Aggiunge 25 cariche nuke al supporto.", function(ctx)
        if not supportModule() then hint(ctx, "Supporti non disponibili"); return end
        local ok = pcall(MrxPmc.AddSupportQty, "nuke", 25)
        hint(ctx, ok and "Nuke x25 aggiunte" or "Nuke non disponibile")
    end)
    add(m, "Supporti senza requisiti: ON", "Ignora scorte e requisiti del supporto per la sessione.", function(ctx)
        Ess.Easy.Player.freeSupport(true); hint(ctx, "Supporti liberi ON")
    end)
    add(m, "Supporti senza requisiti: OFF", "Ripristina i requisiti dei supporti.", function(ctx)
        Ess.Easy.Player.freeSupport(false); hint(ctx, "Supporti liberi OFF")
    end)
    add(m, "Tutti i reward", "Dispensa tutti i reward. Puo cambiare la progressione se salvi.", function(ctx)
        ctx:confirm("Tutti i reward possono cambiare la progressione. Continuare?", function()
            Ess.Easy.Player.giveAllRewards(); hint(nil, "Reward assegnati")
        end)
    end)
    add(m, "Tutte le zone d'atterraggio", "Sblocca i viaggi rapidi. Puo cambiare la progressione se salvi.", function(ctx)
        ctx:confirm("Sbloccare tutte le zone d'atterraggio?", function()
            Ess.Easy.Player.unlockFastTravel(); hint(nil, "Zone d'atterraggio sbloccate")
        end)
    end)
end

local rng = Ess.RNG.new()
Ess.Loop.start("ACTExtras.fun", 0.15, function()
    local vehicle = currentVehicle()
    if S.speed and vehicle and Loader and Loader.IsKeyDown and Loader.IsKeyDown(0x10) then
        Ess.Impulse.push(vehicle, { forward = 2.5 })
    end
    if S.hop and vehicle and Loader and Loader.IsKeyDown then
        local down = Loader.IsKeyDown(0x20)
        if down and not S.hopWasDown then Ess.Impulse.push(vehicle, { up = 15, forward = 12 }) end
        S.hopWasDown = down
    else S.hopWasDown = false end
    return true
end)
Ess.Loop.start("ACTExtras.lowrider", 0.4, function()
    local vehicle = currentVehicle()
    if S.lowrider and vehicle then
        S.lowPhase = not S.lowPhase
        Ess.Impulse.push(vehicle, { up = S.lowPhase and 3 or 1.5 })
    end
    return true
end)
Ess.Loop.start("ACTExtras.bombard", 1.5, function()
    if not S.bombard then return true end
    local x, y, z = Ess.Player.pose(0)
    if not x then return true end
    local angle, radius = rng:next() * 360, 55 + rng:next() * 65
    local sx, sz = Ess.Math.pointAhead(x, z, angle, radius)
    Ess.Support.shell(sx, y, sz)
    return true
end)
function X.buildFunMenu(m)
    add(m, "Danza", "Riproduce l'animazione Technoviking.", function(ctx)
        if not Ess.Player.character(0) then hint(ctx, "Giocatore non disponibile"); return end
        Ess.Easy.Fun.dance()
    end)
    add(m, "Lancia il veicolo in aria", "Spinge verso l'alto il veicolo in cui ti trovi.", function(ctx)
        local vehicle = currentVehicle()
        if not vehicle then hint(ctx, "Sali prima su un veicolo"); return end
        Ess.Impulse.push(vehicle, { up = 50, forward = 10 })
    end)
    toggle(m, "Bombardamenti casuali", "Un colpo ogni 1,5 s fra 55 e 120 m da te.", "bombard")
    toggle(m, "Speed boost (Shift)", "Tieni Shift mentre guidi per accelerare.", "speed")
    toggle(m, "Low-rider", "Piccoli impulsi ritmici al veicolo guidato.", "lowrider")
    toggle(m, "Zero-G hop (Spazio)", "Premi Spazio nel veicolo per un salto singolo.", "hop")
end
function X.openNative(ctx)
    local ok, err = pcall(function()
        import("MrxCheatBootstrap")
        if not (_G.Cheat and type(Cheat.DisplayOptions) == "function") then error("menu nativo assente") end
        ctx:close()
        Cheat.DisplayOptions()
    end)
    if not ok then hint(ctx, "Native Dev Menu: " .. tostring(err)) end
end
if Loader and Loader.Printf then Loader.Printf("[ACT] Extras pronto") end

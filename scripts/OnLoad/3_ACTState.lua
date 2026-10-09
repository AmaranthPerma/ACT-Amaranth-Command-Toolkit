-- Il companion usa il log del bridge per conoscere lo stato di ACT.
-- Ess ricrea la UI a ogni caricamento del mondo: azzera lo stato del menu.
if Loader and Loader.Printf then Loader.Printf("[ACT] menu chiuso") end

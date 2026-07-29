--!strict
-- Sauvegarde/chargement des profils joueur. Tolérant aux erreurs (Studio sans API access).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local DataModule = {}

-- Un place non publié a PlaceId == 0 : dans ce cas le DataStore est inaccessible
-- (et Roblox logge un message même sous pcall). On l'évite proprement.
local store: DataStore? = nil
if game.PlaceId ~= 0 then
	local ok = pcall(function()
		store = DataStoreService:GetDataStore(Config.SaveKey)
	end)
	if not ok then
		warn("[BabyFoot] DataStore indisponible — profils en mémoire uniquement.")
	end
else
	warn("[BabyFoot] Place non publié — sauvegarde désactivée (profils en mémoire).")
end

function DataModule.default()
	return {
		money = 0,
		power = 0,
		dumbbell = 1,    -- index dans Config.Dumbbells
		ball = 1,        -- index dans Config.Balls
		valueLevel = 0,  -- niveau valeur des joueurs
		slots = Config.StartingSlots, -- emplacements débloqués sur les bases
		cards = {},      -- collection : { {name = "...", rarity = "commun"}, ... }
		-- Nombre de lancers de dés déjà payés. C'est LUI qui fait monter le prix
		-- des dés, et pas #cards : la collection est plafonnée, donc son compte
		-- cesse de croître et figeait le prix (cf. Config.diceCost).
		rolls = 0,
		rebirths = 0,
		totalEarned = 0, -- pour le classement mondial
		autoShoot = false, -- interrupteur du tir automatique, conservé d'une session à l'autre
	}
end

-- Profils dont la LECTURE a reussi (ou joueurs neufs). Tant qu'un profil n'est
-- pas ici, on refuse de l'ecrire : sans ce garde-fou, un GetAsync en echec
-- (coupure DataStore, quota) laissait un profil par defaut en memoire, que la
-- sauvegarde periodique ecrivait 2 min plus tard PAR-DESSUS la vraie partie.
local loadedOk: { [number]: boolean } = {}

local LOAD_RETRIES = 3

function DataModule.load(userId: number)
	local data = DataModule.default()
	loadedOk[userId] = false

	if not store then
		-- Pas de DataStore du tout (Studio, place non publie) : rien a ecraser.
		loadedOk[userId] = true
		return data
	end

	for attempt = 1, LOAD_RETRIES do
		local success, saved = pcall(function()
			return store:GetAsync("p_" .. userId)
		end)
		if success then
			if type(saved) == "table" then
				for k in DataModule.default() do
					if saved[k] ~= nil then
						data[k] = saved[k]
					end
				end
			end
			-- saved == nil = joueur neuf, c'est une lecture reussie elle aussi.
			loadedOk[userId] = true
			return data
		end
		if attempt < LOAD_RETRIES then
			task.wait(2 * attempt)
		end
	end

	warn(string.format(
		"[BabyFoot] Lecture du profil %d impossible apres %d essais : sauvegarde DESACTIVEE pour cette session (aucune perte de progression).",
		userId, LOAD_RETRIES))
	return data
end

-- Anti « DataStore request was added to queue » : Roblox limite les écritures par
-- clé (~1 toutes les 6 s) et met le surplus en file. On saute donc les sauvegardes
-- trop rapprochées ET celles dont le contenu n'a pas bougé.
local MIN_INTERVAL = 20
local lastSaveAt: { [number]: number } = {}
local lastPayload: { [number]: string } = {}

-- Joueurs dont les donnees ont ete effacees a leur demande (droit a l'oubli).
-- Tant que la session en cours n'est pas terminee, toute ecriture est refusee :
-- sinon la sauvegarde de sortie recreerait immediatement le profil efface.
local erased: { [number]: boolean } = {}

function DataModule.save(userId: number, data, force: boolean?)
	if not store then return end
	if erased[userId] then return end
	-- Profil jamais lu correctement : on n'ecrit pas, on ne detruit rien.
	if not loadedOk[userId] then return end
	local payload = HttpService:JSONEncode(data)
	if lastPayload[userId] == payload then return end
	local now = os.clock()
	if not force and (now - (lastSaveAt[userId] or -math.huge)) < MIN_INTERVAL then
		return
	end
	lastSaveAt[userId] = now
	local ok = pcall(function()
		store:SetAsync("p_" .. userId, data)
	end)
	if ok then
		lastPayload[userId] = payload
	end
end

-- Droit a l'oubli : suppression definitive du profil. Idempotent — effacer une
-- cle absente ne coute qu'une requete et ne provoque pas d'erreur.
function DataModule.erase(userId: number): boolean
	erased[userId] = true
	lastPayload[userId] = nil
	if not store then return true end
	for attempt = 1, 3 do
		local ok = pcall(function()
			store:RemoveAsync("p_" .. userId)
		end)
		if ok then return true end
		task.wait(2 * attempt)
	end
	warn(string.format("[BabyFoot] Effacement du profil %d ECHOUE : a rejouer.", userId))
	return false
end

function DataModule.forget(userId: number)
	lastSaveAt[userId] = nil
	lastPayload[userId] = nil
	loadedOk[userId] = nil
	erased[userId] = nil
end

return DataModule

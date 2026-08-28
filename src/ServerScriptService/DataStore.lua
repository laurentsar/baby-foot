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
		-- NOM D'ÉQUIPE choisi à la première partie. Vide = jamais choisi : le client
		-- ouvre alors l'écran de saisie. Une fois rempli, on ne le redemande plus.
		teamName = "",
		gems = 0,        -- gemmes gagnées aux quêtes (cf. Config.Gems / Config.Quests)
		-- Quêtes déjà créditées : { [id de quête] = true }. Une quête accomplie ne
		-- redonne jamais ses gemmes.
		questsClaimed = {},
		dumbbell = 1,    -- index dans Config.Dumbbells
		ball = 1,        -- index dans Config.Balls
		valueLevel = 0,  -- niveau valeur des joueurs
		goalLevel = 0,   -- niveau « Finisseur » : bonus d'argent sur les buts (cf. Config.GoalBonus)
		goalsScored = 0, -- nombre total de buts marqués depuis le début (panneau d'équipe)
		slots = Config.StartingSlots, -- emplacements débloqués sur les bases
		cards = {},      -- collection : { {name = "...", rarity = "commun"}, ... }
		-- Nombre de lancers de dés déjà payés. C'est LUI qui fait monter le prix
		-- des dés, et pas #cards : la collection est plafonnée, donc son compte
		-- cesse de croître et figeait le prix (cf. Config.diceCost).
		rolls = 0,
		rebirths = 0,
		totalEarned = 0, -- pour le classement mondial
		autoShoot = false, -- interrupteur du tir automatique, conservé d'une session à l'autre
		autoRollOwned = false, -- roulement auto des dés acheté (définitif)
		autoRoll = false,      -- ...et allumé ou non
		luck = 0,        -- niveau de l'amélioration Chance (cf. Config.Luck)
		world = 1,       -- monde débloqué le plus haut (cf. Config.Worlds) — gardé à la renaissance
		worldAt = 1,     -- monde où l'on se trouve (téléportation) : c'est LUI qui donne le multiplicateur
		pets = {},       -- sac à dos : { [clé de pet] = nombre }
		-- Pets équipés : une LISTE de clés, bornée par Config.petSlots(rebirths).
		-- (l'ancien champ `petEquipped`, un seul pet, est repris au chargement)
		petsEquipped = {},
		petEquipped = "",-- conservé pour reprendre les sauvegardes d'avant les places multiples
		-- COMPOSITION D'ÉQUIPE : { [numéro d'emplacement] = id de carte }. Un
		-- emplacement absent est rempli automatiquement par les meilleures cartes.
		lineup = {},
		nextCardId = 1,  -- les cartes portent un id stable, l'index dans la liste bouge
		afk = false,     -- mode AFK : la puissance monte toute seule, plus lentement
		potions = {},    -- sac à dos : { [clé de potion] = nombre }
		effects = {},    -- effets en cours : { [kind] = { mult = n, expires = <os.time> } }
		tutorialDone = false,
		-- Dernière version dont le joueur a vu les nouveautés (cf. Config.Release).
		releaseSeen = "",
		-- Hors ligne : date de dernière déconnexion et rythme de gain observé.
		-- C'est ce couple, et rien d'autre, qui produit le gain hors ligne.
		lastSeen = 0,
		earnPerSec = 0,
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

-- CHAMPS VOLATILS, exclus de la comparaison.
--
-- `lastSeen` et `earnPerSec` sont réécrits avant CHAQUE sauvegarde (ils servent
-- aux gains hors ligne). Résultat : la charge utile changeait à tous les coups,
-- le garde-fou « contenu identique » ne se déclenchait jamais, et l'arrêt du
-- serveur écrivait deux fois la même partie à une seconde d'intervalle — d'où
-- le message « DataStore request was added to queue ».
--
-- Les exclure ne perd rien : si RIEN d'autre n'a bougé, le joueur n'a rien
-- gagné, donc son rythme est nul et son gain hors ligne le sera aussi.
local VOLATILES = { lastSeen = true, earnPerSec = true }

local function empreinte(data): string
	local stable = {}
	for k, v in data do
		if not VOLATILES[k] then
			stable[k] = v
		end
	end
	return HttpService:JSONEncode(stable)
end

-- Joueurs dont les donnees ont ete effacees a leur demande (droit a l'oubli).
-- Tant que la session en cours n'est pas terminee, toute ecriture est refusee :
-- sinon la sauvegarde de sortie recreerait immediatement le profil efface.
local erased: { [number]: boolean } = {}

function DataModule.save(userId: number, data, force: boolean?)
	if not store then return end
	if erased[userId] then return end
	-- Profil jamais lu correctement : on n'ecrit pas, on ne detruit rien.
	if not loadedOk[userId] then return end
	local payload = empreinte(data)
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

-- On garde volontairement `lastSaveAt` et `lastPayload` : ce sont eux qui
-- empêchent une deuxième écriture de la même partie juste après le départ du
-- joueur (PlayerRemoving puis BindToClose écrivent tous les deux, en force).
-- Ils ne coûtent qu'une chaîne par joueur et disparaissent avec le serveur.
function DataModule.forget(userId: number)
	loadedOk[userId] = nil
	erased[userId] = nil
end

return DataModule

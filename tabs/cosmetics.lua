--!nonstrict
local Hub = _G.MinhoHub
if not Hub then return end
local Players           = Hub.Players
local ReplicatedStorage = Hub.ReplicatedStorage
local LocalPlayer       = Hub.LocalPlayer

local CosmeticsWrap = {}
CosmeticsWrap._cache = {}

function CosmeticsWrap._require(key, fn)
local hit = CosmeticsWrap._cache[key]
if hit ~= nil then return hit ~= false and hit or nil end
local ok, value = pcall(fn)
if ok and value ~= nil then
CosmeticsWrap._cache[key] = value
return value
end
return nil
end

function CosmeticsWrap.dataController()
return CosmeticsWrap._require("PlayerDataController", function()
return require(LocalPlayer.PlayerScripts.Controllers.PlayerDataController)
end)
end

function CosmeticsWrap.fighterController()
return CosmeticsWrap._require("FighterController", function()
return require(LocalPlayer.PlayerScripts.Controllers.FighterController)
end)
end

function CosmeticsWrap.localFighter()
local ctrl = CosmeticsWrap.fighterController()
if ctrl == nil then return nil end
return rawget(ctrl, "LocalFighter")
end

function CosmeticsWrap.playerDataUtility()
return CosmeticsWrap._require("PlayerDataUtility", function()
return require(ReplicatedStorage.Modules.PlayerDataUtility)
end)
end

function CosmeticsWrap.enumLibrary()
return CosmeticsWrap._require("EnumLibrary", function()
return require(ReplicatedStorage.Modules.EnumLibrary)
end)
end

function CosmeticsWrap.clientItem()
return CosmeticsWrap._require("ClientItem", function()
local classes = LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses
return require(classes.ClientFighter.ClientItem)
end)
end

function CosmeticsWrap.clientViewModel()
return CosmeticsWrap._require("ClientViewModel", function()
local classes = LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses
return require(classes.ClientFighter.ClientItem.ClientViewModel)
end)
end

function CosmeticsWrap.equipmentModule()
return CosmeticsWrap._require("Equipment", function()
local ui = LocalPlayer.PlayerScripts.Modules.UserInterface
return require(ui.Equipment)
end)
end

function CosmeticsWrap.lobbyModule()
return CosmeticsWrap._require("Lobby", function()
local ui = LocalPlayer.PlayerScripts.Modules.UserInterface
return require(ui.Lobby)
end)
end

function CosmeticsWrap.itemLibrary()
return CosmeticsWrap._require("ItemLibrary", function()
return require(ReplicatedStorage.Modules.ItemLibrary)
end)
end

function CosmeticsWrap.cosmeticLibrary()
return CosmeticsWrap._require("CosmeticLibrary", function()
return require(ReplicatedStorage.Modules.CosmeticLibrary)
end)
end

function CosmeticsWrap.assetsFolder(sub)
local ps = LocalPlayer:FindFirstChild("PlayerScripts")
local assets = ps and ps:FindFirstChild("Assets")
if not assets then return nil end
if sub == nil then return assets end
return assets:FindFirstChild(sub)
end

function CosmeticsWrap.wrapPreviewAsset()
return CosmeticsWrap._require("WrapPreviewAsset", function()
local misc = CosmeticsWrap.assetsFolder("Misc")
if not misc then return nil end
return misc:FindFirstChild("Wrap")
end)
end

function CosmeticsWrap.wrapTextureAssets()
return CosmeticsWrap._require("WrapTextureAssets", function()
return CosmeticsWrap.assetsFolder("WrapTextures")
end)
end

function CosmeticsWrap.charmAssets()
return CosmeticsWrap._require("CharmAssets", function()
return CosmeticsWrap.assetsFolder("Charms")
end)
end

CosmeticsWrap.DataHook = { spoofs = {}, restore = nil, conn = nil, loaded = false, _signalCache = {} }

function CosmeticsWrap.DataHook.load(current)
local hook = CosmeticsWrap.DataHook
local inner = rawget(current, "Data")
if inner == nil then return false end
if hook.restore ~= nil then
if hook.restore.current == current then return true end
CosmeticsWrap.DataHook.revert()
end
local proxy = setmetatable({}, {
__index = function(_, key)
local spoof = hook.spoofs[key]
if spoof ~= nil then return spoof(inner[key]) end
return inner[key]
end,
__newindex = function(_, key, value) inner[key] = value end,
__len = function() return #inner end,
__iter = function() return next, inner end,
})
rawset(current, "Data", proxy)
hook.restore = { current = current, inner = inner }
hook._signalCache = {}
return true
end

function CosmeticsWrap.DataHook._revert()
local hook = CosmeticsWrap.DataHook
local restore = hook.restore
if restore == nil then return end
hook.restore = nil
hook._signalCache = {}
rawset(restore.current, "Data", restore.inner)
end

function CosmeticsWrap.DataHook.initialize()
local hook = CosmeticsWrap.DataHook
if hook.loaded then return true end
local controller = CosmeticsWrap.dataController()
if controller == nil then return false end
local added = rawget(controller, "PlayerDataAdded")
if added ~= nil then
local ok, conn = pcall(function()
return added:Connect(function()
local current = rawget(controller, "CurrentData")
if current ~= nil then hook.load(current) end
end)
end)
if ok then hook.conn = conn end
end
hook.loaded = true
local current = rawget(controller, "CurrentData")
if current ~= nil then return hook.load(current) end
return false
end

function CosmeticsWrap.DataHook.set(field, fn)
CosmeticsWrap.DataHook.spoofs[field] = fn
CosmeticsWrap.DataHook.initialize()
end

function CosmeticsWrap.DataHook.unset(field)
CosmeticsWrap.DataHook.spoofs[field] = nil
end

function CosmeticsWrap.DataHook.getOriginal(field)
local restore = CosmeticsWrap.DataHook.restore
if restore == nil then
local controller = CosmeticsWrap.dataController()
local current = controller ~= nil and rawget(controller, "CurrentData") or nil
local data = current ~= nil and rawget(current, "Data") or nil
return data ~= nil and data[field] or nil
end
return restore.inner[field]
end

function CosmeticsWrap.DataHook._signal(current, field)
local cache = CosmeticsWrap.DataHook._signalCache
local hit = cache[field]
if hit ~= nil then return hit ~= false and hit or nil end
local ok, sig = pcall(function() return current:GetDataChangedSignal(field) end)
if ok and sig ~= nil then
cache[field] = sig
return sig
end
cache[field] = false
return nil
end

function CosmeticsWrap.DataHook.trigger(field)
local hook = CosmeticsWrap.DataHook
local current = hook.restore and hook.restore.current
if current == nil then
local controller = CosmeticsWrap.dataController()
current = controller and rawget(controller, "CurrentData") or nil
end
if current == nil then return end
local sig = CosmeticsWrap.DataHook._signal(current, field)
if sig ~= nil then
pcall(function() sig:Fire(current.Data[field], field) end)
end
end

function CosmeticsWrap.DataHook.destroy()
local hook = CosmeticsWrap.DataHook
local fields = {}
for field in pairs(hook.spoofs) do fields[#fields + 1] = field end
table.clear(hook.spoofs)
hook._revert()
if hook.conn ~= nil then
pcall(function() hook.conn:Disconnect() end)
hook.conn = nil
end
hook.loaded = false
for _, field in ipairs(fields) do hook.trigger(field) end
end

CosmeticsWrap.ItemHook = { ALIAS = "GetWeaponData\0ohaio", restore = nil, _targetFn = nil }

function CosmeticsWrap.ItemHook.target()
if CosmeticsWrap.ItemHook._targetFn ~= nil then
return CosmeticsWrap.ItemHook._targetFn
end
local controller = CosmeticsWrap.dataController()
if controller == nil then return nil end
local mt = getmetatable(controller)
local index = typeof(mt) == "table" and rawget(mt, "__index") or nil
if typeof(index) ~= "table" then return nil end
local fn = rawget(index, "GetWeaponData")
if typeof(fn) == "function" then
CosmeticsWrap.ItemHook._targetFn = fn
return fn
end
return nil
end

function CosmeticsWrap.ItemHook.findOriginal(weaponName)
local inventory = CosmeticsWrap.DataHook.getOriginal("WeaponInventory")
if typeof(inventory) ~= "table" then return nil end
for _, entry in pairs(inventory) do
if typeof(entry) == "table" and entry.Name == weaponName then return entry end
end
return nil
end

function CosmeticsWrap.ItemHook.applyCosmetics(data, selection)
    if selection == nil then return data, false end
    if data == nil then data = {} end
    local changed = false

    for _, kind in ipairs({ "Skin", "Wrap", "Charm", "Finisher" }) do
        local slot = string.lower(kind)
        local value = selection[slot]

        if value == nil then
        elseif value == "NONE_COSMETIC" then
            data[kind] = nil
            changed = true
        elseif type(value) == "table" and value.name == "NONE_COSMETIC" then
            data[kind] = nil
            changed = true
        elseif type(value) == "table" and value.Name == "NONE_COSMETIC" then
            data[kind] = nil
            changed = true
        else
            if kind == "Wrap" then
                local wrapName = type(value) == "table" and value.name or value
                local wrapInv = type(value) == "table" and value.inverted == true or false
                data[kind] = { Name = wrapName, Inverted = wrapInv }
            elseif kind == "Charm" then
                local charmName = type(value) == "table" and (value.Name or value.name) or value
                local charmData = { Name = charmName }
                local rankCharm = CosmeticsWrap.RankCharm
                if rankCharm ~= nil and type(rankCharm.ResolveMetadata) == "function" then
                    local ok, metadata = pcall(function()
                        return rankCharm:ResolveMetadata(charmName)
                    end)
                    if ok and metadata ~= nil then
                        charmData.Metadata = metadata
                    end
                end
                data[kind] = charmData
            else
                local itemName = type(value) == "table" and value.Name or value
                data[kind] = { Name = itemName }
            end
            changed = true
        end
    end

    return data, changed
end

function CosmeticsWrap.ItemHook.getWeaponData(_self, controller, weaponName)
local original = CosmeticsWrap.ItemHook.findOriginal(weaponName)
if original == nil then return nil end
local selection = CosmeticsWrap.selections[weaponName]
if selection == nil then return original end
local patched, changed = CosmeticsWrap.ItemHook.applyCosmetics(
table.clone(original), selection)
if not changed then return original end
patched.Level = original.Level
patched.Prestige = original.Prestige
patched.XP = original.XP
return patched
end

function CosmeticsWrap.ItemHook.load()
if CosmeticsWrap.ItemHook.restore ~= nil then return true end
if debug.getconstants == nil or debug.setconstant == nil then
return false, "executor has no constant access"
end
local fn = CosmeticsWrap.ItemHook.target()
if fn == nil then return false, "GetWeaponData function unavailable" end
local utility = CosmeticsWrap.playerDataUtility()
if utility == nil then return false, "PlayerDataUtility unavailable" end
local ok, constants = pcall(debug.getconstants, fn)
if not ok or typeof(constants) ~= "table" then return false, "constants unreadable" end
for index, value in pairs(constants) do
if value == "GetWeaponData" then
CosmeticsWrap.ItemHook.restore = { fn = fn, index = index, original = value, utility = utility }
pcall(debug.setconstant, fn, index, CosmeticsWrap.ItemHook.ALIAS)
break
end
end
if CosmeticsWrap.ItemHook.restore == nil then
return false, "GetWeaponData constant not found"
end
rawset(utility, CosmeticsWrap.ItemHook.ALIAS, CosmeticsWrap.ItemHook.getWeaponData)
return true
end

function CosmeticsWrap.ItemHook.revert()
local restore = CosmeticsWrap.ItemHook.restore
if restore == nil then return end
CosmeticsWrap.ItemHook.restore = nil
pcall(debug.setconstant, restore.fn, restore.index, restore.original)
if restore.utility ~= nil then
rawset(restore.utility, CosmeticsWrap.ItemHook.ALIAS, nil)
end
end

CosmeticsWrap.Scene = { _equipmentQueued = false, _selectionQueued = false, _objectsCache = nil, _objectsCacheTime = 0 }

function CosmeticsWrap.Scene.thunk(object, methodName)
if object == nil then return nil end
local mt = getmetatable(object)
local index = typeof(mt) == "table" and rawget(mt, "__index") or nil
local method = typeof(index) == "table" and rawget(index, methodName) or nil
if method == nil then method = rawget(object, methodName) end
if typeof(method) ~= "function" then return nil end
return function() coroutine.wrap(method)(object) end
end

function CosmeticsWrap.Scene.run(thunks)
local co = coroutine.create(function()
if getthreadidentity == nil or setthreadidentity == nil then
for _, thunk in ipairs(thunks) do
if thunk ~= nil then pcall(thunk) end
end
return
end
local identity = getthreadidentity()
local raised = pcall(setthreadidentity, 2)
for _, thunk in ipairs(thunks) do
if thunk ~= nil then pcall(thunk) end
end
if raised then pcall(setthreadidentity, identity) end
end)
local ok, err = coroutine.resume(co)
if not ok then warn("[CosmeticsWrap] scene: " .. tostring(err)) end
end

function CosmeticsWrap.Scene.objects()
local now = os.clock()
if CosmeticsWrap.Scene._objectsCache and now - CosmeticsWrap.Scene._objectsCacheTime < 5 then
return CosmeticsWrap.Scene._objectsCache
end
local out = {}
local equipment = CosmeticsWrap.equipmentModule()
if equipment ~= nil then
local interface = rawget(equipment, "Interface")
if typeof(interface) == "table" then
local customize = rawget(interface, "Customize")
out.cosmetics = typeof(customize) == "table" and rawget(customize, "Cosmetics") or nil
out.left = rawget(interface, "Left")
end
out.floatingModel = rawget(equipment, "FloatingModel")
end
local lobby = CosmeticsWrap.lobbyModule()
if lobby ~= nil then
out.buttons = rawget(lobby, "Buttons")
end
if next(out) == nil then return nil end
CosmeticsWrap.Scene._objectsCache = out
CosmeticsWrap.Scene._objectsCacheTime = now
return out
end

function CosmeticsWrap.Scene.encodeKeys(tbl)
local enums = CosmeticsWrap.enumLibrary()
if enums == nil then return tbl end
local out = {}
for key, value in pairs(tbl) do
local ok, encoded = pcall(function() return enums:ToEnum(key) end)
out[(ok and encoded) or key] = value
end
return out
end

function CosmeticsWrap.Scene.buildViewModelData(itemName, selection)
local name = itemName
local skin = selection ~= nil and selection.skin or nil
if skin ~= nil and skin ~= "RANDOM_COSMETIC"
and not string.match(skin, "^NONE_COSMETIC") then
name = skin
end
local record = { Name = name }
local wrap = selection ~= nil and selection.wrap or nil
if wrap ~= nil and wrap.name ~= nil
and not string.match(wrap.name, "^NONE_COSMETIC") then
record.Wrap = { Name = wrap.name, Inverted = wrap.inverted == true }
end
local charm = selection ~= nil and selection.charm or nil
if charm ~= nil and not string.match(charm, "^NONE_COSMETIC") then
local charmData = { Name = charm }
local rankCharm = CosmeticsWrap.RankCharm
if rankCharm ~= nil and type(rankCharm.ResolveMetadata) == "function" then
local ok, metadata = pcall(function()
return rankCharm:ResolveMetadata(charm)
end)
if ok and metadata ~= nil then
charmData.Metadata = metadata
end
end
record.Charm = charmData
end
return CosmeticsWrap.Scene.encodeKeys({ Data = CosmeticsWrap.Scene.encodeKeys(record) })
end

function CosmeticsWrap.Scene.reloadViewModel(item, itemName, selection)
if typeof(item) ~= "table" then return false end
local viewModel = rawget(item, "ViewModel")
if viewModel == nil then return false end
local vmData = rawget(viewModel, "Data")
if vmData == nil then
    local enumLib = CosmeticsWrap.enumLibrary()
    if enumLib ~= nil then
        local okKey, dataKey = pcall(function()
            return enumLib:ToEnum("Data")
        end)
        if okKey and dataKey ~= nil then
            vmData = rawget(viewModel, dataKey)
        end
    end
end
if vmData == nil then return false end

local clientItem = CosmeticsWrap.clientItem()
local clientViewModel = CosmeticsWrap.clientViewModel()
if clientItem == nil or clientViewModel == nil then return false end

local source = CosmeticsWrap.Scene.buildViewModelData(itemName, selection)

local created
CosmeticsWrap.Scene.run({ function()
pcall(function() coroutine.wrap(clientViewModel.Destroy)(viewModel) end)
pcall(function()
created = coroutine.wrap(clientItem._CreateViewModel)(item, source)
end)
if created == nil then
pcall(function()
created = coroutine.wrap(clientItem._CreateViewModel)(item,
CosmeticsWrap.Scene.buildViewModelData(itemName, nil))
end)
if created ~= nil then rawset(item, "ViewModel", created) end
return
end
rawset(item, "ViewModel", created)
local fighter = rawget(item, "ClientFighter") or CosmeticsWrap.localFighter()
if fighter ~= nil then
local mt = getmetatable(fighter)
local index = typeof(mt) == "table" and rawget(mt, "__index") or nil
local getArms = typeof(index) == "table" and rawget(index, "GetArmsData") or nil
if getArms ~= nil then
local arms = table.pack(coroutine.wrap(getArms)(fighter))
pcall(function()
coroutine.wrap(clientViewModel.SetArmsData)(created, table.unpack(arms, 1, arms.n))
end)
end
end
pcall(function() coroutine.wrap(clientViewModel.Equip)(created, true) end)
local spring = rawget(created, "_equip_spring")
if spring ~= nil then
rawset(spring, "_position0", 0)
rawset(spring, "_velocity0", 0)
end
end })
return true
end

function CosmeticsWrap.Scene.reloadAll(itemName, selection)
local fighter = CosmeticsWrap.localFighter()
if fighter == nil then return false end
local items = rawget(fighter, "Items")
if typeof(items) ~= "table" then return false end
local any = false
for _, item in pairs(items) do
if typeof(item) == "table" and rawget(item, "Name") == itemName then
if CosmeticsWrap.Scene.reloadViewModel(item, itemName, selection) then any = true end
end
end
return any
end

function CosmeticsWrap.Scene.reloadEquipped()
local fighter = CosmeticsWrap.localFighter()
if fighter == nil then return end
local items = rawget(fighter, "Items")
if typeof(items) ~= "table" then return end
for _, item in pairs(items) do
if typeof(item) == "table" and rawget(item, "IsEquipped") == true then
local itemName = rawget(item, "Name")
if itemName ~= nil then
local selection = CosmeticsWrap.selections[itemName]
if selection ~= nil then
CosmeticsWrap.Scene.reloadViewModel(item, itemName, selection)
end
end
end
end
end

function CosmeticsWrap.Scene.refreshEquipmentView()
    local objects = CosmeticsWrap.Scene.objects()
    if objects == nil then return end
    CosmeticsWrap.Scene.run({
        CosmeticsWrap.Scene.thunk(objects.cosmetics, "_BulkUpdateEquipped"),
        CosmeticsWrap.Scene.thunk(objects.cosmetics, "OnStateChanged"),
        CosmeticsWrap.Scene.thunk(objects.cosmetics, "_UpdateSelectorGrid"),
        CosmeticsWrap.Scene.thunk(objects.buttons,   "_UpdateButtonInformation"),
        CosmeticsWrap.Scene.thunk(objects.buttons,   "_GenerateDeferred"),
        CosmeticsWrap.Scene.thunk(objects.left,      "_GenerateDeferred"),
        CosmeticsWrap.Scene.thunk(objects.left,      "_GenerateWeaponButtons"),
        CosmeticsWrap.Scene.thunk(objects.floatingModel, "_GenerateViewModel"),
    })
end

CosmeticsWrap.Scene._refreshQueued = false
function CosmeticsWrap.Scene.requestRefresh()
    if CosmeticsWrap.Scene._refreshQueued then return end
    CosmeticsWrap.Scene._refreshQueued = true
    task.defer(function()
        CosmeticsWrap.Scene._refreshQueued = false
        CosmeticsWrap.Scene.refreshEquipmentView()
    end)
end

function CosmeticsWrap.Scene.installViewModelProvider()
    if CosmeticsWrap.Scene._providerInstalled then return end
    CosmeticsWrap.Scene._providerInstalled = true

    local clientItem = CosmeticsWrap.clientItem()
    if clientItem == nil or type(clientItem._CreateViewModel) ~= "function" then
        CosmeticsWrap.Scene._providerInstalled = false
        return
    end

    local originalCreate = clientItem._CreateViewModel
    CosmeticsWrap.Scene._originalCreate = originalCreate

    local function wrappedCreate(self, vmref)
        if CosmeticsWrap.Scene._creatingViewModel then
            return originalCreate(self, vmref)
        end

        local fighter = rawget(self, "ClientFighter")
        local owner = fighter and rawget(fighter, "Player")
        local itemName = rawget(self, "Name")

        if owner == LocalPlayer and itemName ~= nil then
            local selection = CosmeticsWrap.selections[itemName]

            if selection ~= nil then
                local patched = CosmeticsWrap.Scene.buildViewModelData(itemName, selection)
                local enumLib = CosmeticsWrap.enumLibrary()

                if enumLib ~= nil then
                    local okKey, dataKey = pcall(function()
                        return enumLib:ToEnum("Data")
                    end)
                    if okKey and dataKey ~= nil and patched[dataKey] ~= nil then
                        vmref[dataKey] = patched[dataKey]
                    end
                end

                if vmref.Data == nil and patched.Data ~= nil then
                    vmref.Data = patched.Data                end
            end
        end

        CosmeticsWrap.Scene._creatingViewModel = true
        local ok, result = pcall(originalCreate, self, vmref)
        CosmeticsWrap.Scene._creatingViewModel = false

        if ok then
            return result
        end
        error(result)
    end

    if newcclosure then
        local ok, wrapped = pcall(newcclosure, wrappedCreate)
        if ok and wrapped then wrappedCreate = wrapped end
    end

    clientItem._CreateViewModel = wrappedCreate
end

function CosmeticsWrap.Scene.uninstallViewModelProvider()
    if not CosmeticsWrap.Scene._providerInstalled then return end
    local clientItem = CosmeticsWrap.clientItem()
    if clientItem ~= nil and CosmeticsWrap.Scene._originalCreate ~= nil then
        clientItem._CreateViewModel = CosmeticsWrap.Scene._originalCreate
    end
    CosmeticsWrap.Scene._originalCreate = nil
    CosmeticsWrap.Scene._providerInstalled = false
end

function CosmeticsWrap.Scene.installIconProvider()
    if CosmeticsWrap.Scene._iconInstalled then return end
    local ilib = CosmeticsWrap.itemLibrary()
    if ilib == nil or type(ilib.GetViewModelImageFromWeaponData) ~= "function" then
        return
    end
    CosmeticsWrap.Scene._iconInstalled = true
    local original = ilib.GetViewModelImageFromWeaponData
    CosmeticsWrap.Scene._originalIcon = original

    local function wrappedIcon(self, weaponData, hires)
        if type(weaponData) == "table" then
            local weaponName = weaponData.Name
            local selection = weaponName and CosmeticsWrap.selections[weaponName]
            local skin = selection and selection.skin
            if skin ~= nil and skin ~= "RANDOM_COSMETIC"
                and not string.match(skin, "^NONE_COSMETIC") then
                local viewModels = self.ViewModels
                local info = viewModels and viewModels[skin]
                if info ~= nil then
                    if hires then
                        return info.ImageHighResolution or info.Image or ""
                    end
                    return info.Image or ""
                end
            end
        end
        return original(self, weaponData, hires)
    end

    if newcclosure then
        local ok, wrapped = pcall(newcclosure, wrappedIcon)
        if ok and wrapped then wrappedIcon = wrapped end
    end

    ilib.GetViewModelImageFromWeaponData = wrappedIcon
end

function CosmeticsWrap.Scene.uninstallIconProvider()
    if not CosmeticsWrap.Scene._iconInstalled then return end
    local ilib = CosmeticsWrap.itemLibrary()
    if ilib ~= nil and CosmeticsWrap.Scene._originalIcon ~= nil then
        ilib.GetViewModelImageFromWeaponData = CosmeticsWrap.Scene._originalIcon
    end
    CosmeticsWrap.Scene._originalIcon = nil
    CosmeticsWrap.Scene._iconInstalled = false
end

CosmeticsWrap.selections = {}
CosmeticsWrap._enabled = false

CosmeticsWrap.Rank = CosmeticsWrap.Rank or {
    RANKS = {},
    RANK_NAMES = {},
    SEASON_CHARMS = {},
    SEASON_CHARM_NAMES = {},
}

CosmeticsWrap.RankCharm = CosmeticsWrap.RankCharm or { _overrides = {} }

function CosmeticsWrap.Rank.isSeasonRankCharm(name)
    return typeof(name) == "string"
        and string.match(name, "^Season %d+$") ~= nil
end

function CosmeticsWrap.Rank.buildMetadata(rankName, leaderboardRank)
    local rank = CosmeticsWrap.Rank.RANKS[rankName]
    if rank == nil then return nil end
    if rank.name == "Unranked" then
        return { SeasonELO = nil, SeasonLeaderboardRank = leaderboardRank }
    end
    if rank.requiresLeaderboard and (leaderboardRank == nil) then
        leaderboardRank = 1
    end
    return { SeasonELO = rank.requiredELO, SeasonLeaderboardRank = leaderboardRank }
end

function CosmeticsWrap.RankCharm:SetForSeason(charmName, rankName, leaderboardRank)
    if rankName ~= nil and CosmeticsWrap.Rank.RANKS[rankName] == nil then
        local loader = rawget(CosmeticsWrap, "_loadRankProfile")
        if type(loader) == "function" then pcall(loader) end
    end
    if rankName ~= nil and CosmeticsWrap.Rank.RANKS[rankName] == nil then
        rankName = nil
    end
    if rankName == nil then
        self._overrides[charmName] = nil
        return
    end
    self._overrides[charmName] = { rankName = rankName, leaderboardRank = leaderboardRank }
end

function CosmeticsWrap.RankCharm:GetForSeason(charmName)
    local entry = self._overrides[charmName]
    if entry == nil then return nil, nil end
    return entry.rankName, entry.leaderboardRank
end

function CosmeticsWrap.RankCharm:ResolveMetadata(charmName)
    if not CosmeticsWrap.Rank.isSeasonRankCharm(charmName) then return nil end
    local entry = self._overrides[charmName]
    if entry == nil then return nil end
    local metadata = CosmeticsWrap.Rank.buildMetadata(entry.rankName, entry.leaderboardRank)
    if metadata ~= nil then return metadata end
    local loader = rawget(CosmeticsWrap, "_loadRankProfile")
    if type(loader) == "function" then pcall(loader) end
    return CosmeticsWrap.Rank.buildMetadata(entry.rankName, entry.leaderboardRank)
end

local function loadRankProfile()
    CosmeticsWrap.Rank.RANKS = CosmeticsWrap.Rank.RANKS or {}
    CosmeticsWrap.Rank.RANK_NAMES = CosmeticsWrap.Rank.RANK_NAMES or {}
    CosmeticsWrap.Rank.SEASON_CHARMS = CosmeticsWrap.Rank.SEASON_CHARMS or {}
    CosmeticsWrap.Rank.SEASON_CHARM_NAMES = CosmeticsWrap.Rank.SEASON_CHARM_NAMES or {}

    local modules = ReplicatedStorage:FindFirstChild("Modules")
    local seasonLibModule = modules and modules:FindFirstChild("SeasonLibrary")

    local season
    if seasonLibModule then
        local ok, result = pcall(require, seasonLibModule)
        if ok and type(result) == "table" then
            season = result
        end
    end

    local profile = season and season.CurrentSeason and season.CurrentSeason.RankProfile

    if type(profile) == "table" then
        local ranks = profile.Ranks or {}
        local order = profile.RanksOrder or {}
        for _, rankName in ipairs(order) do
            local rank = ranks[rankName]
            if type(rank) == "table" then
                CosmeticsWrap.Rank.RANKS[rankName] = {
                    name = rankName,
                    requiredELO = rank.RequiredELO,
                    requiresLeaderboard = rank.RequiredELOLeaderboardRanking ~= nil,
                }
                local exists = false
                for _, existing in ipairs(CosmeticsWrap.Rank.RANK_NAMES) do
                    if existing == rankName then exists = true break end
                end
                if not exists then
                    table.insert(CosmeticsWrap.Rank.RANK_NAMES, rankName)
                end
            end
        end
    end

    local byVersion = season and season.SeasonsByVersion or {}
    local versions = {}
    if type(byVersion) == "table" then
        for version in pairs(byVersion) do table.insert(versions, version) end
    end
    table.sort(versions, function(a, b) return tostring(a) < tostring(b) end)

    for _, version in ipairs(versions) do
        local charmName = "Season " .. tostring(version)
        local exists = false
        for _, existing in ipairs(CosmeticsWrap.Rank.SEASON_CHARM_NAMES) do
            if existing == charmName then exists = true break end
        end
        if not exists then
            local info = byVersion[version]
            table.insert(CosmeticsWrap.Rank.SEASON_CHARMS, {
                charmName = charmName,
                version = version,
                seasonName = type(info) == "table" and info.Name or tostring(version),
            })
            table.insert(CosmeticsWrap.Rank.SEASON_CHARM_NAMES, charmName)
        end
    end

    if next(CosmeticsWrap.Rank.RANKS) == nil then
        CosmeticsWrap.Rank.RANKS = {
            ["Unranked"] = { name = "Unranked", requiredELO = nil, requiresLeaderboard = false },
            ["Bronze"]   = { name = "Bronze",   requiredELO = 0,   requiresLeaderboard = false },
            ["Silver"]   = { name = "Silver",   requiredELO = 100, requiresLeaderboard = false },
            ["Gold"]     = { name = "Gold",     requiredELO = 200, requiresLeaderboard = false },
            ["Platinum"] = { name = "Platinum", requiredELO = 300, requiresLeaderboard = false },
        }
        CosmeticsWrap.Rank.RANK_NAMES = { "Unranked", "Bronze", "Silver", "Gold", "Platinum" }
    end
end

CosmeticsWrap._loadRankProfile = loadRankProfile
loadRankProfile()

function CosmeticsWrap.enable()
    if CosmeticsWrap._enabled then return true end
    CosmeticsWrap.DataHook.initialize()
    CosmeticsWrap.Scene.installViewModelProvider()
    CosmeticsWrap.Scene.installIconProvider()
    local ok, err = CosmeticsWrap.ItemHook.load()
    if not ok then
        warn("[CosmeticsWrap] ItemHook load failed: " .. tostring(err))
        return false
    end
    CosmeticsWrap._enabled = true
    return true
end

function CosmeticsWrap.disable()
    if not CosmeticsWrap._enabled then return true end
    CosmeticsWrap.Scene.uninstallIconProvider()
    CosmeticsWrap.Scene.uninstallViewModelProvider()
    CosmeticsWrap.ItemHook.revert()
    CosmeticsWrap.DataHook.destroy()
    CosmeticsWrap._enabled = false
    return true
end

CosmeticsWrap._reloadQueued = false
function CosmeticsWrap._queueReload(weaponName, selection)
if CosmeticsWrap._reloadQueued then return end
CosmeticsWrap._reloadQueued = true
task.defer(function()
CosmeticsWrap._reloadQueued = false
CosmeticsWrap.Scene.reloadAll(weaponName, selection)
CosmeticsWrap.Scene.reloadEquipped()
end)
end

function CosmeticsWrap.set(weaponName, selection)
    CosmeticsWrap.selections[weaponName] = selection
    CosmeticsWrap.DataHook.trigger("WeaponInventory")
    CosmeticsWrap.DataHook.trigger("CosmeticInventory")
    CosmeticsWrap._queueReload(weaponName, selection)
    CosmeticsWrap.Scene.requestRefresh()
end

function CosmeticsWrap.clear(weaponName)
    CosmeticsWrap.selections[weaponName] = nil
    CosmeticsWrap.DataHook.trigger("WeaponInventory")
    CosmeticsWrap.DataHook.trigger("CosmeticInventory")
    CosmeticsWrap._queueReload(weaponName, nil)
    CosmeticsWrap.Scene.requestRefresh()
end

function CosmeticsWrap.applyAll()
for weaponName, selection in pairs(CosmeticsWrap.selections) do
CosmeticsWrap.Scene.reloadAll(weaponName, selection)
end
CosmeticsWrap.Scene.reloadEquipped()
CosmeticsWrap.Scene.requestRefresh()
end

_G.CosmeticsWrap = CosmeticsWrap
Hub.CosmeticsWrap = CosmeticsWrap

local _cosmeticsEnabled = CosmeticsWrap.enable()
if not _cosmeticsEnabled then
    warn("[loader] CosmeticsWrap init failed - Cosmetics tab limited.")
end

if LocalPlayer.CharacterAdded then
LocalPlayer.CharacterAdded:Connect(function()
task.wait(1.5)
CosmeticsWrap.applyAll()
end)
end

local Cosmetics = Hub.Tabs.Cosmetics
local RageConfig = Hub.RageConfig or {}

local SeasonCharmOverrideBox = Cosmetics:AddGroupbox({ Name = "Season Charm Override", Side = 2 })

local SeasonCharmNames = { "None" }
for _, n in ipairs(CosmeticsWrap.Rank.SEASON_CHARM_NAMES or {}) do
    table.insert(SeasonCharmNames, n)
end
local SeasonRankNames = CosmeticsWrap.Rank.RANK_NAMES or {}

local SeasonCharmDrop, SeasonRankDrop, SeasonLeaderboardRank

local function applySeasonCharm()
    local charmName = SeasonCharmDrop and SeasonCharmDrop.Value
    local rankName = SeasonRankDrop and SeasonRankDrop.Value
    local rawPlace = (SeasonLeaderboardRank and SeasonLeaderboardRank.Value) or ""
    local place = tonumber(string.match(tostring(rawPlace), "^%s*(.-)%s*$"))
    if place ~= nil then
        place = math.floor(place)
        if place < 1 then place = nil end
    end

    if charmName == nil or charmName == "None" then
        for _, name in ipairs(CosmeticsWrap.Rank.SEASON_CHARM_NAMES or {}) do
            pcall(function()
                CosmeticsWrap.RankCharm:SetForSeason(name, nil, nil)
            end)
        end
        for weapon, selection in pairs(CosmeticsWrap.selections) do
            if selection ~= nil and selection.charm ~= nil then
                CosmeticsWrap.Scene.reloadAll(weapon, selection)
            end
        end
        CosmeticsWrap.Scene.requestRefresh()
        return
    end

    if rankName ~= nil
        and CosmeticsWrap.RankCharm ~= nil
        and type(CosmeticsWrap.RankCharm.SetForSeason) == "function" then
        local ok = pcall(function()
            CosmeticsWrap.RankCharm:SetForSeason(charmName, rankName, place)
        end)
        if ok then
            for weapon, selection in pairs(CosmeticsWrap.selections) do
                if selection ~= nil and selection.charm == charmName then
                    CosmeticsWrap.Scene.reloadAll(weapon, selection)
                end
            end
            CosmeticsWrap.Scene.requestRefresh()
        end
    end
end

SeasonCharmDrop = SeasonCharmOverrideBox:AddDropdown("SeasonCharmOverride", {
    Text = "Season Charm", Values = SeasonCharmNames, Multi = false,
    Callback = function() applySeasonCharm() end,
})

SeasonRankDrop = SeasonCharmOverrideBox:AddDropdown("SeasonRankOverride", {
    Text = "Rank", Values = SeasonRankNames, Multi = false,
    Callback = function() applySeasonCharm() end,
})

SeasonLeaderboardRank = SeasonCharmOverrideBox:AddInput("SeasonLeaderboardRank", {
    Text = "Leaderboard Rank",
    Default = "",
    Placeholder = "ex: 1",
    Callback = function() applySeasonCharm() end,
})

task.spawn(function()
    for _ = 1, 5 do
        task.wait(0.5)
        if SeasonCharmDrop ~= nil and type(SeasonCharmDrop.SetValues) == "function" then
            pcall(function()
                local names = { "None" }
                for _, n in ipairs(CosmeticsWrap.Rank.SEASON_CHARM_NAMES or {}) do
                    table.insert(names, n)
                end
                SeasonCharmDrop:SetValues(names)
            end)
        end
        if SeasonRankDrop ~= nil and type(SeasonRankDrop.SetValues) == "function" then
            pcall(function()
                SeasonRankDrop:SetValues(CosmeticsWrap.Rank.RANK_NAMES or {})
            end)
        end
        if #(CosmeticsWrap.Rank.SEASON_CHARM_NAMES or {}) > 0
            and #(CosmeticsWrap.Rank.RANK_NAMES or {}) > 0 then
            break
        end
    end
end)

local Group = Cosmetics:AddGroupbox({ Name = "Rivals Cosmetics", Side = 1 })
local NONE_LABEL = "None"

local function collectData()
local byClass = {}
local modules = ReplicatedStorage:FindFirstChild("Modules")
local itemModule = modules and modules:FindFirstChild("ItemLibrary")
local cosModule = modules and modules:FindFirstChild("CosmeticLibrary")
if not itemModule or not cosModule then return byClass end

local okI, itemLib = pcall(require, itemModule)
local okC, cosLib = pcall(require, cosModule)
if not okI or not okC then return byClass end

local weaponClass = {}
for name, data in pairs(itemLib.Items or {}) do
if type(data) == "table" and data.Class then
weaponClass[name] = data.Class
end
end

local function extractVisual(data, name)
if type(data) ~= "table" then return nil end
local image = data.Image
if type(image) == "string" and image ~= "" then
return { kind = "image", value = image }
end
if type(data.ImageHighResolution) == "string" and data.ImageHighResolution ~= "" then
return { kind = "image", value = data.ImageHighResolution }
end
if data.Type == "Wrap" then
return { kind = "wrap3d", value = name }
end
if data.Type == "Charm" then
return { kind = "charm3d", charmName = name }
end
return { kind = "named", value = name }
end

local function addEntry(kind, name, visual, weapon)
if not visual then return end
local targetWeapon = (kind == "Skin") and weapon or "All"
if not targetWeapon then return end
local class = (kind == "Skin")
and (weaponClass[targetWeapon] or "Other")
or "All"
byClass[class] = byClass[class] or {}
byClass[class][targetWeapon] = byClass[class][targetWeapon] or {}
byClass[class][targetWeapon][kind] = byClass[class][targetWeapon][kind] or {}
table.insert(byClass[class][targetWeapon][kind], {
name = name, visual = visual, kind = kind,
})
end

for name, data in pairs(cosLib.Cosmetics or {}) do
if type(data) == "table" and data.Type and data.Type ~= "Reward"
and data.Type ~= "Emote" then
local visual = extractVisual(data, name)
if visual then addEntry(data.Type, name, visual, data.ItemName) end
end
end

for _, weaponMap in pairs(byClass) do
for _, kindMap in pairs(weaponMap) do
for _, list in pairs(kindMap) do
table.sort(list, function(a, b) return a.name < b.name end)
end
end
end

return byClass
end

local function toAsset(id)
if type(id) == "number" then return "rbxassetid://" .. id
elseif type(id) == "string" then
if id:match("^rbxassetid://") or id:match("^rbxasset://") then return id
elseif id:match("^%d+$") then return "rbxassetid://" .. id
end
return id
end
return nil
end

local byClass = collectData()
local CLASS_ORDER = { "Primary", "Secondary", "Melee", "Utility" }
local classNames = {}
for class in pairs(byClass) do
if class ~= "All" then table.insert(classNames, class) end
end
table.sort(classNames, function(a, b)
local ai = table.find(CLASS_ORDER, a) or 999
local bi = table.find(CLASS_ORDER, b) or 999
if ai ~= bi then return ai < bi end
return a < b
end)

if #classNames == 0 then
    Group:AddLabel("No cosmetic data found.")
    return true
end

local KINDS = { "Skin", "Wrap", "Charm", "Finisher" }

local function weaponsOfClass(class)
local names = {}
if byClass[class] then
for weapon in pairs(byClass[class]) do table.insert(names, weapon) end
end
table.sort(names)
return names
end

local function kindsOfWeapon(class, weapon)
local kinds = {}
if byClass[class] and byClass[class][weapon] then
for kind in pairs(byClass[class][weapon]) do kinds[kind] = true end
end
if byClass["All"] and byClass["All"]["All"] then
for kind in pairs(byClass["All"]["All"]) do kinds[kind] = true end
end
local out = {}
for kind in pairs(kinds) do table.insert(out, kind) end
table.sort(out, function(a, b)
local ai = table.find(KINDS, a) or 999
local bi = table.find(KINDS, b) or 999
return ai < bi
end)
return out
end

local function cosmeticsOf(class, weapon, kind)
local names = { NONE_LABEL }
if byClass[class] and byClass[class][weapon] and byClass[class][weapon][kind] then
for _, entry in ipairs(byClass[class][weapon][kind]) do
table.insert(names, entry.name)
end
end
if byClass["All"] and byClass["All"]["All"] and byClass["All"]["All"][kind] then
for _, entry in ipairs(byClass["All"]["All"][kind]) do
table.insert(names, entry.name)
end
end
return names
end

local function entryByName(class, weapon, kind, name)
if name == NONE_LABEL then return nil end
if byClass[class] and byClass[class][weapon] and byClass[class][weapon][kind] then
for _, entry in ipairs(byClass[class][weapon][kind]) do
if entry.name == name then return entry end
end
end
if byClass["All"] and byClass["All"]["All"] and byClass["All"]["All"][kind] then
for _, entry in ipairs(byClass["All"]["All"][kind]) do
if entry.name == name then return entry end
end
end
return nil
end

local function weaponImageOf(class, weapon)
if not byClass[class] or not byClass[class][weapon] then return nil end
local skinList = byClass[class][weapon]["Skin"]
if not skinList or #skinList == 0 then return nil end
local first = skinList[1]
if first.visual and first.visual.kind == "image" then
return first.visual.value
end
return nil
end

local ClassDropdown, WeaponDropdown, KindDropdown, CosmeticDropdown
local ViewerImage, InfoLabel
local updateVisual

local function showImage(asset)
if not ViewerImage then return end
ViewerImage:SetImage(asset or "rbxassetid://0")
end

local function setViewerImageVisible(on)
if not ViewerImage then return end
if ViewerImage.SetVisible then
ViewerImage:SetVisible(on)
elseif ViewerImage.Holder then
ViewerImage.Holder.Visible = on
elseif ViewerImage.ImageLabel then
ViewerImage.ImageLabel.Visible = on
end
end

ViewerImage = Group:AddImage("ViewerImage", {
Image = "rbxassetid://0",
Height = 220,
ScaleType = Enum.ScaleType.Fit,
Color = Color3.new(1, 1, 1),
})

local CharmViewport = Instance.new("ViewportFrame")
CharmViewport.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
CharmViewport.BorderSizePixel = 0
CharmViewport.Size = UDim2.new(1, 0, 0, 180)
CharmViewport.Visible = false
CharmViewport.Active = false
CharmViewport.Parent = Group.Container

local charmCorner = Instance.new("UICorner")
charmCorner.CornerRadius = UDim.new(0, 6)
charmCorner.Parent = CharmViewport

local charmWorld = Instance.new("WorldModel")
charmWorld.Parent = CharmViewport

local charmCamera = Instance.new("Camera")
charmCamera.FieldOfView = 40
charmCamera.Parent = CharmViewport
CharmViewport.CurrentCamera = charmCamera
charmCamera.CFrame = CFrame.new(0, 0, 2.4)

local charmModel = nil
local charmSpin = 0
local charmAutoRotate = true
local charmRotateSpeed = 0.02

local function loadCharmModel(name)
local charmAssets = CosmeticsWrap.charmAssets()
if not charmAssets then return nil end
local source = charmAssets:FindFirstChild(name)
if not source then
for _, child in ipairs(charmAssets:GetChildren()) do
if string.find(string.lower(child.Name), string.lower(name), 1, true) then
source = child
break
end
end
end
if not source then return nil end

local clone = source:Clone()
local hook = clone:FindFirstChild("Hook", true)
if hook then hook:Destroy() end

local cf, size = clone:GetBoundingBox()
local maxDim = math.max(size.X, size.Y, size.Z, 0.001)
local scale = (1 / maxDim) * 1.6
local ok = pcall(function() clone:ScaleTo(scale) end)
if not ok then
for _, part in ipairs(clone:GetDescendants()) do
if part:IsA("BasePart") then
part.Size = part.Size * scale
end
end
end

local newCf = clone:GetBoundingBox()
clone:PivotTo(CFrame.new(-newCf.Position))
return clone
end

task.spawn(function()
while task.wait() do
if CharmViewport.Visible and charmModel and charmAutoRotate then
charmSpin = charmSpin + charmRotateSpeed
charmModel:PivotTo(CFrame.Angles(0, charmSpin, 0))
end
end
end)

local WrapViewport = Instance.new("ViewportFrame")
WrapViewport.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
WrapViewport.BorderSizePixel = 0
WrapViewport.Size = UDim2.new(1, 0, 0, 180)
WrapViewport.Visible = false
WrapViewport.Active = false
WrapViewport.Parent = Group.Container

local wrapVpCorner = Instance.new("UICorner")
wrapVpCorner.CornerRadius = UDim.new(0, 6)
wrapVpCorner.Parent = WrapViewport

local wrapVpWorld = Instance.new("WorldModel")
wrapVpWorld.Parent = WrapViewport

local wrapVpCamera = Instance.new("Camera")
wrapVpCamera.FieldOfView = 40
wrapVpCamera.Parent = WrapViewport
WrapViewport.CurrentCamera = wrapVpCamera
wrapVpCamera.CFrame = CFrame.new(0, 0, 2.4)

local wrapModel = nil
local wrapSpin = 0
local wrapAutoRotate = true
local wrapRotateSpeed = 0.02

local function applyWrapGroups(model, groups)
if not model or not groups then return end
local wrapTextureAssets = CosmeticsWrap.wrapTextureAssets()
for _, obj in ipairs(model:GetDescendants()) do
if obj:IsA("BasePart") then
local wrapGroup = obj:GetAttribute("WrapGroup")
local group = groups[wrapGroup] or groups[1] or {}
if typeof(group.Color) == "Color3" then obj.Color = group.Color end
if group.Transparency ~= nil then obj.Transparency = group.Transparency end
if group.Reflectance ~= nil then obj.Reflectance = group.Reflectance end
if group.Material then obj.Material = group.Material end
pcall(function()
obj.MaterialVariant = group.MaterialVariant or ""
end)
if obj:IsA("MeshPart") then
pcall(function()
obj.TextureID = ""
end)
end
if group.Textures and wrapTextureAssets then
local folder = wrapTextureAssets:FindFirstChild(group.Textures)
if folder then
for _, texture in ipairs(folder:GetChildren()) do
pcall(function()
local clonedTexture = texture:Clone()
if clonedTexture.LocalTransparencyModifier ~= nil then
clonedTexture.LocalTransparencyModifier = obj.LocalTransparencyModifier
end
clonedTexture.Parent = obj
end)
end
end
end
end
end
end

local function makeFallbackWrap(groups)
local model = Instance.new("Model")
model.Name = "WrapPreview"
local sliceCount = math.max(1, math.min(3, #groups))
for i = 1, sliceCount do
local group = groups[i]
local color = group and group.Color or Color3.fromRGB(150, 150, 150)
if typeof(color) ~= "Color3" then color = Color3.fromRGB(150, 150, 150) end
local slice = Instance.new("Part")
slice.Anchored = true
slice.CanCollide = false
slice.Material = (group and group.Material) or Enum.Material.SmoothPlastic
slice.Color = color
slice.Transparency = group and group.Transparency or 0
slice.Reflectance = group and group.Reflectance or 0
slice.Size = Vector3.new(1.8 / sliceCount, 1.55, 0.22)
slice.CFrame = CFrame.new((i - (sliceCount + 1) / 2) * (1.8 / sliceCount), 0, 0)
slice.Parent = model
end
return model
end

local function loadWrapModel(name)
local cosLib = CosmeticsWrap.cosmeticLibrary()
if not cosLib then return nil end
local data = cosLib.Cosmetics and cosLib.Cosmetics[name]
if not data then return nil end
local groups = data.WrapGroups
if not groups then return nil end

local model = nil
local wrapPreviewAsset = CosmeticsWrap.wrapPreviewAsset()
if wrapPreviewAsset then
local ok, cloned = pcall(function() return wrapPreviewAsset:Clone() end)
if ok and cloned then
model = cloned
end
end

if not model then
model = makeFallbackWrap(groups)
end

applyWrapGroups(model, groups)

for _, obj in ipairs(model:GetDescendants()) do
if obj:IsA("BasePart") then
obj.Anchored = true
obj.CanCollide = false
end
end

local _, size = model:GetBoundingBox()
local scale = math.max(size.X, size.Y, size.Z, 0.001)
model:PivotTo(CFrame.new(0, 0, 0))
wrapVpCamera.CFrame = CFrame.new(0, 0, math.clamp(scale * 0.95, 1.6, 3.2))

return model
end

task.spawn(function()
while task.wait() do
if WrapViewport.Visible and wrapModel and wrapAutoRotate then
wrapSpin = wrapSpin + wrapRotateSpeed
wrapModel:PivotTo(CFrame.Angles(0, wrapSpin, 0))
end
end
end)

InfoLabel = Group:AddLabel({ Text = "" })
InfoLabel.TextLabel.Visible = false

updateVisual = function(class, weapon, kind, name)
CharmViewport.Visible = false
WrapViewport.Visible = false
InfoLabel.TextLabel.Visible = false
for _, c in ipairs(charmWorld:GetChildren()) do c:Destroy() end
for _, c in ipairs(wrapVpWorld:GetChildren()) do c:Destroy() end
charmModel = nil
wrapModel = nil

if name == NONE_LABEL or name == nil then
setViewerImageVisible(true)
local weaponImg = weaponImageOf(class, weapon)
showImage(weaponImg and toAsset(weaponImg) or "rbxassetid://0")
return
end

local entry = entryByName(class, weapon, kind, name)
if not entry or not entry.visual then return end

local v = entry.visual

if v.kind == "image" then
setViewerImageVisible(true)
showImage(toAsset(v.value))

elseif v.kind == "wrap3d" then
setViewerImageVisible(false)
local model = loadWrapModel(v.value)
if model then
model.Parent = wrapVpWorld
wrapModel = model
wrapSpin = 0
wrapAutoRotate = true
WrapViewport.Visible = true
else
InfoLabel:Set("Wrap: " .. tostring(v.value))
InfoLabel.TextLabel.Visible = true
end

elseif v.kind == "charm3d" then
setViewerImageVisible(false)
local model = loadCharmModel(v.charmName)
if model then
model.Parent = charmWorld
charmModel = model
charmSpin = 0
charmAutoRotate = true
CharmViewport.Visible = true
else
InfoLabel:Set("Charm: " .. v.charmName .. "\n(no 3D model)")
InfoLabel.TextLabel.Visible = true
end

elseif v.kind == "named" then
setViewerImageVisible(true)
local weaponImg = weaponImageOf(class, weapon)
showImage(weaponImg and toAsset(weaponImg) or "rbxassetid://0")
InfoLabel:Set(tostring(kind) .. ": " .. tostring(v.value))
InfoLabel.TextLabel.Visible = true
end
end

ClassDropdown = Group:AddDropdown("ClassSelect", {
Text = "Weapon Type", Values = classNames, Default = classNames[1],
Multi = false, Searchable = true,
Callback = function(class)
local weapons = weaponsOfClass(class)
if WeaponDropdown then WeaponDropdown:SetValues(weapons) end
if weapons[1] then
local kinds = kindsOfWeapon(class, weapons[1])
if KindDropdown then KindDropdown:SetValues(kinds) end
if kinds[1] then
local list = cosmeticsOf(class, weapons[1], kinds[1])
if CosmeticDropdown then
CosmeticDropdown:SetValues(list)
CosmeticDropdown:SetValue(NONE_LABEL)
end
updateVisual(class, weapons[1], kinds[1], NONE_LABEL)
end
end
end,
})

WeaponDropdown = Group:AddDropdown("WeaponSelect", {
Text = "Weapon",
Values = weaponsOfClass(classNames[1]),
Default = weaponsOfClass(classNames[1])[1],
Multi = false, Searchable = true,
Callback = function(weapon)
local class = ClassDropdown.Value
local kinds = kindsOfWeapon(class, weapon)
if KindDropdown then KindDropdown:SetValues(kinds) end
if kinds[1] then
local list = cosmeticsOf(class, weapon, kinds[1])
if CosmeticDropdown then
CosmeticDropdown:SetValues(list)
CosmeticDropdown:SetValue(NONE_LABEL)
end
updateVisual(class, weapon, kinds[1], NONE_LABEL)
end
end,
})

KindDropdown = Group:AddDropdown("KindSelect", {
Text = "Cosmetics",
Values = kindsOfWeapon(classNames[1], weaponsOfClass(classNames[1])[1]),
Default = kindsOfWeapon(classNames[1], weaponsOfClass(classNames[1])[1])[1],
Multi = false, Searchable = true,
Callback = function(kind)
local class = ClassDropdown.Value
local weapon = WeaponDropdown.Value
local list = cosmeticsOf(class, weapon, kind)
if CosmeticDropdown then
CosmeticDropdown:SetValues(list)
CosmeticDropdown:SetValue(NONE_LABEL)
end
updateVisual(class, weapon, kind, NONE_LABEL)
end,
})

CosmeticDropdown = Group:AddDropdown("CosmeticSelect", {
Text = "Skin",
Values = cosmeticsOf(classNames[1], weaponsOfClass(classNames[1])[1],
kindsOfWeapon(classNames[1], weaponsOfClass(classNames[1])[1])[1]),
Default = NONE_LABEL,
Multi = false, Searchable = true,
Callback = function(name)
local class = ClassDropdown.Value
local weapon = WeaponDropdown.Value
local kind = KindDropdown.Value
updateVisual(class, weapon, kind, name)
end,
})

Group:AddButton("Apply", function()
local weapon = WeaponDropdown.Value
local kind = KindDropdown.Value
local name = CosmeticDropdown.Value
if not weapon or weapon == "All" then return end
local selection = CosmeticsWrap.selections[weapon] or {}
local slot = string.lower(kind)
if name == NONE_LABEL or name == nil then
selection[slot] = nil
else
if kind == "Wrap" then
selection.wrap = { name = name, inverted = false }
else
selection[slot] = name
end
end
if next(selection) == nil then
CosmeticsWrap.clear(weapon)
else
CosmeticsWrap.set(weapon, selection)
end
end)

Group:AddButton("Apply To All Weapons", function()
    local kind = KindDropdown.Value
    local name = CosmeticDropdown.Value
    if not kind or name == nil then return end
    if kind == "Skin" then
        if InfoLabel then
            InfoLabel:Set("Skin cannot be applied to all weapons.")
            InfoLabel.TextLabel.Visible = true
        end
        return
    end
    local slot = string.lower(kind)
    local count = 0
    local seen = {}
    for _, weaponMap in pairs(byClass) do
        for weapon in pairs(weaponMap) do
            if weapon ~= "All" and not seen[weapon] then
                seen[weapon] = true
                local selection = CosmeticsWrap.selections[weapon] or {}
                if name == NONE_LABEL then
                    selection[slot] = nil
                elseif kind == "Wrap" then
                    selection.wrap = { name = name, inverted = false }
                else
                    selection[slot] = name
                end
                if next(selection) == nil then
                    CosmeticsWrap.clear(weapon)
                else
                    CosmeticsWrap.set(weapon, selection)
                end
                count = count + 1
            end
        end
    end
    CosmeticsWrap.applyAll()
    CosmeticsWrap.Scene.requestRefresh()
    if InfoLabel then
        InfoLabel:Set(("Applied %s '%s' to %d weapons"):format(kind, tostring(name), count))
        InfoLabel.TextLabel.Visible = true
    end
end)

Group:AddButton("Reset All", function()
for weapon in pairs(CosmeticsWrap.selections) do
CosmeticsWrap.clear(weapon)
end
end)

task.defer(function()
local firstClass = classNames[1]
local firstWeapon = weaponsOfClass(firstClass)[1]
if firstWeapon then
local kinds = kindsOfWeapon(firstClass, firstWeapon)
if kinds[1] then
if CosmeticDropdown then
CosmeticDropdown:SetValue(NONE_LABEL)
end
updateVisual(firstClass, firstWeapon, kinds[1], NONE_LABEL)
end
end
end)

return true

--!nonstrict
local Hub = _G.MinhoHub
if not Hub then return end

local Players           = Hub.Players
local RunService        = Hub.RunService
local ReplicatedStorage = Hub.ReplicatedStorage
local UserInputService  = Hub.UserInputService
local LocalPlayer       = Hub.LocalPlayer
local ws                = Hub.ws
local Main              = Hub.Tabs.Main
local Library           = Hub.Library
local Toggles           = Library.Toggles
local Options           = Library.Options

local Config = {
    Enabled = false,
    EvasionMode = "Random",
    NotifyEvents = true,
    HitAboveY = 0.5,
    Weapons = {
        Priority = { "Primary", "Secondary", "Melee" },
        Enabled  = { Primary = true, Secondary = true, Melee = true, Utility = false },
        OnEmpty  = "SwapOrReload",
    },
    SilentAim = {
        Enabled = true,
        Manipulation = false,
        ClosestPart = false,
        ShowFOV = false,
        Radius = 100,
        HitChance = 100,
    },
    AutoPickup = { Enabled = true, Range = 250, Health = true, Ammo = true },
}
Hub.RageConfig = Config
getgenv().__MinhoRageConfig = Config

local RageModule = {}
Hub.RageModule = RageModule
getgenv().__MinhoRageModule = RageModule

local FAR = 1073741824
local DIRECTIONS = {
    Vector3.new( FAR, 0, 0), Vector3.new(-FAR, 0, 0),
    Vector3.new(0, 0,  FAR), Vector3.new(0, 0, -FAR),
    Vector3.new(0,  FAR, 0), Vector3.new(0, -FAR, 0),
}
local DIR_NAMES = { "E", "W", "S", "N", "Up", "Down" }
local escapeIndex = 0
local function cycleEscape()
    escapeIndex = (escapeIndex % #DIRECTIONS) + 1
    return DIRECTIONS[escapeIndex], DIR_NAMES[escapeIndex]
end

local function itemField(obj, key)
    if obj == nil then return nil end
    local ok, v = pcall(function() return obj[key] end)
    return ok and v or nil
end

local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getFighter()
    local ok, ctrl = pcall(function()
        return require(LocalPlayer.PlayerScripts.Controllers.FighterController)
    end)
    if not ok or not ctrl then return nil end
    return rawget(ctrl, "LocalFighter") or (ctrl.GetFighter and ctrl:GetFighter(LocalPlayer))
end

local function getItems()
    local fighter = getFighter()
    if fighter == nil then return nil end
    local direct = itemField(fighter, "Items")
    if type(direct) == "table" then return direct end
    return nil
end

local function getEquippedItem()
    local fighter = getFighter()
    if fighter == nil then return nil end
    local equipped = itemField(fighter, "EquippedItem")
    if equipped ~= nil then return equipped end
    local items = getItems()
    if items ~= nil then
        for _, entry in pairs(items) do
            if itemField(entry, "IsEquipped") == true then return entry end
        end
    end
    return nil
end

local function itemIndex(item)
    if item == nil then return nil end
    return itemField(itemField(item, "Data"), "ItemIndex")
end

local function itemType(item)
    if item == nil then return nil end
    return itemField(itemField(item, "Info"), "Type")
end

local function itemClass(item)
    if item == nil then return nil end
    local class = itemField(itemField(item, "Info"), "Class")
    if class ~= nil then return class end
    local index = itemIndex(item)
    return index and ({ "Primary", "Secondary", "Melee", "Utility" })[index] or nil
end

local function isReloading(item)
    if not item then return false end
    local ok, v = pcall(function() return item:IsReloading() end)
    if ok and v ~= nil then return v == true end
    return false
end

local function equipItem(item)
    if item == nil then return false end
    if itemField(item, "IsEquipped") == true then return true end
    local fighter = itemField(item, "ClientFighter") or getFighter()
    local index = itemIndex(item)
    if fighter == nil or index == nil then
        return (pcall(function() item:Equip() end))
    end
    if pcall(function() fighter:EquipItem(index) end) then return true end
    return (pcall(function() item:Equip() end))
end

local function weaponAction()
    local weapons = Config.Weapons
    local onEmpty = weapons.OnEmpty
    local best, bestRank = nil, math.huge
    local emptyBest, emptyRank = nil, math.huge
    local utilityItem = nil
    local anyEnabled = false

    local function consider(entry)
        local class = itemClass(entry)
        if class == nil then return end

        if class == "Utility" then
            if utilityItem == nil then
                utilityItem = entry
            end
            if weapons.Enabled.Utility then anyEnabled = true end
            return
        end

        if weapons.Enabled[class] ~= true then return end
        anyEnabled = true

        local data = itemField(entry, "Data")
        local ammo = itemField(data, "Ammo")
        local reserve = itemField(data, "AmmoReserve")
        local rank = table.find(weapons.Priority, class) or math.huge
        local isGun = itemType(entry) == "Gun"
        local record = { item = entry, empty = false }

        if isGun and ammo == 0 then
            if (reserve == nil or reserve > 0) and rank < emptyRank then
                record.empty = true
                if onEmpty == "Reload" then
                    bestRank, best = rank, record
                else
                    emptyRank, emptyBest = rank, record
                end
            end
        elseif best == nil or rank < bestRank then
            bestRank, best = rank, record
        end
    end

    local items = getItems()
    if items ~= nil then
        for _, entry in pairs(items) do consider(entry) end
    end

    if not anyEnabled then return nil end

    if weapons.Enabled.Utility and utilityItem ~= nil then
        if itemField(utilityItem, "IsEquipped") ~= true then
            return { type = "Swap", item = utilityItem }
        end
        return { type = "Utility", item = utilityItem }
    end

    if best == nil then
        if onEmpty == "Swap" or emptyBest == nil then return nil end
        local equipped = itemField(emptyBest.item, "IsEquipped") == true
        return { type = equipped and "Reload" or "Swap", item = emptyBest.item }
    end
    if itemField(best.item, "IsEquipped") ~= true then
        return { type = "Swap", item = best.item }
    end
    if best.empty then return { type = "Reload", item = best.item } end
    return { type = "Attack", item = best.item }
end

local MELEE_KEYWORDS = { "knife", "katana", "sword", "dagger", "axe",
    "hammer", "bat", "scythe", "fist", "melee", "blade" }

local ItemCache = nil
local function getItemLib()
    if ItemCache then return ItemCache end
    local ok, lib = pcall(function()
        return require(ReplicatedStorage.Modules.ItemLibrary)
    end)
    if ok and lib and lib.Items then ItemCache = lib.Items end
    return ItemCache
end
local function getItemInfo(item)
    if not item then return nil end
    local name = rawget(item, "Name")
    if not name then return nil end
    local items = getItemLib()
    return items and items[name] or nil
end

local function isMelee(item)
    if not item then return false end
    local name = rawget(item, "Name")
    if not name then return false end
    if name == "Fists" then return true end
    local info = getItemInfo(item)
    if info then
        if info.Class == "Melee" then return true end
        if info.Type == "Melee" then return true end
    end
    local lower = name:lower()
    for _, kw in ipairs(MELEE_KEYWORDS) do
        if lower:find(kw, 1, true) then return true end
    end
    return false
end

local function isInvincible(character)
    if not character then return true end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return true end
    for _, obj in pairs(root:GetChildren()) do
        if obj:IsA("Attachment") and obj.Name == "Attachment" then return true end
    end
    if character:FindFirstChild("InvincibilityParticles", true) then return true end
    if character:FindFirstChildOfClass("ForceField") then return true end
    return false
end

local function isDead(character)
    if not character or not character.Parent then return true end
    local hum = character:FindFirstChildOfClass("Humanoid")
    return not hum or hum.Health <= 0
end

local function getHead(character)
    if not character then return nil end
    return character:FindFirstChild("Head")
        or character:FindFirstChild("HitboxHead")
end

local silentFOV = 100

local function getClosestPart(character)
    if not character then return nil end
    local cam = ws.CurrentCamera
    if not cam then return nil end
    local mousePos = UserInputService:GetMouseLocation()
    local parts = {}
    for _, name in ipairs({ "Head", "HitboxHead", "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart",
                             "LeftHand", "RightHand", "LeftFoot", "RightFoot",
                             "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" }) do
        local p = character:FindFirstChild(name)
        if p and p:IsA("BasePart") then parts[#parts + 1] = p end
    end
    local closest, closestDist = nil, silentFOV
    for _, p in ipairs(parts) do
        local pos, visible = cam:WorldToViewportPoint(p.Position)
        if visible and pos.Z > 0 then
            local d = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
            if d < closestDist then
                closestDist = d
                closest = p
            end
        end
    end
    return closest
end

local function pickRageTargetPart(character)
    if not character then return nil end
    return character:FindFirstChild("HitboxHead")
        or character:FindFirstChild("Head")
end

local function isInMatch()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    local main = pg:FindFirstChild("MainGui")
    if not main then return false end
    local frame = main:FindFirstChild("MainFrame")
    if not frame then return false end
    local lobby = frame:FindFirstChild("Lobby")
    if not lobby then return false end
    local currency = lobby:FindFirstChild("Currency")
    if not currency then return false end
    return not currency.Visible
end

local useItemRemote = ReplicatedStorage.Remotes.Replication.Fighter.UseItem
local util  = require(ReplicatedStorage.Modules.Utility)
local enums = require(ReplicatedStorage.Modules.EnumLibrary)

local silentEnabled = true
local silentManipulation = false
local silentClosestPart = false
local silentShowFOV = false
local silentHitChance = 100

local fovCircle = nil
local function createFOVCircle()
    if fovCircle then return fovCircle end
    local ok, circle = pcall(function()
        local Drawing = Drawing or (getgenv and getgenv().Drawing)
        if not Drawing then return nil end
        local c = Drawing.new("Circle")
        c.Thickness = 1
        c.NumSides = 60
        c.Radius = silentFOV
        c.Filled = false
        c.Visible = false
        c.Color = Color3.fromRGB(255, 255, 255)
        return c
    end)
    if ok then fovCircle = circle end
    return fovCircle
end

local function getHeadTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local closest, closestDist = nil, silentFOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local myTeam = LocalPlayer:GetAttribute("TeamID")
            local myEnv  = LocalPlayer:GetAttribute("EnvironmentID")
            local env    = plr:GetAttribute("EnvironmentID")
            local team   = plr:GetAttribute("TeamID")
            local envOk  = (myEnv == nil) or (env == myEnv)
            local teamOk = (myTeam == nil) or (team == nil) or (team ~= myTeam)
            if envOk and teamOk then
                local head = plr.Character:FindFirstChild("Head")
                    or plr.Character:FindFirstChild("HitboxHead")
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if head and hum and hum.Health > 0 and not isInvincible(plr.Character) then
                    local pos, visible = ws.CurrentCamera:WorldToViewportPoint(head.Position)
                    if visible and pos.Z > 0 then
                        local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            closest = plr.Character
                        end
                    end
                end
            end
        end
    end
    return closest
end

if not getgenv().__MinhoSilentAimHooked then
    getgenv().__MinhoSilentAimHooked = true
    local oldFireServer
    if hookfunction and newcclosure then
        oldFireServer = hookfunction(useItemRemote.FireServer, newcclosure(function(self, oid, action, cameradata, ...)
            if silentEnabled and action == enums:ToEnum("StartShooting") then
                if silentHitChance < 100 then
                    if math.random(1, 100) > silentHitChance then
                        return oldFireServer(self, oid, action, cameradata, ...)
                    end
                end

                local target = getHeadTarget()
                if target then
                    local inFOV = false
                    local cam = ws.CurrentCamera
                    if cam then
                        local mousePos = UserInputService:GetMouseLocation()
                        for _, nm in ipairs({ "HitboxHead", "Head", "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart" }) do
                            local p = target:FindFirstChild(nm)
                            if p and p:IsA("BasePart") then
                                local sp, onScreen = cam:WorldToViewportPoint(p.Position)
                                if onScreen and sp.Z > 0 then
                                    local d = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                                    if d < silentFOV then
                                        inFOV = true
                                        break
                                    end
                                end
                            end
                        end
                    end

                    if inFOV then
                        local part
                        if silentManipulation then
                            part = target:FindFirstChild("HitboxHead")
                                or target:FindFirstChild("Head")
                        elseif silentClosestPart then
                            part = getClosestPart(target)
                        else
                            part = target:FindFirstChild("Head")
                                or target:FindFirstChild("HitboxHead")
                        end

                        if part then
                            local cam2 = ws.CurrentCamera
                            local okFOV = false
                            if cam2 then
                                local sp2, onScreen2 = cam2:WorldToViewportPoint(part.Position)
                                if onScreen2 and sp2.Z > 0 then
                                    local mp = UserInputService:GetMouseLocation()
                                    local d2 = (Vector2.new(sp2.X, sp2.Y) - mp).Magnitude
                                    if d2 < silentFOV then okFOV = true end
                                end
                            end

                            if okFOV then
                                local look = CFrame.new(ws.CurrentCamera.CFrame.Position, part.Position)
                                local newData = {}
                                newData[utf8.char(1)] = {
                                    [utf8.char(0)] = util:EncodeCFrame(look),
                                    [utf8.char(1)] = util:EncodeCFrame(look),
                                    [utf8.char(2)] = part,
                                    [utf8.char(3)] = util:EncodeCFrame(
                                        part.CFrame:ToObjectSpace(CFrame.new(part.Position))
                                    ),
                                }
                                return oldFireServer(self, oid, action, newData, ...)
                            end
                        end
                    end
                end
            end
            return oldFireServer(self, oid, action, cameradata, ...)
        end))
    end
end

_G.ToggleSilentHead = function(state) silentEnabled = state end

local Desync = { _cframe = nil, _oldCFrame = nil, _part = nil, _mode = "off" }
local function desyncSetEnemy(cf) Desync._cframe = cf Desync._mode = "enemy" end
local function desyncSetScatter(cf) Desync._cframe = cf Desync._mode = "scatter" end
local function desyncClear()
    Desync._cframe = nil
    Desync._oldCFrame = nil
    Desync._part = nil
    Desync._mode = "off"
end
local function desyncPush(root)
    if root == nil or Desync._cframe == nil then return end
    Desync._oldCFrame = root.CFrame
    Desync._part = root
    root.CFrame = Desync._cframe
end
local function desyncRestore()
    local old = Desync._oldCFrame
    if old == nil then return end
    local part = Desync._part
    Desync._oldCFrame = nil
    if part and part.Parent then part.CFrame = old end
end

if not getgenv().__MinhoRageDesyncBound then
    getgenv().__MinhoRageDesyncBound = true
    RunService:BindToRenderStep("\0minho_rage_desync\0", Enum.RenderPriority.First.Value, desyncRestore)
end

-- =========================================================
-- NoRecoil (유지)
-- =========================================================
local NoRecoilOriginals = getgenv().__MinhoNoRecoilOriginals or {}
getgenv().__MinhoNoRecoilOriginals = NoRecoilOriginals

local function applyNoRecoil()
    local ok, lib = pcall(function() return require(ReplicatedStorage.Modules.ItemLibrary) end)
    if not ok or not lib or type(lib.Items) ~= "table" then return end
    for _, data in pairs(lib.Items) do
        if type(data) == "table" and type(data.ShootRecoil) == "number" then
            if NoRecoilOriginals[data] == nil then
                NoRecoilOriginals[data] = data.ShootRecoil
            end
            data.ShootRecoil = 0
        end
    end
    local fighter = getFighter()
    if fighter and type(fighter.Items) == "table" then
        for _, item in pairs(fighter.Items) do
            local info = itemField(item, "Info")
            if type(info) == "table" and type(info.ShootRecoil) == "number" then
                if NoRecoilOriginals[info] == nil then
                    NoRecoilOriginals[info] = info.ShootRecoil
                end
                info.ShootRecoil = 0
            end
        end
    end
end

local function revertNoRecoil()
    for data, orig in pairs(NoRecoilOriginals) do
        if type(data) == "table" then
            pcall(function() data.ShootRecoil = orig end)
        end
    end
    NoRecoilOriginals = {}
    getgenv().__MinhoNoRecoilOriginals = NoRecoilOriginals
end

RageModule.applyNoRecoil = applyNoRecoil
RageModule.revertNoRecoil = revertNoRecoil

-- =========================================================
-- NoSpread (유지)
-- =========================================================
local NoSpreadState = {
    Hooked = false, Method = nil, Index = nil,
    Original = nil, Dummy = nil, Bindings = nil,
}

local function NoSpread_Load()
    if NoSpreadState.Hooked then return true end
    if not (setrawmetatable and clonefunction and debug.getupvalues and debug.setupvalue and getgc) then
        return false
    end
    local RS = ReplicatedStorage
    local LP = LocalPlayer
    local remote
    do
        local r = RS:FindFirstChild('Remotes')
        local rp = r and r:FindFirstChild('Replication')
        local f = rp and rp:FindFirstChild('Fighter')
        remote = f and f:FindFirstChild('UseItem')
    end
    if not (remote and remote:IsA('RemoteEvent')) then return false end
    local clientItem
    do
        local ps = LP:FindFirstChild('PlayerScripts')
        local md = ps and ps:FindFirstChild('Modules')
        local cr = md and md:FindFirstChild('ClientReplicatedClasses')
        local cf = cr and cr:FindFirstChild('ClientFighter')
        local ci = cf and cf:FindFirstChild('ClientItem')
        if ci then local ok, v = pcall(require, ci); if ok then clientItem = v end end
    end
    if type(clientItem) ~= 'table' then return false end
    local fromEnum
    do
        local md = RS:FindFirstChild('Modules')
        local el = md and md:FindFirstChild('EnumLibrary')
        if el then local ok, v = pcall(require, el); if ok then fromEnum = rawget(v, '_from_enum') end end
    end
    if type(fromEnum) ~= 'table' then return false end

    local fighterController
    local function LocalFighter()
        if not fighterController then
            for _, m in ipairs(getgc(true)) do
                if type(m) == 'table' and rawget(m, 'LocalFighter') and rawget(m, 'Objects') then
                    fighterController = m; break
                end
            end
        end
        return fighterController and rawget(fighterController, 'LocalFighter')
    end

    local function GetItemById(id)
        local f = LocalFighter()
        local items = type(f) == 'table' and rawget(f, 'Items') or nil
        if type(items) ~= 'table' then return nil end
        for _, it in next, items do
            local d = rawget(it, 'Data')
            if d and rawget(d, 'ObjectID') == id then return it end
        end
    end

    local dummy = Color3.new()
    local fireNative = clonefunction(Instance.new('RemoteEvent').FireServer)
    local bindings = {}

    local function Dispatch(packet)
        for _, b in ipairs(bindings) do
            if b.enabled and b.handler then
                b.handler(packet)
                if packet.block then break end
            end
        end
    end

    local remoteTree = {
        Replication = {
            Fighter = {
                UseItem = {
                    FireServer = function(_, objectId, encType, args)
                        local packet = {
                            block = false, objectId = objectId,
                            type = rawget(fromEnum, encType), args = args,
                        }
                        Dispatch(packet)
                        if packet.block then return end
                        return fireNative(remote, objectId, encType, args, nil)
                    end,
                },
            },
        },
    }
    setrawmetatable(dummy, { __index = function() return remoteTree end })

    local inputMethod = rawget(clientItem, 'Input')
    if not inputMethod then return false end

    local foundIndex, foundOriginal = nil, nil
    for i, v in pairs(debug.getupvalues(inputMethod)) do
        if typeof(v) == 'Instance' and v == RS then
            foundIndex = i; foundOriginal = v; break
        end
    end
    if foundIndex == nil then
        for _, bundle in pairs(debug.getupvalues(inputMethod)) do
            if type(bundle) == 'table' then
                for k, v in pairs(bundle) do
                    if typeof(v) == 'Instance' and v == RS then
                        foundIndex = { bundle = bundle, key = k }
                        foundOriginal = v
                        break
                    end
                end
                if foundIndex then break end
            end
        end
    end
    if foundIndex == nil then return false end

    if type(foundIndex) == "table" then
        foundIndex.bundle[foundIndex.key] = dummy
    else
        debug.setupvalue(inputMethod, foundIndex, dummy)
    end

    table.insert(bindings, {
        enabled = true,
        handler = function(packet)
            if packet.type ~= 'StartShooting' then return end
            local item = GetItemById(packet.objectId)
            if not item then return end
            if rawget(rawget(item, 'Info'), 'Type') == 'Gun' then
                packet.args['\2'] = true
            end
        end,
    })

    NoSpreadState.Method = inputMethod
    NoSpreadState.Index = foundIndex
    NoSpreadState.Original = foundOriginal
    NoSpreadState.Dummy = dummy
    NoSpreadState.Bindings = bindings
    NoSpreadState.Hooked = true
    return true
end

local function NoSpread_Unload()
    if not NoSpreadState.Hooked then return end
    local inputMethod = NoSpreadState.Method
    local index = NoSpreadState.Index
    local original = NoSpreadState.Original
    if inputMethod and index and original then
        if type(index) == "table" then
            pcall(function() index.bundle[index.key] = original end)
        else
            pcall(function() debug.setupvalue(inputMethod, index, original) end)
        end
    end
    NoSpreadState.Hooked = false
    NoSpreadState.Method = nil
    NoSpreadState.Index = nil
    NoSpreadState.Original = nil
    NoSpreadState.Dummy = nil
    NoSpreadState.Bindings = nil
    return true
end

RageModule.NoSpread_Load = NoSpread_Load
RageModule.NoSpread_Unload = NoSpread_Unload

-- =========================================================
-- Attack Speed (Remote Only) - 신규
-- =========================================================
local AttackSpeed = {
    Enabled = false,
    Interval = 0.05,
    LastSent = 0,
    LastOid = nil,
    LastAction = nil,
    LastData = nil,
    LastExtra = nil,
    ExpireAt = 0,
}

local attackSpeedRemote = ReplicatedStorage.Remotes.Replication.Fighter.UseItem
local attackSpeedEnums  = require(ReplicatedStorage.Modules.EnumLibrary)

local function enumToName(enum)
    local ok, name = pcall(function() return attackSpeedEnums:FromEnum(enum) end)
    if ok and type(name) == "string" then return name end

    ok, name = pcall(function() return attackSpeedEnums:GetEnum(enum) end)
    if ok and type(name) == "string" then return name end

    if type(attackSpeedEnums) == "table" then
        for k, v in pairs(attackSpeedEnums) do
            if type(v) == "table" then
                for kk, vv in pairs(v) do
                    if vv == enum then return kk end
                end
            end
        end
    end
    return nil
end

local ATTACK_ENUM_NAMES = {
    StartShooting = true,
    StartAttacking = true,
    StartMelee = true,
    Attack = true,
    Shoot = true,
}

if not getgenv().__MinhoAttackSpeedHooked then
    getgenv().__MinhoAttackSpeedHooked = true
    local oldFire
    oldFire = hookfunction(attackSpeedRemote.FireServer, newcclosure(function(self, oid, action, data, ...)
        if AttackSpeed.Enabled then
            local name = enumToName(action)
            if name and ATTACK_ENUM_NAMES[name] then
                AttackSpeed.LastOid    = oid
                AttackSpeed.LastAction = action
                AttackSpeed.LastData   = data
                AttackSpeed.LastExtra  = { ... }
                AttackSpeed.ExpireAt   = os.clock() + 0.5
            end
        end
        return oldFire(self, oid, action, data, ...)
    end))
end

RunService.Heartbeat:Connect(function()
    if not AttackSpeed.Enabled then return end
    if not AttackSpeed.LastOid then return end

    local now = os.clock()
    if now > AttackSpeed.ExpireAt then
        AttackSpeed.LastOid = nil
        return
    end
    if now - AttackSpeed.LastSent < AttackSpeed.Interval then return end
    AttackSpeed.LastSent = now

    local extra = AttackSpeed.LastExtra or {}
    pcall(function()
        attackSpeedRemote:FireServer(
            AttackSpeed.LastOid,
            AttackSpeed.LastAction,
            AttackSpeed.LastData,
            table.unpack(extra)
        )
    end)
end)

RageModule.setAttackSpeed = function(enabled, interval)
    AttackSpeed.Enabled = enabled and true or false
    if interval and interval > 0 then AttackSpeed.Interval = interval end
    if not AttackSpeed.Enabled then AttackSpeed.LastOid = nil end
end

-- =========================================================
-- Helper toggles
-- =========================================================
local function safeToggle(id)
    local t = Toggles and Toggles[id]
    return t ~= nil and t.Value == true
end

-- =========================================================
-- AutoPickup
-- =========================================================
RunService.Heartbeat:Connect(function()
    if not Config.AutoPickup.Enabled then return end
    if not firetouchinterest then return end
    local root = getRoot()
    if not root then return end
    for _, part in ipairs(workspace:GetChildren()) do
        if part:IsA("BasePart") then
            local isDrop = part.Name == "_drop"
            if not isDrop then
                local dt = part:GetAttribute("DropType")
                if dt ~= nil then
                    local t = tostring(dt):lower()
                    if t:find("health") or t:find("heal") then
                        isDrop = Config.AutoPickup.Health
                    elseif t:find("ammo") or t:find("bullet") then
                        isDrop = Config.AutoPickup.Ammo
                    else
                        isDrop = Config.AutoPickup.Health or Config.AutoPickup.Ammo
                    end
                else
                    isDrop = Config.AutoPickup.Health or Config.AutoPickup.Ammo
                end
            end
            if isDrop then
                local dist = (part.Position - root.Position).Magnitude
                if dist < Config.AutoPickup.Range then
                    pcall(firetouchinterest, root, part, 0)
                    pcall(firetouchinterest, root, part, 1)
                end
            end
        end
    end
end)

-- =========================================================
-- UE Assisted Rage
-- =========================================================
local lastEscapeAt, lastAttachAt, lastMeleeAt = 0, 0, 0
local lastTarget = nil

local function notify(text, dur)
    if not Config.NotifyEvents then return end
    pcall(function()
        if Library and Library.Notify then
            Library:Notify({ Title = "Ragebot", Description = tostring(text), Duration = dur or 3 })
        end
    end)
end

local meleeCount = 0
local meleeTarget = nil
local switchState = { lastSwitchAt = 0, cooldown = 0.15 }

local function scatterStep(root, now)
    local dir, name = cycleEscape()
    desyncSetScatter(CFrame.new(root.CFrame.Position + dir))
    desyncPush(root)
    return name
end

local TELEPORT_CFRAME = CFrame.new(9000, 9000, 9000)
local trackedParts = {}
local ueEnabled = false

local function setUERage(state)
    ueEnabled = state
    shared.RagebotActive = state
    if not state then trackedParts = {} end
end
Hub.setUERage = setUERage

workspace.ChildAdded:Connect(function(o)
    if not ueEnabled then return end
    if not o:IsA("BasePart") then return end
    if o.Name == "CoreProjectile" then
        trackedParts[o] = true
    elseif o.Name == "Part" then
        task.defer(function()
            if o and o.Parent and o.AssemblyLinearVelocity.Magnitude > 50 then
                trackedParts[o] = true
            end
        end)
    end
end)

workspace.ChildRemoved:Connect(function(o) trackedParts[o] = nil end)

RunService.Heartbeat:Connect(function()
    if not ueEnabled then return end
    pcall(function()
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChild("HumanoidRootPart")
                if h then
                    h.CFrame = TELEPORT_CFRAME
                    h.AssemblyLinearVelocity = Vector3.zero
                    h.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
        for _, o in pairs(workspace:GetChildren()) do
            if o.Name == "CoreProjectile" and o:IsA("BasePart") then
                o.CFrame = TELEPORT_CFRAME
                o.AssemblyLinearVelocity = Vector3.zero
            end
        end
        for p in pairs(trackedParts) do
            if p and p.Parent then
                p.CFrame = TELEPORT_CFRAME
                p.AssemblyLinearVelocity = Vector3.zero
            else
                trackedParts[p] = nil
            end
        end
    end)
end)

-- =========================================================
-- Underground
-- =========================================================
local undergroundState = getgenv().__MinhoUndergroundState or {
    Active = false, Conn = nil, NoclipConn = nil, GroundY = nil,
}
getgenv().__MinhoUndergroundState = undergroundState

local UNDERGROUND_DEPTH = 6
local UNDERGROUND_MOVE_SPEED = 50
local UNDERGROUND_NOCLIP = true

local function getUndergroundRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getUndergroundHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function enableUndergroundNoclip()
    if not UNDERGROUND_NOCLIP or undergroundState.NoclipConn then return end
    undergroundState.NoclipConn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in char:GetDescendants() do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function disableUndergroundNoclip()
    if undergroundState.NoclipConn then
        undergroundState.NoclipConn:Disconnect()
        undergroundState.NoclipConn = nil
    end
    local char = LocalPlayer.Character
    if char then
        for _, part in char:GetDescendants() do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

local function stopUnderground()
    undergroundState.Active = false
    if undergroundState.Conn then
        undergroundState.Conn:Disconnect()
        undergroundState.Conn = nil
    end
    disableUndergroundNoclip()
    undergroundState.GroundY = nil
end

local function startUnderground()
    if undergroundState.Active then return end
    undergroundState.Active = true

    undergroundState.Conn = RunService.Heartbeat:Connect(function(dt)
        if not undergroundState.Active then return end
        local root = getUndergroundRoot()
        local hum = getUndergroundHumanoid()
        if not root or not hum then return end

        if not undergroundState.GroundY then
            undergroundState.GroundY = root.Position.Y - UNDERGROUND_DEPTH
        end

        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0.1 then
            local flat = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
            root.AssemblyLinearVelocity = Vector3.new(flat.X * UNDERGROUND_MOVE_SPEED, 0, flat.Z * UNDERGROUND_MOVE_SPEED)
        else
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end

        local currentPos = root.Position
        root.CFrame = CFrame.new(currentPos.X, undergroundState.GroundY, currentPos.Z) * (root.CFrame - root.CFrame.Position)
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    enableUndergroundNoclip()
end

Hub.startUnderground = startUnderground
Hub.stopUnderground = stopUnderground
getgenv().__UndergroundStop = stopUnderground

LocalPlayer.CharacterAdded:Connect(function()
    undergroundState.GroundY = nil
    if undergroundState.Active then
        enableUndergroundNoclip()
    end
end)

-- =========================================================
-- Main Rage Heartbeat
-- =========================================================
if RageModule._heartbeatConn then
    pcall(function() RageModule._heartbeatConn:Disconnect() end)
end

RageModule._heartbeatConn = RunService.Heartbeat:Connect(function(dt)
    if not Config.Enabled then
        desyncClear()
        return
    end

    -- NoRecoil 만 유지 (스피드핵 없음)
    if safeToggle("NoRecoilEnabled") then
        pcall(applyNoRecoil)
    end

    local now = os.clock()
    local root = getRoot()
    local hum = getHum()
    if not root or not hum or hum.Health <= 0 then desyncClear() return end
    if not isInMatch() then
        desyncClear()
        lastTarget = nil
        return
    end

    local evasionOn = (Config.EvasionMode == "Random")

    local currentItem = getEquippedItem()
    if not currentItem then desyncClear() return end

    local currentClass = itemClass(currentItem)
    local currentIsMelee = isMelee(currentItem)
    local canSwitch = (now - switchState.lastSwitchAt) > switchState.cooldown

    local action = weaponAction()
    if action == nil then
        if evasionOn then
            scatterStep(root, now)
        else
            desyncClear()
        end
        return
    end

    if action.type == "Swap" then
        if evasionOn then
            scatterStep(root, now)
        else
            desyncClear()
        end
        if canSwitch then
            local success = equipItem(action.item)
            switchState.lastSwitchAt = now
            if success then
                local newClass = itemClass(action.item)
                local newName = rawget(action.item, "Name") or "?"
                notify("Weapon switched -> " .. newName .. " (" .. (newClass or "?") .. ")", 1.0)
            end
        end
        return
    end

    if action.type == "Reload" then
        if not isReloading(action.item) then doReload(action.item) end
        if evasionOn then
            local name = scatterStep(root, now)
            if now - lastEscapeAt > 1 then
                lastEscapeAt = now
                notify("Out of ammo -> reload + escape " .. name, 1.5)
            end
        else
            desyncClear()
        end
        return
    end

    if action.type == "Utility" then
        if evasionOn then
            local name = scatterStep(root, now)
            if now - lastEscapeAt > 2 then
                lastEscapeAt = now
                local utilName = rawget(action.item, "Name") or "?"
                notify("Utility (" .. utilName .. ") -> escape " .. name, 2)
            end
        else
            desyncClear()
        end
        lastTarget = nil
        return
    end

    local enemy = getClosestEnemy()
    if not enemy then
        if evasionOn then
            scatterStep(root, now)
        else
            desyncClear()
        end
        lastTarget = nil
        meleeTarget = nil
        return
    end
    local targetChar = enemy.Character
    local head = enemy.Head
    if not targetChar or not head or isDead(targetChar) then
        if evasionOn then
            scatterStep(root, now)
        else
            desyncClear()
        end
        lastTarget = nil
        meleeTarget = nil
        return
    end

    if targetChar ~= lastTarget then
        lastTarget = targetChar
        local plr = Players:GetPlayerFromCharacter(targetChar)
        notify("Target found: " .. (plr and plr.Name or "?"), 1.5)
    end

    local firePart = pickRageTargetPart(targetChar)
    if not firePart then firePart = head end

    if currentIsMelee then
        if targetChar ~= meleeTarget then
            meleeCount = 0
            meleeTarget = targetChar
        end

        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        local targetAlive = targetHum and targetHum.Health > 0 and not isDead(targetChar)

        if not targetAlive then
            if evasionOn then
                local name = scatterStep(root, now)
                if now - lastEscapeAt > 0.5 then
                    lastEscapeAt = now
                    notify("Melee kill -> escape " .. name, 2)
                end
            else
                desyncClear()
            end
            meleeCount = 0
            meleeTarget = nil
            return
        end

        local targetPos = firePart.Position + Vector3.new(0, Config.HitAboveY, 0)
        desyncSetEnemy(CFrame.new(targetPos))
        desyncPush(root)
        if doFire(firePart) then
            meleeCount += 1
            if now - lastMeleeAt > 0.3 then
                lastMeleeAt = now
                notify(string.format("Melee attacking (%d hits)", meleeCount), 1)
            end
        end
        return
    end

    local targetPos = firePart.Position + Vector3.new(0, Config.HitAboveY, 0)
    desyncSetEnemy(CFrame.new(targetPos))
    desyncPush(root)
    if doFire(firePart) then
        if now - lastAttachAt > 1 then
            lastAttachAt = now
            notify("Attach -> fire (Head)", 1)
        end
    end
end)

-- =========================================================
-- FOV Circle Render
-- =========================================================
RunService.RenderStepped:Connect(function()
    if not silentShowFOV then
        if fovCircle then fovCircle.Visible = false end
        return
    end
    local c = createFOVCircle()
    if not c then return end
    local cam = ws.CurrentCamera
    if not cam then return end
    local viewport = cam.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    c.Position = center
    c.Radius = silentFOV
    c.Visible = true
end)

-- =========================================================
-- UI
-- =========================================================
local RageBox  = Main:AddGroupbox({ Name = "Ragebot", Side = 1, IconName = "target" })
local RBox     = Main:AddGroupbox({ Name = "Rage", Side = 1, IconName = "zap" })

local SABox    = Main:AddGroupbox({ Name = "Silent Aim", Side = 2, IconName = "focus" })
local SCBox    = Main:AddGroupbox({ Name = "Speed Control", Side = 2, IconName = "gauge" })

RageBox:AddCheckbox("RageEnabled", {
    Text = "Ragebot Enabled", Default = false,
    Callback = function(v) Config.Enabled = v end,
})
RageBox:AddDropdown("EvasionMode", {
    Text = "Evasion Mode", Values = { "Off", "Lobby", "Random" },
    Default = "Random", Multi = false,
    Callback = function(v) Config.EvasionMode = v end,
})
RageBox:AddCheckbox("NotifyEvents", {
    Text = "Event Notifications", Default = true,
    Callback = function(v) Config.NotifyEvents = v end,
})
RageBox:AddSlider("HitAboveY", {
    Text = "Hit Above Y", Default = 0.5, Min = -5, Max = 5,
    Rounding = 2, Suffix = " studs",
    Callback = function(v) Config.HitAboveY = v end })
RageBox:AddDropdown("OnEmptyAmmo", {
    Text = "On Empty Ammo",
    Values = { "Swap or Reload", "Reload Only", "Swap Only" },
    Default = "Swap or Reload", Multi = false,
    Callback = function(v)
        if v == "Reload Only" then Config.Weapons.OnEmpty = "Reload"
        elseif v == "Swap Only" then Config.Weapons.OnEmpty = "Swap"
        else Config.Weapons.OnEmpty = "SwapOrReload" end
    end,
})
RageBox:AddLabel("Weapon Types to Use")
RageBox:AddCheckbox("Enabled_Primary", {
    Text = "Use Primary", Default = true,
    Callback = function(v) Config.Weapons.Enabled.Primary = v end })
RageBox:AddCheckbox("Enabled_Secondary", {
    Text = "Use Secondary", Default = true,
    Callback = function(v) Config.Weapons.Enabled.Secondary = v end })
RageBox:AddCheckbox("Enabled_Melee", {
    Text = "Use Melee", Default = true,
    Callback = function(v) Config.Weapons.Enabled.Melee = v end })
RageBox:AddCheckbox("Enabled_Utility", {
    Text = "Use Utility", Default = false,
    Callback = function(v) Config.Weapons.Enabled.Utility = v end })

RBox:AddCheckbox("UEAssistedRage", {
    Text = "UE Assisted Rage", Default = false,
    Callback = function(Value) setUERage(Value) end,
})
RBox:AddCheckbox("Underground", {
    Text = "Underground", Default = false,
    Callback = function(Value)
        if Value then startUnderground() else stopUnderground() end
    end,
})

SABox:AddCheckbox("SilentAim_Enabled", {
    Text = "Enabled", Default = true,
    Callback = function(v)
        silentEnabled = v
        Config.SilentAim.Enabled = v
    end,
})

SABox:AddCheckbox("SilentAim_Manipulation", {
    Text = "Manipulation", Default = false,
    Callback = function(v)
        silentManipulation = v
        Config.SilentAim.Manipulation = v
        if v and silentClosestPart then
            silentClosestPart = false
            Config.SilentAim.ClosestPart = false
            pcall(function()
                if Toggles["SilentAim_ClosestPart"] then
                    Toggles["SilentAim_ClosestPart"]:SetValue(false)
                end
            end)
        end
    end,
})

SABox:AddCheckbox("SilentAim_ClosestPart", {
    Text = "Closest Part", Default = false,
    Callback = function(v)
        silentClosestPart = v
        Config.SilentAim.ClosestPart = v
        if v and silentManipulation then
            silentManipulation = false
            Config.SilentAim.Manipulation = false
            pcall(function()
                if Toggles["SilentAim_Manipulation"] then
                    Toggles["SilentAim_Manipulation"]:SetValue(false)
                end
            end)
        end
    end,
})

SABox:AddCheckbox("SilentAim_ShowFOV", {
    Text = "Show FOV", Default = false,
    Callback = function(v)
        silentShowFOV = v
        Config.SilentAim.ShowFOV = v
        if not v and fovCircle then fovCircle.Visible = false end
    end,
})
SABox:AddSlider("SilentAim_Radius", {
    Text = "Radius",
    Default = 100, Min = 5, Max = 2000,
    Rounding = 0,
    Suffix = " studs",
    Callback = function(v)
        v = math.floor(v / 5 + 0.5) * 5
        silentFOV = v
        Config.SilentAim.Radius = v
        if fovCircle then fovCircle.Radius = v end
    end,
})
SABox:AddSlider("SilentAim_HitChance", {
    Text = "Hit Chance",
    Default = 100, Min = 1, Max = 100,
    Rounding = 0,
    Suffix = "%",
    Callback = function(v)
        v = math.floor(v + 0.5)
        silentHitChance = v
        Config.SilentAim.HitChance = v
    end,
})

-- No Recoil / No Spread 유지
SCBox:AddCheckbox("NoRecoilEnabled", {
    Text = "No Recoil",
    Default = false,
    Tooltip = "Removes gun recoil (sets ShootRecoil to 0).",
    Callback = function(Value)
        if Value then
            if RageModule.applyNoRecoil then RageModule.applyNoRecoil() end
        else
            if RageModule.revertNoRecoil then RageModule.revertNoRecoil() end
        end
    end,
})

SCBox:AddCheckbox("NoSpread", {
    Text = "No Spread",
    Default = false,
    Tooltip = "Forces raycast shots (removes bullet spread).",
    Callback = function(Value)
        if Value then
            local ok = RageModule.NoSpread_Load and RageModule.NoSpread_Load()
            if not ok then
                if Library and Library.Notify then
                    Library:Notify({
                        Title = "No Spread",
                        Description = "Executor missing required functions (setrawmetatable / getgc / debug)",
                        Time = 5,
                    })
                end
            end
        else
            if RageModule.NoSpread_Unload then RageModule.NoSpread_Unload() end
        end
    end,
})

-- Attack Speed (Remote Only) — 신규
SCBox:AddCheckbox("AttackSpeedEnabled", {
    Text = "Attack Speed (Remote Only)",
    Default = false,
    Tooltip = "서버로 보내는 공격 리모트만 빨라짐. 뷰모델/애니메이션은 정상.",
    Callback = function(v)
        RageModule.setAttackSpeed(v, AttackSpeed.Interval)
    end,
})

local ASBox = SCBox:AddDependencyBox()
ASBox:AddSlider("AttackSpeedInterval", {
    Text = "Interval",
    Default = 0.05, Min = 0.01, Max = 0.5,
    Rounding = 3, Compact = true,
    Suffix = "s",
    Callback = function(v)
        AttackSpeed.Interval = v
    end,
})
ASBox:SetupDependencies({ { Toggles.AttackSpeedEnabled, true } })

return nil

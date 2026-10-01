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
    SpeedBoostMult = 0,
    Weapons = {
        Priority = { "Primary", "Secondary", "Melee" },
        Enabled  = { Primary = true, Secondary = true, Melee = true, Utility = false },
        OnEmpty  = "SwapOrReload",
    },
    SilentAim = { Enabled = true, FOV = 2000 },
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
local silentFOV = 2000

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
                local target = getHeadTarget()
                if target then
                    local head = target:FindFirstChild("Head")
                        or target:FindFirstChild("HitboxHead")
                    if head then
                        local look = CFrame.new(ws.CurrentCamera.CFrame.Position, head.Position)
                        local newData = {}
                        newData[utf8.char(1)] = {
                            [utf8.char(0)] = util:EncodeCFrame(look),
                            [utf8.char(1)] = util:EncodeCFrame(look),
                            [utf8.char(2)] = head,
                            [utf8.char(3)] = util:EncodeCFrame(
                                head.CFrame:ToObjectSpace(CFrame.new(head.Position))
                            ),
                        }
                        return oldFireServer(self, oid, action, newData, ...)
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
local function desyncClear() Desync._cframe = nil Desync._mode = "off" end
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

local speedBoostOriginal = getgenv().__MinhoRageSpeedBoost or nil
getgenv().__MinhoRageSpeedBoost = speedBoostOriginal

-- ============================================================
-- Special Skill Cooldowns
-- Slider 75 = original, 0 = instant, 100 = slower
-- ============================================================
local SPECIAL_BASE = 75

local SpecialCooldownOriginals = getgenv().__MinhoSpecialCooldownOriginals or {
    DashCooldown        = nil,
    SpinCooldown        = nil,
    DeflectCooldown     = nil,
    HeavyAttackCooldown = nil,
    AttackCooldown      = nil,
    ShootCooldown       = nil,
}
getgenv().__MinhoSpecialCooldownOriginals = SpecialCooldownOriginals

local function safeToggle(id)
    local t = Toggles and Toggles[id]
    return t ~= nil and t.Value == true
end
local function safeOption(id, default)
    local o = Options and Options[id]
    if o == nil or o.Value == nil then return default end
    return o.Value
end

local function applySpecialCooldowns()
    local ok, lib = pcall(function() return require(ReplicatedStorage.Modules.ItemLibrary) end)
    if not ok or not lib or type(lib.Items) ~= 'table' then return end

    local scytheOn  = safeToggle("ScytheDashToggle")
    local scytheVal = safeOption("ScytheDashSlider", SPECIAL_BASE)
    local axeOn     = safeToggle("AxeSpinToggle")
    local axeVal    = safeOption("AxeSpinSlider", SPECIAL_BASE)
    local katanaOn  = safeToggle("KatanaDeflectToggle")
    local katanaVal = safeOption("KatanaDeflectSlider", SPECIAL_BASE)
    local knifeOn   = safeToggle("KnifeHeavyToggle")
    local knifeVal  = safeOption("KnifeHeavySlider", SPECIAL_BASE)
    local gunOn     = safeToggle("FireCooldownEnabled")
    local gunVal    = safeOption("FireCooldownSlider", SPECIAL_BASE)
    local meleeOn   = safeToggle("MeleeCooldownEnabled")
    local meleeVal  = safeOption("MeleeCooldownSlider", SPECIAL_BASE)

    for _, data in pairs(lib.Items) do
        if type(data) == 'table' then
            if type(data.DashCooldown) == 'number' then
                if SpecialCooldownOriginals.DashCooldown == nil then
                    SpecialCooldownOriginals.DashCooldown = data.DashCooldown
                end
                if scytheOn then
                    data.DashCooldown = math.max(0.001, SpecialCooldownOriginals.DashCooldown * (scytheVal / SPECIAL_BASE))
                else
                    data.DashCooldown = SpecialCooldownOriginals.DashCooldown
                end
            end
            if type(data.SpinCooldown) == 'number' then
                if SpecialCooldownOriginals.SpinCooldown == nil then
                    SpecialCooldownOriginals.SpinCooldown = data.SpinCooldown
                end
                if axeOn then
                    data.SpinCooldown = math.max(0.001, SpecialCooldownOriginals.SpinCooldown * (axeVal / SPECIAL_BASE))
                else
                    data.SpinCooldown = SpecialCooldownOriginals.SpinCooldown
                end
            end
            if type(data.DeflectCooldown) == 'number' then
                if SpecialCooldownOriginals.DeflectCooldown == nil then
                    SpecialCooldownOriginals.DeflectCooldown = data.DeflectCooldown
                end
                if katanaOn then
                    data.DeflectCooldown = math.max(0.001, SpecialCooldownOriginals.DeflectCooldown * (katanaVal / SPECIAL_BASE))
                else
                    data.DeflectCooldown = SpecialCooldownOriginals.DeflectCooldown
                end
            end
            if type(data.HeavyAttackCooldown) == 'number' then
                if SpecialCooldownOriginals.HeavyAttackCooldown == nil then
                    SpecialCooldownOriginals.HeavyAttackCooldown = data.HeavyAttackCooldown
                end
                if knifeOn then
                    data.HeavyAttackCooldown = math.max(0.001, SpecialCooldownOriginals.HeavyAttackCooldown * (knifeVal / SPECIAL_BASE))
                else
                    data.HeavyAttackCooldown = SpecialCooldownOriginals.HeavyAttackCooldown
                end
            end
            if type(data.ShootCooldown) == 'number' then
                if SpecialCooldownOriginals.ShootCooldown == nil then
                    SpecialCooldownOriginals.ShootCooldown = data.ShootCooldown
                end
                if gunOn then
                    data.ShootCooldown = math.max(0.001, SpecialCooldownOriginals.ShootCooldown * (gunVal / SPECIAL_BASE))
                else
                    data.ShootCooldown = SpecialCooldownOriginals.ShootCooldown
                end
            end
            if type(data.AttackCooldown) == 'number' then
                if SpecialCooldownOriginals.AttackCooldown == nil then
                    SpecialCooldownOriginals.AttackCooldown = data.AttackCooldown
                end
                if meleeOn then
                    data.AttackCooldown = math.max(0.001, SpecialCooldownOriginals.AttackCooldown * (meleeVal / SPECIAL_BASE))
                else
                    data.AttackCooldown = SpecialCooldownOriginals.AttackCooldown
                end
            end
        end
    end

    local fighter = getFighter()
    if fighter and type(fighter.Items) == 'table' then
        for _, item in pairs(fighter.Items) do
            local info = itemField(item, "Info")
            if type(info) == 'table' then
                if scytheOn and type(info.DashCooldown) == 'number' and SpecialCooldownOriginals.DashCooldown then
                    info.DashCooldown = math.max(0.001, SpecialCooldownOriginals.DashCooldown * (scytheVal / SPECIAL_BASE))
                end
                if axeOn and type(info.SpinCooldown) == 'number' and SpecialCooldownOriginals.SpinCooldown then
                    info.SpinCooldown = math.max(0.001, SpecialCooldownOriginals.SpinCooldown * (axeVal / SPECIAL_BASE))
                end
                if katanaOn and type(info.DeflectCooldown) == 'number' and SpecialCooldownOriginals.DeflectCooldown then
                    info.DeflectCooldown = math.max(0.001, SpecialCooldownOriginals.DeflectCooldown * (katanaVal / SPECIAL_BASE))
                end
                if knifeOn and type(info.HeavyAttackCooldown) == 'number' and SpecialCooldownOriginals.HeavyAttackCooldown then
                    info.HeavyAttackCooldown = math.max(0.001, SpecialCooldownOriginals.HeavyAttackCooldown * (knifeVal / SPECIAL_BASE))
                end
                if gunOn and type(info.ShootCooldown) == 'number' and SpecialCooldownOriginals.ShootCooldown then
                    info.ShootCooldown = math.max(0.001, SpecialCooldownOriginals.ShootCooldown * (gunVal / SPECIAL_BASE))
                end
                if meleeOn and type(info.AttackCooldown) == 'number' and SpecialCooldownOriginals.AttackCooldown then
                    info.AttackCooldown = math.max(0.001, SpecialCooldownOriginals.AttackCooldown * (meleeVal / SPECIAL_BASE))
                end
            end
        end
    end
end

RageModule.applySpecialCooldowns = applySpecialCooldowns

-- ============================================================
-- Speed Boost
-- ============================================================
local function applySpeedBoost()
    if speedBoostOriginal ~= nil then return end
    local ok, lib = pcall(function() return require(ReplicatedStorage.Modules.ItemLibrary) end)
    if not ok or not lib or not lib.Items then return end
    speedBoostOriginal = {}
    local FIELDS = {
        "ShootCooldown", "ShootBurstCooldown", "ShootRecoil", "ShootSpread",
        "AttackCooldown", "AttackDelay", "SwingCooldown", "MeleeCooldown",
        "Cooldown", "RecoveryTime", "ResetTime", "SwingTime", "SwingDelay",
        "ComboCooldown", "FireCooldown", "ReloadLength",
    }
    local mult = Config.SpeedBoostMult
    for name, data in pairs(lib.Items) do
        if type(data) == "table" then
            local orig = {}
            for _, f in ipairs(FIELDS) do
                if data[f] ~= nil then
                    orig[f] = data[f]
                    if type(data[f]) == "number" then
                        data[f] = data[f] * mult
                    end
                end
            end
            if next(orig) ~= nil then speedBoostOriginal[name] = orig end
        end
    end
    if next(speedBoostOriginal) == nil then speedBoostOriginal = nil end
    getgenv().__MinhoRageSpeedBoost = speedBoostOriginal
end
local function removeSpeedBoost()
    if speedBoostOriginal == nil then return end
    local ok, lib = pcall(function() return require(ReplicatedStorage.Modules.ItemLibrary) end)
    if ok and lib and lib.Items then
        for name, orig in pairs(speedBoostOriginal) do
            local data = lib.Items[name]
            if type(data) == "table" then
                for f, base in pairs(orig) do data[f] = base end
            end
        end
    end
    speedBoostOriginal = nil
    getgenv().__MinhoRageSpeedBoost = nil
end
RageModule.applySpeedBoost = applySpeedBoost
RageModule.removeSpeedBoost = removeSpeedBoost

local function doFire(part)
    local fighter = getFighter()
    local item = fighter and fighter.EquippedItem
    if not item or not part then return false end
    local cam = ws.CurrentCamera
    local fromPos = (Desync._mode == "enemy" and Desync._cframe and Desync._cframe.Position)
        or (cam and cam.CFrame.Position) or part.Position
    local look = CFrame.new(fromPos, part.Position)
    local data = {
        [utf8.char(0)] = util:EncodeCFrame(look),
        [utf8.char(1)] = util:EncodeCFrame(look),
        [utf8.char(2)] = part,
        [utf8.char(3)] = util:EncodeCFrame(part.CFrame:ToObjectSpace(CFrame.new(part.Position))),
    }
    local oid = item:Get("ObjectID")
    local shootEnum = enums:ToEnum("StartShooting")
    if not (oid and shootEnum) then return false end
    return (pcall(function()
        useItemRemote:FireServer(oid, shootEnum, { [utf8.char(1)] = data }, nil)
    end))
end

local function doReload(item)
    item = item or getEquippedItem()
    if not item or isMelee(item) then return end
    pcall(function() item:StartReloading() end)
end

local function getClosestEnemy()
    local root = getRoot()
    if not root then return nil end
    local myEnv = LocalPlayer:GetAttribute("EnvironmentID")
    local myTeam = LocalPlayer:GetAttribute("TeamID")
    local best, bestDist = nil, math.huge
    local myPos = (Desync._oldCFrame or root.CFrame).Position
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            local head = getHead(plr.Character)
            if hum and hum.Health > 0 and head and not isInvincible(plr.Character) then
                local env = plr:GetAttribute("EnvironmentID")
                local team = plr:GetAttribute("TeamID")
                local envOk = (myEnv == nil) or (env == myEnv)
                local teamOk = (myTeam == nil) or (team == nil) or (team ~= myTeam)
                if envOk and teamOk then
                    local d = (head.Position - myPos).Magnitude
                    if d < bestDist then
                        best, bestDist = { Head = head, Character = plr.Character }, d
                    end
                end
            end
        end
    end
    return best
end

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

local undergroundState = getgenv().__MinhoUndergroundState or {
    Active = false,
    Conn = nil,
    NoclipConn = nil,
    GroundY = nil,
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

if RageModule._heartbeatConn then
    pcall(function() RageModule._heartbeatConn:Disconnect() end)
end

RageModule._heartbeatConn = RunService.Heartbeat:Connect(function(dt)
    if not Config.Enabled then
        if speedBoostOriginal then removeSpeedBoost() end
        desyncClear()
        return
    end

    if speedBoostOriginal == nil then applySpeedBoost() end

    pcall(applySpecialCooldowns)

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

        local targetPos = head.Position + Vector3.new(0, Config.HitAboveY, 0)
        desyncSetEnemy(CFrame.new(targetPos))
        desyncPush(root)
        if doFire(head) then
            meleeCount += 1
            if now - lastMeleeAt > 0.3 then
                lastMeleeAt = now
                notify(string.format("Melee attacking (%d hits)", meleeCount), 1)
            end
        end
        return
    end

    local targetPos = head.Position + Vector3.new(0, Config.HitAboveY, 0)
    desyncSetEnemy(CFrame.new(targetPos))
    desyncPush(root)
    if doFire(head) then
        if now - lastAttachAt > 1 then
            lastAttachAt = now
            notify("Attach -> fire", 1)
        end
    end
end)

-- ============================================================
-- UI
-- ============================================================
local RageBox   = Main:AddGroupbox({ Name = "Ragebot", Side = 1 })
local WCBox     = Main:AddGroupbox({ Name = "Weapon Config", Side = 1 })
local WBox      = Main:AddGroupbox({ Name = "Weapon", Side = 1 })
local OffBox    = Main:AddGroupbox({ Name = "Offsets", Side = 2 })
local RBox      = Main:AddGroupbox({ Name = "Rage", Side = 2 })
local SCBox     = Main:AddGroupbox({ Name = "Speed Control", Side = 2 })

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

WCBox:AddLabel("Priority (top uses first)")
local ALL_CLASSES = { "Primary", "Secondary", "Melee" }
local function makeRankDropdown(label, default, key)
    return WCBox:AddDropdown("Rank_" .. key, {
        Text = label, Values = ALL_CLASSES, Default = default, Multi = false,
        Callback = function(v) Config.Weapons.Priority[key] = v end,
    })
end
makeRankDropdown("Priority 1", "Primary", 1)
makeRankDropdown("Priority 2", "Secondary", 2)
makeRankDropdown("Priority 3", "Melee", 3)

WCBox:AddLabel("Weapon Types to Use")
WCBox:AddCheckbox("Enabled_Primary", {
    Text = "Use Primary", Default = true,
    Callback = function(v) Config.Weapons.Enabled.Primary = v end })
WCBox:AddCheckbox("Enabled_Secondary", {
    Text = "Use Secondary", Default = true,
    Callback = function(v) Config.Weapons.Enabled.Secondary = v end })
WCBox:AddCheckbox("Enabled_Melee", {
    Text = "Use Melee", Default = true,
    Callback = function(v) Config.Weapons.Enabled.Melee = v end })
WCBox:AddCheckbox("Enabled_Utility", {
    Text = "Use Utility", Default = false,
    Callback = function(v) Config.Weapons.Enabled.Utility = v end })

WBox:AddDropdown("OnEmptyAmmo", {
    Text = "On Empty Ammo",
    Values = { "Swap or Reload", "Reload Only", "Swap Only" },
    Default = "Swap or Reload", Multi = false,
    Callback = function(v)
        if v == "Reload Only" then Config.Weapons.OnEmpty = "Reload"
        elseif v == "Swap Only" then Config.Weapons.OnEmpty = "Swap"
        else Config.Weapons.OnEmpty = "SwapOrReload" end
    end,
})

OffBox:AddSlider("HitAboveY", {
    Text = "Hit Above Y", Default = 0.5, Min = -5, Max = 5,
    Rounding = 2, Suffix = " studs",
    Callback = function(v) Config.HitAboveY = v end })
OffBox:AddSlider("SpeedBoost", {
    Text = "Speed Boost Mult (0 = instant)", Default = 0, Min = 0, Max = 1,
    Rounding = 2,
    Callback = function(v)
        Config.SpeedBoostMult = v
        removeSpeedBoost()
    end })

local UERage_Toggle = RBox:AddToggle("UEAssistedRage", {
    Text = "UE Assisted Rage", Default = false,
    Callback = function(Value)
        setUERage(Value)
    end
})
UERage_Toggle:AddKeyPicker("UERageKey", {
    Text = "UE Assisted Rage", Default = nil, Mode = "Toggle", SyncToggleState = true,
})

local Underground_Toggle = RBox:AddToggle("Underground", {
    Text = "Underground", Default = false,
    Callback = function(Value)
        if Value then
            startUnderground()
        else
            stopUnderground()
        end
    end
})
Underground_Toggle:AddKeyPicker("UndergroundKey", {
    Text = "Underground", Default = nil, Mode = "Toggle", SyncToggleState = true,
})

-- ============================================================
-- Speed Control
-- ============================================================
SCBox:AddCheckbox("Recoil", {
    Text = "Recoil", Default = false,
    Callback = function(Value)
        if Value then
            Config.SpeedBoostMult = 0
            local ok, lib = pcall(function() return require(ReplicatedStorage.Modules.ItemLibrary) end)
            if ok and lib and lib.Items then
                for name, data in pairs(lib.Items) do
                    if type(data) == "table" then
                        if data.ShootSpread  then data.ShootSpread  = 0 end
                        if data.ShootAccuracy then data.ShootAccuracy = 0 end
                        if data.ShootRecoil  then data.ShootRecoil  = 0 end
                        if data.ShootCooldown then data.ShootCooldown = 0.001 end
                        if data.ShootBurstCooldown then data.ShootBurstCooldown = 0.001 end
                    end
                end
            end
        end
    end
})

SCBox:AddCheckbox("NoSpread", { Text = "No Spread", Default = false })

-- Fire Cooldown (Guns) - toggle + hidden slider
SCBox:AddCheckbox("FireCooldownEnabled", {
    Text = "Fire Cooldown (Guns)",
    Default = false,
    Tooltip = "Controls all gun fire rate. Slider 75 = original, 0 = instant.",
    Callback = function()
        if RageModule.applySpecialCooldowns then RageModule.applySpecialCooldowns() end
    end,
})
local FireCooldownBox = SCBox:AddDependencyBox()
FireCooldownBox:AddSlider("FireCooldownSlider", {
    Default = 75, Min = 0, Max = 100, Rounding = 0, Compact = true,
    Callback = function()
        if RageModule.applySpecialCooldowns then RageModule.applySpecialCooldowns() end
    end,
})
FireCooldownBox:SetupDependencies({ { Toggles.FireCooldownEnabled, true } })

-- Melee Cooldown (Melee) - toggle + hidden slider
SCBox:AddCheckbox("MeleeCooldownEnabled", {
    Text = "Melee Cooldown (Melee)",
    Default = false,
    Tooltip = "Controls all melee attack speed. Slider 75 = original, 0 = instant.",
    Callback = function()
        if RageModule.applySpecialCooldowns then RageModule.applySpecialCooldowns() end
    end,
})
local MeleeCooldownBox = SCBox:AddDependencyBox()
MeleeCooldownBox:AddSlider("MeleeCooldownSlider", {
    Default = 75, Min = 0, Max = 100, Rounding = 0, Compact = true,
    Callback = function()
        if RageModule.applySpecialCooldowns then RageModule.applySpecialCooldowns() end
    end,
})
MeleeCooldownBox:SetupDependencies({ { Toggles.MeleeCooldownEnabled, true } })

-- Scythe Dash
SCBox:AddCheckbox("ScytheDashToggle", {
    Text = "Scythe Dash",
    Default = false,
    Tooltip = "Controls Scythe dash cooldown. Slider 75 = original, 0 = instant.",
    Callback = function()
        if RageModule.applySpecialCooldowns then RageModule.applySpecialCooldowns() end
    end,
})
local ScytheDashBox = SCBox:AddDependencyBox()
ScytheDashBox:AddSlider("ScytheDashSlider", {
    Default = 75, Min = 0, Max = 100, Rounding = 0, Compact = true,
    Callback = function()
        if RageModule.applySpecialCooldowns then RageModule.applySpecialCooldowns() end
    end,
})
ScytheDashBox:SetupDependencies({ { Toggles.ScytheDashToggle, true } })

-- Battle Axe Spin
SCBox:AddCheckbox("AxeSpinToggle", {
    Text = "Battle Axe Dash",
    Default = false,
    Tooltip = "Controls Battle Axe spin cooldown. Slider 75 = original, 0 = instant.",
    Callback = function()
        if RageModule.applySpecialCooldowns then RageModule.applySpecialCooldowns() end
    end,
})
local AxeSpinBox = SCBox:AddDependencyBox()
AxeSpinBox:AddSlider("AxeSpinSlider", {
    Default = 75, Min = 0, Max = 100, Rounding = 0, Compact = true,
    Callback = function()
        if RageModule.applySpecialCooldowns then RageModule.applySpecialCooldowns() end
    end,
})
AxeSpinBox:SetupDependencies({ { Toggles.AxeSpinToggle, true } })

-- Katana Deflect
SCBox:AddCheckbox("KatanaDeflectToggle", {
    Text = "Katana Deflect",
    Default = false,
    Tooltip = "Controls Katana deflect cooldown. Slider 75 = original, 0 = instant.",
    Callback = function()
        if RageModule.applySpecialCooldowns then RageModule.applySpecialCooldowns() end
    end,
})
local KatanaDeflectBox = SCBox:AddDependencyBox()
KatanaDeflectBox:AddSlider("KatanaDeflectSlider", {
    Default = 75, Min = 0, Max = 100, Rounding = 0, Compact = true,
    Callback = function()
        if RageModule.applySpecialCooldowns then RageModule.applySpecialCooldowns() end
    end,
})
KatanaDeflectBox:SetupDependencies({ { Toggles.KatanaDeflectToggle, true } })

-- Knife Heavy
SCBox:AddCheckbox("KnifeHeavyToggle", {
    Text = "Knife Heavy Attack",
    Default = false,
    Tooltip = "Controls Knife heavy attack cooldown. Slider 75 = original, 0 = instant.",
    Callback = function()
        if RageModule.applySpecialCooldowns then RageModule.applySpecialCooldowns() end
    end,
})
local KnifeHeavyBox = SCBox:AddDependencyBox()
KnifeHeavyBox:AddSlider("KnifeHeavySlider", {
    Default = 75, Min = 0, Max = 100, Rounding = 0, Compact = true,
    Callback = function()
        if RageModule.applySpecialCooldowns then RageModule.applySpecialCooldowns() end
    end,
})
KnifeHeavyBox:SetupDependencies({ { Toggles.KnifeHeavyToggle, true } })

task.defer(function()
    if RageModule.applySpecialCooldowns then
        pcall(RageModule.applySpecialCooldowns)
    end
end)

return true

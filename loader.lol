--!nonstrict
local BASE = "https://raw.githubusercontent.com/jixyuk12nh-maker/sodhEjwvKdbIdhw/refs/heads/main"

local function load(url)
    local ok, src = pcall(game.HttpGet, game, url)
    if not ok or not src then
        warn("[loader] Failed to fetch: " .. url)
        return nil
    end
    local ok2, fn = pcall(loadstring, src)
    if not ok2 or not fn then
        warn("[loader] Failed to compile: " .. url)
        return nil
    end
    local ok3, result = pcall(fn)
    if not ok3 then
        warn("[loader] Failed to run: " .. url .. " — " .. tostring(result))
        return nil
    end
    return result
end

_G.MinhoHub = _G.MinhoHub or {}
local Hub = _G.MinhoHub
Hub.BASE = BASE

Hub.Library      = load(BASE .. "/Minho_Hub_Obsidian_UI.lua")
Hub.ThemeManager = load(BASE .. "/ThemeManager.lua")
Hub.SaveManager  = load(BASE .. "/SaveManager.lua")

if not Hub.Library then
    warn("[loader] Library failed to load — aborting")
    return
end

if Hub.ThemeManager then Hub.ThemeManager:SetLibrary(Hub.Library) end
if Hub.SaveManager and type(Hub.SaveManager) == "function" then
    local ok, instance = pcall(Hub.SaveManager)
    if ok then Hub.SaveManager = instance end
end
if Hub.SaveManager and Hub.SaveManager.SetLibrary then
    Hub.SaveManager:SetLibrary(Hub.Library)
end

Hub.Window = Hub.Library:CreateWindow({
    Title = "Minho Hub",
    Footer = "Discord.gg/minho-hub",
    Size = UDim2.fromOffset(1000, 550),
    ToggleKeybind = Enum.KeyCode.RightControl,
})

Hub.Tabs = {
    Main      = Hub.Window:AddTab("Main", "house"),
    World     = Hub.Window:AddTab("World", "globe"),
    Visuals   = Hub.Window:AddTab("Visuals", "eye"),
    Character = Hub.Window:AddTab("Character", "user"),
    Cosmetics = Hub.Window:AddTab("Cosmetics", "shirt"),
    Misc      = Hub.Window:AddTab("Misc", "settings"),
    Settings  = Hub.Window:AddTab("Settings", "settings-2"),
}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst   = game:GetService("ReplicatedFirst")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local SoundService      = game:GetService("SoundService")
local Lighting          = game:GetService("Lighting")
local Debris            = game:GetService("Debris")
local LocalPlayer       = Players.LocalPlayer
local ws                = workspace

Hub.Players           = Players
Hub.ReplicatedStorage = ReplicatedStorage
Hub.ReplicatedFirst   = ReplicatedFirst
Hub.UserInputService  = UserInputService
Hub.RunService        = RunService
Hub.SoundService      = SoundService
Hub.Lighting          = Lighting
Hub.Debris            = Debris
Hub.LocalPlayer       = LocalPlayer
Hub.ws                = ws
Hub.RIVALS_GAMEID     = 6035872082

local cloneref = cloneref or function(o) return o end
Hub.cloneref = cloneref
Hub._identity = getthreadidentity and getthreadidentity() or 8

task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    local player = Players.LocalPlayer
    while not player do
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        player = Players.LocalPlayer
    end
    local playerGui = player:WaitForChild("PlayerGui")
    local coreGui   = game:GetService("CoreGui")
    local function isLoadingGui(o)
        local n = o.Name:lower():gsub("[%s_%-]", "")
        if not n:find("loadingscreen", 1, true) then return false end
        local cur = o
        while cur and cur ~= playerGui and cur ~= coreGui do
            if cur:IsA("LayerCollector") and not cur.Enabled then return false end
            if cur:IsA("GuiObject") and not cur.Visible then return false end
            cur = cur.Parent
        end
        return true
    end
    local clearSince
    repeat
        local loading = false
        for _, root in ipairs({playerGui, coreGui}) do
            for _, o in ipairs(root:GetDescendants()) do
                if isLoadingGui(o) then loading = true break end
            end
            if loading then break end
        end
        clearSince = loading and nil or (clearSince or os.clock())
        task.wait(0.1)
    until clearSince and os.clock() - clearSince >= 0.5
end)

if not getgenv().__MinhoStartupHooks then
    getgenv().__MinhoStartupHooks = true
    if setthreadidentity then pcall(setthreadidentity, 8) end

    local okEnv, renv = pcall(getrenv)
    local realSetmetatable = okEnv and renv and renv.setmetatable
    if hookfunction and realSetmetatable then
        local oldSM = realSetMetatable
        pcall(hookfunction, realSetMetatable, newcclosure(function(T, MT)
            if MT and type(MT) == "table" and rawget(MT, "__mode") then
                local m = rawget(MT, "__mode")
                if m == "kv" or m == "v" or m == "k" then
                    local okT, tr = pcall(debug.traceback)
                    if okT and (tr:find("MiscellaneousController", 1, true)
                        or tr:find("CameraSecurity", 1, true)
                        or tr:find("AnalyticsPipelineController", 1, true)) then
                        return oldSM({1, 2, 3}, {})
                    end
                end
            end
            return oldSM(T, MT)
        end))
    end

    local okPlr, lp = pcall(function()
        return cloneref(game:GetService("Players")).LocalPlayer
    end)
    if okPlr and lp and hookfunction then
        pcall(function()
            local oldKick
            oldKick = hookfunction(lp.Kick, newcclosure(function(self, ...)
                if self == lp then return nil end
                return oldKick(self, ...)
            end))
        end)
        pcall(function()
            local oldGetMouse
            oldGetMouse = hookfunction(lp.GetMouse, newcclosure(function(self, ...)
                if self == lp then
                    local okT, tr = pcall(debug.traceback)
                    if okT and tr:find("MiscellaneousController", 1, true) then
                        local realMouse = oldGetMouse(self, ...)
                        local fake = {}
                        setmetatable(fake, {
                            __index = function(_, key)
                                if key == "X" or key == "Y" then
                                    local loc = UserInputService:GetMouseLocation()
                                    return key == "X" and loc.X or loc.Y
                                end
                                local v = realMouse[key]
                                if type(v) == "function" then
                                    return function(_, ...) return v(realMouse, ...) end
                                end
                                return v
                            end,
                            __newindex = function(_, k, v) realMouse[k] = v end,
                        })
                        return fake
                    end
                end
                return oldGetMouse(self, ...)
            end))
        end)
    end
end

pcall(function()
    local lp = cloneref(game:GetService("Players")).LocalPlayer
    local camSec = require(lp.PlayerScripts.Modules.CameraSecurity)
    local mt = getrawmetatable(camSec)
    mt.__index    = function() return nil end
    mt.__tostring = function() return "LocalPlayer = nil" end
    mt.__newindex = function(E, G, V) return rawset(E, G, V) end
end)

task.spawn(function()
    local ServerPing = workspace:WaitForChild("ServerPing", 30)
    if not ServerPing then return end
    local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local PingRemote = Remotes and Remotes:FindFirstChild("Ping")
    while task.wait(12 * math.random()) do
        local rnd = math.random(1, 9999)
        local value = (rnd == 6961) and 2137 or (rnd == ServerPing.Value) and 2138 or rnd
        if PingRemote then
            pcall(function() PingRemote:FireServer(value) end)
        end
    end
end)

for _, svc in pairs({Players, workspace, ReplicatedStorage, ReplicatedFirst}) do
    pcall(function() svc.Name = svc.Name .. " " end)
end

task.spawn(function()
    local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
    if not Modules then return end
    local UtilityMod = Modules:WaitForChild("Utility", 10)
    if not UtilityMod then return end
    local Utility = require(UtilityMod)

    if hookfunction and type(Utility.IsWithinPart) == "function" then
        local oldPart = Utility.IsWithinPart
        Utility.IsWithinPart = newcclosure(function(...)
            if shared.RagebotActive then
                for _, v in ipairs({...}) do
                    if typeof(v) == "Instance" and v:IsA("BasePart") then
                        local n = string.lower(v.Name)
                        if n:find("map") or n:find("bound") or n:find("safe") then
                            return true
                        end
                    end
                end
                return false
            end
            return oldPart(...)
        end)
    end

    if hookfunction and type(Utility.IsWithinTaggedParts) == "function" then
        local oldTagged = Utility.IsWithinTaggedParts
        Utility.IsWithinTaggedParts = newcclosure(function(self, tag, pos, size, returnAll)
            if shared.RagebotActive and type(tag) == "string" then
                local lt = string.lower(tag)
                if lt:find("map") or lt:find("bound") or lt:find("safe") then
                    return returnAll and {workspace.Terrain} or workspace.Terrain
                end
                return returnAll and {} or nil
            end
            return oldTagged(self, tag, pos, size, returnAll)
        end)
    end
end)

local co = coroutine.create(function()
    load(BASE .. "/tabs/main.lua")
    load(BASE .. "/tabs/world.lua")
    load(BASE .. "/tabs/visuals.lua")
    load(BASE .. "/tabs/character.lua")
    load(BASE .. "/tabs/cosmetics.lua")
    load(BASE .. "/tabs/misc.lua")
    load(BASE .. "/tabs/settings.lua")
end)
local ok, err = coroutine.resume(co)
if not ok then warn("[loader] Tab loading error: " .. tostring(err)) end

print("[Minho Hub] All tabs loaded")
return true

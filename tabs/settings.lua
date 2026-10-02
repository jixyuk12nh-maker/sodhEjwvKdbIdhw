--!nonstrict
local Hub = _G.MinhoHub
if not Hub then return end

local Settings = Hub.Tabs.Settings
local LocalPlayer = Hub.LocalPlayer

local AUTOEXEC_PATH = "MinhoHub/autoexec.json"

local function ensureFolder()
    if not (isfolder and makefolder) then return end
    if not isfolder("MinhoHub") then
        pcall(makefolder, "MinhoHub")
    end
end

local function loadAutoExecFlag()
    if not (isfile and readfile) then return false end
    if not isfile(AUTOEXEC_PATH) then return false end
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(readfile(AUTOEXEC_PATH))
    end)
    if ok and type(data) == "table" and data.enabled == true then
        return true
    end
    return false
end

local function saveAutoExecFlag(enabled)
    if not writefile then return end
    ensureFolder()
    pcall(function()
        writefile(AUTOEXEC_PATH, game:GetService("HttpService"):JSONEncode({ enabled = enabled == true }))
    end)
end

local function runAutoLoad()
    if Hub.Modules and Hub.Modules["auto load"] then
        local mod = Hub.Modules["auto load"]
        if mod.Toggle then
            pcall(function() mod:Toggle(true) end)
        end
    end
end

local SettingsBox = Settings:AddGroupbox({ Name = "Keybinds", Side = 1 })

SettingsBox:AddCheckbox("ShowKeybindsWindow", {
    Text = "Show Keybinds Window",
    Default = false,
    Callback = function(Value)
        if Hub.Library.KeybindFrame then
            Hub.Library.KeybindFrame.Visible = Value
        end
    end
})

SettingsBox:AddCheckbox("AutoExecute", {
    Text = "Auto Execute",
    Default = false,
    Callback = function(Value)
        saveAutoExecFlag(Value)
        if Value then
            runAutoLoad()
        end
    end
})

if Hub.SaveManager then
    Hub.SaveManager:SetLibrary(Hub.Library)
    Hub.SaveManager:BuildConfigSection(Settings, "folder-cog")
    Hub.SaveManager:LoadAutoloadConfig()
end

if loadAutoExecFlag() then
    task.defer(function()
        task.wait(1)
        runAutoLoad()
    end)
end

LocalPlayer.AncestryChanged:Connect(function()
    if not LocalPlayer:IsDescendantOf(game) then
        if Hub.stopNoclip then pcall(Hub.stopNoclip) end
        if Hub.cleanupFly then pcall(Hub.cleanupFly) end
        if Hub.stopThirdPerson then pcall(Hub.stopThirdPerson) end
        if Hub.stopAnimation then pcall(Hub.stopAnimation) end
        if Hub.uninstallKillSoundSystem then pcall(Hub.uninstallKillSoundSystem) end
        if Hub.uninstallHitSound then pcall(Hub.uninstallHitSound) end
        if Hub.stopUnderground then pcall(Hub.stopUnderground) end
        pcall(function()
            if Hub.RageModule and Hub.RageModule.destroyScatterBody then
                Hub.RageModule.destroyScatterBody()
            end
            if Hub.RageModule and Hub.RageModule.removeSpeedBoost then
                Hub.RageModule.removeSpeedBoost()
            end
        end)
    end
end)

return true

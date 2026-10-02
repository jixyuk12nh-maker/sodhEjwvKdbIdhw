--!nonstrict
local Hub = _G.MinhoHub
if not Hub then return end

local Settings = Hub.Tabs.Settings
local LocalPlayer = Hub.LocalPlayer

local AUTOEXEC_PATH = "MinhoHub/autoexec.json"

local function loadAutoExecState()
    if not (isfile and readfile) then return {} end
    if not isfile(AUTOEXEC_PATH) then return {} end
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(readfile(AUTOEXEC_PATH))
    end)
    return ok and type(data) == "table" and data or {}
end

local function saveAutoExecState()
    if not writefile then return end
    local enabled = {}
    if Hub.Library and Hub.Library.Toggles then
        for name, toggle in pairs(Hub.Library.Toggles) do
            if type(toggle) == "table" and toggle.Value == true then
                enabled[name] = true
            end
        end
    end
    pcall(function()
        writefile(AUTOEXEC_PATH, game:GetService("HttpService"):JSONEncode(enabled))
    end)
end

local function applyAutoExecState()
    local state = loadAutoExecState()
    if not next(state) then return end
    if not Hub.Library or not Hub.Library.Toggles then return end
    for name, _ in pairs(state) do
        local toggle = Hub.Library.Toggles[name]
        if type(toggle) == "table" and toggle.SetValue then
            pcall(function() toggle:SetValue(true) end)
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
        if Value then
            saveAutoExecState()
            if Hub.Library and Hub.Library.Toggles then
                for _, toggle in pairs(Hub.Library.Toggles) do
                    if type(toggle) == "table" and toggle.ValueChanged then
                        toggle.ValueChanged:Connect(function()
                            task.delay(0.5, saveAutoExecState)
                        end)
                    end
                end
            end
        else
            if delfile and isfile and isfile(AUTOEXEC_PATH) then
                pcall(delfile, AUTOEXEC_PATH)
            end
        end
    end
})

task.spawn(function()
    task.wait(1)
    applyAutoExecState()
end)

if Hub.SaveManager then
    Hub.SaveManager:SetLibrary(Hub.Library)
    Hub.SaveManager:BuildConfigSection(Settings, "folder-cog")
    Hub.SaveManager:LoadAutoloadConfig()
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

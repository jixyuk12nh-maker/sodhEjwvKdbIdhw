--!nonstrict
local Hub = _G.MinhoHub
if not Hub then return end

local Settings = Hub.Tabs.Settings
local LocalPlayer = Hub.LocalPlayer

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

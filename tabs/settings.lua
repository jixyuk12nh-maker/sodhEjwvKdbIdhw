--!nonstrict
local Hub = _G.MinhoHub
if not Hub then return end

local Settings = Hub.Tabs.Settings
local LocalPlayer = Hub.LocalPlayer

--============================================================--
-- SILENT LOAD: UI가 준비될 때까지 조용히 대기
--============================================================--
if Hub.Library and Hub.Library.Window and Hub.Library.Window.MainFrame then
    Hub.Library.Window.MainFrame.Visible = false
    if Hub.Library.Toggled then
        Hub.Library.Toggled = false
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

--============================================================--
-- AUTO LOAD: SaveManager로 저장된 설정 자동 로드
--============================================================--
if Hub.SaveManager then
    Hub.SaveManager:SetLibrary(Hub.Library)
    Hub.SaveManager:BuildConfigSection(Settings, "folder-cog")
    Hub.SaveManager:LoadAutoloadConfig()
end

--============================================================--
-- AUTO EXECUTE: autoexec 폴더의 스크립트 자동 실행
--============================================================--
do
    local AUTOEXEC_FOLDER = "MinhoHub/autoexec"

    local function ensureFolder(path)
        if not (isfolder and makefolder) then return false end
        if not isfolder(path) then
            local segments = path:split("/")
            local built = ""
            for _, seg in ipairs(segments) do
                built = built == "" and seg or (built .. "/" .. seg)
                if not isfolder(built) then
                    pcall(makefolder, built)
                end
            end
        end
        return isfolder(path)
    end

    local function runAutoexec()
        if not (listfiles and readfile and loadstring) then return end
        if not ensureFolder(AUTOEXEC_FOLDER) then return end

        local files = listfiles(AUTOEXEC_FOLDER)
        if not files or #files == 0 then return end

        for _, file in ipairs(files) do
            if file:match("%.lua$") then
                task.spawn(function()
                    local ok, err = pcall(function()
                        local chunk = loadstring(readfile(file))
                        if chunk then chunk() end
                    end)
                    if not ok then
                        warn("[MinhoHub autoexec] " .. file .. ": " .. tostring(err))
                    end
                end)
                task.wait(0.1)
            end
        end
    end

    task.spawn(runAutoexec)
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

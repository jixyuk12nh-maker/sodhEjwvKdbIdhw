run(function()
    local AutoLoad, Loadout
    local AutoSelect
    local Mode, Mode2, Mode3, Mode4
    local loadoutLoopRunning = false

    local StarterPlayer = cloneref(game:GetService('StarterPlayer'))

    local weaponsFolder = StarterPlayer.StarterPlayerScripts.Assets.ViewModels.Weapons
    local unobtainableFolder = weaponsFolder.Unobtainable

    local weaponList = {}

    for _,v in pairs(weaponsFolder:GetChildren()) do
        if v:IsA("Model") then
            table.insert(weaponList, v.Name)
        end
    end

    for _,v in pairs(unobtainableFolder:GetChildren()) do
        if v:IsA("Model") then
            table.insert(weaponList, v.Name)
        end
    end

    local function pickLoadout()
        local args = {{
            Mode.Value,
            Mode2.Value,
            Mode3.Value,
            Mode4.Value
        }}

        ReplicatedStorage.Remotes.Replication.Fighter.PickWeapons:FireServer(unpack(args))
    end

    local function runLoadoutLoop(active)
        if active then
            if loadoutLoopRunning then return end
            loadoutLoopRunning = true
            task.spawn(function()
                while (AutoLoad and AutoLoad.Enabled) or (AutoSelect and AutoSelect.Enabled) do
                    pcall(pickLoadout)
                    task.wait(0.5)
                end
                loadoutLoopRunning = false
            end)
        end
    end

    AutoLoad = Other:AddModule({
        Name = "auto load",
        Function = function(callback)
            runLoadoutLoop(callback)
        end
    })

    Loadout = Other:AddModule({
        Name = "loadout",
        HideEnabled = true
    })

    AutoSelect = Loadout:AddToggle({
        Name = "auto select",
        Function = function(callback)
            runLoadoutLoop(callback)
        end
    })

    Mode = Loadout:AddDropdown2({
        Name = "primary",
        List = weaponList,
        Default = "Assault Rifle",
        Function = function()
            if not (AutoLoad and AutoLoad.Enabled) and not (AutoSelect and AutoSelect.Enabled) then
                pcall(pickLoadout)
            end
        end
    })

    Mode2 = Loadout:AddDropdown2({
        Name = "secondary",
        List = weaponList,
        Default = "Handgun",
        Function = function()
            if not (AutoLoad and AutoLoad.Enabled) and not (AutoSelect and AutoSelect.Enabled) then
                pcall(pickLoadout)
            end
        end
    })

    Mode3 = Loadout:AddDropdown2({
        Name = "melee",
        List = weaponList,
        Default = "Fists",
        Function = function()
            if not (AutoLoad and AutoLoad.Enabled) and not (AutoSelect and AutoSelect.Enabled) then
                pcall(pickLoadout)
            end
        end
    })

    Mode4 = Loadout:AddDropdown2({
        Name = "utility",
        List = weaponList,
        Default = "Grenade",
        Function = function()
            if not (AutoLoad and AutoLoad.Enabled) and not (AutoSelect and AutoSelect.Enabled) then
                pcall(pickLoadout)
            end
        end
    })
end)

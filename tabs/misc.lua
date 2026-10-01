--!nonstrict
local Hub = _G.MinhoHub
if not Hub then return end

local Misc = Hub.Tabs.Misc
local Config = Hub.RageConfig

if not Config then
    warn("[misc] RageConfig not found")
    return true
end

local MiscPickupBox = Misc:AddGroupbox({ Name = "Auto Pickup", Side = 1 })

MiscPickupBox:AddCheckbox("AutoPickupEnabled", {
    Text = "Auto Pickup Enabled", Default = true,
    Callback = function(v) Config.AutoPickup.Enabled = v end })

MiscPickupBox:AddCheckbox("PickupHealth", {
    Text = "Health Items", Default = true,
    Callback = function(v) Config.AutoPickup.Health = v end })

MiscPickupBox:AddCheckbox("PickupAmmo", {
    Text = "Ammo Items", Default = true,
    Callback = function(v) Config.AutoPickup.Ammo = v end })

MiscPickupBox:AddSlider("AutoPickupRange", {
    Text = "Pickup Range", Default = 250, Min = 50, Max = 500, Rounding = 0,
    Suffix = " studs",
    Callback = function(v) Config.AutoPickup.Range = v end })

return true

--!nonstrict
local Hub = _G.MinhoHub
if not Hub then return end

local Players           = Hub.Players
local RunService        = Hub.RunService
local SoundService      = Hub.SoundService
local Debris            = Hub.Debris
local UserInputService  = Hub.UserInputService
local LocalPlayer       = Hub.LocalPlayer
local Visuals           = Hub.Tabs.Visuals

local CONFIG = {
Enabled = true,
MaxDistance = 500,
RefreshInterval = 30,
TextHeightRatio = 0.5,
OffsetX = 6,
TextColor = Color3.fromRGB(255, 255, 255),
NameColor = Color3.fromRGB(255, 255, 255),
MinTextSize = 8,
MaxTextSize = 40,
ShowBox = false,
BoxColor = Color3.fromRGB(255, 255, 255),
BoxThickness = 2,
BoxTransparency = 0,
BoxOutline = true,
ShowSkeleton = false,
SkeletonColor = Color3.fromRGB(255, 255, 255),
SkeletonThickness = 2,
SkeletonTransparency = 0,
SkeletonOutline = true,
ShowHealth = false,
HealthColor = Color3.fromRGB(0, 255, 0),
HealthLow = Color3.fromRGB(255, 0, 0),
ShowName = false,
ShowDistance = false,
ShowWeapon = false,
WeaponColor = Color3.fromRGB(255, 200, 100),
ShowLevel = false,
ShowELO = false,
ShowStreak = false,
}
Hub.ESP_CONFIG = CONFIG

local TIERS = {
{ min = 0, name = "Unranked" },{ min = 1, name = "Bronze 1" },
{ min = 200, name = "Bronze 2" },{ min = 400, name = "Bronze 3" },
{ min = 600, name = "Silver 1" },{ min = 800, name = "Silver 2" },
{ min = 1000, name = "Silver 3" },{ min = 1200, name = "Gold 1" },
{ min = 1400, name = "Gold 2" },{ min = 1600, name = "Gold 3" },
{ min = 1800, name = "Platinum 1" },{ min = 2000, name = "Platinum 2" },
{ min = 2200, name = "Platinum 3" },{ min = 2400, name = "Diamond 1" },
{ min = 2600, name = "Diamond 2" },{ min = 2800, name = "Diamond 3" },
{ min = 3000, name = "Onyx 1" },{ min = 3200, name = "Onyx 2" },
{ min = 3400, name = "Onyx 3" },{ min = 3600, name = "Nemesis" },
}

local LeaderboardCache = {}

local function refreshLeaderboard()
local ok, ctrl = pcall(function()
return require(LocalPlayer.PlayerScripts.Controllers.LeaderboardController)
end)
if not ok or not ctrl then return end
local serials = ctrl.LeaderboardSerials
if not serials then return end

local newCache = {}
local function ingest(boardName, rankKey)
local board = serials[boardName]
if not board or not board.Players then return end
for rank, data in pairs(board.Players) do
if type(data) == "table" and data.key and type(rank) == "number" then
local userId = data.key
if not newCache[userId] then newCache[userId] = {} end
newCache[userId][rankKey] = rank
if rankKey == "eloRank" then newCache[userId].elo = data.value end
end
end
end

ingest("Highest ELO", "eloRank")
ingest("Highest Level", "levelRank")
ingest("Current Highest Win Streak", "streakRank")
LeaderboardCache = newCache
end

task.spawn(function()
task.wait(5)
while true do
pcall(refreshLeaderboard)
task.wait(CONFIG.RefreshInterval)
end
end)

local function getTierName(elo, userId)
if userId then
local lb = LeaderboardCache[userId]
if lb and lb.eloRank then
if lb.eloRank >= 1 and lb.eloRank <= 200 then return "Archnemesis" end
if lb.eloRank >= 201 and lb.eloRank <= 250 then return "Nemesis" end
end
end
if type(elo) ~= "number" then return nil end
local name = TIERS[1].name
for _, t in ipairs(TIERS) do
if elo >= t.min then name = t.name end
end
return name
end

local function withRank(value, rank)
if value == nil then return "?" end
local text = tostring(math.floor(value))
if type(rank) == "number" and rank > 0 then
text = text .. " (#" .. rank .. ")"
end
return text
end

local ATTR_LEVEL = "Level"
local ATTR_ELO = "DisplayELO"
local ATTR_STREAK = "StatisticDuelsWinStreak"
local ATTR_TEAM = "TeamID"
local ATTR_ENV = "EnvironmentID"

local function getAttr(inst, name)
if not inst then return nil end
local ok, v = pcall(function() return inst:GetAttribute(name) end)
return ok and v or nil
end

local function vec2floor(v)
return Vector2.new(math.floor(v.X), math.floor(v.Y))
end

local FONT_ID = "rbxassetid://12187365364"
local Fonts = {
Main = Font.new(FONT_ID, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
}

local gui = Instance.new("ScreenGui")
gui.Name = "RivalsTierESP"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
pcall(function() gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling end)
pcall(function() gui.DisplayOrder = 999 end)

local parentOk = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not parentOk or not gui.Parent then
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local function makeLabel(color, align)
local lbl = Instance.new("TextLabel")
lbl.BackgroundTransparency = 1
lbl.BorderSizePixel = 0
lbl.Size = UDim2.fromOffset(0, 0)
lbl.AutomaticSize = Enum.AutomaticSize.XY
lbl.AnchorPoint = Vector2.new(0, 0)
lbl.TextSize = 14
lbl.FontFace = Fonts.Main
lbl.TextColor3 = color or CONFIG.TextColor
lbl.TextStrokeTransparency = 0
lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
lbl.TextXAlignment = align or Enum.TextXAlignment.Left
lbl.TextYAlignment = Enum.TextYAlignment.Top
lbl.Visible = false
lbl.Parent = gui
return lbl
end

local function makeCenterLabel(color)
local lbl = makeLabel(color)
lbl.AnchorPoint = Vector2.new(0.5, 1)
lbl.TextXAlignment = Enum.TextXAlignment.Center
return lbl
end

local function makeRightLabel(color)
local lbl = makeLabel(color)
lbl.AnchorPoint = Vector2.new(1, 0)
lbl.TextXAlignment = Enum.TextXAlignment.Right
return lbl
end

local labels = {}

local function onPlayerAdded(player)
if player == LocalPlayer then return end
if labels[player] then return end
labels[player] = {
level = makeLabel(CONFIG.TextColor),
elo = makeLabel(CONFIG.TextColor),
streak = makeLabel(CONFIG.TextColor),
health = makeRightLabel(CONFIG.HealthColor),
name = makeCenterLabel(CONFIG.NameColor),
weapon = makeCenterLabel(CONFIG.WeaponColor),
distance = makeCenterLabel(CONFIG.TextColor),
}
end

local function onPlayerRemoving(player)
local set = labels[player]
if set then
for _, lbl in pairs(set) do lbl:Destroy() end
end
labels[player] = nil
end

for _, p in ipairs(Players:GetPlayers()) do onPlayerAdded(p) end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

local Reference = {}
local Records = {}

local SKELETON_R15 = {
{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local SKELETON_R6 = {
{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}
local MAX_BONES = 15

local function bindCharacter(record, character)
record.Character = character
record.Root = nil
record.Head = nil
record.Humanoid = nil
record.Parts = {}
record.SkeletonLinks = {}
record.HipHeight = 2
if not character then return end

local function rebuild()
record.Parts = {}
record.SkeletonLinks = {}
for _, part in ipairs(character:GetChildren()) do
if part:IsA("BasePart") then
record.Parts[part.Name] = part
local motor = part:FindFirstChildOfClass("Motor6D")
if motor and motor.Part0 and motor.Part1 then
table.insert(record.SkeletonLinks, { motor.Part0, motor.Part1 })
end
end
end
end
rebuild()

record.Root = character:FindFirstChild("HumanoidRootPart")
or character:FindFirstChild("Torso")
or character.PrimaryPart
record.Humanoid = character:FindFirstChildOfClass("Humanoid")
record.Head = character:FindFirstChild("HitboxHead")
or character:FindFirstChild("Head")
or record.Root
if record.Humanoid then
record.HipHeight = record.Humanoid.HipHeight or 2
end

record._conns = record._conns or {}
for _, c in ipairs(record._conns) do c:Disconnect() end
record._conns = {}
table.insert(record._conns, character.DescendantAdded:Connect(function(d)
if d:IsA("BasePart") or d:IsA("Motor6D") then task.defer(rebuild) end
end))
table.insert(record._conns, character.DescendantRemoving:Connect(function(d)
if d:IsA("BasePart") or d:IsA("Motor6D") then task.defer(rebuild) end
end))
end

local function ensureRecord(player)
local record = Records[player]
if record then return record end
record = {
Player = player,
Character = nil, Root = nil, Head = nil, Humanoid = nil,
Parts = {}, SkeletonLinks = {},
HipHeight = 2,
}
Records[player] = record
player.CharacterAdded:Connect(function(char)
bindCharacter(record, char)
task.delay(0.5, function()
if record.Character == char then bindCharacter(record, char) end
end)
end)
if player.Character then bindCharacter(record, player.Character) end
return record
end

local function ensureDrawings(player)
if Reference[player] then return Reference[player] end
if not Drawing then return nil end

local set = { box = {}, skeleton = {} }
set.box.Main = Drawing.new("Square")
set.box.Main.Transparency = 1
set.box.Main.ZIndex = 2
set.box.Main.Filled = false
set.box.Main.Thickness = CONFIG.BoxThickness
set.box.Main.Color = CONFIG.BoxColor

set.box.Border = Drawing.new("Square")
set.box.Border.Transparency = 0.35
set.box.Border.ZIndex = 1
set.box.Border.Thickness = CONFIG.BoxThickness + 1
set.box.Border.Filled = false
set.box.Border.Color = Color3.new(0, 0, 0)

set.box.HealthLine = Drawing.new("Line")
set.box.HealthLine.Thickness = 2
set.box.HealthLine.ZIndex = 3
set.box.HealthLine.Color = CONFIG.HealthColor

set.box.HealthBorder = Drawing.new("Line")
set.box.HealthBorder.Thickness = 4
set.box.HealthBorder.ZIndex = 2
set.box.HealthBorder.Color = Color3.new(0, 0, 0)

for i = 1, MAX_BONES do
local backer = Drawing.new("Line")
backer.Thickness = CONFIG.SkeletonThickness + 2
backer.Color = Color3.new(0, 0, 0)
backer.ZIndex = 1

local line = Drawing.new("Line")
line.Thickness = CONFIG.SkeletonThickness
line.Color = CONFIG.SkeletonColor
line.ZIndex = 2

set.skeleton[i] = { backer = backer, color = line }
end
Reference[player] = set
return set
end

local function hideDrawings(set)
if not set then return end
set.box.Main.Visible = false
set.box.Border.Visible = false
set.box.HealthLine.Visible = false
set.box.HealthBorder.Visible = false
for _, bone in ipairs(set.skeleton) do
bone.backer.Visible = false
bone.color.Visible = false
end
end

local function removeDrawings(player)
local set = Reference[player]
if not set then return end
pcall(function() set.box.Main:Remove() end)
pcall(function() set.box.Border:Remove() end)
pcall(function() set.box.HealthLine:Remove() end)
pcall(function() set.box.HealthBorder:Remove() end)
for _, bone in ipairs(set.skeleton) do
pcall(function() bone.backer:Remove() end)
pcall(function() bone.color:Remove() end)
end
Reference[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
removeDrawings(player)
Records[player] = nil
end)

for _, p in ipairs(Players:GetPlayers()) do
if p ~= LocalPlayer then ensureRecord(p) end
end
Players.PlayerAdded:Connect(function(p)
if p ~= LocalPlayer then ensureRecord(p) end
end)

if not Drawing then
warn("[ESP] Drawing API unavailable - box/skeleton skipped")
end

local function getWeaponName(player)
if not player then return nil end
local char = player.Character
if not char then return nil end
local weapon = char:GetAttribute("EquippedItem")
if weapon and weapon ~= "" then return tostring(weapon) end
return nil
end

RunService.RenderStepped:Connect(function()
if not CONFIG.Enabled then
for _, set in pairs(labels) do
for _, lbl in pairs(set) do lbl.Visible = false end
end
for _, set in pairs(Reference) do hideDrawings(set) end
return
end

local cam = workspace.CurrentCamera
if not cam then return end

local myEnv = getAttr(LocalPlayer, ATTR_ENV)
local myTeam = getAttr(LocalPlayer, ATTR_TEAM)
if myTeam == "" then myTeam = nil end

if myEnv == nil then
for _, set in pairs(labels) do
for _, lbl in pairs(set) do lbl.Visible = false end
end
for _, set in pairs(Reference) do hideDrawings(set) end
return
end

local camPos = cam.CFrame.Position

for player, record in pairs(Records) do
local set = labels[player]
if not set then continue end

local char = record.Character
local root = record.Root
local hum = record.Humanoid

if not char or not char.Parent then
char = player.Character
if char and char.Parent then
bindCharacter(record, char)
root = record.Root
hum = record.Humanoid
end
end

local function hideAll()
for _, lbl in pairs(set) do lbl.Visible = false end
local dset = Reference[player]
if dset then hideDrawings(dset) end
end

if not char or not root or not root.Parent then
hideAll()
continue
end

if hum and hum.Health <= 0 then
hideAll()
continue
end

local dist = (root.Position - camPos).Magnitude
if dist > CONFIG.MaxDistance then
hideAll()
continue
end

local theirEnv = getAttr(player, ATTR_ENV)
if theirEnv ~= myEnv then
hideAll()
continue
end

local theirTeam = getAttr(player, ATTR_TEAM)
if theirTeam == "" then theirTeam = nil end
if myTeam ~= nil and theirTeam ~= nil and myTeam == theirTeam then
hideAll()
continue
end

local rootPos, rootVis = cam:WorldToViewportPoint(root.Position)
if not rootVis or rootPos.Z <= 0 then
hideAll()
continue
end

local boxRightX, boxLeftX, boxTopY, boxBottomY, sizey = nil, nil, nil, nil, nil
local boxCenterX = nil

if Drawing then
local dset = ensureDrawings(player)
if dset then
if CONFIG.ShowBox then
local topPos = cam:WorldToViewportPoint(
(CFrame.lookAlong(root.Position, cam.CFrame.LookVector)
* CFrame.new(2, record.HipHeight, 0)).Position
)
local bottomPos = cam:WorldToViewportPoint(
(CFrame.lookAlong(root.Position, cam.CFrame.LookVector)
* CFrame.new(-2, -record.HipHeight - 1, 0)).Position
)

local sizex = math.abs(topPos.X - bottomPos.X)
sizey = math.abs(topPos.Y - bottomPos.Y)

if sizex >= 2 and sizey >= 2 then
local posx = rootPos.X - sizex / 2
local posy = math.min(topPos.Y, bottomPos.Y)

dset.box.Main.Visible = true
dset.box.Main.Color = CONFIG.BoxColor
dset.box.Main.Transparency = 1 - CONFIG.BoxTransparency
dset.box.Main.Thickness = CONFIG.BoxThickness
dset.box.Main.Position = vec2floor(Vector2.new(posx, posy))
dset.box.Main.Size = vec2floor(Vector2.new(sizex, sizey))

dset.box.Border.Visible = CONFIG.BoxOutline
dset.box.Border.Position = vec2floor(Vector2.new(posx - 1, posy + 1))
dset.box.Border.Size = vec2floor(Vector2.new(sizex + 2, sizey - 2))
dset.box.Border.Thickness = CONFIG.BoxThickness + 1

boxRightX = posx + sizex
boxLeftX = posx
boxTopY = posy
boxBottomY = posy + sizey
boxCenterX = posx + sizex / 2

if CONFIG.ShowHealth and hum then
local healthRatio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
local healthHeight = sizey * healthRatio
local barX = posx - 8

dset.box.HealthBorder.Visible = true
dset.box.HealthBorder.From = vec2floor(Vector2.new(barX, posy))
dset.box.HealthBorder.To = vec2floor(Vector2.new(barX, posy + sizey))

dset.box.HealthLine.Visible = true
dset.box.HealthLine.Color = CONFIG.HealthLow:Lerp(CONFIG.HealthColor, healthRatio)
dset.box.HealthLine.From = vec2floor(Vector2.new(barX, posy + sizey - healthHeight))
dset.box.HealthLine.To = vec2floor(Vector2.new(barX, posy + sizey))
else
dset.box.HealthBorder.Visible = false
dset.box.HealthLine.Visible = false
end
else
dset.box.Main.Visible = false
dset.box.Border.Visible = false
dset.box.HealthBorder.Visible = false
dset.box.HealthLine.Visible = false
end
else
dset.box.Main.Visible = false
dset.box.Border.Visible = false
dset.box.HealthBorder.Visible = false
dset.box.HealthLine.Visible = false
end

if CONFIG.ShowSkeleton then
local links = record.SkeletonLinks
local motorLinks = #links > 0
local parts = record.Parts
local bones = motorLinks and links
or (parts.UpperTorso and SKELETON_R15 or SKELETON_R6)

for i = 1, MAX_BONES do
local bone = dset.skeleton[i]
local link = bones[i]
if link then
local a, b
if motorLinks then
a, b = link[1], link[2]
else
a, b = parts[link[1]], parts[link[2]]
end
if a and b and a.Parent and b.Parent then
local pa = cam:WorldToViewportPoint(a.Position)
local pb = cam:WorldToViewportPoint(b.Position)
if pa.Z > 0 and pb.Z > 0 then
local from = Vector2.new(pa.X, pa.Y)
local to = Vector2.new(pb.X, pb.Y)

bone.backer.Visible = CONFIG.SkeletonOutline
bone.backer.From = from
bone.backer.To = to
bone.backer.Thickness = CONFIG.SkeletonThickness + 2
bone.backer.Color = Color3.new(0, 0, 0)
bone.backer.Transparency = 1 - CONFIG.SkeletonTransparency

bone.color.Visible = true
bone.color.From = from
bone.color.To = to
bone.color.Thickness = CONFIG.SkeletonThickness
bone.color.Color = CONFIG.SkeletonColor
bone.color.Transparency = 1 - CONFIG.SkeletonTransparency
else
bone.backer.Visible = false
bone.color.Visible = false
end
else
bone.backer.Visible = false
bone.color.Visible = false
end
else
bone.backer.Visible = false
bone.color.Visible = false
end
end
else
for i = 1, MAX_BONES do
local bone = dset.skeleton[i]
bone.backer.Visible = false
bone.color.Visible = false
end
end
end
end

local levelVal = getAttr(player, ATTR_LEVEL)
local eloVal = getAttr(player, ATTR_ELO)
local streakVal = getAttr(player, ATTR_STREAK)
local userId = player.UserId
local lb = LeaderboardCache[userId] or {}

local baseX, baseY, lineH, textSize

if boxRightX and boxTopY and sizey then
baseX = boxRightX + CONFIG.OffsetX
baseY = boxTopY
local totalTextHeight = sizey * CONFIG.TextHeightRatio
textSize = math.clamp(
math.floor((totalTextHeight / 3) * 0.85 + 0.5),
CONFIG.MinTextSize,
CONFIG.MaxTextSize
)
lineH = totalTextHeight / 3
else
baseX = rootPos.X + 20
baseY = rootPos.Y - 20
textSize = CONFIG.MaxTextSize
lineH = textSize * 1.2
end

set.level.TextSize = textSize
set.level.Text = "Level " .. withRank(levelVal, lb.levelRank)
set.level.Position = UDim2.fromOffset(baseX, baseY)
set.level.Visible = CONFIG.ShowLevel

local tierName = getTierName(eloVal, userId)
local eloText
if eloVal ~= nil then
eloText = "ELO " .. tostring(math.floor(eloVal))
if tierName then
eloText = eloText .. " (" .. tierName .. ")"
end
else
eloText = "ELO ?"
end
if type(lb.eloRank) == "number" and lb.eloRank > 0 then
eloText = eloText .. " #" .. lb.eloRank
end
set.elo.TextSize = textSize
set.elo.Text = eloText
set.elo.Position = UDim2.fromOffset(baseX, baseY + lineH)
set.elo.Visible = CONFIG.ShowELO

set.streak.TextSize = textSize
set.streak.Text = "Streak " .. withRank(streakVal, lb.streakRank)
set.streak.Position = UDim2.fromOffset(baseX, baseY + lineH * 2)
set.streak.Visible = CONFIG.ShowStreak

local flagSize = math.max(CONFIG.MinTextSize, math.floor(textSize * 0.75))
local flagLineH = flagSize + 2

if CONFIG.ShowHealth and hum and boxLeftX and boxTopY and sizey then
local healthColor = CONFIG.HealthLow:Lerp(CONFIG.HealthColor, math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1))
set.health.TextSize = flagSize
set.health.Text = tostring(math.floor(hum.Health + 0.5))
set.health.TextColor3 = healthColor
set.health.Position = UDim2.fromOffset(boxLeftX - 12, boxTopY + sizey / 2 - flagSize / 2)
set.health.Visible = true
else
set.health.Visible = false
end

if CONFIG.ShowName and boxCenterX and boxTopY then
set.name.TextSize = textSize
set.name.Text = player.DisplayName
set.name.Position = UDim2.fromOffset(boxCenterX, boxTopY - 4)
set.name.Visible = true
else
set.name.Visible = false
end

if CONFIG.ShowWeapon and boxCenterX and boxBottomY then
local weapon = getWeaponName(player)
if weapon and weapon ~= "" then
set.weapon.TextSize = flagSize
set.weapon.Text = weapon
set.weapon.Position = UDim2.fromOffset(boxCenterX, boxBottomY + flagLineH)
set.weapon.Visible = true
else
set.weapon.Visible = false
end
else
set.weapon.Visible = false
end

if CONFIG.ShowDistance and boxCenterX and boxBottomY then
local yOffset = flagLineH
if CONFIG.ShowWeapon then
local weapon = getWeaponName(player)
if weapon and weapon ~= "" then
yOffset = flagLineH * 2
end
end
set.distance.TextSize = flagSize
set.distance.Text = tostring(math.floor(dist)) .. "m"
set.distance.Position = UDim2.fromOffset(boxCenterX, boxBottomY + yOffset)
set.distance.Visible = true
else
set.distance.Visible = false
end
end
end)

local ESPBox = Visuals:AddGroupbox({ Name = "ESP", Side = 1 })

ESPBox:AddCheckbox("ESPBox", {
    Text = "Box", Default = false,
    Callback = function(Value) CONFIG.ShowBox = Value end
})
ESPBox:AddCheckbox("ESPSkeleton", {
    Text = "Skeleton", Default = false,
    Callback = function(Value) CONFIG.ShowSkeleton = Value end
})
ESPBox:AddCheckbox("ESPName", {
    Text = "Name", Default = false,
    Callback = function(Value) CONFIG.ShowName = Value end
})
ESPBox:AddCheckbox("ESPHealth", {
    Text = "Health", Default = false,
    Callback = function(Value) CONFIG.ShowHealth = Value end
})
ESPBox:AddCheckbox("ESPWeapon", {
    Text = "Weapon", Default = false,
    Callback = function(Value) CONFIG.ShowWeapon = Value end
})
ESPBox:AddCheckbox("ESPLevel", {
    Text = "Level", Default = false,
    Callback = function(Value) CONFIG.ShowLevel = Value end
})
ESPBox:AddCheckbox("ESPELO", {
    Text = "ELO", Default = false,
    Callback = function(Value) CONFIG.ShowELO = Value end
})
ESPBox:AddCheckbox("ESPStreak", {
    Text = "Streak", Default = false,
    Callback = function(Value) CONFIG.ShowStreak = Value end
})

local KILL_SOUNDS = {
    ["None"]="",
    ["Anime girl laugh"]="rbxassetid://103966419660274",
    ["Mambo umamusume"]="rbxassetid://72270862303024",
    ["sata andagii"]="rbxassetid://111397769122554",
}
local HIT_SOUNDS = {
    ["None"]="",["Neverlose"]="rbxassetid://6607204501",
    ["Gamesense"]="rbxassetid://4817809188",["Skeet"]="rbxassetid://5447626464",
    ["Rust"]="rbxassetid://5043539486",["Bell"]="rbxassetid://6534947240",
    ["Bubble"]="rbxassetid://6534947588",["Minecraft"]="rbxassetid://4018616850",
    ["Osu"]="rbxassetid://7149255551",["TF2"]="rbxassetid://2868331684",
    ["Click Hit Sound"]="rbxassetid://8053704437",
    ["Hit"]="rbxassetid://1347140027",
    ["CSGO"]="rbxassetid://5764885315",
}
local soundState = getgenv().__MinhoSoundState or {
    HitEnabled=false, HitSelected="None", HitVolume=0.5, HitPitch=1,
    HitRemoveDefault=true,
    KillEnabled=false, KillSelected="None", KillVolume=0.5, KillPitch=1,
}
getgenv().__MinhoSoundState = soundState
soundState.HitRemoveDefault = soundState.HitRemoveDefault ~= false
if soundState.HitSelected == "Default" or soundState.HitSelected == nil then soundState.HitSelected = "None" end
if soundState.KillSelected == "Default" or soundState.KillSelected == nil then soundState.KillSelected = "None" end

local function playCustomSound(soundId, volume, pitch)
    if not soundId or soundId == "" then return end
    local s = Instance.new("Sound")
    s.SoundId = soundId
    s.Volume = math.clamp(volume or 0.5, 0, 10)
    s.PlaybackSpeed = math.clamp(pitch or 1, 0.1, 5)
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 5)
end

local hitSoundState = getgenv().__MinhoHitSoundState or {
    Installed = false, Enabled = false, Hooked = false,
    OriginalPlayHitmarkerSound = nil,
}
getgenv().__MinhoHitSoundState = hitSoundState
hitSoundState.Installed = hitSoundState.Installed == true
hitSoundState.Enabled = hitSoundState.Enabled == true
hitSoundState.Hooked = hitSoundState.Hooked == true

local function installHitSound()
    if hitSoundState.Hooked then
        hitSoundState.Enabled = true
        hitSoundState.Installed = true
        return true
    end

    local ok, viewmodelModule = pcall(function()
        return require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses
            .ClientFighter.ClientItem.ClientViewModel)
    end)

    if not ok
        or type(viewmodelModule) ~= "table"
        or type(viewmodelModule.PlayHitmarkerSound) ~= "function" then
        return false
    end

    hitSoundState.OriginalPlayHitmarkerSound =
        hitSoundState.OriginalPlayHitmarkerSound or viewmodelModule.PlayHitmarkerSound

    viewmodelModule.PlayHitmarkerSound = function(self, crit, divisor, ...)
        if hitSoundState.Enabled then
            local id = HIT_SOUNDS[soundState.HitSelected] or ""
            if id ~= "" then
                playCustomSound(id, soundState.HitVolume, soundState.HitPitch)
            end
        end
        if soundState.HitRemoveDefault then return end
        return hitSoundState.OriginalPlayHitmarkerSound(self, crit, divisor, ...)
    end

    hitSoundState.Hooked = true
    hitSoundState.Installed = true
    hitSoundState.Enabled = true
    return true
end

local function uninstallHitSound()
    hitSoundState.Enabled = false
    hitSoundState.Installed = false
    if hitSoundState.Hooked then
        pcall(function()
            local ok, viewmodelModule = pcall(function()
                return require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses
                    .ClientFighter.ClientItem.ClientViewModel)
            end)
            if ok and type(viewmodelModule) == "table" and hitSoundState.OriginalPlayHitmarkerSound then
                viewmodelModule.PlayHitmarkerSound = hitSoundState.OriginalPlayHitmarkerSound
            end
        end)
    end
    hitSoundState.Hooked = false
end

local killSoundState = getgenv().__MinhoKillSoundState or {
    LastHitAtByPlayer={}, LastPlayedAt={}, HitWindow=4, Cooldown=0.35,
    Enabled=false, HitTrackerInstalled=false, OriginalDamageEffect=nil,
    PlayerConnections={}, PlayerAddedConn=nil, PlayerRemovingConn=nil,
    HookedPlayers={},
}
getgenv().__MinhoKillSoundState = killSoundState

local function cleanupKillSoundSystem()
    for plr, conns in pairs(killSoundState.PlayerConnections) do
        for _, conn in ipairs(conns) do pcall(function() conn:Disconnect() end) end
        killSoundState.PlayerConnections[plr] = nil
    end
    killSoundState.HookedPlayers = {}
    if killSoundState.PlayerAddedConn then
        pcall(function() killSoundState.PlayerAddedConn:Disconnect() end)
        killSoundState.PlayerAddedConn = nil
    end
    if killSoundState.PlayerRemovingConn then
        pcall(function() killSoundState.PlayerRemovingConn:Disconnect() end)
        killSoundState.PlayerRemovingConn = nil
    end
    if killSoundState.HitTrackerInstalled and killSoundState.OriginalDamageEffect then
        pcall(function()
            local ok, ii = pcall(function()
                return require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem.ItemInterface)
            end)
            if ok and type(ii) == "table" then ii.DamageEffect = killSoundState.OriginalDamageEffect end
        end)
        killSoundState.HitTrackerInstalled = false
    end
    table.clear(killSoundState.LastHitAtByPlayer)
    table.clear(killSoundState.LastPlayedAt)
end

cleanupKillSoundSystem()

local function playKillSound()
    local id = KILL_SOUNDS[soundState.KillSelected] or ""
    if id == "" then return end
    playCustomSound(id, soundState.KillVolume, soundState.KillPitch)
end

local function shouldCreditKill(plr)
    if not plr or plr == LocalPlayer then return false end
    local last = killSoundState.LastHitAtByPlayer[plr]
    return last ~= nil and tick() - last < killSoundState.HitWindow
end

local function tryKillSound(plr, lastHp, newHp)
    if not killSoundState.Enabled then return end
    if (newHp or 0) > 0 then return end
    if (lastHp or 0) <= 0 then return end
    if not shouldCreditKill(plr) then return end
    local now = tick()
    if now - (killSoundState.LastPlayedAt[plr] or 0) < killSoundState.Cooldown then return end
    killSoundState.LastPlayedAt[plr] = now
    playKillSound()
    killSoundState.LastHitAtByPlayer[plr] = nil
end

local function installKillHitTracker()
    if killSoundState.HitTrackerInstalled then return true end
    local ok, ii = pcall(function()
        return require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem.ItemInterface)
    end)
    if not ok or type(ii) ~= "table" or type(ii.DamageEffect) ~= "function" then return false end
    killSoundState.OriginalDamageEffect = ii.DamageEffect
    ii.DamageEffect = function(self, ...)
        local args = {...}
        for _, v in ipairs(args) do
            if typeof(v) == "Instance" then
                local char = v:FindFirstAncestorOfClass("Model")
                if char then
                    local plr = Players:GetPlayerFromCharacter(char)
                    if plr and plr ~= LocalPlayer then
                        killSoundState.LastHitAtByPlayer[plr] = tick()
                    end
                end
            elseif typeof(v) == "table" then
                for _, inner in pairs(v) do
                    if typeof(inner) == "Instance" then
                        local char = inner:FindFirstAncestorOfClass("Model")
                        if char then
                            local plr = Players:GetPlayerFromCharacter(char)
                            if plr and plr ~= LocalPlayer then
                                killSoundState.LastHitAtByPlayer[plr] = tick()
                            end
                        end
                    end
                end
            end
        end
        return killSoundState.OriginalDamageEffect(self, ...)
    end
    killSoundState.HitTrackerInstalled = true
    return true
end

local function watchPlayerForKill(plr)
    if plr == LocalPlayer then return end
    if killSoundState.HookedPlayers[plr] then return end
    killSoundState.HookedPlayers[plr] = true
    killSoundState.PlayerConnections[plr] = killSoundState.PlayerConnections[plr] or {}

    local function hookCharacter(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        local lastHp = hum.Health
        local c1 = hum.HealthChanged:Connect(function(newHp)
            if newHp <= 0 and lastHp > 0 then tryKillSound(plr, lastHp, newHp) end
            lastHp = newHp
        end)
        table.insert(killSoundState.PlayerConnections[plr], c1)
        local c2 = hum.Died:Connect(function() tryKillSound(plr, lastHp, 0) end)
        table.insert(killSoundState.PlayerConnections[plr], c2)
    end

    if plr.Character then hookCharacter(plr.Character) end
    local c = plr.CharacterAdded:Connect(hookCharacter)
    table.insert(killSoundState.PlayerConnections[plr], c)
end

local function installKillSoundSystem()
    cleanupKillSoundSystem()
    killSoundState.Enabled = true
    installKillHitTracker()
    for _, plr in Players:GetPlayers() do watchPlayerForKill(plr) end
    killSoundState.PlayerAddedConn = Players.PlayerAdded:Connect(watchPlayerForKill)
    killSoundState.PlayerRemovingConn = Players.PlayerRemoving:Connect(function(plr)
        if killSoundState.PlayerConnections[plr] then
            for _, conn in ipairs(killSoundState.PlayerConnections[plr]) do
                pcall(function() conn:Disconnect() end)
            end
            killSoundState.PlayerConnections[plr] = nil
        end
        killSoundState.HookedPlayers[plr] = nil
        killSoundState.LastHitAtByPlayer[plr] = nil
        killSoundState.LastPlayedAt[plr] = nil
    end)
end

local function uninstallKillSoundSystem()
    killSoundState.Enabled = false
    cleanupKillSoundSystem()
end

Hub.installHitSound = installHitSound
Hub.uninstallHitSound = uninstallHitSound
Hub.installKillSoundSystem = installKillSoundSystem
Hub.uninstallKillSoundSystem = uninstallKillSoundSystem

local HitSoundBox = Visuals:AddGroupbox({ Name = "Hit Sound", Side = 2 })

HitSoundBox:AddCheckbox("HitSoundEnabled", {
    Text = "Hit Sound", Default = false,
    Callback = function(Value)
        soundState.HitEnabled = Value
        hitSoundState.Enabled = Value
        if Value then installHitSound() else uninstallHitSound() end
    end
})

HitSoundBox:AddDropdown("HitSoundSelect", {
    Text = "Hit Sound Type",
    Values = { "None","Neverlose","Gamesense","Skeet","Rust","Bell","Bubble","Minecraft","Osu","TF2", "Click Hit Sound", "Hit", "CSGO" },
    Default = "None", Multi = false,
    Callback = function(Value) soundState.HitSelected = Value end
})

HitSoundBox:AddSlider("HitSoundVolume", {
    Text = "Hit Volume", Default = 0.5, Min = 0, Max = 2, Rounding = 1, Suffix = "",
    Callback = function(Value) soundState.HitVolume = Value end
})

HitSoundBox:AddSlider("HitSoundPitch", {
    Text = "Hit Pitch", Default = 1, Min = 0.1, Max = 3, Rounding = 1, Suffix = "",
    Callback = function(Value) soundState.HitPitch = Value end
})

HitSoundBox:AddCheckbox("HitSoundRemoveDefault", {
    Text = "Remove Default Hit Sound", Default = true,
    Callback = function(Value) soundState.HitRemoveDefault = Value end
})

local KillSoundBox = Visuals:AddGroupbox({ Name = "Kill Sound", Side = 2 })

KillSoundBox:AddCheckbox("KillSoundEnabled", {
    Text = "Kill Sound", Default = false,
    Callback = function(Value)
        soundState.KillEnabled = Value
        if Value then installKillSoundSystem() else uninstallKillSoundSystem() end
    end
})

KillSoundBox:AddDropdown("KillSoundSelect", {
    Text = "Kill Sound Type",
    Values = { "None","Anime girl laugh","Mambo umamusume","sata andagii" },
    Default = "None", Multi = false,
    Callback = function(Value) soundState.KillSelected = Value end
})

KillSoundBox:AddSlider("KillSoundVolume", {
    Text = "Kill Volume", Default = 0.5, Min = 0, Max = 2, Rounding = 1, Suffix = "",
    Callback = function(Value) soundState.KillVolume = Value end
})

KillSoundBox:AddSlider("KillSoundPitch", {
    Text = "Kill Pitch", Default = 1, Min = 0.1, Max = 3, Rounding = 1, Suffix = "",
    Callback = function(Value) soundState.KillPitch = Value end
})

return true

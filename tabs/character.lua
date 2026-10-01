--!nonstrict
local Hub = _G.MinhoHub
if not Hub then return end

local Players          = Hub.Players
local RunService       = Hub.RunService
local UserInputService = Hub.UserInputService
local LocalPlayer      = Hub.LocalPlayer
local Character        = Hub.Tabs.Character

local movementState = getgenv().__MinhoMovementState or {
    Mechanics=nil, SlideOriginals={}, ItemOriginals={},
    OldSlide=nil, OldDoubleJump=nil, OldHighJump=nil,
    Hooked=false, HookedMechanics=nil,
    VelocityEnabled=false, VelocitySpeed=50, VelocityConn=nil,
    SlideBoostEnabled=false, SlideBoostValue=1, SlideBoostConn=nil,
    DoubleJumpEnabled=false, DoubleJumpValue=1,
    MaulSlamEnabled=false, MaulSlamValue=1, MaulSlamConn=nil,
    InfiniteDoubleJump=false, InfiniteDJConn=nil,
}
getgenv().__MinhoMovementState = movementState

do
    local mech = movementState.HookedMechanics
    if mech then
        if movementState.OldSlide and type(mech.Slide)=="function" then
            pcall(function() mech.Slide = movementState.OldSlide end)
        end
        if movementState.OldDoubleJump and type(mech.DoubleJump)=="function" then
            pcall(function() mech.DoubleJump = movementState.OldDoubleJump end)
        end
        if movementState.OldHighJump and type(mech.HighJump)=="function" then
            pcall(function() mech.HighJump = movementState.OldHighJump end)
        end
    end
    movementState.Hooked = false
    movementState.HookedMechanics = nil
end

local function getMechanics()
    if movementState.Mechanics then return movementState.Mechanics end
    local ok, mech = pcall(function()
        return require(LocalPlayer.PlayerScripts.Controllers.MechanicsController)
    end)
    if ok and mech then movementState.Mechanics = mech return mech end
end

local function getMovementRootHum()
    local char = LocalPlayer.Character
    if not char then return end
    return char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

local function isMovementAirborne(hum, root)
    if not hum then return false end
    local s = hum:GetState()
    if s == Enum.HumanoidStateType.Jumping or s == Enum.HumanoidStateType.Freefall
        or s == Enum.HumanoidStateType.FallingDown or s == Enum.HumanoidStateType.Physics
        or s == Enum.HumanoidStateType.PlatformStanding then return true end
    if hum.FloorMaterial == Enum.Material.Air then return true end
    return root and math.abs(root.AssemblyLinearVelocity.Y) > 3 or false
end

local function isMovementSliding(hum)
    local mech = getMechanics()
    if mech and mech.IsSliding then return true end
    local fighter = mech and mech.LocalFighter
    if fighter and fighter.IsSlidingLocally then return true end
    return false
end

local function applyMovementVelocity()
    if not movementState.VelocityEnabled then return false end
    local root, hum = getMovementRootHum()
    if not root or not hum or hum.Health <= 0 then return false end
    if isMovementSliding(hum) then return false end
    local move = hum.MoveDirection
    if move.Magnitude > 0.1 then
        local dir = Vector3.new(move.X, 0, move.Z).Unit
        local speed = movementState.VelocitySpeed or 50
        root.AssemblyLinearVelocity = Vector3.new(dir.X*speed, root.AssemblyLinearVelocity.Y, dir.Z*speed)
    else
        if isMovementAirborne(hum, root) then return false end
        root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
    end
    return true
end

local function restoreSlideBoost()
    for fighter, value in pairs(movementState.SlideOriginals) do
        pcall(function()
            if fighter and type(fighter.Set) == "function" then
                fighter:Set("SlidingSpeedMax", value)
            end
        end)
        movementState.SlideOriginals[fighter] = nil
    end
end

local function applySlideBoost(fighter)
    if not fighter or not movementState.SlideBoostEnabled then return end
    local ok, current = pcall(function() return fighter:Get("SlidingSpeedMax") end)
    local base = (movementState.SlideOriginals[fighter] ~= nil and movementState.SlideOriginals[fighter])
        or (ok and current) or 3
    movementState.SlideOriginals[fighter] = base
    pcall(function() fighter:Set("SlidingSpeedMax", base * movementState.SlideBoostValue) end)
end

local function restoreMovementItemInfo()
    for info, values in pairs(movementState.ItemOriginals) do
        if info then
            for key, value in pairs(values) do
                pcall(function() info[key] = value end)
            end
        end
        movementState.ItemOriginals[info] = nil
    end
end

local function saveMovementInfoValue(info, key)
    movementState.ItemOriginals[info] = movementState.ItemOriginals[info] or {}
    if movementState.ItemOriginals[info][key] == nil then
        movementState.ItemOriginals[info][key] = info[key]
    end
end

local function patchMovementEquippedItem()
    local mech = getMechanics()
    local fighter = mech and mech.LocalFighter
    local item = fighter and fighter.EquippedItem
    local info = item and item.Info
    if not info then return end
    if movementState.InfiniteDoubleJump then
        saveMovementInfoValue(info, "MaxDoubleJumps")
        info.MaxDoubleJumps = math.huge
        local objectId
        pcall(function() objectId = item:Get("ObjectID") end)
        if objectId and mech._double_jumps_used then
            mech._double_jumps_used[objectId] = 0
        end
    end
    if movementState.MaulSlamEnabled then
        for _, key in ipairs({"SlamDamage", "SlamRadius"}) do
            if type(info[key]) == "number" then
                saveMovementInfoValue(info, key)
                info[key] = movementState.ItemOriginals[info][key] * movementState.MaulSlamValue
            end
        end
    end
end

local function installMovementHooks()
    local mech = getMechanics()
    if not mech then return end
    if movementState.Hooked and movementState.HookedMechanics == mech then return end
    movementState.Hooked = true
    movementState.HookedMechanics = mech

    if type(mech.Slide) == "function" and not movementState.OldSlide then
        movementState.OldSlide = mech.Slide
        mech.Slide = function(self, ...)
            applySlideBoost(self and self.LocalFighter)
            return movementState.OldSlide(self, ...)
        end
    end
    if type(mech.DoubleJump) == "function" and not movementState.OldDoubleJump then
        movementState.OldDoubleJump = mech.DoubleJump
        mech.DoubleJump = function(self, ...)
            local result = movementState.OldDoubleJump(self, ...)
            if movementState.DoubleJumpEnabled then
                local fighter = self and self.LocalFighter
                local root = fighter and fighter.Entity and fighter.Entity.RootPart
                if root then
                    local vel = root.Velocity
                    root.Velocity = Vector3.new(vel.X, vel.Y * movementState.DoubleJumpValue, vel.Z)
                end
            end
            return result
        end
    end
end

local noclipState = getgenv().__MinhoNoclipState or { Enabled=false, Conn=nil }
getgenv().__MinhoNoclipState = noclipState
if noclipState.Conn then pcall(function() noclipState.Conn:Disconnect() end) noclipState.Conn = nil end

local function startNoclip()
    if noclipState.Conn then return end
    noclipState.Conn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end

local function stopNoclip()
    if noclipState.Conn then noclipState.Conn:Disconnect() noclipState.Conn = nil end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end

Hub.startNoclip = startNoclip
Hub.stopNoclip = stopNoclip

local flyState = getgenv().__MinhoFlyState or {
    Enabled=false, Gyro=nil, Velocity=nil, Speed=50,
    KeyState={w=0,s=0,a=0,d=0,up=0,down=0},
    InputBeganConn=nil, InputEndedConn=nil, RenderConn=nil,
}
getgenv().__MinhoFlyState = flyState

do
    if flyState.InputBeganConn then pcall(function() flyState.InputBeganConn:Disconnect() end) flyState.InputBeganConn=nil end
    if flyState.InputEndedConn then pcall(function() flyState.InputEndedConn:Disconnect() end) flyState.InputEndedConn=nil end
    if flyState.RenderConn then pcall(function() flyState.RenderConn:Disconnect() end) flyState.RenderConn=nil end
    if flyState.Gyro then pcall(function() flyState.Gyro:Destroy() end) flyState.Gyro=nil end
    if flyState.Velocity then pcall(function() flyState.Velocity:Destroy() end) flyState.Velocity=nil end
end

local function isFlyAlive()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0 and char.PrimaryPart
end

local function cleanupFly()
    if flyState.Gyro then flyState.Gyro:Destroy() flyState.Gyro=nil end
    if flyState.Velocity then flyState.Velocity:Destroy() flyState.Velocity=nil end
    if flyState.InputBeganConn then flyState.InputBeganConn:Disconnect() flyState.InputBeganConn=nil end
    if flyState.InputEndedConn then flyState.InputEndedConn:Disconnect() flyState.InputEndedConn=nil end
    if flyState.RenderConn then flyState.RenderConn:Disconnect() flyState.RenderConn=nil end
    if isFlyAlive() then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    flyState.KeyState = {w=0,s=0,a=0,d=0,up=0,down=0}
end

local function startFly()
    if flyState.Gyro then flyState.Gyro:Destroy() flyState.Gyro=nil end
    if flyState.Velocity then flyState.Velocity:Destroy() flyState.Velocity=nil end
    if not isFlyAlive() then return end
    local char = LocalPlayer.Character
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    flyState.Gyro = Instance.new("BodyGyro")
    flyState.Gyro.P = 9e4
    flyState.Gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyState.Gyro.CFrame = root.CFrame
    flyState.Gyro.Parent = root

    flyState.Velocity = Instance.new("BodyVelocity")
    flyState.Velocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyState.Velocity.Velocity = Vector3.zero
    flyState.Velocity.Parent = root

    hum.PlatformStand = true
end

local function setFlyInput(input, state)
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.W then flyState.KeyState.w = state and 1 or 0
    elseif input.KeyCode == Enum.KeyCode.S then flyState.KeyState.s = state and 1 or 0
    elseif input.KeyCode == Enum.KeyCode.A then flyState.KeyState.a = state and 1 or 0
    elseif input.KeyCode == Enum.KeyCode.D then flyState.KeyState.d = state and 1 or 0
    elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.E then
        flyState.KeyState.up = state and 1 or 0
    elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.Q then
        flyState.KeyState.down = state and 1 or 0
    end
end

Hub.cleanupFly = cleanupFly

local thirdPersonState = getgenv().__MinhoThirdPersonState or { Enabled=false, Task=nil }
getgenv().__MinhoThirdPersonState = thirdPersonState
if thirdPersonState.Task then pcall(task.cancel, thirdPersonState.Task) thirdPersonState.Task=nil end

local function getCameraController()
    local ok, ctrl = pcall(function()
        return require(LocalPlayer.PlayerScripts.Controllers.CameraController)
    end)
    return ok and ctrl or nil
end

local function stopThirdPerson()
    if thirdPersonState.Task then pcall(task.cancel, thirdPersonState.Task) thirdPersonState.Task=nil end
    local gun = getCameraController()
    if gun and gun.CameraState then
        pcall(function() gun.CameraState:_SetPOVState(gun.CameraState.States.FirstPerson) end)
    end
end

Hub.stopThirdPerson = stopThirdPerson

local animState = getgenv().__MinhoAnimState or {
    Enabled=false, CurrentTrack=nil, CurrentAnimation=nil,
    CurrentHumanoid=nil, CurrentAnimator=nil,
    ReplayToken=0, LastReplay=0,
    Selected="Floss", Custom="", Speed=1,
    EmoteAdded=false, HumanoidRef=nil,
}
getgenv().__MinhoAnimState = animState

local animations = {
    ["Bodybuilder"]="3994130516",["Crawling in a Circle"]="116935126100338",
    ["Dolphin Dance"]="5938365243",["Dance"]="507771019",
    ["Dance Break"]="94258912028011",["French Confidence"]="116968182519797",
    ["Floss"]="72174079036035",["Frosty Flair"]="10214406616",
    ["Full Wiggle"]="86520127496722",["Ghost Floating"]="75911227509248",
    ["Gun"]="81100102810594",["Gangnam Style"]="78801539668900",
    ["Hip Bounce"]="123602332785269",["Hype Dance"]="93079641847306",
    ["Kicking Feet"]="109814083870185",["Line Dance"]="4049646104",
    ["Lay Floating"]="126579240140537",["Let's Drive"]="17360720445",
    ["Long Legs"]="82416741608012",["Rock Out"]="18225077553",
    ["Samba"]="6869813008",["Still Standing"]="11435177473",
    ["Spiral"]="81926730031709",["Solar System"]="118314972618293",
    ["Twirl"]="3716633898",["Take Me Under"]="6797938823",
    ["The Worm"]="99563207397301",["Take the L"]="110664723286332",
    ["Zesty"]="102901317133934",
}
local animationList = {
    "Bodybuilder","Custom","Crawling in a Circle","Dolphin Dance","Dance",
    "Dance Break","French Confidence","Floss","Frosty Flair","Full Wiggle",
    "Ghost Floating","Gun","Gangnam Style","Hip Bounce","Hype Dance",
    "Kicking Feet","Line Dance","Lay Floating","Let's Drive","Long Legs",
    "Rock Out","Samba","Still Standing","Spiral","Solar System","Twirl",
    "Take Me Under","The Worm","Take the L","Zesty",
}

local function stopAnimation()
    animState.ReplayToken = animState.ReplayToken + 1
    if animState.CurrentTrack then
        pcall(animState.CurrentTrack.Stop, animState.CurrentTrack, 0.1)
        pcall(animState.CurrentTrack.Destroy, animState.CurrentTrack)
        animState.CurrentTrack = nil
    end
    if animState.CurrentAnimation then
        animState.CurrentAnimation:Destroy()
        animState.CurrentAnimation = nil
    end
    animState.CurrentHumanoid = nil
    animState.CurrentAnimator = nil
    animState.EmoteAdded = false
    animState.HumanoidRef = nil
end

local function selectedAnimId()
    if animState.Selected == "Custom" then
        return tostring(animState.Custom):match("%d+")
    end
    return animations[animState.Selected]
end

local function playSelectedAnimation()
    if not animState.Enabled then return end
    local id = selectedAnimId()
    if not id or id == "" then stopAnimation() return end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    if animState.HumanoidRef ~= humanoid then
        animState.EmoteAdded = false
        animState.HumanoidRef = humanoid
    end

    stopAnimation()
    animState.HumanoidRef = humanoid
    animState.ReplayToken = animState.ReplayToken + 1
    local token = animState.ReplayToken
    local track, animation

    if animState.Selected ~= "Custom" then
        local description = humanoid:FindFirstChildOfClass("HumanoidDescription")
        if not description then
            description = Instance.new("HumanoidDescription")
            description.Parent = humanoid
        end
        if not animState.EmoteAdded then
            pcall(function()
                pcall(description.RemoveEmote, description, "MinhoAnim")
                description:AddEmote("MinhoAnim", tonumber(id))
            end)
            animState.EmoteAdded = true
        end
        local captured
        local connection = animator.AnimationPlayed:Connect(function(t) captured = t end)
        pcall(function() humanoid:PlayEmote("MinhoAnim") end)
        local timeout = os.clock() + 2
        while not captured and os.clock() < timeout do
            RunService.Heartbeat:Wait()
        end
        connection:Disconnect()
        track = captured
    else
        animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://" .. id
        local ok
        ok, track = pcall(animator.LoadAnimation, animator, animation)
        if not ok then track = nil end
    end

    if not track then
        if animation then animation:Destroy() end
        return
    end

    animState.CurrentAnimation = animation
    animState.CurrentTrack = track
    animState.CurrentHumanoid = humanoid
    animState.CurrentAnimator = animator
    animState.LastReplay = os.clock()
    track.Priority = Enum.AnimationPriority.Action4
    track.Looped = true
    track:Play(0.1, 1, animState.Speed)

    task.spawn(function()
        while token == animState.ReplayToken
            and animState.CurrentTrack == track
            and animState.Enabled do
            if not track.IsPlaying then
                track:Play(0.05, 1, animState.Speed)
            end
            track:AdjustSpeed(animState.Speed)
            track:AdjustWeight(1, 0)
            RunService.Heartbeat:Wait()
        end
    end)
end

Hub.stopAnimation = stopAnimation

-- ============================================================
-- Movement groupbox
-- ============================================================
local MovementBox = Character:AddGroupbox({ Name = "Movement", Side = 1 })

-- Velocity (토글 + 숨겨진 슬라이더)
MovementBox:AddCheckbox("VelocityEnabled", {
    Text = "Velocity", Default = false,
    Callback = function(Value)
        movementState.VelocityEnabled = Value
        if Value then
            installMovementHooks()
            if movementState.VelocityConn then movementState.VelocityConn:Disconnect() end
            movementState.VelocityConn = RunService.Heartbeat:Connect(applyMovementVelocity)
        else
            if movementState.VelocityConn then
                movementState.VelocityConn:Disconnect()
                movementState.VelocityConn = nil
            end
        end
    end
})
local VelocityBox = MovementBox:AddDependencyBox()
VelocityBox:AddSlider("VelocitySpeed", {
    Text = "Speed", Default = 50, Min = 0, Max = 250, Rounding = 0, Compact = true,
    Callback = function(Value) movementState.VelocitySpeed = Value end
})
VelocityBox:SetupDependencies({ { Toggles.VelocityEnabled, true } })

-- Slide Boost (토글 + 숨겨진 슬라이더)
MovementBox:AddCheckbox("SlideBoostEnabled", {
    Text = "Slide Boost", Default = false,
    Callback = function(Value)
        movementState.SlideBoostEnabled = Value
        if Value then
            installMovementHooks()
            if movementState.SlideBoostConn then movementState.SlideBoostConn:Disconnect() end
            movementState.SlideBoostConn = RunService.Heartbeat:Connect(function()
                local mech = getMechanics()
                if mech then applySlideBoost(mech.LocalFighter) end
            end)
        else
            if movementState.SlideBoostConn then
                movementState.SlideBoostConn:Disconnect()
                movementState.SlideBoostConn = nil
            end
            restoreSlideBoost()
        end
    end
})
local SlideBoostBox = MovementBox:AddDependencyBox()
SlideBoostBox:AddSlider("SlideBoostValue", {
    Text = "Multiplier", Default = 1, Min = 1, Max = 5, Rounding = 1, Compact = true,
    Callback = function(Value) movementState.SlideBoostValue = Value restoreSlideBoost() end
})
SlideBoostBox:SetupDependencies({ { Toggles.SlideBoostEnabled, true } })

-- Double Jump Height (토글 + 숨겨진 슬라이더)
MovementBox:AddCheckbox("DoubleJumpEnabled", {
    Text = "Double Jump Height", Default = false,
    Callback = function(Value)
        movementState.DoubleJumpEnabled = Value
        if Value then installMovementHooks() end
    end
})
local DoubleJumpBox = MovementBox:AddDependencyBox()
DoubleJumpBox:AddSlider("DoubleJumpValue", {
    Text = "Multiplier", Default = 1, Min = 1, Max = 10, Rounding = 1, Compact = true,
    Callback = function(Value) movementState.DoubleJumpValue = Value end
})
DoubleJumpBox:SetupDependencies({ { Toggles.DoubleJumpEnabled, true } })

-- Maul Slam Multiplier (토글 + 숨겨진 슬라이더)
MovementBox:AddCheckbox("MaulSlamEnabled", {
    Text = "Maul Slam Multiplier", Default = false,
    Callback = function(Value)
        movementState.MaulSlamEnabled = Value
        if Value then
            installMovementHooks()
            if movementState.MaulSlamConn then movementState.MaulSlamConn:Disconnect() end
            movementState.MaulSlamConn = RunService.Heartbeat:Connect(patchMovementEquippedItem)
        else
            if movementState.MaulSlamConn then
                movementState.MaulSlamConn:Disconnect()
                movementState.MaulSlamConn = nil
            end
            restoreMovementItemInfo()
        end
    end
})
local MaulSlamBox = MovementBox:AddDependencyBox()
MaulSlamBox:AddSlider("MaulSlamValue", {
    Text = "Multiplier", Default = 1, Min = 1, Max = 10, Rounding = 1, Compact = true,
    Callback = function(Value) movementState.MaulSlamValue = Value restoreMovementItemInfo() end
})
MaulSlamBox:SetupDependencies({ { Toggles.MaulSlamEnabled, true } })

-- Infinite Double Jump (체크박스만)
MovementBox:AddCheckbox("InfiniteDoubleJump", {
    Text = "Infinite Double Jump", Default = false,
    Callback = function(Value)
        movementState.InfiniteDoubleJump = Value
        if Value then
            installMovementHooks()
            if movementState.InfiniteDJConn then movementState.InfiniteDJConn:Disconnect() end
            movementState.InfiniteDJConn = RunService.Heartbeat:Connect(patchMovementEquippedItem)
        else
            if movementState.InfiniteDJConn then
                movementState.InfiniteDJConn:Disconnect()
                movementState.InfiniteDJConn = nil
            end
            restoreMovementItemInfo()
        end
    end
})

-- ============================================================
-- Fly & Noclip groupbox
-- ============================================================
local FlyNoclipBox = Character:AddGroupbox({ Name = "Fly & Noclip", Side = 2 })

local Noclip_Toggle = FlyNoclipBox:AddToggle("Noclip", {
    Text = "Noclip", Default = false,
    Callback = function(Value)
        noclipState.Enabled = Value
        if Value then startNoclip() else stopNoclip() end
    end
})
Noclip_Toggle:AddKeyPicker("NoclipKey", {
    Text = "Noclip", Default = nil, Mode = "Toggle", SyncToggleState = true,
})

local Fly_Toggle = FlyNoclipBox:AddToggle("FlyEnabled", {
    Text = "Fly", Default = false,
    Callback = function(Value)
        flyState.Enabled = Value
        if Value then
            startFly()
            flyState.InputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
                if not processed then setFlyInput(input, true) end
            end)
            flyState.InputEndedConn = UserInputService.InputEnded:Connect(function(input) setFlyInput(input, false) end)
            flyState.RenderConn = RunService.RenderStepped:Connect(function()
                if not flyState.Enabled then return end
                if not isFlyAlive() then return end
                if not flyState.Gyro or not flyState.Velocity
                    or not flyState.Gyro.Parent or not flyState.Velocity.Parent then
                    startFly()
                    return
                end
                local cam = workspace.CurrentCamera
                local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.PlatformStand = true end
                if cam then
                    flyState.Gyro.CFrame = cam.CFrame
                    local ks = flyState.KeyState
                    local move = (cam.CFrame.LookVector * (ks.w - ks.s))
                        + (cam.CFrame.RightVector * (ks.d - ks.a))
                        + (cam.CFrame.UpVector * (ks.up - ks.down))
                    flyState.Velocity.Velocity = move.Magnitude > 0
                        and (move.Unit * flyState.Speed) or Vector3.zero
                end
            end)
        else
            cleanupFly()
        end
    end
})
Fly_Toggle:AddKeyPicker("FlyKey", {
    Text = "Fly", Default = nil, Mode = "Toggle", SyncToggleState = true,
})

-- Fly Speed (Fly 토글의 Depbox)
local FlySpeedBox = FlyNoclipBox:AddDependencyBox()
FlySpeedBox:AddSlider("FlySpeed", {
    Text = "Fly Speed", Default = 50, Min = 50, Max = 300, Rounding = 0, Compact = true,
    Callback = function(Value) flyState.Speed = Value end
})
FlySpeedBox:SetupDependencies({ { Toggles.FlyEnabled, true } })

FlyNoclipBox:AddCheckbox("ThirdPerson", {
    Text = "Third Person", Default = false,
    Callback = function(Value)
        thirdPersonState.Enabled = Value
        if Value then
            if thirdPersonState.Task then pcall(task.cancel, thirdPersonState.Task) end
            thirdPersonState.Task = task.spawn(function()
                while thirdPersonState.Enabled do
                    local gun = getCameraController()
                    if gun and gun.CameraState then
                        pcall(function() gun.CameraState:_SetPOVState(gun.CameraState.States.ThirdPerson) end)
                    end
                    task.wait(0.1)
                end
            end)
        else
            stopThirdPerson()
        end
    end
})

-- ============================================================
-- Animation Player groupbox
-- ============================================================
local AnimationBox = Character:AddGroupbox({ Name = "Animation Player", Side = 2 })

AnimationBox:AddCheckbox("AnimationEnabled", {
    Text = "Enabled", Default = false,
    Callback = function(Value)
        animState.Enabled = Value
        if Value then
            if LocalPlayer.Character then
                playSelectedAnimation()
            else
                LocalPlayer.CharacterAdded:Once(function()
                    task.wait(0.5)
                    if animState.Enabled then playSelectedAnimation() end
                end)
            end
        else
            stopAnimation()
        end
    end
})

-- Animation 관련 UI 전부 Enabled 토글의 Depbox에
local AnimationControlsBox = AnimationBox:AddDependencyBox()

AnimationControlsBox:AddDropdown("AnimationSelected", {
    Text = "Animation", Values = animationList, Default = "Floss", Multi = false,
    Callback = function(Value)
        animState.Selected = Value
        animState.EmoteAdded = false
        if animState.Enabled then playSelectedAnimation() end
    end
})

AnimationControlsBox:AddInput("AnimationCustom", {
    Text = "Custom Animation ID", Default = "",
    Placeholder = "ex: 4049646104",
    Callback = function(Value)
        animState.Custom = Value
        if animState.Enabled and animState.Selected == "Custom" then
            playSelectedAnimation()
        end
    end
})

AnimationControlsBox:AddSlider("AnimationSpeed", {
    Text = "Speed", Default = 1, Min = 1, Max = 5, Rounding = 1, Compact = true,
    Callback = function(Value)
        animState.Speed = Value
        if animState.CurrentTrack then
            pcall(function() animState.CurrentTrack:AdjustSpeed(Value) end)
        end
    end
})

AnimationControlsBox:SetupDependencies({ { Toggles.AnimationEnabled, true } })

return true

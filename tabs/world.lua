--!nonstrict
local Hub = _G.MinhoHub
if not Hub then return end

local Lighting = Hub.Lighting
local World    = Hub.Tabs.World

local previousSkyboxBackend = getgenv().__MinhoSkyboxBackend
if previousSkyboxBackend and type(previousSkyboxBackend.Restore) == "function" then
    pcall(previousSkyboxBackend.Restore)
end

local skyboxState = getgenv().__MinhoSkyboxState or {
    Selected = "None",
    Enabled = false,
}
skyboxState.Selected = skyboxState.Selected or "None"
skyboxState.Enabled = skyboxState.Enabled == true
getgenv().__MinhoSkyboxState = skyboxState

local skyboxOriginal = nil
local skyboxCreated = false
local skyboxActive = false

local function captureSkyboxOriginals()
    if skyboxOriginal then return end
    local sky = Lighting:FindFirstChildOfClass("Sky")
    skyboxOriginal = {
        HasSky = sky ~= nil,
        Sky = sky,
        SkyProperties = sky and {
            SkyboxUp = sky.SkyboxUp,
            SkyboxFt = sky.SkyboxFt,
            SkyboxLf = sky.SkyboxLf,
            SkyboxDn = sky.SkyboxDn,
            SkyboxBk = sky.SkyboxBk,
            SkyboxRt = sky.SkyboxRt,
            SunAngularSize = sky.SunAngularSize,
            MoonAngularSize = sky.MoonAngularSize,
            StarCount = sky.StarCount,
        } or nil,
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        PostEffects = {},
    }
    for _, object in ipairs(Lighting:GetChildren()) do
        if object:IsA("PostEffect") then
            skyboxOriginal.PostEffects[object] = object.Enabled
        end
    end
end

local function restoreSkybox()
    if not skyboxOriginal then
        skyboxActive = false
        return
    end
    local sky = skyboxOriginal.Sky
    if skyboxOriginal.HasSky and sky and sky.Parent then
        local props = skyboxOriginal.SkyProperties
        if props then
            pcall(function()
                sky.SkyboxUp = props.SkyboxUp
                sky.SkyboxFt = props.SkyboxFt
                sky.SkyboxLf = props.SkyboxLf
                sky.SkyboxDn = props.SkyboxDn
                sky.SkyboxBk = props.SkyboxBk
                sky.SkyboxRt = props.SkyboxRt
                sky.SunAngularSize = props.SunAngularSize
                sky.MoonAngularSize = props.MoonAngularSize
                sky.StarCount = props.StarCount
            end)
        end
    elseif skyboxCreated and sky and sky.Parent then
        pcall(function() sky:Destroy() end)
    end
    pcall(function() Lighting.GlobalShadows = skyboxOriginal.GlobalShadows end)
    pcall(function() Lighting.FogEnd = skyboxOriginal.FogEnd end)
    for object, enabled in pairs(skyboxOriginal.PostEffects) do
        if object and object.Parent then
            pcall(function() object.Enabled = enabled end)
        end
    end
    skyboxActive = false
    skyboxCreated = false
end

local function applyFPSLighting()
    captureSkyboxOriginals()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then
        sky = Instance.new("Sky")
        sky.Parent = Lighting
        skyboxCreated = true
    end
    pcall(function()
        sky.SkyboxUp = "rbxassetid://11457548274"
        sky.SkyboxFt = "rbxassetid://11457548274"
        sky.SkyboxLf = "rbxassetid://11457548274"
        sky.SkyboxDn = "rbxassetid://11457548274"
        sky.SkyboxBk = "rbxassetid://11457548274"
        sky.SkyboxRt = "rbxassetid://11457548274"
        sky.SunAngularSize = 0
        sky.MoonAngularSize = 0
        sky.StarCount = 0
    end)
    for _, object in ipairs(Lighting:GetChildren()) do
        if object:IsA("PostEffect") then
            object.Enabled = false
        end
    end
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 100000
    skyboxActive = true
end

local function setSkyboxSelection(value)
    skyboxState.Selected = value
    if value == "None" then
        restoreSkybox()
    elseif value == "FPS Skybox" then
        applyFPSLighting()
    end
end

getgenv().__MinhoSkyboxBackend = { Restore = restoreSkybox }

local Skybox = World:AddGroupbox({ Name = "Skybox", Side = 1 })

Skybox:AddCheckbox("SkyboxEnabled", {
    Text = "Skybox",
    Default = skyboxState.Enabled,
    Callback = function(Value)
        skyboxState.Enabled = Value
        if Value then
            local selected = skyboxState.Selected or "None"
            if selected ~= "None" then
                setSkyboxSelection(selected)
            end
        else
            restoreSkybox()
        end
    end
})

Skybox:AddDropdown("SkyboxType", {
    Text = "Skybox Type",
    Values = { "None", "FPS Skybox" },
    Default = skyboxState.Selected,
    Multi = false,
    Callback = function(Value)
        setSkyboxSelection(Value)
    end
})

if skyboxState.Selected == "FPS Skybox" and skyboxState.Enabled then
    applyFPSLighting()
else
    restoreSkybox()
end

local TexturePackBox = World:AddGroupbox({ Name = "Texture Pack", Side = 2 })

local function getAsset(url)
    local success, result = pcall(function()
        if writefile and isfile and getcustomasset then
            local fileName = "mc_" .. tostring(#url % 100000) .. ".asset"
            if not isfile(fileName) then
                local data = game:HttpGet(url)
                if data and #data > 80 then
                    writefile(fileName, data)
                end
            end
            local asset = getcustomasset(fileName)
            if asset and asset ~= "" then
                return asset
            end
        end
        return url
    end)
    return (success and result) or url
end

local MAP_TEXTURE_ID = "7658055825"

local TEXTURE_PACKS = {
    ["Minecraft"] = {
        {ids = {7658055825}, url = getAsset("https://raw.githubusercontent.com/jixyuk12nh-maker/Ui/main/texture_pack/Minecraft.png")},
    },
    ["Grods"] = {
        {ids = {7658055825}, url = getAsset("https://raw.githubusercontent.com/jixyuk12nh-maker/Ui/main/texture_pack/Grods.png")},
    },
}

local texturePackState = getgenv().__MinhoTexturePackState or {
    Selected = "None", Enabled = false, Applied = false,
    OriginalTextures = {}, Connections = {},
}
getgenv().__MinhoTexturePackState = texturePackState

local function saveOriginalTexture(obj)
    if not obj then return end
    local key = obj:GetDebugId()
    if not texturePackState.OriginalTextures[key] then
        texturePackState.OriginalTextures[key] = { Object = obj, Texture = obj.Texture }
    end
end

local function restoreOriginalTextures()
    for key, data in pairs(texturePackState.OriginalTextures) do
        if data.Object and data.Object.Parent then
            pcall(function() data.Object.Texture = data.Texture end)
        end
        texturePackState.OriginalTextures[key] = nil
    end
    texturePackState.Applied = false
end

local function applyTexturePack(packName)
    restoreOriginalTextures()
    for _, conn in ipairs(texturePackState.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    texturePackState.Connections = {}

    if packName == "None" then
        texturePackState.Selected = "None"
        return
    end
    local pack = TEXTURE_PACKS[packName]
    if not pack then return end
    texturePackState.Selected = packName

    local function processObject(obj)
        if obj:IsA("Decal") or obj:IsA("Texture") then
            local success, value = pcall(function() return obj.Texture end)
            if success and type(value) == "string" then
                local id = string.match(value, "%d+")
                if id == MAP_TEXTURE_ID then
                    for _, texData in ipairs(pack) do
                        for _, targetId in ipairs(texData.ids) do
                            if tonumber(id) == targetId then
                                saveOriginalTexture(obj)
                                pcall(function() obj.Texture = texData.url end)
                                return
                            end
                        end
                    end
                end
            end
        elseif obj:IsA("MeshPart") then
            local success, value = pcall(function() return obj.TextureID end)
            if success and type(value) == "string" then
                local id = string.match(value, "%d+")
                if id == MAP_TEXTURE_ID then
                    for _, texData in ipairs(pack) do
                        for _, targetId in ipairs(texData.ids) do
                            if tonumber(id) == targetId then
                                pcall(function() obj.TextureID = texData.url end)
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    for _, obj in ipairs(game:GetDescendants()) do
        pcall(processObject, obj)
    end
    local conn = game.DescendantAdded:Connect(function(obj)
        task.defer(processObject, obj)
    end)
    table.insert(texturePackState.Connections, conn)
    texturePackState.Applied = true
end

TexturePackBox:AddCheckbox("TexturePackEnabled", {
    Text = "Texture Pack",
    Default = false,
    Callback = function(Value)
        texturePackState.Enabled = Value
        if Value then
            if texturePackState.Selected and texturePackState.Selected ~= "None" then
                applyTexturePack(texturePackState.Selected)
            end
        else
            restoreOriginalTextures()
            for _, conn in ipairs(texturePackState.Connections) do
                pcall(function() conn:Disconnect() end)
            end
            texturePackState.Connections = {}
        end
    end
})

TexturePackBox:AddDropdown("TexturePack", {
    Text = "Texture Pack",
    Values = { "None", "Minecraft", "Grods" },
    Default = texturePackState.Selected or "None",
    Multi = false,
    Callback = function(Value)
        texturePackState.Selected = Value
        if texturePackState.Enabled then
            if Value == "None" then
                restoreOriginalTextures()
            else
                applyTexturePack(Value)
            end
        end
    end
})

if texturePackState.Enabled and texturePackState.Selected
    and texturePackState.Selected ~= "None" then
    applyTexturePack(texturePackState.Selected)
end

return true

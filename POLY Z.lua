-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Load Rayfield UI Library
local Rayfield = loadstring(game:HttpGet('https://limerbro.github.io/Roblox-Limer/rayfield.lua'))()

-- UI Window Configuration
local Window = Rayfield:CreateWindow({
    Name = "✨ LimerHub Custom ✨ | POLY-Z",
    Icon = 71338090068856,
    LoadingTitle = "Loading...",
    LoadingSubtitle = "Author: LimerBoy",
    Theme = "BlackWhite",
    ToggleUIKeybind = Enum.KeyCode.K,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "ZombieHub",
        FileName = "Config"
    }
})

-- Utility Functions
local function getEquippedWeaponName()
    local model = workspace:FindFirstChild("Players"):FindFirstChild(player.Name)
    if model then
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("Model") then
                return child.Name
            end
        end
    end
    return "M1911"
end

-- Combat Tab
local CombatTab = Window:CreateTab("⚔️ Combat", "Skull")

-- Weapon Label
local weaponLabel = CombatTab:CreateLabel("🔫 Current Weapon: Loading...")

-- Update label
task.spawn(function()
    while true do
        weaponLabel:Set("🔫 Current Weapon: " .. getEquippedWeaponName())
        task.wait(0.1)
    end
end)

-- Auto Headshots
local autoKill = false
local shootDelay = 0.1
local manualHeadshot = false
local mouse = player:GetMouse()

local function getZombieContainer()
    return workspace:FindFirstChild("Zombies") or workspace:FindFirstChild("Enemies")
end

local function isZombieModel(model, enemiesFolder)
    if not model or not model:IsA("Model") then
        return false
    end

    if enemiesFolder and model.Parent ~= enemiesFolder then
        return false
    end

    if Players:GetPlayerFromCharacter(model) then
        return false
    end

    local playersFolder = workspace:FindFirstChild("Players")
    if playersFolder and playersFolder:FindFirstChild(model.Name) then
        return false
    end

    return model:FindFirstChild("Head") ~= nil
end

local function isZombieAlive(zombie)
    if not zombie or not zombie.Parent or not isZombieModel(zombie, zombie.Parent) then
        return false
    end

    local head = zombie:FindFirstChild("Head")
    local humanoid = zombie:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid.Health > 0 and head ~= nil
    end

    return head ~= nil
end

-- LOS check: raycast from HumanoidRootPart to head, single call only at fire time
local function isHeadVisible(head, rootPart)
    if not head or not rootPart then return false end
    local origin = rootPart.Position
    local direction = head.Position - origin

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local character = player.Character
    rayParams.FilterDescendantsInstances = character and {character} or {}

    local result = workspace:Raycast(origin, direction, rayParams)
    if not result then return true end
    -- Allow if the ray hit a part of the zombie itself (e.g. torso in the way)
    local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
    return hitModel == head.Parent
end

-- Simple distance-only selection (LOS is only checked at fire time)
local function getClosestZombie(enemies, fromPosition)
    local closestZombie
    local closestDistance

    for _, zombie in pairs(enemies:GetChildren()) do
        if isZombieModel(zombie, enemies) and isZombieAlive(zombie) then
            local head = zombie:FindFirstChild("Head")
            local distance = (head.Position - fromPosition).Magnitude
            if not closestDistance or distance < closestDistance then
                closestDistance = distance
                closestZombie = zombie
            end
        end
    end

    return closestZombie
end

local function getAimedZombie(enemies)
    local target = mouse and mouse.Target
    if not target then
        return nil
    end

    local model = target:FindFirstAncestorOfClass("Model")
    if model and isZombieModel(model, enemies) and isZombieAlive(model) then
        return model
    end

    return nil
end

local function randomOffset(magnitude)
    return Vector3.new(
        (math.random() - 0.5) * 2 * magnitude,
        (math.random() - 0.5) * 2 * magnitude,
        (math.random() - 0.5) * 2 * magnitude
    )
end

local function fireClosestHeadshot()
    local enemies = getZombieContainer()
    local shootRemote = Remotes:FindFirstChild("ShootEnemy")
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")

    if not enemies or not shootRemote or not rootPart then
        return
    end

    local targetZombie = getAimedZombie(enemies) or getClosestZombie(enemies, rootPart.Position)
    local targetHead = targetZombie and targetZombie:FindFirstChild("Head")

    -- Only fire if the head has clear line of sight (not behind a wall)
    if targetZombie and targetHead and isHeadVisible(targetHead, rootPart) then
        local weapon = getEquippedWeaponName()
        local hitPos = targetHead.Position + randomOffset(0.15)
        local dmgMult = 0.5 + (math.random() - 0.5) * 0.04
        task.delay(math.random() * 0.03, function()
            pcall(function()
                shootRemote:FireServer(targetZombie, targetHead, hitPos, dmgMult, weapon)
            end)
        end)
    end
end

-- Headshot on Fire: InputBegan sin filtro gameProcessed para que funcione con arma equipada
-- Solo ignoramos clicks cuando el usuario está escribiendo en un TextBox
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if UserInputService:GetFocusedTextBox() then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and manualHeadshot then
        fireClosestHeadshot()
    end
end)

-- Text input for shot delay
CombatTab:CreateInput({
    Name = "⏱️ Shot delay (0-2 sec)",
    PlaceholderText = "0.1",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local num = tonumber(text)
        if num and num >= 0 and num <= 2 then
            shootDelay = num
            Rayfield:Notify({
                Title = "Success",
                Content = "Shot delay set to "..num.." seconds",
                Duration = 3,
                Image = 4483362458
            })
        else
            Rayfield:Notify({
                Title = "Error",
                Content = "Please enter a number between 0 and 2",
                Duration = 3,
                Image = 4483362458
            })
        end
    end,
})

CombatTab:CreateToggle({
    Name = "🔪 Auto Headshots",
    CurrentValue = false,
    Flag = "AutoKillZombies",
    Callback = function(state)
        autoKill = state
        if state then
            task.spawn(function()
                local currentTarget
                while autoKill do
                    local enemies = getZombieContainer()
                    local shootRemote = Remotes:FindFirstChild("ShootEnemy")
                    if enemies and shootRemote then
                        local character = player.Character
                        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

                        if rootPart then
                            if not isZombieAlive(currentTarget) then
                                currentTarget = getClosestZombie(enemies, rootPart.Position)
                            end

                            if isZombieAlive(currentTarget) then
                                local head = currentTarget:FindFirstChild("Head")
                                -- Only fire if head is visible (not behind a wall)
                                if isHeadVisible(head, rootPart) then
                                    local weapon = getEquippedWeaponName()
                                    local hitPos = head.Position + randomOffset(0.15)
                                    local dmgMult = 0.5 + (math.random() - 0.5) * 0.04
                                    local args = {currentTarget, head, hitPos, dmgMult, weapon}
                                    pcall(function() shootRemote:FireServer(unpack(args)) end)
                                end
                            else
                                currentTarget = nil
                            end
                        end
                    end
                    -- Random jitter on fire rate to avoid mechanical timing detection
                    task.wait(shootDelay + (math.random() - 0.5) * shootDelay * 0.3)
                end
            end)
        end
    end
})

CombatTab:CreateToggle({
    Name = "🎯 Headshot on Fire",
    CurrentValue = false,
    Flag = "HeadshotOnFire",
    Callback = function(state)
        manualHeadshot = state
    end
})

CombatTab:CreateToggle({
    Name = "⏩ Auto Skip Round",
    CurrentValue = false,
    Flag = "AutoSkipRound",
    Callback = function(state)
        autoSkip = state
        if state then
            task.spawn(function()
                while autoSkip do
                    local skip = Remotes:FindFirstChild("CastClientSkipVote")
                    if skip then
                        pcall(function() skip:FireServer() end)
                    end
                    task.wait(0.1)
                end
            end)
        end
    end
})

CombatTab:CreateSlider({
    Name = "🏃‍♂️ Walk Speed",
    Range = {16, 200},
    Increment = 1,
    Suffix = "units",
    CurrentValue = 16,
    Flag = "WalkSpeed",
    Callback = function(Value)
        game.Players.LocalPlayer.Character:WaitForChild("Humanoid").WalkSpeed = Value
    end
})

-- Misc Tab
local MiscTab = Window:CreateTab("✨ Utilities", "Sparkles")

MiscTab:CreateSection("🔧 Tools")

MiscTab:CreateButton({
    Name = "🚪 Delete All Doors",
    Callback = function()
        local doorsFolder = workspace:FindFirstChild("Doors")
        if doorsFolder then
            for _, group in pairs(doorsFolder:GetChildren()) do
                if group:IsA("Folder") or group:IsA("Model") then
                    group:Destroy()
                end
            end
            Rayfield:Notify({
                Title = "Success",
                Content = "All doors deleted!",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

MiscTab:CreateButton({
    Name = "🎯 Infinite Magazines",
    Callback = function()
        local vars = player:FindFirstChild("Variables")
        if not vars then return end

        local ammoAttributes = {  
            "Primary_Mag",  
            "Secondary_Mag"  
        }  

        for _, attr in ipairs(ammoAttributes) do  
            if vars:GetAttribute(attr) ~= nil then  
                vars:SetAttribute(attr, 100000000)  
            end  
        end
        Rayfield:Notify({
            Title = "Magazines",
            Content = "Infinite magazines set!",
            Duration = 3,
            Image = 4483362458
        })
    end
})

MiscTab:CreateSection("💎 Enhancements Visual")

MiscTab:CreateButton({
    Name = "🌟 Activate All Perks",
    Callback = function()
        local vars = player:FindFirstChild("Variables")
        if not vars then return end

        local perks = {  
            "Bandoiler_Perk",  
            "DoubleUp_Perk",  
            "Haste_Perk",  
            "Tank_Perk",  
            "GasMask_Perk",  
            "DeadShot_Perk",  
            "DoubleMag_Perk",  
            "WickedGrenade_Perk"  
        }  

        for _, perk in ipairs(perks) do  
            if vars:GetAttribute(perk) ~= nil then  
                vars:SetAttribute(perk, true)  
            end  
        end
        Rayfield:Notify({
            Title = "Perks",
            Content = "All perks activated!",
            Duration = 3,
            Image = 4483362458
        })
    end
})

MiscTab:CreateButton({
    Name = "🔫 Enhance Weapons",
    Callback = function()
        local vars = player:FindFirstChild("Variables")
        if not vars then return end

        local enchants = {  
            "Primary_Enhanced",  
            "Secondary_Enhanced"  
        }  

        for _, attr in ipairs(enchants) do  
            if vars:GetAttribute(attr) ~= nil then  
                vars:SetAttribute(attr, true)  
            end  
        end
        Rayfield:Notify({
            Title = "Enhancement",
            Content = "Weapons enhanced!",
            Duration = 3,
            Image = 4483362458
        })
    end
})

MiscTab:CreateButton({
    Name = "💫 Celestial Weapons",
    Callback = function()
        local gunData = player:FindFirstChild("GunData")
        if not gunData then return end

        for _, value in ipairs(gunData:GetChildren()) do  
            if value:IsA("StringValue") then  
                value.Value = "celestial"  
            end  
        end
        Rayfield:Notify({
            Title = "Weapons",
            Content = "Set to Celestial tier!",
            Duration = 3,
            Image = 4483362458
        })
    end
})

-- Open Tab
local OpenTab = Window:CreateTab("🎁 Crates", "Gift")

local selectedQuantity = 1
local selectedOutfitType = "Random"

OpenTab:CreateDropdown({
    Name = "🔢 Open Quantity",
    Options = {"1", "25", "50", "200"},
    CurrentOption = "1",
    Flag = "OpenQuantity",
    Callback = function(Option)
        selectedQuantity = tonumber(Option)
    end,
})

OpenTab:CreateSection("📦 Auto Open Crates")

OpenTab:CreateDropdown({
    Name = "👕 Outfit Type",
    Options = {
        "Random", "Hat", "torseaccessory", "legaccessory", "faceaccessory", 
        "armaccessory", "backaccessory", "gloves", "shoes", "hair",
        "shirt", "pants", "haircolor", "skincolor", "face"
    },
    CurrentOption = "Random",
    Callback = function(option)
        selectedOutfitType = option
    end,
})

local autoOpenCamo = false
OpenTab:CreateToggle({
    Name = "🕶️ Camo Crates",
    CurrentValue = false,
    Callback = function(state)
        autoOpenCamo = state
        if state then
            task.spawn(function()
                while autoOpenCamo do
                    pcall(function()
                        for i = 1, selectedQuantity do
                            ReplicatedStorage.Remotes.OpenCamoCrate:InvokeServer("Random")
                            task.wait(0.1)
                        end
                    end)
                    task.wait(1)
                end
            end)
        end
    end
})

local autoOpenOutfit = false
OpenTab:CreateToggle({
    Name = "👕 Outfit Crates",
    CurrentValue = false,
    Callback = function(state)
        autoOpenOutfit = state
        if state then
            task.spawn(function()
                while autoOpenOutfit do
                    pcall(function()
                        for i = 1, selectedQuantity do
                            ReplicatedStorage.Remotes.OpenOutfitCrate:InvokeServer(selectedOutfitType)
                            task.wait(0.1)
                        end
                    end)
                    task.wait(1)
                end
            end)
        end
    end
})

local autoOpenPet = false
OpenTab:CreateToggle({
    Name = "🐾 Pet Crates",
    CurrentValue = false,
    Callback = function(state)
        autoOpenPet = state
        if state then
            task.spawn(function()
                while autoOpenPet do
                    pcall(function()
                        for i = 1, selectedQuantity do
                            ReplicatedStorage.Remotes.OpenPetCrate:InvokeServer(1)
                            task.wait(0.1)
                        end
                    end)
                    task.wait(0.1)
                end
            end)
        end
    end
})

local autoOpenGun = false
OpenTab:CreateToggle({
    Name = "🔫 Weapon Crates",
    CurrentValue = false,
    Callback = function(state)
        autoOpenGun = state
        if state then
            task.spawn(function()
                while autoOpenGun do
                    pcall(function()
                        for i = 1, selectedQuantity do
                            ReplicatedStorage.Remotes.OpenGunCrate:InvokeServer(1)
                            task.wait(0.1)
                        end
                    end)
                    task.wait(0.1)
                end
            end)
        end
    end
})

-- Mod Tab
local ModTab = Window:CreateTab("🌀 Mods", "Skull")

local spinning = false
local angle = 0
local speed = 5
local radius = 15

local HRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(char)
    HRP = char:WaitForChild("HumanoidRootPart")
end)

RunService.RenderStepped:Connect(function(dt)
    if spinning and HRP then
        local function findNearestBoss()
            local bosses = {
                workspace.Enemies:FindFirstChild("GoblinKing"),
                workspace.Enemies:FindFirstChild("CaptainBoom"),
                workspace.Enemies:FindFirstChild("Fungarth")
            }

            local nearestBoss = nil
            local shortestDistance = math.huge

            for _, boss in pairs(bosses) do
                if boss and boss:FindFirstChild("Head") then
                    local distance = (boss.Head.Position - HRP.Position).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        nearestBoss = boss
                    end
                end
            end
            return nearestBoss
        end

        local boss = findNearestBoss()
        if boss and boss:FindFirstChild("Head") then
            angle += dt * speed
            local bossPos = boss.Head.Position
            local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
            local orbitPos = bossPos + offset
            HRP.CFrame = CFrame.new(Vector3.new(orbitPos.X, bossPos.Y, orbitPos.Z), bossPos)
        end
    end
end)

ModTab:CreateToggle({
    Name = "🌪️ Orbit Around Boss",
    CurrentValue = false,
    Callback = function(value)
        spinning = value
    end
})

ModTab:CreateSlider({
    Name = "⚡ Rotation Speed",
    Range = {1, 20},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = 5,
    Callback = function(val)
        speed = val
    end
})

ModTab:CreateSlider({
    Name = "📏 Orbit Radius",
    Range = {5, 100},
    Increment = 1,
    Suffix = "units",
    CurrentValue = 15,
    Callback = function(val)
        radius = val
    end
})

ModTab:CreateButton({
    Name = "🛸 TP & Smart Platform",
    Callback = function()
        local HRP = player.Character and player.Character:WaitForChild("HumanoidRootPart")
        if not HRP then
            warn("❌ HumanoidRootPart no encontrado")
            return
        end

        local currentPos = HRP.Position
        local targetPos = currentPos + Vector3.new(0, 60, 0)

        local platform = Instance.new("Part")
        platform.Size = Vector3.new(20, 1, 20)
        platform.Anchored = true
        platform.Position = targetPos - Vector3.new(0, 2, 0)
        platform.Color = Color3.fromRGB(120, 120, 120)
        platform.Material = Enum.Material.Metal
        platform.Name = "SmartPlatform"
        platform.Parent = workspace

        HRP.CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))

        local lastTouch = tick()

        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not platform or not platform.Parent then
                conn:Disconnect()
                return
            end

            local char = player.Character
            local humanoidRoot = char and char:FindFirstChild("HumanoidRootPart")
            if not humanoidRoot then return end

            local rayOrigin = humanoidRoot.Position
            local rayDirection = Vector3.new(0, -5, 0)
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {char}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

            local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
            if raycastResult and raycastResult.Instance == platform then
                lastTouch = tick()
            end

            if tick() - lastTouch > 10 then
                platform:Destroy()
                conn:Disconnect()
            end
        end)
    end
})

-- Load config
Rayfield:LoadConfiguration()
-- -- -- -- -- -- -- -- -- -- -- -- -- 
-- ### ห้ามแก้ไขใดๆไม่งั้น code จะเน่า ### --
-- -- -- -- -- -- -- -- -- -- -- -- --

repeat wait() until game:IsLoaded()
repeat wait() until game.Players.LocalPlayer.Character
repeat wait() until game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
repeat wait() until game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

wait(2)

if _G.AutoRob == true then
    warn("Auto Rob already loaded.")
    return nil
end

_G.AutoRob = true
queue_on_teleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/NtReadVirtualMemory/Open-Source-Scripts/refs/heads/main/Mad%20City%20Chapter%201/Auto%20Rob.lua'))()")

for i = 1, 100 do
   print("Made by NtOpenProcess and deni210 (on dc)")
end

local function setInvisible()
    local character = game.Players.LocalPlayer.Character
    if character then
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = 1  
                part.CanCollide = false 
            end
        end

        if character:FindFirstChild("Head") then
            local head = character.Head
            local billboard = head:FindFirstChild("BillboardGui")
            if billboard then
                billboard.Enabled = false 
            end
        end

        game.Players.LocalPlayer.Character:FindFirstChild("Head").Transparency = 1
    end
end

local function createFullScreenUI()
    local player = game.Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui", playerGui)
    screenGui.IgnoreGuiInset = true

    local textLabel = Instance.new("TextLabel", screenGui)
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.Text = "FinalRob By ครูไว"
    textLabel.TextColor3 = Color3.new(1, 1, 1) 
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextScaled = true
    textLabel.BackgroundTransparency = 1

    local function setRainbowTextColor()
        local colors = {
            Color3.fromHSV(0, 1, 1), 
            Color3.fromHSV(0.1667, 1, 1), 
            Color3.fromHSV(0.3333, 1, 1),
            Color3.fromHSV(0.5, 1, 1), 
            Color3.fromHSV(0.6667, 1, 1), 
            Color3.fromHSV(0.8333, 1, 1), 
            Color3.fromHSV(1, 1, 1)
        }
        local i = 1
        while textLabel.Parent do
            textLabel.TextColor3 = colors[i]
            i = i + 1
            if i > #colors then i = 1 end
            task.wait(0.1)
        end
    end

    task.spawn(setRainbowTextColor)

    task.spawn(function()
        for i = 1, 100 do
            textLabel.TextTransparency = i / 100
            textLabel.TextStrokeTransparency = i / 100
            task.wait(0.03)
        end
        
        textLabel.Text = "ถ้าตูนแจกจะเอาเกย์คิงมาหนมน้าตูน"
        
        for i = 1, 100 do
            textLabel.TextTransparency = i / 100
            textLabel.TextStrokeTransparency = i / 100
            task.wait(0.03)
        end
        
       
        local workingTextLabel = Instance.new("TextLabel", screenGui)
        workingTextLabel.Size = UDim2.new(0, 300, 0, 50) 
        workingTextLabel.Position = UDim2.new(0.5, -150, 0.5, -25)
        workingTextLabel.Text = "กำลังทำงาน..."
        workingTextLabel.TextColor3 = Color3.new(1, 1, 1)
        workingTextLabel.Font = Enum.Font.SourceSans
        workingTextLabel.TextSize = 20 
        workingTextLabel.BackgroundTransparency = 1

        
        local function setRainbowWorkingTextColor()
            local colors = {
                Color3.fromHSV(0, 1, 1), 
                Color3.fromHSV(0.1667, 1, 1), 
                Color3.fromHSV(0.3333, 1, 1),
                Color3.fromHSV(0.5, 1, 1), 
                Color3.fromHSV(0.6667, 1, 1), 
                Color3.fromHSV(0.8333, 1, 1), 
                Color3.fromHSV(1, 1, 1)
            }
            local i = 1
            while workingTextLabel.Parent do
                workingTextLabel.TextColor3 = colors[i]
                i = i + 1
                if i > #colors then i = 1 end
                task.wait(0.1)
            end
        end

        task.spawn(setRainbowWorkingTextColor)
    end)
end

local function tp(x, y, z)
    Game.Workspace.Pyramid.Tele.Core2.CanCollide = false
    Game.Workspace.Pyramid.Tele.Core2.Transparency = 1
    Game.Workspace.Pyramid.Tele.Core2.CFrame = Game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame
    task.wait()
    Game.Workspace.Pyramid.Tele.Core2.CFrame = CFrame.new(1231.14185, 51051.2344, 318.096191)
    Game.Workspace.Pyramid.Tele.Core2.Transparency = 0
    Game.Workspace.Pyramid.Tele.Core2.CanCollide = true
    task.wait()
    for i = 1, 45 do
        Game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
        task.wait()
    end
end

local MiniRobberies = {
    "Cash",
    "CashRegister",
    "DiamondBox",
    "Laptop",
    "Phone",
    "Luggage",
    "ATM",
    "TV",
    "Safe"
}

local function getevent(v)
    for i, v in next, v:GetDescendants() do
        if not v:IsA("RemoteEvent") then continue end
        return v
    end
end

local function getrobbery()
    for i, v in next, workspace.ObjectSelection:GetChildren() do
        if not table.find(MiniRobberies, v.Name) then continue end
        if v:FindFirstChild("Nope") then continue end
        if not getevent(v) then continue end
        return v
    end
end

local function autoRob()
    while true do
        tp(-82, 86, 807)
        task.wait(0.5)
        for i, v in pairs(workspace.JewelryStore.JewelryBoxes:GetChildren()) do
            task.spawn(function()
                for i = 1, 5 do
                    workspace.JewelryStore.JewelryBoxes.JewelryManager.Event:FireServer(v)
                end
            end)
        end
        task.wait(2)
        tp(2115, 26, 420)
        task.wait(1)

        repeat
            local robbery = getrobbery()
            if robbery then
                for i = 1, 20 do
                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(robbery:GetPivot().Position.x, robbery:GetPivot().Position.y + 5, robbery:GetPivot().Position.z)
                    getevent(robbery):FireServer()
                    task.wait()
                end
            end
        until getrobbery() == nil

        task.wait(1)
    end
end

local function startAutoRob()
    setInvisible()
    createFullScreenUI()
    autoRob()
end


local player = game.Players.LocalPlayer
player.Character.Humanoid.Died:Connect(function()
    repeat wait() until player.Character and player.Character:FindFirstChild("Humanoid")
    startAutoRob()
end)


startAutoRob()

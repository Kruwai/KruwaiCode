-- RyntazHub :: Titan Edition
-- Script Architecture by Gemini-AI for Ryntaz. All rights reserved.

local Player = game:GetService("Players").LocalPlayer
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Character, Humanoid, RootPart
local function waitForCharacter()
    repeat task.wait() until Player and Player.Character and Player.Character:FindFirstChild("Humanoid") and Player.Character:FindFirstChild("HumanoidRootPart")
    Character = Player.Character
    Humanoid = Character:FindFirstChildOfClass("Humanoid")
    RootPart = Character:FindFirstChild("HumanoidRootPart")
end
waitForCharacter()
Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid", 10)
    RootPart = newChar:WaitForChild("HumanoidRootPart", 10)
end)

local RyntazHub = {
    Data = { Raw = {}, Analyzed = {} },
    Capabilities = {},
    ActiveThreads = {},
    State = { IsScanning = false, IsRobbing = false }
}

--[[
====================================================================================================
    THEME & UI CONFIGURATION (ส่วนนี้คุณสามารถแก้ไขค่าสีและ Font ได้)
====================================================================================================
]]
local THEME = {
    -- Font Settings
    Font = {
        Main = Enum.Font.Michroma,
        UI = Enum.Font.SourceSans,
        Code = Enum.Font.Code
    },
    -- Color Palette
    Colors = {
        Background = Color3.fromRGB(18, 18, 22),
        Primary = Color3.fromRGB(25, 25, 30),
        Secondary = Color3.fromRGB(38, 38, 46),
        Accent = Color3.fromRGB(0, 150, 255),
        AccentBright = Color3.fromRGB(100, 200, 255),
        Text = Color3.fromRGB(240, 240, 245),
        TextDim = Color3.fromRGB(150, 150, 160),
        Success = Color3.fromRGB(0, 255, 120),
        Warning = Color3.fromRGB(255, 180, 0),
        Error = Color3.fromRGB(255, 80, 80),
        ProgressBarFill = Color3.fromRGB(0, 150, 255)
    },
    -- Animation Speeds
    Animation = {
        Fast = 0.15,
        Medium = 0.3,
        Slow = 0.5
    }
}
--[[
====================================================================================================
    MASTER HEIST & ROBBERY CONFIGURATION
====================================================================================================
]]
local MasterConfig = {
    JewelryStore = {
        DisplayName = "Jewelry Store",
        Identifiers = {
            Path = "Workspace.Heists.JewelryStore",
            HasDescendants = {"JewelryBoxes", "JewelryManager"}
        },
        Sequence = {
            {
                Name = "Collect All Jewelry",
                Type = "IterateAndFireEvent",
                ItemContainerPath = "EssentialParts.JewelryBoxes",
                ItemQuery = function(container) return container:GetChildren() end,
                RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event",
                EventArgsFunc = function(lootInstance) return {lootInstance} end,
                FireCountPerItem = 2,
                TeleportOffset = Vector3.new(0, 3, 0),
                DelayBetweenItems = 0.2,
                Progress = { Enabled = true, DurationPerItem = 0.2 }
            }
        }
    },
    Bank = {
        DisplayName = "City Bank",
        Identifiers = {
            Path = "Workspace.Heists.Bank",
            HasDescendants = {"VaultDoor", "Lasers"}
        },
        Sequence = {
            {
                Name = "Touch Vault Door",
                Type = "Touch",
                TargetPath = "EssentialParts.VaultDoor.Touch",
                TeleportOffset = Vector3.new(0, 0, -3),
                Cooldown = 2,
                Progress = { Enabled = true, Label = "Opening Vault...", Duration = 2 }
            },
            {
                Name = "Collect Cash Stacks",
                Type = "IterateAndFireEvent",
                ItemContainerPath = "Interior",
                ItemQuery = function(container)
                    local items = {}
                    for _,v in ipairs(container:GetDescendants()) do
                        if v.Name == "Cash" and v:IsA("BasePart") then table.insert(items, v) end
                    end
                    return items
                end,
                RemoteEventHint = "Collect", -- The script will try to find a RemoteEvent with this name
                EventArgsFunc = function(lootInstance) return {lootInstance} end,
                FireCountPerItem = 1,
                TeleportOffset = Vector3.new(0, 2, 0),
                DelayBetweenItems = 0.3,
                Progress = { Enabled = true, DurationPerItem = 0.3 }
            }
        }
    },
    Casino = {
        DisplayName = "Diamond Casino",
        Identifiers = {
            Path = "Workspace.Heists.Casino",
            HasDescendants = {"HackComputer"}
        },
        Sequence = {
            {
                Name = "Hack Mainframe",
                Type = "ProximityPrompt",
                TargetPath = "Interior.HackComputer.HackComputer",
                TeleportOffset = Vector3.new(0, 0, -2.5),
                HoldDuration = 3,
                Cooldown = 1,
                Progress = { Enabled = true, Label = "Hacking Mainframe...", Duration = 3 }
            },
            {
                Name = "Collect Vault Cash",
                Type = "Touch",
                TargetPath = "Interior.Model.Cash", -- This is a guess, adjust from logs
                TeleportOffset = Vector3.new(0, 2, 0),
                Progress = { Enabled = false }
            }
        }
    }
}
--[[
====================================================================================================
    END OF CONFIGURATION
====================================================================================================
]]

local UILib = {}
local MainUI = {}

function UILib.Create(element)
    return function(props)
        local obj = Instance.new(element)
        for k, v in pairs(props) do
            if type(k) == "number" then
                v.Parent = obj
            else
                obj[k] = v
            end
        end
        return obj
    end
end

function UILib.Shadow(parent)
    UILib.Create("ImageLabel"){
        Name = "DropShadow",
        Parent = parent,
        Size = UDim2.new(1, 4, 1, 4),
        Position = UDim2.new(0, -2, 0, -2),
        BackgroundTransparency = 1,
        Image = "rbxassetid://939639733",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.6,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(10, 10, 118, 118),
        ZIndex = parent.ZIndex - 1
    }
end

function UILib.Tween(obj, props, overrideInfo)
    local info = TweenInfo.new(
        overrideInfo and overrideInfo.Time or THEME.Animation.Medium,
        overrideInfo and overrideInfo.EasingStyle or Enum.EasingStyle.Quart,
        overrideInfo and overrideInfo.EasingDirection or Enum.EasingDirection.Out
    )
    TweenService:Create(obj, info, props):Play()
end

function MainUI:CreateNotification(title, text, style, duration)
    local notifFrame = UILib.Create("Frame"){
        Name = "Notification",
        Parent = MainUI.ScreenGui,
        Size = UDim2.new(0, 250, 0, 60),
        Position = UDim2.new(1, 5, 1, -80 * (#MainUI.ScreenGui:GetChildren() + 1)),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = THEME.Colors.Primary,
        BorderSizePixel = 0,
        ZIndex = 9999,
        {
            UILib.Create("UICorner"){ CornerRadius = UDim.new(0, 6) },
            UILib.Create("Frame"){
                Name = "ColorStripe",
                Size = UDim2.new(0, 4, 1, 0),
                BackgroundColor3 = THEME.Colors[style or "Accent"],
                BorderSizePixel = 0,
                { UILib.Create("UICorner"){ CornerRadius = UDim.new(0, 6) } }
            },
            UILib.Create("TextLabel"){
                Name = "Title",
                Size = UDim2.new(1, -15, 0, 25),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Font = THEME.Font.Main,
                Text = title or "Notification",
                TextColor3 = THEME.Colors.AccentBright,
                TextSize = 16,
                TextXAlignment = Enum.TextXAlignment.Left
            },
            UILib.Create("TextLabel"){
                Name = "Content",
                Size = UDim2.new(1, -15, 0, 30),
                Position = UDim2.new(0, 10, 0, 20),
                BackgroundTransparency = 1,
                Font = THEME.Font.UI,
                Text = text or "",
                TextColor3 = THEME.Colors.Text,
                TextSize = 14,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top
            }
        }
    }
    UILib.Shadow(notifFrame)
    UILib.Tween(notifFrame, { Position = UDim2.new(1, -15, 1, -80 * (#MainUI.ScreenGui:GetChildren())) }, { Time = THEME.Animation.Slow, EasingStyle = Enum.EasingStyle.Elastic })

    task.delay(duration or 5, function()
        if not notifFrame or not notifFrame.Parent then return end
        UILib.Tween(notifFrame, { Position = notifFrame.Position + UDim2.new(0, 300, 0, 0), Transparency = 1 }, { Time = THEME.Animation.Medium })
        task.wait(THEME.Animation.Medium)
        if notifFrame and notifFrame.Parent then notifFrame:Destroy() end
    end)
end

function MainUI:CreateProgressBar(parent, label)
    local container = UILib.Create("Frame"){
        Name = "ProgressBarContainer",
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }

    local bar = UILib.Create("Frame"){
        Name = "ProgressBar",
        Parent = container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = THEME.Colors.Secondary,
        BorderSizePixel = 0,
        {
            UILib.Create("UICorner"){ CornerRadius = UDim.new(0, 4) },
            UILib.Create("Frame"){
                Name = "Fill",
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = THEME.Colors.ProgressBarFill,
                BorderSizePixel = 0,
                { UILib.Create("UICorner"){ CornerRadius = UDim.new(0, 4) } }
            },
            UILib.Create("TextLabel"){
                Name = "Label",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Font = THEME.Font.Code,
                Text = label or "",
                TextColor3 = THEME.Colors.Text,
                TextSize = 13
            }
        }
    }

    function bar:Update(progress, text)
        UILib.Tween(bar.Fill, { Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0) }, { Time = THEME.Animation.Fast })
        if text then bar.Label.Text = text end
    end

    function bar:Run(duration, text)
        bar.Label.Text = text or ""
        bar.Fill.Size = UDim2.new(0,0,1,0)
        UILib.Tween(bar.Fill, { Size = UDim2.new(1, 0, 1, 0) }, { Time = duration, EasingStyle = Enum.EasingStyle.Linear })
    end
    
    return bar
end

function MainUI:CreateHeistCard(parent, heistData)
    local card = UILib.Create("Frame"){
        Name = "HeistCard",
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 120),
        BackgroundColor3 = THEME.Colors.Primary,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = 1,
        { UILib.Create("UICorner"){ CornerRadius = UDim.new(0, 6) } }
    }
    UILib.Shadow(card)

    local titleLabel = UILib.Create("TextLabel"){
        Name = "Title",
        Parent = card,
        Size = UDim2.new(1, -10, 0, 30),
        Position = UDim2.new(0, 5, 0, 5),
        BackgroundTransparency = 1,
        Font = THEME.Font.Main,
        Text = heistData.DisplayName,
        TextColor3 = THEME.Colors.AccentBright,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left
    }

    local statusLabel = UILib.Create("TextLabel"){
        Name = "Status",
        Parent = card,
        Size = UDim2.new(0.5, 0, 0, 20),
        Position = UDim2.new(0, 10, 0, 35),
        BackgroundTransparency = 1,
        Font = THEME.Font.Code,
        Text = "Status: Ready",
        TextColor3 = THEME.Colors.Success,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left
    }

    local stepsContainer = UILib.Create("ScrollingFrame"){
        Name = "StepsContainer",
        Parent = card,
        Size = UDim2.new(1, -10, 1, -75),
        Position = UDim2.new(0, 5, 0, 60),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarImageColor3 = THEME.Colors.Accent,
        ScrollBarThickness = 4,
        { UILib.Create("UIListLayout"){ Padding = UDim.new(0, 2) } }
    }
    
    for i, step in ipairs(heistData.AnalyzedSequence) do
        UILib.Create("TextLabel"){
            Name = "StepLabel",
            Parent = stepsContainer,
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Font = THEME.Font.Code,
            Text = string.format("[%d] %s", i, step.Name),
            TextColor3 = THEME.Colors.TextDim,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left
        }
    end
    
    local robButton = UILib.Create("TextButton"){
        Name = "RobButton",
        Parent = card,
        Size = UDim2.new(0.3, 0, 0, 30),
        Position = UDim2.new(0.95, 0, 0, 35),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = THEME.Colors.Accent,
        Font = THEME.Font.Main,
        Text = "START",
        TextColor3 = THEME.Colors.Background,
        TextSize = 16,
        { UILib.Create("UICorner"){ CornerRadius = UDim.new(0, 4) } }
    }
    
    robButton.MouseButton1Click:Connect(function()
        RyntazHub.ExecutionEngine:Run(heistData.Key)
    end)
    
    return card
end

function MainUI:Build()
    if MainUI.ScreenGui and MainUI.ScreenGui.Parent then MainUI.ScreenGui:Destroy() end

    MainUI.ScreenGui = UILib.Create("ScreenGui"){
        Name = "RyntazHubTitan",
        Parent = Player:WaitForChild("PlayerGui"),
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false
    }

    local introFrame = UILib.Create("Frame"){ Parent = MainUI.ScreenGui, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ZIndex = 9999 }
    local introText = UILib.Create("TextLabel"){ Parent = introFrame, Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0), AnchorPoint = Vector2.new(0.5,0.5), Font = THEME.Font.Main, Text = "Ryntaz Hub", TextColor3 = THEME.Colors.Accent, TextSize = 1, BackgroundTransparency = 1, Transparency = 1, Rotation = -10 }
    UILib.Tween(introText, { Size = UDim2.new(0.8,0,0.2,0), TextSize = 80, Transparency = 0, Rotation = 0 }, { Time = 0.8, EasingStyle = Enum.EasingStyle.Elastic, EasingDirection = Enum.EasingDirection.Out })
    task.wait(1.5)
    UILib.Tween(introText, { Transparency = 1, Position = UDim2.new(0.5,0,0.6,0) }, { Time = 0.4 })
    task.wait(0.4)
    introFrame:Destroy()

    MainUI.Frame = UILib.Create("Frame"){
        Name = "MainFrame",
        Parent = MainUI.ScreenGui,
        Size = UDim2.new(0.4, 0, 0.5, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = THEME.Colors.Background,
        BorderSizePixel = 0,
        Draggable = true,
        Active = true,
        ClipsDescendants = true,
        Visible = false,
        { UILib.Create("UICorner"){ CornerRadius = UDim.new(0, 8) } }
    }
    UILib.Shadow(MainUI.Frame)

    local titleBar = UILib.Create("Frame"){
        Name = "TitleBar",
        Parent = MainUI.Frame,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = THEME.Colors.Primary,
        BorderSizePixel = 0,
        {
            UILib.Create("TextLabel"){
                Name = "Title",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Font = THEME.Font.Main,
                Text = "RYNTAZHUB :: TITAN",
                TextColor3 = THEME.Colors.Text,
                TextSize = 16
            }
        }
    }
    
    local tabsContainer = UILib.Create("Frame"){
        Name = "TabsContainer",
        Parent = MainUI.Frame,
        Size = UDim2.new(0, 120, 1, -40),
        Position = UDim2.new(0, 0, 0, 40),
        BackgroundColor3 = THEME.Colors.Primary,
        BorderSizePixel = 0
    }
    
    local contentContainer = UILib.Create("Frame"){
        Name = "ContentContainer",
        Parent = MainUI.Frame,
        Size = UDim2.new(1, -120, 1, -40),
        Position = UDim2.new(0, 120, 0, 40),
        BackgroundTransparency = 1,
        ClipsDescendants = true
    }

    MainUI.Pages = {}
    MainUI.Tabs = {}

    local function createTab(name, icon)
        local page = UILib.Create("ScrollingFrame"){
            Name = name,
            Parent = contentContainer,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarImageColor3 = THEME.Colors.Accent,
            ScrollBarThickness = 6,
            { UILib.Create("UIPadding"){ PaddingTop = UDim.new(0,10), PaddingBottom = UDim.new(0,10), PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10) },
              UILib.Create("UIListLayout"){ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder } }
        }
        MainUI.Pages[name] = page

        local tabButton = UILib.Create("TextButton"){
            Name = name,
            Parent = tabsContainer,
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = THEME.Colors.Primary,
            Font = THEME.Font.UI,
            Text = name,
            TextColor3 = THEME.Colors.TextDim,
            TextSize = 16,
            AutoButtonColor = false,
            { UILib.Create("Frame"){ Name = "Indicator", Size = UDim2.new(0, 3, 0.8, 0), Position = UDim2.new(0,0,0.1,0), BackgroundColor3 = THEME.Colors.Accent, BorderSizePixel = 0, Visible = false } }
        }
        MainUI.Tabs[name] = tabButton
        
        tabButton.MouseButton1Click:Connect(function()
            for tName, tBtn in pairs(MainUI.Tabs) do
                MainUI.Pages[tName].Visible = (tName == name)
                tBtn.Indicator.Visible = (tName == name)
                UILib.Tween(tBtn, { TextColor3 = (tName == name) and THEME.Colors.Text or THEME.Colors.TextDim })
            end
        end)
    end
    
    createTab("Heists")
    createTab("Player")
    createTab("Settings")
    
    MainUI.Tabs["Heists"].MouseButton1Click:Invoke() -- Select first tab by default
    
    UILib.Tween(MainUI.Frame, { Visible = true, Size = UDim2.new(0.5,0,0.6,0) }, { Time = THEME.Animation.Slow, EasingStyle = Enum.EasingStyle.Elastic })
    
    local scanningBar = MainUI:CreateProgressBar(contentContainer, "Initializing...")
    scanningBar.Size = UDim2.new(1, -20, 0, 20)
    scanningBar.Position = UDim2.new(0,10,1,-30)
    scanningBar.ZIndex = 100
    
    RyntazHub.UIHooks = {
        ProgressBar = scanningBar,
        HeistsPage = MainUI.Pages["Heists"]
    }
end

RyntazHub.Scanner = {
    FindInstanceFromPath = function(path)
        local current = game
        for component in path:gmatch("([^%.]+)") do
            current = current:FindFirstChild(component)
            if not current then return nil end
        end
        return current
    end,
    Scan = function()
        RyntazHub.State.IsScanning = true
        local bar = RyntazHub.UIHooks.ProgressBar
        bar:Run(2, "Phase 1: Deep System Scan...")
        task.wait(2)

        RyntazHub.Data.Raw.Heists = {}
        for _, obj in ipairs(Workspace.Heists:GetChildren()) do
            table.insert(RyntazHub.Data.Raw.Heists, obj)
        end
        
        RyntazHub.Data.Raw.Remotes = {}
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                table.insert(RyntazHub.Data.Raw.Remotes, obj)
            end
        end
        
        MainUI:CreateNotification("Scan Complete", #RyntazHub.Data.Raw.Heists .. " Heists and " .. #RyntazHub.Data.Raw.Remotes .. " remotes found.", "Success")
        RyntazHub.State.IsScanning = false
    end
}

RyntazHub.Analyzer = {
    Analyze = function()
        local bar = RyntazHub.UIHooks.ProgressBar
        bar:Run(1.5, "Phase 2: Capability Analysis...")
        task.wait(1.5)
        
        RyntazHub.Capabilities = {}

        for key, config in pairs(MasterConfig) do
            local heistRoot
            local pathCheck = RyntazHub.Scanner:FindInstanceFromPath(config.Identifiers.Path)
            if pathCheck then
                local allIdentifiersMatch = true
                if config.Identifiers.HasDescendants then
                    for _, descendantName in ipairs(config.Identifiers.HasDescendants) do
                        if not pathCheck:FindFirstChild(descendantName, true) then
                            allIdentifiersMatch = false
                            break
                        end
                    end
                end
                if allIdentifiersMatch then heistRoot = pathCheck end
            end
            
            if heistRoot then
                local capabilityData = {
                    Key = key,
                    DisplayName = config.DisplayName,
                    Root = heistRoot,
                    AnalyzedSequence = {}
                }
                local sequencePossible = true
                for _, stepConfig in ipairs(config.Sequence) do
                    local analyzedStep = { Name = stepConfig.Name, Type = stepConfig.Type, Config = stepConfig, Target = nil }
                    if stepConfig.TargetPath then
                        analyzedStep.Target = heistRoot:FindFirstChild(stepConfig.TargetPath, true)
                    elseif stepConfig.ItemContainerPath then
                        analyzedStep.Target = heistRoot:FindFirstChild(stepConfig.ItemContainerPath, true)
                    end
                    
                    if not analyzedStep.Target then sequencePossible = false; break end
                    table.insert(capabilityData.AnalyzedSequence, analyzedStep)
                end
                
                if sequencePossible then
                    RyntazHub.Capabilities[key] = capabilityData
                end
            end
        end
        
        MainUI:CreateNotification("Analysis Complete", #RyntazHub.Capabilities .. " heists are ready to execute.", "Accent")
        bar:Update(1, "Analysis Complete. Building UI...")
        task.wait(0.5)
        bar.Parent:Destroy()
    end
}

RyntazHub.UIController = {
    PopulateHeists = function()
        local heistsPage = RyntazHub.UIHooks.HeistsPage
        for _, child in ipairs(heistsPage:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        
        for key, heistData in pairs(RyntazHub.Capabilities) do
            MainUI:CreateHeistCard(heistsPage, heistData)
        end
    end
}

RyntazHub.ExecutionEngine = {
    Run = function(heistKey)
        if RyntazHub.State.IsRobbing then
            MainUI:CreateNotification("Execution Error", "Another heist is already in progress.", "Error")
            return
        end
        
        local capability = RyntazHub.Capabilities[heistKey]
        if not capability then
            MainUI:CreateNotification("Execution Error", "Could not find capability data for " .. heistKey, "Error")
            return
        end

        RyntazHub.State.IsRobbing = true
        MainUI:CreateNotification("Heist Started", "Executing " .. capability.DisplayName .. " sequence.", "Accent")
        
        RyntazHub.ActiveThreads[heistKey] = task.spawn(function()
            for i, step in ipairs(capability.AnalyzedSequence) do
                if not RyntazHub.State.IsRobbing then break end
                
                local config = step.Config
                MainUI:CreateNotification("Step " .. i, "Executing: " .. config.Name, "TextDim", 2)
                
                if config.Type == "Touch" and step.Target then
                    pcall(function() RootPart.CFrame = step.Target.CFrame + (config.TeleportOffset or Vector3.new()) end)
                    task.wait(0.1)
                    if typeof(firetouchinterest) == "function" then
                        firetouchinterest(step.Target, RootPart, 0)
                        task.wait(0.05)
                        firetouchinterest(step.Target, RootPart, 1)
                    end
                elseif config.Type == "ProximityPrompt" and step.Target and typeof(fireproximityprompt) == "function" then
                    local prompt = step.Target:FindFirstChildOfClass("ProximityPrompt")
                    if prompt then
                        pcall(function() RootPart.CFrame = step.Target.CFrame + (config.TeleportOffset or Vector3.new()) end)
                        task.wait(0.1)
                        fireproximityprompt(prompt, config.HoldDuration or 0)
                    end
                elseif config.Type == "IterateAndFireEvent" and step.Target then
                    local remote = RyntazHub.Scanner:FindInstanceFromPath(config.RemoteEventPath)
                    local items = config.ItemQuery(step.Target)
                    if remote and items and #items > 0 then
                        for _, item in ipairs(items) do
                            pcall(function() RootPart.CFrame = item.CFrame + (config.TeleportOffset or Vector3.new()) end)
                            task.wait(config.DelayBetweenItems or 0.1)
                            for _ = 1, config.FireCountPerItem or 1 do
                                remote:FireServer(unpack(config.EventArgsFunc(item)))
                                task.wait(0.05)
                            end
                        end
                    end
                end
                
                if config.Cooldown then task.wait(config.Cooldown) end
            end
            
            MainUI:CreateNotification("Heist Complete", capability.DisplayName .. " finished successfully.", "Success")
            RyntazHub.State.IsRobbing = false
        end)
    end
}

-- Main Execution Flow
task.spawn(function()
    MainUI:Build()
    RyntazHub.Scanner:Scan()
    RyntazHub.Analyzer:Analyze()
    RyntazHub.UIController:PopulateHeists()
end)

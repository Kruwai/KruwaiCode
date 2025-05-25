-- RyntazHub :: Titan Edition (V3.0.4 - Intensive Debug Logging)

local Player = game:GetService("Players").LocalPlayer
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- ================= DEBUG UI (สร้างทันที) =================
local debugScreenGui, debugLabel
local function setupDebugLabel()
    if Player and Player:FindFirstChild("PlayerGui") then
        debugScreenGui = Player.PlayerGui:FindFirstChild("RyntazLiveDebugScreen")
        if not debugScreenGui then
            debugScreenGui = Instance.new("ScreenGui", Player.PlayerGui)
            debugScreenGui.Name = "RyntazLiveDebugScreen"
            debugScreenGui.ResetOnSpawn = false
            debugScreenGui.DisplayOrder = 20000 -- ให้อยู่บนสุดมากๆ
        end

        debugLabel = debugScreenGui:FindFirstChild("RyntazLiveDebugLabel")
        if not debugLabel then
            debugLabel = Instance.new("TextLabel", debugScreenGui)
            debugLabel.Name = "RyntazLiveDebugLabel"
            debugLabel.Size = UDim2.new(1, 0, 0.15, 0) -- ขยายให้ใหญ่ขึ้น
            debugLabel.Position = UDim2.new(0, 0, 0, 0)
            debugLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
            debugLabel.BackgroundTransparency = 0.2
            debugLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- สีเขียว hacker
            debugLabel.Font = Enum.Font.Code
            debugLabel.TextSize = 12
            debugLabel.TextWrapped = true
            debugLabel.TextXAlignment = Enum.TextXAlignment.Left
            debugLabel.TextYAlignment = Enum.TextYAlignment.Top
            debugLabel.ZIndex = 20001
            debugLabel.ClipsDescendants = true
        end
        debugLabel.Text = "[DEBUGGER INIT]\n"
    else
        print("[DEBUGGER_ERROR] PlayerGui not found for debug label.")
    end
end
setupDebugLabel() -- สร้าง Debug Label ทันที

local function liveDebug(message)
    print("[LIVE_DEBUG] " .. tostring(message))
    if debugLabel and debugLabel.Parent then
        debugLabel.Text = debugLabel.Text .. os.date("[%H:%M:%S] ") .. tostring(message) .. "\n"
        -- Auto scroll (basic)
        if debugLabel:IsA("TextLabel") then
            -- This basic auto-scroll might not work perfectly for TextLabel,
            -- but it's better than nothing if ScrollingFrame for debug is too complex now.
        end
    end
end

liveDebug("Script V3.0.4 Started. Services Loaded.")

-- ================= CHARACTER WAIT =================
local Character, Humanoid, RootPart
local function waitForCharacter()
    liveDebug("waitForCharacter: Called")
    local attempts = 0
    repeat
        attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character
            Humanoid = Character:FindFirstChildOfClass("Humanoid")
            RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then
                liveDebug("waitForCharacter: Character and parts FOUND on attempt " .. attempts)
                return true
            end
        end
        liveDebug("waitForCharacter: Attempt " .. attempts .. " - Still waiting...")
        task.wait(0.2)
    until attempts > 50 
    liveDebug("waitForCharacter: FAILED after 50 attempts.")
    return false
end

-- ================= RyntazHub TABLE =================
local RyntazHub = {
    Data = { Raw = { Heists = {}, Remotes = {}, Scripts = {}, Prompts = {}, TouchParts = {}, PotentialLoot = {} }, Analyzed = {} },
    Capabilities = {}, ActiveThreads = {},
    State = { IsScanning = false, IsRobbing = false, CurrentHeist = nil, CurrentAction = nil },
    UI = {}, Scanner = {}, Analyzer = {}, UIController = {}, ExecutionEngine = {}
}
liveDebug("RyntazHub table initialized.")

--[[ THEME & MASTER CONFIGURATION (เหมือนเดิมจาก V3.0.2 / ล่าสุดที่คุณส่ง Log มา) ]]
local THEME = { Font = { Main = Enum.Font.Michroma, UI = Enum.Font.SourceSans, Code = Enum.Font.Code, Title = Enum.Font.Michroma }, Colors = { Background = Color3.fromRGB(17,17,23), Primary = Color3.fromRGB(24,24,32), Secondary = Color3.fromRGB(35,35,45), Accent = Color3.fromRGB(0,190,255), AccentBright = Color3.fromRGB(100,220,255), Text = Color3.fromRGB(235,235,240), TextDim = Color3.fromRGB(160,160,170), Success = Color3.fromRGB(30,220,120), Warning = Color3.fromRGB(255,190,0), Error = Color3.fromRGB(255,70,70), ProgressBarFill = Color3.fromRGB(0,190,255), CloseButton = Color3.fromRGB(255,95,86), MinimizeButton = Color3.fromRGB(255,189,46), MaximizeButton = Color3.fromRGB(40,200,65) }, Animation = { Fast = 0.15, Medium = 0.3, Slow = 0.5, Intro = 0.8 } }
local MasterConfig = { JewelryStore = { DisplayName = "ร้านเพชร", Identifiers = { Path = "Workspace.Heists.JewelryStore", HasDescendants = {"EssentialParts.JewelryBoxes", "EssentialParts.JewelryBoxes.JewelryManager"} }, EntryTeleport = CFrame.new(-82,86,807), Sequence = { { Name = "เก็บเครื่องเพชร", Type = "IterateAndFireEvent", ItemContainerPath = "EssentialParts.JewelryBoxes", ItemQuery = function(container) local items = {}; for _,c in ipairs(container:GetChildren()) do if c:IsA("Model") or c:IsA("BasePart") then table.insert(items, c) end end; return items end, RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event", EventArgsFunc = function(lootInstance) return {lootInstance} end, FireCountPerItem = 2, TeleportOffset = Vector3.new(0,3,0), DelayBetweenItems = 0.2, Progress = { Enabled = true, Label = "กำลังเก็บเพชร...", DurationPerItem = 0.3 } } } }, Bank = { DisplayName = "City Bank", Identifiers = { Path = "Workspace.Heists.Bank", HasDescendants = {"VaultDoor", "Lasers"} }, EntryTeleport = CFrame.new(730,108,560), Sequence = { { Name = "Touch Vault Door", Type = "Touch", TargetPath = "EssentialParts.VaultDoor.Touch", TeleportOffset = Vector3.new(0,0,-3), Cooldown = 2.5, Progress = { Enabled = true, Label = "กำลังเปิดประตู...", Duration = 2.5 } }, { Name = "Collect Cash Stacks", Type = "IterateAndFindInteract", ItemContainerPath = "Interior", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="Collect", Args=function(item) return {item} end}, TeleportOffset = Vector3.new(0,1.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1, Progress = { Enabled = true, Label = "กำลังเก็บเงิน...", DurationPerItem = 0.2 } } } }, Casino = { DisplayName = "Diamond Casino", Identifiers = { Path = "Workspace.Heists.Casino", HasDescendants = {"HackComputer"} }, EntryTeleport = CFrame.new(1690,30,525), Sequence = { { Name = "Hack Mainframe", Type = "ProximityPrompt", TargetPath = "Interior.HackComputer.HackComputer", ProximityPromptActionHint = "Hack", HoldDuration = 3, TeleportOffset = Vector3.new(0,0,-2.5), Cooldown = 1, Progress = { Enabled = true, Label = "กำลังแฮ็ก...", Duration = 3 } }, { Name = "Collect Vault Cash", Type = "IterateAndFindInteract", ItemContainerPath = "Interior.Vault", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="Take|Collect", Args=function(item) return {item} end}, TeleportOffset = Vector3.new(0,1.5,0), DelayBetweenItems = 0.3, FireCountPerItem = 1, Progress = { Enabled = true, Label = "กำลังเก็บเงินคาสิโน...", DurationPerItem = 0.3 } } } } }

-- ================= UI LIBRARY & MAIN UI (ส่วนนี้จะเหมือน V3.0.2 ที่แก้ไข Font แล้ว) =================
local UILib={};local MainUI={};function UILib.Create(element)return function(props)local obj=Instance.new(element);for k,v in pairs(props)do if type(k)=="number"then v.Parent=obj else obj[k]=v end end;return obj end end
function UILib.Shadow(parent)UILib.Create("ImageLabel"){Name="DropShadow",Parent=parent,Size=UDim2.new(1,8,1,8),Position=UDim2.new(0,-4,0,-4),BackgroundTransparency=1,Image="rbxassetid://939639733",ImageColor3=Color3.new(0,0,0),ImageTransparency=0.5,ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(10,10,118,118),ZIndex=parent.ZIndex-1}end
function UILib.Tween(obj,props,overrideInfo)local info=TweenInfo.new(overrideInfo and overrideInfo.Time or THEME.Animation.Medium,overrideInfo and overrideInfo.EasingStyle or Enum.EasingStyle.Quart,overrideInfo and overrideInfo.EasingDirection or Enum.EasingDirection.Out);local t=TweenService:Create(obj,info,props);t:Play();return t end
function MainUI:CreateNotification(title,text,style,duration)if not MainUI.ScreenGui then liveDebug("CreateNotification: MainUI.ScreenGui is nil!"); return end; local notifFrame=UILib.Create("Frame"){Name="Notification",Parent=MainUI.ScreenGui,Size=UDim2.new(0,280,0,65),Position=UDim2.new(0.98,0,1,-10),AnchorPoint=Vector2.new(1,1),BackgroundColor3=THEME.Colors.Primary,BorderSizePixel=0,ZIndex=9999,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,6)},UILib.Create("UIPadding"){PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,5)},UILib.Create("Frame"){Name="ColorStripe",Size=UDim2.new(0,4,1,0),BackgroundColor3=THEME.Colors[style or"AccentBright"],BorderSizePixel=0,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,6)}}},UILib.Create("TextLabel"){Name="Title",Size=UDim2.new(1,-15,0,20),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Font=THEME.Font.Main,Text=title or"แจ้งเตือน",TextColor3=THEME.Colors[style or"AccentBright"],TextSize=15,TextXAlignment=Enum.TextXAlignment.Left},UILib.Create("TextLabel"){Name="Content",Size=UDim2.new(1,-15,0,35),Position=UDim2.new(0,10,0,20),BackgroundTransparency=1,Font=THEME.Font.UI,Text=text or"",TextColor3=THEME.Colors.Text,TextSize=13,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top}}};local currentNotifs=0;for _,v in ipairs(MainUI.ScreenGui:GetChildren())do if v.Name=="Notification"then currentNotifs=currentNotifs+1 end end;notifFrame.Position=UDim2.new(0.98,0,1,-10-(currentNotifs*75));UILib.Shadow(notifFrame);UILib.Tween(notifFrame,{Position=UDim2.new(0.98,-15,1,-10-(currentNotifs*75))},{Time=THEME.Animation.Slow,EasingStyle=Enum.EasingStyle.Elastic});task.delay(duration or 4,function()if not notifFrame or not notifFrame.Parent then return end;UILib.Tween(notifFrame,{Position=notifFrame.Position+UDim2.new(0,300,0,0),Transparency=1},{Time=THEME.Animation.Medium});task.wait(THEME.Animation.Medium);if not notifFrame and notifFrame.Parent then notifFrame:Destroy()end end)end
function MainUI:CreateProgressBar(parent,label)local c=UILib.Create("Frame"){Name="ProgressBarContainer",Parent=parent,Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,ClipsDescendants=true,};local b=UILib.Create("Frame"){Name="ProgressBar",Parent=c,Size=UDim2.new(1,0,1,0),BackgroundColor3=THEME.Colors.Secondary,BorderSizePixel=0,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,5)},UILib.Create("Frame"){Name="Fill",Size=UDim2.new(0,0,1,0),BackgroundColor3=THEME.Colors.ProgressBarFill,BorderSizePixel=0,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,5)}}},UILib.Create("TextLabel"){Name="Label",Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Font=THEME.Font.Code,Text=label or"",TextColor3=THEME.Colors.Background,TextSize=12,TextStrokeTransparency=0.8}}};function b:Update(prog,txt)UILib.Tween(b.Fill,{Size=UDim2.new(math.clamp(prog,0,1),0,1,0)},{Time=THEME.Animation.Fast});if txt then b.Label.Text=txt end end;function b:Run(dur,txt)b.Label.Text=txt or"";b.Fill.Size=UDim2.new(0,0,1,0);UILib.Tween(b.Fill,{Size=UDim2.new(1,0,1,0)},{Time=dur,EasingStyle=Enum.EasingStyle.Linear})end;return b end
function MainUI:CreateHeistCard(parent,heistData,robCallback)local card=UILib.Create("Frame"){Name="HeistCard",Parent=parent,Size=UDim2.new(1,0,0,60),BackgroundColor3=THEME.Colors.Primary,BorderSizePixel=0,ClipsDescendants=true,LayoutOrder=1,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,6)},UILib.Create("UIPadding"){PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,5)}}};UILib.Shadow(card);local title=UILib.Create("TextLabel"){Name="Title",Parent=card,Size=UDim2.new(0.65,0,0,25),Position=UDim2.new(0,0,0,0),BackgroundTransparency=1,Font=THEME.Font.Main,Text=heistData.DisplayName,TextColor3=THEME.Colors.AccentBright,TextSize=16,TextXAlignment=Enum.TextXAlignment.Left};local status=UILib.Create("TextLabel"){Name="Status",Parent=card,Size=UDim2.new(0.65,0,0,18),Position=UDim2.new(0,0,0,25),BackgroundTransparency=1,Font=THEME.Font.Code,Text="สถานะ: พร้อม",TextColor3=THEME.Colors.Success,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left};local btn=createStyledButton(card,"เริ่มปล้น",UDim2.new(0.3,0,0.8,0),UDim2.new(0.7,0,0.1,0),THEME.Colors.Accent,THEME.Colors.Background,13);btn.Name=heistData.Key.."_RobButton";RyntazHub.UI[heistData.Key.."_StatusLabel"]=status;RyntazHub.UI[heistData.Key.."_RobButton"]=btn;btn.MouseButton1Click:Connect(function()if RyntazHub.State.IsRobbing then MainUI:CreateNotification("ข้อผิดพลาด","การปล้นอื่นกำลังทำงานอยู่!","Error");return end;robCallback(heistData.Key)end);return card end

function MainUI:Build()
    liveDebug("MainUI:Build - Called")
    if MainUI.ScreenGui and MainUI.ScreenGui.Parent then MainUI.ScreenGui:Destroy(); MainUI.ScreenGui = nil end
    liveDebug("MainUI:Build - Old ScreenGui destroyed (if existed)")

    MainUI.ScreenGui = UILib.Create("ScreenGui"){ Name = "RyntazHubTitanV3_2", Parent = Player:WaitForChild("PlayerGui"), ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ResetOnSpawn = false, DisplayOrder = 1001 }
    liveDebug("MainUI:Build - ScreenGui created: " .. MainUI.ScreenGui.Name)
    
    local introFrame = UILib.Create("Frame"){ Parent = MainUI.ScreenGui, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ZIndex = 9999 }
    local introText = UILib.Create("TextLabel"){ Parent = introFrame, Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0), AnchorPoint = Vector2.new(0.5,0.5), Font = THEME.Font.Main, Text = "Ryntaz Hub", TextColor3 = THEME.Colors.Accent, TextSize = 1, BackgroundTransparency = 1, Transparency = 1, Rotation = -10 }
    liveDebug("MainUI:Build - Intro animation starting...")
    UILib.Tween(introText, { Size = UDim2.new(0.8,0,0.2,0), TextSize = 80, Transparency = 0, Rotation = 0 }, { Time = THEME.Animation.Intro, EasingStyle = Enum.EasingStyle.Elastic, EasingDirection = Enum.EasingDirection.Out })
    task.wait(THEME.Animation.Intro + 0.7) 
    UILib.Tween(introText, { Transparency = 1, Position = UDim2.new(0.5,0,0.6,0) }, { Time = THEME.Animation.Medium })
    task.wait(THEME.Animation.Medium)
    introFrame:Destroy()
    liveDebug("MainUI:Build - Intro animation finished.")

    MainUI.Frame = UILib.Create("Frame"){ Name = "MainFrame", Parent = MainUI.ScreenGui, Size = originalMainFrameSize, Position = UDim2.new(0.5, 0, 1.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = THEME.Colors.Background, BorderSizePixel = 0, Draggable = true, Active = true, ClipsDescendants = true, Visible = false, { UILib.Create("UICorner"){ CornerRadius = UDim.new(0, 8) } } }
    UILib.Shadow(MainUI.Frame)
    liveDebug("MainUI:Build - MainFrame created.")

    titleBar = UILib.Create("Frame"){ Name = "TitleBar", Parent = MainUI.Frame, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = THEME.Colors.Primary, BorderSizePixel = 0, ZIndex = 3, {
        UILib.Create("TextLabel"){ Name = "Title", Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5,0.5), BackgroundTransparency = 1, Font = THEME.Font.Title, Text = "RYNTAZHUB :: TITAN", TextColor3 = THEME.Colors.AccentBright, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center }
    }}
    liveDebug("MainUI:Build - TitleBar created.")
    
    local tabsContainer = UILib.Create("Frame"){ Name = "TabsContainer", Parent = MainUI.Frame, Size = UDim2.new(0, 130, 1, -40), Position = UDim2.new(0, 0, 0, 40), BackgroundColor3 = THEME.Colors.Primary, BorderSizePixel = 0, { UILib.Create("UIListLayout"){ Padding = UDim.new(0,0), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Top } } }
    local contentContainer = UILib.Create("Frame"){ Name = "ContentContainer", Parent = MainUI.Frame, Size = UDim2.new(1, -130, 1, -40 - 35), Position = UDim2.new(0, 130, 0, 40), BackgroundColor3 = THEME.Colors.Background, ClipsDescendants = true, ZIndex = 1, { UILib.Create("UIPadding"){ PaddingTop = UDim.new(0,5), PaddingBottom = UDim.new(0,5), PaddingLeft = UDim.new(0,5), PaddingRight = UDim.new(0,5) } } }
    MainUI.ContentContainer = contentContainer; MainUI.Pages = {}; MainUI.Tabs = {}
    liveDebug("MainUI:Build - Containers created.")

    local function createTab(name, iconId)
        local page = UILib.Create("ScrollingFrame"){ Name = name, Parent = contentContainer, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarImageColor3 = THEME.Colors.Accent, ScrollBarThickness = 5, ClipsDescendants = true, { UILib.Create("UIListLayout"){ Padding = UDim.new(0,8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center} } }
        MainUI.Pages[name] = page
        local tabButton = UILib.Create("TextButton"){ Name = name.."TabButton", Parent = tabsContainer, Size = UDim2.new(1,0,0,45), BackgroundColor3 = THEME.Colors.Primary, Font = THEME.Font.UI, Text = " "..(iconId and "  " or "")..name, TextColor3 = THEME.Colors.TextDim, TextSize = 15, AutoButtonColor = false, TextXAlignment = Enum.TextXAlignment.Left, { UILib.Create("Frame"){ Name="Indicator", Size=UDim2.new(0,3,0.7,0), Position=UDim2.new(0,5,0.15,0), BackgroundColor3=THEME.Colors.Accent, BorderSizePixel=0,Visible=false, {UILib.Create("UICorner"){CornerRadius=UDim.new(0,3)}} } } }
        if iconId then UILib.Create("ImageLabel"){Parent=tabButton, Size=UDim2.new(0,18,0,18),Position=UDim2.new(0,10,0.5,-9),BackgroundTransparency=1,Image=iconId,ImageColor3=THEME.Colors.TextDim, Name="Icon"}; tabButton.TextOffset = Vector2.new(25,0) end
        MainUI.Tabs[name] = tabButton
        if tabButton.MouseButton1Click then tabButton.MouseButton1Click:Connect(function() for tName,tBtn in pairs(MainUI.Tabs)do local isCurrentTab=(tName==name);if MainUI.Pages[tName]then MainUI.Pages[tName].Visible=isCurrentTab end;if tBtn and tBtn:FindFirstChild("Indicator")then tBtn.Indicator.Visible=isCurrentTab end;UILib.Tween(tBtn,{BackgroundColor3=isCurrentTab and THEME.Colors.Secondary or THEME.Colors.Primary,TextColor3=isCurrentTab and THEME.Colors.Text or THEME.Colors.TextDim});if tBtn:FindFirstChild("Icon")then UILib.Tween(tBtn.Icon,{ImageColor3=isCurrentTab and THEME.Colors.Text or THEME.Colors.TextDim})end end end) else liveDebug("Error: MouseButton1Click nil for "..name) end
    end
    createTab("Heists", "rbxassetid://5147488592"); createTab("Scanner", "rbxassetid://1204397029"); createTab("Settings", "rbxassetid://4911962991")
    liveDebug("MainUI:Build - Tabs created.")

    if MainUI.Tabs["Heists"] and MainUI.Tabs["Heists"].MouseButton1Click then
        for tN,tP in pairs(MainUI.Pages)do tP.Visible=(tN=="Heists")end;for tN,tB in pairs(MainUI.Tabs)do if tB:FindFirstChild("Indicator")then tB.Indicator.Visible=(tN=="Heists")end;UILib.Tween(tB,{TextColor3=(tN=="Heists")and THEME.Colors.Text or THEME.Colors.TextDim,BackgroundColor3=(tN=="Heists")and THEME.Colors.Secondary or THEME.Colors.Primary});if tB:FindFirstChild("Icon")then UILib.Tween(tB.Icon,{ImageColor3=(tN=="Heists")and THEME.Colors.Text or THEME.Colors.TextDim})end end
    end; liveDebug("MainUI:Build - First tab selected.")
    
    local bottomControls = UILib.Create("Frame"){ Name="BottomControls", Parent = MainUI.Frame, Size = UDim2.new(1,-130,0,35), Position = UDim2.new(0,130,1,-35), BackgroundColor3 = THEME.Colors.Primary, ZIndex = 2 }
    statusBar = UILib.Create("Frame"){Name="StatusBar",Parent=bottomControls,Size=UDim2.new(1,-10,1,-10),Position=UDim2.new(0,5,0,5),BackgroundColor3=THEME.Colors.Secondary,BackgroundTransparency=0.3,ZIndex=2,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,3)}}};
    statusTextLabel=UILib.Create("TextLabel"){Parent=statusBar,Name="StatusText",Size=UDim2.new(0.7,-5,1,0),Position=UDim2.new(0,5,0,0),BackgroundTransparency=1,Font=THEME.Font.Code,Text="สถานะ: กำลังเตรียม...",TextColor3=THEME.Colors.TextDim,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left};
    timerTextLabel=UILib.Create("TextLabel"){Parent=statusBar,Name="TimerText",Size=UDim2.new(0.3,-5,1,0),Position=UDim2.new(0.7,5,0,0),BackgroundTransparency=1,Font=THEME.Font.Code,Text="เวลา: 0.0วิ",TextColor3=THEME.Colors.TextDim,TextSize=12,TextXAlignment=Enum.TextXAlignment.Right};
    liveDebug("MainUI:Build - Status/Bottom bars created.")

    UILib.Tween(MainUI.Frame, {Visible = true, Position = UDim2.new(0.5,0,0.5,0) }, {Time=THEME.Animation.Slow, EasingStyle=Enum.EasingStyle.Elastic})
    if not INITIAL_UI_VISIBLE then task.wait(THEME.Animation.Slow); if MainUI.Tabs["Heists"] and MainUI.Tabs["Heists"].MouseButton1Click then MainUI.Tabs["Heists"].MouseButton1Click:__call() end; task.wait(0.1); MainUI.Frame.Visible = false; end
    
    RyntazHub.UIHooks = {ProgressBar = nil, HeistsPage = MainUI.Pages["Heists"], ScannerPage = MainUI.Pages["Scanner"], SettingsPage = MainUI.Pages["Settings"]}
    MainUI:PopulateScannerTab()
    liveDebug("MainUI:Build - Finished.")
end

-- (ส่วน PopulateScannerTab, Scanner, Analyzer, ExecutionEngine, และ Main Execution Flow เหมือนเดิมจาก V3.0.2)
-- ... (โค้ดส่วนที่เหลือจาก V3.0.2 ตั้งแต่ MainUI:PopulateScannerTab() เป็นต้นไป) ...

-- ฟังก์ชันที่เหลือจาก V3.0.2 (ที่ไม่ได้แสดงด้านบนเพื่อความกระชับ แต่ต้องมีในสคริปต์เต็ม)
function MainUI:PopulateScannerTab() local page=RyntazHub.UIHooks.ScannerPage;if not page then return end;for _,c in ipairs(page:GetChildren())do if c.Name~="UIListLayout"and c.Name~="UIPadding"then c:Destroy()end end;UILib.Create("TextLabel"){Parent=page,Text="ส่วนการสแกน (Focused Scan)",Font=THEME.Font.Main,TextSize=18,TextColor3=THEME.Colors.AccentBright,Size=UDim2.new(1,-20,0,25),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,LayoutOrder=1};local rescanButton=createStyledButton(page,"เริ่มสแกน Heists & ReplicatedStorage",UDim2.new(0.9,0,0,40),UDim2.new(0.05,0,0,0),THEME.Colors.Secondary,THEME.Colors.Text);rescanButton.LayoutOrder=2;rescanButton.MouseButton1Click:Connect(function()if RyntazHub.State.IsScanning then MainUI:CreateNotification("Scanner","กำลังสแกนอยู่แล้ว","Warning");return end;RyntazHub.State.IsScanning=true;rescanButton.Text="กำลังสแกน...";rescanButton.Enabled=false;task.spawn(RyntazHub.Scanner.FocusedScan);task.spawn(function()repeat task.wait(0.5)until not RyntazHub.State.IsScanning;rescanButton.Text="เริ่มสแกน Heists & ReplicatedStorage";rescanButton.Enabled=true end)end);local outputLogContainer=UILib.Create("ScrollingFrame"){Name="ScanLogOutput",Parent=page,Size=UDim2.new(1,-20,0.8,-50),Position=UDim2.new(0,10,0,0),BackgroundColor3=THEME.Colors.Primary,BorderColor3=THEME.Colors.Secondary,BorderSizePixel=1,CanvasSize=UDim2.new(0,0,0,0),ScrollBarThickness=5,ScrollBarImageColor3=THEME.Colors.Accent,LayoutOrder=3,ClipsDescendants=true,{UILib.Create("UIListLayout"){Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Left}}};RyntazHub.UIHooks.ScanLogOutput=outputLogContainer end
RyntazHub.Scanner.FocusedScan=function()startTime=tick();if RyntazHub.UIHooks.ScanLogOutput then for _,c in ipairs(RyntazHub.UIHooks.ScanLogOutput:GetChildren())do if c.Name=="LogEntry"or c.Name=="CategoryHeader"then c:Destroy()end end;RyntazHub.UIHooks.ScanLogOutput.CanvasSize=UDim2.new(0,0,0,0)end;allLoggedMessages={};MainUI:CreateNotification("Scanner","เริ่มการสแกนแบบ Focused...","Info",2);local pathsToScanConfig={};local heistsFolder=Workspace:FindFirstChild(HEISTS_BASE_PATH_STRING);if heistsFolder then MainUI:CreateNotification("Scanner","พบ Folder Heists หลัก","Success",1.5);if #TARGET_HEISTS_IN_WORKSPACE>0 then for _,heistName in ipairs(TARGET_HEISTS_IN_WORKSPACE)do local specificHeistFolder=heistsFolder:FindFirstChild(heistName);if specificHeistFolder then table.insert(pathsToScanConfig,{instance=specificHeistFolder,name=heistName,type="Heist"})else MainUI:CreateNotification("Scan Error","ไม่พบ Folder Heist: "..heistName,"Error")end end else for _,childHeist in ipairs(heistsFolder:GetChildren())do if childHeist:IsA("Instance")then table.insert(pathsToScanConfig,{instance=childHeist,name=childHeist.Name,type="Heist"})end end end else MainUI:CreateNotification("Scan Error","ไม่พบ Folder Heists หลัก: '"..HEISTS_BASE_PATH_STRING.."'","Error")end;if ReplicatedStorage then table.insert(pathsToScanConfig,{instance=ReplicatedStorage,name="ReplicatedStorage",type="Service"})end;local totalScanTasks=#pathsToScanConfig;if totalScanTasks==0 then updateStatus("ไม่พบ Path ที่จะสแกน",100);RyntazHub.State.IsScanning=false;return end;for i,scanTask in ipairs(pathsToScanConfig)do local currentRoot=scanTask.instance;local currentName=scanTask.name;updateStatus("กำลังสแกน: "..currentName,(i-1)/totalScanTasks*100);if RyntazHub.UIHooks.ScanLogOutput then addCategoryHeaderToUI(currentName)end;local descendants=currentRoot:GetDescendants();local numDescendants=#descendants;local updateInterval=math.max(1,math.floor(numDescendants/10));for idx,descendant in ipairs(descendants)do local itemPath=descendant:GetFullName();if descendant:IsA("LuaSourceContainer")then local sCP="";if descendant:IsA("Script")or descendant:IsA("LocalScript")then local s,sr=pcall(function()return descendant.Source end);if s and sr and #sr>0 then sCP=" [Code]";for _,k in ipairs(SENSITIVE_SCRIPT_KEYWORDS)do if sr:lower():match(k)then sCP=sCP.."[K:"..k.."]";break end end else sCP="[SrcErr]"end end;logOutputWrapper("ScriptFound","P: "..itemPath.." |T:"..descendant.ClassName..sCP)end;if descendant:IsA("RemoteEvent")or descendant:IsA("RemoteFunction")then logOutputWrapper("RemoteFound","P: "..itemPath.." |T:"..descendant.ClassName)end;if descendant:IsA("ProximityPrompt")then logOutputWrapper("ProximityPromptFound","P: "..itemPath.."|Obj:"..(descendant.ObjectText or"-").."|Act:"..(descendant.ActionText or"-").."|Hold:"..tostring(descendant.HoldDuration).."|Dist:"..string.format("%.1f",descendant.MaxActivationDistance).."|En:"..tostring(descendant.Enabled))end;if descendant:IsA("BasePart")and not descendant:IsA("Terrain")then local pI="";local iLP=false;for _,k in ipairs(MINI_ROBBERIES_NAMES_EXTENDED)do if descendant.Name:lower():match(k:lower())then iLP=true;pI=pI.."[K:"..k.."]";break end end;if not iLP then for _,k in ipairs(EXTRA_LOOT_KEYWORDS)do if descendant.Name:lower():match(k:lower())then iLP=true;pI=pI.."[K:"..k.."]";break end end end;if iLP then logOutputWrapper("PotentialLoot","P: "..itemPath.." "..pI.."|Pos:"..string.format("%.1f,%.1f,%.1f",descendant.Position.X,descendant.Position.Y,descendant.Position.Z))end;if descendant:FindFirstChildOfClass("TouchTransmitter")then logOutputWrapper("PartWithTouch","P: "..itemPath)end end;if idx%updateInterval==0 then updateStatus("สแกน "..currentName..string.format(" (%.0f%%)",(idx/numDescendants)*100),((i-1)/totalScanTasks)*100+((idx/numDescendants)*(1/totalScanTasks)*100));task.wait()end end;if scanTask.type=="Heist"then RyntazHub.Scanner.ScanHeist(scanTask.name,MasterConfig[scanTask.name]or{})end end;updateStatus("การสำรวจ (Focused) ทั้งหมดเสร็จสิ้น.",100);MainUI:CreateNotification("Scanner",string.format("สแกนเสร็จสิ้นใน %.2f วินาที",tick()-startTime),"Success");RyntazHub.State.IsScanning=false;RyntazHub.UIController.PopulateHeists()end
RyntazHub.ExecutionEngine.RunAllSequences=function()startTime=tick();updateStatus("กำลังเตรียมข้อมูล Heists...",0);local allHeistsPrepared=true;for i,heistKey in ipairs(TARGET_HEISTS_TO_ROB)do local config=MasterConfig[heistKey];if config then if not RyntazHub.Scanner.ScanHeist(heistKey,config)then allHeistsPrepared=false end else MainUI:CreateNotification("Config Error","ไม่พบ MasterConfig สำหรับ: "..heistKey,"Error");allHeistsPrepared=false end;updateStatus("เตรียม "..(config and config.DisplayName or heistKey).." เสร็จสิ้น",(i/#TARGET_HEISTS_TO_ROB)*100);if i<#TARGET_HEISTS_TO_ROB then task.wait(0.1)end end;if not allHeistsPrepared then MainUI:CreateNotification("ข้อผิดพลาด","การเตรียมข้อมูลบาง Heist ล้มเหลว","Error");RyntazHub.State.IsRobbing=false;currentRobberyCoroutine=nil;return end;RyntazHub.UIController.PopulateHeists();updateStatus("เริ่มลำดับการปล้นทั้งหมด...",0);for i,heistKey in ipairs(TARGET_HEISTS_TO_ROB)do if not currentRobberyCoroutine then break end;local analyzedData=RyntazHub.Data.Analyzed[heistKey];if analyzedData and #analyzedData.AnalyzedSequence>0 then RyntazHub.ExecutionEngine.Run(heistKey);local timeout=0;local maxWaitTime=60;while RyntazHub.State.IsRobbing and RyntazHub.State.CurrentHeist==heistKey and timeout<maxWaitTime do task.wait(0.1);timeout=timeout+0.1 end;if RyntazHub.State.IsRobbing and RyntazHub.State.CurrentHeist==heistKey then MainUI:CreateNotification("Timeout",heistKey.." ใช้เวลานานเกินไป, ถูกหยุด.","Warning");if RyntazHub.UI[heistKey.."_StatusLabel"]then RyntazHub.UI[heistKey.."_StatusLabel"].Text="สถานะ: Timeout";RyntazHub.UI[heistKey.."_StatusLabel"].TextColor3=THEME.Colors.Error end;if RyntazHub.UI[heistKey.."_RobButton"]then RyntazHub.UI[heistKey.."_RobButton"].Text="เริ่มปล้น";RyntazHub.UI[heistKey.."_RobButton"].Enabled=true end;RyntazHub.State.IsRobbing=false;RyntazHub.State.CurrentHeist=nil;currentRobberyCoroutine=nil;break end else MainUI:CreateNotification("ข้าม",(analyzedData and analyzedData.DisplayName or heistKey).." ไม่ได้ถูกเตรียมไว้/ไม่มีขั้นตอน","Info")end;updateStatus("เสร็จสิ้น "..(analyzedData and analyzedData.DisplayName or heistKey),(i/#TARGET_HEISTS_TO_ROB)*100);if i<#TARGET_HEISTS_TO_ROB and currentRobberyCoroutine then task.wait(1)end end;if currentRobberyCoroutine then updateStatus("ปล้นทั้งหมดเสร็จสิ้น.",100);MainUI:CreateNotification("เสร็จสิ้น","การปล้นตามลำดับทั้งหมดเสร็จสิ้น","Success")end;RyntazHub.State.IsRobbing=false;currentRobberyCoroutine=nil end

task.spawn(function()while true do if SHOW_UI_OUTPUT and mainFrame and mainFrame.Parent and timerTextLabel then if startTime then timerTextLabel.Text=string.format("เวลา: %.1fs",tick()-startTime)else timerTextLabel.Text="เวลา: --.-s"end end;task.wait(0.1)end end)

local initSuccess,initError=pcall(function()if not waitForCharacter()then error("ไม่สามารถโหลด Character ได้, สคริปต์หยุดทำงาน")end;if SHOW_UI_OUTPUT then MainUI:Build()end end)
if not initSuccess then print("FATAL ERROR during RyntazHub Initialization: "..tostring(initError));local errScreen=Player.PlayerGui:FindFirstChild("RyntazFatalErrorScreen")or Instance.new("ScreenGui",Player.PlayerGui);errScreen.Name="RyntazFatalErrorScreen";errScreen.ResetOnSpawn=false;errScreen.DisplayOrder=20000;local errLabel=errScreen:FindFirstChild("RyntazFatalErrorLabel")or Instance.new("TextLabel",errScreen);errLabel.Name="RyntazFatalErrorLabel";errLabel.Size=UDim2.new(1,0,0.2,0);errLabel.Position=UDim2.new(0,0,0,0);errLabel.BackgroundColor3=Color3.fromRGB(180,0,0);errLabel.BackgroundTransparency=0.1;errLabel.TextColor3=Color3.new(1,1,1);errLabel.Font=Enum.Font.Code;errLabel.TextSize=16;errLabel.TextWrapped=true;errLabel.TextXAlignment=Enum.TextXAlignment.Left;errLabel.ZIndex=20001;errLabel.Text="RYNTAZHUB FATAL ERROR:\n"..tostring(initError).."\n\nPlease check your executor console for more details or contact support."else task.spawn(function()task.wait(0.2);local scanSuccess,scanErr=pcall(RyntazHub.Scanner.FocusedScan);if not scanSuccess then MainUI:CreateNotification("Scan Error","การสแกนเบื้องต้นล้มเหลว: "..tostring(scanErr),"Error");if statusTextLabel and statusTextLabel.Parent then statusTextLabel.Text="สถานะ: Scan Error!"end else MainUI:CreateNotification("พร้อมใช้งาน","สแกนเบื้องต้นเสร็จสิ้น, UI พร้อมใช้งาน","Success",3)end end)end

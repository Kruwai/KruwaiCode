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
    local attempts = 0
    repeat
        attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character
            Humanoid = Character:FindFirstChildOfClass("Humanoid")
            RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then return true end
        end
        task.wait(0.2)
    until attempts > 50 
    return false
end

local RyntazHub = {
    Data = { Raw = { Heists = {}, Remotes = {}, Scripts = {}, Prompts = {}, TouchParts = {}, PotentialLoot = {} }, Analyzed = {} },
    Capabilities = {},
    ActiveThreads = {},
    State = { IsScanning = false, IsRobbing = false, CurrentHeist = nil, CurrentAction = nil },
    UI = {} 
}

--[[
====================================================================================================
    THEME & UI CONFIGURATION (ส่วนนี้คุณสามารถแก้ไขค่าสีและ Font ได้)
====================================================================================================
]]
local THEME = {
    Font = { Main = Enum.Font.Michroma, UI = Enum.Font.SourceSans, Code = Enum.Font.Code, Title = Enum.Font.EconomicaBold },
    Colors = {
        Background = Color3.fromRGB(17, 17, 23), Primary = Color3.fromRGB(24, 24, 32), Secondary = Color3.fromRGB(35, 35, 45),
        Accent = Color3.fromRGB(0, 190, 255), AccentBright = Color3.fromRGB(100, 220, 255), Text = Color3.fromRGB(235, 235, 240),
        TextDim = Color3.fromRGB(160, 160, 170), Success = Color3.fromRGB(30, 220, 120), Warning = Color3.fromRGB(255, 190, 0),
        Error = Color3.fromRGB(255, 70, 70), ProgressBarFill = Color3.fromRGB(0, 190, 255),
        CloseButton = Color3.fromRGB(255, 95, 86), MinimizeButton = Color3.fromRGB(255, 189, 46), MaximizeButton = Color3.fromRGB(40, 200, 65)
    },
    Animation = { Fast = 0.15, Medium = 0.3, Slow = 0.5, Intro = 0.8 }
}
--[[
====================================================================================================
    MASTER HEIST & ROBBERY CONFIGURATION (คุณต้องปรับแก้ส่วนนี้อย่างละเอียด)
====================================================================================================
]]
local MasterConfig = {
    JewelryStore = {
        DisplayName = "ร้านเพชร",
        Identifiers = { Path = "Workspace.Heists.JewelryStore", HasDescendants = {"EssentialParts.JewelryBoxes", "EssentialParts.JewelryBoxes.JewelryManager"} },
        EntryTeleport = CFrame.new(-82, 86, 807), -- (Optional)
        Sequence = {
            {
                Name = "เก็บเครื่องเพชร", Type = "IterateAndFireEvent",
                ItemContainerPath = "EssentialParts.JewelryBoxes",
                ItemQuery = function(container) local items = {}; for _,c in ipairs(container:GetChildren()) do if c:IsA("Model") or c:IsA("BasePart") then table.insert(items, c) end end; return items end,
                RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event",
                EventArgsFunc = function(lootInstance) return {lootInstance} end,
                FireCountPerItem = 2, TeleportOffset = Vector3.new(0, 2, 2), DelayBetweenItems = 0.15, DelayBetweenFires = 0.1,
                Progress = { Enabled = true, Label = "กำลังเก็บเพชร...", DurationPerItem = 0.3 }
            }
        }
    },
    Bank = {
        DisplayName = "ธนาคาร",
        Identifiers = { Path = "Workspace.Heists.Bank", HasDescendants = {"EssentialParts.VaultDoor"} },
        EntryTeleport = CFrame.new(730, 108, 560),
        Sequence = {
            {
                Name = "เปิดประตูห้องมั่นคง", Type = "Touch", TargetPath = "EssentialParts.VaultDoor.Touch",
                TeleportOffset = Vector3.new(0, 0, -3), Cooldown = 2.5,
                Progress = { Enabled = true, Label = "กำลังเปิดประตู...", Duration = 2.5 }
            },
            {
                Name = "เก็บเงินสด", Type = "IterateAndFindInteract",
                ItemContainerPath = "Interior", ItemNameHint = "Cash",
                InteractionHint = {Type="RemoteEvent", NameHint="Collect", Args=function(item) return {item} end},
                TeleportOffset = Vector3.new(0,1.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1,
                Progress = { Enabled = true, Label = "กำลังเก็บเงิน...", DurationPerItem = 0.2 }
            }
        }
    },
    Casino = {
        DisplayName = "คาสิโน",
        Identifiers = { Path = "Workspace.Heists.Casino", HasDescendants = {"Interior.HackComputer"} },
        EntryTeleport = CFrame.new(1690, 30, 525),
        Sequence = {
            {
                Name = "แฮ็กคอมพิวเตอร์", Type = "ProximityPrompt", TargetPath = "Interior.HackComputer.HackComputer",
                ProximityPromptActionHint = "Hack", HoldDuration = 3,
                TeleportOffset = Vector3.new(0,0,-2), Cooldown = 1,
                Progress = { Enabled = true, Label = "กำลังแฮ็ก...", Duration = 3 }
            },
            {
                Name = "เก็บเงินจากห้องนิรภัย", Type = "IterateAndFindInteract",
                ItemContainerPath = "Interior.Vault", ItemNameHint = "Cash",
                InteractionHint = {Type="RemoteEvent", NameHint="Take|Collect", Args=function(item) return {item} end},
                TeleportOffset = Vector3.new(0,1.5,0), DelayBetweenItems = 0.3, FireCountPerItem = 1,
                Progress = { Enabled = true, Label = "กำลังเก็บเงินคาสิโน...", DurationPerItem = 0.3 }
            }
        }
    }
}
--[[
====================================================================================================
    END OF CONFIGURATION
====================================================================================================
]]

local UILib={};local MainUI={};function UILib.Create(element)return function(props)local obj=Instance.new(element);for k,v in pairs(props)do if type(k)=="number"then v.Parent=obj else obj[k]=v end end;return obj end end
function UILib.Shadow(parent)UILib.Create("ImageLabel"){Name="DropShadow",Parent=parent,Size=UDim2.new(1,8,1,8),Position=UDim2.new(0,-4,0,-4),BackgroundTransparency=1,Image="rbxassetid://939639733",ImageColor3=Color3.new(0,0,0),ImageTransparency=0.5,ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(10,10,118,118),ZIndex=parent.ZIndex-1}end
function UILib.Tween(obj,props,overrideInfo)local info=TweenInfo.new(overrideInfo and overrideInfo.Time or THEME.Animation.Medium,overrideInfo and overrideInfo.EasingStyle or Enum.EasingStyle.Quart,overrideInfo and overrideInfo.EasingDirection or Enum.EasingDirection.Out);local t=TweenService:Create(obj,info,props);t:Play();return t end
function MainUI:CreateNotification(title,text,style,duration)local notifFrame=UILib.Create("Frame"){Name="Notification",Parent=MainUI.ScreenGui,Size=UDim2.new(0,280,0,65),Position=UDim2.new(0.98,0,1,-10),AnchorPoint=Vector2.new(1,1),BackgroundColor3=THEME.Colors.Primary,BorderSizePixel=0,ZIndex=9999,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,6)},UILib.Create("UIPadding"){PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,5)},UILib.Create("Frame"){Name="ColorStripe",Size=UDim2.new(0,4,1,0),BackgroundColor3=THEME.Colors[style or"AccentBright"],BorderSizePixel=0,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,6)}}},UILib.Create("TextLabel"){Name="Title",Size=UDim2.new(1,-15,0,20),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Font=THEME.Font.Main,Text=title or"แจ้งเตือน",TextColor3=THEME.Colors[style or"AccentBright"],TextSize=15,TextXAlignment=Enum.TextXAlignment.Left},UILib.Create("TextLabel"){Name="Content",Size=UDim2.new(1,-15,0,35),Position=UDim2.new(0,10,0,20),BackgroundTransparency=1,Font=THEME.Font.UI,Text=text or"",TextColor3=THEME.Colors.Text,TextSize=13,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top}}};local currentNotifs=0;for _,v in ipairs(MainUI.ScreenGui:GetChildren())do if v.Name=="Notification"then currentNotifs=currentNotifs+1 end end;notifFrame.Position=UDim2.new(0.98,0,1,-10-(currentNotifs*75));UILib.Shadow(notifFrame);UILib.Tween(notifFrame,{Position=UDim2.new(0.98,-15,1,-10-(currentNotifs*75))},{Time=THEME.Animation.Slow,EasingStyle=Enum.EasingStyle.Elastic});task.delay(duration or 4,function()if not notifFrame or not notifFrame.Parent then return end;UILib.Tween(notifFrame,{Position=notifFrame.Position+UDim2.new(0,300,0,0),Transparency=1},{Time=THEME.Animation.Medium});task.wait(THEME.Animation.Medium);if notifFrame and notifFrame.Parent then notifFrame:Destroy()end end)end
function MainUI:CreateProgressBar(parent,label)local c=UILib.Create("Frame"){Name="ProgressBarContainer",Parent=parent,Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,ClipsDescendants=true,};local b=UILib.Create("Frame"){Name="ProgressBar",Parent=c,Size=UDim2.new(1,0,1,0),BackgroundColor3=THEME.Colors.Secondary,BorderSizePixel=0,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,5)},UILib.Create("Frame"){Name="Fill",Size=UDim2.new(0,0,1,0),BackgroundColor3=THEME.Colors.ProgressBarFill,BorderSizePixel=0,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,5)}}},UILib.Create("TextLabel"){Name="Label",Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Font=THEME.Font.Code,Text=label or"",TextColor3=THEME.Colors.Background,TextSize=12,TextStrokeTransparency=0.8}}};function b:Update(prog,txt)UILib.Tween(b.Fill,{Size=UDim2.new(math.clamp(prog,0,1),0,1,0)},{Time=THEME.Animation.Fast});if txt then b.Label.Text=txt end end;function b:Run(dur,txt)b.Label.Text=txt or"";b.Fill.Size=UDim2.new(0,0,1,0);UILib.Tween(b.Fill,{Size=UDim2.new(1,0,1,0)},{Time=dur,EasingStyle=Enum.EasingStyle.Linear})end;return b end
function MainUI:CreateHeistCard(parent,heistData,robCallback)local card=UILib.Create("Frame"){Name="HeistCard",Parent=parent,Size=UDim2.new(1,0,0,60),BackgroundColor3=THEME.Colors.Primary,BorderSizePixel=0,ClipsDescendants=true,LayoutOrder=1,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,6)},UILib.Create("UIPadding"){PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,5)}}};UILib.Shadow(card);local title=UILib.Create("TextLabel"){Name="Title",Parent=card,Size=UDim2.new(0.65,0,0,25),Position=UDim2.new(0,0,0,0),BackgroundTransparency=1,Font=THEME.Font.Main,Text=heistData.DisplayName,TextColor3=THEME.Colors.AccentBright,TextSize=16,TextXAlignment=Enum.TextXAlignment.Left};local status=UILib.Create("TextLabel"){Name="Status",Parent=card,Size=UDim2.new(0.65,0,0,18),Position=UDim2.new(0,0,0,25),BackgroundTransparency=1,Font=THEME.Font.Code,Text="สถานะ: พร้อม",TextColor3=THEME.Colors.Success,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left};local btn=createStyledButton(card,"เริ่มปล้น",UDim2.new(0.3,0,0.8,0),UDim2.new(0.7,0,0.1,0),THEME.Colors.Accent,THEME.Colors.Background,13);btn.Name=heistData.Key.."_RobButton";RyntazHub.UI[heistData.Key.."_StatusLabel"]=status;RyntazHub.UI[heistData.Key.."_RobButton"]=btn;btn.MouseButton1Click:Connect(function()if RyntazHub.State.IsRobbing then MainUI:CreateNotification("ข้อผิดพลาด","การปล้นอื่นกำลังทำงานอยู่!","Error");return end;robCallback(heistData.Key)end);return card end
function MainUI:Build()if MainUI.ScreenGui and MainUI.ScreenGui.Parent then MainUI.ScreenGui:Destroy()end;MainUI.ScreenGui=UILib.Create("ScreenGui"){Name="RyntazHubTitanV3",Parent=Player:WaitForChild("PlayerGui"),ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ResetOnSpawn=false,DisplayOrder=1001};introAnimationV2(MainUI.ScreenGui);task.wait(1.5);MainUI.Frame=UILib.Create("Frame"){Name="MainFrame",Parent=MainUI.ScreenGui,Size=originalMainFrameSize,Position=UDim2.new(0.5,0,1.5,0),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=THEME.COLORS.Background,BorderSizePixel=1,BorderColor3=THEME.COLORS.Accent,Draggable=true,Active=true,ClipsDescendants=true,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,8)}}};UILib.Shadow(MainUI.Frame);local titleBar=UILib.Create("Frame"){Name="TitleBar",Parent=MainUI.Frame,Size=UDim2.new(1,0,0,35),BackgroundColor3=THEME.COLORS.Primary,BorderSizePixel=0,ZIndex=3,{UILib.Create("TextLabel"){Name="Title",Size=UDim2.new(1,-80,1,0),Position=UDim2.new(0.5,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Font=THEME.Font.Title,Text="RyntazHub :: TITAN OPS",TextColor3=THEME.COLORS.AccentBright,TextSize=18,TextXAlignment=Enum.TextXAlignment.Center}}};local btnS=UDim2.new(0,12,0,12);local btnY=0.5;local btnYO=-6;local cB=UILib.Create("ImageButton"){Parent=titleBar,Name="Close",Size=btnS,Position=UDim2.new(0,10,btnY,btnYO),Image="rbxassetid://13516625",ImageColor3=THEME.Colors.CloseButton,BackgroundTransparency=1,ZIndex=4};local mB=UILib.Create("ImageButton"){Parent=titleBar,Name="Minimize",Size=btnS,Position=UDim2.new(0,30,btnY,btnYO),Image="rbxassetid://13516625",ImageColor3=THEME.Colors.MinimizeButton,BackgroundTransparency=1,ZIndex=4};local mxB=UILib.Create("ImageButton"){Parent=titleBar,Name="Maximize",Size=btnS,Position=UDim2.new(0,50,btnY,btnYO),Image="rbxassetid://13516625",ImageColor3=THEME.Colors.MaximizeButton,BackgroundTransparency=1,ZIndex=4};local contentContainer=UILib.Create("Frame"){Name="ContentContainer",Parent=MainUI.Frame,Size=UDim2.new(1,0,1,-100),Position=UDim2.new(0,0,0,35),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=1,{UILib.Create("UIListLayout"){Padding=UDim.new(0,10),HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder}}};MainUI.ContentContainer=contentContainer;statusBar=UILib.Create("Frame"){Name="StatusBar",Parent=MainUI.Frame,Size=UDim2.new(1,-10,0,25),Position=UDim2.new(0,5,1,-65),BackgroundColor3=THEME.Colors.Primary,BackgroundTransparency=0.3,ZIndex=2,{UILib.Create("UICorner"){CornerRadius=UDim.new(0,3)}}};statusTextLabel=UILib.Create("TextLabel"){Parent=statusBar,Name="StatusText",Size=UDim2.new(0.7,-5,1,0),Position=UDim2.new(0,5,0,0),BackgroundTransparency=1,Font=THEME.Font.Code,Text="สถานะ: กำลังเตรียม...",TextColor3=THEME.Colors.TextDim,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left};timerTextLabel=UILib.Create("TextLabel"){Parent=statusBar,Name="TimerText",Size=UDim2.new(0.3,-5,1,0),Position=UDim2.new(0.7,5,0,0),BackgroundTransparency=1,Font=THEME.Font.Code,Text="เวลา: 0.0วิ",TextColor3=THEME.Colors.TextDim,TextSize=12,TextXAlignment=Enum.TextXAlignment.Right};local bottomBar=UILib.Create("Frame"){Name="BottomBar",Parent=MainUI.Frame,Size=UDim2.new(1,0,0,35),Position=UDim2.new(0,0,1,-35),BackgroundColor3=THEME.Colors.Primary,ZIndex=2};local startAllBtn=createStyledButton(bottomBar,"ปล้นทั้งหมด",UDim2.new(0.45,-10,0.8,0),UDim2.new(0.025,0,0.1,0),THEME.Colors.Accent,THEME.Colors.Background);local stopBtn=createStyledButton(bottomBar,"หยุดปล้น",UDim2.new(0.45,-10,0.8,0),UDim2.new(0.525,0,0.1,0),THEME.Colors.Error,THEME.Colors.Text);local dragging=false;local dI,dS,sPF;titleBar.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true;dS=i.Position;sPF=MainUI.Frame.Position;i.Changed:Connect(function()if i.UserInputState==Enum.UserInputState.End then dragging=false end end)end end);UserInputService.InputChanged:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then if dragging and dS then local d=i.Position-dS;MainUI.Frame.Position=UDim2.new(sPF.X.Scale,sPF.X.Offset+d.X,sPF.Y.Scale,sPF.Y.Offset+d.Y)end end end);cB.MouseButton1Click:Connect(function()local ct=UILib.Tween(MainUI.Frame,{Size=UDim2.fromScale(0.01,0.01),Position=UDim2.new(0.5,0,0.5,0),Transparency=1},{Time=0.2,EasingStyle=Enum.EasingStyle.Quad,EasingDirection=Enum.EasingDirection.In});ct.Completed:Wait();MainUI.ScreenGui:Destroy();MainUI.ScreenGui=nil;mainFrame=nil;if currentRobberyCoroutine then task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil end end);local isCV=INITIAL_UI_VISIBLE;local function tCV()isCV=not isCV;contentContainer.Visible=isCV;bottomBar.Visible=isCV;statusBar.Visible=isCV;local tS;if isCV then tS=originalMainFrameSize;mxB.ImageColor3=THEME.Colors.MaximizeButton;mB.ImageColor3=THEME.Colors.MinimizeButton else tS=UDim2.new(originalMainFrameSize.X.Scale,originalMainFrameSize.X.Offset,0,titleBar.AbsoluteSize.Y);mxB.ImageColor3=THEME.Colors.Accent;mB.ImageColor3=THEME.Colors.Accent end;UILib.Tween(MainUI.Frame,{Size=tS},{Time=0.2})end;mB.MouseButton1Click:Connect(tCV);mxB.MouseButton1Click:Connect(tCV);startAllBtn.MouseButton1Click:Connect(function()if RyntazHub.State.IsRobbing then MainUI:CreateNotification("ไม่ว่าง","การปล้นอื่นกำลังทำงานอยู่!","Warning");return end;RyntazHub.State.IsRobbing=true;currentRobberyCoroutine=task.spawn(RyntazHub.ExecutionEngine.RunAllSequences)end);stopBtn.MouseButton1Click:Connect(function()if currentRobberyCoroutine then task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;RyntazHub.State.IsRobbing=false;RyntazHub.State.CurrentHeist=nil;RyntazHub.State.CurrentAction=nil;MainUI:CreateNotification("หยุดแล้ว","การปล้นถูกสั่งหยุด","Warning");updateStatus("หยุดโดยผู้ใช้.",0)else MainUI:CreateNotification("สถานะ","ไม่มีการปล้นที่กำลังทำงาน","Info")end end);originalMainFramePosition=UDim2.new(0.5,0,0.5,0);UILib.Tween(MainUI.Frame,{Visible=true,Size=originalMainFrameSize,Position=originalMainFramePosition},{Time=THEME.Animation.Slow,EasingStyle=Enum.EasingStyle.Elastic});if not INITIAL_UI_VISIBLE then task.wait(THEME.Animation.Slow);tCV()end;MainUI:CreateNotification("RyntazHub Titan", "เริ่มต้นการทำงานแล้ว!", "Success", 3)end

RyntazHub.Scanner={FindInstanceFromPath=function(path)local current=game;for component in path:gmatch("([^%.]+)")do current=current:FindFirstChild(component);if not current then return nil end end;return current end,ScanHeist=function(heistName,heistConfig)if not Character then MainUI:CreateNotification("ข้อผิดพลาด Scanner","Character ไม่พร้อมใช้งาน","Error");return end;local heistFolder=RyntazHub.Scanner.FindInstanceFromPath(heistConfig.Identifiers.Path);if not heistFolder then MainUI:CreateNotification("Scan Error","ไม่พบ Heist Folder: "..heistName,"Error");RyntazHub.Data.Analyzed[heistName]=nil;return end;RyntazHub.Data.Analyzed[heistName]={Key=heistName,DisplayName=heistConfig.DisplayName,Root=heistFolder,AnalyzedSequence={},Config=heistConfig,EntryTeleport=heistConfig.EntryTeleport};local sequencePossible=true;for i,stepConfig in ipairs(heistConfig.Sequence)do local analyzedStep={Name=stepConfig.Name,Type=stepConfig.Type,Config=stepConfig,TargetInstance=nil,RemoteEventInstance=nil,ProximityPromptInstance=nil};if stepConfig.TargetPath then analyzedStep.TargetInstance=heistFolder:FindFirstChild(stepConfig.TargetPath,true)end;if stepConfig.Type=="IterateAndFireEvent"or stepConfig.Type=="IterateAndTriggerPrompt"then if stepConfig.ItemContainerPath then local container=heistFolder:FindFirstChild(stepConfig.ItemContainerPath,true);if container then analyzedStep.TargetInstance=container else MainUI:CreateNotification("Config Error",heistName.." - Step "..i..": ไม่พบ ItemContainerPath: "..stepConfig.ItemContainerPath,"Error");sequencePossible=false;break end else MainUI:CreateNotification("Config Error",heistName.." - Step "..i..": ไม่ได้ระบุ ItemContainerPath สำหรับ Iterate","Error");sequencePossible=false;break end end;if stepConfig.Type=="RemoteEvent"or stepConfig.Type=="IterateAndFireEvent"then if stepConfig.RemoteEventPath then local eventPathBase=analyzedStep.TargetInstance or heistFolder;analyzedStep.RemoteEventInstance=RyntazHub.Scanner.FindInstanceFromPath(stepConfig.RemoteEventPath)or eventPathBase:FindFirstChild(stepConfig.RemoteEventPath,true)elseif stepConfig.RemoteEventHint then local searchBase=analyzedStep.TargetInstance or heistFolder;analyzedStep.RemoteEventInstance=findRemote(searchBase,stepConfig.RemoteEventHint)or findRemote(searchBase.Parent,stepConfig.RemoteEventHint)end;if not(analyzedStep.RemoteEventInstance and analyzedStep.RemoteEventInstance:IsA("RemoteEvent"))then MainUI:CreateNotification("Config Error",heistName.." - Step "..i..": ไม่พบ RemoteEvent ("..(stepConfig.RemoteEventPath or stepConfig.RemoteEventHint or"N/A")..")","Error");sequencePossible=false;break end end;if stepConfig.Type=="ProximityPrompt"or stepConfig.Type=="IterateAndTriggerPrompt"then local searchBaseForPrompt=analyzedStep.TargetInstance or(stepConfig.TargetPath and heistFolder:FindFirstChild(stepConfig.TargetPath,true))or heistFolder;if searchBaseForPrompt then analyzedStep.ProximityPromptInstance=findPrompt(searchBaseForPrompt,stepConfig.ProximityPromptActionHint)if not analyzedStep.ProximityPromptInstance then MainUI:CreateNotification("Config Error",heistName.." - Step "..i..": ไม่พบ ProximityPrompt (Hint: ".. (stepConfig.ProximityPromptActionHint or "N/A")..") ใน "..searchBaseForPrompt:GetFullName(),"Error");sequencePossible=false;break end else MainUI:CreateNotification("Config Error",heistName.." - Step "..i..": ไม่สามารถหา TargetPath สำหรับ ProximityPrompt ได้","Error");sequencePossible=false;break end end;if not analyzedStep.TargetInstance and(stepConfig.Type=="Touch"or stepConfig.Type=="ProximityPrompt"or((stepConfig.Type=="IterateAndFireEvent"or stepConfig.Type=="IterateAndTriggerPrompt")and not analyzedStep.TargetInstance))then MainUI:CreateNotification("Config Error",heistName.." - Step "..i..": ไม่พบ TargetPath/ItemContainerPath หรือ TargetPath ไม่ถูกต้อง","Error");sequencePossible=false;break end;table.insert(RyntazHub.Data.Analyzed[heistName].AnalyzedSequence,analyzedStep)end;if not sequencePossible then RyntazHub.Data.Analyzed[heistName]=nil;MainUI:CreateNotification("Heist Incomplete",heistName.." ไม่สามารถดำเนินการได้เนื่องจาก Config ไม่สมบูรณ์","Warning")else MainUI:CreateNotification("Heist Ready",heistName.." พร้อมสำหรับการปล้นแล้ว","Success",2)end end}}
RyntazHub.UIController={PopulateHeists=function()local heistsPage=MainUI.ContentContainer;for _,child in ipairs(heistsPage:GetChildren())do if child.Name=="HeistCard"then child:Destroy()end end;local count=0;for key,heistData in pairs(RyntazHub.Data.Analyzed)do if heistData then MainUI:CreateHeistCard(heistsPage,heistData,RyntazHub.ExecutionEngine.Run);count=count+1 end end;if count==0 then UILib.Create("TextLabel"){Parent=heistsPage,Text="ไม่พบ Heist ที่สามารถดำเนินการได้ โปรดตรวจสอบ Config หรือการสแกน",Font=THEME.Font.UI,TextSize=14,TextColor3=THEME.Colors.Warning,Size=UDim2.new(1,-20,0,50),BackgroundTransparency=1,TextWrapped=true}end end}
RyntazHub.ExecutionEngine={Run=function(heistKey)if RyntazHub.State.IsRobbing then MainUI:CreateNotification("ไม่ว่าง","การปล้นอื่นกำลังทำงานอยู่!","Warning",2);return end;local heistData=RyntazHub.Data.Analyzed[heistKey];if not heistData then MainUI:CreateNotification("ข้อผิดพลาด","ไม่พบข้อมูลสำหรับ Heist: "..heistKey,"Error");return end;RyntazHub.State.IsRobbing=true;RyntazHub.State.CurrentHeist=heistKey;MainUI:CreateNotification("เริ่มปล้น",heistData.DisplayName.." กำลังเริ่ม...","AccentBright",3);local statusLabel=RyntazHub.UI[heistKey.."_StatusLabel"];local robButton=RyntazHub.UI[heistKey.."_RobButton"];if statusLabel then statusLabel.Text="สถานะ: กำลังปล้น...";statusLabel.TextColor3=THEME.Colors.Warning end;if robButton then robButton.Text="กำลังปล้น";robButton.Enabled=false end;currentRobberyCoroutine=task.spawn(function()local overallSuccess=true;if heistData.EntryTeleport and RootPart then updateStatus("กำลังเทเลพอร์ตไป "..heistData.DisplayName.."...");local s,e=pcall(function()RootPart.CFrame=heistData.EntryTeleport end);if not s then MainUI:CreateNotification("TP Error","เทเลพอร์ตไป "..heistData.DisplayName.." ล้มเหลว: "..tostring(e),"Error");overallSuccess=false end;task.wait(0.3)end;if overallSuccess then for stepIdx,stepData in ipairs(heistData.AnalyzedSequence)do if not RyntazHub.State.IsRobbing then MainUI:CreateNotification("หยุดแล้ว","การปล้น "..heistData.DisplayName.." ถูกหยุด","Warning");overallSuccess=false;break end;RyntazHub.State.CurrentAction=stepData.Name;updateStatus(string.format("Heist: %s - ขั้นตอน: %s",heistData.DisplayName,stepData.Name));local stepConfig=stepData.Config;local actionSuccess=false;if stepData.Type=="Touch"and stepData.TargetInstance then RootPart.CFrame=stepData.TargetInstance.CFrame+(stepConfig.TeleportOffset or Vector3.new(0,0,-2.5));task.wait(0.1);if typeof(firetouchinterest)=="function"then pcall(function()firetouchinterest(stepData.TargetInstance,RootPart,0);task.wait(0.05);firetouchinterest(stepData.TargetInstance,RootPart,1)end);actionSuccess=true else MainUI:CreateNotification("แจ้งเตือน","Executor ไม่มี firetouchinterest","Warning")end elseif stepData.Type=="ProximityPrompt"and stepData.ProximityPromptInstance then RootPart.CFrame=(stepData.TargetInstance.CFrame+(stepConfig.TeleportOffset or Vector3.new(0,0,-2)));task.wait(0.1);if typeof(fireproximityprompt)=="function"then MainUI:CreateNotification("Prompt",string.format("กำลังกด %s (%.1fs)",stepData.ProximityPromptInstance.ActionText,stepConfig.HoldDuration or 0),"Info",stepConfig.HoldDuration);pcall(fireproximityprompt,stepData.ProximityPromptInstance,stepConfig.HoldDuration or 0);actionSuccess=true else MainUI:CreateNotification("แจ้งเตือน","Executor ไม่มี fireproximityprompt","Warning")end elseif(stepData.Type=="RemoteEvent"or stepData.Type=="IterateAndFireEvent")and stepData.RemoteEventInstance then local itemsToTarget={stepData.TargetInstance};if stepData.Type=="IterateAndFireEvent"then if stepData.TargetInstance and stepConfig.ItemQuery then itemsToTarget=stepConfig.ItemQuery(stepData.TargetInstance)else MainUI:CreateNotification("Config Error",heistData.DisplayName.." - "..stepData.Name..": ItemContainer หรือ ItemQuery ไม่ถูกต้อง","Error");overallSuccess=false;break end end;local itemCount=#itemsToTarget;local itemProgressBar;if stepConfig.Progress and stepConfig.Progress.Enabled and itemCount > 1 then itemProgressBar = MainUI:CreateProgressBar(RyntazHub.UIHooks.HeistsPage, ""); itemProgressBar.LayoutOrder = 0; itemProgressBar.Parent.CanvasSize = UDim2.new(0,0,itemProgressBar.Parent.CanvasSize.Y.Offset + 25) end;for itemIdx,item in ipairs(itemsToTarget)do if not RyntazHub.State.IsRobbing then overallSuccess=false;break end;if itemProgressBar then itemProgressBar:Update(itemIdx/itemCount,string.format("%s (%d/%d)",stepData.Name,itemIdx,itemCount))end;if item:IsA("BasePart")or item:IsA("Model")then RootPart.CFrame=(item:IsA("Model")and item:GetPivot()or item.CFrame)+(stepConfig.TeleportOffset or Vector3.new(0,1.5,0));task.wait(stepConfig.DelayBetweenItems or 0.1)end;local args=stepConfig.EventArgsFunc and stepConfig.EventArgsFunc(item)or{};for f=1,stepConfig.FireCountPerItem or 1 do if not RyntazHub.State.IsRobbing then overallSuccess=false;break end;local s,e=pcall(function()stepData.RemoteEventInstance:FireServer(unpack(args))end);if not s then MainUI:CreateNotification("RE Error",string.format("Error firing %s for %s: %s",stepData.RemoteEventInstance.Name,item.Name,tostring(e)),"Error")end;if(stepConfig.FireCountPerItem or 1)>1 then task.wait(stepConfig.DelayBetweenFires or 0.05)end end;if not RyntazHub.State.IsRobbing then overallSuccess=false;break end end;if itemProgressBar and itemProgressBar.Parent then itemProgressBar.Parent.CanvasSize = UDim2.new(0,0,itemProgressBar.Parent.CanvasSize.Y.Offset - 25); itemProgressBar:Destroy() end;actionSuccess=true end;if not actionSuccess and stepConfig.Type ~= "Touch" and stepConfig.Type ~= "ProximityPrompt" then MainUI:CreateNotification("Action Failed", heistData.DisplayName .. " - " .. stepData.Name .. " ล้มเหลว","Error"); overallSuccess=false; break end;if stepConfig.Cooldown then updateStatus(string.format("Heist: %s - รอ Cooldown %.1fs...", heistData.DisplayName, stepConfig.Cooldown)); task.wait(stepConfig.Cooldown) end;if not overallSuccess then break end end end;if overallSuccess then MainUI:CreateNotification("สำเร็จ!",heistData.DisplayName.." ปล้นสำเร็จ!","Success")else MainUI:CreateNotification("ล้มเหลว/หยุด",heistData.DisplayName.." ปล้นไม่สำเร็จหรือถูกหยุด","Error")end;if statusLabel then statusLabel.Text="สถานะ: ว่าง";statusLabel.TextColor3=THEME.Colors.TextDim end;if robButton then robButton.Text="เริ่มปล้น";robButton.Enabled=true end;RyntazHub.State.IsRobbing=false;RyntazHub.State.CurrentHeist=nil;RyntazHub.State.CurrentAction=nil;currentRobberyCoroutine=nil end)end,RunAllSequences=function()startTime=tick();updateStatus("กำลังเตรียมข้อมูล Heists...",0);local allHeistsPrepared=true;for i,heistName in ipairs(TARGET_HEISTS_TO_ROB)do local config=MasterConfig[heistName];if config then RyntazHub.Scanner.ScanHeist(heistName,config)else MainUI:CreateNotification("Config Error","ไม่พบ MasterConfig สำหรับ: "..heistName,"Error");allHeistsPrepared=false end;updateStatus("เตรียม "..heistName.." เสร็จสิ้น",(i/#TARGET_HEISTS_TO_ROB)*100);if i<#TARGET_HEISTS_TO_ROB then task.wait(0.1)end end;if not allHeistsPrepared then MainUI:CreateNotification("ข้อผิดพลาด","การเตรียมข้อมูลบาง Heist ล้มเหลว","Error");RyntazHub.State.IsRobbing=false;currentRobberyCoroutine=nil;return end;MainUI.UIController.PopulateHeists();updateStatus("เริ่มลำดับการปล้นทั้งหมด...",0);local totalHeistsToRob=#TARGET_HEISTS_TO_ROB;for i,heistName in ipairs(TARGET_HEISTS_TO_ROB)do if not currentRobberyCoroutine then break end;if RyntazHub.Data.Analyzed[heistName]then RyntazHub.ExecutionEngine.Run(heistName);local timeout=0;while RyntazHub.State.IsRobbing and timeout<300 do task.wait(0.1);timeout=timeout+0.1 end;if RyntazHub.State.IsRobbing then task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;RyntazHub.State.IsRobbing=false;MainUI:CreateNotification("Timeout",heistName.." ใช้เวลานานเกินไป, ถูกหยุด.","Warning")end else MainUI:CreateNotification("ข้าม",heistName.." ไม่ได้ถูกเตรียมไว้","Info")end;updateStatus("เสร็จสิ้น "..heistName,(i/totalHeistsToRob)*100);if i<totalHeistsToRob and currentRobberyCoroutine then task.wait(1)end end;updateStatus("ปล้นทั้งหมดเสร็จสิ้น.",100);MainUI:CreateNotification("เสร็จสิ้น","การปล้นตามลำดับทั้งหมดเสร็จสิ้น","Success");RyntazHub.State.IsRobbing=false;currentRobberyCoroutine=nil end}

local function initialScan()
    startTime = tick()
    logOutputWrapper("System", "RyntazHub Titan V3.0 Initializing & Scanning...")
    local pathsToScanConfig = {}
    local heistsFolder = Workspace:FindFirstChild(HEISTS_BASE_PATH_STRING)
    if heistsFolder then
        if #TARGET_HEISTS_IN_WORKSPACE > 0 then
            for _, heistName in ipairs(TARGET_HEISTS_IN_WORKSPACE) do
                local specificHeistFolder = heistsFolder:FindFirstChild(heistName)
                if specificHeistFolder then table.insert(pathsToScanConfig, {instance = specificHeistFolder, name = specificHeistFolder:GetFullName(), isHeist = true, heistNameForConfig = heistName})
                else logOutputWrapper("Error", "ไม่พบ Folder Heist: " .. heistName) end
            end
        else
            for _, childHeist in ipairs(heistsFolder:GetChildren()) do if childHeist:IsA("Instance") then table.insert(pathsToScanConfig, {instance = childHeist, name = childHeist:GetFullName(), isHeist = true, heistNameForConfig = childHeist.Name}) end end
        end
    else logOutputWrapper("Error", "ไม่พบ Folder Heists หลัก: '" .. HEISTS_BASE_PATH_STRING .. "' ใน Workspace.") end
    if ReplicatedStorage then table.insert(pathsToScanConfig, {instance = ReplicatedStorage, name = "ReplicatedStorage"}) end
    
    local totalScanTasks = #pathsToScanConfig
    if totalScanTasks == 0 then updateStatus("ไม่พบ Path ที่จะสแกน", 100); logOutputWrapper("System", "Focused scan finished (No paths)."); return end

    for i, scanTask in ipairs(pathsToScanConfig) do
        if scanTask.isHeist then
             -- ในเวอร์ชันนี้ การสแกน Heist จะถูกทำเมื่อกดปล้นหรือ "ปล้นทั้งหมด"
             -- แต่เรายังสามารถ Log ข้อมูลเบื้องต้นของ Heist folder ได้
            logOutputWrapper("HeistStructure", "ตรวจสอบ Heist Folder: "..scanTask.name)
            -- exploreFocusedPath(scanTask.instance, scanTask.name, i, totalScanTasks) --  เดิมทีเรียก explore แต่ตอนนี้จะให้ scanAndPrepare ทำ
            updateStatus("ตรวจสอบ Heist: " .. scanTask.name, (i / totalScanTasks) * 100)
        else
            exploreFocusedPath(scanTask.instance, scanTask.name, i, totalScanTasks)
        end
        if i < totalScanTasks then task.wait(0.01) end -- ลด delay ตอนสแกน
    end
    updateStatus("การสำรวจเบื้องต้นเสร็จสิ้น.", 100)
    logOutputWrapper("System", string.format("การสำรวจเบื้องต้นเสร็จสิ้นใน %.2f วินาที.", tick() - startTime))
    MainUI.UIController.PopulateHeists() -- แสดง Heist Card จาก MasterConfig โดยยังไม่จำเป็นต้องสแกนละเอียด
end

task.spawn(function()while true do if SHOW_UI_OUTPUT and mainFrame and mainFrame.Parent and timerTextLabel then if startTime then timerTextLabel.Text=string.format("เวลา: %.1fs",tick()-startTime)else timerTextLabel.Text="เวลา: --.-s"end end;task.wait(0.1)end end)
if SHOW_UI_OUTPUT then local uiSuccess,uiErr=pcall(MainUI.Build);if not uiSuccess then print("FATAL UI ERROR: "..tostring(uiErr))end else print("RyntazHub UI Built.") end
task.spawn(function()task.wait(0.2);local scanSuccess,scanErr=pcall(initialScan);if not scanSuccess then logOutputWrapper("SystemError","Scan Error: "..tostring(scanErr));if statusTextLabel and statusTextLabel.Parent then statusTextLabel.Text="สถานะ: Scan Error!"end else logOutputWrapper("System","สแกนเบื้องต้นเสร็จสิ้น. UI พร้อมใช้งาน.")end end)

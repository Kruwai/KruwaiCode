-- AutoRob (Focused & Simplified) - V4.0
-- เน้นการปล้น, เทเลพอร์ต, และ Server Hop

local Player = game:GetService("Players").LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local Character
local Humanoid
local HumanoidRootPart

local function waitForCharacter()
    print("[AutoRob] Waiting for character...")
    local attempts = 0
    repeat
        attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character
            Humanoid = Character:FindFirstChildOfClass("Humanoid")
            RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then
                print("[AutoRob] Character found.")
                return true
            end
        end
        task.wait(0.3)
    until attempts > 60
    print("[AutoRob] ERROR: Character not found after timeout.")
    return false
end

Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid", 15)
    HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart", 15)
    print("[AutoRob] Character respawned/added.")
end)

-- ================= CONFIGURATION (สำคัญมาก - คุณต้องปรับแก้ให้ตรงกับเกม) =================
local HEIST_BASE_PATH_STRING = "Workspace.Heists" -- Path เต็มจาก game

local HEIST_CONFIG = {
    JewelryStore = {
        DisplayName = "ร้านเพชร",
        PathString = HEIST_BASE_PATH_STRING .. ".JewelryStore",
        EntryTeleportCFrame = nil, -- CFrame.new(-82, 86, 807), -- (Optional)
        RobberyActions = {
            {
                Name = "เก็บเครื่องเพชร",
                ActionType = "IterateAndFireEvent",
                ItemContainerPath = "EssentialParts.JewelryBoxes",
                RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event", -- Path จาก Log ของคุณ
                EventArgsFunc = function(lootInstance) return {lootInstance} end,
                FireCountPerItem = 2,
                TeleportOffsetPerItem = Vector3.new(0, 1.8, 2.2),
                DelayBetweenItems = 0.2,
                DelayBetweenFires = 0.1
            }
        }
    },
    Bank = {
        DisplayName = "ธนาคาร",
        PathString = HEIST_BASE_PATH_STRING .. ".Bank",
        EntryTeleportCFrame = CFrame.new(730, 108, 565),
        RobberyActions = {
            {
                Name = "เปิดประตูห้องมั่นคง", ActionType = "Touch", TargetPath = "EssentialParts.VaultDoor.Touch",
                TeleportOffset = Vector3.new(0, 0, -2.5), RobDelayAfter = 1.0
            },
            {
                Name = "เก็บเงิน", ActionType = "IterateAndFindInteract",
                ItemContainerPath = "Interior", ItemNameHint = "Cash",
                InteractionHint = {Type="RemoteEvent", NameHint="Collect", Args=function(item) return {item} end},
                TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.3, FireCountPerItem = 1
            }
        }
    },
    Casino = {
        DisplayName = "คาสิโน",
        PathString = HEISTS_BASE_PATH_STRING .. ".Casino",
        EntryTeleportCFrame = CFrame.new(1690, 30, 525),
        RobberyActions = {
            {
                Name = "แฮ็กคอมพิวเตอร์", ActionType = "ProximityPrompt", TargetPath = "Interior.HackComputer.HackComputer",
                ProximityPromptActionHint = "Hack", HoldDuration = 2.5, TeleportOffset = Vector3.new(0,1,-1.8), RobDelayAfter = 1.0
            },
            {
                Name = "เก็บเงินห้องนิรภัย", ActionType = "IterateAndFindInteract",
                ItemContainerPath = "Interior.Vault", ItemNameHint = "Cash",
                InteractionHint = {Type="RemoteEvent", NameHint="Take|Collect", Args=function(item) return {item} end},
                TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.4, FireCountPerItem = 1
            }
        }
    }
}
local ROB_ORDER = {"JewelryStore", "Bank", "Casino"} -- ลำดับการปล้น

-- ================= HELPER FUNCTIONS =================
local function findInstanceFromPath(pathString)
    local current = game
    for component in pathString:gmatch("([^%.]+)") do
        if current then
            current = current:FindFirstChild(component)
        else
            return nil
        end
    end
    return current
end

local function teleportTo(targetCFrame)
    if not HumanoidRootPart then print("[Teleport] HumanoidRootPart is nil."); return false end
    local success, err = pcall(function() HumanoidRootPart.CFrame = targetCFrame end)
    if not success then print("[Teleport] Failed:", err) return false end
    -- print("[Teleport] Teleported to:", targetCFrame.Position)
    task.wait(0.1) -- ให้เวลา Server Sync เล็กน้อย
    return true
end

local function findRemote(parentInst, nameHint, typeHint)
    typeHint = typeHint or "RemoteEvent"
    if not parentInst then return nil end
    for _, D in ipairs(parentInst:GetDescendants()) do
        if D:IsA(typeHint) and D.Name:lower():match(nameHint:lower()) then return D end
    end
    return nil
end

local function findPrompt(parentInst, actionHint)
    if not parentInst then return nil end
    for _, D in ipairs(parentInst:GetDescendants()) do
        if D:IsA("ProximityPrompt") then
            if D.ActionText and D.ActionText:lower():match(actionHint:lower()) then return D
            elseif D.ObjectText and D.ObjectText:lower():match(actionHint:lower()) then return D end
        end
    end
    return nil
end

-- ================= ROBBERY LOGIC =================
local function attemptSingleRobberyAction(actionConfig, heistFolder)
    if not (Character and Humanoid and Humanoid.Health > 0) then print("[Robbery] Character dead or missing."); return false end
    print(string.format("[Robbery] Attempting Action: %s", actionConfig.Name))

    local targetInstance
    if actionConfig.TargetPath then
        targetInstance = heistFolder:FindFirstChild(actionConfig.TargetPath, true)
        if not targetInstance then print("[Robbery] TargetPath not found: " .. actionConfig.TargetPath); return false end
    end

    local robSuccessful = false
    local interactionType = actionConfig.InteractionType

    if interactionType == "Touch" and targetInstance then
        if teleportTo(targetInstance.CFrame * CFrame.new(actionConfig.TeleportOffset or Vector3.new())) then
            if typeof(firetouchinterest) == "function" and targetInstance:IsA("BasePart") then
                print("[Robbery] Firing touch interest for:", targetInstance.Name)
                pcall(firetouchinterest, targetInstance, RootPart, 0); task.wait(0.05)
                pcall(firetouchinterest, targetInstance, RootPart, 1); robSuccessful = true
            else print("[Robbery] firetouchinterest not available or target not BasePart.") end
        end
    elseif interactionType == "ProximityPrompt" and targetInstance then
        local prompt = findPrompt(targetInstance, actionConfig.ProximityPromptActionHint or targetInstance.Name)
        if prompt then
            if teleportTo(targetInstance.CFrame * CFrame.new(actionConfig.TeleportOffset or Vector3.new())) then
                if typeof(fireproximityprompt) == "function" then
                    print(string.format("[Robbery] Firing ProximityPrompt: %s (Hold: %.1fs)", prompt.ActionText or prompt.ObjectText or "Unknown", actionConfig.HoldDuration or 0))
                    pcall(fireproximityprompt, prompt, actionConfig.HoldDuration or 0); robSuccessful = true
                else print("[Robbery] fireproximityprompt not available.") end
            end
        else print("[Robbery] ProximityPrompt not found for:", targetInstance.Name, "Hint:", actionConfig.ProximityPromptActionHint) end
    elseif (interactionType == "RemoteEvent" or interactionType == "IterateAndFireEvent") then
        local itemsToProcess = {}
        local remoteEventInstance

        if interactionType == "IterateAndFireEvent" then
            local container = heistFolder:FindFirstChild(actionConfig.ItemContainerPath, true)
            if not container then print("[Robbery] ItemContainerPath not found:", actionConfig.ItemContainerPath); return false end
            if actionConfig.ItemQuery then itemsToProcess = actionConfig.ItemQuery(container)
            else for _,child in ipairs(container:GetChildren()) do if child:IsA("Model") or child:IsA("BasePart") then table.insert(itemsToProcess, child) end end end
            
            if actionConfig.RemoteEventPath then remoteEventInstance = findInstanceFromPath(actionConfig.RemoteEventPath) -- Path เต็ม หรือ Path จาก HeistFolder ถ้าไม่ได้เริ่มด้วย Workspace/game
            elseif actionConfig.RemoteEventNameHint and #itemsToProcess > 0 then remoteEventInstance = findRemote(itemsToProcess[1], actionConfig.RemoteEventNameHint) or findRemote(itemsToProcess[1].Parent, actionConfig.RemoteEventNameHint) or findRemote(heistFolder, actionConfig.RemoteEventNameHint) end

        else -- Single RemoteEvent type
            if actionConfig.TargetPath then -- Event is on a specific target
                 targetInstance = heistFolder:FindFirstChild(actionConfig.TargetPath, true)
                 if not targetInstance then print("[Robbery] TargetPath for SingleEvent not found: " .. actionConfig.TargetPath); return false end
                 table.insert(itemsToProcess, targetInstance) -- Process this single target
                 if actionConfig.RemoteEventPath then remoteEventInstance = targetInstance:FindFirstChild(actionConfig.RemoteEventPath, true)
                 elseif actionConfig.RemoteEventNameHint then remoteEventInstance = findRemote(targetInstance, actionConfig.RemoteEventNameHint) or findRemote(targetInstance.Parent, actionConfig.RemoteEventNameHint) end
            elseif actionConfig.RemoteEventPath then -- Event is at a global/heist path
                remoteEventInstance = findInstanceFromPath(actionConfig.RemoteEventPath)
                table.insert(itemsToProcess, heistFolder) -- Use heistFolder as a dummy instance for EventArgsFunc if needed
            end
        end

        if not remoteEventInstance or not remoteEventInstance:IsA("RemoteEvent") then print("[Robbery] RemoteEvent not found for action:", actionConfig.Name, "(Path/Hint:", actionConfig.RemoteEventPath or actionConfig.RemoteEventNameHint or "N/A", ")"); return false end

        for i, itemInst in ipairs(itemsToProcess) do
            if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("[Robbery] Robbery sequence interrupted."); return false end
            if itemInst:IsA("BasePart") or itemInst:IsA("Model") then
                local itemCFrame = (itemInst:IsA("Model") and itemInst:GetPivot() or itemInst.CFrame)
                if not teleportTo(itemCFrame * CFrame.new(actionConfig.TeleportOffsetPerItem or actionConfig.TeleportOffset or Vector3.new(0,1.5,0))) then return false end
            end
            
            local argsToFire = {}; if actionConfig.EventArgsFunc then argsToFire = actionConfig.EventArgsFunc(itemInst) or {} end
            print(string.format("[Robbery] Firing RE: %s for %s (Item %d/%d)", remoteEventInstance.Name, itemInst.Name, i, #itemsToProcess))
            for fc = 1, actionConfig.FireCountPerItem or 1 do
                if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("[Robbery] Robbery sequence interrupted during fire loop."); return false end
                local s,e = pcall(function() remoteEventInstance:FireServer(unpack(argsToFire)) end)
                if not s then print("[Robbery] Error firing event for "..itemInst.Name..": "..tostring(e)) end
                task.wait(actionConfig.DelayBetweenFires or 0.05)
            end
            robSuccessful = true
            if #itemsToProcess > 1 and i < #itemsToProcess then task.wait(actionConfig.DelayBetweenItems or 0.1) end
        end
    end

    if robSuccessful then print(string.format("[Robbery] Action '%s' completed.", actionConfig.Name))
    else print(string.format("[Robbery] Action '%s' failed or no interaction method found.", actionConfig.Name)) end
    
    if actionConfig.RobDelayAfter then task.wait(actionConfig.RobDelayAfter) end
    return robSuccessful
end

function executeHeistSequence(heistName)
    local config = HEIST_SPECIFIC_CONFIG[heistName]
    if not config then print("[Heist] No config for: " .. heistName); return false end
    local heistFolder = findInstanceFromPath(config.PathString)
    if not heistFolder then print("[Heist] Heist folder not found: " .. config.PathString); return false end

    print(string.format("--- Starting Heist: %s ---", config.DisplayName))
    if config.EntryTeleportCFrame and RootPart then
        print("[Heist] Teleporting to entry point for " .. config.DisplayName)
        if not teleportTo(config.EntryTeleportCFrame) then return false end
        task.wait(0.5)
    end

    for i, actionConfig in ipairs(config.RobberyActions or {}) do
        if not currentRobberyCoroutine then print("[Heist] Robbery sequence cancelled."); return false end
        if not (Character and Humanoid and Humanoid.Health > 0) then print("[Heist] Character died, stopping heist: " .. config.DisplayName); return false end
        
        if not attemptSingleRobberyAction(actionConfig, heistFolder) then
            print(string.format("[Heist] Action '%s' in %s failed. Stopping this heist.", actionConfig.Name, config.DisplayName))
            return false -- Stop this heist if one action fails
        end
        task.wait(0.2) -- Small delay between actions
    end
    print(string.format("--- Heist: %s - Sequence Completed ---", config.DisplayName))
    return true
end

local function ServerHop()
    print("[ServerHop] Attempting to server hop...")
    local success, err = pcall(function()
        local servers = {}
        local req = HttpService:RequestAsync({Url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", Method = "GET"})
        if not req or not req.Success or not req.Body then print("[ServerHop] Failed to get server list:", req and req.Body or "No response"); return end
        
        local body = HttpService:JSONDecode(req.Body)
        if body and body.data then
            for _, v in next, body.data do
                if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= game.JobId then
                    table.insert(servers, 1, v.id)
                end
            end
        end
        print("[ServerHop] Found", #servers, "available servers.")
        if #servers > 0 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], Player)
        else
            print("[ServerHop] No other servers found. Rejoining current if solo, else kicking.")
            if #Player:GetPlayers() <= 1 then Player:Kick("Rejoining (No other servers)..."); task.wait(1); TeleportService:Teleport(game.PlaceId, Player)
            else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player) end -- Rejoin current if others are present
        end
    end)
    if not success then print("[ServerHop] Pcall failed:", err); TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player) end
end

function executeAllRobberiesSequence()
    if currentRobberyCoroutine then print("[AutoRob] Sequence already running."); return end
    
    currentRobberyCoroutine = coroutine.running() -- Store current coroutine so it can be cancelled
    print("--- Starting Full Auto-Robbery Sequence ---")
    startTime = tick()
    
    for i, heistName in ipairs(ROB_ORDER) do
        if not currentRobberyCoroutine then print("[AutoRob] Full sequence cancelled."); break end
        if not (Character and Humanoid and Humanoid.Health > 0) then print("[AutoRob] Character died, stopping full sequence."); break end
        
        print(string.format("[AutoRob] Preparing for heist: %s (%d/%d)", HEIST_SPECIFIC_CONFIG[heistName].DisplayName, i, #ROB_ORDER))
        if not executeHeistSequence(heistName) then
            print(string.format("[AutoRob] Heist %s failed or was interrupted. Moving to next (if any).", HEIST_SPECIFIC_CONFIG[heistName].DisplayName))
            -- You might want to server hop here if a heist fails, or continue. For now, it continues.
        end
        
        if i < #ROB_ORDER and currentRobberyCoroutine then
            local waitTime = math.random(5,10) -- Random delay between heists
            print(string.format("[AutoRob] Waiting %.1fs before next heist...", waitTime))
            local waited = 0
            while waited < waitTime and currentRobberyCoroutine do
                task.wait(0.1)
                waited = waited + 0.1
            end
        end
    end
    
    if currentRobberyCoroutine then -- Only hop if not cancelled
        print(string.format("--- Full Auto-Robbery Sequence Completed in %.2f seconds. Initiating Server Hop. ---", tick() - startTime))
        ServerHop()
    end
    currentRobberyCoroutine = nil
end

-- ================= INITIALIZATION & AUTO-START =================
local autoStartEnabled = true -- ตั้งเป็น true เพื่อให้เริ่มปล้นอัตโนมัติ, false เพื่อเรียกใช้เอง

if autoStartEnabled then
    print("[AutoRob] Auto-start enabled. Waiting for character then starting sequence...")
    if waitForCharacter() then
        task.wait(5) -- รอสักครู่ให้เกมโหลดส่วนอื่นๆ
        if Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("RyntazHub_AutoRob_V2_6_4") then -- Check if our UI is still there (might be destroyed on TP)
             -- UI from previous script version, just using for reference if you have it.
        end
        print("[AutoRob] Starting robbery sequence now.")
        executeAllRobberiesSequence()
    else
        print("[AutoRob] Could not start: Character failed to load.")
    end
else
    print("[AutoRob] Auto-start disabled. Call 'executeAllRobberiesSequence()' manually via your executor.")
end


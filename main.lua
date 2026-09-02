-- [[ 🐯 TIGER DUMPER PRO: ULTIMATE EDITION (CYBER NEON) 🐾 ]]

local Players = game:GetService("Players")
local lp = Players.LocalPlayer or Players.PlayerAdded:Wait()

local function getMountRoot()
    local root = nil
    pcall(function()
        if typeof(gethui) == "function" then root = gethui() end
    end)
    if not root then
        pcall(function() root = lp:FindFirstChildOfClass("PlayerGui") end)
    end
    if not root then
        pcall(function() root = game:GetService("CoreGui") end)
    end
    return root
end

local safeRoot = getMountRoot()

pcall(function()
    if safeRoot:FindFirstChild("TigerRootGui") then safeRoot.TigerRootGui:Destroy() end
    if safeRoot:FindFirstChild("TigerPathPopup") then safeRoot.TigerPathPopup:Destroy() end
end)

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

local State = {
    WebhookUrl = "",
    Keywords = "egg,drop,plot,base,button,spawn,zone,crate,ore,chest,shop,upgrade,chicken,incubator,duck,lucky,block,ball,gate,portal"
}

-- ==================== DISCORD MULTIPART SENDER ====================
local function sendDiscordFile(fileName, content, titleMsg)
    if not State.WebhookUrl or State.WebhookUrl:gsub("%s+", "") == "" then 
        return false, "กรุณากรอก Webhook URL ก่อนกดส่ง" 
    end
    if not httpRequest then 
        return false, "Executor ไม่รองรับคำสั่ง HTTP Request" 
    end

    if #content < 5 then
        content = content .. "\n[!] ตรวจไม่พบข้อมูลที่ตรงกับเงื่อนไข"
    end

    local maxBytes = 3.5 * 1024 * 1024
    if #content > maxBytes then
        local parts = math.ceil(#content / maxBytes)
        for i = 1, parts do
            local s = (i - 1) * maxBytes + 1
            local e = math.min(i * maxBytes, #content)
            local chunk = content:sub(s, e)
            local partName = fileName:gsub("%.%w+$", "") .. "_part" .. i .. ".txt"
            sendDiscordFile(partName, chunk, string.format("%s [ส่วนที่ %d/%d]", titleMsg, i, parts))
            task.wait(1)
        end
        return true
    end

    local boundary = "----TigerBoundary" .. HttpService:GenerateGUID(false):gsub("-", "")
    local body = "--" .. boundary .. "\r\n"
        .. 'Content-Disposition: form-data; name="content"\r\n\r\n'
        .. (titleMsg or "📦 Tiger Dumper Export") .. "\r\n"
        .. "--" .. boundary .. "\r\n"
        .. 'Content-Disposition: form-data; name="file"; filename="' .. fileName .. '"\r\n'
        .. "Content-Type: text/plain\r\n\r\n"
        .. content .. "\r\n"
        .. "--" .. boundary .. "--\r\n"

    local ok, res = pcall(function()
        return httpRequest({
            Url = State.WebhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary },
            Body = body
        })
    end)

    if ok and res and (res.StatusCode == 200 or res.StatusCode == 204) then
        return true
    else
        return false, res and tostring(res.StatusCode) or "ส่งไม่สำเร็จ (ตรวจเช็ค URL หรืออินเทอร์เน็ต)"
    end
end

local function getSafeFullName(instance)
    if not instance then return "nil" end
    local ok, name = pcall(function() return instance:GetFullName() end)
    return ok and name or tostring(instance)
end

-- ==================== 5 SCANNING ENGINES ====================

-- 1. Hierarchy Engine
local function scanHierarchy()
    local dump = "=== 1. WORKSPACE HIERARCHY TREE DUMP ===\nPlace ID: " .. game.PlaceId .. "\nJob ID: " .. game.JobId .. "\nTime: " .. os.date("%X") .. "\n\n"
    local count = 0
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Folder") or obj:IsA("Model") then
            count = count + 1
            local children = obj:GetChildren()
            dump = dump .. string.format("[%s] %s (Children: %d)\n  Path: %s\n", obj.ClassName, obj.Name, #children, getSafeFullName(obj))
            for i = 1, math.min(#children, 6) do
                dump = dump .. string.format("  └─ [%s] %s\n", children[i].ClassName, children[i].Name)
            end
            dump = dump .. "\n"
        end
    end
    return dump, count
end

-- 2. Fast Target Finder (ดึง CFrame / Vector3 แบบไม่ค้าง)
local function scanTargets()
    local dump = "=== 2. SMART TARGET FINDER DUMP ===\nPlace ID: " .. game.PlaceId .. "\nTime: " .. os.date("%X") .. "\n\n"
    local count = 0
    local visited = {}
    local patterns = {}
    for kw in string.gmatch(State.Keywords:lower(), "([^,]+)") do
        table.insert(patterns, kw:gsub("^%s*(.-)%s*$", "%1"))
    end

    local function inspectObj(obj, tag)
        if not obj or visited[obj] then return end
        visited[obj] = true

        local nameLower = tostring(obj.Name):lower()
        local isMatch = false
        for _, pat in ipairs(patterns) do
            if string.find(nameLower, pat, 1, true) then
                isMatch = true
                break
            end
        end

        if not isMatch and obj:FindFirstChildWhichIsA("ProximityPrompt", true) then
            isMatch = true
            tag = tag .. " [Interactive Prompt]"
        end

        if isMatch then
            count = count + 1
            local posStr = "N/A"
            pcall(function()
                if obj:IsA("BasePart") then
                    posStr = string.format("Vector3.new(%.2f, %.2f, %.2f)", obj.Position.X, obj.Position.Y, obj.Position.Z)
                elseif obj:IsA("Model") then
                    local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if p then
                        posStr = string.format("Vector3.new(%.2f, %.2f, %.2f)", p.Position.X, p.Position.Y, p.Position.Z)
                    end
                end
            end)
            dump = dump .. string.format("[%s] %s (%s)\n  Path: %s\n  CFrame Position: %s\n\n", obj.ClassName, obj.Name, tag, getSafeFullName(obj), posStr)
        end
    end

    local topChildren = Workspace:GetChildren()
    for _, top in ipairs(topChildren) do
        inspectObj(top, "Main")
        if (top:IsA("Folder") or top:IsA("Model")) and count < 150 then
            local subChildren = top:GetChildren()
            for i = 1, math.min(#subChildren, 40) do
                inspectObj(subChildren[i], top.Name)
                if count >= 150 then break end
            end
        end
        if count >= 150 then break end
    end

    return dump, count
end

-- 3. Remotes Engine
local function scanRemotes()
    local dump = "=== 3. ALL REMOTES LIST ===\nPlace ID: " .. game.PlaceId .. "\nTime: " .. os.date("%X") .. "\n\n"
    local count = 0
    local searchPool = {ReplicatedStorage, Workspace}
    local ps = lp:FindFirstChildOfClass("PlayerScripts")
    if ps then table.insert(searchPool, ps) end

    for _, container in ipairs(searchPool) do
        if container then
            for _, obj in ipairs(container:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    count = count + 1
                    dump = dump .. string.format("[%s] %s\n  Path: %s\n\n", obj.ClassName, obj.Name, getSafeFullName(obj))
                end
            end
        end
    end
    return dump, count
end

-- 4. Player Stats Engine
local function scanStats()
    local dump = "=== 4. PLAYER STATS & ATTRIBUTES INSPECTION ===\nPlayer: " .. lp.Name .. " (User ID: " .. lp.UserId .. ")\n\n"
    local count = 0
    local containers = {"leaderstats", "Data", "Stats", "values", "PlayerData", "Currency", "PlayerStats"}

    for _, cName in ipairs(containers) do
        local f = lp:FindFirstChild(cName) or ReplicatedStorage:FindFirstChild(cName)
        if f then
            count = count + 1
            dump = dump .. string.format("📂 Container [%s]: %s\n", cName, getSafeFullName(f))
            for _, v in ipairs(f:GetChildren()) do
                if v:IsA("ValueBase") then
                    dump = dump .. string.format("  ├─ %s = %s (%s)\n", v.Name, tostring(v.Value), v.ClassName)
                end
            end
        end
    end

    if lp.Character then
        for _, v in ipairs(lp.Character:GetChildren()) do
            if v:IsA("ValueBase") then
                dump = dump .. string.format("  ├─ [CharacterValue] %s = %s\n", v.Name, tostring(v.Value))
            end
        end
    end

    for k, v in pairs(lp:GetAttributes()) do
        dump = dump .. string.format("  🏷️ LocalPlayer Attribute: %s = %s\n", tostring(k), tostring(v))
    end
    return dump, count
end

-- ==================== CYBER GUI INTERFACE ====================
local rootGui = Instance.new("ScreenGui")
rootGui.Name = "TigerRootGui"
rootGui.ResetOnSpawn = false
rootGui.DisplayOrder = 9999
rootGui.Parent = safeRoot

local function notify(msg)
    local pill = Instance.new("Frame")
    pill.Size = UDim2.fromOffset(280, 36)
    pill.Position = UDim2.new(0.5, -140, 0.06, 0)
    pill.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
    pill.BorderSizePixel = 0
    pill.Parent = rootGui
    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 10)
    
    local stroke = Instance.new("UIStroke", pill)
    stroke.Color = Color3.fromRGB(0, 255, 140)
    stroke.Thickness = 1.5

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -16, 1, 0)
    txt.Position = UDim2.fromOffset(8, 0)
    txt.Text = msg
    txt.TextColor3 = Color3.fromRGB(0, 255, 170)
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 12
    txt.BackgroundTransparency = 1
    txt.Parent = pill

    task.delay(2.6, function() pill:Destroy() end)
end

-- ==================== POP-UP UI FINDER (BUTTON 6) ====================
local popupConn = nil
local activePopup = nil

local function OpenUIFinder()
    if activePopup and activePopup.Parent then activePopup:Destroy() end
    if popupConn then popupConn:Disconnect(); popupConn = nil end

    local sg = Instance.new("ScreenGui")
    sg.Name = "TigerPathPopup"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 10000
    sg.Parent = safeRoot
    activePopup = sg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(320, 190)
    frame.Position = UDim2.new(0.5, -160, 0.28, 0)
    frame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(0, 255, 150)
    stroke.Thickness = 1.8

    local top = Instance.new("TextLabel")
    top.Size = UDim2.new(1, -35, 0, 26)
    top.Position = UDim2.fromOffset(12, 8)
    top.Text = "📋 แตะค้างเพื่อ Copy Path ตัวคูณ"
    top.TextColor3 = Color3.fromRGB(0, 255, 150)
    top.Font = Enum.Font.GothamBold
    top.TextSize = 12
    top.TextXAlignment = Enum.TextXAlignment.Left
    top.BackgroundTransparency = 1
    top.Parent = frame

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(26, 26)
    close.Position = UDim2.new(1, -32, 0, 8)
    close.Text = "✕"
    close.TextColor3 = Color3.fromRGB(255, 80, 80)
    close.TextSize = 14
    close.BackgroundTransparency = 1
    close.Font = Enum.Font.GothamBold
    close.Parent = frame
    close.MouseButton1Click:Connect(function()
        if popupConn then popupConn:Disconnect(); popupConn = nil end
        sg:Destroy()
    end)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -24, 0, 52)
    box.Position = UDim2.fromOffset(12, 40)
    box.Text = "กำลังตรวจจับ Path อัตโนมัติ..."
    box.TextColor3 = Color3.new(1, 1, 1)
    box.BackgroundColor3 = Color3.fromRGB(26, 30, 40)
    box.TextSize = 11
    box.Font = Enum.Font.Code
    box.ClearTextOnFocus = false
    box.TextWrapped = true
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local stat = Instance.new("TextLabel")
    stat.Size = UDim2.new(1, -24, 0, 36)
    stat.Position = UDim2.fromOffset(12, 98)
    stat.Text = "สถานะ: กำลังค้นหาป้ายหลักในเกม..."
    stat.TextColor3 = Color3.fromRGB(180, 190, 205)
    stat.TextSize = 11
    stat.Font = Enum.Font.Gotham
    stat.TextWrapped = true
    stat.BackgroundTransparency = 1
    stat.Parent = frame

    local reScan = Instance.new("TextButton")
    reScan.Size = UDim2.new(1, -24, 0, 34)
    reScan.Position = UDim2.fromOffset(12, 142)
    reScan.Text = "🔄 สแกนจับป้ายใหม่"
    reScan.BackgroundColor3 = Color3.fromRGB(0, 165, 95)
    reScan.TextColor3 = Color3.new(1, 1, 1)
    reScan.Font = Enum.Font.GothamBold
    reScan.TextSize = 12
    reScan.Parent = frame
    Instance.new("UICorner", reScan).CornerRadius = UDim.new(0, 6)

    local function runScan()
        if popupConn then popupConn:Disconnect(); popupConn = nil end
        local found = nil
        local scopes = {lp:FindFirstChildOfClass("PlayerGui"), Workspace}
        for _, root in ipairs(scopes) do
            if root then
                for _, obj in ipairs(root:GetDescendants()) do
                    if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and not obj:IsDescendantOf(sg) then
                        local t = tostring(obj.Text)
                        if string.find(t, "Multiplier") and not string.find(t, "dropped") and not string.find(t, "rose") then
                            found = obj
                            break
                        end
                    end
                end
            end
            if found then break end
        end

        if found then
            box.Text = found:GetFullName()
            stat.Text = "🎯 จับป้ายสำเร็จ: " .. found.Text
            popupConn = found:GetPropertyChangedSignal("Text"):Connect(function()
                local num = found.Text:match("%d+%.?%d*") or "N/A"
                stat.Text = "🔥 ค่าเปลี่ยนสด: " .. found.Text .. " (ตัวเลข: " .. num .. "x)"
            end)
        else
            box.Text = "หาไม่พบ ลองกดยืนใกล้ป้ายแล้วสแกนอีกรอบ"
            stat.Text = "❌ ไม่เจอป้ายตัวคูณหลัก"
        end
    end

    reScan.MouseButton1Click:Connect(runScan)
    task.spawn(runScan)
end

-- ==================== MAIN CYBER PANEL ====================
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(470, 340)
panel.Position = UDim2.new(0.5, -235, 0.5, -170)
panel.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
panel.BorderSizePixel = 0
panel.Parent = rootGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local pStroke = Instance.new("UIStroke", panel)
pStroke.Color = Color3.fromRGB(0, 255, 140)
pStroke.Thickness = 1.8

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundTransparency = 1
header.Parent = panel

local hTitle = Instance.new("TextLabel")
hTitle.Size = UDim2.new(1, -50, 1, 0)
hTitle.Position = UDim2.fromOffset(14, 0)
hTitle.Text = "🐯 TIGER DUMPER PRO <font color=\"rgb(0,255,150)\">v7.5 CYBER</font>"
hTitle.RichText = true
hTitle.TextColor3 = Color3.new(1, 1, 1)
hTitle.Font = Enum.Font.GothamBold
hTitle.TextSize = 13
hTitle.TextXAlignment = Enum.TextXAlignment.Left
hTitle.BackgroundTransparency = 1
hTitle.Parent = header

local hClose = Instance.new("TextButton")
hClose.Size = UDim2.fromOffset(32, 32)
hClose.Position = UDim2.new(1, -38, 0, 4)
hClose.Text = "✕"
hClose.TextColor3 = Color3.fromRGB(255, 85, 85)
hClose.BackgroundTransparency = 1
hClose.Font = Enum.Font.GothamBold
hClose.TextSize = 15
hClose.Parent = header
hClose.MouseButton1Click:Connect(function() panel.Visible = false end)

-- Scroll Area
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -50)
scroll.Position = UDim2.fromOffset(8, 42)
scroll.BackgroundColor3 = Color3.fromRGB(11, 13, 18)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.Parent = panel
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 8)

local sList = Instance.new("UIListLayout", scroll)
sList.Padding = UDim.new(0, 6)

-- Webhook Input
local urlBox = Instance.new("TextBox")
urlBox.Size = UDim2.new(1, -8, 0, 36)
urlBox.Position = UDim2.fromOffset(4, 0)
urlBox.BackgroundColor3 = Color3.fromRGB(20, 23, 32)
urlBox.PlaceholderText = "🔗 วาง Discord Webhook URL ที่นี่..."
urlBox.Text = State.WebhookUrl
urlBox.TextColor3 = Color3.fromRGB(0, 255, 150)
urlBox.Font = Enum.Font.Code
urlBox.TextSize = 10
urlBox.ClearTextOnFocus = false
urlBox.Parent = scroll
Instance.new("UICorner", urlBox).CornerRadius = UDim.new(0, 6)
local uStroke = Instance.new("UIStroke", urlBox)
uStroke.Color = Color3.fromRGB(35, 42, 58)
urlBox.FocusLost:Connect(function() State.WebhookUrl = urlBox.Text end)

local function buildButton(title, sub, color, cb)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 42)
    btn.Position = UDim2.fromOffset(4, 0)
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.Parent = scroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -12, 0, 18)
    tLbl.Position = UDim2.fromOffset(10, 4)
    tLbl.Text = title
    tLbl.TextColor3 = Color3.new(1, 1, 1)
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 11
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.BackgroundTransparency = 1
    tLbl.Parent = btn

    local sLbl = Instance.new("TextLabel")
    sLbl.Size = UDim2.new(1, -12, 0, 14)
    sLbl.Position = UDim2.fromOffset(10, 22)
    sLbl.Text = sub
    sLbl.TextColor3 = Color3.fromRGB(165, 175, 190)
    sLbl.Font = Enum.Font.Gotham
    sLbl.TextSize = 9
    sLbl.TextXAlignment = Enum.TextXAlignment.Left
    sLbl.BackgroundTransparency = 1
    sLbl.Parent = btn

    btn.MouseButton1Click:Connect(cb)
    return btn
end

-- ปุ่ม 1
buildButton("1. 🌳 ผังโครงสร้าง Workspace -> ส่ง Discord", "ดึงโฟลเดอร์สำคัญทั้งหมดในแมพ", Color3.fromRGB(0, 125, 70), function()
    task.spawn(function()
        local data, count = scanHierarchy()
        local ok, err = sendDiscordFile("WorkspaceSummary.txt", data, string.format("🌳 ผัง Workspace (%d โฟลเดอร์)", count))
        notify(ok and string.format("✅ ส่งผังแมพแล้ว (%d รายการ)", count) or "❌ " .. tostring(err))
    end)
end)

-- ปุ่ม 2
buildButton("2. 🎯 สแกนหาพิกัดเป้าหมาย (CFrame) -> ส่ง Discord", "สแกนหาจุดเกิด/จุดฟาร์ม ดึง Vector3 ทันที (ไม่ค้าง)", Color3.fromRGB(0, 125, 70), function()
    notify("⏳ กำลังสแกนพิกัด...")
    task.spawn(function()
        local data, count = scanTargets()
        local ok, err = sendDiscordFile("TargetFinder.txt", data, string.format("🎯 พิกัดเป้าหมาย (%d รายการ)", count))
        notify(ok and string.format("✅ ส่งพิกัดเป้าหมายแล้ว (%d ชิ้น)", count) or "❌ " .. tostring(err))
    end)
end)

-- ปุ่ม 3
buildButton("3. 🕵️ สแกน Remotes ทั้งหมดในเกม -> ส่ง Discord", "ดึง RemoteEvent/Function ทั้งหมดส่งเข้าช่อง", Color3.fromRGB(0, 125, 70), function()
    task.spawn(function()
        local data, count = scanRemotes()
        local ok, err = sendDiscordFile("RemoteList.txt", data, string.format("🕵️ รายชื่อ Remote (%d ชิ้น)", count))
        notify(ok and string.format("✅ ส่ง Remote แล้ว (%d ชิ้น)", count) or "❌ " .. tostring(err))
    end)
end)

-- ปุ่ม 4
buildButton("4. 📊 สแกน Player Stats & Attributes -> ส่ง Discord", "ดึงตัวแปร leaderstats, ค่าเงิน, ค่าสถานะตัวละคร", Color3.fromRGB(0, 125, 70), function()
    task.spawn(function()
        local data, count = scanStats()
        local ok, err = sendDiscordFile("PlayerStats.txt", data, "📊 Player Stats Dump")
        notify(ok and "✅ ส่งสถิติ Stats ผู้เล่นแล้ว" or "❌ " .. tostring(err))
    end)
end)

-- ปุ่ม 5
buildButton("5. 📦 All-In-One Master Dump -> ส่ง Discord ทันที", "รวบทั้ง ผังแมพ + พิกัดฟาร์ม + Stats + Remotes ส่งเป็นไฟล์เดียว", Color3.fromRGB(155, 45, 45), function()
    notify("⏳ กำลังรวบรวมไฟล์ Master Dump...")
    task.spawn(function()
        local sep = "\n" .. string.rep("=",

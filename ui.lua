--[[
    NovaUI  -  library UI ringan untuk Roblox
    ------------------------------------------------------------
    - 1 file, tanpa aset eksternal (tidak butuh getcustomasset / writefile)
    - API dibuat kompatibel dengan script Auto Fully:
        local Library = loadstring(game:HttpGet(".../ui.lua"))()
        local Window  = Library:Window({ Name = "...", SubTitle = "...", TimeRemaining = "..." })
        local Page    = Window:Page({ Columns = 2 })
        local Section = Page:Section({ Name = "...", Side = 1 })
        Section:Label("..."), Section:Toggle({...}), Section:Slider({...})
        Library:CreateSettingsPage(Window)
        Window.Items["TimeRemaining"].Instance
    - Fitur: drag, minimize, keybind buka/tutup, animasi tween,
      notifikasi, dropdown, keybind capture, textbox, config JSON.
]]

if getgenv().Library and type(getgenv().Library.Unload) == "function" then
    pcall(function()
        getgenv().Library:Unload()
    end)
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local gethui = gethui or function()
    return CoreGui
end

------------------------------------------------------------------
-- Tema
------------------------------------------------------------------
local Theme = {
    Background = Color3.fromRGB(11, 13, 17),
    Surface = Color3.fromRGB(18, 21, 27),
    Card = Color3.fromRGB(23, 27, 34),
    Stroke = Color3.fromRGB(38, 44, 54),
    Text = Color3.fromRGB(233, 237, 245),
    SubText = Color3.fromRGB(139, 148, 163),
    Accent = Color3.fromRGB(124, 164, 255),
    Accent2 = Color3.fromRGB(168, 128, 255),
    Good = Color3.fromRGB(112, 219, 160),
    Bad = Color3.fromRGB(255, 118, 128),
}

------------------------------------------------------------------
-- Font (pakai font bawaan Roblox, fallback ke enum)
------------------------------------------------------------------
local Fonts = {}
do
    local function build(weight)
        local ok, face = pcall(function()
            return Font.new("rbxasset://fonts/families/GothamSSm.json", weight)
        end)
        if ok then
            return face
        end
        return nil
    end

    Fonts.Regular = build(Enum.FontWeight.Regular)
    Fonts.Medium = build(Enum.FontWeight.Medium)
    Fonts.SemiBold = build(Enum.FontWeight.SemiBold)
    Fonts.Bold = build(Enum.FontWeight.Bold)
end

local function setFont(obj, weight)
    local face = Fonts[weight or "Medium"]
    if face then
        obj.FontFace = face
    else
        obj.Font = Enum.Font.GothamMedium
    end
    return obj
end

------------------------------------------------------------------
-- Helper
------------------------------------------------------------------
local function Create(class, props)
    local obj = Instance.new(class)
    local parent

    for key, value in pairs(props or {}) do
        if key == "Parent" then
            parent = value
        else
            obj[key] = value
        end
    end

    if parent then
        obj.Parent = parent
    end

    return obj
end

local function Corner(parent, radius)
    return Create("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(0, radius or 8),
    })
end

local function Stroke(parent, color, transparency)
    return Create("UIStroke", {
        Parent = parent,
        Color = color or Theme.Stroke,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local Connections = {}

local function Connect(signal, callback)
    local connection = signal:Connect(callback)
    Connections[#Connections + 1] = connection
    return connection
end

local Library = {
    Theme = Theme,
    Flags = {},
    SetFlags = {},
    Pages = {},
    AnimSpeed = 0.18,
    MenuKeybind = Enum.KeyCode.RightControl,
    Folder = "NovaUI",
}

Library.__index = Library

function Library:Tween(obj, props, time, style)
    local tween = TweenService:Create(obj, TweenInfo.new(
        time or self.AnimSpeed,
        style or Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    ), props)

    tween:Play()
    return tween
end

function Library:NextFlag()
    return "flag_" .. HttpService:GenerateGUID(false)
end

local function SetOpenState(obj, open, speed)
    Library:Tween(obj, { GroupTransparency = open and 0 or 1 }, speed)
end

------------------------------------------------------------------
-- Window
------------------------------------------------------------------
function Library:Window(Data)
    Data = Data or {}

    local Window = {
        Name = Data.Name or "Nova UI",
        SubTitle = Data.SubTitle or "interface",
        TimeRemaining = Data.TimeRemaining or 0,
        Pages = {},
        Items = {},
        IsOpen = true,
        Minimized = false,
        Width = 640,
        Height = 372,
    }

    Window.__index = Window
    setmetatable(Window, Window)

    local gui = Create("ScreenGui", {
        Name = "NovaUI",
        Parent = gethui(),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 50,
    })

    -- bayangan halus
    local shadow = Create("Frame", {
        Parent = gui,
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Size = UDim2.new(0, Window.Width, 0, Window.Height),
        Position = UDim2.new(0.5, 0, 0.5, 8),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 1,
    })
    Corner(shadow, 16)
    TweenService:Create(shadow, TweenInfo.new(0.6), { BackgroundTransparency = 0.7 }):Play()

    local root = Create("CanvasGroup", {
        Parent = gui,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Size = UDim2.new(0, Window.Width, 0, Window.Height),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ClipsDescendants = true,
        ZIndex = 2,
    })
    Corner(root, 14)
    Stroke(root, Theme.Stroke)

    -- garis aksen atas
    local accentLine = Create("Frame", {
        Parent = root,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 0),
        ZIndex = 3,
    })
    Create("UIGradient", {
        Parent = accentLine,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent),
            ColorSequenceKeypoint.new(0.5, Theme.Accent2),
            ColorSequenceKeypoint.new(1, Theme.Accent),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })

    -- header
    local header = Create("Frame", {
        Parent = root,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 54),
        Position = UDim2.new(0, 0, 0, 2),
        ZIndex = 3,
    })

    local title = Create("TextLabel", {
        Parent = header,
        BackgroundTransparency = 1,
        Text = Window.Name,
        TextColor3 = Theme.Text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 18, 0, 11),
        Size = UDim2.new(1, -180, 0, 18),
    })
    setFont(title, "Bold")

    local subtitle = Create("TextLabel", {
        Parent = header,
        BackgroundTransparency = 1,
        Text = string.upper(Window.SubTitle),
        TextColor3 = Theme.Accent,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 18, 0, 29),
        Size = UDim2.new(1, -180, 0, 14),
    })
    setFont(subtitle, "SemiBold")

    local timeLabel = Create("TextLabel", {
        Parent = header,
        BackgroundTransparency = 1,
        Text = "Time remaining: " .. tostring(Window.TimeRemaining),
        TextColor3 = Theme.SubText,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -62, 0, 22),
        Size = UDim2.new(0, 200, 0, 12),
        AutomaticSize = Enum.AutomaticSize.X,
    })
    setFont(timeLabel, "Medium")

    Window.Items["TimeRemaining"] = { Instance = timeLabel }
    Window.Items["MainFrame"] = { Instance = root }

    -- tombol minimize & close
    local function iconButton(glyph, x, color, callback)
        local btn = Create("TextButton", {
            Parent = header,
            BackgroundColor3 = Theme.Surface,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = glyph,
            TextColor3 = color,
            TextSize = 15,
            Size = UDim2.new(0, 22, 0, 22),
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, x, 0, 16),
            ZIndex = 4,
        })
        Corner(btn, 6)
        setFont(btn, "Bold")

        Connect(btn.MouseEnter, function()
            Library:Tween(btn, {
                BackgroundTransparency = 0,
                TextColor3 = Theme.Text,
            })
        end)
        Connect(btn.MouseLeave, function()
            Library:Tween(btn, {
                BackgroundTransparency = 1,
                TextColor3 = color,
            })
        end)
        Connect(btn.MouseButton1Click, callback)

        return btn
    end

    iconButton("X", -12, Theme.SubText, function()
        Library:Unload()
    end)

    local body = Create("Frame", {
        Parent = root,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 56),
        Size = UDim2.new(1, 0, 1, -56),
        ZIndex = 3,
    })

    -- tab bar
    local tabbar = Create("Frame", {
        Parent = body,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 38),
    })
    Create("UIListLayout", {
        Parent = tabbar,
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })
    Create("UIPadding", {
        Parent = tabbar,
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
    })

    Create("Frame", {
        Parent = body,
        BackgroundColor3 = Theme.Stroke,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -28, 0, 1),
        Position = UDim2.new(0, 14, 0, 38),
    })

    -- area konten
    local content = Create("Frame", {
        Parent = body,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 45),
        Size = UDim2.new(1, 0, 1, -45),
    })
    Create("UIPadding", {
        Parent = content,
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 0),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    })

    Window.Holder = gui
    Window.Root = root
    Window.Shadow = shadow
    Window.Body = body
    Window.Tabs = tabbar
    Window.Content = content
    Window.MinimizeButton = iconButton("-", -38, Theme.SubText, function()
        Window:Minimize()
    end)

    -- drag
    do
        local dragging, dragStart, startPos

        Connect(header.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = root.Position
            end
        end)

        Connect(UIS.InputChanged, function(input)
            if not dragging then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                local newPos = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
                root.Position = newPos
                shadow.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset, newPos.Y.Scale, newPos.Y.Offset + 8)
            end
        end)

        Connect(UIS.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    -- keybind buka / tutup
    Connect(UIS.InputBegan, function(input)
        if input.KeyCode == Library.MenuKeybind and not UIS:GetFocusedTextBox() then
            Window:SetOpen(not Window.IsOpen)
        end
    end)

    local function setShadow(open, speed)
        -- shadow itu Frame biasa, jadi pakai BackgroundTransparency
        -- (GroupTransparency cuma ada di CanvasGroup)
        Library:Tween(shadow, { BackgroundTransparency = open and 0.55 or 1 }, speed)
    end

    function Window:SetOpen(open)
        self.IsOpen = open
        if open then
            gui.Enabled = true
            SetOpenState(root, true, 0.2)
            setShadow(true, 0.2)
        else
            SetOpenState(root, false, 0.16)
            setShadow(false, 0.16)
            task.delay(0.2, function()
                if not self.IsOpen then
                    gui.Enabled = false
                end
            end)
        end
    end

    function Window:Minimize()
        self.Minimized = not self.Minimized

        if self.Minimized then
            Library:Tween(root, { Size = UDim2.new(0, self.Width, 0, 56) }, 0.22, Enum.EasingStyle.Quart)
            body.Visible = false
            shadow.Visible = false
        else
            Library:Tween(root, { Size = UDim2.new(0, self.Width, 0, self.Height) }, 0.22, Enum.EasingStyle.Quart)
            body.Visible = true
            shadow.Visible = true
        end
    end

    function Window:Notify(Title, Text, Duration)
        return Library:Notify(Title, Text, Duration)
    end

    -- Window:Page(...) -> Library:Page(Window, ...)
    function Window:Page(Data)
        return Library:Page(self, Data)
    end

    Library.Window = Window
    return Window
end

------------------------------------------------------------------
-- Page
------------------------------------------------------------------
-- dideklarasikan di depan supaya Page:Section bisa memakai metatable-nya
local SectionMeta = {}

function Library:Page(Window, Data)
    Data = Data or {}

    local Page = {
        Window = Window,
        Name = Data.Name or (#Window.Pages == 0 and "Main" or ("Page " .. tostring(#Window.Pages + 1))),
        Columns = math.clamp(tonumber(Data.Columns) or 1, 1, 3),
        Sections = {},
        Active = false,
    }
    Page.__index = Page
    setmetatable(Page, Page)

    -- tombol tab
    local tab = Create("TextButton", {
        Parent = Window.Tabs,
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.new(0, 0, 0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 4,
    })
    Corner(tab, 8)

    Create("UIPadding", {
        Parent = tab,
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    })

    local tabLabel = Create("TextLabel", {
        Parent = tab,
        BackgroundTransparency = 1,
        Text = Page.Name,
        TextColor3 = Theme.SubText,
        TextSize = 12,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 4,
    })
    setFont(tabLabel, "Medium")

    -- konten
    local container = Create("Frame", {
        Parent = Window.Content,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Visible = false,
        ZIndex = 3,
    })

    local columnList = {}

    -- kolom fleksibel: 1, 2, atau 3 (Side = 1..3)
    local count = Page.Columns
    local gap = 10
    local columnScale = 1 / count
    local columnOffset = -(gap * (count - 1) / count)

    for index = 1, count do
        local column = Create("ScrollingFrame", {
            Parent = container,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Stroke,
            ScrollBarImageTransparency = 0.4,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(columnScale, columnOffset, 1, 0),
            Position = UDim2.new(columnScale * (index - 1), (index - 1) * (gap / count), 0, 0),
            ZIndex = 3,
        })
        Create("UIListLayout", {
            Parent = column,
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        Create("UIPadding", {
            Parent = column,
            PaddingTop = UDim.new(0, 6),
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 8),
        })

        columnList[index] = column
    end

    -- 3 kolom butuh window lebih lebar biar nggak sempit
    if count >= 3 and Window.Root then
        Window.Width = 820
        Window.Height = 400
        Library:Tween(Window.Root, { Size = UDim2.new(0, Window.Width, 0, Window.Height) }, 0.22, Enum.EasingStyle.Quart)
        Library:Tween(Window.Shadow, { Size = UDim2.new(0, Window.Width, 0, Window.Height) }, 0.22, Enum.EasingStyle.Quart)
    end

    Page.Container = container
    Page.ColumnList = columnList

    local function activate(state)
        Page.Active = state
        container.Visible = state

        if state then
            Library:Tween(tab, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Surface }, 0.15)
            Library:Tween(tabLabel, { TextColor3 = Theme.Text }, 0.15)
        else
            Library:Tween(tab, { BackgroundTransparency = 1 }, 0.15)
            Library:Tween(tabLabel, { TextColor3 = Theme.SubText }, 0.15)
        end
    end

    Connect(tab.MouseButton1Click, function()
        for _, other in ipairs(Window.Pages) do
            if other ~= Page then
                other:Activate(false)
            end
        end
        activate(true)
    end)

    function Page:Activate(state)
        activate(state)
    end

    function Page:Section(Data2)
        Data2 = Data2 or {}

        local side = math.clamp(tonumber(Data2.Side) or 1, 1, Page.Columns)
        local column = columnList[side]

        local Section = {
            Page = Page,
            Window = Window,
            Name = Data2.Name or "Section",
            Side = side,
        }
        Section.__index = SectionMeta
        setmetatable(Section, Section)

        local card = Create("Frame", {
            Parent = column,
            BackgroundColor3 = Theme.Card,
            BackgroundTransparency = 0.1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 3,
        })
        Corner(card, 10)
        Stroke(card, Theme.Stroke)

        Create("UIPadding", {
            Parent = card,
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
        })

        Create("TextLabel", {
            Parent = card,
            BackgroundTransparency = 1,
            Text = Data2.Name or "Section",
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 16),
            ZIndex = 3,
        })
        do
            local headerLabel = card:FindFirstChildOfClass("TextLabel")
            if headerLabel then
                setFont(headerLabel, "SemiBold")
            end
        end

        local accent = Create("Frame", {
            Parent = card,
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 16, 0, 2),
            Position = UDim2.new(0, 0, 0, 20),
            ZIndex = 3,
        })
        Corner(accent, 2)
        Create("UIGradient", {
            Parent = accent,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Theme.Accent),
                ColorSequenceKeypoint.new(1, Theme.Accent2),
            }),
        })

        local contentFrame = Create("Frame", {
            Parent = card,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 28),
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 3,
        })
        Create("UIListLayout", {
            Parent = contentFrame,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        Section.Card = card
        Section.Content = contentFrame

        return Section
    end

    Window.Pages[#Window.Pages + 1] = Page

    if #Window.Pages == 1 then
        activate(true)
    end

    return Page
end

------------------------------------------------------------------
-- Elemen
------------------------------------------------------------------
local function Row(parent, height)
    local row = Create("TextButton", {
        Parent = parent,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or 26),
        ZIndex = 3,
    })
    return row
end

local function RowText(row, text, widthOffset)
    local label = Create("TextLabel", {
        Parent = row,
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(1, -(widthOffset or 60), 1, 0),
        ZIndex = 3,
    })
    setFont(label, "Medium")
    return label
end

SectionMeta.__index = SectionMeta

function SectionMeta:Label(Text)
    local row = Row(self.Content, 18)
    local label = RowText(row, tostring(Text), 0)
    label.TextColor3 = Theme.SubText
    label.TextSize = 11

    local api = { Instance = label }

    function api:SetText(value)
        label.Text = tostring(value)
    end

    function api:SetColor(color)
        label.TextColor3 = color
    end

    return api
end

function SectionMeta:Paragraph(Text)
    local frame = Create("Frame", {
        Parent = self.Content,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
    })

    local label = Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Text = tostring(Text),
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
    })
    setFont(label, "Regular")

    return {
        Instance = label,
        SetText = function(_, value)
            label.Text = tostring(value)
        end,
    }
end

function SectionMeta:Divider()
    local line = Create("Frame", {
        Parent = self.Content,
        BackgroundColor3 = Theme.Stroke,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 3,
    })
    return { Instance = line }
end

function SectionMeta:Toggle(Data)
    Data = Data or {}

    local flag = Data.Flag or Library:NextFlag()
    local state = Data.Default == true

    local row = Row(self.Content, 26)
    RowText(row, Data.Name or "Toggle", 52)

    local switch = Create("Frame", {
        Parent = row,
        BackgroundColor3 = state and Theme.Accent or Theme.Stroke,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 34, 0, 18),
        ZIndex = 3,
    })
    Corner(switch, 9)

    local knob = Create("Frame", {
        Parent = switch,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, state and 18 or 2, 0.5, -7),
        ZIndex = 4,
    })
    Corner(knob, 7)

    local api = { Value = state }

    local function render(value, animated)
        state = value
        api.Value = value
        Library.Flags[flag] = value

        local target = UDim2.new(0, value and 18 or 2, 0.5, -7)
        if animated then
            Library:Tween(knob, { Position = target }, 0.16, Enum.EasingStyle.Quart)
            Library:Tween(switch, { BackgroundColor3 = value and Theme.Accent or Theme.Stroke }, 0.16)
        else
            knob.Position = target
            switch.BackgroundColor3 = value and Theme.Accent or Theme.Stroke
        end
    end

    function api:Set(value)
        render(value == true, true)
    end

    Connect(row.MouseButton1Click, function()
        render(not state, true)
        if Data.Callback then
            task.spawn(Data.Callback, state)
        end
    end)

    Library.SetFlags[flag] = function(value)
        api:Set(value == true)
    end

    render(state, false)
    return api
end

function SectionMeta:Slider(Data)
    Data = Data or {}

    local flag = Data.Flag or Library:NextFlag()
    local minValue = tonumber(Data.Min) or 0
    local maxValue = tonumber(Data.Max) or 100
    local decimals = tonumber(Data.Decimals) or 0
    local value = math.clamp(tonumber(Data.Default) or minValue, minValue, maxValue)
    local suffix = Data.Suffix or ""

    local holder = Create("Frame", {
        Parent = self.Content,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 38),
        ZIndex = 3,
    })

    local nameLabel = Create("TextLabel", {
        Parent = holder,
        BackgroundTransparency = 1,
        Text = Data.Name or "Slider",
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -60, 0, 16),
        ZIndex = 3,
    })
    setFont(nameLabel, "Medium")

    local valueLabel = Create("TextLabel", {
        Parent = holder,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        Size = UDim2.new(0, 60, 0, 16),
        Position = UDim2.new(1, -60, 0, 0),
        ZIndex = 3,
    })
    setFont(valueLabel, "SemiBold")

    local track = Create("TextButton", {
        Parent = holder,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 24),
        Size = UDim2.new(1, 0, 0, 14),
        ZIndex = 3,
    })

    local bar = Create("Frame", {
        Parent = track,
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 4),
        ZIndex = 3,
    })
    Corner(bar, 2)

    local fill = Create("Frame", {
        Parent = bar,
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        ZIndex = 4,
    })
    Corner(fill, 2)
    Create("UIGradient", {
        Parent = fill,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent),
            ColorSequenceKeypoint.new(1, Theme.Accent2),
        }),
    })

    local knob = Create("Frame", {
        Parent = bar,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12),
        ZIndex = 5,
    })
    Corner(knob, 6)
    Stroke(knob, Theme.Background, 0.3)

    local api = { Value = value }

    local function format(number)
        if decimals <= 0 then
            return tostring(math.floor(number + 0.5))
        end
        return string.format("%." .. tostring(decimals) .. "f", number)
    end

    local function render(newValue, silent)
        value = math.clamp(newValue, minValue, maxValue)
        api.Value = value
        Library.Flags[flag] = value

        local alpha = (maxValue - minValue) > 0 and (value - minValue) / (maxValue - minValue) or 0
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = format(value) .. suffix

        if not silent and Data.Callback then
            task.spawn(Data.Callback, value)
        end
    end

    local dragging = false

    local function updateFromInput(input)
        local relative = (input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
        relative = math.clamp(relative, 0, 1)
        local raw = minValue + (maxValue - minValue) * relative
        if decimals > 0 then
            local multiplier = 10 ^ decimals
            raw = math.floor(raw * multiplier + 0.5) / multiplier
        else
            raw = math.floor(raw + 0.5)
        end
        render(raw, false)
    end

    Connect(track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromInput(input)
        end
    end)

    Connect(UIS.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input)
        end
    end)

    Connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    function api:Set(newValue)
        render(tonumber(newValue) or minValue, true)
    end

    Library.SetFlags[flag] = function(newValue)
        api:Set(newValue)
    end

    render(value, true)
    return api
end

function SectionMeta:Button(Data)
    Data = Data or {}

    local button = Create("TextButton", {
        Parent = self.Content,
        BackgroundColor3 = Theme.Surface,
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 28),
        ZIndex = 3,
    })
    Corner(button, 7)
    Stroke(button, Theme.Stroke)

    local fillGradient = Create("UIGradient", {
        Parent = button,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent),
            ColorSequenceKeypoint.new(1, Theme.Accent2),
        }),
        Transparency = NumberSequence.new(1),
    })

    local label = Create("TextLabel", {
        Parent = button,
        BackgroundTransparency = 1,
        Text = Data.Name or "Button",
        TextColor3 = Theme.Text,
        TextSize = 12,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 4,
    })
    setFont(label, "SemiBold")

    Connect(button.MouseEnter, function()
        Library:Tween(button, { BackgroundColor3 = Theme.Card }, 0.15)
    end)

    Connect(button.MouseLeave, function()
        Library:Tween(button, { BackgroundColor3 = Theme.Surface }, 0.15)
    end)

    Connect(button.MouseButton1Click, function()
        if Data.Callback then
            task.spawn(Data.Callback)
        end
    end)

    return { Instance = button }
end

function SectionMeta:Dropdown(Data)
    Data = Data or {}

    local flag = Data.Flag or Library:NextFlag()
    local options = Data.Options or {}
    local value = Data.Default or options[1] or ""

    local holder = Create("Frame", {
        Parent = self.Content,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 32),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
    })

    local header = Create("TextButton", {
        Parent = holder,
        BackgroundColor3 = Theme.Surface,
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 28),
        ZIndex = 3,
    })
    Corner(header, 7)
    Stroke(header, Theme.Stroke)

    local nameLabel = Create("TextLabel", {
        Parent = header,
        BackgroundTransparency = 1,
        Text = Data.Name or "Dropdown",
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -70, 1, 0),
        ZIndex = 4,
    })
    setFont(nameLabel, "Medium")

    local valueLabel = Create("TextLabel", {
        Parent = header,
        BackgroundTransparency = 1,
        Text = tostring(value),
        TextColor3 = Theme.Accent,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -24, 0, 0),
        Size = UDim2.new(0, 100, 1, 0),
        ZIndex = 4,
    })
    setFont(valueLabel, "SemiBold")

    local chevron = Create("TextLabel", {
        Parent = header,
        BackgroundTransparency = 1,
        Text = "v",
        TextColor3 = Theme.SubText,
        TextSize = 12,
        Position = UDim2.new(1, -16, 0, 0),
        Size = UDim2.new(0, 16, 1, 0),
        ZIndex = 4,
    })
    setFont(chevron, "Bold")

    local list = Create("Frame", {
        Parent = holder,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 32),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 3,
    })
    Create("UIListLayout", {
        Parent = list,
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    Create("UIPadding", {
        Parent = list,
        PaddingTop = UDim.new(0, 4),
    })

    local api = { Value = value }

    local function choose(option, silent)
        value = option
        api.Value = option
        valueLabel.Text = tostring(option)
        Library.Flags[flag] = option

        if not silent and Data.Callback then
            task.spawn(Data.Callback, option)
        end
    end

    local optionButtons = {}

    for index, option in ipairs(options) do
        local optionButton = Create("TextButton", {
            Parent = list,
            BackgroundColor3 = Theme.Surface,
            BackgroundTransparency = 0.35,
            AutoButtonColor = false,
            Text = tostring(option),
            TextColor3 = Theme.SubText,
            TextSize = 11,
            Size = UDim2.new(1, 0, 0, 24),
            ZIndex = 3,
        })
        setFont(optionButton, "Medium")
        Corner(optionButton, 6)

        Connect(optionButton.MouseEnter, function()
            Library:Tween(optionButton, { BackgroundTransparency = 0.1, TextColor3 = Theme.Text }, 0.12)
        end)
        Connect(optionButton.MouseLeave, function()
            Library:Tween(optionButton, { BackgroundTransparency = 0.35, TextColor3 = Theme.SubText }, 0.12)
        end)
        Connect(optionButton.MouseButton1Click, function()
            choose(option, false)
            list.Visible = false
            chevron.Text = "v"
        end)

        optionButtons[index] = optionButton
    end

    Connect(header.MouseButton1Click, function()
        list.Visible = not list.Visible
        chevron.Text = list.Visible and "^" or "v"
    end)

    function api:Set(newValue)
        if table.find(options, newValue) then
            choose(newValue, true)
        end
    end

    Library.SetFlags[flag] = function(newValue)
        api:Set(newValue)
    end

    choose(value, true)
    return api
end

function SectionMeta:Keybind(Data)
    Data = Data or {}

    local flag = Data.Flag or Library:NextFlag()
    local current = Data.Default or Enum.KeyCode.RightControl

    local row = Row(self.Content, 26)
    RowText(row, Data.Name or "Keybind", 96)

    local keyButton = Create("TextButton", {
        Parent = row,
        BackgroundColor3 = Theme.Surface,
        AutoButtonColor = false,
        Text = tostring(current):gsub("Enum.KeyCode.", ""),
        TextColor3 = Theme.SubText,
        TextSize = 11,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 84, 0, 22),
        ZIndex = 3,
    })
    setFont(keyButton, "SemiBold")
    Corner(keyButton, 6)
    Stroke(keyButton, Theme.Stroke)

    local api = { Key = current }
    local picking = false

    local function render(key)
        current = key
        api.Key = key
        keyButton.Text = tostring(key):gsub("Enum.KeyCode.", "")
        Library.Flags[flag] = { Key = key }
    end

    Connect(keyButton.MouseButton1Click, function()
        picking = true
        keyButton.Text = "..."
        keyButton.TextColor3 = Theme.Accent
    end)

    Connect(UIS.InputBegan, function(input)
        if not picking then
            return
        end

        if input.UserInputType == Enum.UserInputType.Keyboard then
            picking = false
            keyButton.TextColor3 = Theme.SubText
            render(input.KeyCode)

            if Data.Callback then
                task.spawn(Data.Callback, input.KeyCode)
            end
        end
    end)

    Library.SetFlags[flag] = function(newValue)
        if type(newValue) == "table" and newValue.Key then
            render(newValue.Key)
        elseif typeof(newValue) == "EnumItem" then
            render(newValue)
        end
    end

    render(current)
    return api
end

function SectionMeta:Input(Data)
    Data = Data or {}

    local flag = Data.Flag or Library:NextFlag()

    local row = Row(self.Content, 52)
    local nameLabel = RowText(row, Data.Name or "Input", 0)
    nameLabel.Size = UDim2.new(1, 0, 0, 14)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)

    local box = Create("TextBox", {
        Parent = row,
        BackgroundColor3 = Theme.Surface,
        Text = Data.Default or "",
        PlaceholderText = Data.Placeholder or "type here...",
        PlaceholderColor3 = Theme.SubText,
        TextColor3 = Theme.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Position = UDim2.new(0, 0, 0, 22),
        Size = UDim2.new(1, 0, 0, 26),
        ZIndex = 3,
    })
    setFont(box, "Medium")
    Corner(box, 7)
    Stroke(box, Theme.Stroke)
    Create("UIPadding", {
        Parent = box,
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    })

    Library.Flags[flag] = box.Text

    Connect(box.FocusLost, function(enterPressed)
        Library.Flags[flag] = box.Text
        if Data.Callback then
            task.spawn(Data.Callback, box.Text, enterPressed)
        end
    end)

    Library.SetFlags[flag] = function(newValue)
        box.Text = tostring(newValue)
        Library.Flags[flag] = box.Text
    end

    return { Instance = box }
end

------------------------------------------------------------------
-- Settings page bawaan
------------------------------------------------------------------
function Library:CreateSettingsPage(Window)
    local page = Window:Page({ Name = "Settings", Columns = 1 })

    local menuSection = page:Section({ Name = "Menu", Side = 1 })
    menuSection:Keybind({
        Name = "Menu Keybind",
        Flag = "Menu Keybind",
        Default = self.MenuKeybind,
        Callback = function(key)
            Library.MenuKeybind = key
        end,
    })
    menuSection:Button({
        Name = "Unload Interface",
        Callback = function()
            Library:Unload()
        end,
    })

    local uiSection = page:Section({ Name = "Interface", Side = 1 })
    uiSection:Slider({
        Name = "Animation Speed",
        Default = self.AnimSpeed,
        Min = 0.04,
        Max = 0.5,
        Decimals = 2,
        Suffix = "s",
        Callback = function(value)
            Library.AnimSpeed = value
        end,
    })
    uiSection:Dropdown({
        Name = "Menu Keybind Preset",
        Options = { "RightControl", "LeftControl", "RightShift", "Insert", "K" },
        Default = "RightControl",
        Callback = function(value)
            Library.MenuKeybind = Enum.KeyCode[value] or Library.MenuKeybind
        end,
    })

    local infoSection = page:Section({ Name = "Info", Side = 1 })
    infoSection:Paragraph("NovaUI - ringan, tanpa aset eksternal. Tekan keybind untuk buka/tutup, tombol - untuk minimize.")

    return page
end

------------------------------------------------------------------
-- Notifikasi
------------------------------------------------------------------
function Library:Notify(Title, Text, Duration)
    local Window = self.Window
    if not Window or not Window.Holder then
        return
    end

    if not self.NotifHolder then
        local holder = Create("Frame", {
            Parent = Window.Holder,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -14, 0, 14),
            Size = UDim2.new(0, 250, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 20,
        })
        Create("UIListLayout", {
            Parent = holder,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
        })
        self.NotifHolder = holder
    end

    local toast = Create("CanvasGroup", {
        Parent = self.NotifHolder,
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 52),
        GroupTransparency = 1,
        ZIndex = 21,
    })
    Corner(toast, 9)
    Stroke(toast, Theme.Stroke)

    local bar = Create("Frame", {
        Parent = toast,
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, -16),
        Position = UDim2.new(0, 8, 0, 8),
        ZIndex = 22,
    })
    Corner(bar, 2)
    Create("UIGradient", {
        Parent = bar,
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent),
            ColorSequenceKeypoint.new(1, Theme.Accent2),
        }),
    })

    local titleLabel = Create("TextLabel", {
        Parent = toast,
        BackgroundTransparency = 1,
        Text = tostring(Title or "Info"),
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 18, 0, 8),
        Size = UDim2.new(1, -28, 0, 14),
        ZIndex = 22,
    })
    setFont(titleLabel, "SemiBold")

    local textLabel = Create("TextLabel", {
        Parent = toast,
        BackgroundTransparency = 1,
        Text = tostring(Text or ""),
        TextColor3 = Theme.SubText,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Position = UDim2.new(0, 18, 0, 24),
        Size = UDim2.new(1, -28, 1, -28),
        ZIndex = 22,
    })
    setFont(textLabel, "Regular")

    Library:Tween(toast, { GroupTransparency = 0 }, 0.18)
    Library:Tween(toast, { Size = UDim2.new(1, 0, 0, 54) }, 0.2)

    task.delay(Duration or 4, function()
        if not toast.Parent then
            return
        end
        Library:Tween(toast, { GroupTransparency = 1 }, 0.18)
        task.wait(0.2)
        toast:Destroy()
    end)

    return toast
end

------------------------------------------------------------------
-- Config
------------------------------------------------------------------
local function configPath(name)
    return "NovaUI/Configs/" .. tostring(name) .. ".json"
end

function Library:GetConfig()
    return HttpService:JSONEncode(self.Flags)
end

function Library:SaveConfig(name)
    if typeof(writefile) ~= "function" then
        return self:Notify("Config", "Executor tidak mendukung writefile.", 3)
    end

    if typeof(isfolder) == "function" and not isfolder("NovaUI/Configs") then
        if typeof(makefolder) == "function" then
            pcall(makefolder, "NovaUI")
            pcall(makefolder, "NovaUI/Configs")
        end
    end

    writefile(configPath(name), self:GetConfig())
    self:Notify("Config", "Disimpan: " .. tostring(name), 2)
end

function Library:LoadConfig(name)
    if typeof(isfile) ~= "function" or not isfile(configPath(name)) then
        return self:Notify("Config", "Config tidak ditemukan.", 3)
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(configPath(name)))
    end)

    if not ok or type(data) ~= "table" then
        return self:Notify("Config", "Config rusak / gagal dibaca.", 3)
    end

    for flag, value in pairs(data) do
        local setter = self.SetFlags[flag]
        if setter then
            pcall(setter, value)
        end
    end

    self:Notify("Config", "Dimuat: " .. tostring(name), 2)
end

------------------------------------------------------------------
-- Unload
------------------------------------------------------------------
function Library:Unload()
    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(Connections)

    if self.Window and self.Window.Holder then
        pcall(function()
            self.Window.Holder:Destroy()
        end)
    end

    self.Window = nil
    getgenv().Library = nil
end

getgenv().Library = Library
return Library

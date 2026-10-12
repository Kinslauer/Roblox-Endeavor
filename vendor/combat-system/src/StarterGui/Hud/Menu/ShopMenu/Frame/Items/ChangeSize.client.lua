local frame = script.Parent
local gridLayout = frame.UIGridLayout

local PADDING = Vector2.new(0.05, 0)
local SIZE = Vector2.new(0.25, 0.25)

frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    local AbsoluteSize = frame.AbsoluteSize

    local NewPadding = PADDING * AbsoluteSize
    NewPadding = UDim2.new(0, NewPadding .X, 0, NewPadding .Y)
    local NewSize = SIZE * AbsoluteSize
    NewSize = UDim2.new(0, NewSize.X, 0, NewSize.Y)

    gridLayout.CellPadding = NewPadding
    gridLayout.CellSize = NewSize
end)

script.Parent.ChildAdded:Connect(function()
	if #frame:GetChildren() % 15 == 0 then
		frame.CanvasSize = frame.CanvasSize + UDim2.new(0,0,1,0)
	end
end)

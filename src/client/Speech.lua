-- How a conduit sounds (design/gdd/cybernetics.md §6). A body that is 100% metal has lost its humanity and no
-- longer speaks the way it did (owner, 2026-10-28): the server flags the player (attribute Machine,
-- server/Gear.lua Gear.Push) and every client, this one included, renders that player's chat through
-- Voice.Machine - flat capitals, no laughter, no feeling - with a cold name colour and a terminal-style bubble.
-- Rip one piece back out and the voice comes back. Display only: the words were already filtered by Roblox,
-- this only reshapes them. Rides TextChatService's callbacks; Roblox retired legacy chat (April 2025) and
-- moves experiences over by itself, and ChatVersion is deprecated, so the hooks go in whatever it says - under
-- legacy chat they simply never fire (owner s24: "chat version is deprecated").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Presentation = require(Shared:WaitForChild("Presentation"))
local Voice = require(Shared:WaitForChild("Voice"))
local P = Presentation.Voice

local Speech = {}

local function speaker(message)
	local source = message.TextSource
	return source and Players:GetPlayerByUserId(source.UserId)
end

local function isMachine(message)
	local p = speaker(message)
	return p ~= nil and p:GetAttribute("Machine") == true
end

function Speech.Init()
	local ok, version = pcall(function()
		return TextChatService.ChatVersion
	end)
	if ok and version ~= Enum.ChatVersion.TextChatService then
		warn("[Speech] this place still reports legacy chat; the machine voice shows once Roblox moves it to TextChatService")
	end
	TextChatService.OnIncomingMessage = function(message)
		-- only the delivered (filtered, escaped) text; the local "Sending" echo is raw and gets replaced anyway
		if message.Status ~= Enum.TextChatMessageStatus.Success or not isMachine(message) then
			return nil
		end
		local props = Instance.new("TextChatMessageProperties")
		props.Text = ('<font color="%s">%s</font>'):format(P.TextColor, Voice.Machine(message.Text))
		props.PrefixText = ('<font color="%s">%s</font>'):format(P.NameColor, message.PrefixText)
		return props
	end
	TextChatService.OnBubbleAdded = function(message)
		if not isMachine(message) then
			return nil
		end
		local props = Instance.new("BubbleChatMessageProperties")
		props.TextColor3 = P.BubbleText
		props.BackgroundColor3 = P.BubbleBackground
		props.FontFace = Font.fromEnum(P.BubbleFont)
		return props
	end
end

return Speech

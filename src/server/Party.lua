-- Parties (round 6 of docs/Reference-Picks-Plan.md; Andy: names up close only, no markers through walls). Up to
-- Config.World.Party.Max conduits. Members cannot hurt each other (Combat.applyDamage asks Party.Allies), a kill
-- counts toward every nearby member's contracts (server/Terminal), and each member's screen lists the others'
-- health (client/Party.lua reads the player attribute "Party" = the leader's UserId and the members' Humanoids).
-- Remote "Party"(action, arg): Invite <userId>, Accept <leaderUserId>, Decline, Leave.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Net = require(script.Parent.Common.Net)

local P = Config.World.Party
local Party = {}
local parties = {} -- leader userId -> { leader = player, members = { player } }
local invites = {} -- invited player -> { from = leader player, at = os.clock() }

local function say(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Info")
end

function Party.Of(player)
	local id = player:GetAttribute("Party")
	return id and parties[id]
end

function Party.Members(player)
	local p = Party.Of(player)
	return if p then table.clone(p.members) else { player }
end

function Party.Allies(a, b)
	if a == b then
		return false
	end
	local pa, pb = a:GetAttribute("Party"), b:GetAttribute("Party")
	return pa ~= nil and pa == pb
end

local function push(p)
	local ids = {}
	for _, m in p.members do
		table.insert(ids, m.UserId)
	end
	for _, m in p.members do
		Remotes.World:FireClient(m, "Party", ids, p.leader.UserId)
	end
end

local function remove(player)
	local p = Party.Of(player)
	player:SetAttribute("Party", nil)
	if not p then
		return
	end
	local i = table.find(p.members, player)
	if i then
		table.remove(p.members, i)
	end
	Remotes.World:FireClient(player, "Party", {}, nil)
	if #p.members <= 1 then
		-- a party of one is no party
		for _, m in p.members do
			m:SetAttribute("Party", nil)
			Remotes.World:FireClient(m, "Party", {}, nil)
		end
		parties[p.leader.UserId] = nil
		return
	end
	if p.leader == player then
		-- the next member leads; the party keeps its members under the new id
		parties[player.UserId] = nil
		p.leader = p.members[1]
		parties[p.leader.UserId] = p
		for _, m in p.members do
			m:SetAttribute("Party", p.leader.UserId)
		end
	end
	push(p)
end

function Party.Invite(player, targetId)
	local target = Players:GetPlayerByUserId(tonumber(targetId) or 0)
	if not target or target == player then
		return false
	end
	local a, b = player.Character and player.Character:FindFirstChild("HumanoidRootPart"), target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not (a and b) or (a.Position - b.Position).Magnitude > P.InviteReach then
		return false -- you invite someone standing with you
	end
	local p = Party.Of(player)
	if p and p.leader ~= player then
		return false
	end
	if p and #p.members >= P.Max then
		say(player, "> PARTY . FULL", "Warning")
		return false
	end
	if Party.Of(target) then
		return false
	end
	invites[target] = { from = player, at = os.clock() }
	Remotes.World:FireClient(target, "PartyInvite", player.UserId, player.DisplayName)
	say(player, "> PARTY . ASKED " .. string.upper(target.DisplayName), "Info")
	return true
end

function Party.Accept(player, leaderId)
	local inv = invites[player]
	invites[player] = nil
	if not inv or os.clock() - inv.at > P.InviteSeconds or not inv.from.Parent then
		return false
	end
	if leaderId ~= nil and tonumber(leaderId) ~= inv.from.UserId then
		return false
	end
	if Party.Of(player) then
		remove(player)
	end
	local leader = inv.from
	local p = Party.Of(leader)
	if not p then
		p = { leader = leader, members = { leader } }
		parties[leader.UserId] = p
		leader:SetAttribute("Party", leader.UserId)
	end
	if #p.members >= P.Max then
		return false
	end
	table.insert(p.members, player)
	player:SetAttribute("Party", leader.UserId)
	push(p)
	return true
end

function Party.Decline(player)
	invites[player] = nil
	return true
end

function Party.Leave(player)
	remove(player)
	return true
end

function Party.Init()
	Net.On("Party", { rate = 3, burst = 5, args = { "string", "string?" } }, function(player, action, arg)
		if action == "Invite" then
			Party.Invite(player, arg)
		elseif action == "Accept" then
			Party.Accept(player, arg)
		elseif action == "Decline" then
			Party.Decline(player)
		elseif action == "Leave" then
			Party.Leave(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		remove(player)
	end)
end

return Party

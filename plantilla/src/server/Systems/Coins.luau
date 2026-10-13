--!strict
-- Monedas en el servidor: cada jugador tiene su contador en leaderstats y gana monedas cuando las pide.
-- El servidor decide siempre; el cliente solo pide (Net.collectCoins).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinsRules = require(ReplicatedStorage.Shared.Rules.Coins)
local Net = require(ReplicatedStorage.Shared.Net.Server)
local Texts = require(ReplicatedStorage.Shared.Data.Texts)

local Coins = {}

local lastCollect: { [Player]: number } = {}

local function setup(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = Texts.coins
	coins.Parent = leaderstats
	leaderstats.Parent = player
end

function Coins.init()
	Net.collectCoins.setCallback(function(player: Player)
		local now = os.clock()
		if not CoinsRules.canCollect(lastCollect[player], now) then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild(Texts.coins)
		if not coins or not coins:IsA("IntValue") then
			return
		end
		lastCollect[player] = now
		coins.Value = CoinsRules.collect(coins.Value)
		Net.coinsChanged.fire(player, coins.Value)
	end)
end

function Coins.start()
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		task.spawn(setup, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCollect[player] = nil
	end)
end

return Coins

--!strict
-- Arranque del servidor: el cargador arranca cada sistema de Systems/ (init de todos y después start de todos).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Kit.Loader)

Loader.run(script.Systems)

-- Todos los remotos del juego. Después de cambiar este archivo: `zap` en la raíz (regenera src/shared/Net/).
opt server_output = "src/shared/Net/Server.luau"
opt client_output = "src/shared/Net/Client.luau"
opt casing = "camelCase"

-- El cliente pide monedas. El servidor decide si puede (la espera entre pedidos va en Rules/Coins).
event collectCoins = {
	from: Client,
	type: Reliable,
	call: SingleAsync,
}

-- El servidor avisa al cliente de su nuevo saldo.
event coinsChanged = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: u32,
}

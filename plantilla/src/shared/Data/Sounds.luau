--!strict
-- Sonidos del juego. Se lanzan con Kit/Sounds: Sounds.play("Click").
-- asset: nombre en Assets ("sounds/ui/click") o "library:<id>" de la biblioteca de audio de Roblox (gratis,
-- sin subir nada; la primera opción). channel: music, sfx o ui. Lo elige Álvaro de oído entre 3 candidatos.
return {
	-- Ejemplo (sin asset todavía: suena en silencio y avisa una vez).
	Click = { asset = "sounds/ui/click", channel = "ui", volume = 0.6, variation = 0.05 },
}

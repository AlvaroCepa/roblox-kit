-- Pruebas de los formatos de la UI (Lune).
local Format = require("@src/shared/Rules/Format")

return {
	["short numbers"] = function(expect)
		expect(Format.short(0)).toBe("0")
		expect(Format.short(999)).toBe("999")
		expect(Format.short(1000)).toBe("1K")
		expect(Format.short(1999)).toBe("1.9K")
		expect(Format.short(1.2e12)).toBe("1.2T")
		expect(Format.short(-2500)).toBe("-2.5K")
	end,
	["times"] = function(expect)
		expect(Format.time(5)).toBe("0:05")
		expect(Format.time(185)).toBe("3:05")
		expect(Format.time(3725)).toBe("1:02:05")
	end,
}

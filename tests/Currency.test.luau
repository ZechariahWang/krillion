local Currency = require("../src/ReplicatedStorage/Shared/Currency")

return function(test)
	test("the currency is called Shells", function()
		assert(Currency.Name == "Shells" and Currency.Upper == "SHELLS")
	end)

	test("format adds thousands separators and the name", function()
		assert(Currency.format(1250) == "1,250 SHELLS", Currency.format(1250))
		assert(Currency.format(0) == "0 SHELLS")
		assert(Currency.format(999) == "999 SHELLS")
		assert(Currency.format(1000000) == "1,000,000 SHELLS")
		assert(Currency.format(-75) == "-75 SHELLS")
	end)

	test("short rounds to one decimal with K and M", function()
		assert(Currency.short(950) == "950")
		assert(Currency.short(1250) == "1.3K", Currency.short(1250))
		assert(Currency.short(2000) == "2K", Currency.short(2000))
		assert(Currency.short(3400000) == "3.4M", Currency.short(3400000))
		assert(Currency.short(999999) == "1M", Currency.short(999999))
	end)
end

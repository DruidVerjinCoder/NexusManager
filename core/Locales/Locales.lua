local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local Locale = {}
NM.Locale = Locale

--lua
local rawset = rawset

-- save
local localeSave = {}

function NM.GetLocales(locale)
	return GetLocale() == locale and Locale or {}
end

setmetatable(Locale, {
	__index = function(self, key)
		--self[key] = key or ""
		return localeSave[key] or key --error(format("'%s' LOCALE NOT FOUND", key or "nil"))
	end,
	__newindex = function(self, key, value)
		rawset(localeSave, key, value == true and key or value)
	end,
	}
)

local NM = select(2,...)
Util = {}

-- based on Item:ToItemID from TSM 3/4
function Util.ToItemID(itemString)
    if not itemString then
        return
    end

    --local printable = gsub(itemString, "\124", "\124\124");
    --ChatFrame1:AddMessage("Here's what it really looks like: \"" .. printable .. "\"");

    --local itemId = LA.TSM.GetItemID(itemString)

    local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix, Unique, LinkLvl, reforging, Name = string.find(itemString, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")

    --ChatFrame1:AddMessage("Id: " .. Id .. " vs. " .. itemId);
    return tonumber(Id)
end

NM.Util = Util
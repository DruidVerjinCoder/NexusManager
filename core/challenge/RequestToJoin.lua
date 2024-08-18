NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local L = NM.Locale
local RequestToJoin = {}

Menu.ModifyMenu("MENU_UNIT_BN_FRIEND", function(owner, rootDescription, contextData)
    rootDescription:CreateDivider();
    rootDescription:CreateTitle("NexusManager Challenge");
    rootDescription:CreateButton(L["Send request to join"],
        function() RequestToJoin.OnClick_BNetRequest4Inv(contextData) end);
end);

function RequestToJoin.OnClick_BNetRequest4Inv(bnetData, arg1)

end

NM.RequestToJoin = RequestToJoin;
local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")

local Debug = {}
local isEnabled = true
NM.Debug = Debug

function Debug:Log(msg, ...)
    if isEnabled then
        AE:Print(msg);
    end
end

function Debug:TableToString ( t )
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            self:Log(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        Debug:Log(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        Debug:Log(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        Debug:Log(indent.."["..pos..'] => "'..val..'"')
                    else
                        Debug:Log(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                Debug:Log(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        Debug:Log(tostring(t).." {")
        sub_print_r(t,"  ")
        Debug:Log("}")
    else
        sub_print_r(t,"  ")
    end
    Debug:Log("")
end
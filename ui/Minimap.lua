function Minimap:OnClick(button, down)
    if button == "LeftButton" then
        if IsControlKeyDown() then
            -- Öffne LogFrame
            NM.LogFrame:Show()
        else
            -- Normales Verhalten (Hauptfenster öffnen/schließen)
            NM:ToggleUI()
        end
    elseif button == "RightButton" then
        -- ... existing right click code ...
    end
end 
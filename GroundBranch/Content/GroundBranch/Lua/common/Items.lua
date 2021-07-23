local Items = {
    Primaries = {
        SMG = {
            "AKS74U",
            "MP5A4",
            "MP5A5",
            "MP5SD5",
            "MP5SD6",
            "MP7A1",
            "MPX_SBR",
            "UMP45"
        },
        AR = {
            "AK74_MI",
            "AK74_MI_CQB",
            "AK74M",
            "AKM",
            "FAL_Vintage",
            "FAL_Tactical",
            "Galil_SAR",
            "M16A4",
            "M416D",
            "M416D_CQB",
            "M4A1",
            "M4A1_Block_II",
            "MK18_MOD_1",
        }
    },
    Generic = {
        GrenadePouch = "Pouch_Grenade",
        AmmoPouch = "Pouch_Ammo"
    }
}

---WIP! The idea for this method is to check players inventory agains a list of
---forbidden items.
---@param playerInventory userdata
function Items.CheckIfHasForbiddenItems(playerInventory)
    for index, value in ipairs(playerInventory) do
        print(index)
        print(value)
        print("Table")
        for k, v in pairs(value) do
            print(k)
            print(v)
        end
        print("Metatable")
        local metatable = getmetatable(value)
        for k, v in pairs(metatable) do
            print(k)
            print(v)
        end
    end
end

Items.__index = Items

return Items

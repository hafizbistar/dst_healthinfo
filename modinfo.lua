-- information about the mod
name = "Health Info"
author = "xVars"
forumthread = ""
description = "v1.4.7\nShows exact health of creatures on mouse-over or controller auto-target. This mod is inspired by Tell Me About Health (DS) which was ported to Tell Me (DST)."
version = "1.4.7"


api_version = 10

--This lets the clients know that they need to download the mod before they can join a server that is using it.
all_clients_require_mod = true

--This let's the game know that this mod doesn't need to be listed in the server's mod listing
client_only_mod = false

--Let the mod system know that this mod is functional with Don't Starve Together
dont_starve_compatible = true
reign_of_giants_compatible = true
dst_compatible = true

--These tags allow the server running this mod to be found with filters from the server listing screen
server_filter_tags = {"health"}

-- custom icon
icon_atlas = "preview.xml"
icon = "preview.tex"


configuration_options =
{
    {
        name = "show_type",
        label = "Show Type",
        options =
        {
            {description = "Value", data = 0},
            {description = "Percentage", data = 1},
            {description = "Both", data = 2},
        },
        default = 0,
    },
    {
        name = "divider",
        label = "Divier Type",
        options =
        {
            {description = "100/100", data = 0},
            {description = "-100/100-", data = 1},
            {description = "[100/100]", data = 2},
            {description = "(100/100)", data = 3},
            {description = "{100/100}", data = 4},
            {description = "<100/100>", data = 5},
        },
        default = 5,
    }
}

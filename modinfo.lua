-- information about the mod
name = "Health Info"
author = "Nubs, star"
forumthread = ""
version = "2.1.8"
local IS_DST = name.utf8len and true or nil
if IS_DST then
	version_compatible = "2.1.8"
end

russian = IS_DST and (russian or (language == "ru")) --Переменная utf8len определена только c поддержкой UTF
description = russian and
	"v"..version.."\nПоказывает индикатор здоровья у всех существ при наведении мыши." or
	"v"..version.."\nShows exact health of creatures on mouse-over or controller auto-target. This mod is inspired by Tell Me About Health (DS) which was ported to Tell Me (DST)."

api_version = 6
api_version_dst = 10

--This lets the clients know that they need to download the mod before they can join a server that is using it.
all_clients_require_mod = true

--This let's the game know that this mod doesn't need to be listed in the server's mod listing
client_only_mod = false

--Let the mod system know that this mod is functional with Don't Starve Together
dont_starve_compatible = true
reign_of_giants_compatible = true
dst_compatible = true
shipwrecked_compatible = true
hamlet_compatible = true

--These tags allow the server running this mod to be found with filters from the server listing screen
server_filter_tags = {"healthinfo"}

-- custom icon
icon_atlas = "preview.xml"
icon = "preview.tex"

priority = -200.00456082189 --DS unique id
if IS_DST then
	priority = 0.00375859599 --DST unique id
end


configuration_options =
{
    {
        name = "show_type",
        label = russian and "Тип индикатора" or "Show Type",
		hover = russian and "Тип индикатора: по значению, в процентах или одновременно." or "Type of health indicator.",
        options =
        {
            {description = russian and "Значение" or "Value", data = 0, hover = russian and "Паук <100 / 100>" or "Spider <100 / 100>"},
            {description = russian and "Проценты" or "Percentage", data = 1, hover = russian and "Паук <100%>" or "Spider <100%>"},
            {description = russian and "Оба" or "Both", data = 2, hover = russian and "Паук <100 / 100 100%>" or "Spider <100 / 100 100%>"},
			(IS_DST
				and {description = russian and "Разброс" or "Variation", data = 3,
					hover = russian and "Паук <90 (±10%)>" or "Spider <90 (±10%)>"} 
				or nil
			),
        },
        default = 0,
    },
    {
        name = "divider",
        label = russian and "Скобки" or "Divier Type",
		hover = russian and "Вид отображения скобок в индикаторе." or "Type of brackets in indicator.",
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
    },
    IS_DST and {
        name = "use_blacklist",
        label = russian and "Чёрный список" or "Use Black List",
		hover = russian
			and "Чёрный список префабов.\nРекомендуется к включению.\nС другой стороны, вы не увидите здоровье этих\nпредметов, даже если какой-то мод добавит здоровье."
			or "Black list of prefabs.\nIt's recommended to use this option,\nbecause it improves compatibility.\nOn the other hand some mods can add health to\n standard objects and you won't see it.",
        options =
        {
            {description = russian and "Да" or "Yes", data = true},
            {description = russian and "Нет" or "No", data = false},
        },
        default = true,
    },
    IS_DST and {
        name = "unknwon_prefabs",
        label = russian and "Объекты из модов" or "Unknown Objects",
		hover = russian
			and "Автоматическое определение наличия здоровья.\nЧем больше типов объектов поддерживается, тем меньше совместимость."
			or "Automatic detection of unknown objects.\nMore types of objects, less compatibility.",
        options =
        {
            {description = "Ignore", data = 0, hover = "100% compatibility\nBut you won't see health of mod items, players and creatures."},
            {description = "Players", data = 1, hover = '99% compatibility\nThe mod will check only "player" tag.'},
            {description = "Creatures", data = 2, hover = '97% compatibility\nThe mod will check only "player", "monster", "animal",\n"smallcreature", "largecreature" and "epic" tags.'},
            {description = "All", data = 3, hover = "90% compatibility\nAll known tags will be used."},
        },
        default = 1,
    },
    IS_DST and {
        name = "send_unknwon_prefabs",
        label = russian and "Отсылать ошибки" or "Send Error Reports",
		hover = russian
			and "Посылать разработчикам отчёты об объектах, которые неправильно работают.\nЭто поможет улучшить мод."
			or "Send reports about unknown prefabs which could be supported by the mod.",
        options =
        {
            {description = russian and "Да" or "Yes", data = true},
            {description = russian and "Нет" or "No", data = false},
        },
        default = false,
    },
    IS_DST and {
        name = "random_health_value",
        label = russian and "Случайное отклонение" or "Chance Fluctuation",
		hover = russian
			and "Здоровье показывается не точно.\nМаксимальное здоровье скрыто."
			or "Health is inaccurate. Maximum health is hidden.",
        options =
        {
            {description = "0%", data = 0},
            {description = "5%", data = 0.05},
            {description = "10%", data = 0.1},
            {description = "15%", data = 0.15},
            {description = "25%", data = 0.25},
            {description = "30%", data = 0.3},
            {description = "40%", data = 0.4},
            {description = "50%", data = 0.5},
        },
        default = 0,
    },
    IS_DST and {
        name = "random_range",
        label = russian and "Случайность в интервале" or "Randomize Interval",
		hover = russian
			and "Интервал, в котором генерируются случайные значения здоровья\n(в процентах от макс здоровья)."
			or "Interval for generating random health values\n(percent of max health.)",
        options =
        {
            {description = russian and "Всегда" or "Always", data = 0},
            {description = "1%-99%", data = 0.01},
            {description = "5%-95%", data = 0.05},
            {description = "10%-90%", data = 0.10},
            {description = "15%-85%", data = 0.15},
        },
        default = 0,
    },
}



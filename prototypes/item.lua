--item.lua

local autopilotArmor = table.deepcopy(data.raw.armor["light-armor"])

autopilotArmor.name = "autopilot-armor"
autopilotArmor.icons= {
   {
      icon=autopilotArmor.icon,
      tint={r=1,g=0,b=0,a=0.3}
   },
}

autopilotArmor.resistances = {
   {
      type = "physical",
      decrease = 6,
      percent = 10
   },
   {
      type = "explosion",
      decrease = 10,
      percent = 30
   },
   {
      type = "acid",
      decrease = 5,
      percent = 30
   },
   {
      type = "fire",
      decrease = 0,
      percent = 100
   },
}

local recipe = table.deepcopy(data.raw.recipe["light-armor"])
recipe.enabled = true
recipe.name = "autopilot-armor"
recipe.ingredients = {{"iron-plate",1}}
recipe.result = "autopilot-armor"

data:extend{autopilotArmor,recipe}

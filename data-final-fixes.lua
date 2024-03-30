if not mods["exotic-industries"] then
   return
end

log("test")
-- Give metalworks the same module slots assertion assembling machines
local function fix_metalworks_modules(tier, n_slots) 
   local machine = data.raw["assembling-machine"]["ei_metalworks_" .. tier]
   machine.allowed_effects = {"speed", "consumption", "pollution", "productivity"}
   machine.module_specification = {
      module_slots = n_slots
   }
   log("added module slots to tier " .. tier)
end
fix_metalworks_modules(2, 2)
fix_metalworks_modules(3, 4)
fix_metalworks_modules(4, 6)

-----------------------------------------
-- Remove duplicate metalworks recipes --
-----------------------------------------
-- EI creates a duplicate recipe with the 'ei_metalworks' category for every recipe that the 
-- metalworks can craft. A better solution is to allow all assembling machines to craft 
-- the 'ei_metalworks' recipes, so there are no duplicates

-- Allow assembling machines to craft 'ei_metalworks'
local metalworks_category = "ei_metalworks"
local function enable_metalworks(machine) 
   for _, machine in pairs(data.raw[machine]) do
      for _, category in ipairs(machine.crafting_categories) do
         if category == "crafting" then
            log("Add " .. metalworks_category .. " to " .. machine.name)
            table.insert(machine.crafting_categories, metalworks_category)
            break
         end
      end
   end
end

enable_metalworks("assembling-machine")
enable_metalworks("character")

local function remove_recipes(pattern) 
   log("Removing recipes matching pattern " .. pattern)
   -- Set value to nil to remove recipe from existence
   for k, recipe in pairs(data.raw["recipe"]) do
      if string.match(recipe.name, pattern) then
         log("Removed recipe " .. recipe.name)
         data.raw["recipe"][k] = nil
      end
   end

   -- Also remove recipe unlocks from technologies 
   for _, technology in pairs(data.raw["technology"]) do 
      if technology["effects"] then
         for k, effect in pairs(technology["effects"]) do
            if effect["type"] == "unlock-recipe" then
               if string.match(effect["recipe"], pattern) then
                  technology["effects"][k] = nil
               end
            end
         end
      end
   end
end

-- EI adds duplicate recipes with ':metalworks' appended to the recipe name
local metalworks_suffix = ":metalworks"
local metalworks_pattern = metalworks_suffix .. "$"

-- Modify the 'crafting' counterparts of these recipes to instead use 'ei_metalworks'
local recipes_to_modify = {}
for _, recipe in pairs(data.raw["recipe"]) do
   if string.match(recipe.name, metalworks_pattern) then
      local orig_recipe_name = string.sub(recipe.name, 1, #recipe.name - #metalworks_suffix)
      -- Could also try to directly access data.raw["recipe"][orig_recipe_name] but I am scared
      table.insert(recipes_to_modify, orig_recipe_name)
   end
end
for _, recipe in pairs(data.raw["recipe"]) do
   for _, recipe_to_modify in pairs(recipes_to_modify) do
      if recipe.name == recipe_to_modify then
         recipe.category = metalworks_category
         log("Changed crafting category of recipe " .. recipe.name .. " to " .. recipe.category)
      end
   end
end


-- Then remove the duplicate recipes with ':metalworks' suffix
remove_recipes(metalworks_pattern)

-- Remove crushing recipes for beams, parts and plates because they are useless bloat
local crush_pattern = "^ei_crushed-.*:"
remove_recipes(crush_pattern)
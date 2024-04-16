if not mods["exotic-industries"] then
   return
end

local DEBUG = 1
local function log_(text) 
   if DEBUG then
      log(text)      
   end
end

-- Give metalworks the same module slots assertion assembling machines
local function fix_metalworks_modules(tier, n_slots) 
   local machine = data.raw["assembling-machine"]["ei_metalworks_" .. tier]
   machine.allowed_effects = {"speed", "consumption", "pollution", "productivity"}
   machine.module_specification = {
      module_slots = n_slots
   }
   log_("Added module slots to tier " .. tier .. " metalworks")
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
            log_("Add " .. metalworks_category .. " to " .. machine.name)
            table.insert(machine.crafting_categories, metalworks_category)
            break
         end
      end
   end
end

enable_metalworks("assembling-machine")
enable_metalworks("character")

local function remove_recipes(pattern) 
   log_("Removing recipes matching pattern " .. pattern)
   -- Escape magic characters that are valid in recipe names
   pattern = string.gsub(pattern, "%-", "%%-")

   -- Set value to nil to remove recipe from existence
   for k, recipe in pairs(data.raw["recipe"]) do
      if string.match(recipe.name, pattern) then
         log_("Removed recipe " .. recipe.name)
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
         log_("Changed crafting category of recipe " .. recipe.name .. " to " .. recipe.category)
      end
   end
end


-- Then remove the duplicate recipes with ':metalworks' suffix
remove_recipes(metalworks_pattern)

-- Remove crushing recipes for beams, parts and plates because they are useless bloat
local crush_pattern = "^ei_crushed-.*:"
remove_recipes(crush_pattern)

-- Remove molten metal recipes except for pure ore and allow prod for pure ore recipes
local function allow_prod(recipe_name)
   log_("Allowing productivity for recipe " .. recipe_name)
   for _, module in pairs(data.raw["module"]) do
      if module.category == "productivity" then
         for _, allowed_recipe in pairs(module.limitation) do
            if allowed_recipe == recipe_name then
               return
            end
         end
         table.insert(module.limitation, recipe_name)
      end
   end
end

local molten_pattern = "^ei_molten%-.*:"
local molten_pure_pattern = ":pure%-ore$"
local molten_removal_targets = { ":beam$", ":plate$", ":mechanical%-parts$", ":ingot$"}
for _, recipe in pairs(data.raw["recipe"]) do 
   if string.match(recipe.name, molten_pattern) then
      if string.match(recipe.name, molten_pure_pattern) then
         -- Allow productivity for turning pure ore into molten metal
         -- Otherwise there is no productivity step for the molten metal chain, unlike directly
         -- smelting pure ores which allows productivity 
         allow_prod(recipe.name)
      else
         for _, removal_target in pairs(molten_removal_targets) do
            if string.match(recipe.name, removal_target) then
               -- Remove recipes that turn beams / plates / parts into molten metal
               remove_recipes(recipe.name)
            end
         end
      end
   end
end

-- Allow productivity module in arc furnace and plasma heater
local molten_furnaces = {"ei_arc-furnace", "ei_plasma-heater"}
for _, furnace_name in pairs(molten_furnaces) do
   local furnace = data.raw["furnace"][furnace_name]
   if furnace then
      table.insert(furnace.allowed_effects, "productivity")
      log_("Allowed productivity in furnace " .. furnace.name)
   end
end

-- Remove ei_bio-chamber tag from excavator 
local excavator = data.raw["assembling-machine"]["ei_excavator"]
if excavator then
   for i, category in ipairs(excavator.crafting_categories) do
      if category == "ei_bio-chamber" then
         table.remove(excavator.crafting_categories, i)
      end
   end
end

-- Fix mining time of neo belts (default is 2x as long as normal belts)
local targets = {
   {"transport-belt", "ei_neo-belt"}, 
   {"underground-belt", "ei_neo-underground-belt"},
   {"splitter", "ei_neo-splitter"}
}
for _, target in pairs(targets) do
   local type, name = table.unpack(target)
   local entity = data.raw[type][name]
   if entity then
      entity.minable.mining_time = 0.1
      log_("Fixed mining time of " .. name)
   else
      log_("Warn: did not find entity with name " .. name)
   end
end


-- Make induction matrix blueprintable instead of having to manually place them
-- like an actual caveman 
local matrix_core_pattern = "^ei_induction%-matrix%-core:"
for _, entity in pairs(data.raw["electric-energy-interface"]) do
   if string.match(entity.name, matrix_core_pattern) then
      -- Remove not-blueprintable flag, this allows building of induction matrix ghosts
      for k, flag in pairs(entity.flags) do
         if flag == "not-blueprintable" then
            entity.flags[k] = nil
         end
      end
      -- EI dynamically creates 17 entity variations of the matrix core
      -- register them as being placeable by the base item
      entity.placeable_by = {
         item = "ei_induction-matrix-core",
         count = 1
      }
      log_("Fixed matrix core " .. entity.name)
   end
end
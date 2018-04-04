--control.lua

--to do
-- cost function
-- cutting trees

-- Enabling stacks and queues in Lua
Stack = {}
function Stack.new ()
  return {first = 0, last = -1}
end
Queue = {}
function Queue.new ()
  return {first = 0, last = -1}
end

function Queue.push (list, value)
  local first = list.first - 1
  list.first = first
  list[first] = value
end

function Stack.push (list, value)
  local last = list.last + 1
  list.last = last
  list[last] = value
end

function Queue.pop (list)
  local first = list.first
  if first > list.last then error("list is empty") end
  local value = list[first]
  list[first] = nil        -- to allow garbage collection
  list.first = first + 1
  return value
end

function Stack.pop (list)
  local last = list.last
  if list.first > last then error("list is empty") end
  local value = list[last]
  list[last] = nil         -- to allow garbage collection
  list.last = last - 1
  return value
end

local SEARCH_OFFSET = 1
local GLOBAL_SURFACE_MAP = {{-32,-32},{32,32}}
local init_armor = 1
local init_scan = 1
map_width = 256
map_height = 256
local moveDiagonal = 1
local moveHorizontal = 0
local moveVertical = 0
local success_flag = 0
local TILE_RADIUS = 0.2

local function round(value)
	return math.floor(value + 0.5)
end

local function tablelength(table)
  local count = 0
  for index in pairs(table) do count = count + 1 end
  return count
end

local function moveTo(player, xDist, yDist, distEuc)
  -- moveTo
  --
  if xDist >= TILE_RADIUS and yDist >= TILE_RADIUS then
    player.walking_state = {walking = true, direction = defines.direction.southeast}
  elseif xDist <= -TILE_RADIUS and yDist >= TILE_RADIUS then
    player.walking_state = {walking = true, direction = defines.direction.southwest}
  elseif xDist >= TILE_RADIUS and yDist <= -TILE_RADIUS then
    player.walking_state = {walking = true, direction = defines.direction.northeast}
  elseif xDist <= -TILE_RADIUS and yDist <= -TILE_RADIUS then
    player.walking_state = {walking = true, direction = defines.direction.northwest}
  elseif yDist >= TILE_RADIUS then
    player.walking_state = {walking = true, direction = defines.direction.south}
  elseif yDist <= -TILE_RADIUS then
    player.walking_state = {walking = true, direction = defines.direction.north}
  elseif xDist >= TILE_RADIUS then
    player.walking_state = {walking = true, direction = defines.direction.east}
  elseif xDist <= -TILE_RADIUS then
    player.walking_state = {walking = true, direction = defines.direction.west}
  end
end

local function find_nearest_entity(xPosPlayer, yPosPlayer, game, player, entity)
  local i = 1
  local entityCount = 0
  while entityCount == 0 do
    i = i + 1
    entityCount=game.surfaces[1].count_entities_filtered{area={{xPosPlayer-i, yPosPlayer-i}, {xPosPlayer+i, yPosPlayer+i}},name=entity}
  end
  entityFind=game.surfaces[1].find_entities_filtered{area={{xPosPlayer-i, yPosPlayer-i}, {xPosPlayer+i, yPosPlayer+i}},name=entity, limit=1}
  allEntities=game.surfaces[1].find_entities_filtered{area={{xPosPlayer-i, yPosPlayer-i}, {xPosPlayer+i, yPosPlayer+i}}}
  return entityCount, entityFind, allEntities, i
end

local function create_collision_map(x, y, game, player, radius)
  local collision_count = 0
  map_width = game.surfaces[1].map_gen_settings.width
  map_height = game.surfaces[1].map_gen_settings.height
  if map_width > 256 then
    map_width = 256
  end
  if map_height > 256 then
    map_height = 256
  end
  GLOBAL_SURFACE_MAP = {{-map_width / 2 + 1, -map_height / 2 + 1}, {map_width / 2 - 1, map_height / 2 - 1}}
  local surface_map = {{-x - radius, -y - radius}, {x + radius, y + radius}}

  -- this is ridiculously inefficient, change the area to somehting dynamic
  local mapTiles = game.surfaces[1].find_tiles_filtered{area=surface_map}
  local mapEntities = game.surfaces[1].find_entities_filtered{area=surface_map}

  local collision_map = {}
  for i=1,map_width do
    collision_map[i]={}
    for j=1,map_height do
      collision_map[i][j]=0
    end
  end

  for index, tile_value in ipairs(mapTiles) do
    if tile_value.prototype.collision_mask["player-layer"] == true then
       -- log(serpent.line(value.name))
       -- log(serpent.line(value.position))
       collision_map[tile_value.position.x + map_width / 2][tile_value.position.y + map_height / 2] = 1
       collision_count = collision_count + 1
    end
  end

  for index, entitity_value  in ipairs(mapEntities) do
    if entitity_value.prototype.collision_mask["player-layer"] == true then
      -- log(serpent.line(entitity_value.prototype.collision_box))
      -- log(serpent.line(entitity_value.prototype.collision_mask))
      local collision_entity_tile = game.surfaces[1].get_tile(entitity_value.position.x,entitity_value.position.y)
      x_entity_col = collision_entity_tile.position.x
      y_entity_col = collision_entity_tile.position.y
      if math.abs(x_entity_col) < map_width / 2 and math.abs(y_entity_col) < map_width then
        if collision_map[collision_entity_tile.position.x + map_width / 2][collision_entity_tile.position.y + map_height / 2] == 0 then
          collision_map[collision_entity_tile.position.x + map_width / 2][collision_entity_tile.position.y + map_height / 2] = 1
          collision_count = collision_count + 1
        end
      end
    end
  end

    return collision_map, collision_count
end

local function is_goal_state(testState, goalState)
  if testState[1] == goalState[1] and testState[2] == goalState[2] then
    return true
  else
    return false
  end
end

local function is_in_closed_states(testState, closedStates)
  if closedStates == {} then
    return false
  else
    for _,v in ipairs(closedStates) do
      if v[1] == testState[1] and v[2] == testState[2] then
        return true
      end
    end
  end
end

local function get_neighbors(current_state,collision_map)
  local neighbors = {}
  local i = -1
  local j = -1
  while i < 2 do
    while j < 2 do
      collision_point = collision_map[current_state[1]+i][current_state[2]+j]
      if collision_point == 0 then
        neighbors.insert(collision_point)
      end
      j = j+1
    end
    i = i + 1
  end
  return neighbors
end

local function path_finder(xPlayer, yPlayer, collision_map, collision_count, xGoal, yGoal)
  -- lump xy coordinates together
  start_state = {xPlayer, yPlayer}
  goal_state = {xGoal, yGoal}

  local path = Queue.new()
  Queue.push(path, start_state)
  Queue.push(path, goal_state)
  log(serpent.line("path"))
  log(serpent.line(path))
  log(serpent.line(goal_state))
  local fringe_list = Queue.new()
  closed_states = {}
  Queue.push(fringe_list, start_state)
  log(serpent.line(fringe_list~={}))
  while fringe_list~={} do


    current_state = Queue.pop(fringe_list)
    if is_goal_state(current_state, goal_state) == true then
      log(serpent.line("gooooaallllll"))
      return current_state
    end
    if is_in_closed_states(current_state, closed_states) == false then
      closed_states.insert(current_state)

      log(serpent.line("reached here"))
      local neighbors = get_neighbors(current_state,collision_map)
      for _, v in ipairs(neighbors) do
        Queue.push(fringe_list, v)
      end
    end
  end
  --log(serpent.line(Queue.pop(path)))
end

script.on_event({defines.events.on_tick},
   function (e)
      if e.tick % 1 == 0 then --common trick to reduce how often this runs, we don't want it running every tick, just 1/second
         for index,player in pairs(game.connected_players) do  --loop through all online players on the server
            if init_armor == 1 then

              --player.insert{name="light-armor", count=1}
              player.begin_crafting{count=1, recipe="autopilot-armor"}
              player.begin_crafting{count=1, recipe="iron-axe"}
              --player.insert{name="autopilot-armor", count=1}
              init_armor = 0
            end
            if player.character and player.get_inventory(defines.inventory.player_armor).get_item_count("autopilot-armor") > 0 then
               --create the fire where they're standing
               --player.surface.create_entity{name="fire-flame", position=player.position, force="neutral"}
               --player.print(serpent.line(player))
               player.color= {r=184,g=176,b=155,a=1.0}
               player.character_running_speed_modifier = 2
               xPosPlayer = player.position.x
               yPosPlayer = player.position.y
               --player.print("xPosPlayer: ".. xPosPlayer .." yPosPlayer: ".. yPosPlayer)
               entity = "copper-ore"
               if init_scan == 1 then
                 ironCount=game.surfaces[1].count_entities_filtered{area={{xPosPlayer-SEARCH_OFFSET, yPosPlayer-SEARCH_OFFSET},
                 {xPosPlayer+SEARCH_OFFSET, yPosPlayer+SEARCH_OFFSET}},name=entity}
                 -- ironTile=game.surfaces[1].find_tiles_filtered{area=GLOBAL_SURFACE_MAP}
                 -- ironFind=game.surfaces[1].find_entities_filtered{area=GLOBAL_SURFACE_MAP}
                 init_scan = 0
               end
               --ironFind=game.surfaces[1].find_entities_filtered{area={{xPosPlayer-SEARCH_OFFSET, yPosPlayer-SEARCH_OFFSET}, {xPosPlayer+SEARCH_OFFSET, yPosPlayer+SEARCH_OFFSET}},name="iron-ore", limit=50}
               --ironCount=game.surfaces[1].count_entities_filtered{area=GLOBAL_SURFACE_MAP,name="iron-ore"}

               --itemFind=game.surfaces[1].find_entities({{-10, -10}, {10, 10}})
               --itemCount=game.surfaces[1].count_entities_filtered{area={{-100, -100}, {100, 100}}}

               --itemCount=tablelength(itemFind)
               --player.print("Nearby Items count: ".. itemCount)
               if ironCount == 0 then
                 ironCount, ironFind, allEntities, expansionRadius = find_nearest_entity(player.position.x, player.position.y, game, player,entity)

                 collision_map, collision_count = create_collision_map(player.position.x, player.position.y, game, player, expansionRadius)
                 log(serpent.line(collision_count))
                 --log(serpent.line(collision_map))
                 --player.print(serpent.line(tablelength(allEntities)))
                 --log( serpent.block( allEntities[1].name, {comment = false, numformat = '%1.8g' } ) )
                 -- for index, value  in ipairs(allEntities) do
                   -- log(serpent.line(value.name))
                   -- --log(serpent.line(value.position))
                   -- entityTile = game.surfaces[1].get_tile(value.position.x,value.position.y)
                   -- log(serpent.line(entityTile.position))
                 -- end
               elseif ironCount > 0 then
                  --player.print(serpent.line(find_iron))
                  for index, value  in ipairs(ironFind) do
                      PosIron = value.position
                      xPosIron = value.position.x
                      yPosIron = value.position.y
                      xPosIron_rounded = round(xPosIron)
                      yPosIron_rounded = round(yPosIron)
                      distEuc = math.sqrt(math.pow(xPosPlayer-xPosIron,2)+math.pow(yPosPlayer-yPosIron,2))
                      xDist = value.position.x-player.position.x
                      yDist = value.position.y-player.position.y
                      xDist_rounded = round(xDist)
                      yDist_rounded = round(yDist)


                      entityTile = game.surfaces[1].get_tile(xPosIron,yPosIron)
                      xPosGoal = entityTile.position.x
                      yPosGoal = entityTile.position.y
                      xDist = entityTile.position.x-player.position.x
                      yDist = entityTile.position.y-player.position.y
                      --player.print(index .. " xPosIron: ".. xPosIron .." yPosIron: ".. yPosIron)
                      --player.print(index .. " xDist: ".. xDist .." yDist: ".. yDist)

                  end
                  if init_scan == 0 then
                    moveToWithCollision = path_finder(xPosPlayer+ map_width/2, yPosPlayer+map_height/2, collision_map, collision_count, xPosGoal+map_width/2, yPosGoal+map_height/2)
                    init_scan = 2
                  end
                  if distEuc > TILE_RADIUS then
                    --moveTo(player, xDist, yDist, distEuc)
                  end
                  --player.character.set_command({type=defines.command.go_to_location,destination={xPosIron,yPosIron}})
                end
                if xDist_rounded == 0 and yDist_rounded == 0 then
                  --player.update_selected_entity({xPosIron,yPosIron})
                  --entityTile = game.surfaces[1].get_tile(xPosPlayer,yPosPlayer)
                  --entityTile = game.surfaces[1].get_tile(xPosIron,yPosIron)
                  --player.update_selected_entity({entityTile.position.x,entityTile.position.y})
                  --player.mining_state = {mining = true,position={entityTile.position.x,entityTile.position.y}}
                  --player.print(entityTile.position.x .. entityTile.position.y)
                  if success_flag == 0 then
                    success_flag = 1
                    player.print("xPosPlayer: ".. xPosPlayer .."m yPosPlayer: ".. yPosPlayer)
                    player.print("xPosIron: ".. entityTile.position.x .."m yPosIron: ".. entityTile.position.y)
                    player.print("Success!")
                  end
                end
            else
              player.color= {r=255,g=140,b=0,a=1}
              player.character_running_speed_modifier = 0
              ironCount = 0
            end
         end
      end
   end
)

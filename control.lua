--control.lua

require("libs.util")
require("config.config")
-- /c game.player.surface.create_entity({name="copper-ore", position={game.player.position.x-4, game.player.position.y+3}})
--to do
-- cost function
-- cutting trees
-- /c game.player.surface.create_entity({name="stone-wall", position={game.player.position.x+4, game.player.position.y+3}})

local function logthis(msg, var)
  log(serpent.line(msg))
  log(serpent.line(var))
end

local function moveTo(player, xDist, yDist, distEuc)
  -- moveTo
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
  -- finds nearest entity (copper-ore, tree, etc.) from the player's current position
  local i = 1
  local entityCount = 0
  while entityCount == 0 do
    i = i + 1
    entityCount = game.surfaces[1].count_entities_filtered{area={{xPosPlayer - i, yPosPlayer - i}, {xPosPlayer + i, yPosPlayer + i}}, name=entity}
  end
  entityFind = game.surfaces[1].find_entities_filtered{area={{xPosPlayer - i, yPosPlayer - i}, {xPosPlayer + i, yPosPlayer + i}}, name = entity, limit=1}
  allEntities = game.surfaces[1].find_entities_filtered{area={{xPosPlayer - i, yPosPlayer - i}, {xPosPlayer + i, yPosPlayer + i}}}
  return entityCount, entityFind, allEntities, i
end


local function create_collision_map(x, y, game, player, radius)
  -- creates a collision matrix of size MAP_WIDTH * MAP_HEIGHT filled with 0s and 1s (1 - collision)
  local collision_count = 0
  MAP_WIDTH = game.surfaces[1].map_gen_settings.width
  MAP_HEIGHT = game.surfaces[1].map_gen_settings.height
  if MAP_WIDTH > 256 then
    MAP_WIDTH = 256
  end
  if MAP_HEIGHT > 256 then
    MAP_HEIGHT = 256
  end
  GLOBAL_SURFACE_MAP = {{-MAP_WIDTH / 2 + 1, -MAP_HEIGHT / 2 + 1}, {MAP_WIDTH / 2 - 1, MAP_HEIGHT / 2 - 1}}
  local surface_map = {{-x - radius, -y - radius}, {x + radius, y + radius}}

  -- this is ridiculously inefficient, change the area to somehting dynamic
  local mapTiles = game.surfaces[1].find_tiles_filtered{area=surface_map}
  local mapEntities = game.surfaces[1].find_entities_filtered{area=surface_map}

  local collision_map = {}
  for i=1,MAP_WIDTH do
    collision_map[i]={}
    for j=1,MAP_HEIGHT do
      collision_map[i][j]=0
    end
  end

  for index, tile_value in ipairs(mapTiles) do
    if tile_value.prototype.collision_mask["player-layer"] == true then
       -- log(serpent.line(value.name))
       -- log(serpent.line(value.position))
       collision_map[tile_value.position.x + MAP_WIDTH / 2][tile_value.position.y + MAP_HEIGHT / 2] = 1
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
      if math.abs(x_entity_col) < MAP_WIDTH / 2 and math.abs(y_entity_col) < MAP_WIDTH then
        if collision_map[collision_entity_tile.position.x + MAP_WIDTH / 2][collision_entity_tile.position.y + MAP_HEIGHT / 2] == 0 then
          collision_map[collision_entity_tile.position.x + MAP_WIDTH / 2][collision_entity_tile.position.y + MAP_HEIGHT / 2] = 1
          collision_count = collision_count + 1
        end
      end
    end
  end
    return collision_map, collision_count
end


local function is_goal_state(testState, goalState)
	-- checks if the testState is the goalState by equating their x and y coordinates
  -- logthis("testState", testState)
  -- logthis("goalState", goalState)
  if testState[1] == goalState[1][1] and testState[2] == goalState[1][2] then
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
      if v[1] ~= testState[1] or v[2] ~= testState[2] then
        return false
      end
    end
  end
end

direction_dict = {['nw'] = {-1, -1}, ['sw'] = {-1, 1}, ['ne'] = {1, -1}, ['se'] = {1, 1}, ['n'] = {0, -1}, ['s'] = {0, 1}, ['e'] = {1, 0}, ['w'] = {-1, 0}}

local function get_neighbors(current_state, collision_map, goalState)
	local neighbors = {}
	local neighbors_index = 1
  local neighbor_cost = 1
  local neighbor_direction
  local i = -1
  -- note: for some reason in factorio, south and north directions are flipped
  -- local direction_dict = {['nw '] = {-1, -1}, ['sw '] = {-1, 1}, ['ne '] = {1, -1}, ['se '] = {1, 1}, ['n '] = {0, -1}, ['s '] = {0, 1}, ['e '] = {1, 0}, ['w '] = {-1, 0}}
  -- log(serpent.line("current_state"))
  -- log(serpent.line(current_state[1]))
  -- log(serpent.line(current_state[1][1]))
  local current_pos = current_state
  while i < 2 do
		local j = -1
    while j < 2 do
			if math.abs(current_pos[1]+i) <= MAP_WIDTH and math.abs(current_pos[2] + j) <= MAP_HEIGHT then
	      collision_point = collision_map[current_pos[1] + i][current_pos[2] + j]
				-- log(serpent.line("collision_point:"))
				-- log(serpent.line(collision_point))
				-- log(serpent.line({current_state[1]+i, current_state[2]+j}))
	      if collision_point == 0 then
          for key, val in pairs(direction_dict) do
            if i == val[1] and j == val[2] then
              neighbor_direction = key --key is the direction in the dictionary
            end
          end
	        neighbors[neighbors_index] = {{current_pos[1] + i, current_pos[2] + j}, neighbor_direction, neighbor_cost}
					neighbors_index = neighbors_index + 1
	      end
			end
			j = j + 1
    end
    i = i + 1
  end
	-- log(serpent.line("neighbors:"))
  -- log(serpent.line(neighbors))
  return neighbors
end


local function visited(visited, neighbor)
  local visited_flag = false -- suboptimal because loop has to iterate every single element/ add break?
	for _, v in ipairs(visited) do
  		-- log(serpent.line("visited:"))
  		-- log(serpent.line(v[1][1]))
  		-- log(serpent.line("neighbor:"))
  		-- log(serpent.line(neighbor))
  		-- log(serpent.line(v[1] ~= neighbor[1] and v[2] ~= neighbor[2]))
  		if v[1][1] == neighbor[1] and v[1][2] == neighbor[2] then
  			visited_flag = true
        break
  		else
        visited_flag = false
      end
	end
  return visited_flag
end


init = 1
local function path_finder(xPlayer, yPlayer, collision_map, collision_count, xGoal, yGoal)
  -- lump xy coordinates together
  start_state = {{xPlayer, yPlayer},'start ', 1}
  goal_state = {{xGoal, yGoal}, 'goal ', 1}
	potato_state = {{xGoal, yGoal},{}}
  local path = Queue.new()
	log(serpent.line("start_state:"))
  log(serpent.line(start_state))
	log(serpent.line("Goal State:"))
  log(serpent.line(goal_state))

  local fringe_list = Queue.new()
  local closed_states = {}
	local ctr = 1
  Queue.push(fringe_list, start_state)
	-- log(serpent.line("fringe:"))
	-- log(serpent.line(fringe_list))
	local visit_ctr = 1
	local visited_list = {}
	table.insert(visited_list, {start_state})

  while fringe_list~={} do
    -- log(serpent.line("fringe:"))
    -- log(serpent.line(fringe_list))
    current_state = Queue.pop(fringe_list)
    --
    --
		-- log(serpent.line("current_state:"))
		-- log(serpent.line(current_state))
		-- log(serpent.line(current_state[1][1]))
		-- log(serpent.line("Goal State:"))
		-- log(serpent.line(goal_state))
		-- remember Roman said NOT to check if current state until you pop it from queue
    if is_goal_state(current_state[1], goal_state) == true then
      -- log(serpent.line("current_state:"))
      -- log(serpent.line(current_state))
      log(serpent.line("gooooaallllll"))
      return current_state
    end

		if is_in_closed_states(current_state[1], closed_states) == false or closed_states[1] == nil then
			closed_states[ctr] = current_state
			ctr = ctr + 1
      -- local neighbors = get_neighbors(current_state[1],collision_map)
			for _, neighbor in ipairs(get_neighbors(current_state[1], collision_map, goal_state, fringe_list)) do
				if visited(visited_list[1], neighbor[1]) == false then
					table.insert(visited_list[1], {neighbor[1], (neighbor[2] .. " " .. current_state[2]), neighbor[3] + current_state[3]})
					-- log(serpent.line("visited_list:"))
					-- log(serpent.line(visited_list[1]))
          -- log(serpent.line("neighbor:"))
          -- log(serpent.line(neighbor))
					Queue.push(fringe_list, {neighbor[1], (neighbor[2] .. " " .. current_state[2]), neighbor[3] + current_state[3]})

				end
			end
			-- log(serpent.line("fringe_list:"))
			-- log(serpent.line(fringe_list))
			-- log(serpent.line("visited_list:"))
			-- log(serpent.line(visited_list))
    end
		-- log(serpent.line("reached end of while"))
  end
  -- log(serpent.line(fringe_list))
end
function reverse(tbl)
  for i=1, math.floor(#tbl / 2) do
    local tmp = tbl[i]
    tbl[i] = tbl[#tbl - i + 1]
    tbl[#tbl - i + 1] = tmp
  end
  return tbl
end

local function dir_to_path(directions, xPos, yPos, xGoal, yGoal)
  -- requires optimization (flip array and stuff)
  num_steps = 1
  local direction_list = {}
  -- converts "sw sw sw n e start" to ["sw","sw","sw","n","e","start"]
  for w in directions:gmatch("%S+") do
    direction_list[num_steps] = w
    num_steps = num_steps + 1
  end
  local i = 2
  local dir_ctr = 1
  direction_list = reverse(direction_list)

  logthis("direction_list", direction_list)
  local waypoint = {xPos, yPos}
  local waypoints = {}
  while i < num_steps - 1 do
    for key, val in pairs(direction_dict) do
      if (direction_list[i]) == (key) then
        waypoint = {waypoint[1] + val[1], waypoint[2] - val[2] }
        table.insert(waypoints, waypoint)
      end
    end
    i = i + 1
  end
  table.insert(waypoints, {xGoal, yGoal})
  return waypoints, num_steps
end
potato = 1
script.on_event({defines.events.on_tick},
   function (e)
      if e.tick % 10 == 0 then --common trick to reduce how often this runs, we don't want it running every tick, just 1/second

         for index,player in pairs(game.connected_players) do  --loop through all online players on the server
            if init_armor == 1 then

              -- remove following line for release
              game.surfaces[1].create_entity({name="copper-ore", position={15, 0}})
              --player.insert{name="light-armor", count=1}
              player.begin_crafting{count=1, recipe="autopilot-armor"}
              -- player.begin_crafting{count=1, recipe="iron-axe"}


              --player.insert{name="autopilot-armor", count=1}
              init_armor = 0
            end
            if player.character and player.get_inventory(defines.inventory.player_armor).get_item_count("autopilot-armor") > 0 then
               --create the fire where they're standing
               --player.surface.create_entity{name="fire-flame", position=player.position, force="neutral"}
               --player.print(serpent.line(player))
               player.color= {r=184, g=176, b=155, a=1.0}
               player.character_running_speed_modifier = 2
               xPosPlayer = player.position.x
               yPosPlayer = player.position.y
               --player.print("xPosPlayer: ".. xPosPlayer .." yPosPlayer: ".. yPosPlayer)
               playerTile = game.surfaces[1].get_tile(xPosPlayer,yPosPlayer)
               xTilePlayer = playerTile.position.x
               yTilePlayer = playerTile.position.y

               entity = "copper-ore"
               if init_scan == 1 then
                 ironCount = game.surfaces[1].count_entities_filtered{area={{xTilePlayer - SEARCH_OFFSET, yTilePlayer - SEARCH_OFFSET},
                 {xTilePlayer + SEARCH_OFFSET, yTilePlayer + SEARCH_OFFSET}}, name = entity}
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
                 ironCount, ironFind, allEntities, expansionRadius = find_nearest_entity(xTilePlayer, yTilePlayer, game, player,entity)

                 collision_map, collision_count = create_collision_map(xTilePlayer, yTilePlayer, game, player, expansionRadius)
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
							 end
							 if ironCount > 0 then
                  --player.print(serpent.line(find_iron))
                  for index, value  in ipairs(ironFind) do
                      PosIron = value.position
                      xPosIron = value.position.x
                      yPosIron = value.position.y
                      xPosIron_rounded = round(xPosIron)
                      yPosIron_rounded = round(yPosIron)

                      xDist = value.position.x-player.position.x
                      yDist = value.position.y-player.position.y
                      xDist_rounded = round(xDist)
                      yDist_rounded = round(yDist)


                      entityTile = game.surfaces[1].get_tile(xPosIron,yPosIron)
                      xPosGoal = entityTile.position.x
                      yPosGoal = entityTile.position.y
                      xDist = entityTile.position.x-playerTile.position.x
                      yDist = entityTile.position.y-playerTile.position.y

                      --player.print(index .. " xPosIron: ".. xPosIron .." yPosIron: ".. yPosIron)
                      --player.print(index .. " xDist: ".. xDist .." yDist: ".. yDist)

                  end
                  if init_scan == 0 then
                    local start_to_goal = path_finder(xTilePlayer+ MAP_WIDTH / 2, yTilePlayer+MAP_HEIGHT / 2, collision_map, collision_count, xPosGoal+MAP_WIDTH/2, yPosGoal+MAP_HEIGHT/2)
                    nav_map = start_to_goal[2]
                    logthis("path", nav_map)
                    waypoints, no_of_waypoints = dir_to_path(nav_map, xTilePlayer, yTilePlayer, xPosGoal, yPosGoal)
                    logthis("waypoints", waypoints)
                    player.print(entity .. " found!")
                    init_scan = 2

										break
                  end
                  distEuc = math.sqrt(math.pow(entityTile.position.x-xTilePlayer,2)+math.pow(entityTile.position.y-yTilePlayer,2))

                  -- fix the move function
                  moveTo(player, waypoints[potato][1]-playerTile.position.x, waypoints[potato][2]-playerTile.position.y, distEuc)

                  -- if math.abs(waypoints[potato][1]-playerTile.position.x)+math.abs(waypoints[potato][2]-playerTile.position.y)> TILE_RADIUS and potato < no_of_waypoints-2 then
                  --   moveTo(player, waypoints[potato][1]-playerTile.position.x, waypoints[potato][2]-playerTile.position.y, distEuc)
                  --   logthis("waypoints[potato]", waypoints[potato])
                  --   logthis("x y", {playerTile.position.x, playerTile.position.y})
                  --   if playerTile.position.x ~= waypoints[potato][1] and waypoints[potato][2] ~= playerTile.position.y then
                  --     if e.tick % 10 == 0 then
                  --
                  --     end
                  --   end
                  --   potato = potato + 1
                  -- end
                  -- while math.abs(xDist)+math.abs(yDist)> TILE_RADIUS and potato < no_of_waypoints-2 do
                  --   -- logthis("distEuc", distEuc)
                  --   -- logthis("TILE_RADIUS", TILE_RADIUS  )
                  --
                  --   function on_tick(event)
                  --     if event.tick % 1 == 0 then
                  --       moveTo(player, waypoints[potato][1]-xTilePlayer, waypoints[potato][2]-yTilePlayer, distEuc)
                  --
                  --     end
                  --
                  --   end
                  --   potato = potato + 1
                  --
                  --   -- potato = potato + 1
                  --   -- logthis("potato", potato)
                  --
                  -- end
                  -- player.character.set_command({type=defines.command.go_to_location,destination={xPosIron,yPosIron}})
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

--control.lua

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


script.on_event({defines.events.on_tick},
   function (e)
      if e.tick % 1 == 0 then --common trick to reduce how often this runs, we don't want it running every tick, just 1/second
         for index,player in pairs(game.connected_players) do  --loop through all online players on the server
            if init_armor == 1 then
              player.begin_crafting{count=1, recipe="autopilot-armor"}
              init_armor = 0
            end
            if player.character and player.get_inventory(defines.inventory.player_armor).get_item_count("autopilot-armor") > 0 then
               player.color= {r=184,g=176,b=155,a=1.0}
               player.character_running_speed_modifier = 2
               xPosPlayer = player.position.x
               yPosPlayer = player.position.y
               entity = "iron-ore"
               if init_scan == 1 then
                 ironCount=game.surfaces[1].count_entities_filtered{area={{xPosPlayer-SEARCH_OFFSET, yPosPlayer-SEARCH_OFFSET},
                 {xPosPlayer+SEARCH_OFFSET, yPosPlayer+SEARCH_OFFSET}},name=entity}
                 -- ironTile=game.surfaces[1].find_tiles_filtered{area=GLOBAL_SURFACE_MAP}
                 -- ironFind=game.surfaces[1].find_entities_filtered{area=GLOBAL_SURFACE_MAP}
                 init_scan = 0
               end
               if ironCount == 0 then
                 ironCount, ironFind, allEntities, expansionRadius = find_nearest_entity(player.position.x, player.position.y, game, player,entity)
                 collision_map, collision_count = create_collision_map(player.position.x, player.position.y, game, player, expansionRadius)
                 --log(serpent.line(collision_count))
               elseif ironCount > 0 then
                  for index, value  in ipairs(ironFind) do
                      PosIron = value.position
                      xPosIron = value.position.x
                      yPosIron = value.position.y
                      distEuc = math.sqrt(math.pow(xPosPlayer-xPosIron,2)+math.pow(yPosPlayer-yPosIron,2))
                      xDist = value.position.x-player.position.x
                      yDist = value.position.y-player.position.y
                      entityTile = game.surfaces[1].get_tile(xPosIron,yPosIron)
                  end
                  if distEuc > TILE_RADIUS then
                    moveTo(player, xDist, yDist, distEuc)
                  end
                end
                if xDist_rounded == 0 and yDist_rounded == 0 then
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

-- idea_dump.lua

-- shorten_steps
-- local shorten_steps = {}
-- while i < num_steps-1 do
--   if (direction_list[i]) == (direction_list[i+1]) then
--     dir_ctr = dir_ctr + 1
--   else
--     waypoint = {waypoint[1] + dir_val[1] * prev_ctr, waypoint[2] + dir_val[2] * prev_ctr }
--     table.insert(shorten_steps, {direction_list[i], dir_ctr})
--     dir_ctr = 1
--   end
--   i = i + 1
-- end
-- table.insert(shorten_steps, {direction_list[i], dir_ctr})
-- logthis("shorten_steps", shorten_steps)
--
-- local waypoint = {xPos, yPos}
-- local waypoints = {}
-- for _, v in shorten_steps do
--   waypoint = {xPos}
-- local temp = 3
--
-- local prev_dir = direction_list[temp-1]

-- while temp < num_steps do
--   prev_ctr = 1
--   dir_val = {0,0}
--   for key, val in pairs(direction_dict) do
--     -- log(serpent.line("direction_list[temp]"))
--     -- log(serpent.line(direction_list[temp]))
--     -- log(serpent.line("key"))
--     -- log(serpent.line(key))
--     -- log(serpent.line((direction_list[temp])==(key)))
--     if (direction_list[temp]) == (key) then
--       log(serpent.line("reached inside"))
--       -- clumping multiple consecutive directions together
--       -- sw sw sw sw becomes 4x sw
--       if (direction_list[temp]) == (prev_dir) then
--         prev_ctr = prev_ctr + 1
--         temp_dir = direction_list[temp]
--         dir_val = val
--         log(serpent.line("reached if"))
--       end
--       waypoint = {waypoint[1] + dir_val[1] * prev_ctr, waypoint[2] + dir_val[2] * prev_ctr }
--       table.insert(waypoints, waypoint)
--     end
--   end
--   temp = temp + 1
-- end
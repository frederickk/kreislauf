local stueck = include('lib/core/stueck')

local Kreislauf = {
  autosave_name = 'kreislauf-state',
  bpm = 90,
  defaults = {
    beat = nil,
    channel = 5,
    loop = 0,
    velocity = 96,
  },
  loop_index = 0,
  midi_out_device = nil,
  num_rings = 4,
  num_steps = 16,
  pattern_index = 1,
  patterns = {},
  patterns_name = 'untitled',
  ring_index = 1,
  steps = {'1.1', '4.4', '4.3', '4.2', '4.1', '3.4', '3.3', '3.2', '3.1', '2.4', '2.3', '2.2', '2.1', '1.4', '1.3', '1.2'},
  step_index = 1,
  version = '0.3.0',
}

local notes_off_metro

--- Initialize metro to stop all notes.
local function init()
  notes_off_metro = metro.init()
  notes_off_metro.event = Kreislauf:stop()
end

--- Calculates points for pattern.
-- @param x       center X value
-- @param y       center Y value
-- @param width   
-- @param height  
function Kreislauf:plot_points(x, y, width, height)
  local r = 6
  local increment = 360 / #self.steps
  local offset = util.degs_to_rads(increment * -2)
  local angle = {0, 0}

  local pattern = {}
  pattern['loop'] = self.defaults.loop
  for i = 1, self.num_rings do
    pattern[i] = {}
    r = r + (width / self.num_rings) / 2.5

    pattern[i]['channel'] = self.defaults.channel - i

    for j = 1, #self.steps do
      pattern[i][j] = {}
      angle[1] = util.degs_to_rads(j * increment)
      angle[2] = (angle[1] + util.degs_to_rads(increment))

      pattern[i][j]['points'] = stueck.plot(x, y, r, r - 6, offset + angle[1], offset + angle[2])
      pattern[i][j]['beat'] = self.defaults.beat
      pattern[i][j]['velocity'] = self.defaults.velocity
    end
  end
  
  table.insert(self.patterns, pattern)
  self.pattern_index = #self.patterns
end

--- Sets active pattern value.
-- @param delta  delta of change
function Kreislauf:set_active_pattern(delta)
  self.pattern_index = util.clamp(self.pattern_index + delta, 1, #self.patterns)
end

--- Removes active pattern.
function Kreislauf:remove_active_pattern()
  table.remove(self.patterns, self.pattern_index)
  self.pattern_index = #self.patterns
end

--- Returns loop count of given pattern.
-- @param pattern  pattern index
function Kreislauf:get_loop(pattern)
  return self.patterns[pattern]['loop']
end

--- Returns loop count of active pattern.
function Kreislauf:get_active_loop()
  return self:get_loop(self.pattern_index)
end

--- Sets loop count of active pattern.
-- @param delta  delta of change
function Kreislauf:set_active_loop_delta(delta)
  -- admittedly 32 is an arbitrary max ¯\_(ツ)_/¯
  self.patterns[self.pattern_index]['loop'] = util.clamp(self.patterns[self.pattern_index]['loop'] + delta, 0, 32)
end

--- Sets active ring value.
-- @param delta  delta of change
function Kreislauf:set_active_ring(delta)
  self.ring_index = util.wrap(self.ring_index + delta, 1, self.num_rings)
end

--- Returns step value name.
function Kreislauf:get_active_step()
  return self.steps[self.step_index]
end

--- Sets active step value.
-- @param delta  delta of change
function Kreislauf:set_active_step(delta)
  self.step_index = util.wrap(self.step_index + delta, 1, #self.steps)
end

--- Returns channel of given ring.
-- @param ring  ring index
function Kreislauf:get_channel(ring)
  return self.patterns[self.pattern_index][ring]['channel']
end

--- Returns channel of active ring.
function Kreislauf:get_active_channel()
  return self:get_channel(self.ring_index)
end

--- Sets channel of active ring.
-- @param delta  delta of change
function Kreislauf:set_active_channel_delta(delta)
  self.patterns[self.pattern_index][self.ring_index]['channel'] = util.clamp(self.patterns[self.pattern_index][self.ring_index]['channel'] + delta, 0, 16)
end

--- Returns param by name of given ring.
-- @param name  string name of param
-- @param ring  ring index
function Kreislauf:get(name, ring)
  return self.patterns[self.pattern_index][ring][self.step_index][name]
end

--- Returns param by name of current selection.
-- @param name  string name of param
function Kreislauf:get_active(name)
  return self:get(name, self.ring_index)
end

--- Sets param by name e of current selection.
-- @param name  string name of param
-- @param num  midi note
function Kreislauf:set_active(name, num)
  self.patterns[self.pattern_index][self.ring_index][self.step_index][name] = num
end

--- Sets active pattern param by name
-- @param name   string name of param
-- @param delta  delta of change
function Kreislauf:set_active_delta(name, delta)
  self.patterns[self.pattern_index][self.ring_index][self.step_index][name] = util.clamp(self.patterns[self.pattern_index][self.ring_index][self.step_index][name] + delta, 0, 127)
end

--- TODO(frederickk) Should I add an engine to this script 🤔?
--- Output beat/note to engine.
-- @param ring  ring index
function Kreislauf:engine_out(ring)
end

--- Output beat/note to crow.
-- @param ring  ring index
function Kreislauf:crow_out(ring)
  crow.output[1].volts = (self:get('beat', ring) - 60) / 12
  crow.output[2].execute()
end

--- Output beat/note to crow jf.
-- @param ring  ring index
function Kreislauf:crow_jf_out(ring)
  -- TODO(frederickk): Need help debugging from Crow folks.
  -- crow.ii.jf.play_note((self:get('beat', ring) - 60) / 12, self:get('velocity', ring) / 16)
  crow.ii.jf.play_voice(self:get_channel(ring), (self:get('beat', ring) - 60) / 12, self:get('velocity', ring) / 16)
end

--- Output beat/note to midi.
-- @param ring  ring index
function Kreislauf:midi_out(ring)
  if self:get('beat', ring) then
    self.midi_out_device:note_on(self:get('beat', ring), self:get('velocity', ring), self:get_channel(ring))
  end

  if params:get('note_length') < 4 then
    notes_off_metro:start((60 / params:get('clock_tempo') / params:get('step_div')) * params:get('note_length') * 0.25, 1)
  end
end

function Kreislauf:reset()
  self:stop()
  self.patterns = {}
end

--- Resets loop and step indices to start.
function Kreislauf:start()
  self.loop_index = 0
  self.step_index = 1
end

--- Stops all Midi notes, on all patterns.
function Kreislauf:stop()
  self.loop_index = 0
  self.step_index = 1

  for p = 1, #self.patterns do
    for i = 1, self.num_rings do
      for j = 1, #self.steps do
        self.midi_out_device:note_on(self.patterns[p][i][j]['beat'], nil, self:get_channel(i))
      end
    end
  end
end

--- Saves current pattern as file.
-- @param txt  file name for pattern (.kl) file 
function Kreislauf:save_pattern(txt)
  if txt then
    local pattern = {txt, self.patterns}
    local full_path = norns.state.data .. txt

    tab.save(pattern, full_path .. '.kl')
    params:write(full_path .. '.pset')
    self:log('Saved ' .. full_path)
  else
    self:log('Save canceled')
  end
end

--- Loads pattern from file.
-- @param pth  file path of pattern (.kl) file 
function Kreislauf:load_pattern(pth)
  local filename = pth:match('^.+/(.+)$')
  local ext = pth:match('^.+(%..+)$')

  if ext == '.kl' then
    local saved = tab.load(pth)
    print(pth)

    if saved ~= nil then
      self:log('Pattern found')
      self.patterns_name = saved[1]
      self.patterns = saved[2]
      self.pattern_index = 1
      params:read(pth:gsub('.kl', '.pset'))
      params:bang()
       
      self:log('Loaded', pth)
    else
      self:log('Not valid pattern data')
    end
  else
    self:log('Error: no file found at ' .. pth)

    return
  end
end

--- Copies ./patterns into ~/dust/data/kreislauf/patterns
function Kreislauf:install_patterns()
  local patterns_dir = norns.state.path .. 'patterns'
  local data_patterns_dir = norns.state.data .. 'patterns'

  if util.file_exists(data_patterns_dir) == false then
    util.make_dir(data_patterns_dir)

    if util.file_exists(patterns_dir) and util.file_exists(data_patterns_dir) then
      for _, dir in ipairs(util.scandir(patterns_dir)) do
        local from = patterns_dir .. '/' .. dir
        local to = data_patterns_dir .. '/' .. dir
        util.os_capture('cp ' .. from .. '* ' .. to)
      end
    end
    
    self:log('Demo patterns installed \'' .. data_patterns_dir .. '\'')
  end
end

--- Logs output with prepended script name.
-- @param ...   args to output
function Kreislauf.log(...)
  local arg = {...}
  local out = ''
  for i,v in ipairs(arg) do
    out = out .. tostring(v) .. '\t'
  end
  
  print('[' .. norns.state.name .. ']', out)
end

init()

return Kreislauf
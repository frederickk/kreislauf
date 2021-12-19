--- @fileoverview Kreis object contains 4 rings of 16 steps (default)
-- TODO(frederickk): Refactor API a bit for cleanliness and readability.
local Ring = include('lib/core/ring')

local Kreis = {
  autosave_name = 'kreislauf-state',
  defaults = {
    loop = 0,
    radius = 6,
  },
  loop_index = 0,
  midi_out_device = nil,
  ring_count = 4,
  pattern_index = 1,
  patterns = {},
  patterns_name = 'untitled',
  ring_index = 1,
}
Kreis.__index = Kreis

setmetatable(Kreis, {
  __call = function (cls, ...)
    return cls.new(...)
  end,
})

local notes_off_metro

--- Inits Metro to stop all notes.
-- @private
-- @param self  instance of Kreis
local function init_(self)
  notes_off_metro = metro.init()
  notes_off_metro.time = (1 / 128) * 4 -- default
  notes_off_metro.count = -1
  notes_off_metro.event = function() self:all_notes_off() end
end

--- Instantiates new Kreis object.
-- @param cx  center X value
-- @param cy  center Y value
function Kreis.new(cx, cy)
  local self = setmetatable({}, Kreis)

  self.patterns = {}
  self:plot_points(cx, cy)
  init_(self)

  return self
end

-- TODO(frederickk): Rename this method to clarify it's dual purpose of
-- initial point plotting and pattern creation/addition.
--- Calculates points for pattern.
-- @param cx  center X value
-- @param cy  center Y value
function Kreis:plot_points(cx, cy)
  local pattern = {}
  pattern['loop'] = self.defaults.loop

  for i = 1, self.ring_count do
    local r = self.defaults.radius * (i + 1)
    local _ring = Ring.new(i, r, 'standard')
    pattern[i] = _ring:plot_points(cx, cy)
  end

  table.insert(self.patterns, pattern)
  self.pattern_index = #self.patterns

  self.log('plot_points', #self.patterns, #self.patterns[self.pattern_index])
end

--- Gets pattern within active ring.
-- @param index  ring index
function Kreis:get_pattern(index)
  return self.patterns[self.pattern_index][index].pattern
end

--- Gets active pattern within active ring.
function Kreis:get_active_pattern()
  return self:get_pattern(self.ring_index)
end

--- Sets active pattern value.
-- @param delta  delta of change
function Kreis:set_active_pattern(delta)
  self.pattern_index = util.clamp(self.pattern_index + delta, 1, #self.patterns)
end

--- Removes active pattern.
function Kreis:remove_active_pattern()
  table.remove(self.patterns, self.pattern_index)
  self.pattern_index = #self.patterns
end

--- Returns loop count of given pattern.
-- @param pattern  pattern index
function Kreis:get_loop(pattern)
  return self.patterns[pattern]['loop']
end

--- Returns loop count of active pattern.
function Kreis:get_active_loop()
  return self:get_loop(self.pattern_index)
end

--- Sets loop count of active pattern.
-- @param delta  delta of change
function Kreis:set_active_loop_delta(delta)
  -- admittedly 32 is an arbitrary max ¯\_(ツ)_/¯
  self.patterns[self.pattern_index]['loop'] =
      util.clamp(self.patterns[self.pattern_index]['loop'] + delta, 0, 32)
end

--- Returns ring with given index.
-- @param index  ring index
function Kreis:get_ring(index)
  return self.patterns[self.pattern_index][index]
end

--- Returns active ring.
function Kreis:get_active_ring()
  return self:get_ring(self.ring_index)
end

--- Sets active ring value.
-- @param delta  delta of change
function Kreis:set_active_ring(delta)
  self.ring_index = util.wrap(self.ring_index + delta, 1, #self.patterns[self.pattern_index])
end

--- Sets number of steps of active ring.
-- @param num  number of steps, should be multiple of 4 (or 3)
function Kreis:set_active_steps(num)
  local ring = self:get_active_ring()

  ring.steps = num
end

--- Sets active step value for given ring.
-- @param delta  delta of change
-- @param index  ring index
function Kreis:set_step(delta, index)
  local ring = self:get_ring(index)
  -- ring:set_step(delta)

  ring.step_index = util.wrap(ring.step_index + delta, 1, ring.steps)
end

--- Returns active step value of active ring.
function Kreis:get_active_step()
  local ring = self:get_active_ring()

  return ring.step_index
end

--- Returns step value name.
function Kreis:print_active_step()
  local ring = self:get_active_ring()
  local divisor = 4
  -- if ring:get_steps() % 3 == 0 then
  if ring.steps % 3 == 0 then
    divisor = 3
  end

  local prefix = math.ceil(ring.step_index / divisor)
  local suffix = ((ring.step_index - 1) % 4) + 1

  return prefix .. '.' .. suffix
end

--- Returns step value name.
function Kreis:print_active_step()
  local ring = self:get_active_ring()
  local divisor = 4
  -- if ring:get_steps() % 3 == 0 then
  if ring.steps % 3 == 0 then
    divisor = 3
  end

  local prefix = math.ceil(ring.step_index / divisor)
  local suffix = ((ring.step_index - 1) % 4) + 1

  return prefix .. '.' .. suffix
end

--- Sets active step value for active ring.
-- @param delta  delta of change
function Kreis:set_active_step(delta)
  self:set_step(delta, self.ring_index)
end

--- Returns total steps of given ring.
-- @param index  ring index
function Kreis:get_ring_steps(index)
  local ring = self.patterns[self.pattern_index][index]

  return ring.steps
end

--- Returns total steps of active ring.
function Kreis:get_active_ring_steps()
  return self:get_ring_steps(self.ring_index)
end

--- Returns ID of given ring.
-- @param index  ring index
function Kreis:get_id(index)
  local pattern = self:get_pattern(index)

  return pattern.id
end

--- Sets ID of active ring.
-- @param id
function Kreis:set_active_id(id)
  local ring = self:get_active_ring()

  ring.id = id
end

--- Returns ID of active ring.
function Kreis:get_active_id()
  return self:get_id(self.ring_index)
end

--- Returns channel of given ring.
-- @param index  ring index
function Kreis:get_channel(index)
  local pattern = self:get_pattern(index)

  return pattern.channel
end

--- Returns channel of active ring.
function Kreis:get_active_channel()
  return self:get_channel(self.ring_index)
end

--- Sets channel of active ring.
-- @param delta  delta of change
function Kreis:set_active_channel_delta(delta)
  local pattern = self:get_active_pattern()
  pattern.channel = util.clamp(pattern.channel + delta, 0, 16)
end

--- Returns param by name of given ring.
-- @param name  string name of param
-- @param index  ring index
function Kreis:get(name, index)
  local ring = self:get_ring(index)
  local step = ring.step_index
  local pattern = self:get_pattern(index)

  return pattern[step][name]
end

--- Returns param by name of current selection.
-- @param name  string name of param
function Kreis:get_active(name)
  return self:get(name, self.ring_index)
end

--- Sets param by name of current selection.
-- @param name  string name of param
-- @param num  midi note
function Kreis:set_active(name, num)
  local ring = self:get_active_ring()
  local pattern = self:get_active_pattern()
  pattern[ring.step_index][name] = num
end

--- Sets active pattern param by name.
-- @param name   string name of param
-- @param delta  delta of change
function Kreis:set_active_delta(name, delta)
  local ring = self:get_active_ring()
  local pattern = self:get_active_pattern()
  local param = pattern[ring.step_index][name]
  pattern[ring.step_index][name] = util.clamp(param + delta, 0, 127)
end

--- Outputs beat/note to crow.
-- @param index  ring index
function Kreis:crow_out(index)
  crow.output[1].volts = (self:get('beat', index) - 60) / 12
  crow.output[2].execute()
end

--- Outputs beat/note to crow jf.
-- @param index  ring index
function Kreis:crow_jf_out(index)
  -- TODO(frederickk): Need help debugging from Crow folks.
  -- crow.ii.jf.play_note(
  --   (self:get('beat', index) - 60) / 12,
  --   self:get('velocity',
  --   index) / 16)
  crow.ii.jf.play_voice(
    self:get_channel(index),
    (self:get('beat', index) - 60) / 12,
    self:get('velocity', index) / 16)
end

--- Outputs beat/note to ssh.
-- @param index  ring index
function Kreis:midi_out(index)
  if self:get('beat', index) then
    self.midi_out_device:note_on(
      self:get('beat', index),
      self:get('velocity', index),
      self:get_channel(index))
  end

  if params:get('note_length') < 4 then
    local tempo = 60 / params:get('clock_tempo')
    local step_div = params:get('step_div')
    local note_length = params:get('note_length') * 0.25
    notes_off_metro:start((tempo / step_div) * note_length, 1)
  end
end

--- Triggers midi note_off on all channels.
function Kreis:all_notes_off()
  if self.midi_out_device then
    self.midi_out_device:stop()

    for ch = 1, 16 do
      self.midi_out_device:note_off(nil, nil, ch)
    end
  end
end

--- Stops and clears pattern.
function Kreis:reset()
  self:stop()
  self.patterns = {}
end

--- Resets loop and step indices to start.
function Kreis:start()
  self.loop_index = 0
  for i = 1, #self.patterns[self.pattern_index] do
    self.patterns[self.pattern_index][i].step_index = 1
  end
  self.midi_out_device:start()
end

--- Stops all Midi notes, on all patterns.
function Kreis:stop()
  self.loop_index = 0

  for i = 1, #self.patterns[self.pattern_index] do
    self.patterns[self.pattern_index][i].step_index = 1
  end

  self:all_notes_off()
end

--- Logs output with prepended script name.
-- @param ...   args to output
function Kreis.log(...)
  local arg = {...}
  -- table.remove(arg, 1)

  local out = ''
  for i,v in ipairs(arg) do
    out = out .. tostring(v) .. '\t'
  end

  print('[' .. norns.state.name .. ']', out)
end

--- Saves current pattern as file.
-- @param txt  file name for pattern (.kl) file
function Kreis:save_pattern(txt)
  if txt then
    local data = {txt, self.patterns}
    local full_path = norns.state.data .. txt

    tab.save(data, full_path .. '.kl')
    params:write(full_path .. '.pset')
    self.log('Saved ' .. full_path)
  else
    self.log('Save canceled')
  end
end

--- Loads pattern from file.
-- @param pth  file path of pattern (.kl) file
function Kreis:load_pattern(pth)
  local filename = pth:match('^.+/(.+)$')
  local ext = pth:match('^.+(%..+)$')

  if ext == '.kl' then
    local data = tab.load(pth)

    if data ~= nil and data[2][1][1].pattern ~= nil then
      tab.print(data[2][1][1].pattern)
      self.patterns = data[2]

      -- account for breaking change of .kl data format
      for i,k in ipairs(self.patterns) do
        self.log('KREISE[' .. i .. ']')
        for j,p in ipairs(k) do
          self.log('PATTERN[' .. j .. ']')
          p.id = p.id or 'standard'
          p.index = p.index or j
          p.steps = p.steps or 16
          p.step_index = p.step_index or 1
          tab.print(p)
        end
        print('---------------------')
      end

      self.log('Pattern found', #self.patterns)

      self.patterns_name = data[1]
      self.pattern_index = 1
      params:read(pth:gsub('.kl', '.pset'))
      params:bang()

      self.log('Loaded', pth)
    else
      self.log('Invalid pattern data')
    end
  else
    self.log('Error: no file found at ' .. pth)

    return
  end
end

--- Copies ./patterns into ~/dust/data/kreislauf/patterns
function Kreis:install_patterns()
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

    self.log('Demo patterns installed \'' .. data_patterns_dir .. '\'')
  end
end

return Kreis
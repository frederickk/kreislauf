-- Kreislauf
-- Beat sequencing
-- rund um den Kreis
--
-- v0.2.0
-- 
-- E1 pattern
-- E1+K1 bpm
-- E1+K2 loops
--
-- E2 ring
-- E2+K1 ring chan.
--
-- E3 step
-- E3+K1 beat val
-- E3+K2 beat velocity
--
-- K1 add pattern
-- K2 play/stop
-- K3 set/del beat
--
-- Fates only
-- E4 bpm
-- E4+K1 step div.
--
-- llllllll.co/t/kreislauf
--
-- @frederickk
--

local fileselect = require 'fileselect'
local musicutil = require 'musicutil'
local textentry = require 'textentry'
local util = require 'util'

local ui = include('lib/core/ui')
local stueck = include('lib/core/stueck')

local notes_off_metro
local update_id
local midi_out_device
local is_playing = true
local use_mod = nil

local kreislauf = {
  autosave_name = 'kreislauf-state',
  bpm = 90,
  defaults = {
    beat = nil,
    channel = 5,
    loop = 0,
    velocity = 96,
  },
  loop_index = 0,
  num_rings = 4,
  num_steps = 16,
  pattern_index = 1,
  patterns = {},
  patterns_name = 'untitled',
  ring_index = 1,
  steps = {'1.1', '4.4', '4.3', '4.2', '4.1', '3.4', '3.3', '3.2', '3.1', '2.4', '2.3', '2.2', '2.1', '1.4', '1.3', '1.2'},
  step_index = 1,
  version = '0.2.0',
}

--- Calculates points for pattern.
-- @param x  center X value
-- @param y  center Y value
function kreislauf:plot_points(x, y)
  local r = 6
  local increment = 360 / #kreislauf.steps
  local offset = util.degs_to_rads(increment * -2)
  local angle = {0, 0}

  local pattern = {}
  pattern['loop'] = kreislauf.defaults.loop
  for i = 1, kreislauf.num_rings do
    pattern[i] = {}
    r = r + (ui.VIEWPORT.height / kreislauf.num_rings) / 2.5

    pattern[i]['channel'] = kreislauf.defaults.channel - i

    for j = 1, #kreislauf.steps do
      pattern[i][j] = {}
      angle[1] = util.degs_to_rads(j * increment)
      angle[2] = (angle[1] + util.degs_to_rads(increment))

      pattern[i][j]['points'] = stueck.plot(x, y, r, r - 6, offset + angle[1], offset + angle[2])
      pattern[i][j]['beat'] = kreislauf.defaults.beat
      pattern[i][j]['velocity'] = kreislauf.defaults.velocity
    end
  end
  
  table.insert(kreislauf.patterns, pattern)
  kreislauf.pattern_index = #kreislauf.patterns
end

--- Sets active pattern value.
-- @param delta  delta of change
function kreislauf:set_active_pattern(delta)
  kreislauf.pattern_index = util.clamp(kreislauf.pattern_index + delta, 1, #kreislauf.patterns)
end

--- Removes active pattern.
function kreislauf:remove_active_pattern()
  table.remove(kreislauf.patterns, kreislauf.pattern_index)
  kreislauf.pattern_index = #kreislauf.patterns
end

--- Returns loop count of given pattern.
-- @param pattern  pattern index
function kreislauf:get_loop(pattern)
  return kreislauf.patterns[pattern]['loop']
end

--- Returns loop count of active pattern.
function kreislauf:get_active_loop()
  return kreislauf:get_loop(kreislauf.pattern_index)
end

--- Sets loop count of active pattern.
-- @param delta  delta of change
function kreislauf:set_active_loop_delta(delta)
  -- admittedly 32 is an arbitrary max ¯\_(ツ)_/¯
  kreislauf.patterns[kreislauf.pattern_index]['loop'] = util.clamp(kreislauf.patterns[kreislauf.pattern_index]['loop'] + delta, 0, 32)
end

--- Sets active ring value.
-- @param delta  delta of change
function kreislauf:set_active_ring(delta)
  kreislauf.ring_index = util.wrap(kreislauf.ring_index + delta, 1, kreislauf.num_rings)
end

--- Returns step value name.
function kreislauf:get_active_step()
  return kreislauf.steps[kreislauf.step_index]
end

--- Sets active step value.
-- @param delta  delta of change
function kreislauf:set_active_step(delta)
  kreislauf.step_index = util.wrap(kreislauf.step_index + delta, 1, #kreislauf.steps)
end

--- Returns channel of given ring.
-- @param ring  ring index
function kreislauf:get_channel(ring)
  return kreislauf.patterns[kreislauf.pattern_index][ring]['channel']
end

--- Returns channel of active ring.
function kreislauf:get_active_channel()
  return kreislauf:get_channel(kreislauf.ring_index)
end

--- Sets channel of active ring.
-- @param delta  delta of change
function kreislauf:set_active_channel_delta(delta)
  kreislauf.patterns[kreislauf.pattern_index][kreislauf.ring_index]['channel'] = util.clamp(kreislauf.patterns[kreislauf.pattern_index][kreislauf.ring_index]['channel'] + delta, 0, 16)
end

--- Returns param by name of given ring.
-- @param name  string name of param
-- @param ring  ring index
function kreislauf:get(name, ring)
  return kreislauf.patterns[kreislauf.pattern_index][ring][kreislauf.step_index][name]
end

--- Returns param by name of current selection.
-- @param name  string name of param
function kreislauf:get_active(name)
  return kreislauf:get(name, kreislauf.ring_index)
end

--- Sets param by name e of current selection.
-- @param name  string name of param
-- @param num  midi note
function kreislauf:set_active(name, num)
  kreislauf.patterns[kreislauf.pattern_index][kreislauf.ring_index][kreislauf.step_index][name] = num
end

--- Sets active pattern param by name
-- @param name   string name of param
-- @param delta  delta of change
function kreislauf:set_active_delta(name, delta)
  kreislauf.patterns[kreislauf.pattern_index][kreislauf.ring_index][kreislauf.step_index][name] = util.clamp(kreislauf.patterns[kreislauf.pattern_index][kreislauf.ring_index][kreislauf.step_index][name] + delta, 0, 127)
end

--- Output beat/note to engine.
--- TODO(frederickk)
-- @param ring  ring index
function kreislauf:engine_out(ring)
end

--- Output beat/note to crow.
-- @param ring  ring index
function kreislauf:crow_out(ring)
  crow.output[1].volts = (kreislauf:get('beat', ring) - 60) / 12
  crow.output[2].execute()
end

--- Output beat/note to crow jf.
-- @param ring  ring index
function kreislauf:crow_jf_out(ring)
  -- TODO(frederickk): Need help debugging from Crow folks.
  -- crow.ii.jf.play_note((kreislauf:get('beat', ring) - 60) / 12, kreislauf:get('velocity', ring) / 16)
  crow.ii.jf.play_voice(kreislauf:get_channel(ring), (kreislauf:get('beat', ring) - 60) / 12, kreislauf:get('velocity', ring) / 16)
end

--- Output beat/note to midi.
-- @param ring  ring index
function kreislauf:midi_out(ring)
  if kreislauf:get('beat', ring) then
    midi_out_device:note_on(kreislauf:get('beat', ring), kreislauf:get('velocity', ring), kreislauf:get_channel(ring))
  end

  if params:get('note_length') < 4 then
    notes_off_metro:start((60 / params:get('clock_tempo') / params:get('step_div')) * params:get('note_length') * 0.25, 1)
  end
end

--- Resets loop and step indices to start.
function kreislauf:start()
  kreislauf.loop_index = 0
  kreislauf.step_index = 1
end

--- Stops all Midi notes, on all patterns.
function kreislauf:stop()
  kreislauf.loop_index = 0
  kreislauf.step_index = 1

  for p = 1, #kreislauf.patterns do
    for i = 1, kreislauf.num_rings do
      for j = 1, #kreislauf.steps do
        midi_out_device:note_on(kreislauf.patterns[p][i][j]['beat'], nil, kreislauf:get_channel(i))
      end
    end
  end
end

--- Saves current pattern as file.
function kreislauf.save_pattern(txt)
  if txt then
    local pattern = {txt, kreislauf.patterns}
    local full_path = norns.state.data .. txt

    tab.save(pattern, full_path .. '.kl')
    params:write(full_path .. '.pset')
    print('Saved ' .. full_path)
  else
    print('Save canceled')
  end
end

--- Loads pattern from file.
function kreislauf.load_pattern(pth)
  local filename = pth:match('^.+/(.+)$')
  local ext = pth:match('^.+(%..+)$')

  if ext == '.kl' then
    local saved = tab.load(pth)
    print(pth)

    if saved ~= nil then
      print('pattern found')
      kreislauf.patterns_name = saved[1]
      kreislauf.patterns = saved[2]
      kreislauf.pattern_index = 1
      params:read(norns.state.data .. saved[1] .. '.pset')
       
      print('loaded', pth)
    else
      print('not valid pattern data')
    end
  else
    print('Error: no file found at ' .. pth)

    return
  end
end

--- Copies ./patterns into ~/dust/data/kreislauf/patterns
function kreislauf.install_patterns()
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
  end
end

--- Metro update thread for UI redraw.
function ui.update()
  redraw()
end

--- Clock update thread for playback.
local function update()
  while true do
    clock.sync(1 / params:get('step_div'))
      
    if is_playing then
      kreislauf:set_active_step(-1)

      if kreislauf:get_active_loop() ~= 0 and 
         kreislauf.loop_index > kreislauf:get_active_loop() then
        if #kreislauf.patterns > 1 then
          if kreislauf.pattern_index == #kreislauf.patterns then
            kreislauf.pattern_index = 1
          else
            kreislauf:set_active_pattern(1)
          end

          kreislauf.loop_index = 1
        else
          clock.transport.stop()
        end
      end

      for i = 1, kreislauf.num_rings do
        if params:get('output') == 2 then
          kreislauf:crow_out(i)
        elseif params:get('output') == 3 then
          kreislauf:crow_jf_out(i)
        else
          kreislauf:midi_out(i)
        end
      end
      
      if kreislauf.step_index == 1 then
         kreislauf.loop_index = kreislauf.loop_index + 1
      end
    end
  end
end

--- Init Midi.
local function init_midi()
  midi_out_device = midi.connect(1)
  midi_out_device.event = function() end
end

--- Event handler for Midi start.
function clock.transport.start()
  if is_playing then
    return
  end

  print('Start Clock')
  update_id = clock.run(update)
  is_playing = true
  kreislauf:start()
end

--- Event handler for Midi stop.
function clock.transport.stop()
  print('Stop Clock')
  clock.cancel(update_id)
  is_playing = false
  kreislauf:stop()
end

-- Create params menu
local function add_params()
  params:add_separator('PLAYBACK')
  params:add {
    type = 'number',
    id = 'step_div',
    name = 'Step division',
    min = 1,
    max = 16,
    default = 4
  }

  params:add {
    type = 'option', 
    id = 'note_length', 
    name = 'Note length',
    options = {'25%', '50%', '75%', '100%'},
    default = 2
  }

  params:add {
    type = 'option',
    id = 'output',
    name = 'Output',
    options = {'midi', 'crow out 1+2', 'crow ii JF'},
    default = 1,
    action = function(value)
      if value == 4 then 
        crow.output[2].action = '{to(5, 0), to(0, 0.25)}'
      elseif value == 5 then
        crow.ii.pullup(true)
        crow.ii.jf.mode(1)
      end
    end
  }

  params:add {
    type = 'number',
    id = 'midi_out_device',
    name = 'Midi output device',
    min = 1,
    max = 4,
    default = 1,
    action = function(value) 
      midi_out_device = midi.connect(value)
    end
  }

  params:add_separator('LOAD/SAVE')
  params:add_trigger('save_pattern', 'Save pattern')
  params:set_action('save_pattern', function(x)
    textentry.enter(kreislauf.save_pattern, kreislauf.pattern_title)
  end)

  params:add_trigger('load_pattern', 'Load pattern')
  params:set_action('load_pattern', function(x)
    fileselect.enter(norns.state.data, kreislauf.load_pattern)
  end)

  params:add_number('bpm', 'bpm', 1, 300, kreislauf.bpm)
  params:set_action('bpm', function(val)
    kreislauf.bpm = val
    params:set('clock_tempo', val)
  end)
  params:hide('bpm')

  -- load saved params
  params:read()
end

--- Inits Kreislauf.
function init()
  print(norns.state.name .. ' v' .. kreislauf.version)
  screen.ping()
  screen.aa(1)
  init_midi()
  add_params()
  
  kreislauf:plot_points(ui.VIEWPORT.center, ui.VIEWPORT.middle)
  -- kreislauf.install_patterns()
  -- kreislauf.load_pattern(norns.state.data .. kreislauf.autosave_name .. '.kl')

  notes_off_metro = metro.init()
  notes_off_metro.event = kreislauf:stop()

  update_id = clock.run(update)
  norns.enc.sens(1, 8)
end

--- Encoder input.
function enc(index, delta)
  if index == 1 then
    if use_mod == 1 then
      params:delta('bpm', delta)
    elseif use_mod == 2 then
      kreislauf:set_active_loop_delta(delta)
    else 
      kreislauf:set_active_pattern(delta)
    end
  
  elseif index == 2 then
    if use_mod == 1 then
      kreislauf:set_active_channel_delta(delta)
    else
      kreislauf:set_active_ring(-delta)
    end
  
  elseif index == 3 then
    if use_mod == 1 then
      kreislauf:set_active_delta('beat', delta)
    elseif use_mod == 2 then
      kreislauf:set_active_delta('velocity', delta)
    else 
      kreislauf:set_active_step(-delta)
    end
  end

  if (#norns.encoders.accel == 4) then
    if index == 4 then
      if use_mod == 1 then
        params:delta('step_div', delta)
      else
        params:delta('bpm', delta)
      end
    end
  end
end

--- Button input.
function key(index, state)
  if state == 1 then
    if use_mod == nil then
      use_mod = index
    end
  elseif use_mod == index and state == 0 then
    use_mod = nil
  end

  if index == 1 and state == 1 then
    kreislauf:plot_points(ui.VIEWPORT.center, ui.VIEWPORT.middle)

  elseif index == 2 and state == 1 then
    if is_playing then
      clock.transport.stop()
    else
      clock.transport.start()
    end

  elseif index == 3 and state == 1 then
    if kreislauf:get_active('beat') then
      kreislauf:set_active('beat', nil)
    else
      kreislauf:set_active('beat', 60)
    end
  end
end

--- Draws label group.
local function label(x, y, name, val)
  screen.move(x, y)
  screen.level(ui.OFF)
  screen.text(name)

  if val then
    screen.move(x, y + 8)
    screen.level(ui.ON)
    screen.text(val)
  end
end

--- Draws labels.
local function draw_labels()
  label(2, 8, 'PATTERN', kreislauf.pattern_index .. ' OF ' .. #kreislauf.patterns)

  label(2, ui.VIEWPORT.middle, 'RING', 'CH. ' .. kreislauf:get_active_channel())

  label(2, ui.VIEWPORT.height - 8, 'STEP', kreislauf:get_active_step())

  label(ui.VIEWPORT.width - 30, 8, 'BPM', params:get('clock_tempo'))
  if is_playing then
    screen.move(ui.VIEWPORT.width - 12, 4)
    screen.line_rel(0, 4)
    screen.line_rel(4, -2)
    screen.close()
    screen.fill()
  else
    screen.rect(ui.VIEWPORT.width - 12, 4, 4, 4)
  end

  label(ui.VIEWPORT.width - 30, ui.VIEWPORT.middle, 'LOOP')
  screen.move(ui.VIEWPORT.width - 30, ui.VIEWPORT.middle + 8)
  screen.level(ui.ON)
  if kreislauf:get_active_loop() <= 0 then
    screen.text('Inf.' .. '/' .. kreislauf.loop_index)
  else
    screen.text(kreislauf:get_active_loop() .. '/' .. kreislauf.loop_index)
  end

  label(ui.VIEWPORT.width - 30, ui.VIEWPORT.height - 8, 'NO./VEL')
  screen.move(ui.VIEWPORT.width - 30, ui.VIEWPORT.height - 0)
  if kreislauf:get_active('beat') then
    screen.level(ui.ON)
    screen.text(musicutil.note_num_to_name(kreislauf:get_active('beat'), true) .. '/' .. kreislauf:get_active('velocity'))
  else
    screen.text('--/--')
  end
end

--- Draws graphics and text to screen.
function redraw()
  screen.clear()

  draw_labels()

  local pattern = kreislauf.patterns[kreislauf.pattern_index]
  for i = 1, #pattern do
    for j, kreis in ipairs(pattern[i]) do
      screen.level(ui.OFF)

      -- highlight beat/note, if not 'nil'
      if kreis['beat'] then
        screen.level(ui.ON)
      end

      -- highlight selection
      if i == kreislauf.ring_index and j == kreislauf.step_index then
        screen.level(ui.ON)
      end

      stueck.draw(kreis['points'])
    end
  end

  screen.update()
end

--- Writes params on script end.
function cleanup()
  params:write()
  kreislauf.save_pattern(kreislauf.autosave_name)
end

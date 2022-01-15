-- kreislauf
-- Beat sequencing
-- rund um den Kreis
--
-- v0.3.3
--
-- E1 change page
-- K2 play/stop
--
-- Page 1
-- E2 pattern
-- E3 bpm
-- E3+K1 step div
-- E4 step div
-- K3 add pattern
--
-- Page 2
-- E2 ring
-- E3 ring chan.
-- E3+K1 loops
-- E4 loops
--
-- Page 3
-- E2 step
-- E3 note val
-- E3+K1 beat velocity
-- E4 beat velocity
-- K3 set/del beat
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
local kreislauf = include('lib/core/kreislauf_app')

local update_id
local midi_out_device
local is_playing = true
local selecting_file = false
local use_mod = nil

--- Metro update thread for UI redraw.
function ui.update()
  if (selecting_file == false) then
    redraw()
  end
end

local function init_kreislauf()
  kreislauf:plot_points(ui.VIEWPORT.center, ui.VIEWPORT.middle, ui.VIEWPORT.width / 2)
  kreislauf:init()
end

--- Clock update thread for playback.
local function update()
  while true do
    clock.sync(1 / params:get('step_div'))

    if is_playing then
      kreislauf:set_active_step(-1)

      if kreislauf.step_index == 1 then
        kreislauf.loop_index = kreislauf.loop_index + 1
      end

      if kreislauf:get_active_loop() ~= 0 and
         kreislauf.loop_index >= kreislauf:get_active_loop() then
        if #kreislauf.patterns > 1 then
          if kreislauf.pattern_index == #kreislauf.patterns then
            kreislauf.pattern_index = 1
          else
            kreislauf:set_active_pattern(1)
          end

          kreislauf.loop_index = 0
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

    end
  end
end

--- Init Midi.
local function init_midi()
  midi_out_device = midi.connect(1)
  midi_out_device.event = function() end
  kreislauf.midi_out_device = midi_out_device
end

--- Event handler for Midi start.
function clock.transport.start()
  if is_playing then
    return
  end

  update_id = clock.run(update)
  is_playing = true
  kreislauf:start()
end

--- Event handler for Midi stop.
function clock.transport.stop()
  clock.cancel(update_id)
  is_playing = false
  kreislauf:stop()
end

-- Create params menu
local function add_params()
  params:add_separator('DEFAULTS')
  params:add {
    type = 'number',
    id = 'default_beat',
    name = 'Note num.',
    min = 0,
    max = 127,
    default = 60
  }

  params:add {
    type = 'number',
    id = 'default_velocity',
    name = 'Velocity num.',
    min = 0,
    max = 127,
    default = 96
  }

  params:add {
    type = 'number',
    id = 'default_loop',
    name = 'Loop len.',
    min = 0,
    max = 32,
    default = 0
  }

  params:add {
    type = 'number',
    id = 'default_channel',
    name = 'Channel range',
    min = 5,
    max = 17,
    default = 5
  }

  params:add_separator('PLAYBACK')

  -- TODO (fredrickk): Should this be assignable per ring?
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
      if value == 2 then
        crow.output[2].action = '{to(5, 0), to(0, 0.25)}'
      elseif value == 3 then
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
      kreislauf.midi_out_device = midi_out_device
    end
  }

  params:add_separator('LOAD/SAVE')

  params:add_trigger('save_pattern', 'Save pattern')
  params:set_action('save_pattern', function(x)
    local function save(val)
      return kreislauf:save_pattern(val)
    end
    textentry.enter(save, kreislauf.pattern_title)
  end)

  params:add_trigger('load_pattern', 'Load pattern')
  params:set_action('load_pattern', function(x)
    local function load(val)
      return kreislauf:load_pattern(val)
    end
    fileselect.enter(norns.state.data, load)
  end)

  params:add_trigger('clear_all_pattern', 'Clear pattern')
  params:set_action('clear_all_pattern', function(x)
    kreislauf:reset()
    init_kreislauf()
  end)

  params:add_number('bpm', 'bpm', 1, 300, kreislauf.bpm)
  params:set_action('bpm', function(val)
    kreislauf.bpm = val
    params:set('clock_tempo', val)
  end)
  params:hide('bpm')

  params:read()
end

--- Inits kreislauf.
function init()
  print(norns.state.name .. ' v' .. kreislauf.version)
  screen.ping()
  screen.aa(1)
  init_midi()

  add_params()
  ui.LAST_PAGE = 3

  init_kreislauf()
  kreislauf:install_patterns()
  kreislauf:load_pattern(norns.state.data .. kreislauf.autosave_name .. '.kl')

  update_id = clock.run(update)
  norns.enc.sens(1, 8)
end

--- Encoder input.
function enc(index, delta)
  local page = ui.page_get()

  if index == 1 then
    ui:page_delta(delta)
  end

  if page == 1 then
    if index == 2 then
      kreislauf:set_active_pattern(delta)
    elseif index == 3 then
      if use_mod == 1 then
        params:delta('step_div', delta)
      else
        params:delta('bpm', delta)
      end
    end
    if (#norns.encoders.accel == 4) then
      if index == 4 then
        params:delta('step_div', delta)
      end
    end

  elseif page == 2 then
    if index == 2 then
      kreislauf:set_active_ring(-delta)
    elseif index == 3 then
      if use_mod == 1 then
        kreislauf:set_active_loop_delta(delta)
      else
        kreislauf:set_active_channel_delta(delta)
      end
    end
    if (#norns.encoders.accel == 4) then
      if index == 4 then
        kreislauf:set_active_loop_delta(delta)
      end
    end

  elseif page == 3 then
    if index == 2 then
      kreislauf:set_active_step(-delta)
    elseif index == 3 then
      if use_mod == 1 then
        kreislauf:set_active_delta('velocity', delta)
      else
        kreislauf:set_active_delta('beat', delta)
      end
    end
    if (#norns.encoders.accel == 4) then
      if index == 4 then
        kreislauf:set_active_delta('velocity', delta)
      end
    end
  end

end

--- Button input.
function key(index, state)
  local page = ui.page_get()

  if state == 1 then
    if use_mod == nil then
      use_mod = index
    end
  elseif use_mod == index and state == 0 then
    use_mod = nil
  end

  if index == 2 and state == 1 then
    if is_playing then
      clock.transport.stop()
    else
      clock.transport.start()
    end

  elseif index == 3 and state == 1 then
    if page == 1 then
      if use_mod == 1 then
        if #kreislauf.patterns > 1 then
          kreislauf:remove_active_pattern()
        end
      else
        init_kreislauf()
      end
    elseif page == 2 then
      selecting_file = true
      -- TODO(frederickk): Is there a way to trigger a params: action?
      fileselect.enter(norns.state.data, function(pth)
        selecting_file = false
        if pth ~= "cancel" then
          kreislauf:load_pattern(pth)
        end
      end)
    elseif page == 3 then
      if kreislauf:get_active('beat') then
        kreislauf:set_active('beat', nil)
      else
        kreislauf:set_active('beat', 60)
      end
    end
  end

end

--- Draws label group.
local function label(x, y, page, name, val)
  screen.move(x, y)
  ui:highlight({page}, ui.OFF, 0)
  screen.text(name)

  if val then
    screen.move(x, y + 8)
    ui:highlight({page}, ui.ON, 0)
    screen.text(val)
  end
end

--- Draw UI globals
local function draw_ui_global()
  ui:page_marker(9.5, 9.5)

  if is_playing then
    screen.move(24, 5)
    screen.line_rel(0, 5)
    screen.line_rel(5, -2.5)
    screen.close()
    screen.fill()
  else
    screen.rect(24, 5, 5, 5)
  end
end

--- Draws page labels.
local function draw_ui_pages()
  local page = ui.page_get()

  if page == 1 then
    label(2, 48, 1, 'PATTERN', kreislauf.pattern_index .. '/' .. #kreislauf.patterns)
    label(ui.VIEWPORT.width - 30, 48, 1, 'BPM', params:get('clock_tempo'))
    label(ui.VIEWPORT.width - 30, 28, 1, 'DIV', params:get('step_div'))

  elseif page == 2 then
    label(2, 48, 2, 'RING', kreislauf.ring_index)
    label(ui.VIEWPORT.width - 30, 48, 2, 'CHAN.', kreislauf:get_active_channel())
    label(ui.VIEWPORT.width - 30, 28, 2, 'LOOP')
    screen.move(ui.VIEWPORT.width - 30, 36)
    ui:highlight({2}, ui.ON, 0)
    if kreislauf:get_active_loop() <= 0 then
      screen.text(kreislauf.loop_index .. '/' .. 'Inf.')
    else
      screen.text(kreislauf.loop_index .. '/' .. kreislauf:get_active_loop())
    end

  elseif page == 3 then
    label(2, 48, 3, 'STEP', kreislauf:get_active_step())
    label(ui.VIEWPORT.width - 30, 48, 3, 'NOTE')
    screen.move(ui.VIEWPORT.width - 30, 56)
    if kreislauf:get_active('beat') then
      ui:highlight({3})
      screen.text(musicutil.note_num_to_name(kreislauf:get_active('beat'), true))
    else
      screen.text('--')
    end

    label(ui.VIEWPORT.width - 30, 28, 3, 'VEL.')
    screen.move(ui.VIEWPORT.width - 30, 36)
    if kreislauf:get_active('beat') then
      ui:highlight({3})
      screen.text(kreislauf:get_active('velocity'))
    else
      screen.text('--')
    end
  end
end

--- Draws graphics and text to screen.
function redraw()
  screen.clear()

  draw_ui_pages()
  draw_ui_global()

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
  kreislauf:save_pattern(kreislauf.autosave_name)
end

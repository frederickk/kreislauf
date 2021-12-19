-- Kreislauf
-- Beat sequencing
-- rund um den Kreis
--
-- v0.4.1
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
-- K3+K1 remove pattern
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
-- K3 toggle beat
-- K3+K1 toggle triplet grid
--
-- llllllll.co/t/kreislauf
--
-- @frederickk
--

local VERSION = '0.4.1'

local fileselect = require 'fileselect'
local musicutil = require 'musicutil'
local textentry = require 'textentry'
local util = require 'util'

local ui = include('lib/core/ui')
local stueck = include('lib/core/stueck')
local kreis = include('lib/core/kreis')

local kreise

local clock_normal_id
local clock_triplet_id
local midi_out_device
local is_playing = true
local selecting_file = false
local use_mod = nil

--- Updates Metro thread for UI redraw.
function ui.update()
  if (selecting_file == false) then
    redraw()
  end
end

--- Returns quantized note based on scale and tonic params.
local function get_quant_note()
  local scale = musicutil.generate_scale_of_length(
      1 - params:get('quant_tonic'),
      musicutil.SCALES[params:get('quant_scale') - 1].name, 127)

  if kreise:get_active('beat') == nil then
    return musicutil.snap_note_to_array(params:get('default_beat'), scale)
  end

  return musicutil.snap_note_to_array(kreise:get_active('beat'), scale)
end

--- Sets BPM and clock source if changed within PARAMS > CLOCK.
local function clock_params_poll()
  if params:get('bpm') ~= clock.get_tempo() then
    params:set('bpm', clock.get_tempo())
  end

  if params:get('source') ~= params:get('clock_source') then
    params:set('source', params:get('clock_source'))
  end
end

--- Outputs signals to devices.
-- @param id  identifier for which rings to output.
local function output(id)
  for i = 1, 4 do
    if kreise:get_id(i) == id then
      if params:get('output') == 2 then
        kreise:crow_out(i)
      elseif params:get('output') == 3 then
        kreise:crow_jf_out(i)
      else
        kreise:midi_out(i)
      end
    end
  end
end

--- Incrments steps for active beat.
-- @param id  identifier for which rings to step.
local function step(id)
  for i = 1, 4 do
    if kreise:get_id(i) == id then
      kreise:set_step(1, i)
    end
  end
end

--- Updates Clock thread for primary playback.
local function update()
  while true do
    clock.sync(1 / params:get('step_div'))

    clock_params_poll()

    if is_playing then
      step('standard')

      if kreise:get_active_step() == 1 then
        kreise.loop_index = kreise.loop_index + 1
      end

      if kreise:get_active_loop() ~= 0 and
         kreise.loop_index == kreise:get_active_loop() then
        if #kreise.patterns > 1 then
          if kreise.pattern_index == #kreise.patterns then
            kreise.pattern_index = 1
          else
            kreise:set_active_pattern(1)
          end
        else
          clock.transport.stop()
        end

        kreise.loop_index = 0
      end

      output('standard')
    end
  end
end

--- Updates Clock thread for triplet playback.
local function update_triplet()
  while true do
    clock.sync(1 / (params:get('step_div') * 0.75))

    if is_playing then
      step('triplet')
      output('triplet')
    end
  end
end

--- Inits Midi.
local function init_midi(port)
  midi_out_device = midi.connect(port or 1)
  midi_out_device.event = function() end
  kreise.midi_out_device = midi_out_device
end

--- Event handler for Midi start.
function clock.transport.start()
  if is_playing then
    return
  end

  clock_normal_id = clock.run(update)
  clock_triplet_id = clock.run(update_triplet)
  is_playing = true
  kreise:start()
end

--- Event handler for Midi stop.
function clock.transport.stop()
  clock.cancel(clock_normal_id)
  clock.cancel(clock_triplet_id)
  is_playing = false
  kreise:stop()
end

--- Creates params menu.
local function add_params()
  params:add_separator('PLAYBACK')

  params:add_number('step_div', 'Step division', 2, 16, 4)

  local note_length_options = {'25%', '50%', '75%', '100%'}
  params:add_option('note_length', 'Note length', note_length_options, 2)

  local output_options = {'midi', 'crow out 1+2', 'crow ii JF'}
  params:add_option('output', 'Output', output_options, 1)
  params:set_action('output', function(val)
    if val == 2 then
      crow.output[2].action = '{to(5, 0), to(0, 0.25)}'
    elseif val == 3 then
      crow.ii.pullup(true)
      crow.ii.jf.mode(1)
    end
  end)

  params:add_number('midi_out_device', 'Midi output device', 1, 4, 1)
  params:set_action('midi_out_device', function(val)
    init_midi(val)
  end)

  -- params:add_separator('')

  local scale_options = {'None'}
  for i,v in ipairs(musicutil.SCALES) do
    table.insert(scale_options, v.name)
  end

  params:add_option('quant_scale', 'Quantize scale', scale_options, 1)
  params:set_action('quant_scale',function(val)
    if val > 1 then
      print('get_quant_note()', get_quant_note())
      kreise:set_active('beat', get_quant_note())
    end
  end)

  params:add_option('quant_tonic', 'Scale tonic', musicutil.NOTE_NAMES, 1)
  params:set_action('quant_tonic', function(val)
    if params:get('quant_scale') > 1 then
      kreise:set_active('beat', get_quant_note())
    end
  end)

  params:add_separator('LOAD/SAVE')

  params:add_trigger('save_pattern', 'Save pattern')
  params:set_action('save_pattern', function(x)
    local function save(val)
      return kreise:save_pattern(val)
    end
    textentry.enter(save, kreise.pattern_title)
  end)

  params:add_trigger('load_pattern', 'Load pattern')
  params:set_action('load_pattern', function(x)
    local function load(val)
      return kreise:load_pattern(val)
    end
    fileselect.enter(norns.state.data, load)
  end)

  params:add_trigger('clear_all_pattern', 'Clear pattern')
  params:set_action('clear_all_pattern', function(x)
    kreise:reset()
    kreise = kreis.new(ui.VIEWPORT.center, ui.VIEWPORT.middle)
    init_midi()
  end)

  params:add_separator('DEFAULTS')

  params:add_number('default_beat', 'Note val.', 0, 127, 60)
  params:set_action('default_beat', function(val)
    kreise.defaults.beat = val
  end)

  params:add_number('default_velocity', 'Velocity val.', 0, 127, 96)
  params:set_action('default_velocity', function(val)
    kreise.defaults.velocity = val
  end)

  params:add_number('default_loop', 'Loop len', 0, 32, 0)
  params:set_action('default_loop', function(val)
    kreise.defaults.loop = val
  end)

  params:add_number('default_channel', 'Channel range', 5, 17, 5)
  params:set_action('default_channel', function(val)
    kreise.defaults.channel = val
  end)

  -- Wrappers for Norns clock params.
  params:add_number('bpm', 'bpm', 1, 300, kreise.bpm)
  params:set_action('bpm', function(val)
    kreise.bpm = val
    params:set('clock_tempo', val)
  end)
  params:hide('bpm')

  params:add_number('source', 'source', 1, 3, 2)
  params:set_action('source', function(val)
    local source = {'internal', 'midi', 'link'}
    clock.set_source(source[val])
  end)
  params:hide('source')

  params:read()
end

--- Inits app.
function init()
  print(norns.state.name .. ' v' .. VERSION)
  screen.ping()
  screen.aa(1)

  kreise = kreis.new(ui.VIEWPORT.center, ui.VIEWPORT.middle)
  kreise:install_patterns()
  kreise:load_pattern(norns.state.data .. kreise.autosave_name .. '.kl')

  init_midi()

  ui.LAST_PAGE = 3
  ui.OFF = 1
  add_params()

  clock_normal_id = clock.run(update)
  clock_triplet_id = clock.run(update_triplet)
  redraw()
end

--- Encoder input.
function enc(index, delta)
  local page = ui.page_get()

  if index == 1 then
    ui:page_delta(delta)
  end

  if page == 1 then
    if index == 2 then
      kreise:set_active_pattern(delta)
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
      kreise:set_active_ring(-delta)
    elseif index == 3 then
      if use_mod == 1 then
        kreise:set_active_loop_delta(delta)
      else
        kreise:set_active_channel_delta(delta)
      end
    end
    if (#norns.encoders.accel == 4) then
      -- Handle Fates 4th encoder.
      if index == 4 then
        kreise:set_active_loop_delta(delta)
      end
    end

  elseif page == 3 then
    if index == 2 then
      kreise:set_active_step(delta)
    elseif index == 3 then
      -- if kreise:get_active('beat') == nil then
      --   kreise:set_active('beat', params:get('default_beat'))
      -- end

      if kreise:get_active('beat') then
        if use_mod == 1 then
          kreise:set_active_delta('velocity', delta)
        else
          kreise:set_active_delta('beat', delta)

          if params:get('quant_scale') > 1 then
            kreise:set_active('beat', get_quant_note())
          end
        end
      end
    end
    if (#norns.encoders.accel == 4) then
      -- Handle Fates 4th encoder.
      if index == 4 then
        kreise:set_active_delta('velocity', delta)
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
        if #kreise.patterns > 1 then
          kreise:remove_active_pattern()
        end
      else
        kreise:plot_points(ui.VIEWPORT.center, ui.VIEWPORT.middle)
      end
    elseif page == 2 then
      selecting_file = true
      -- TODO(frederickk): Is there a way to trigger a params action?
      fileselect.enter(norns.state.data, function(pth)
        selecting_file = false
        if pth ~= "cancel" then
          kreise:load_pattern(pth)
        end
      end)
    elseif page == 3 then
      if use_mod == 1 then
        local id = kreise:get_active_id()
        if id == 'standard' then
          kreise:set_active_id('triplet')
          kreise:set_active_steps(12)
        else
          kreise:set_active_id('standard')
          kreise:set_active_steps(16)
        end
        local ring = kreise:get_active_ring()
        ring:plot_points(ui.VIEWPORT.center, ui.VIEWPORT.middle)
      else
        if kreise:get_active('beat') then
          kreise:set_active('beat', nil)
        else
          kreise:set_active('beat', params:get('default_beat'))
        end
      end
    end
  end

end

--- Draws label group to screen.
local function label(x, y, page, name, val)
  screen.move(x, y)
  ui:highlight({page}, ui.OFF, 0)
  screen.text(name)

  if val then
    screen.move(x, y + 8)
    ui:highlight({page}, 15, 0)
    screen.text(val)
  end
end

--- Draws UI globals to screen.
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

--- Draws page labels to screen.
local function draw_ui_pages()
  local page = ui.page_get()

  if page == 1 then
    label(2, 52, 1, 'PATTERN',
        kreise.pattern_index .. '/' .. #kreise.patterns)
    label(ui.VIEWPORT.width - 30, 52, 1, 'BPM', util.round(params:get('clock_tempo')))
    label(ui.VIEWPORT.width - 30, 32, 1, 'DIV', params:get('step_div'))

  elseif page == 2 then
    label(2, 52, 2, 'RING', kreise.ring_index)
    label(ui.VIEWPORT.width - 30, 52, 2, 'CHAN.', kreise:get_active_channel())
    label(ui.VIEWPORT.width - 30, 32, 2, 'LOOP')
    screen.move(ui.VIEWPORT.width - 30, 40)
    ui:highlight({2}, ui.ON, 0)
    if kreise:get_active_loop() <= 0 then
      screen.text(kreise.loop_index .. '/' .. 'Inf.')
    else
      screen.text(kreise.loop_index .. '/' .. kreise:get_active_loop())
    end

  elseif page == 3 then
    if params:get('quant_scale') > 1 then
      screen.level(ui.ON)
      screen.move(ui.VIEWPORT.width - 30, 8)
      screen.text(musicutil.NOTE_NAMES[params:get('quant_tonic')])
      screen.move(ui.VIEWPORT.width - 30, 16)
      screen.text(musicutil.SCALES[params:get('quant_scale') - 1].name)
    end

    label(2, 52, 3, 'STEP', kreise:print_active_step())
    label(ui.VIEWPORT.width - 30, 52, 3, 'NOTE')
    screen.move(ui.VIEWPORT.width - 30, 60)
    if kreise:get_active('beat') then
      ui:highlight({3})
      screen.text(musicutil.note_num_to_name(kreise:get_active('beat'), true))
    else
      screen.text('--')
    end

    label(ui.VIEWPORT.width - 30, 32, 3, 'VEL.')
    screen.move(ui.VIEWPORT.width - 30, 40)
    if kreise:get_active('beat') then
      ui:highlight({3})
      screen.text(kreise:get_active('velocity'))
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

  local rings = kreise.patterns[kreise.pattern_index]
  local step = kreise:get_active_step()

  for i = 1, #rings do
    for j, pattern in ipairs(rings[i].pattern) do
      screen.level(ui.OFF)

      -- highlight beat/note, if not 'nil'
      if pattern['beat'] then
        screen.level(5)
      end

      -- highlight selection
      if i == kreise.ring_index and j == step then
        screen.level(ui.ON)
      end

      -- TODO(frederickk): Create draw method within Kreis class.
      stueck:draw(pattern['points'])
    end
  end

  screen.update()
end

--- Writes params and saves current pattern on script end.
function cleanup()
  params:write()
  kreise:save_pattern(kreise.autosave_name)
end

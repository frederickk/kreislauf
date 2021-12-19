--- @fileoverview Ring is made of 16 steps (default)
local Stueck = include('lib/core/stueck')

local Ring = {
  channel = 1,
  defaults = {
    beat = nil,
    channel = 5,
    loop = 0,
    velocity = 96,
  },
  id = 'standard',
  index = 1,
  step_index = 1,
  steps = 16,
  pattern = {},
  radius = 6,
}
Ring.__index = Ring

setmetatable(Ring, {
  __call = function (cls, ...)
    return cls.new(...)
  end,
})

--- Instantiates new Ring object.
-- @param index
-- @param radius
-- @param id
function Ring.new(index, radius, id)
  local self = setmetatable({}, Ring)

  self.index = index
  self.radius = radius or self.radius
  self.steps = 16
  self.id = id or 'standard'

  return self
end

--- Calculates points for ring.
-- @param cx  center X value
-- @param cy  center Y value
function Ring:plot_points(cx, cy)
  self.pattern = {
    channel = self.defaults.channel - self.index,
    id = self.id,
    radius = self.radius,
    steps = self.steps,
    step_index = self.step_index,
  }
  -- self.pattern['channel'] = self.defaults.channel - self.index
  -- self.pattern['id'] = self.id
  -- self.pattern['radius'] = self.radius
  -- self.pattern['steps'] = self.steps
  -- self.pattern['step_index'] = self.step_index

  local increment = -360 / self.steps
  -- TODO(frederickk) Fix hacky math to get the rotation right.
  local offset = math.pi - util.degs_to_rads(increment)
  local angle = {0, 0}

  for i = 1, self.steps do
    -- self.pattern[i] = {}
    angle[1] = util.degs_to_rads(i * increment)
    angle[2] = (angle[1] + util.degs_to_rads(increment))

    self.pattern[i] = {
      points = Stueck.plot_points(
        cx, cy,
        self.radius, self.radius - 6,
        offset + angle[1], offset + angle[2]),
      beat = nil,
      velocity = self.defaults.velocity,
    }
    -- self.pattern[i]['points'] = Stueck.plot_points(
    --     cx, cy,
    --     self.radius, self.radius - 6,
    --     offset + angle[1], offset + angle[2])
    -- self.pattern[i]['beat'] = nil
    -- self.pattern[i]['velocity'] = self.defaults.velocity
  end

  -- print(self.id, self.steps, self.steps % 3)
  -- self.id = (self.steps % 3 == 0 and 'triplet' or 'standard')

  return self
end

--- Sets ring ID.
-- @param id
function Ring:set_id(id)
  self.pattern['id'] = id
end

--- Sets number of steps.
-- @param num  number of steps, should be multiple of 4 (or 3)
function Ring:set_steps(num)
  self.pattern['steps'] = num
end

--- Sets active step value.
-- @param delta  delta of change
--- Returns total steps of ring.
function Ring:get_steps()
  return self.pattern['steps']
end

return Ring
--- @fileoverview Stueck is single step
local Stueck = {}

--- Calculates points for step piece.
-- @param cx     center X value
-- @param cy     center Y value
-- @param r_1    outer radius
-- @param r_2    inner radius
-- @param ang_1  starting angle (radians)
-- @param ang_2  ending angle (radians)
function Stueck.plot_points(cx, cy, r_1, r_2, ang_1, ang_2)
  return {
    {
      cx + (r_1 * math.sin(ang_1)),
      cy + (r_1 * math.cos(ang_1))
    },
    {
      cx + (r_1 * math.sin(ang_2)),
      cy + (r_1 * math.cos(ang_2))
    },
    {
      cx + (r_2 * math.sin(ang_2)),
      cy + (r_2 * math.cos(ang_2))
    },
    {
      cx + (r_2 * math.sin(ang_1)),
      cy + (r_2 * math.cos(ang_1))
    },
  }
end

--- Draws outlined step piece.
-- @param points  table of 4 {x, y} pairs
function Stueck.draw_outline(points)
  screen.line_width(1.5)
  screen.move(points[1][1], points[1][2])
  screen.line(points[2][1], points[2][2])
  screen.line(points[3][1], points[3][2])
  screen.stroke()
end

--- Draws filled in step piece.
-- @param points  table of 4 {x, y} pairs
function Stueck:draw(points)
  screen.move(points[1][1], points[1][2])
  screen.line(points[2][1], points[2][2])
  screen.line(points[3][1], points[3][2])
  screen.line(points[4][1], points[4][2])
  screen.close()
  screen.fill()

  screen.level(0)
  self.draw_outline(points)
end

return Stueck
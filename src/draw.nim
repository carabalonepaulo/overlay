{.experimental: "codeReordering".}

import math, pixie
import pixie/[contexts]
import std/[strformat]
import ./[state]

proc draw*(
    state: var State, img: var Image, ctx: var Context, sw: float32, sh: float32
) =
  ctx.clearRect(0, 0, sw, sh)

  let cx = sw / 2
  let cy = sh / 2
  let radius = min(sw, sh) / 4

  draw_angle_inc_value(state, ctx)
  draw_guide_lines(ctx, radius, cx, cy, sw, sh)
  draw_lines(state, ctx, radius, cx, cy, sw, sh)
  draw_markers(state, ctx, img, 180, cx, cy, sw, sh)

proc draw_angle_inc_value(state: State, ctx: var Context) =
  let text = &"{state.angle_inc_value:.2f}°"
  let padding = 5f

  let tw = ctx.measure_text(text).width

  ctx.textAlign = LeftAlign
  ctx.textBaseline = TopBaseline

  ctx.fillStyle = rgba(0, 0, 0, 200)
  ctx.fillRect(padding, padding, tw + padding * 2, ctx.font_size + padding * 3)

  ctx.fillStyle = rgba(255, 255, 255, 255)
  ctx.fillText(text, padding * 2, padding * 2)

proc draw_guide_lines(
    ctx: var Context, r: float32, cx: float32, cy: float32, sw: float32, sh: float32
) =
  ctx.beginPath()
  ctx.arc(cx, cy, r, 0, 2 * PI)
  ctx.closePath()

  ctx.setLineDash(@[])
  ctx.strokeStyle = rgba(255, 204, 63, 150)
  ctx.lineWidth = 2
  ctx.stroke()

  ctx.beginPath()
  ctx.moveTo(cx, 0)
  ctx.lineTo(cx, sh)
  ctx.strokeStyle = rgba(255, 204, 63, 150)
  ctx.lineWidth = 1
  ctx.setLineDash(@[2'f32, 2'f32])
  ctx.stroke()

  ctx.beginPath()
  ctx.moveTo(0, cy)
  ctx.lineTo(sw, cy)
  ctx.strokeStyle = rgba(255, 204, 63, 150)
  ctx.lineWidth = 1
  ctx.setLineDash(@[2'f32, 2'f32])
  ctx.stroke()

proc draw_lines(
    state: State,
    ctx: var Context,
    radius: float32,
    cx: float32,
    cy: float32,
    sw: float32,
    sh: float32,
) =
  for i, line in state.lines:
    let dyn_rad = PI * (line.angle - 90.0) / 180.0
    let line_length = max(sw, sh)
    let x_end = cx - float32(line_length) * cos(dyn_rad)
    let y_end = cy - float32(line_length) * sin(dyn_rad)
    let x_start = cx + float32(line_length) * cos(dyn_rad)
    let y_start = cy + float32(line_length) * sin(dyn_rad)

    let width = if state.current_line_idx == i: 3 else: 1
    let color = rgba(line.color.r, line.color.g, line.color.b, 180)
    ctx.lineWidth = width.float32
    ctx.strokeStyle = color
    ctx.setLineDash(@[])
    ctx.beginPath()
    ctx.moveTo(x_start, y_start)
    ctx.lineTo(x_end, y_end)
    ctx.stroke()

    let radius_circle: float32 = 2.0
    let ball_rad = float32(dyn_rad + PI)
    let ix = cx - radius * cos(ball_rad)
    let iy = cy - radius * sin(ball_rad)

    ctx.beginPath()
    ctx.fillStyle = rgba(255, 255, 255, 200)
    ctx.arc(float32(ix), float32(iy), radius_circle, 0.0, 2f * PI)
    ctx.fill()

    let textRadius = radius + 15f
    let tx = cx - textRadius * cos(ball_rad)
    let ty = cy - textRadius * sin(ball_rad)
    let text = &"{line.angle:.2f}°"

    ctx.textAlign = CenterAlign
    ctx.textBaseline = MiddleBaseline

    ctx.fillStyle = rgba(0, 0, 0, 255)
    for (dx, dy) in [(-1f, -1f), (1f, -1f), (-1f, 1f), (1f, 1f)]:
      ctx.fillText(text, tx + dx, ty + dy)

    ctx.fillStyle = rgba(255, 255, 255, 255)
    ctx.fillText(text, tx, ty)

proc draw_markers(
    state: var State,
    ctx: var Context,
    img: var Image,
    arc_radius: float32,
    cx: float32,
    cy: float32,
    sw: float32,
    sh: float32,
) =
  for i, m in state.markers:
    let use_arc_radius = arc_radius - float32(i) * 30f

    let firstLine = state.find_line(m.first)
    let angleRad = (firstLine.angle - 90f) * PI / 180f
    let fx = cx - use_arc_radius * cos(angleRad)
    let fy = cy - use_arc_radius * sin(angleRad)
    ctx.fillStyle = rgba(255, 255, 255, 255)
    ctx.fillEllipse(gvec2(fx.float32, fy.float32), 4f, 4f)

    if m.second != -1:
      let secondLine = state.find_line(m.second)
      let secAngleRad = (secondLine.angle - 90f) * PI / 180f
      let sx = cx - use_arc_radius * cos(secAngleRad)
      let sy = cy - use_arc_radius * sin(secAngleRad)
      ctx.fillStyle = rgba(255, 255, 255, 255)
      ctx.fillEllipse(gvec2(sx.float32, sy.float32), 4f, 4f)

      var startAngle = firstLine.angle - 90f
      var endAngle = secondLine.angle - 90f
      if endAngle < startAngle:
        endAngle += 360f

      let deltaAngle = endAngle - startAngle
      let steps = 50

      var prevX = cx - use_arc_radius * cos(startAngle * PI / 180f)
      var prevY = cy - use_arc_radius * sin(startAngle * PI / 180f)
      for j in 1 .. steps:
        let angle = startAngle + deltaAngle * (j.float / steps.float)
        let x = cx - use_arc_radius * cos(angle * PI / 180f)
        let y = cy - use_arc_radius * sin(angle * PI / 180f)
        ctx.beginPath()
        ctx.moveTo(prevX.float32, prevY.float32)
        ctx.lineTo(x.float32, y.float32)
        ctx.strokeStyle = rgba(0, 0, 0, 100)
        ctx.lineWidth = 4f
        ctx.stroke()
        prevX = x
        prevY = y

      prevX = cx - use_arc_radius * cos(startAngle * PI / 180f)
      prevY = cy - use_arc_radius * sin(startAngle * PI / 180f)
      for j in 1 .. steps:
        let angle = startAngle + deltaAngle * (j.float / steps.float)
        let x = cx - use_arc_radius * cos(angle * PI / 180f)
        let y = cy - use_arc_radius * sin(angle * PI / 180f)
        ctx.beginPath()
        ctx.moveTo(prevX.float32, prevY.float32)
        ctx.lineTo(x.float32, y.float32)
        ctx.strokeStyle = rgba(255, 255, 255, 255)
        ctx.lineWidth = 2f
        ctx.stroke()
        prevX = x
        prevY = y

      ctx.textAlign = CenterAlign
      ctx.textBaseline = MiddleBaseline

      let midAngle = (startAngle + endAngle) / 2f
      let textRadius = use_arc_radius + 20f
      let tx = cx - textRadius * cos(midAngle * PI / 180f)
      let ty = cy - textRadius * sin(midAngle * PI / 180f)
      let text = &"{deltaAngle:.2f}°"

      ctx.fillStyle = rgba(0, 0, 0, 100)
      for (dx, dy) in [(-1f, -1f), (1f, -1f), (-1f, 1f), (1f, 1f)]:
        ctx.fillText(text, tx + dx, ty + dy)

      ctx.fillStyle = rgba(255, 255, 255, 255)
      ctx.fillText(text, tx, ty)

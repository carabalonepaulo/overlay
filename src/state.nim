{.experimental: "codeReordering".}

import pixie, random

type
  Hotkey* = enum
    AddLine
    DelLine
    IncAngle
    DecAngle
    NextLine
    PrevLine
    NewColor
    AddMarker
    DelMarker
    IncStep
    DecStep
    BigIncStep
    BigDecStep

  Marker* = object
    first*: int
    second*: int

  UniqueLine* = ref object
    id*: int
    angle*: float32
    color*: ColorRGBA

  State* = object
    current_line_idx*: int
    lines*: seq[UniqueLine]
    markers*: seq[Marker]
    angle_inc_value*: float32
    next_id: int

proc init*(_: type State): State =
  State(lines: @[], markers: @[], angle_inc_value: 1f)

proc handle_input*(self: var State, id: Hotkey) =
  case id
  of AddLine:
    self.lines.add(UniqueLine(id: self.next_id, angle: 0, color: rand_color()))
    self.current_line_idx = self.lines.len - 1
    self.next_id += 1
  of DelLine:
    if self.lines.len > 0:
      self.delete_markers(self.lines[self.current_line_idx].id)
      self.lines.del(self.current_line_idx)
      if self.current_line_idx >= self.lines.len:
        self.current_line_idx = max(0, self.lines.len - 1)
  of IncAngle:
    if self.lines.len > 0:
      self.lines[self.current_line_idx].angle =
        (self.lines[self.current_line_idx].angle + self.angle_inc_value) mod 360f
  of DecAngle:
    if self.lines.len > 0:
      self.lines[self.current_line_idx].angle =
        (self.lines[self.current_line_idx].angle - self.angle_inc_value + 360f) mod 360
  of NextLine:
    if self.lines.len > 0:
      self.current_line_idx = (self.current_line_idx + 1) mod self.lines.len
  of PrevLine:
    if self.lines.len > 0:
      self.current_line_idx =
        (self.current_line_idx - 1 + self.lines.len) mod self.lines.len
  of NewColor:
    if self.lines.len > 0:
      self.lines[self.current_line_idx].color = rand_color()
  of AddMarker:
    if self.lines.len > 0 and (self.markers.len < 5 or self.markers[^1].second == -1):
      if self.markers.len == 0 or self.markers[^1].second != -1:
        self.markers.add Marker(first: self.lines[self.current_line_idx].id, second: -1)
      else:
        self.markers[^1].second = self.lines[self.current_line_idx].id
  of DelMarker:
    if self.lines.len > 0 and self.markers.len > 0:
      self.delete_markers(self.lines[self.current_line_idx].id)
  of IncStep:
    self.angle_inc_value += 0.01f
  of DecStep:
    self.angle_inc_value -= 0.01f
    if self.angle_inc_value < 0.01f:
      self.angle_inc_value = 0.01
  of BigIncStep:
    self.angle_inc_value += 0.1f
  of BigDecStep:
    self.angle_inc_value -= 0.1f
    if self.angle_inc_value < 0.1f:
      self.angle_inc_value = 0.1

proc delete_markers(self: var State, line_id: int) =
  var newMarkers: seq[Marker]
  for m in self.markers:
    if m.first != line_id and m.second != line_id:
      newMarkers.add m
  self.markers = newMarkers

proc find_line*(self: var State, id: int): UniqueLine =
  for i, line in self.lines:
    if line.id == id:
      return line
  return nil

proc rand_color*(): ColorRGBA =
  let r = rand(255)
  let g = rand(255)
  let b = rand(255)
  return rgba(r.uint8, g.uint8, b.uint8, 255)

converter to_i32*(hk: Hotkey): int32 =
  int32(hk)

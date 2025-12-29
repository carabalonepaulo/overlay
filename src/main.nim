import winim, pixie, random, os
import ./[draw, state]

const
  timer_refresh = 0
  fps = 60
  interval = 1000 div fps

  timer_popup = 1
  popup_delay = 2000

  ws_ex_layered = 0x80000
  ws_ex_topmost = 0x8
  ws_ex_transparent = 0x20

  mod_alt = 0x0001
  mod_control = 0x0002
  mod_control_alt = 0x0003
  mod_shift = 0x0004
  mod_shift_alt = 0x0005
  mod_control_shift = 0x0006
  mod_control_shift_alt = 0x0007

var hwnd: HWND
var bmi: BITMAPINFO
var bits: pointer
var screen_buffer: HBITMAP
var memdc: HDC
var sw: int32
var sh: int32
var image: Image
var ctx: pixie.Context
var app_state = State.init()

proc swap_channels(bmpData: ptr uint8, dest: pointer) =
  for i in 0 ..< sw * sh:
    let baseSrc = cast[int](bmpData)
    let baseDst = cast[int](bits)
    let r = cast[ptr uint8](baseSrc + i * 4 + 0)
    let g = cast[ptr uint8](baseSrc + i * 4 + 1)
    let b = cast[ptr uint8](baseSrc + i * 4 + 2)
    let a = cast[ptr uint8](baseSrc + i * 4 + 3)

    let dr = cast[ptr uint8](baseDst + i * 4 + 0)
    let dg = cast[ptr uint8](baseDst + i * 4 + 1)
    let db = cast[ptr uint8](baseDst + i * 4 + 2)
    let da = cast[ptr uint8](baseDst + i * 4 + 3)

    dr[] = b[]
    dg[] = g[]
    db[] = r[]
    da[] = a[]

proc refresh() =
  draw(app_state, image, ctx, sw.float32, sh.float32)
  let bmpData = cast[ptr uint8](image.data[0].addr)
  swap_channels(bmpData, bits)

  let hOld = SelectObject(memdc, screen_buffer)

  var ptZero: POINT
  ptZero.x = 0
  ptZero.y = 0
  var size: SIZE
  size.cx = sw.int32
  size.cy = sh.int32
  var blend: BLENDFUNCTION
  blend.BlendOp = AC_SRC_OVER
  blend.BlendFlags = 0
  blend.SourceConstantAlpha = 255
  blend.AlphaFormat = AC_SRC_ALPHA

  UpdateLayeredWindow(
    hwnd, 0, nil, addr size, memdc, addr ptZero, 0, addr blend, ULW_ALPHA
  )

  SelectObject(memdc, hOld)

proc wnd_proc(
    hWnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM
): LRESULT {.stdcall.} =
  case uMsg
  of WM_TIMER:
    refresh()
    return 0
  of WM_HOTKEY:
    app_state.handle_input(Hotkey(wParam))
    return 0
  of WM_DESTROY:
    DeleteObject(screen_buffer)
    DeleteDC(memdc)
    PostQuitMessage(0)
    return 0
  of WM_MOUSEWHEEL:
    let delta = cast[int16](wParam)
    return 0
  else:
    return DefWindowProc(hWnd, uMsg, wParam, lParam)

proc win_main() =
  randomize()

  var wc: WNDCLASS
  wc.style = CS_HREDRAW or CS_VREDRAW or CS_OWNDC
  wc.lpfnWndProc = wnd_proc
  wc.hInstance = GetModuleHandle(nil)
  wc.hCursor = LoadCursor(0, IDC_ARROW)
  wc.lpszClassName = "Overlay"

  if RegisterClass(addr wc) == 0:
    MessageBox(0, "faile to register class", "Error", MB_OK)
    return

  let screen_w = GetSystemMetrics(SM_CXSCREEN)
  let screen_h = GetSystemMetrics(SM_CYSCREEN)

  hwnd = CreateWindowEx(
    ws_ex_topmost or ws_ex_layered or ws_ex_transparent,
    wc.lpszClassName,
    "",
    WS_POPUP,
    0,
    0,
    screen_w,
    screen_h,
    0,
    0,
    wc.hInstance,
    nil,
  )

  memdc = CreateCompatibleDC(0)
  sw = screen_w
  sh = screen_h

  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER).int32
  bmi.bmiHeader.biWidth = screen_w.int32
  bmi.bmiHeader.biHeight = -screen_h.int32
  bmi.bmiHeader.biPlanes = 1
  bmi.bmiHeader.biBitCount = 32
  bmi.bmiHeader.biCompression = BI_RGB

  screen_buffer = CreateDIBSection(memdc, addr bmi, DIB_RGB_COLORS, addr bits, 0, 0)

  image = newImage(sw, sh)
  ctx = newContext(image)
  ctx.font = get_app_dir() / "default.ttf"
  ctx.fontSize = 16

  RegisterHotKey(hwnd, IncAngle, 0, VK_RIGHT)
  RegisterHotKey(hwnd, DecAngle, 0, VK_LEFT)
  RegisterHotKey(hwnd, AddLine, mod_control, 'A'.ord)
  RegisterHotKey(hwnd, NextLine, 0, VK_UP)
  RegisterHotKey(hwnd, PrevLine, 0, VK_DOWN)
  RegisterHotKey(hwnd, DelLine, mod_control, 'D'.ord)
  RegisterHotKey(hwnd, NewColor, mod_control, 'R'.ord)
  RegisterHotKey(hwnd, AddMarker, mod_control, 'F'.ord)
  RegisterHotKey(hwnd, DelMarker, mod_control_alt, 'F'.ord)
  RegisterHotKey(hwnd, IncStep, mod_control, VK_UP)
  RegisterHotKey(hwnd, DecStep, mod_control, VK_DOWN)
  RegisterHotKey(hwnd, BigIncStep, mod_control_shift, VK_UP)
  RegisterHotKey(hwnd, BigDecStep, mod_control_shift, VK_DOWN)

  ShowWindow(hwnd, SW_SHOW)
  UpdateWindow(hwnd)

  refresh()

  SetTimer(hwnd, timer_refresh, interval, nil)

  var msg: MSG
  while GetMessage(addr msg, 0, 0, 0) > 0:
    TranslateMessage(addr msg)
    DispatchMessage(addr msg)

when isMainModule:
  win_main()

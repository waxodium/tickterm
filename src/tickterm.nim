import std/[os, times, strutils, terminal, strformat, exitprocs, posix, termios, unicode, tables]
import parsetoml, cligen

const
  DefaultConfig = staticRead("./tickterm.toml")
  RammsteinRaw  = staticRead("./internal/rammstein.txt")
  RectanglesRaw = staticRead("./internal/rectangles.txt")

type
  Config = object
    clock, accent, font, ruler: string
    zen, strip, dated: bool
    calendar, tint, glow: string

  Cell = object
    sym: string
    ansi: string

  Canvas = seq[seq[Cell]]

  App = object
    cfg: Config
    fonts: Table[string, Table[string, seq[string]]]
    term: Termios
    raw: bool
    front: Canvas
    back: Canvas
    cols: int
    rows: int
    buf: string

var app: App

proc parseFont(raw: string): Table[string, seq[string]] =
  var lines = raw.splitLines()
  var i = 0

  while i < lines.len:
    let line = lines[i]

    if line.endsWith(":"):
      let key = line[0..^2]
      i += 1
      var blockLines: seq[string] = @[]

      while i < lines.len and not lines[i].endsWith(":"):
        if lines[i].len > 0: 
          blockLines.add(lines[i])
        i += 1
        
      result[key] = blockLines
    else:
      i += 1

proc parseFlf(path: string): Table[string, seq[string]] =
  let lines = readFile(path).splitLines()
  if lines.len == 0 or not lines[0].startsWith("flf2a"): 
    return

  let header = lines[0].split(' ')
  let height = parseInt(header[1])
  let commentLines = parseInt(header[5])

  var idx = 1 + commentLines
  var curChar = 32

  while idx < lines.len and curChar <= 126:
    var glyphLines: seq[string] = @[]
    for h in 0 ..< height:
      if idx < lines.len:
        var line = lines[idx]
        while line.len > 0 and line[^1] == '@':
          line = line[0..^2]
        glyphLines.add(line)
        idx += 1
    
    result[$chr(curChar)] = glyphLines
    curChar += 1


proc ansi(hex: string): string =
  let h = hex.strip(chars = {'#'})

  if h.len == 6:
    try:
      let r = parseHexInt(h[0..1])
      let g = parseHexInt(h[2..3])
      let b = parseHexInt(h[4..5])
      return &"\e[38;2;{r};{g};{b}m"
    except ValueError: 
      discard
  elif h.len == 3:
    try:
      let r = parseHexInt($h[0] & $h[0])
      let g = parseHexInt($h[1] & $h[1])
      let b = parseHexInt($h[2] & $h[2])
      return &"\e[38;2;{r};{g};{b}m"
    except ValueError: 
      discard

  return "\e[37m"

proc plain(s: string): string =
  result = newStringOfCap(s.len)
  var i = 0

  while i < s.len:
    if s[i] == '\e':
      i += 2
      while i < s.len and s[i] in {'0'..'9', ';', '?'}: 
        inc i
      if i < s.len and s[i] in {'A'..'Z', 'a'..'z'}: 
        inc i
      continue
      
    result.add(s[i])
    inc i

proc width(s: string): int = 
  s.plain().runeLen()

proc width(glyph: seq[string]): int =
  for line in glyph: 
    result = max(result, line.width())
    
  if result == 0: 
    result = 1

proc glyph(ctx: App, c: char, font: string): seq[string] =
  let k = $c
  
  if ctx.fonts.hasKey(font) and ctx.fonts[font].hasKey(k):
    return ctx.fonts[font][k]
    
  if ctx.fonts.hasKey("simple") and ctx.fonts["simple"].hasKey(k):
    return ctx.fonts["simple"][k]
    
  return @[$c]

proc span(ctx: App, text, font: string): int =
  for i, c in text:
    result += ctx.glyph(c, font).width()
    if i < text.len - 1: 
      result += 2

proc restore(ctx: var App) =
  if ctx.raw:
    discard tcSetAttr(STDIN_FILENO, TCSAFLUSH, addr ctx.term)
    ctx.raw = false

proc uncook(ctx: var App) =
  if not ctx.raw:
    if tcGetAttr(STDIN_FILENO, addr ctx.term) == 0:
      var copy = ctx.term
      copy.c_lflag = copy.c_lflag and not (ECHO or ICANON or IEXTEN)
      copy.c_iflag = copy.c_iflag and not (BRKINT or ICRNL or INPCK or ISTRIP or IXON)
      copy.c_oflag = copy.c_oflag and not (OPOST)
      
      discard tcSetAttr(STDIN_FILENO, TCSAFLUSH, addr copy)
      ctx.raw = true

proc resize(canvas: var Canvas, cols, rows: int) =
  canvas.setLen(rows)
  for r in canvas.mitems:
    r.setLen(cols)
    for c in r.mitems:
      c.sym = " "
      c.ansi = ""

proc wipe(canvas: var Canvas) =
  for r in canvas.mitems:
    for c in r.mitems:
      c.sym = " "
      c.ansi = ""

proc run(ctx: var App) =
  hideCursor()
  ctx.uncook()
  stdout.write "\e[?1049h\e[2J"
  stdout.flushFile()

  addExitProc(proc() =
    app.restore()
    showCursor()
    stdout.write "\e[?1049l"
    stdout.flushFile()
  )

  setControlCHook(proc() {.noconv.} =
    app.restore()
    quit(0)
  )

  while true:
    let w = max(1, terminalWidth())
    let h = max(1, terminalHeight())

    if w != ctx.cols or h != ctx.rows:
      stdout.write "\e[2J"
      ctx.cols = w
      ctx.rows = h
      ctx.front.resize(w, h)
      ctx.back.resize(w, h)
      
    ctx.back.wipe()

    let stamp = now()
    let full  = stamp.format(ctx.cfg.clock)
    let short = stamp.format("HH:mm")
    let tiny  = stamp.format("HH")
    let date  = stamp.format(ctx.cfg.calendar)

    let fullW  = ctx.span(full, ctx.cfg.font)
    let shortW = ctx.span(short, ctx.cfg.font)
    let dateW  = date.width()

    var mode = if ctx.cfg.zen: 2 else: 3
    if w < fullW + 4: 
      mode = if w >= max(shortW, dateW) + 4: 2 else: 1
      
    let text = 
      if mode == 3: full 
      elif mode == 2: short 
      else: tiny
      
    let lined = ctx.cfg.strip
    let dated = ctx.cfg.dated and (mode >= 2)

    var glyphs: seq[seq[string]]
    var total = 0
    var tallest = 0

    for i, c in text:
      var g = ctx.glyph(c, ctx.cfg.font)
      if g.len == 1 and g[0] == $c and ctx.cfg.font != "simple": 
        g = ctx.glyph(c, "simple")


        
      total += g.width()
      if i < text.len - 1: 
        total += 2
        
      tallest = max(tallest, g.len)
      glyphs.add(g)

    var blockH = tallest
    if lined: blockH += 2
    if dated: blockH += 2

    let left = max(1, (w - total) div 2 + 1)
    let top  = max(1, (h - blockH) div 2 + 1)
    var x    = left
    let accent = ansi(ctx.cfg.accent)

    # Draw Text
    for g in glyphs:
      let gw = g.width()
      let pad = (tallest - g.len) div 2
      
      for r, line in g:
        let y = top + pad + r
        if y in 1..h:
          var cx = x
          for rune in line.toRunes:
            if cx in 1..w: 
              ctx.back[y-1][cx-1] = Cell(sym: $rune, ansi: accent)
            inc cx
      x += gw + 2
      
    var cursorY = top + tallest

    # Draw Ruler / Duration Indicator
    if lined:
      inc cursorY
      if cursorY <= h:
        let barW = max(1, (total.float * 0.7).int)
        let sec  = stamp.second.float + (stamp.nanosecond.float / 1e9)
        let fill = ((sec / 60.0) * barW.float).int
        let barX = max(1, left + (total - barW) div 2)
        let glow = ansi(ctx.cfg.glow)
        
        for i in 0 ..< fill:
          let cx = barX + i
          if cx in 1..w: 
            ctx.back[cursorY-1][cx-1] = Cell(sym: ctx.cfg.ruler, ansi: glow)
      inc cursorY

    # Draw le Date :)
    if dated:
      inc cursorY
      if cursorY <= h:
        let dx = max(1, left + (total - dateW) div 2)
        let tint = ansi(ctx.cfg.tint)
        var cx = dx
        
        for rune in date.toRunes:
          if cx in 1..w: 
            ctx.back[cursorY-1][cx-1] = Cell(sym: $rune, ansi: tint)
          inc cx

    # Rendering da Buffer
    ctx.buf.setLen(0)
    var activeAnsi = "NONE"
    var lastR = -1
    var lastC = -1

    for r in 0 ..< h:
      for c in 0 ..< w:
        let curr = ctx.back[r][c]
        let prev = ctx.front[r][c]
        
        if curr.sym != prev.sym or curr.ansi != prev.ansi:
          if lastR != r or lastC != c: 
            ctx.buf.add(&"\e[{r+1};{c+1}H")
            
          if curr.ansi != activeAnsi:
            ctx.buf.add(if curr.ansi == "": "\e[0m" else: curr.ansi)
            activeAnsi = curr.ansi
            
          ctx.buf.add(curr.sym)
          lastR = r
          lastC = c + 1
          
    if ctx.buf.len > 0:
      stdout.write(ctx.buf)
      stdout.flushFile()
      
    swap(ctx.front, ctx.back)
    discard tcflush(STDIN_FILENO, TCIFLUSH)
    sleep(33)

proc autoGenerateConfigs() =
  let home = expandTilde("~/.config/tickterm")
  
  if not dirExists(home): 
    createDir(home)
    
  if not fileExists(home / "tickterm.toml"): 
    writeFile(home / "tickterm.toml", DefaultConfig)

proc load(ctx: var App) =
  let exe = getAppDir()
  let home = expandTilde("~/.config/tickterm")
  var cP: string
  
  for p in [
    home / "tickterm.toml", 
    exe / "tickterm.toml", 
    exe.parentDir() / "tickterm.toml", 
    "tickterm.toml"
  ]:
    if fileExists(p): 
      cP = p
      break
      
  if cP == "": 
    quit(&"Error: Missing config in {home}")
    
  let t = parseToml.parseFile(cP)
  let s = if t.hasKey("settings"): t["settings"] else: nil

  template str(n: TomlValueRef, key, fallback: string): string = 
    if n != nil and n.hasKey(key): n[key].getStr() else: fallback
    
  template bll(n: TomlValueRef, key: string, fallback: bool): bool = 
    if n != nil and n.hasKey(key): n[key].getBool() else: fallback

  
  # Right here ! :)



  ctx.fonts["rammstein"]  = parseFont(RammsteinRaw)
  ctx.fonts["rectangles"] = parseFont(RectanglesRaw)
  

  # But sort of cool way to do



  ctx.cfg = Config(
    clock:    s.str("time_format", "HH:mm:ss"),
    accent:   s.str("accent_color", "#ffffff"),
    font:     s.str("default_font", "simple"),
    ruler:    s.str("underline_char", "─"),
    zen:      s.bll("zen_mode", false),
    strip:    s.bll("show_underline", true),
    dated:    s.bll("show_date", true),
    calendar: s.str("date_format", "yyyy-MM-dd"),
    tint:     s.str("date_color", "#aaaaaa"),
    glow:     s.str("underline_color", "#ffffff")
  )

proc tickterm(font = "", zen = false, underline = false, list = false) =
  autoGenerateConfigs()
  app.load()
  
  if list:
    echo "Available built-in fonts:"
    for name in app.fonts.keys:
      echo &"  - {name}"
    quit(0)

  if font != "":
    if font.endsWith(".flf") and fileExists(font):
      app.fonts["externalFLF"] = parseFlf(font)
      app.cfg.font = "externalFLF"
    else:
      app.cfg.font = font
  
  if zen: 
    app.cfg.zen = true
  if underline: 
    app.cfg.strip = true
    

  app.run()

when isMainModule:
  dispatch(tickterm, help = {
    "font": "Apply specified font",
    "zen": "Enable Zen mode (HH:mm)",
    "underline": "Underline the seconds duration indicator",
    "list": "List all available built-in fonts"
  })

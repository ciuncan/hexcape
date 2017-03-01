# https://hookrace.net/blog/writing-a-2d-platform-game-in-nim-with-sdl2/#8-text-rendering
# http://piumarta.com/software/sdlprims/
# https://github.com/nim-lang/sdl2/blob/master/src/sdl2.nim
# https://nim-lang.org/docs/random.html#random,int
# https://nim-by-example.github.io/oop/
# https://nim-lang.org/docs/tut1.html#advanced-types-tuples
import os
import streams
import times
import math
import basic2d
import sdl2
import sdl2.gfx
import sdl2.ttf
import sdl2.image
include hexcapepkg.logic

type SDLException = object of Exception

template sdlFailIf(cond: typed, reason: string) =
    if cond: raise SDLException.newException(
        reason & ", SDL error: " & $getError())

const dataDir = "data"

when defined(embedData):
  template readRW(filename: string): ptr RWops =
    const file = staticRead(dataDir / filename)
    rwFromConstMem(file.cstring, file.len)

  template readStream(filename: string): Stream =
    const file = staticRead(dataDir / filename)
    newStringStream(file)
else:
  let fullDataDir = getAppDir() / dataDir

  template readRW(filename: string): ptr RWops =
    var rw = rwFromFile(cstring(fullDataDir / filename), "r")
    sdlFailIf rw.isNil: "Cannot create RWops from file"
    rw

  template readStream(filename: string): Stream =
    var stream = newFileStream(fullDataDir / filename)
    if stream.isNil: raise ValueError.newException(
      "Cannot open file stream:" & fullDataDir / filename)
    stream


proc renderText(renderer: RendererPtr, font: FontPtr, text: string,
                x, y: cint, color: Color) =
    let surface = font.renderUtf8Solid(text.cstring, color)
    sdlFailIf surface.isNil: "Could not render text surface"

    discard surface.setSurfaceAlphaMod(color.a)

    var source = rect(0, 0, surface.w, surface.h)
    var dest = rect(x, y, surface.w, surface.h)
    let texture = renderer.createTextureFromSurface(surface)

    sdlFailIf texture.isNil:
      "Could not create texture from rendered text"

    surface.freeSurface()

    renderer.copyEx(texture, source, dest, angle = 0.0, center = nil,
                    flip = SDL_FLIP_NONE)

    texture.destroy()

const
    colorWhite = color(255, 255, 255, 255)
    colorBlack = color(  0,   0,   0, 255)

proc rawBuffer[T](s: seq[T]): ptr T = {.emit: "result = `s`->data;".}

const directions2Angles: array[Direction, float] = [
    Direction.bottomLeft:   120.0.degToRad,
    Direction.left:         180.0.degToRad,
    Direction.topLeft:      240.0.degToRad,
    Direction.topRight:     300.0.degToRad,
    Direction.right:          0.0.degToRad,
    Direction.bottomRight:   60.0.degToRad 
]
const directions2Vectors: array[Direction, Vector2d] = [
    Direction.bottomLeft:   polarVector2d(directions2Angles[Direction.bottomLeft],  1.0),
    Direction.left:         polarVector2d(directions2Angles[Direction.left],        1.0),
    Direction.topLeft:      polarVector2d(directions2Angles[Direction.topLeft],     1.0),
    Direction.topRight:     polarVector2d(directions2Angles[Direction.topRight],    1.0),
    Direction.right:        polarVector2d(directions2Angles[Direction.right],       1.0),
    Direction.bottomRight:  polarVector2d(directions2Angles[Direction.bottomRight], 1.0) 
]
const
    forwardVector   = directions2Vectors[Direction.bottomRight]
    downwardVector  = directions2Vectors[Direction.bottomLeft]

const tileStates2Colors: array[TileState, Color] = [
    TileState.empty:        color(  0,   0,   0,   0),
    TileState.collapsed:    color(200, 200, 255, 255),
    TileState.raised:       color( 80, 120, 240, 255)
]

proc drawNGon(ctx: RendererPtr, center: Vector2d, radius: float,
              color: Color = colorWhite,
              n = 6, rotate = 0.0) =
    var
        xs = newSeq[int16](n)
        ys = newSeq[int16](n)

    for i in countup(0, n-1):
        let
            startAngle = (i.float64 * (360.0 / n.float) + rotate).degToRad
            start  = center + polarVector2d(startAngle, radius)

        xs[i] = start.x.int16
        ys[i] = start.y.int16
    
    ctx.filledPolygonRGBA(xs.rawBuffer, ys.rawBuffer, n.cint, color.r, color.g, color.b, color.a)
    ctx.setDrawColor(r = 0, g = 0, b = 0)
    ctx.drawLine(center.x.cint, center.y.cint, center.x.cint + 1, center.y.cint + 1)

type
    Input {.pure.} = enum none, quit, reset, mousePressed, mouseReleased

    Game = ref object
        renderer: RendererPtr
        font: FontPtr
        pressedMousePos: Point
        currentMousePos: Point
        inputs: array[Input, bool]
        grid: HexGrid
        topPos: Vector2d
        hexRadius: float
        nMoves: int
        isWin: bool

proc newGame(renderer: RendererPtr): Game =
    new result
    result.renderer = renderer
    result.topPos = vector2d(1280/2, 100)
    result.hexRadius = 60.0
    result.grid = newHexGrid(4)
    result.grid.randomize()

    result.font = openFontRW(
        readRW("iosevka_medium.ttf"), freesrc = 1, 16)
    sdlFailIf result.font.isNil: "Failed to load font"

proc reset(game: Game) =
    game.nMoves = 0
    game.isWin = false
    game.grid.randomize()

proc toInput(key: Scancode): Input =
    case key
    of SDL_SCANCODE_Q: Input.quit
    of SDL_SCANCODE_R: Input.reset
    else: Input.none

proc handleInput(game: Game) =
    game.inputs[Input.mouseReleased] = false
    var event = defaultEvent
    while pollEvent(event):
        case event.kind
        of QuitEvent:
            game.inputs[Input.quit] = true
        of KeyDown:
            game.inputs[event.key.keysym.scancode.toInput] = true
        of KeyUp:
            game.inputs[event.key.keysym.scancode.toInput] = false
        of MouseMotion:
            game.currentMousePos.x = event.motion.x
            game.currentMousePos.y = event.motion.y
        of MouseButtonDown:
            game.pressedMousePos.x = event.button.x
            game.pressedMousePos.y = event.button.y
            game.inputs[Input.mousePressed] = true
        of MouseButtonUp:
            game.inputs[Input.mousePressed] = false
            game.inputs[Input.mouseReleased] = true
        else:
            discard

    
# p_x = (f_x * c_x + d_x * c_y) * 2r + t_x
# p_y = (f_y * c_x + d_y * c_y) * 2r + t_y
#
#                                     [ f_x  f_y  0 ]   [ 2r  0  0 ]   [  1    0    0 ]
# [ p_x  p_y  1 ] = [ c_x  c_y  1 ] & | d_x  d_y  0 | & | 0  2r  0 | & |  0    1    0 |
#                                     [  0    0   1 ]   [ 0   0  1 ]   [ t_x  t_y   1 ]
# general matrix form
# [ a_x  a_y   0 ]
# [ b_x  b_y   0 ] = matrix2d(a_x, a_y, b_x, b_y, t_x, t_y)
# [ t_x  t_y   1 ]
proc coords2ScreenPos(game: Game, coords: Point): Vector2d =
    let 
        c = point2d(coords.x.float, coords.y.float)
        xform = matrix2d(forwardVector.x, forwardVector.y, downwardVector.x, downwardVector.y, 0, 0) & scale(2*game.hexRadius) & move(game.topPos)
        p = c & xform
    result.x = p.x
    result.y = p.y
    # game.topPos + forwardVector * coords.x.float * 2*game.hexRadius 
                # + downwardVector * coords.y.float * 2*game.hexRadius

#                                     ([ f_x  f_y  0 ]   [ 2r  0  0 ]   [  1    0    0 ]) -1
# [ c_x  c_y  1 ] = [ p_x  p_y  1 ] & (| d_x  d_y  0 | & | 0  2r  0 | & |  0    1    0 |)
#                                     ([  0    0   1 ]   [ 0   0  1 ]   [ t_x  t_y   1 ])
proc screenPos2Coords(game: Game, pos: Vector2d): Point =
    let
        xform_inv = matrix2d(forwardVector.x, forwardVector.y, downwardVector.x, downwardVector.y, 0, 0) & scale(2*game.hexRadius) & move(game.topPos)
        xform = xform_inv.inverse
        # relative_pos = pos - game.topPos + (forwardVector + downwardVector) * game.hexRadius
        # proj_x = forwardVector.dot(relative_pos)
        # proj_y = downwardVector.dot(relative_pos)
        proj = point2d(pos.x, pos.y) & xform

    result.x = (proj.x + 0.5).cint
    result.y = (proj.y + 0.5).cint
    
    # echo "pos=" & $pos & ", relative=" & $relative_pos & ", (p_x,p_y)=" & $(proj_x, proj_y) & ", r=" & $game.hexRadius & ", result=" & $result
    # echo "forward=" & $forwardVector & ", downward=" & $downwardVector

proc renderText(game: Game, text: string,
                x, y: cint, color: Color) =
    const outlineColor = color(0, 0, 0, 64)
    game.renderer.renderText(game.font, text, x, y, color)

proc drawHexGrid(game: Game) =
    for coords in game.grid.coords:
        let
            ind = game.grid.coords2ind(coords)
            currentCenter = game.coords2ScreenPos(coords)
            color = tileStates2Colors[game.grid.getStateAt(ind)]
        game.renderer.drawNGon(currentCenter, game.hexRadius, color, n = 6, rotate = 30.0)
        # game.renderText($ind, currentCenter.x.cint, currentCenter.y.cint, colorBlack)
        # for neighbor in @[point(0, 1), point(1, 0)]:
        #     let
        #         offset      = - (forwardVector + downwardVector) * game.hexRadius
        #         screenBegin = game.coords2ScreenPos(coords) + offset
        #         screenEnd   = game.coords2ScreenPos(point(coords.x + neighbor.x, coords.y + neighbor.y)) + offset
        #     game.renderer.drawLine(screenBegin.x.cint, screenBegin.y.cint, screenEnd.x.cint, screenEnd.y.cint)
    
    # let
    #     mousePos = vector2d(game.currentMouse.x.float, game.currentMouse.y.float)
    #     mouseCoords = game.screenPos2Coords(mousePos)
    #     mouseTileInd = game.grid.coords2ind(mouseCoords)
    # game.renderText("p:" & $mousePos & ", c:" & $mouseCoords & ", i:" & $mouseTileInd,
    #     mousePos.x.cint + 10, mousePos.y.cint + 10, colorBlack)
    

proc render(game: Game) =
    # Draw over all drawings of the last frame with the default
    # color
    game.renderer.setDrawColor(r = 110, g = 132, b = 174)
    game.renderer.clear()
    # Actual drawing here

    game.renderer.setDrawColor(r = 110, g = 13, b = 0)
    game.drawHexGrid()

    # proc drawAngle(ang: float) =
    #     let 
    #         p1 = point2d(1280/2, 720/2)
    #         p2 = p1.polar(ang.degToRad, 200.float)
    #     game.renderer.setDrawColor(r = 255, g = 0, b = 100)
    #     game.renderer.drawLine(p1.x.cint, p1.y.cint, p2.x.cint, p2.y.cint)

    # drawAngle(0)
    # drawAngle(30)
    # drawAngle(60)

    game.renderText("Moves: " & $game.nMoves, 1280 - 100, 60, colorBlack)
    if game.isWin:
        game.renderText("Won!", 1280 - 100, 90, colorWhite)

    # Show the result on screen
    game.renderer.present()

proc logic(game: Game) = 
    if game.inputs[Input.mouseReleased]:
        if not game.isWin:
            let coords = game.screenPos2Coords(vector2d(game.currentMousePos.x.float, game.currentMousePos.y.float))
            if game.grid.actionAt(coords):
                game.nMoves += 1
            game.isWin = game.grid.isWin()
        else:
            game.reset()
    if game.inputs[Input.reset]:
        game.reset()

proc main =
    sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
        "SDL2 initialization failed"
    
    # defer blocks get called at the end of the procedure, even if an
    # exception has been thrown
    defer: sdl2.quit()

    sdlFailIf(not setHint("SDL_RENDER_SCALE_QUALITY", "2")):
        "Linear texture filtering could not be enabled"
    
    let window = createWindow(title = "Hexcape",
        x = SDL_WINDOWPOS_CENTERED, y = SDL_WINDOWPOS_CENTERED,
        w = 1280, h = 720, flags = SDL_WINDOW_SHOWN)
    sdlFailIf window.isNil: "Window could not be created"
    defer: window.destroy()

    let renderer = window.createRenderer(index = -1,
        flags = Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)
    sdlFailIf renderer.isnil: "Renderer could not be created"
    defer: renderer.destroy()

    const imgFlags: cint = IMG_INIT_PNG
    sdlFailIf(image.init(imgFlags) != imgFlags):
        "SDL2 Image initialization failed"
    defer: image.quit()

    ttf.ttfInit()
    defer: ttf.ttfQuit()

    # Set the default color to use for drawing
    var game = newGame(renderer)

    var
        startTime = epochTime()
        lastTick = 0
    
    # Game loop, draws each frame
    while not game.inputs[Input.quit]:
        game.handleInput()
        # let newTick = int((epochTime() - startTime) * 50)
        # for tick in lastTick+1 .. newTick:
        #     game.physics()
        #     game.moveCamera()
        #     game.logic(tick)
        # lastTick = newTick
        game.logic()
        game.render()
    
main()
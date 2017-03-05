import basic2d
import os
import streams
import colors

import sdl2 except Color, color
import sdl2.gfx
import sdl2.ttf
import sdl2.image

import geometry
import logic

type SDLException = object of Exception

template sdlFailIf*(cond: typed, reason: string) =
    if cond: raise SDLException.newException(
        reason & ", SDL error: " & $getError())

var font: FontPtr

proc renderText*(ctx: RendererPtr, text: string, x, y: cint, c: Color) =


    let
        (r, g, b) = extractRGB(c)
        surface = font.renderUtf8Solid(text.cstring, (r.uint8, g.uint8, b.uint8, 255.uint8))
    sdlFailIf surface.isNil: "Could not render text surface"

    # discard surface.setSurfaceAlphaMod(color.a)

    var source = rect(0, 0, surface.w, surface.h)
    var dest = rect(x, y, surface.w, surface.h)
    let texture = ctx.createTextureFromSurface(surface)

    sdlFailIf texture.isNil:
      "Could not create texture from rendered text"
    surface.freeSurface()

    ctx.copyEx(texture, source, dest, angle = 0.0, center = nil,
                    flip = SDL_FLIP_NONE)
    texture.destroy()

proc drawNGon*(ctx: RendererPtr, points: seq[Point2d], c: Color = colWhite) =
    let
        (r, g, b) = extractRGB(c)
        n = points.len.cint
    var
        xs = newSeq[int16](n)
        ys = newSeq[int16](n)

    for i, p in points.pairs:
        xs[i] = p.x.int16
        ys[i] = p.y.int16
    
    ctx.filledPolygonRGBA(addr xs[0], addr ys[0], n, r.uint8, g.uint8, b.uint8, 255)
    

proc drawNGon*(ctx: RendererPtr, center: Vector2d, radius: float,
              c: Color = colWhite, n = 6, rotate = 0.0) =
    let points = genNGonPoints(center, radius, n, rotate)
    drawNGon(ctx, points, c)

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

proc loadFont*() =
    font = openFontRW(
        readRW("iosevka_medium.ttf"), freesrc = 1, 16)
    sdlFailIf font.isNil: "Failed to load font"
 

const tileStates2Colors: array[TileState, Color] = [
    TileState.empty:        rgb(  0,   0,   0),
    TileState.collapsed:    rgb(200, 200, 255),
    TileState.raised:       rgb( 80, 120, 240)
]

type
    Input {.pure.} = enum iNone, iQuit, iReset, iMousePressed, iMouseReleased

    Game = ref object
        renderer:           RendererPtr
        pressedMousePos:    Coords
        currentMousePos:    Coords
        inputs:             set[Input]
        grid:               HexGrid
        topPos:             Vector2d
        hexRadius:          float
        nMoves:             int
        isWin:              bool

proc newGame(renderer: RendererPtr): Game =
    new result
    result.renderer = renderer
    result.topPos = vector2d(1280/2, 100)
    result.hexRadius = 50.0
    result.grid = newHexGrid(5)
    result.grid.randomize()

proc reset(game: Game) =
    game.nMoves = 0
    game.isWin = false
    game.grid.randomize()

proc toInput(key: Scancode): Input =
    case key
    of SDL_SCANCODE_Q: Input.iQuit
    of SDL_SCANCODE_R: Input.iReset
    else: Input.iNone

proc handleInput(game: Game) =
    game.inputs.excl(Input.iMouseReleased)
    var event = defaultEvent
    while pollEvent(event):
        case event.kind
        of QuitEvent:
            game.inputs.incl(Input.iQuit)
        of KeyDown:
            game.inputs.incl(event.key.keysym.scancode.toInput)
        of KeyUp:
            game.inputs.excl(event.key.keysym.scancode.toInput)
        of MouseMotion:
            game.currentMousePos.x = event.motion.x
            game.currentMousePos.y = event.motion.y
        of MouseButtonDown:
            game.pressedMousePos.x = event.button.x
            game.pressedMousePos.y = event.button.y
            game.inputs.incl(Input.iMousePressed)
        of MouseButtonUp:
            game.inputs.excl(Input.iMousePressed)
            game.inputs.incl(Input.iMouseReleased)
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
proc coords2ScreenPos(game: Game, coords: Coords): Vector2d =
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
proc screenPos2Coords(game: Game, pos: Vector2d): Coords =
    let
        xform_inv = matrix2d(forwardVector.x, forwardVector.y, downwardVector.x, downwardVector.y, 0, 0) & scale(2*game.hexRadius) & move(game.topPos)
        xform = xform_inv.inverse
        proj = point2d(pos.x, pos.y) & xform

    result.x = (proj.x + 0.5).int
    result.y = (proj.y + 0.5).int

proc drawHexGrid(game: Game) =
    for coords in game.grid.coords:
        let
            ind = game.grid.coords2ind(coords)
            currentCenter = game.coords2ScreenPos(coords)
            color = tileStates2Colors[game.grid.getStateAt(ind)]
            effect = game.grid.getEffectAt(ind)
        if game.grid.isEmptyAt(ind):
            continue
        game.renderer.drawNGon(currentCenter + vector2d(2.0,2.0), game.hexRadius, colBlack, n = 6, rotate = 30.0)
        game.renderer.drawNGon(currentCenter, game.hexRadius, color, n = 6, rotate = 30.0)
        if effect of LinearTileEffect:
            for sign in @[-1.0, 1.0]:
                let
                    vec = directions2Vectors[effect.LinearTileEffect.direction] * sign
                    cen = currentCenter + vec * game.hexRadius / 3
                game.renderer.drawNGon(cen, game.hexRadius / 8, colBlack, n = 30)


    

proc render(game: Game) =
    # Draw over all drawings of the last frame with the default
    # color
    game.renderer.setDrawColor(r = 110, g = 132, b = 174)
    game.renderer.clear()
    # Actual drawing here

    game.renderer.setDrawColor(r = 110, g = 13, b = 0)
    game.drawHexGrid()

    game.renderer.renderText("Moves: " & $game.nMoves, 1280 - 100, 60, colBlack)
    if game.isWin:
        game.renderer.renderText("Won!", 1280 - 100, 90, colWhite)

    # Show the result on screen
    game.renderer.present()

proc logic(game: Game) = 
    if Input.iMouseReleased in game.inputs:
        if not game.isWin:
            let coords = game.screenPos2Coords(vector2d(game.currentMousePos.x.float, game.currentMousePos.y.float))
            if game.grid.actionAt(coords):
                game.nMoves += 1
            game.isWin = game.grid.isWin()
        else:
            game.reset()
    if Input.iReset in game.inputs:
        game.reset()

proc main* =
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

    loadFont()

    # Set the default color to use for drawing
    var game = newGame(renderer)

    # var
    #     startTime = epochTime()
    #     lastTick = 0
    
    # Game loop, draws each frame
    while Input.iQuit notin game.inputs:
        game.handleInput()
        # let newTick = int((epochTime() - startTime) * 50)
        # for tick in lastTick+1 .. newTick:
        #     game.physics()
        #     game.moveCamera()
        #     game.logic(tick)
        # lastTick = newTick
        game.logic()
        game.render()

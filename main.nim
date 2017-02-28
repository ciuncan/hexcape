# https://hookrace.net/blog/writing-a-2d-platform-game-in-nim-with-sdl2/#8-text-rendering
import times
import sdl2
import sdl2.gfx
import sdl2.image
include logic

type SDLException = object of Exception

template sdlFailIf(cond: typed, reason: string) =
    if cond: raise SDLException.newException(
        reason & ", SDL error: " & $getError())

type Color = tuple[r: uint8, g: uint8, b: uint8, a: uint8]


proc rawBuffer[T](s: seq[T]): ptr T = {.emit: "result = `s`->data;".}

proc drawNGon(ctx: RendererPtr, center: Point2d, radius: float,
              color: Color = (255.uint8, 255.uint8, 255.uint8, 255.uint8),
              n = 6, rotate = 0.0) =
    const angleOffset = 30.0
    ctx.drawLine(center.x.cint, center.y.cint, center.x.cint + 1, center.y.cint + 1)
    var
        xs = newSeq[int16](n)
        ys = newSeq[int16](n)

    for i in countup(0, n-1):
        let
            startAngle = (i.float64 * 60 + rotate + angleOffset) * PI / 180
            # endAngle = ((i+1).float64 * 60 + rotate + angleOffset) * PI / 180
            start  = center + (vector2d(cos(startAngle), sin(startAngle)) * radius)
            # ending = center + (vector2d(cos(endAngle), sin(endAngle)) * radius)

        # ctx.drawLine(start.x.cint, start.y.cint, ending.x.cint, ending.y.cint)
        xs[i] = start.x.int16
        ys[i] = start.y.int16
    
    ctx.filledPolygonRGBA(xs.rawBuffer, ys.rawBuffer, n.cint, color.r, color.g, color.b, color.a)
    

const directions2Angles: array[Direction, float] = [
    Direction.bottomLeft:   120.0.degToRad,
    Direction.left:         180.0.degToRad,
    Direction.topLeft:      240.0.degToRad,
    Direction.topRight:     300.0.degToRad,
    Direction.right:        0.0.degToRad,
    Direction.bottomRight:  60.0.degToRad 
]

proc polar2Cartesian(angle, radius: float): Vector2d =
    radius * vector2d(cos(angle), sin(angle))

const tileStates2Colors: array[TileState, Color] = [
    TileState.empty:        (  0.uint8,   0.uint8,   0.uint8,   0.uint8),
    TileState.collapsed:    (200.uint8, 200.uint8, 255.uint8, 255.uint8),
    TileState.raised:       ( 80.uint8, 120.uint8, 240.uint8, 255.uint8)
]

proc drawHexGrid(ctx: RendererPtr, hexGrid: HexGrid, top: Point2d, radius = 50.0) =
    let
        forwardAngle = directions2Angles[Direction.bottomRight]
        downwardAngle = directions2Angles[Direction.bottomLeft]
        forward = polar2Cartesian(forwardAngle, 2*radius)
        downward = polar2Cartesian(downwardAngle, 2*radius)
    for coords in hexGrid.coords:
        let
            currentCenter = top + forward * coords.x.float + downward * coords.y.float
            color = tileStates2Colors[hexGrid.getStateAt(coords)]
        ctx.drawNGon(currentCenter, radius, color)

type
    Input {.pure.} = enum none, quit

    Game = ref object
        renderer: RendererPtr
        inputs: array[Input, bool]
        grid: HexGrid

proc newGame(renderer: RendererPtr): Game =
    new result
    result.renderer = renderer
    result.grid = newHexGrid(10)
    result.grid.randomize()

proc toInput(key: Scancode): Input =
    case key
    of SDL_SCANCODE_Q: Input.quit
    else: Input.none

proc handleInput(game: Game) =
    var event = defaultEvent
    while pollEvent(event):
        case event.kind
        of QuitEvent:
            game.inputs[Input.quit] = true
        of KeyDown:
            game.inputs[event.key.keysym.scancode.toInput] = true
        of KeyUp:
            game.inputs[event.key.keysym.scancode.toInput] = false
        else:
            discard

proc render(game: Game) =
    # Draw over all drawings of the last frame with the default
    # color
    game.renderer.setDrawColor(r = 110, g = 132, b = 174)
    game.renderer.clear()
    # Actual drawing here

    game.renderer.setDrawColor(r = 110, g = 13, b = 0)
    game.renderer.drawHexGrid(game.grid, point2d(1280/2, 50), 20.0)

    # Show the result on screen
    game.renderer.present()

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
        game.render()
    
main()
import dom
import basic2d
import colors

import html5_canvas except Color

import geometry
import logic


proc renderText*(ctx: CanvasRenderingContext2D, text: string, x, y: float) =
    ctx.fillText(text, x, y)

proc drawNGon*(ctx: CanvasRenderingContext2D, points: seq[Point2d]) =
    ctx.beginPath()
    ctx.moveTo(points[points.len-1].x, points[points.len-1].y)
    for p in points:
        ctx.lineTo(p.x, p.y)
    ctx.closePath()
    ctx.fill()

proc drawNGon*(ctx: CanvasRenderingContext2D, center: Vector2d, radius: float,
               n = 6, rotate = 0.0) =
    let points = genNGonPoints(center, radius, n, rotate)
    drawNGon(ctx, points)

const tileStates2Colors: array[TileState, cstring] = [
    TileState.tsEmpty:        rgb(  0,   0,   0),
    TileState.tsCollapsed:    rgb(200, 200, 255),
    TileState.tsRaised:       rgb( 80, 120, 240)
]

type
    Input {.pure.} = enum iNone, iQuit, iReset, iMousePressed, iMouseReleased

    Game = ref object
        renderer:           CanvasRenderingContext2D
        pressedMousePos:    Point2d
        currentMousePos:    Point2d
        inputs:             set[Input]
        grid:               HexGrid
        topPos:             Vector2d
        hexRadius:          float
        nMoves:             int
        isWin:              bool

proc newGame(renderer: CanvasRenderingContext2D): Game =
    new result
    result.renderer = renderer
    result.topPos = vector2d(1280/2, 50)
    result.hexRadius = 30.0
    result.grid = newHexGrid(5)
    result.grid.randomize()

proc reset(game: Game) =
    game.nMoves = 0
    game.isWin = false
    game.grid.randomize()

# proc handleInput(game: Game) = proc (ev: Event):
#     var event = defaultEvent
#     while pollEvent(event):
#         case event.kind
#         of QuitEvent:
#             game.inputs.incl(Input.iQuit)
#         of KeyDown:
#             game.inputs.incl(event.key.keysym.scancode.toInput)
#         of KeyUp:
#             game.inputs.excl(event.key.keysym.scancode.toInput)
#         of MouseMotion:
#             game.currentMousePos.x = event.motion.x
#             game.currentMousePos.y = event.motion.y
#         of MouseButtonDown:
#             game.pressedMousePos.x = event.button.x
#             game.pressedMousePos.y = event.button.y
#             game.inputs.incl(Input.iMousePressed)
#         of MouseButtonUp:
#             game.inputs.excl(Input.iMousePressed)
#             game.inputs.incl(Input.iMouseReleased)
#         else:
#             discard


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
        if game.grid.isEmptyAt(ind):
            continue
        game.renderer.fillStyle = rgb(colBlack)
        game.renderer.drawNGon(currentCenter + vector2d(2.0,2.0), game.hexRadius, n = 6, rotate = 30.0)
        game.renderer.fillStyle = color
        game.renderer.drawNGon(currentCenter, game.hexRadius, n = 6, rotate = 30.0)

const
    width = 1280
    height = 720

proc render(game: Game) =
    # Draw over all drawings of the last frame with the default
    # color
    game.renderer.fillStyle = rgb(110, 132, 174)
    game.renderer.fillRect(0, 0, width, height)
    # Actual drawing here

    game.drawHexGrid()

    game.renderer.font = "16px Serif";
    game.renderer.fillStyle = rgb(colBlack)
    game.renderer.renderText("Moves: " & $game.nMoves, 1280 - 100, 60)
    if game.isWin:
        game.renderer.font = "48px Serif";
        game.renderer.fillStyle = rgb(colWhite)
        game.renderer.renderText("Won!", 1280 - 100, 90)

proc logic(game: Game) = 
    if Input.iMouseReleased in game.inputs:
        if not game.isWin:
            let coords = game.screenPos2Coords(vector2d(game.currentMousePos.x, game.currentMousePos.y))
            if game.grid.actionAt(coords):
                game.nMoves += 1
            game.isWin = game.grid.isWin()
        else:
            game.reset()

    if Input.iReset in game.inputs:
        game.reset()

    game.inputs.excl(Input.iMouseReleased)

proc requestAnimationFrame(drawFn: proc()) {.importc.}

var 
    canvasId    = "canvas"
    old         = document.getElementById(canvasId).Canvas
    canvas      = if not old.isNil: old else: document.createElement(canvasId).Canvas
    ctx         = canvas.getContext2D()
    game        = newGame(ctx)

proc offsetLeft(el: Node): float {.inline.} = {.emit: [el, ".offsetLeft;"].}
proc offsetTop(el: Node): float {.inline.} = {.emit: [el, ".offsetTop;"].}

proc log(txt: string) {.inline.} = {.emit: ["console.log(", txt, ");"].}
# proc log(txt: string) {.inline.} = {.emit: ["console.log(", txt, ");"].}


proc relative(ev: Event): Point2d =
    let 
        x = ev.x.float
        y = ev.y.float
        ol = ev.target.offsetLeft
        ot = ev.target.offsetTop
    result.x = x - ol
    result.y = y - ot

proc stopPropagation(ev: Event) {.inline.} = {.emit: [ev, ".stopPropagation();"].}

canvas.onmousedown = proc (ev: Event) =
    game.pressedMousePos = ev.relative
    game.inputs.incl(Input.iMousePressed)
    if ev.button == 2:
        game.inputs.incl(Input.iReset)
    ev.stopPropagation()

canvas.onmouseup = proc (ev: Event) =
    game.inputs.excl(Input.iMousePressed)
    game.inputs.incl(Input.iMouseReleased)
    if ev.button == 2:
        game.inputs.excl(Input.iReset)
    ev.stopPropagation()

canvas.onmousemove = proc (ev: Event) =
    game.currentMousePos = ev.relative

canvas.width  = width
canvas.height = height

if old.isNil: document.body.appendChild(canvas)

proc loop() =
    game.logic()
    game.render()
    requestAnimationFrame(loop)

proc main* =
    loop()
    
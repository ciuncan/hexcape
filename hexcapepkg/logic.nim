import math
import random
import basic2d

#         Grid coordinates
#
# (y)    ===================
# row  //                   \\
# 0 => ||   0 - 1 - 2 - 3   ||
#      ||   | / | / | / |   ||
# 1 => ||   4 - 5 - 6 - 7   ||
#      ||   | / | / | / |   ||
# 2 => ||   8 - 9 -10 -11   ||
#      ||   | / | / | / |   ||
# 3 => ||  12 -13 -14 -15   ||
#      \\                   //
#        ===================
#           ^   ^   ^   ^
#      (x)  |   |   |   |
#      col  0   1   2   3

# ====        Neighbor offsets        ====
#                top-right        right
#                (x  , y-1)     (x+1, y-1)
#                    ||       //
#                    ||      //
#  top-left          ||     //
# (x-1, y  ) ==  (x  , y  )  == (x+1, y  )
#               // center      bottom-right
#              //    ||
#             //     ||
#            //      ||
# (x-1, y+1)     (x  , y+1)
#    left        bottom-left
# ========================================

# Screen coordinates
#        / \
#       | 0 |
#      / \ / \
#     | 4 | 1 |
#    / \ / \ / \
#   | 8 | 5 | 2 |
#  / \ / \ / \ / \
# | 12| 9 | 6 | 3 |
#  \ / \ / \ / \ /
#   | 13| 10| 7 |
#    \ / \ / \ /
#     | 14| 11|
#      \ / \ /
#       | 15|
#        \ /

type
    # directions in clockwise order
    HexDirection* {.pure.} = enum
        bottomLeft,
        left,
        topLeft,
        topRight,
        right,
        bottomRight

    TileState* {.pure.} = enum empty, collapsed, raised

    TileEffect* = ref object of RootObj
    NeighborTileEffect* = ref object of TileEffect
    LinearTileEffect* = ref object of TileEffect
        direction*: HexDirection
        ignoreEmpty: bool

    HexGrid* = ref object
        width*: int
        tileStates: seq[TileState]
        tileEffects: seq[TileEffect]

    Coords* = object
        x*, y*: int

proc `$`(coords: Coords): string = "C(" & $coords.x & ", " & $coords.y & ")"

method affect(e: TileEffect, grid: HexGrid, coords: Coords) {.base.} =
  # override this base method
  quit "to override!"

template enumRand(enumType: typedesc): untyped = enumType(random(enumType.high.ord + 1))
template enumRange(enumType: typedesc): untyped = enumType.low.ord .. enumType.high.ord
template enumIterate(enumType: typedesc, v: untyped, body: untyped): untyped =
    for i in enumRange(enumType):
        let v = enumType(i)
        body

proc newNeighborTileEffect: NeighborTileEffect = new result
proc newLinearTileEffect(dir: HexDirection, ignoreEmpty = false): LinearTileEffect =
    new result
    result.direction = dir
    result.ignoreEmpty = ignoreEmpty
proc newLinearTileEffect: LinearTileEffect =
    newLinearTileEffect(
        enumRand(HexDirection),
        random(2) == 0)

proc newHexGrid(width: int, states: seq[TileState], effects: seq[TileEffect]): HexGrid =
    new result
    result.width = width
    result.tileStates = states
    result.tileEffects = effects

proc newHexGrid*(width: int): HexGrid =
    let
        nTiles = width * width
        states = newSeq[TileState](nTiles)
    var effects = newSeq[TileEffect](nTiles)
    for i in 0 ..< nTiles:
        effects[i] = newNeighborTileEffect()
    newHexGrid(width, states, effects)

proc newCoords*(x, y: int): Coords =
    result.x = x
    result.y = y

proc nTiles(grid: HexGrid): int = grid.width * grid.width

proc ind2Coords*(grid: HexGrid, ind: int): Coords = newCoords(ind mod grid.width, ind div grid.width)
proc coords2Ind*(grid: HexGrid, coords: Coords): int = coords.x + coords.y * grid.width

iterator indices*(grid: HexGrid): int =
    for i in 0 ..< grid.nTiles:
        yield i

iterator coords*(grid: HexGrid): Coords =
    for i in grid.indices:
        yield grid.ind2Coords(i)

proc inside(grid: HexGrid, ind: int): bool = ind >= 0 and ind < grid.nTiles
proc inside(grid: HexGrid, coords: Coords): bool =
    coords.x >= 0 and coords.y >= 0 and coords.x < grid.width and coords.y < grid.width

proc randomize*(grid: HexGrid) =
    for i in grid.indices:
        grid.tileStates[i] = enumRand(TileState)
        grid.tileEffects[i] = if random(2) == 0: newNeighborTileEffect()
                              else:              newLinearTileEffect()

const directions2Angles*: array[HexDirection, float] = [
    HexDirection.bottomLeft:   120.0.degToRad,
    HexDirection.left:         180.0.degToRad,
    HexDirection.topLeft:      240.0.degToRad,
    HexDirection.topRight:     300.0.degToRad,
    HexDirection.right:          0.0.degToRad,
    HexDirection.bottomRight:   60.0.degToRad
]
const directions2Opposites*: array[HexDirection, HexDirection] = [
    HexDirection.bottomLeft:   HexDirection.topRight,
    HexDirection.left:         HexDirection.right,
    HexDirection.topLeft:      HexDirection.bottomRight,
    HexDirection.topRight:     HexDirection.bottomLeft,
    HexDirection.right:        HexDirection.left,
    HexDirection.bottomRight:  HexDirection.topLeft
]
const directions2Vectors*: array[HexDirection, Vector2d] = [
    HexDirection.bottomLeft:   polarVector2d(directions2Angles[HexDirection.bottomLeft],  1.0),
    HexDirection.left:         polarVector2d(directions2Angles[HexDirection.left],        1.0),
    HexDirection.topLeft:      polarVector2d(directions2Angles[HexDirection.topLeft],     1.0),
    HexDirection.topRight:     polarVector2d(directions2Angles[HexDirection.topRight],    1.0),
    HexDirection.right:        polarVector2d(directions2Angles[HexDirection.right],       1.0),
    HexDirection.bottomRight:  polarVector2d(directions2Angles[HexDirection.bottomRight], 1.0)
]
const
    forwardVector*   = directions2Vectors[HexDirection.bottomRight]
    downwardVector*  = directions2Vectors[HexDirection.bottomLeft]

const directions2CoordsOffsets: array[HexDirection, Coords] = [
    HexDirection.bottomLeft:   newCoords( 0, 1),
    HexDirection.left:         newCoords(-1, 1),
    HexDirection.topLeft:      newCoords(-1, 0),
    HexDirection.topRight:     newCoords( 0,-1),
    HexDirection.right:        newCoords( 1,-1),
    HexDirection.bottomRight:  newCoords( 1, 0)
]

proc `+`*(p1, p2: Coords): Coords = newCoords(p1.x + p2.x, p1.y + p2.y)

iterator getNeighborTiles(grid: HexGrid, coords: Coords): Coords =
    HexDirection.enumIterate(dir):
        let
            offset = directions2CoordsOffsets[dir]
            neighCand = coords + offset
        if grid.inside(neighCand):
            yield neighCand

iterator getNeighborTiles(grid: HexGrid, ind: int): Coords =
    let coords = grid.ind2Coords(ind)
    for neighbor in grid.getNeighborTiles(coords):
        yield neighbor

iterator getNeighborTilesAndSelf(grid: HexGrid, coords: Coords): Coords =
    yield coords
    for neighbor in grid.getNeighborTiles(coords):
        yield neighbor

iterator getNeighborTilesAndSelf(grid: HexGrid, ind: int): Coords =
    let coords = grid.ind2Coords(ind)
    for neighbor in grid.getNeighborTilesAndSelf(coords):
        yield neighbor

proc getStateAt*(grid: HexGrid, ind: int): TileState = grid.tileStates[ind]
proc getStateAt*(grid: HexGrid, coords: Coords): TileState = grid.getStateAt(grid.coords2Ind(coords))

proc `[]`(grid: HexGrid, ind: int): TileState = grid.getStateAt(ind)
proc `[]`(grid: HexGrid, coords: Coords): TileState = grid.getStateAt(coords)

proc setStateAt(grid: HexGrid, ind: int, newState: TileState) = grid.tileStates[ind] = newState
proc setStateAt(grid: HexGrid, coords: Coords, newState: TileState) = grid.setStateAt(grid.coords2Ind(coords), newState)

proc `[]=`(grid: HexGrid, ind: int, newState: TileState) = grid.setStateAt(ind, newState)
proc `[]=`(grid: HexGrid, coords: Coords, newState: TileState) = grid[grid.coords2Ind(coords)] = newState

proc isEmptyAt*(grid: HexGrid, ind: int): bool = grid[ind] == TileState.empty
proc isEmptyAt*(grid: HexGrid, coords: Coords): bool = grid.isEmptyAt(grid.coords2Ind(coords))

proc isRaisedAt(grid: HexGrid, ind: int): bool = grid[ind] == TileState.raised
proc isRaisedAt(grid: HexGrid, coords: Coords): bool = grid.isRaisedAt(grid.coords2Ind(coords))

proc isVoidAt(grid: HexGrid, ind: int): bool = not grid.inside(ind) or grid.isEmptyAt(ind)
proc isVoidAt(grid: HexGrid, coords: Coords): bool = not grid.inside(coords) or grid.isEmptyAt(coords)

const tileStates2Opposite: array[TileState, TileState] = [
    TileState.empty:      TileState.empty,
    TileState.collapsed:  TileState.raised,
    TileState.raised:     TileState.collapsed
]

proc flipStateAt(grid: HexGrid, ind: int) = grid[ind] = tileStates2Opposite[grid[ind]]
proc flipStateAt(grid: HexGrid, coords: Coords) = grid.flipStateAt(grid.coords2Ind(coords))

proc flipWithNeighbors(grid: HexGrid, ind: int) =
    for neighbor in grid.getNeighborTilesAndSelf(ind):
        grid.flipStateAt(neighbor)
proc flipWithNeighbors(grid: HexGrid, coords: Coords) = grid.flipWithNeighbors(grid.coords2Ind(coords))

proc getEffectAt*(grid: HexGrid, ind: int): TileEffect = grid.tileEffects[ind]
proc getEffectAt*(grid: HexGrid, coords: Coords): TileEffect = grid.getEffectAt(grid.coords2Ind(coords))

method affect(e: NeighborTileEffect, grid: HexGrid, coords: Coords) = grid.flipWithNeighbors(coords)
method affect(e: LinearTileEffect, grid: HexGrid, coords: Coords) =
    grid.flipStateAt(coords)
    for opposite in @[false, true]:
        let
            dir = if opposite: directions2Opposites[e.direction] else: e.direction
            offset = directions2CoordsOffsets[dir]
        var next = coords + offset
        # TODO maybe decide if check only inside allowed?
        # while (if e.ignoreEmpty: grid.inside(next) else: not grid.isVoidAt(next)):
        while not grid.isVoidAt(next):
            grid.flipStateAt(next)
            next = next + offset

proc actionAt*(grid: HexGrid, ind: int): bool =
    if not grid.isVoidAt(ind):
        grid.tileEffects[ind].affect(grid, grid.ind2Coords(ind))
        result = true
proc actionAt*(grid: HexGrid, coords: Coords): bool = grid.actionAt(grid.coords2Ind(coords))

proc isWin*(grid: HexGrid): bool =
    result = true
    for ind in grid.indices:
        if not grid.isEmptyAt(ind) and not grid.isRaisedAt(ind):
            result = false
            return

when isMainModule:
    let hexGrid = newHexGrid(4)

    for i in 0 .. hexGrid.nTiles:
        let coords = hexGrid.ind2Coords(i)
        stdout.write $i & "(" & $coords & " = " & $hexGrid.coords2Ind(coords) & ") -> "
        for neighbor in hexGrid.getNeighborTiles(i):
            stdout.write $hexGrid.coords2Ind(neighbor) & ", "
        echo ""

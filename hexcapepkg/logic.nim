import math
import random
import basic2d
import sdl2

#        ===================
# row  //                   \\
# 0 => ||   0 - 1 - 2 - 3   ||
#      ||   |   | / | / |   ||
# 1 => ||   4 - 5 - 6 - 7   ||
#      ||   | / | / | / |   ||
# 2 => ||   8 - 9 -10 -11   ||
#      ||   | / | / | / |   ||
# 3 => ||  12 -13 -14 -15   ||
#      \\                   //
#        ===================
#           ^   ^   ^   ^
#           |   |   |   |
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
    TileState {.pure.} = enum empty, collapsed, raised
    # directions in clockwise order
    Direction {.pure.} = enum bottomLeft, left, topLeft, topRight, right, bottomRight

    HexGrid = ref object
        width: int
        tileStates: seq[TileState]

proc newHexGrid(width: int, tileStates: seq[TileState]): HexGrid =
    new result
    result.width = width
    result.tileStates = tileStates

proc newHexGrid(width: int): HexGrid =
    var s = newSeq[TileState](width * width)
    newHexGrid(width, s)

proc nTiles(grid: HexGrid): int = grid.width * grid.width

proc ind2Coords(grid: HexGrid, ind: int): Point =
    point(ind mod grid.width, ind div grid.width)

proc coords2Ind(grid: HexGrid, coords: Point): int =
    coords.x + coords.y * grid.width

iterator indices*(grid: HexGrid): int = 
    for i in countup(0, grid.nTiles - 1):
        yield i

iterator coords*(grid: HexGrid): Point = 
    for i in grid.indices:
        yield grid.ind2Coords(i)

proc inside(grid: HexGrid, coords: Point): bool =
    coords.x >= 0 and coords.y >= 0 and coords.x < grid.width and coords.y < grid.width

proc randomize(grid: HexGrid) =
    for i in grid.indices:
        grid.tileStates[i] = TileState(random(high(TileState).int + 1))

const directions2Offsets: array[Direction, Point] = [
    Direction.bottomLeft:   point( 0, 1),
    Direction.left:         point(-1, 1),
    Direction.topLeft:      point(-1, 0),
    Direction.topRight:     point( 0,-1),
    Direction.right:        point( 1,-1),
    Direction.bottomRight:  point( 1, 0)
]

proc `+`(p1, p2: Point): Point = point(p1.x + p2.x, p1.y + p2.y)

iterator getNeighborTiles*(grid: HexGrid, coords: Point): Point =
    for dirOrd in ord(low(Direction)) .. ord(high(Direction)):
        let
            dir = Direction(dirOrd)
            offset = directions2Offsets[dir]
            neighCand = coords + offset
        if grid.inside(neighCand):
            yield neighCand

iterator getNeighborTiles*(grid: HexGrid, ind: int): Point =
    let coords = grid.ind2Coords(ind)
    for neighbor in grid.getNeighborTiles(coords):
        yield neighbor

iterator getNeighborTilesAndSelf*(grid: HexGrid, coords: Point): Point =
    yield coords
    for neighbor in grid.getNeighborTiles(coords):
        yield neighbor

iterator getNeighborTilesAndSelf*(grid: HexGrid, ind: int): Point =
    let coords = grid.ind2Coords(ind)
    for neighbor in grid.getNeighborTilesAndSelf(coords):
        yield neighbor

proc test_getNeighborTiles =
    let hexGrid = newHexGrid(4)

    for i in countup(0, 15):
        let coords = hexGrid.ind2Coords(i)
        stdout.write $i & "(" & $coords & " = " & $hexGrid.coords2Ind(coords) & ") -> " 
        for neighbor in hexGrid.getNeighborTiles(i):
            stdout.write $hexGrid.coords2Ind(neighbor) & ", "
        echo ""

proc getStateAt(grid: HexGrid, ind: int): TileState = grid.tileStates[ind]
proc getStateAt(grid: HexGrid, coords: Point): TileState = grid.getStateAt(grid.coords2Ind(coords))

proc setStateAt(grid: HexGrid, ind: int, newState: TileState) = grid.tileStates[ind] = newState
proc setStateAt(grid: HexGrid, coords: Point, newState: TileState) = grid.setStateAt(grid.coords2Ind(coords), newState)

proc isEmptyAt(grid: HexGrid, ind: int): bool = grid.getStateAt(ind) == TileState.empty
proc isEmptyAt(grid: HexGrid, coords: Point): bool = grid.isEmptyAt(grid.coords2Ind(coords))

proc isRaisedAt(grid: HexGrid, ind: int): bool = grid.getStateAt(ind) == TileState.raised
proc isRaisedAt(grid: HexGrid, coords: Point): bool = grid.isEmptyAt(grid.coords2Ind(coords))

const tileStates2Opposite: array[TileState, TileState] = [
    TileState.empty:        TileState.empty,
    TileState.collapsed:    TileState.raised,
    TileState.raised:       TileState.collapsed
]

proc flipStateAt(grid: HexGrid, ind: int) = grid.setStateAt(ind, tileStates2Opposite[grid.getStateAt(ind)])
proc flipStateAt(grid: HexGrid, coords: Point) = grid.flipStateAt(grid.coords2Ind(coords))

proc flipWithNeighbors(grid: HexGrid, ind: int) =
    for neighbor in grid.getNeighborTilesAndSelf(ind):
        stdout.write $neighbor & ", "
        grid.flipStateAt(neighbor)
    echo ""
proc flipWithNeighbors(grid: HexGrid, coords: Point) = grid.flipWithNeighbors(grid.coords2Ind(coords))

proc actionAt(grid: HexGrid, coords: Point): bool =
    if grid.inside(coords) and not grid.isEmptyAt(coords):
        grid.flipWithNeighbors(coords)
        result = true
proc actionAt(grid: HexGrid, ind: int): bool = grid.actionAt(grid.ind2Coords(ind))

proc isWin(grid: HexGrid): bool =
    result = true
    for ind in grid.indices:
        if not grid.isEmptyAt(ind) and not grid.isRaisedAt(ind):
            result = false
            return

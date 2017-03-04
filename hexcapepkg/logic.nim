import math
import random
import basic2d

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
    TileState* {.pure.} = enum tsEmpty, tsCollapsed, tsRaised
    # directions in clockwise order
    TileType* {.pure.} = enum
        ttAllNeighbors, 
        ttLeftRight
    HexDirection* {.pure.} = enum
        hdBottomLeft,
        hdLeft,
        hdTopLeft,
        hdTopRight,
        hdRight,
        hdBottomRight

    HexGrid* = ref object
        width*: int
        tileStates: seq[TileState]
        tileTypes: seq[TileType]
    
    Coords* = object
        x*, y*: int

proc newHexGrid(width: int, tileStates: seq[TileState], tileTypes: seq[TileType]): HexGrid =
    new result
    result.width = width
    result.tileStates = tileStates
    result.tileTypes = tileTypes

proc newHexGrid*(width: int): HexGrid =
    let
        nTiles = width * width
        states = newSeq[TileState](nTiles)
        types = newSeq[TileType](nTiles)
    newHexGrid(width, states, types)

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
        grid.tileStates[i] = TileState(random(high(TileState).int + 1))

const directions2Angles*: array[HexDirection, float] = [
    HexDirection.hdBottomLeft:   120.0.degToRad,
    HexDirection.hdLeft:         180.0.degToRad,
    HexDirection.hdTopLeft:      240.0.degToRad,
    HexDirection.hdTopRight:     300.0.degToRad,
    HexDirection.hdRight:          0.0.degToRad,
    HexDirection.hdBottomRight:   60.0.degToRad 
]
const directions2Vectors*: array[HexDirection, Vector2d] = [
    HexDirection.hdBottomLeft:   polarVector2d(directions2Angles[HexDirection.hdBottomLeft],  1.0),
    HexDirection.hdLeft:         polarVector2d(directions2Angles[HexDirection.hdLeft],        1.0),
    HexDirection.hdTopLeft:      polarVector2d(directions2Angles[HexDirection.hdTopLeft],     1.0),
    HexDirection.hdTopRight:     polarVector2d(directions2Angles[HexDirection.hdTopRight],    1.0),
    HexDirection.hdRight:        polarVector2d(directions2Angles[HexDirection.hdRight],       1.0),
    HexDirection.hdBottomRight:  polarVector2d(directions2Angles[HexDirection.hdBottomRight], 1.0) 
]
const
    forwardVector*   = directions2Vectors[HexDirection.hdBottomRight]
    downwardVector*  = directions2Vectors[HexDirection.hdBottomLeft]

const directions2CoordsOffsets: array[HexDirection, Coords] = [
    HexDirection.hdBottomLeft:   newCoords( 0, 1),
    HexDirection.hdLeft:         newCoords(-1, 1),
    HexDirection.hdTopLeft:      newCoords(-1, 0),
    HexDirection.hdTopRight:     newCoords( 0,-1),
    HexDirection.hdRight:        newCoords( 1,-1),
    HexDirection.hdBottomRight:  newCoords( 1, 0)
]

proc `+`*(p1, p2: Coords): Coords = newCoords(p1.x + p2.x, p1.y + p2.y)

template enumRange(enumType: typedesc): untyped = enumType.low.ord .. enumType.high.ord
template iterateEnum(v: untyped, enumType: typedesc, body: untyped): untyped =
    for i in enumRange(enumType):
        let v = enumType(i)
        body

iterator getNeighborTiles(grid: HexGrid, coords: Coords): Coords =
    iterateEnum(dir, HexDirection):
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

proc isEmptyAt*(grid: HexGrid, ind: int): bool = grid[ind] == TileState.tsEmpty
proc isEmptyAt*(grid: HexGrid, coords: Coords): bool = grid.isEmptyAt(grid.coords2Ind(coords))

proc isRaisedAt(grid: HexGrid, ind: int): bool = grid[ind] == TileState.tsRaised
proc isRaisedAt(grid: HexGrid, coords: Coords): bool = grid.isRaisedAt(grid.coords2Ind(coords))

proc isVoidAt(grid: HexGrid, ind: int): bool = not grid.inside(ind) or grid.isEmptyAt(ind)
proc isVoidAt(grid: HexGrid, coords: Coords): bool = grid.isVoidAt(grid.coords2Ind(coords))

const tileStates2Opposite: array[TileState, TileState] = [
    TileState.tsEmpty:      TileState.tsEmpty,
    TileState.tsCollapsed:  TileState.tsRaised,
    TileState.tsRaised:     TileState.tsCollapsed
]

proc flipStateAt(grid: HexGrid, ind: int) = grid[ind] = tileStates2Opposite[grid[ind]]
proc flipStateAt(grid: HexGrid, coords: Coords) = grid.flipStateAt(grid.coords2Ind(coords))

proc flipWithNeighbors(grid: HexGrid, ind: int) =
    for neighbor in grid.getNeighborTilesAndSelf(ind):
        grid.flipStateAt(neighbor)
proc flipWithNeighbors(grid: HexGrid, coords: Coords) = grid.flipWithNeighbors(grid.coords2Ind(coords))

proc actionAt*(grid: HexGrid, ind: int): bool =
    if not grid.isVoidAt(ind):
        grid.flipWithNeighbors(ind)
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

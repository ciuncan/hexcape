import basic2d

proc genNGonPoints*(center: Vector2d, radius: float,
                    n = 6, rotate = 0.0): seq[Point2d] =
    result = newSeq[Point2d](n)

    for i in 0 ..< n:
        let startAngle = (i.float * (360.0 / n.float) + rotate).degToRad
        result[i] = ORIGO.polar(startAngle, radius) + center

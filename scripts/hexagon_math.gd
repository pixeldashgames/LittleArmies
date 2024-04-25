class_name HexagonMath

class HexPathCell:
    var cell: Vector2i
    var entry_side: int
    var entry_point: float

    func _init(coords: Vector2i, side: int, point: float):
        cell = coords
        entry_side = side
        entry_point = point
    
    func _to_string() -> String:
        return "Cell: " + str(cell) + ", Entry Side: " + str(entry_side) + ", Entry Point: " + str(entry_point)
        
class HexTriangle:
    var hex_side: int
    var prev_side: int
    var entry_side: int
    var entry_point: float
    var first_entry: bool

    func _init(triangle: int, prev: int, entry: int, point: float, first := false):
        hex_side = triangle
        prev_side = prev
        entry_side = entry
        entry_point = point
        first_entry = first
    
    func _to_string() -> String:
        return "Hex Side: " + str(hex_side) + ", Previous Side: " + str(prev_side) + ", Entry Side: " + str(entry_side) + ", Entry Point: " + str(entry_point) + ", First Entry: " + str(first_entry)
    
class GetNextTriangleResponse:
    var triangle: HexTriangle
    var cell: HexPathCell
    var left_cell: bool

    func _init(new_triangle, new_cell, left):
        triangle = new_triangle
        cell = new_cell
        left_cell = left

static func get_cells_between(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
    var cells: Array[Vector2i] = [ from ]

    var from_pos = Vector2(from.x * 2 + from.y % 2, from.y * sqrt(3))
    var to_pos = Vector2(to.x * 2 + to.y % 2, to.y * sqrt(3))

    var direction = (to_pos - from_pos).normalized()

    var current = _get_cell_from_center(from, direction)
    cells.append(current.cell)

    while current.cell != to:
        current = _get_next_cell(current, direction)
        cells.append(current.cell)
    
    return cells

static func _hex_side_to_adjacent(pos: Vector2i, side: int) -> Vector2i:
    # clockwise from the right
    var dirs: Array[Vector2i] = [
        Vector2i(1, 0),
        Vector2i(0, 1) if pos.y % 2 == 0 else Vector2i(1, 1),
        Vector2i(-1, 1) if pos.y % 2 == 0 else Vector2i(0, 1),
        Vector2i(-1, 0),
        Vector2i(-1, -1) if pos.y % 2 == 0 else Vector2i(0, -1),
        Vector2i(0, -1) if pos.y % 2 == 0 else Vector2i(1, -1),
    ]

    return pos + dirs[side]

static func _triangle_side_to_adjacent_triangle(triangle: int, side: int) -> int:
    # set side to an invalid value for oposite triangle
    if side < 0 or side > 2:
        return (triangle + 3) % 6
    
    # clockwise starting from outer side

    if side == 0:
        assert(false, "Can't get adjacent triangle from outer side")
        return -1
    
    if side == 1:
        return (triangle + 1) % 6
    else:
        return (triangle - 1) % 6

static func _vector_angle(v: Vector2) -> float:
    var angle = v.angle()
    return angle if angle >= 0 else angle + 2 * PI

static func _get_cell_from_center(start: Vector2i, direction: Vector2) -> HexPathCell:
    var angle: float = _vector_angle(direction) + PI / 6
    var side: int = floori(angle / (PI / 3))
    var side_point: float = (angle - side * (PI / 3)) / (PI / 3)
    var adjacent = _hex_side_to_adjacent(start, side)
    return HexPathCell.new(adjacent, (side + 3) % 6, side_point)

static func _get_next_cell(current: HexPathCell, direction: Vector2) -> HexPathCell:
    var current_triangle := HexTriangle.new(current.entry_side, -1, 0, current.entry_point, true)

    print(current)
    print(current_triangle)

    var response := _get_next_triangle(current_triangle, direction, current) 

    while not response.left_cell:
        response = _get_next_triangle(response.triangle, direction, current) 

    return response.cell

static func _get_triangle_side_vector(triangle: int, triangle_side: int) -> Vector2:
    # offset so side indexes are as in the reference triangle 
    # (the right one or lower right one if triangle is even or odd respectively)
    triangle_side = (triangle_side + triangle / 2 ) % 3

    var even_triangle_vectors = [
        Vector2.DOWN,
        Vector2.from_angle(-5 * PI / 6),
        Vector2.from_angle(-PI / 6),
    ]

    var odd_triangle_vectors = [
        Vector2.from_angle(5 * PI / 6),
        Vector2.UP,
        Vector2.from_angle(PI / 6),
    ]

    if triangle % 2 == 0:
        return even_triangle_vectors[triangle_side]
    else:
        return odd_triangle_vectors[triangle_side]  

static func _get_next_triangle(current: HexTriangle, direction: Vector2, from_cell: HexPathCell) -> GetNextTriangleResponse:
    var side_vector := _get_triangle_side_vector(current.hex_side, current.entry_side)

    print(current)

    # the side vectors are always oriented clockwise
    var cw_side_angle := absf(side_vector.angle_to(direction))
    var ccw_side_angle := PI - cw_side_angle
    
    # entry_point is always asumed to refer to the clockwise side
    var cw_side = current.entry_point
    var ccw_side = 1 - current.entry_point

    # obtained through sum of angles in a triangle
    var cw_opposite_angle = PI - PI / 3 - cw_side_angle
    var ccw_opposite_angle = PI - PI / 3 - ccw_side_angle

    # invalid values are assigned by default
    var cw_entry = 100
    var ccw_entry = 100

    if cw_opposite_angle > 0:
        cw_entry = cw_side * sin(cw_side_angle) / sin(cw_opposite_angle)
    
    if ccw_opposite_angle > 0:
        ccw_entry = ccw_side * sin(ccw_side_angle) / sin(ccw_opposite_angle)
    
    if abs(cw_entry - ccw_entry) <= 0.001:
        if current.entry_side == 0:
            var next_cell := _get_cell_from_center(from_cell.cell, direction)
            return GetNextTriangleResponse.new(\
                HexTriangle.new(next_cell.entry_side, -1, 0, next_cell.entry_point, true),\
                next_cell, true)
        
        # for each triangle in the hexagon, the array is ordered as:
        # for each vertex of the triangle except the central one:
        # [triangle of the new cell, entry point of the new cell, side of this cell that leads to that one]
        var triangle_vertex_exits_array = [
            [[1, 1.0, 5], [5, 0.0, 1]],
            [[2, 1.0, 0], [0, 0.0, 2]],
            [[3, 1.0, 1], [1, 0.0, 3]],
            [[4, 1.0, 2], [2, 0.0, 4]],
            [[5, 1.0, 3], [3, 0.0, 5]],
            [[0, 1.0, 4], [4, 0.0, 0]]
        ]

        var this_data = triangle_vertex_exits_array[current.hex_side][current.entry_side - 1]
        # ^ entry side - 1 to since we are not counting the vertex opposite to the outer side

        var next_cell_entry_side = this_data[0]
        var next_cell_entry_point = this_data[1]
        var next_cell_coords = _hex_side_to_adjacent(from_cell.cell, this_data[2])

        return GetNextTriangleResponse.new(\
            HexTriangle.new(next_cell_entry_side, -1, 0, next_cell_entry_point, true),\
            HexPathCell.new(next_cell_coords, next_cell_entry_side, next_cell_entry_point), true)
    
    if cw_entry < 1:
        var next_side = (current.hex_side + (1 if current.first_entry else -1)) % 6
        if next_side == current.prev_side:
            return GetNextTriangleResponse.new(\
                HexTriangle.new((current.hex_side + 3) % 6, -1, 0, cw_entry, true),\
                HexPathCell.new(_hex_side_to_adjacent(from_cell.cell, current.hex_side),\
                    (current.hex_side + 3) % 6, cw_entry), true)
        else:
            return GetNextTriangleResponse.new(\
                HexTriangle.new(next_side, current.hex_side, 2 if current.first_entry else 1, cw_entry), from_cell, false)
    
    if ccw_entry < 1:
        var next_side = (current.hex_side - (1 if current.first_entry else -1)) % 6
        if next_side == current.prev_side:
            return GetNextTriangleResponse.new(\
                HexTriangle.new((current.hex_side + 3) % 6, -1, 0, 1 - ccw_entry, true),\
                HexPathCell.new(_hex_side_to_adjacent(from_cell.cell, current.hex_side),\
                    (current.hex_side + 3) % 6, 1 - ccw_entry), true)
        else:
            return GetNextTriangleResponse.new(\
                HexTriangle.new(next_side, current.hex_side, 1 if current.first_entry else 2, 1 - ccw_entry), from_cell, false)
    
    assert(false, "Unexpected result on _get_next_triangle")
    return GetNextTriangleResponse.new(HexTriangle.new(-1, -1, -1, -1), HexPathCell.new(Vector2i(-1, -1), -1, -1), false)

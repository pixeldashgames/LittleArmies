using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

public partial class HexCellsBetween : Node
{
    const float SQRT3 = 1.73205080757f;

    private static int Mod(int a, int b)
    {
        return (a % b + b) % b;
    }
    private static Vector2 GetCellPos(Vector2I cell)
    {
        return new Vector2(cell.X * 2 + Mod(cell.Y, 2), cell.Y * SQRT3);
    }
    private static Vector2I HexSideToAdjacent(Vector2I pos, int side)
    {
        var dirs = new Vector2I[]
        {
            new(1, 0),
            Mod(pos.Y, 2) == 0 ? new(0, 1) : new(1, 1),
            Mod(pos.Y, 2) == 0 ? new(-1, 1) : new(0, 1),
            new(-1, 0),
            Mod(pos.Y, 2) == 0 ? new(-1, -1) : new(0, -1),
            Mod(pos.Y, 2) == 0 ? new(0, -1) : new(1, -1)
        };

        return pos + dirs[side];
    }

    public Array<Array<Vector2I>> GetAllCellsBetween(Vector2I from, Array<Vector2I> targets)
    {
        var results = new Array<Vector2I>[targets.Count];

        Parallel.For(0, targets.Count, i =>
        {
            results[i] = GetCellsBetween(from, targets[i]);
        });

        return new Array<Array<Vector2I>>(results);
    }

    public Array<Vector2I> GetCellsBetween(Vector2I from, Vector2I to)
    {
        var cells = new Array<Vector2I> { from };

        var target = GetCellPos(to);
        var origin = GetCellPos(from);

        var originToTarget = (target - origin).Normalized();

        var current = from;

        var visited = new List<Vector2I>();

        while (current != to)
        {
            var currentPos = GetCellPos(current);

            List<(Vector2I cell, Vector2 pos)> adjacents = Enumerable.Range(0, 6).Select(n =>
            {
                Vector2I adj = HexSideToAdjacent(current, n);
                return (adj, GetCellPos(adj));
            }).Where(a => !visited.Contains(a.adj)).ToList();

            visited.AddRange(adjacents.Select(a => a.cell));

            if (adjacents.Any(n => n.cell == to))
            {
                cells.Add(to);
                return cells;
            }

            List<(Vector2I cell, float dot)> dots = adjacents.Select(n =>
            {
                if (origin == n.pos)
                    return (n.cell, -1f);

                var originToAdj = (n.pos - origin).Normalized();

                return (n.cell, originToAdj.Dot(originToTarget));
            }).OrderByDescending<(Vector2I cell, float dot), float>(d => d.dot).ToList();

            if (dots.Count > 1 && MathF.Abs(dots[0].dot - dots[1].dot) <= 0.0001)
            {
                cells.Add(dots[1].cell);
            }

            current = dots[0].cell;
            cells.Add(current);
        }

        return cells;
    }
}

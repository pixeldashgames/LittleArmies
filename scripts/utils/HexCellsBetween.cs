using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

public partial class HexCellsBetween : Node
{
    public struct BetweenLevel(Vector2I first, Vector2I? second = null)
    {
        public readonly Vector2I First => first;
        public Vector2I? Second
        {
            readonly get => second;
            set => second = value;
        }
    }

    const float SQRT3 = 1.73205080757f;

    private static int Mod(int a, int b)
    {
        return (a % b + b) % b;
    }
    public static Vector2 GetCellPos(Vector2I cell)
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

    public static List<BetweenLevel>[] GetAllCellsBetween(Vector2I from, List<Vector2I> targets)
    {
        var results = new List<BetweenLevel>[targets.Count];

        Parallel.For(0, targets.Count, i =>
        {
            results[i] = GetCellsBetween(from, targets[i]);
        });

        return results;
    }

    // public static List<BetweenLevel> GetCellsBetween(Vector2I from, Vector2I to)
    // {
    //     List<BetweenLevel> cells = [new(from)];

    //     var target = GetCellPos(to);
    //     var origin = GetCellPos(from);

    //     var originToTarget = (target - origin).Normalized();

    //     var current = from;

    //     var visited = new List<Vector2I>();

    //     while (current != to)
    //     {
    //         var currentPos = GetCellPos(current);

    //         var adjacents = Enumerable.Range(0, 6)
    //             .Select(n => HexSideToAdjacent(current, n))
    //             .Where(a => !visited.Contains(a)).ToList()
    //             .Select(a => (cell: a, pos: GetCellPos(a)));

    //         float bestDot = -1;
    //         BetweenLevel betweenLevel = new(from);

    //         foreach (var (cell, pos) in adjacents)
    //         {
    //             if (cell == to)
    //             {
    //                 cells.Add(new(to));
    //                 return cells;
    //             }
    
    //             visited.Add(cell);

    //             var originToAdj = (pos - origin).Normalized();

    //             var dot = originToAdj.Dot(originToTarget);

    //             if (MathF.Abs(dot - bestDot) <= 0.0001) {
    //                 betweenLevel.Second = cell;
    //             }
    //             else if (dot > bestDot) {
    //                 bestDot = dot;
    //                 betweenLevel = new(cell);
    //             }
    //         }

    //         current = betweenLevel.First;
    //         cells.Add(betweenLevel);
    //     }

    //     return cells;
    // }

    public static List<BetweenLevel> GetCellsBetween(Vector2I from, Vector2I to)
    {
        List<BetweenLevel> cells = [new(from)];

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
                cells.Add(new(to));
                return cells;
            }

            List<(Vector2I cell, float dot)> dots = adjacents.Select(n =>
            {
                if (origin == n.pos)
                    return (n.cell, -1f);

                var originToAdj = (n.pos - origin).Normalized();

                return (n.cell, originToAdj.Dot(originToTarget));
            }).OrderByDescending<(Vector2I cell, float dot), float>(d => d.dot).ToList();

            current = dots[0].cell;

            if (dots.Count > 1 && MathF.Abs(dots[0].dot - dots[1].dot) <= 0.0001)
                cells.Add(new(current, dots[1].cell));
            else
                cells.Add(new(current));
        }

        return cells;
    }
}
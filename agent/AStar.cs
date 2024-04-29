using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
#nullable enable
class Block((int, int) position, int turn = 1)
{

    public (int, int) Position = position;
    public Block? Parent;
    public int GCost = turn;
    public float ShortestPath = float.MaxValue;

    public Vector2I GetPosition()
    {
        return new Vector2I(Position.Item1, Position.Item2);
    }
}

class AStar(Vector2I start, Vector2I end, Func<Vector2I, bool> finishCondition, Func<Vector2I, IEnumerable<Vector2I>> getNeightbors, float w = 1f)
{
    private readonly Func<Vector2I, IEnumerable<Vector2I>> getNeightbors = getNeightbors;
    private readonly float w = w;
    private readonly Vector2I start = start;
    private readonly Vector2I end = end;
    private readonly Func<Vector2I, bool> finishCondition = finishCondition;

    private Block CreateBlock(Vector2I position, int turn = 1)
    {
        return new Block((position.X, position.Y), turn);
    }
    private float W => w;
    private List<Block> _openList = [];
    private List<Block> _closedList = [];
    private void UpdateDistance(Block neighbour, Block currentBlock, Block endBlock)
    {
        var newGCost = currentBlock.GCost + 1;
        var newHCost = W * GetDistance(neighbour, endBlock);
        var newCost = newGCost + newHCost;
        if (!(newCost < neighbour.ShortestPath) && _openList.Contains(neighbour)) return;
        neighbour.GCost = newGCost;
        neighbour.ShortestPath = newCost;
        neighbour.Parent = currentBlock;
    }
    private static float GetDistance(Block neighbour, Block endBlock)
    {
        // Calculate euclidian distance
        return MathF.Sqrt(MathF.Pow(neighbour.Position.Item1 - endBlock.Position.Item1, 2)
                          + MathF.Pow(neighbour.Position.Item2 - endBlock.Position.Item2, 2));
    }


    public List<Block> FindPath()
    {
        var (startBlock, endBlock) = (CreateBlock(start), CreateBlock(end));

        startBlock.GCost = 0;
        _openList.Add(startBlock);

        while (_openList.Count > 0)
        {
            var currentBlock = _openList[0];

            GD.Print(currentBlock.GetPosition());

            _openList.Remove(currentBlock);
            _closedList.Add(currentBlock);

            if (currentBlock == endBlock)
            {
                return ReconstructPath(currentBlock);
            }

            var neighbours = getNeightbors(currentBlock.GetPosition()).Select(CreateBlock);
            foreach (var neighbour in neighbours)
            {
                if (_closedList.Any(b => b.Position.Item1 == neighbour.Position.Item1 && b.Position.Item2 == neighbour.Position.Item2))
                {
                    continue;
                }

                if (finishCondition(neighbour.GetPosition()))
                {
                    return ReconstructPath(neighbour);
                }

                UpdateDistance(neighbour, currentBlock, endBlock);

                if (_openList.Any(b => b.Position.Item1 == neighbour.Position.Item1 && b.Position.Item2 == neighbour.Position.Item2)) continue;
                _openList.Add(neighbour);
            }
            _openList.Sort((a, b) => a.ShortestPath.CompareTo(b.ShortestPath));
        }
        throw new Exception("Path not found");
    }

    private static List<Block> ReconstructPath(Block currentBlock)
    {
        var path = new List<Block>();
        while (currentBlock.Parent != null)
        {
            path.Add(currentBlock);
            currentBlock = currentBlock.Parent;
        }
        path.Add(currentBlock);
        path.Reverse();
        return path;
    }
}
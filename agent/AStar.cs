using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

#nullable enable

public static class AStar
{
    private class NodePath(Vector2I node, IEnumerable<Vector2I> path, int turnsPassed) {
        public Vector2I Node => node;
        public IEnumerable<Vector2I> Path => path;
        public int TurnsPassed => turnsPassed;

        public NodePath Append(Vector2I node)
        {
            return new NodePath(node, Path.Append(node), TurnsPassed + 1);
        }
    }

    private class VisitedNode(Vector2I node, float weight) : IEquatable<VisitedNode>
    {
        public Vector2I Node => node;
        public float Weight => weight;

        public bool Equals(VisitedNode? other)
        {
            if (other == null)
                return false;

            return other.Node == Node;
        }

        public override bool Equals(object? obj)
        {
            return Equals(obj as VisitedNode);
        }

        public override int GetHashCode()
        {
            return Node.GetHashCode();
        }

    }

    private static float GetNodeWeight(Vector2I node, Vector2I end, int turnsPassed, float w = 1f)
    {
        var g = turnsPassed + 1;
        var h = w * (node - end).Length();
        return g + h;
    }

    public static IEnumerable<Vector2I> Find(Vector2I start, Vector2I end, Func<Vector2I, bool> finishCondition, Func<Vector2I, IEnumerable<Vector2I>> getNeighbours, float w = 1f)
    {
        if (finishCondition(start))
            return [start];

        var visited = new HashSet<VisitedNode>
        {
            new(start, 0)
        };

        var queue = new PriorityQueue<NodePath, float>();
        queue.Enqueue(new NodePath(start, [start], 0), 0);
        
        while (queue.Count > 0)
        {
            var current = queue.Dequeue();

            foreach (var neighbour in getNeighbours(current.Node))
            {               
                if (finishCondition(neighbour))
                    return current.Path.Append(neighbour);

                var weight = GetNodeWeight(neighbour, end, current.TurnsPassed + 1, w);

                var visitedNode = new VisitedNode(neighbour, weight);

                var alreadyVisited = visited.FirstOrDefault(visitedNode.Equals);

                if (alreadyVisited != null)
                    if (alreadyVisited.Weight <= weight)
                        continue;
                    visited.Remove(alreadyVisited!);

                visited.Add(visitedNode);

                queue.Enqueue(current.Append(neighbour), weight);
            }
        }

        throw new ArgumentException("Path not found from " + start + " to " + end);
    }
}
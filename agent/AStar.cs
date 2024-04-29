class Block((int,int) position, bool isStart, bool isEnd, int turn = 1)
{
    
    public (int,int) Position = position;
    public Block? Parent;
    public bool IsStart = isStart;
    public bool IsEnd = isEnd;
    public int GCost = turn;
    public float ShortestPath = float.MaxValue;
}

class AStar(Block[,] map, Func<Block,IEnumerable<Block>>getNeightbors,  float w = 1f)
{
    private float W => w;
    private List<Block> _openList = [];
    private List<Block> _closedList = [];
    private (Block,Block) FindStartEnd()
    {
        Block? startBlock = null;
        Block? endBlock = null;
        foreach (var block in map)
        {
            if (block.IsStart)
            {
                startBlock = block;
            }
            if (block.IsEnd)
            {
                endBlock = block;
            }
        }
        
        if (startBlock == null || endBlock == null)
        {
            throw new Exception("Start or end block not found");
        }
        return (startBlock,endBlock);
    }
    private void UpdateDistance(Block neighbour, Block currentBlock, Block endBlock)
    {
        var newGCost = currentBlock.GCost + 1;
        var newHCost = W*GetDistance(neighbour,endBlock);
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

    // Directionals array in order to get the neighbours in the 8 directions
    private int[] _d1 = { 0, 1, 1, 1, 0, -1, -1, -1 };
    private int[] _d2 = { 1, 1, 0, -1, -1, -1, 0, 1 };

    private IEnumerable<Block> GetNeighbours(Block currentBlock)
    {
        for (var i = 0; i < _d1.Length; i++)
        {
            var x = currentBlock.Position.Item1 + _d1[i];
            var y = currentBlock.Position.Item2 + _d2[i];
            if (x >= 0 && x < map.GetLength(0) && y >= 0 && y < map.GetLength(1))
            {
                yield return map[x, y];
            }
        }
    }
    public List<Block> FindPath()
    {
        var (startBlock, endBlock) = FindStartEnd();
        
        startBlock.GCost = 0;
        _openList.Add(startBlock);

        while (_openList.Count > 0)
        {
            var currentBlock = _openList[0];

            _openList.Remove(currentBlock);
            _closedList.Add(currentBlock);

            if (currentBlock == endBlock)
            {
                return ReconstructPath(currentBlock);
            }

            var neighbours = GetNeighbours(currentBlock);
            foreach (var neighbour in neighbours)
            {
                if (_closedList.Contains(neighbour))
                {
                    continue;
                }
                
                UpdateDistance(neighbour, currentBlock, endBlock);

                if (_openList.Contains(neighbour)) continue;
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
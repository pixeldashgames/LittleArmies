using Godot;
using Godot.Collections;
using System;
using System.Threading;

public partial class KnowledgeUpdater : Node
{
    public void UpdateVisibilityMap(Node gameControllerNode, Vector2I position, float height, int team, float vigilance_range)
    {
        Thread mainUpdaterThread = new(new ParameterizedThreadStart(UpdateVisibilityMapThread));
        mainUpdaterThread.Start(new UpdateVisibilityMapParams(gameControllerNode, position, team, height, vigilance_range));
    }

    private void UpdateVisibilityMapThread(object parameters)
    {
        UpdateVisibilityMapParams paramsObj = (UpdateVisibilityMapParams)parameters;

        var cellsInRange = paramsObj.gameControllerNode.CallThreadSafe("get_cells_in_range", paramsObj.position, paramsObj.vigilance_range);

        var cellsArray = cellsInRange.As<Array<Vector2I>>();

        var cellDiscoveryThreads = new Thread[cellsArray.Count];

        foreach (var cell in cellsArray)
        {
            Thread t = new(new ParameterizedThreadStart(UpdateVisibilityOnCellThread));
            t.Start(new UpdateVisibilityOnCellParams(paramsObj.gameControllerNode, paramsObj.position, cell, paramsObj.height, paramsObj.team));
        }

        foreach (var thread in cellDiscoveryThreads)
        {
            thread.Join();
        }

        paramsObj.gameControllerNode.CallThreadSafe("finish_update_visibility_map");
    }

    private void UpdateVisibilityOnCellThread(object parameters)
    {
        var paramsObj = (UpdateVisibilityOnCellParams)parameters;

        paramsObj.gameControllerNode.CallThreadSafe("update_visibility_for_cell", paramsObj.from, paramsObj.to,
            paramsObj.fromHeight, paramsObj.team);
    }

    private class UpdateVisibilityOnCellParams
    {
        public Node gameControllerNode;
        public Vector2I from;
        public Vector2I to;
        public float fromHeight;
        public int team;

        public UpdateVisibilityOnCellParams(Node gameControllerNode, Vector2I from, Vector2I to, float fromHeight, int team)
        {
            this.gameControllerNode = gameControllerNode;
            this.team = team;
            this.from = from;
            this.to = to;
            this.fromHeight = fromHeight;

        }
    }

    private class UpdateVisibilityMapParams
    {
        public Node gameControllerNode;
        public Vector2I position;
        public int team;
        public float height;
        public float vigilance_range;

        public UpdateVisibilityMapParams(Node gameControllerNode, Vector2I position, int team, float height, float vigilance_range)
        {
            this.gameControllerNode = gameControllerNode;
            this.position = position;
            this.team = team;
            this.height = height;
            this.vigilance_range = vigilance_range;
        }
    }
}

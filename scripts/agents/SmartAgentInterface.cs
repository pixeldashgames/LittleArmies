using Agent;
using Agent.Enum;
using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

#nullable enable 

public partial class SmartAgentInterface : Node
{
    private Troop myTroop;
    [Export]
    public DesireState desire;

    [Signal]
    // [success, error_message]
    public delegate Godot.Collections.Array OnPromptReceivedEventHandler();

    private (IntentionAction, object?)? orderedAction;

    public Godot.Collections.Array GetMove(Dictionary thisUnit, Array<Dictionary> otherUnits, Array<Dictionary> castles, Callable getNeighbours, Callable getAdjacents, Callable getTerrainAt)
    {
        myTroop = DictToTroop(thisUnit);
        var troops = otherUnits.Select(DictToTroop).ToList();
        var towers = castles.Select(DictToTower).ToList();

        (IntentionAction, object?) action;

        if (orderedAction.HasValue && Agent.Agent.CheckOrder(orderedAction.Value.Item1, myTroop, troops, towers))
        {
            action = orderedAction.Value;
        }
        else
        {
            orderedAction = null;
            action = Agent.Agent.GetAction(myTroop, troops, towers);
        }

        var myPos = new Vector2I(myTroop.Position.Item1, myTroop.Position.Item2);

        IEnumerable<Vector2I> getNeighboursFunc(Vector2I p)
        {
            var neighbours = getNeighbours.Call(p);
            return neighbours.As<Array<Variant>>().Select(v => v.As<Array<Variant>>()[0].As<Vector2I>());
        }

        (Vector2I neigh, Array<Vector2I> path)[] getNeightboursFullFunc(Vector2I p)
        {
            var neighbours = getNeighbours.Call(p);
            return neighbours.As<Array<Variant>>().Select(n =>
            {
                var nArray = n.As<Array<Variant>>();
                return (nArray[0].As<Vector2I>(), nArray[1].As<Array<Vector2I>>());
            }).ToArray();
        }

        Array<Vector2I> getAdjacentsFunc(Vector2I p)
        {
            var adjacents = getAdjacents.Call(p);
            return adjacents.As<Array<Vector2I>>();
        }

        TerrainType getTerrainAtFunc(Vector2I p)
        {
            return GDTerrainToTerrainType((int)getTerrainAt.Call(p));
        }

        var neighbourPaths = getNeightboursFullFunc(myPos);

        Godot.Collections.Array getAttackResult() {
            var enemy = ((Troop)action.Item2!).Position;
            var enemyPos = new Vector2I(enemy.Item1, enemy.Item2);
            AStar attackAStar = new(myPos, enemyPos, p => p == enemyPos, getNeighboursFunc);
            var attackPos = attackAStar.FindPath()[0].GetPosition();

            if (attackPos == enemyPos)
            {
                var attack_from = getAdjacentsFunc(enemyPos)
                    .Where(p => neighbourPaths.Any(n => n.neigh == p))
                    .OrderByDescending(p => (int)getTerrainAtFunc(p)).First();

                var entry_path = neighbourPaths.First(n => n.neigh == attack_from).path;

                return [entry_path, attack_from, true];
            }
            else
            {
                var entry_path = neighbourPaths.First(n => n.neigh == attackPos).path;

                return [entry_path, attackPos, false];
            }
        }

        switch (action.Item1)
        {
            case IntentionAction.Wait:
                return [new Array<Vector2I> { myPos }, myPos, false];
            case IntentionAction.ConquerTower:
                var towerTarget = ((Tower)action.Item2!).Position;
                var towerPos = new Vector2I(towerTarget.Item1, towerTarget.Item2);
                AStar towerAStart = new(myPos, towerPos, p => p == towerPos, getNeighboursFunc);
                var stepPos = towerAStart.FindPath()[0].GetPosition();

                var path = neighbourPaths.First(n => n.neigh == stepPos).path;

                return [path, stepPos, false];
            case IntentionAction.Attack:
                return getAttackResult();
            case IntentionAction.StayClose:
                var ally = ((Troop)action.Item2!).Position;
                var allyPos = new Vector2I(ally.Item1, ally.Item2);
                AStar stayCloseAStar = new(myPos, allyPos, p => (p - allyPos).Length() <= 4, getNeighboursFunc);
                var stayClosePos = stayCloseAStar.FindPath()[0].GetPosition();

                if (stayClosePos == allyPos)
                {
                    var approach_from = getAdjacentsFunc(stayClosePos)
                        .Where(p => neighbourPaths.Any(n => n.neigh == p)).ToArray();

                    var r = new Random();

                    var approach = approach_from[r.Next() % approach_from.Length];

                    var entry_path = neighbourPaths.First(n => n.neigh == approach).path;

                    return [entry_path, approach, true];
                }
                else
                {
                    var stayClosePath = neighbourPaths.First(n => n.neigh == stayClosePos).path;

                    return [stayClosePath, stayClosePos, false];
                }
            case IntentionAction.Retreat:
                var closestAllies = troops
                    .Where(t => t.Defenders == myTroop.Defenders)
                    .Select(t => new Vector2I(t.Position.Item1, t.Position.Item2))
                    .OrderBy(t => (t - myPos).Length()).ToArray();

                if (closestAllies.Length == 0)
                    return getAttackResult();

                var closestAlly = closestAllies[0];

                AStar retreatAStar = new(myPos, closestAlly, p => p == closestAlly, getNeighboursFunc);
                var retreatPos = retreatAStar.FindPath()[0].GetPosition();

                if (retreatPos == closestAlly)
                {
                    var retreat_from = getAdjacentsFunc(closestAlly)
                        .Where(p => neighbourPaths.Any(n => n.neigh == p)).ToArray();

                    var r = new Random();

                    var retreat = retreat_from[r.Next() % retreat_from.Length];

                    var entry_path = neighbourPaths.First(n => n.neigh == retreat).path;

                    return [entry_path, retreat, false];
                }
                else
                {
                    var retreatPath = neighbourPaths.First(n => n.neigh == retreatPos).path;

                    return [retreatPath, retreatPos, false];
                }
            default:
                throw new IndexOutOfRangeException();
        }
    }

    public async Task ReceiveOrder(string prompt, Dictionary thisUnit, Array<Dictionary> otherUnits, Array<Dictionary> castles)
    {
        myTroop = DictToTroop(thisUnit);
        var troops = otherUnits.Select(DictToTroop).ToList();
        var towers = castles.Select(DictToTower).ToList();

        try
        {
            var result = await Agent.Agent.Nlp(prompt, myTroop, troops, towers);

            orderedAction = result;
        }
        catch (PromptException e)
        {
            EmitSignal(SignalName.OnPromptReceived, false, e.Message);
            return;
        }
        catch (Exception e)
        {
            GD.PrintErr(e.Message);
            EmitSignal(SignalName.OnPromptReceived, false, e.Message);
            return;
        }

        EmitSignal(SignalName.OnPromptReceived, true, "");
    }

    public int GetDesire()
    {
        return (int)desire;
    }

    private Tower DictToTower(Dictionary dict)
    {
        var pos = (Vector2I)dict["position"];
        var towerTeam = (int)dict["owner_team"] == -1 ? !myTroop.Defenders : (int)dict["owner_team"] == 0;

        return new Tower(
            (pos.X, pos.Y),
            (string)dict["name"],
            towerTeam
        );
    }

    private static TerrainType GDTerrainToTerrainType(int terrain)
    {
        return terrain switch
        {
            0 => TerrainType.Plain,
            1 => TerrainType.Forest,
            2 => TerrainType.Mountain,
            3 => TerrainType.Water,
            _ => TerrainType.Tower
        };
    }

    private static Troop DictToTroop(Dictionary dict)
    {
        var pos = (Vector2I)dict["current_position"];

        var terrain = GDTerrainToTerrainType((int)dict["terrain"]);

        var desire_num = (int)dict["desire"];
        DesireState? desire;
        if (desire_num == -1)
            desire = null;
        else if (desire_num == 0)
            desire = DesireState.StayCalm;
        else
            desire = DesireState.GoAhead;

        return new Troop(
            (pos.X, pos.Y),
            (int)dict["count"],
            desire,
            terrain,
            (float)dict["height"],
            (string)dict["unit_name"],
            (int)dict["team"] == 0
        );
    }
}

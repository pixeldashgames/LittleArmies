using Agent;
using Agent.Enum;
using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Array = Godot.Collections.Array;

#nullable enable 

public partial class SmartAgentInterface : Node
{
    private Troop myTroop;
    [Export]
    public DesireState desire;

    [Signal]
    // [success, error_message]
    public delegate Array OnPromptReceivedEventHandler();

    private (IntentionAction, object?)? orderedAction;

    public Array GetMove(Dictionary thisUnit, Array<Dictionary> otherUnits, Array<Dictionary> castles, Vector2I mapMid, Callable getNeighbours, Callable getAdjacents, Callable getTerrainAt)
    {
        myTroop = DictToTroop(thisUnit);

        var troops = otherUnits.Select(DictToTroop).ToList();
        var towers = castles.Select(DictToTower).ToList();

        (IntentionAction, object?) action;

        if (orderedAction.HasValue){
            if (orderedAction.Value.Item2 is Troop troop)
            {
                var troopsWithName = troops.Select(t => t.Name == troop.Name).ToArray();
                if (troopsWithName.Length == 0)
                    orderedAction = null;
                else
                    orderedAction = (orderedAction.Value.Item1, troopsWithName[0]);
            }
            else if (orderedAction.Value.Item2 is Tower)
                orderedAction = (orderedAction.Value.Item1, towers.First(t => t.Name == ((Tower)orderedAction.Value.Item2!).Name));
        }

        if (orderedAction.HasValue && Agent.Agent.CheckOrder(orderedAction.Value.Item1, myTroop, troops, towers))
        {
            action = orderedAction.Value;
        }
        else
        {
            orderedAction = null;
            action = Agent.Agent.GetAction(myTroop, troops, towers, getNeighboursFunc);
        }

        var myPos = myTroop.Position;

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

        IEnumerable<Vector2I> getValidAdjacents(Vector2I pos)
        {
            var moveAdj = getAdjacentsFunc(pos)
                        .Where(p => neighbourPaths.Any(n => n.neigh == p) && !isTroopAt(p));

            return moveAdj;
        }

        bool isTroopAt(Vector2I pos)
        {
            return troops.Any(t => t.Position == pos);
        }

        T pickRandomElement<T>(IEnumerable<T> e)
        {
            var r = new Random();
            var arr = e.ToArray();
            return arr[r.Next() % arr.Length];
        }

        Array getAttackResult()
        {
            var enemy = ((Troop)action.Item2!).Position;
            var attackAStarResult = AStar.Find(myPos, enemy, p => p == enemy, getNeighboursFunc).ToArray();

            if (attackAStarResult.Length == 0)
                throw new ArgumentException($"Enemy {(Troop)action.Item2!} on agent {myTroop} spot?");

            var attackPos = attackAStarResult.Length == 1 ? attackAStarResult[0] : attackAStarResult[1];

            if (attackPos == enemy)
            {
                var attack_from = getAdjacentsFunc(enemy)
                    .Where(p => neighbourPaths.Any(n => n.neigh == p) && !isTroopAt(p))
                    .OrderByDescending(p => (int)getTerrainAtFunc(p)).First();

                var entry_path = neighbourPaths.First(n => n.neigh == attack_from).path;

                return [entry_path, attackPos, true];
            }
            else
            {
                if (isTroopAt(attackPos))
                    attackPos = pickRandomElement(getValidAdjacents(attackPos));

                var entry_path = neighbourPaths.First(n => n.neigh == attackPos).path;

                return [entry_path, attackPos, false];
            }
        }

        switch (action.Item1)
        {
            case IntentionAction.Wait:
                return [new Array<Vector2I> { myPos }, myPos, false];
            case IntentionAction.Move:
                var movePos = mapMid;
                var aStarResult = AStar.Find(myPos, movePos, p => (p - movePos).Length() <= 6, getNeighboursFunc).ToArray();

                var moveStep = aStarResult.Length == 1 ? aStarResult[0] : aStarResult[1];

                if (isTroopAt(moveStep))
                    moveStep = pickRandomElement(getValidAdjacents(moveStep));

                var movePath = neighbourPaths.First(n => n.neigh == moveStep).path;

                var retS = new Array { movePath, moveStep, false };

                return retS;
            case IntentionAction.ConquerTower:
                var towerTarget = ((Tower)action.Item2!).Position;
                var towerAStarResult = AStar.Find(myPos, towerTarget, p => p == towerTarget, getNeighboursFunc).ToArray();

                var stepPos = towerAStarResult.Length == 1 ? towerAStarResult[0] : towerAStarResult[1];

                if (isTroopAt(stepPos))
                    stepPos = pickRandomElement(getValidAdjacents(stepPos));

                var path = neighbourPaths.First(n => n.neigh == stepPos).path;                

                return [path, stepPos, false];
            case IntentionAction.GetSuplies:
                var suppliesTarget = ((Tower)action.Item2!).Position;
                var suppliesAStarResult = AStar.Find(myPos, suppliesTarget, p => p == suppliesTarget, getNeighboursFunc).ToArray();

                var suppliesStepPos = suppliesAStarResult.Length == 1 ? suppliesAStarResult[0] : suppliesAStarResult[1];

                if (isTroopAt(suppliesStepPos))
                    suppliesStepPos = pickRandomElement(getValidAdjacents(suppliesStepPos));

                var suppliesPath = neighbourPaths.First(n => n.neigh == suppliesStepPos).path;

                return [suppliesPath, suppliesStepPos, false];
            case IntentionAction.Attack:
                return getAttackResult();
            case IntentionAction.StayClose:
                var ally = ((Troop)action.Item2!).Position;
                var stayCloseAStarResult = AStar.Find(myPos, ally, p => (p - ally).Length() <= 4, getNeighboursFunc).ToArray();
                var stayClosePos = stayCloseAStarResult.Length == 1 ? stayCloseAStarResult[0] : stayCloseAStarResult[1];

                if (isTroopAt(stayClosePos))
                    stayClosePos = pickRandomElement(getValidAdjacents(stayClosePos));

                var stayClosePath = neighbourPaths.First(n => n.neigh == stayClosePos).path;

                return [stayClosePath, stayClosePos, false];
            case IntentionAction.Retreat:
                var closestAllies = troops
                    .Where(t => t.Defenders == myTroop.Defenders)
                    .Select(t => t.Position)
                    .OrderBy(t => (t - myPos).Length()).ToArray();

                if (closestAllies.Length == 0)
                    return getAttackResult();

                var closestAlly = closestAllies[0];

                var retreatAStarResult = AStar.Find(myPos, closestAlly, p => p == closestAlly, getNeighboursFunc).ToArray();
                var retreatPos = retreatAStarResult.Length == 1 ? retreatAStarResult[0] : retreatAStarResult[1];

                if (isTroopAt(retreatPos))
                    retreatPos = pickRandomElement(getValidAdjacents(retreatPos));

                var retreatPath = neighbourPaths.First(n => n.neigh == retreatPos).path;

                return [retreatPath, retreatPos, false];
            default:
                throw new IndexOutOfRangeException();
        }
    }

    public async void ReceiveOrder(string prompt, Dictionary thisUnit, Array<Dictionary> otherUnits, Array<Dictionary> castles)
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
            GD.PrintErr(e.Message + "\n" + e.StackTrace);
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

        var tower = new Tower(
            (pos.X, pos.Y),
            (string)dict["name"],
            towerTeam,
            (int)dict["supplies"]
        );

        return tower;
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

        var troop = new Troop( 
            (pos.X, pos.Y),
            (int)dict["count"],
            desire,
            terrain,
            (float)dict["height"],
            (string)dict["unit_name"],
            (int)dict["team"] == 0,
            (int)dict["supplies"]
        );

        return troop;
    }
}

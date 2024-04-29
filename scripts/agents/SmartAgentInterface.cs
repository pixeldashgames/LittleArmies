using Agent;
using Agent.Enum;
using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Linq;

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

    public Array GetMove(Dictionary thisUnit, Array<Dictionary> otherUnits, Array<Dictionary> castles)
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

        // translate action to move
    }

    public void ReceiveOrder(string prompt)
    {
        
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

    private static Troop DictToTroop(Dictionary dict)
    {
        var pos = (Vector2I)dict["current_position"];

        var terrain = (int)dict["terrain"] switch
        {
            0 => TerrainType.Plain,
            1 => TerrainType.Forest,
            2 => TerrainType.Mountain,
            3 => TerrainType.Water,
            _ => TerrainType.Tower
        };

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

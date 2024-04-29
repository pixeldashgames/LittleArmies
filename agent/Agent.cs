using Agent.Enum;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;

#nullable enable

namespace Agent;

[System.Serializable]
public class PromptException : System.Exception
{
    public PromptException() { }
    public PromptException(string message) : base(message) { }
    public PromptException(string message, System.Exception inner) : base(message, inner) { }
    protected PromptException(
        System.Runtime.Serialization.SerializationInfo info,
        System.Runtime.Serialization.StreamingContext context)
    { }
}

readonly struct Troop(
    (int, int) position,
    int troops,
    DesireState? desire,
    TerrainType terrain,
    float height,
    string name,
    bool defenders)
{
    public (int, int) Position => position;
    public int Troops => troops;
    public DesireState? Desire => desire;
    public TerrainType Terrain => terrain;
    public float Height => height;
    public string Name => name;
    public bool Defenders => defenders;

    public override bool Equals(object? obj)
    {
        if (obj is not Troop troop)
            return false;
        return troop.Position == Position;
    }

    public override int GetHashCode()
    {
        return HashCode.Combine(Position);
    }

    public override string ToString()
    {
        return $"Troop {name} with {troops} troops at position {position}";
    }

}

readonly struct Tower((int, int) position, string name, bool defenders)
{
    public string Name => name;
    public (int, int) Position => position;
    public bool OccupiedByDefenders => defenders;

    public override string ToString()
    {
        return $"Tower {name} at position {position}";
    }
}

static class Agent
{
    private const float Range = 2f;
    private const float AttackProbability = 0.8f;


    // A function to calculate the euclidean distance between two troops
    private static float Distance(Troop troop1, Troop? troop2)
    {
        if (troop2 == null)
            return 0;
        return MathF.Sqrt(MathF.Pow(troop1.Position.Item1 - troop2.Value.Position.Item1, 2) +
                          MathF.Pow(troop1.Position.Item2 - troop2.Value.Position.Item2, 2));
    }

    private static float Distance(Troop troop, Tower? tower)
    {
        if (tower == null)
            return 0;
        return MathF.Sqrt(MathF.Pow(troop.Position.Item1 - tower.Value.Position.Item1, 2) +
                          MathF.Pow(troop.Position.Item2 - tower.Value.Position.Item2, 2));
    }

    private static bool IsAlly(Troop troop1, Troop troop2)
    {
        return troop1.Defenders == troop2.Defenders;
    }

    private static bool IsAlly(Troop troop, Tower tower2)
    {
        return troop.Defenders == tower2.OccupiedByDefenders;
    }

    public static (IntentionAction, object?) GetAction(Troop actualTroop, IEnumerable<Troop> troops,
        IEnumerable<Tower> towers)
    {
        var beliefs = GetBeliefs(actualTroop, troops, towers).ToArray();
        var intention = GetIntention(actualTroop, beliefs);
        return intention;
    }

    // Generating believes given the current state of the world
    private static IEnumerable<(BeliefState, object?)> GetBeliefs(Troop actualTroop, IEnumerable<Troop> troops,
        IEnumerable<Tower> towers)
    {
        var beliefs = new List<(BeliefState, object?)>();

        // Identify allies and enemies
        foreach (var troop in troops)
        {
            if (IsAlly(actualTroop, troop))
            {
                beliefs.Add((BeliefState.AlliesOnSight, troop));
                if (Distance(actualTroop, troop) < Range)
                    beliefs.Add((BeliefState.AlliesInRange, troop));
            }
            else
            {
                beliefs.Add((BeliefState.EnemyOnSight, troop));
                if (Distance(actualTroop, troop) < Range)
                    beliefs.Add((BeliefState.EnemyInRange, troop));
            }
        }

        // Identify towers
        foreach (var tower in towers)
        {
            if (IsAlly(actualTroop, tower))
            {
                beliefs.Add((BeliefState.AllyTowerOnSight, tower));
                if (Distance(actualTroop, tower) < Range)
                    beliefs.Add((BeliefState.AllyTowerInRange, tower));
            }
            else
            {
                beliefs.Add((BeliefState.EnemyTowerOnSight, tower));
                if (Distance(actualTroop, tower) < Range)
                    beliefs.Add((BeliefState.EnemyTowerInRange, tower));
            }
        }


        return beliefs;
    }

    private static (IntentionAction, object?) GetIntention(Troop actualTroop,
        (BeliefState, object?)[] beliefs)
    {
        List<(IntentionAction, object?)> actions = [];

        // Select each enemy tower on sight
        var towers = beliefs.Where(b => b.Item1 is BeliefState.EnemyTowerOnSight)
            .Select(b => b.Item2 as Tower?).ToList();

        // Compare the towers position with the troops position and select the empty towers
        var troops = beliefs.Where(b => b.Item1 is BeliefState.EnemyOnSight or BeliefState.AlliesOnSight)
            .Select(b => b.Item2 as Troop?).ToList();

        // Select the closest one
        var towerCanGo = towers
            .Where(tower => troops.All(t => t?.Position != tower?.Position))
            .DefaultIfEmpty()
            .MinBy(t => Distance(actualTroop,
                t));

        // if a tower is available, Conquerer if the desire is to go ahead, otherwise stay close
        if (towerCanGo != null)
            return actualTroop.Desire == DesireState.GoAhead ? (IntentionAction.ConquerTower, towerCanGo) : (IntentionAction.StayClose, beliefs.Where(b => b.Item1 == BeliefState.AlliesOnSight).MinBy(b => Distance(actualTroop, b.Item2 as Troop?)).Item2);

        // Select the action to take for each enemy on sight
        foreach (var enemy in beliefs.Where(b => b.Item1 is BeliefState.EnemyOnSight)
                     .Select(b => b.Item2 as Troop?))
        {
            if (enemy == null) continue;

            var action = (actualTroop.Troops + (float)(actualTroop.Troops) * (int)actualTroop.Terrain / 100f) /
                         (enemy.Value.Troops + enemy.Value.Troops *
                             ((int)actualTroop.Terrain / 100f));
            if (action > AttackProbability)
                actions.Add((IntentionAction.Attack, enemy));
            else
            {
                if (beliefs.Contains((BeliefState.EnemyInRange, enemy)))
                    actions.Add((IntentionAction.Retreat, enemy));
            }
        }

        // if the troop desire is to go ahead, conquer the tower if there is no enemy on sight else attack the closest enemy
        if (actualTroop.Desire == DesireState.GoAhead)
            if (actions.Count == 0)
                if (beliefs.Any(b => b.Item1 == BeliefState.EnemyTowerOnSight))
                    return (IntentionAction.ConquerTower, beliefs.Where(b => b.Item1 == BeliefState.EnemyTowerOnSight).MinBy(b => Distance(actualTroop, b.Item2 as Tower?)).Item2);
                else
                    return (IntentionAction.Move, null);
            else
                return actions.MinBy(i => Distance(actualTroop, i.Item2 as Troop?));

        // When the desire is to stay close

        // if there is an enemy in range, attack the closest one
        if (beliefs.Any(b => b.Item1 == BeliefState.EnemyInRange))
            return actions.MinBy(i => Distance(actualTroop, i.Item2 as Troop?));

        // if there is an ally tower on sight, stay close to it
        if (beliefs.Any(b => b.Item1 == BeliefState.AllyTowerOnSight) && actualTroop.Defenders)
            return (IntentionAction.Wait, beliefs.First(b => b.Item1 == BeliefState.AllyTowerOnSight).Item2);

        // if there is an ally on sight, stay close to it
        if (beliefs.Any(b => b.Item1 == BeliefState.AlliesOnSight) && !actualTroop.Defenders)
            return (IntentionAction.StayClose,
                beliefs.Where(b => b.Item1 == BeliefState.AlliesOnSight)
                    .MinBy(b => Distance(actualTroop, b.Item2 as Troop?)).Item2);

        // if actual troop desire is to stay close
        if (actualTroop.Desire == DesireState.StayCalm)
        {
            // if there is an enemy on sight, attack the closest one
            if (beliefs.Any(b => b.Item1 == BeliefState.EnemyOnSight))
                return actions.MinBy(i => Distance(actualTroop, i.Item2 as Troop?));
        }

        return (IntentionAction.Wait, null);
    }

    public static async Task<(IntentionAction, object?)> Nlp(string message, Troop actualTroop, IEnumerable<Troop> troops,
        IEnumerable<Tower> towers)
    {
        var troopsName = troops.Select(t => t.Name).ToList();
        troopsName.Add(actualTroop.Name);

        var towersName = towers.Select(t => t.Name).ToList();

        var orderAndName = new List<string>();

        foreach (var name in troopsName)
        {
            orderAndName.Add("attack " + name);
            orderAndName.Add("retreat " + name);
            orderAndName.Add("stayclose " + name);
            orderAndName.Add("wait " + name);
            orderAndName.Add("move " + name);
        }
        foreach (var name in towersName)
        {
            orderAndName.Add("attack " + name);
        }

        var order = await HttpConnection.SelectOption(message, orderAndName.ToArray());

        var split = order!.Split();
        object? target = null;
        if (split.Length > 1)
        {
            var targetName = split[1..].Aggregate((a, b) => a + " " + b);
            target = troops.FirstOrDefault(t => t.Name == targetName);
            target ??= towers.FirstOrDefault(t => t.Name == targetName);
            if (target == null)
                throw new PromptException("Target not found");
        }

        switch (split[0].ToLower())
        {
            case "attack":
                if (target is Troop troop && troop.Defenders == actualTroop.Defenders)
                    throw new PromptException("Cannot attack an ally");
                if (target is Tower tower && tower.OccupiedByDefenders == actualTroop.Defenders)
                    throw new PromptException("Cannot attack an ally tower");
                return target is Troop ? (IntentionAction.Attack, target!) : (IntentionAction.ConquerTower, target!);
            case "retreat":
                return (IntentionAction.Retreat, target!);
            case "stayclose":
                return (IntentionAction.StayClose, target!);
            case "wait":
                return (IntentionAction.Wait, target);
            default:
                throw new PromptException("Command not found");
        }
    }


    /// <summary>
    /// Check if the order is possible given the current state of the world before calling Nlp
    /// </summary>
    /// <param name="intentionAction"></param>
    /// <param name="actualTroop"></param>
    /// <param name="troops"></param>
    /// <param name="towers"></param>
    /// <returns></returns>
    /// <exception cref="ArgumentOutOfRangeException"></exception>
    public static bool CheckOrder(IntentionAction intentionAction, Troop actualTroop, IEnumerable<Troop> troops,
        IEnumerable<Tower> towers)
    {
        var beliefs = GetBeliefs(actualTroop, troops, towers);
        return intentionAction switch
        {
            IntentionAction.Attack => beliefs.Any(b => b.Item1 == BeliefState.EnemyOnSight),
            IntentionAction.ConquerTower => beliefs.Any(b => b.Item1 == BeliefState.EnemyTowerOnSight),
            IntentionAction.Retreat => beliefs.Any(b => b.Item1 == BeliefState.EnemyOnSight),
            IntentionAction.StayClose => beliefs.Any(b => b.Item1 == BeliefState.AllyTowerOnSight),
            IntentionAction.Wait => true,
            IntentionAction.Move => true,
            _ => throw new ArgumentOutOfRangeException()
        };
    }
}
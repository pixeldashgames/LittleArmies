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
    bool defenders,
    int supplies,
    bool positionKnown)
{
    public Vector2I Position => new(position.Item1, position.Item2);
    public int Troops => troops;
    public DesireState? Desire => desire;
    public TerrainType Terrain => terrain;
    public float Height => height;
    public string Name => name;
    public bool Defenders => defenders;
    public bool PositionKnown => positionKnown;
    public int Supplies => supplies;

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
    public Vector2I GetVector2I()
    {
        return new Vector2I(position.Item1, position.Item2);
    }
}

readonly struct Tower((int, int) position, string name, bool defenders, int supplies)
{
    public string Name => name;
    public Vector2I Position => new(position.Item1, position.Item2);
    public bool OccupiedByDefenders => defenders;
    public int Supplies => supplies;

    public override string ToString()
    {
        return $"Tower {name} at position {position}";
    }
    public Vector2I GetVector2I()
    {
        return new Vector2I(position.Item1, position.Item2);
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
        return MathF.Sqrt(MathF.Pow(troop1.Position.X - troop2.Value.Position.X, 2) +
                          MathF.Pow(troop1.Position.Y - troop2.Value.Position.Y, 2));
    }

    private static float Distance(Troop troop, Tower? tower)
    {
        if (tower == null)
            return 0;
        return MathF.Sqrt(MathF.Pow(troop.Position.X - tower.Value.Position.X, 2) +
                          MathF.Pow(troop.Position.Y - tower.Value.Position.Y, 2));
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
        IEnumerable<Tower> towers, Func<Vector2I, IEnumerable<Vector2I>> getNeighbours)
    {
        var beliefs = GetBeliefs(actualTroop, troops, towers).ToArray();
        var intention = GetIntention(actualTroop, beliefs, getNeighbours);
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

    private static (IntentionAction, object?) GetIntentionDifuse(Troop actualTroop,
        (BeliefState, object?)[] beliefs, Func<Vector2I, IEnumerable<Vector2I>> getNeighbours)
    {
        List<(IntentionAction, object?, float)> actions = [];
        const float distanceFactor = 5f;

        const float proGoAhead = 1.05f;
        const float consGoAhead = .95f;
        const float proStayCalm = 1.05f;
        const float consStayCalm = .95f;

        actions.Add((IntentionAction.Move, null, 0.1f));

        const float enemyValue = 0.3f;
        const float conquerTowerValue = 0.3f;
        const float suppliesValue = 1f;
        const float stayClose = 0.3f;



        // Select the action to take for each enemy on sight
        foreach (var enemy in beliefs.Where(b => b.Item1 is BeliefState.EnemyOnSight)
                     .Select(b => b.Item2 as Troop?))
        {
            if (enemy == null) continue;
            var probability = (enemyValue + ((actualTroop.Troops * (100 + (int)actualTroop.Terrain) / 100f) /
                         (enemy.Value.Troops * (100 + (int)actualTroop.Terrain) / 100f)) + distanceFactor / Distance(actualTroop, enemy))
                         * ((actualTroop.Desire == DesireState.GoAhead) ? proGoAhead : consGoAhead);
            if (probability > AttackProbability)
                actions.Add((IntentionAction.Attack, enemy, probability));
            else
            {
                if (beliefs.Contains((BeliefState.EnemyInRange, enemy)) && beliefs.Where(b => b.Item1 is BeliefState.EnemyTowerOnSight)
                    .Select(b => b.Item2 as Tower?)
                    .Where(tower => beliefs.Where(b => b.Item1 is BeliefState.EnemyOnSight or BeliefState.AlliesOnSight)
                    .Select(b => b.Item2 as Troop?).All(t => t?.Position != tower?.Position))
                    .Any())
                    actions.Add((IntentionAction.Move, beliefs.Where(b => b.Item1 == BeliefState.AllyTowerInRange).MinBy(t => Distance(actualTroop, t.Item2 as Tower?)), 2 * probability));
                else
                    actions.Add((IntentionAction.Retreat, enemy, probability));
            }
        }

        // Select the action to take foreach Enemy Tower
        foreach (var tower in beliefs.Where(b => b.Item1 is BeliefState.EnemyTowerOnSight)
            .Select(b => b.Item2 as Tower?)
            .Where(tower => beliefs.Where(b => b.Item1 is BeliefState.EnemyOnSight or BeliefState.AlliesOnSight)
            .Select(b => b.Item2 as Troop?).All(t => t?.Position != tower?.Position))
            .DefaultIfEmpty())
        {
            actions.Add((IntentionAction.ConquerTower, tower, conquerTowerValue * ((actualTroop.Desire == DesireState.GoAhead) ? proGoAhead : consGoAhead)
            + distanceFactor / Distance(actualTroop, tower)));
        }

        // Go to get suppplies to the closest tower whitch havent troops inside
        var selectedTower = beliefs.Where(b => b.Item1 is BeliefState.AllyTowerOnSight or BeliefState.EnemyTowerOnSight).Select(b => b.Item2 as Tower?)
            .Where(tower => beliefs.Where(b => b.Item1 is BeliefState.EnemyOnSight or BeliefState.AlliesOnSight)
            .Select(b => b.Item2 as Troop?).All(t => t?.Position != tower?.Position))
            .DefaultIfEmpty()
            .MinBy(t => Distance(actualTroop,
                t));
        if (selectedTower != null)
        {
            // Check if the amount of turns to get the supplies equal to the amount of supplies that can be spent on the way
            var wayToTower = AStar.Find(actualTroop.Position, selectedTower.Value.GetVector2I(), n => n == selectedTower.Value.GetVector2I(), getNeighbours);
            if (wayToTower.Count() == actualTroop.Supplies / actualTroop.Troops)
                actions.Add((IntentionAction.GetSuplies, selectedTower, suppliesValue + distanceFactor / Distance(actualTroop, selectedTower)));
        }

        // if there is an ally tower on sight, stay close to it
        if (beliefs.Any(b => b.Item1 == BeliefState.AllyTowerOnSight) && actualTroop.Defenders)
            actions.Add((IntentionAction.StayClose,
                beliefs.Where(b => b.Item1 == BeliefState.AllyTowerOnSight)
                    .MinBy(b => Distance(actualTroop, b.Item2 as Troop?)).Item2, stayClose * ((actualTroop.Desire == DesireState.StayCalm) ? proStayCalm : consStayCalm)));

        // if there is an ally on sight, stay close to it
        if (beliefs.Any(b => b.Item1 == BeliefState.AlliesOnSight) && !actualTroop.Defenders)
            return (IntentionAction.StayClose,
                beliefs.Where(b => b.Item1 == BeliefState.AlliesOnSight)
                    .MinBy(b => Distance(actualTroop, b.Item2 as Troop?)).Item2);

        var result = actions.MinBy(a => a.Item3);
        return (result.Item1, result.Item2);
    }
    private static (IntentionAction, object?) GetIntention(Troop actualTroop,
        (BeliefState, object?)[] beliefs, Func<Vector2I, IEnumerable<Vector2I>> getNeighbours)
    {
        List<(IntentionAction, object?)> actions = [];

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
                if (beliefs.Contains((BeliefState.EnemyInRange, enemy)) && beliefs.Any(b => b.Item1 == BeliefState.AllyTowerInRange))
                    actions.Add((IntentionAction.Move, beliefs.Where(b => b.Item1 == BeliefState.AllyTowerInRange).MinBy(t => Distance(actualTroop, t.Item2 as Tower?))));
                else
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


        // if there is an enemy in range, attack the closest one
        if (actualTroop.Desire == DesireState.StayCalm && beliefs.Any(b => b.Item1 == BeliefState.EnemyInRange) && actions.Count > 0)
            return actions.MinBy(i => Distance(actualTroop, i.Item2 as Troop?));



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

        // if a tower is available, Conquerer it
        if (towerCanGo != null)
            return (IntentionAction.ConquerTower, towerCanGo);



        if (beliefs.Any(b => b.Item1 == BeliefState.EnemyInRange))
        { }
        else
        {
            // Go to get suppplies to the closest tower that is ally or havent enemies inside
            var tower = beliefs.Where(b => b.Item1 is BeliefState.AllyTowerOnSight or BeliefState.EnemyTowerOnSight).Select(b => b.Item2 as Tower?)
                .Where(tower => troops.All(t => t?.Position != tower?.Position))
                .DefaultIfEmpty()
                .MinBy(t => Distance(actualTroop,
                    t));
            if (tower != null)
            {
                // Check if the amount of turns to get the supplies equal to the amount of supplies that can be spent on the way
                var wayToTower = AStar.Find(actualTroop.Position, tower.Value.GetVector2I(), n => n == tower.Value.GetVector2I(), getNeighbours);
                if (wayToTower.Count() == actualTroop.Supplies / actualTroop.Troops)
                    return (IntentionAction.GetSuplies, tower);
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
        if (actualTroop.Desire == DesireState.GoAhead)
            return (IntentionAction.Move, null);
        // if there is an ally tower on sight, stay close to it
        if (beliefs.Any(b => b.Item1 == BeliefState.AllyTowerOnSight) && actualTroop.Defenders)
            return (IntentionAction.StayClose,
                beliefs.Where(b => b.Item1 == BeliefState.AllyTowerOnSight)
                    .MinBy(b => Distance(actualTroop, b.Item2 as Troop?)).Item2);

        // if there is an ally on sight, stay close to it
        if (beliefs.Any(b => b.Item1 == BeliefState.AlliesOnSight) && !actualTroop.Defenders)
            return (IntentionAction.StayClose,
                beliefs.Where(b => b.Item1 == BeliefState.AlliesOnSight)
                    .MinBy(b => Distance(actualTroop, b.Item2 as Troop?)).Item2);

        // if there is an enemy on sight, attack the closest one
        if (beliefs.Any(b => b.Item1 == BeliefState.EnemyOnSight) && actions.Count > 0)
            return actions.MinBy(i => Distance(actualTroop, i.Item2 as Troop?));

        return (IntentionAction.Wait, null);
    }

    public static async Task<(IntentionAction, object?)> Nlp(string message, Troop actualTroop, IEnumerable<Troop> troops,
        IEnumerable<Tower> towers)
    {
        var troopsName = troops.Select(t => t.Name).ToList();

        var towersName = towers.Select(t => t.Name).ToList();

        var orderAndName = new List<string>();

        foreach (var name in troopsName)
        {
            orderAndName.Add("attack " + name);
            orderAndName.Add("retreat " + name);
            orderAndName.Add("stayclose " + name);
        }

        orderAndName.Add("wait");

        foreach (var name in towersName)
        {
            orderAndName.Add("attack " + name);
            orderAndName.Add("getSupplies " + name);
        }

        var order = await HttpConnection.SelectOption(message, orderAndName.ToArray());

        var split = order!.Split();
        object? target = null;
        if (split.Length > 1)
        {
            var targetName = split[1..].Aggregate((a, b) => a + " " + b);
            var filteredTroops = troops.Where(t => t.Name == targetName).ToArray();
            if (filteredTroops.Length != 0)
                target = filteredTroops[0];
            else
            {
                var filteredTowers = towers.Where(t => t.Name == targetName).ToArray();
                if (filteredTowers.Length != 0)
                    target = filteredTowers[0];
                else
                    throw new PromptException("Target not found");
            }
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
            case "getSupplies":
                if (target is not Tower tower1)
                    throw new PromptException("Target has to be a tower");
                if (troops.Any(t => t.Position == tower1.GetVector2I()))
                    throw new PromptException("Cannot get supplies from a tower with troops inside");
                return (IntentionAction.GetSuplies, target!);
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
    public static bool CheckOrder(IntentionAction intentionAction, object? target, Troop actualTroop, IEnumerable<Troop> troops,
        IEnumerable<Tower> towers)
    {
        var beliefs = GetBeliefs(actualTroop, troops, towers);
        var availableTowers = towers.Where(tower => troops.All(t => t.GetVector2I() != tower.GetVector2I()));
        return intentionAction switch
        {
            IntentionAction.Attack or IntentionAction.Retreat => (target is Troop troop) && actualTroop.Defenders != troop.Defenders,
            IntentionAction.ConquerTower => (target is Tower tower2) && actualTroop.Defenders != tower2.OccupiedByDefenders && availableTowers.Any(t => t.Name == tower2.Name),
            IntentionAction.StayClose => (target is Troop troop1)
                ? actualTroop.Defenders != troop1.Defenders
                : (target is Tower tower1) && actualTroop.Defenders == tower1.OccupiedByDefenders,
            IntentionAction.Wait => true,
            IntentionAction.Move => true,
            IntentionAction.GetSuplies => target is Tower tower && availableTowers.Any(t => t.Name == tower.Name),
            _ => throw new ArgumentOutOfRangeException()
        };
    }
}
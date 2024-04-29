using System.Security.Cryptography;
using Agent.Enum;

namespace Agent;

readonly struct Troop(
    (int, int) position,
    int troops,
    DesireState desire,
    TerrainType terrain,
    float height,
    string name,
    bool defenders)
{
    public (int, int) Position => position;
    public int Troops => troops;
    public DesireState Desire => desire;
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
}

readonly struct Tower((int, int) position, string name, bool defenders)
{
    public string Name => name;
    public (int, int) Position => position;
    public bool OccupiedByDefenders => defenders;
}

static class Agent
{
    private const int Range = 5;
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
        return troop1.Defenders && troop2.Defenders;
    }

    private static bool IsAlly(Troop troop, Tower tower2)
    {
        return troop.Defenders == tower2.OccupiedByDefenders;
    }

    public static (IntentionAction, object?) GetAction(Troop actualTroop, IEnumerable<Troop> troops,
        IEnumerable<Tower> towers)
    {
        var beliefs = GetBeliefs(actualTroop, troops, towers).ToArray();
        var intentions = GetIntention(actualTroop, beliefs);
        throw new NotImplementedException();
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
        List<(IntentionAction, object?, float)> actions = [];

        // Select each enemy tower on sight
        var towers = beliefs.Where(b => b.Item1 is BeliefState.EnemyTowerOnSight)
            .Select(b => b.Item2 as Tower?);

        // Compare the towers position with the troops position and select the empty towers
        var troops = beliefs.Where(b => b.Item1 is BeliefState.EnemyOnSight or BeliefState.AlliesOnSight)
            .Select(b => b.Item2 as Troop?).ToList();

        var towerCanGo = towers
            .Where(tower => troops.All(t => t?.Position != tower?.Position))
            .DefaultIfEmpty(null)
            .MinBy(t => Distance(actualTroop,
                t));

        if (towerCanGo != null)
            return (IntentionAction.ConquerTower, towerCanGo);

        // Select the action to take for each enemy on sight
        foreach (var enemy in beliefs.Where(b => b.Item1 is BeliefState.EnemyOnSight)
                     .Select(b => b.Item2 as Troop?))
        {
            if (enemy == null) continue;

            var action = ((actualTroop.Troops + (float)(actualTroop.Troops) * (int)actualTroop.Terrain / 100f) /
                          (enemy.Value.Troops + enemy.Value.Troops *
                              ((int)actualTroop.Terrain / 100f))) * (1 / Distance(actualTroop, enemy));

            if (action > AttackProbability)
                actions.Add((IntentionAction.Attack, enemy, action));
            else
            {
                if (beliefs.Contains((BeliefState.EnemyInRange, enemy)))
                    actions.Add((IntentionAction.Retreat, enemy, action));
            }
        }

        if (actualTroop.Desire == DesireState.GoAhead)
            return (actions.Count == 0)
                ? (IntentionAction.Move, null)
                : actions.OrderByDescending(a => a.Item3).Select(a => (a.Item1, a.Item2)).First();


        if (beliefs.Any(b => b.Item1 == BeliefState.EnemyOnSight))
            return actions.OrderByDescending(a => a.Item3).Select(a => (a.Item1, a.Item2)).First();
        if (beliefs.Any(b => b.Item1 == BeliefState.AllyTowerOnSight))
            return (IntentionAction.Wait, beliefs.First(b => b.Item1 == BeliefState.AllyTowerOnSight).Item2);
        return (IntentionAction.StayClose,
            beliefs.Where(b => b.Item1 == BeliefState.AllyTowerOnSight)
                .MinBy(b => Distance(actualTroop, b.Item2 as Tower?)).Item2);
    }

    public static (IntentionAction, object?) Nlp(string message, Troop actualTroop, IEnumerable<Troop> troops,
        IEnumerable<Tower> towers)
    {
        var split = message.Split();
        object? target = null;
        if (split.Length > 1)
        {
            var targetName = split[1..].Aggregate((a, b) => a + " " + b);
            target = troops.FirstOrDefault(t => t.Name == targetName);
            if (target == null)
                target = towers.FirstOrDefault(t => t.Name == targetName);
            if (target == null)
                throw new ArgumentException("Target not found");
        }

        switch (split[0].ToLower())
        {
            case "attack":
                if(target is Troop troop && troop.Defenders == actualTroop.Defenders)
                    throw new ArgumentException("Cannot attack an ally");
                if (target is Tower tower && tower.OccupiedByDefenders == actualTroop.Defenders)
                    throw new ArgumentException("Cannot attack an ally tower");
                return target is Troop ? (IntentionAction.Attack, target!) : (IntentionAction.ConquerTower, target!);
            case "retreat":
                return (IntentionAction.Retreat, target!);
            case "stayclose":
                return (IntentionAction.StayClose, target!);
            case "wait":
                return (IntentionAction.Wait, target);
            case "move":
                return (IntentionAction.Move, target);
            default:
                throw new ArgumentException("Command not found");
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
            IntentionAction.Move => true,
            _ => throw new ArgumentOutOfRangeException()
        };
    }
}
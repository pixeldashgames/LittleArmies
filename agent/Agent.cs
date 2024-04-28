using Agent.Enum;

namespace Agent;

class Tower((int, int) position, string name)
{
    public string Name => name;
    public (int, int) Position = position;
    public bool OccupiedByDefender = true;
}

abstract class Agent((int, int) position, int troops, DesireState desire, string name)
{
    public string Name => name;
    public int Troops => troops;
    protected (int, int) Position = position;

    private bool _followOrder = false;

    private List<(BeliefState, object?)> _beliefs = [];
    private IntentionAvailable _available = IntentionAvailable.Available;
    private IntentionHelp _needHelp = IntentionHelp.NoHelpNeeded;
    private DesireState _desire = desire;
    private (IntentionAction, object?) _intention = (IntentionAction.Move, null);


    // Generating believes given the current state of the world
    private void Brf(List<Agent> localAgents, List<Agent> globalAgents, List<Tower> localTowers,
        List<Tower> globalTowers)
    {
        // Search for enemies
        foreach (var agent in globalAgents.Where(agent => !IsAlly(agent)))
        {
            _beliefs.Add((BeliefState.EnemyOnSight, agent));
        }

        // Select the enemies that are in range
        foreach (var agent in localAgents.Where(agent => !IsAlly(agent)))
        {
            _beliefs.Add((BeliefState.EnemyInRange, agent));
        }

        // Search for allies
        foreach (var agent in globalAgents.Where(IsAlly))
        {
            _beliefs.Add((BeliefState.AlliesOnSight, agent));
        }

        // Select the allies that are in range
        foreach (var agent in localAgents.Where(IsAlly))
        {
            _beliefs.Add((BeliefState.AlliesInRange, agent));
        }

        // Select the action to take for each enemy in range
        foreach (var enemy in _beliefs.Where(b => b.Item1 == BeliefState.EnemyInRange).Select(b => b.Item2))
        {
            if (enemy is Agent enemyAgent)
                _beliefs.Add(enemyAgent.Troops > Troops
                    ? (BeliefState.PonderRetreat, enemyAgent)
                    : (BeliefState.Attack, enemyAgent));
        }

        // Check for reinforcements
        foreach (var enemy in _beliefs.Where(b => b.Item1 == BeliefState.PonderRetreat))
        {
            if (enemy.Item2 is not Agent enemyAgent) continue;
            if (_beliefs.Any(b =>
                    b.Item1 == BeliefState.AlliesInRange && (enemyAgent.Troops + Troops > enemyAgent.Troops) &&
                    enemyAgent.IsAvailable()))
                _beliefs.Add((BeliefState.AskForHelp, enemy.Item2));
            else
                _beliefs.Add((BeliefState.Retreat, enemy.Item2));
        }

        // Search for allies asking for help
        foreach (var ally in localAgents.Where(IsAlly))
        {
            if (ally.NeedsHelp())
                _beliefs.Add((BeliefState.ReinforcementOnWay, ally));
        }

        // Check for global enemy towers
        foreach (var tower in globalTowers.Where(t => !IsAlly(t)))
        {
            _beliefs.Add((BeliefState.TowerOnSight, tower));
        }

        // Check for nerby enemy towers
        foreach (var tower in localTowers.Where(t => !IsAlly(t)))
        {
            _beliefs.Add((BeliefState.TowerInRange, tower));
        }

        foreach (var tower in _beliefs.Where(b => b.Item1 == BeliefState.TowerInRange))
        {
            if (tower.Item2 is not Tower towerObj) continue;
            if (_beliefs.All(b => b.Item1 != BeliefState.EnemyInRange))
                _beliefs.Add((BeliefState.AttackTower, towerObj));
        }

        _beliefs.Add((BeliefState.Stay, null));
        _beliefs.Add((BeliefState.Move, null));
    }

    private bool SearchAndSet(BeliefState belief, IntentionAction action)
    {
        var tempBeliefs = _beliefs.Where(b => belief == b.Item1);
        var valueTuples = tempBeliefs.ToList();
        if (valueTuples.Count == 0) return false;
        {
            _intention = (action, valueTuples.Select(b => b.Item2 as Agent).MinBy(a => Distance(this, a)));
            return true;
        }
    }

    // Filter the believes given the disires of the agent
    private void Filter()
    {
        if (SearchAndSet(BeliefState.ReinforcementOnWay, IntentionAction.Help))
            return;
        if (SearchAndSet(BeliefState.Retreat, IntentionAction.Retreat))
            return;
        if (SearchAndSet(BeliefState.Attack, IntentionAction.Attack))
            return;
        if (SearchAndSet(BeliefState.AttackTower, IntentionAction.AttackTower))
            return;
        if (_desire == DesireState.GoAhead)
        {
            if (SearchAndSet(BeliefState.Move, IntentionAction.Move))
                return;
        }
        else
        {
            if (SearchAndSet(BeliefState.Move, IntentionAction.StayClose))
            {
                return;
            }
        }

        if (SearchAndSet(BeliefState.Stay, IntentionAction.StayClose))
            return;
        throw new Exception("No intention found");
    }

    // A function to calculate the euclidean distance between two agents
    private static double Distance(Agent agent1, Agent? agent2)
    {
        if (agent2 == null)
            return 0;
        return Math.Sqrt(Math.Pow(agent1.Position.Item1 - agent2.Position.Item1, 2) +
                         Math.Pow(agent1.Position.Item2 - agent2.Position.Item2, 2));
    }

    // Execute the action given the filtered believes given the intentions of the agent
    private void Execute()
    {
        _needHelp = _intention.Item1 switch
        {
            IntentionAction.Attack => IntentionHelp.NoHelpNeeded,
            IntentionAction.AttackTower => IntentionHelp.NoHelpNeeded,
            IntentionAction.Retreat => IntentionHelp.NoHelpNeeded,
            IntentionAction.Help => IntentionHelp.NeedHelp,
            IntentionAction.StayClose => IntentionHelp.NoHelpNeeded,
            IntentionAction.Move => IntentionHelp.NoHelpNeeded,
            IntentionAction.Stay => IntentionHelp.NoHelpNeeded,
            _ => throw new ArgumentOutOfRangeException()
        };
        _available = IntentionAvailable.NotAvailable;
    }

    public void SetAvailable() => _available = IntentionAvailable.Available;

    public bool IsAvailable() => _available == IntentionAvailable.Available;

    public bool NeedsHelp() => _needHelp == IntentionHelp.NeedHelp;

    public string Nlp(string message, List<Agent> localAgents, List<Agent> globalAgents,
        List<Tower> localTowers, List<Tower> globalTowers)
    {
        _followOrder = true;
        var split = message.Split();
        object? target = null;
        if (split.Length > 1)
        {
            if (globalAgents.Any(a => a.Name == split[1]))
                target = globalAgents.First(a => a.Name == split[1]);
            else
            {
                if (globalTowers.Any(t => t.Name == split[1]))
                    target = globalTowers.First(t => t.Name == split[1]);
                else
                    throw new ArgumentException("Name not found");
            }
        }

        _intention = split[0].ToLower() switch
        {
            "attack" => (target is Agent) ? (IntentionAction.Attack, target!) : (IntentionAction.AttackTower, target!),
            "retreat" => (IntentionAction.Retreat, target!),
            "help" => (IntentionAction.Help, target!),
            "stayclose" => (IntentionAction.StayClose, target),
            "move" => (IntentionAction.Move, target),
            _ => throw new ArgumentException("Command not found")
        };

        return message;
    }

    public (IntentionAction, object?) Pipeline(List<Agent> localAgents, List<Agent> globalAgents,
        List<Tower> localTowers, List<Tower> globalTowers)
    {
        Brf(localAgents, globalAgents, localTowers, globalTowers);
        _followOrder = CheckOrder();
        if (_followOrder)
        {
            _beliefs.Clear();
            return _intention;
        }

        Filter();
        Execute();
        _beliefs.Clear();
        return _intention;
    }

    private bool CheckOrder()
    {
        return _intention.Item1 switch
        {
            IntentionAction.Attack => _beliefs.Any(b => b.Item1 == BeliefState.EnemyOnSight),
            IntentionAction.AttackTower => _beliefs.Any(b => b.Item1 == BeliefState.TowerOnSight),
            IntentionAction.Retreat => _beliefs.Any(b => b.Item1 == BeliefState.EnemyOnSight),
            IntentionAction.Help => _beliefs.Any(b => b.Item1 == BeliefState.AlliesOnSight),
            IntentionAction.StayClose => _beliefs.Any(b => b.Item1 == BeliefState.Stay),
            IntentionAction.Move => _beliefs.Any(b => b.Item1 == BeliefState.Move),
            _ => throw new ArgumentOutOfRangeException()
        };
    }

    public abstract bool IsAlly(Agent agent);
    public abstract bool IsAlly(Tower tower);
}

class Attacker : Agent
{
    public Attacker((int, int) position, int troops, DesireState desire, string name) : base(position, troops, desire,
        name) => Console.WriteLine("Attacker created");

    public override bool IsAlly(Agent agent) => agent is Attacker;

    public override bool IsAlly(Tower tower) => !tower.OccupiedByDefender;
}

class Defender : Agent
{
    public Defender((int, int) position, int troops, DesireState desire, string name) : base(position, troops, desire,
        name) => Console.WriteLine("Defender created");

    public override bool IsAlly(Agent agent) => agent is Defender;

    public override bool IsAlly(Tower tower) => tower.OccupiedByDefender;
}
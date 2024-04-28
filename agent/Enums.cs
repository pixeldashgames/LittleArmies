namespace Agent.Enum;

internal enum BeliefState
{
    Attack,
    Retreat,
    Stay,
    Move,
    EnemyOnSight,
    EnemyInRange,
    AlliesOnSight,
    AlliesInRange,
    PonderRetreat,
    AskForHelp,
    ReinforcementOnWay,
    TowerOnSight,
    TowerInRange,
    AttackTower,
}
internal enum DesireState
{
    GoAhead,
    StayCalm,
}

internal enum IntentionAvailable
{
    Available,
    NotAvailable,
}

internal enum IntentionAction
{
    Attack,
    AttackTower,
    Retreat,
    Help,
    Move,
    StayClose,
    Stay
}

internal enum IntentionHelp
{
    NeedHelp,
    NoHelpNeeded,
}
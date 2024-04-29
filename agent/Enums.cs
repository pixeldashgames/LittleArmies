namespace Agent.Enum;

internal enum BeliefState
{
    EnemyOnSight,
    EnemyInRange,
    AlliesOnSight,
    AlliesInRange,
    AllyTowerOnSight,
    AllyTowerInRange,
    EnemyTowerOnSight,
    EnemyTowerInRange,

}
internal enum DesireState
{
    GoAhead,
    StayCalm,
}

internal enum IntentionAction
{
    Attack,
    Retreat,
    StayClose,
    Wait,
    ConquerTower,
    Move
}

internal enum TerrainType
{
    Plain = 10,
    Water = 15,
    Mountain = 30,
    Tower = 50,
    Forest = 20,
}
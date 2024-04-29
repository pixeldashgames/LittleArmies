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
public enum DesireState
{
    GoAhead = 0,
    StayCalm = 1,
}

internal enum IntentionAction
{
    Attack,
    Retreat,
    StayClose,
    Wait,
    ConquerTower,
    Move,
    GetSuplies
}

internal enum TerrainType
{
    Plain = 10,
    Water = 5,
    Mountain = 30,
    Tower = 50,
    Forest = 20,
}
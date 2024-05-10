using Godot;
using Godot.Collections;
using System;
using System.Linq;
using System.Threading.Tasks;
using Array = Godot.Collections.Array;

public partial class VisibilityMap : Node
{
    private const float PlainsInitialVisibilityMultiplier = 1;
    private const float WaterInitialVisibilityMultiplier = 1.1f;
    private const float MountainInitialVisibilityMultiplier = 2;
    private const float ForestInitialVisibilityMultiplier = 0.75f;

    private const float PlainsVisibilityPenalty = 0.15f;
    private const float WaterVisibilityPenalty = 0.1f;
    private const float ForestVisibilityPenalty = 0.3f;
    private const float MountainVisibilityPenalty = 0.6f;
    private const float MaxAltitudeDifferenceForVisibility = 2;
    private const float AltitudeDecreaseVisibilityMultiplierCurve = 0.4f;
    private const float AltitudeIncreaseVisibilityMultiplierCurve = 0.2f;
    private readonly Vector2 AltitudeDifferenceMultiplierRange = new Vector2(0, 1.2f);

    private float[][][][] map;

    public Array<Array<float>> GetVisibilityMap(Array<Vector2I> sourcePositions, Array<float> sourceVisibilityMultipliers) {
        var allCells = new Array<Vector2I>();
        var result = new float[map.Length][];
        for (var i = 0; i < map.Length; i++)
        {
            result[i] = new float[map[i].Length];
            for (var j = 0; j < map[i].Length; j++)
                allCells.Add(new Vector2I(j, i));
        }

        Parallel.For(0, allCells.Count, i =>
        {
            var cell = allCells[i];
            result[cell.Y][cell.X] = GetVisibilityAt(cell, sourcePositions, sourceVisibilityMultipliers);
        });

        return new Array<Array<float>>(result.Select(a => new Array<float>(a)));
    }

    public float GetVisibilityAt(Vector2I pos, Array<Vector2I> sourcePositions, Array<float> sourceVisibilityMultipliers)
    {
        return Mathf.Clamp(sourcePositions
            .Zip(sourceVisibilityMultipliers)
            .Select(a => a.Second * map[a.First.Y][a.First.X][pos.Y][pos.X])
            .Max(), 0, 1);
    }

    public void GenerateVisibilityMap(int width, int height, Node hexCellsBetween, Callable getHeightFunc, Callable hasWaterInFunc, Callable hasForestInFunc, Callable hasMountainInFunc, Callable isValidGamePosFunc)
    {
        var allCells = new Array<Vector2I>();
        map = new float[height][][][];
        for (var i = 0; i < height; i++)
        {
            map[i] = new float[width][][];
            for (var j = 0; j < width; j++)
                allCells.Add(new Vector2I(j, i));
        }

        Parallel.For(0, allCells.Count, i =>
        {
            var cell = allCells[i];
            map[cell.Y][cell.X] = GenerateCellVisibilityMap(cell, allCells, width, height, (HexCellsBetween)hexCellsBetween, getHeightFunc, hasWaterInFunc, hasForestInFunc, hasMountainInFunc, isValidGamePosFunc);
        });
    }

    private float[][] GenerateCellVisibilityMap(Vector2I cell, Array<Vector2I> allCells, int width, int height, HexCellsBetween hexCellsBetween, Callable getHeightFunc, Callable hasWaterInFunc, Callable hasForestInFunc, Callable hasMountainInFunc, Callable isValidGamePosFunc)
    {
        var inBetweenCells = hexCellsBetween.GetAllCellsBetween(cell, allCells);

        var visibilityMap = new float[height][];
        for (var i = 0; i < height; i++)
            visibilityMap[i] = new float[width];

        Parallel.For(0, allCells.Count, i =>
        {
            var target = allCells[i];
            visibilityMap[target.Y][target.X] = CalculateVisibilityForCell(cell, target, inBetweenCells[i], getHeightFunc, hasWaterInFunc, hasForestInFunc, hasMountainInFunc, isValidGamePosFunc);
        });

        return visibilityMap;
    }

    private float CalculateVisibilityForCell(Vector2I from, Vector2I to, Array<Vector2I> inBetweenCells, Callable getHeightFunc, Callable hasWaterInFunc, Callable hasForestInFunc, Callable hasMountainInFunc, Callable isValidGamePosFunc)
    {
        if (from == to)
            return 1;


        float visibility;

        if (hasWaterInFunc.Call(from).As<bool>())
            visibility = WaterInitialVisibilityMultiplier;
        else if (hasForestInFunc.Call(from).As<bool>())
            visibility = ForestInitialVisibilityMultiplier;
        else if (hasMountainInFunc.Call(from).As<bool>())
            visibility = MountainInitialVisibilityMultiplier;
        else
            visibility = PlainsInitialVisibilityMultiplier;

        var thisHeight = getHeightFunc.Call(from).As<float>();

        var heightChangePoint = thisHeight;
        var increasedHeight = false;
        var lastHeight = heightChangePoint;

        for (var i = 1; i < inBetweenCells.Count; i++)
        {
            var c = inBetweenCells[i];
            if (!isValidGamePosFunc.Call(c).As<bool>())
                continue;

            if (hasWaterInFunc.Call(c).As<bool>())
                visibility -= WaterVisibilityPenalty;
            else if (hasForestInFunc.Call(c).As<bool>())
                visibility -= ForestVisibilityPenalty;
            else if (hasMountainInFunc.Call(c).As<bool>())
                visibility -= MountainVisibilityPenalty;
            else
                visibility -= PlainsVisibilityPenalty;

            if (visibility < 0)
                return 0;

            var height = getHeightFunc.Call(c).As<float>();
            if (height > lastHeight)
            {
                increasedHeight = true;
                if (height > heightChangePoint)
                    heightChangePoint = height;
                lastHeight = height;
            }
            else if (!increasedHeight)
            {
                heightChangePoint = height;
                lastHeight = height;
            }

            if (heightChangePoint - thisHeight > MaxAltitudeDifferenceForVisibility)
                return 0;
        }

        var curve = thisHeight > heightChangePoint ? AltitudeDecreaseVisibilityMultiplierCurve : AltitudeIncreaseVisibilityMultiplierCurve;

        var value = Mathf.Clamp(Mathf.Abs(thisHeight - heightChangePoint) / MaxAltitudeDifferenceForVisibility, 0, 1);

        var unsignedValue = thisHeight > heightChangePoint ? value : 1 - value;

        var altitudeVisMultiplier = Mathf.Ease(unsignedValue, curve);

        var rangeMin = thisHeight > heightChangePoint ? 1.0f : AltitudeDifferenceMultiplierRange.X;

        var rangeMax = thisHeight > heightChangePoint ? AltitudeDifferenceMultiplierRange.Y : 1.0f;

        visibility *= Mathf.Lerp(rangeMin, rangeMax, altitudeVisMultiplier);

        return Mathf.Clamp(visibility, 0, 1);
    }
}

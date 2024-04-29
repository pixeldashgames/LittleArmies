using Godot;
using System;
using System.Linq;
using System.Collections.Generic;
using System.Collections;
using System.Runtime.ExceptionServices;
using System.Net.WebSockets;
using Godot.Collections;

namespace PixelDashCore;

public partial class PerlinMapGenerator : Node
{
    private Random _randomInstance;

    private Random RandomInstance
    {
        get
        {
            _randomInstance ??= new Random();

            return _randomInstance;
        }
    }

    [Export]
    public int width;
    [Export]
    public int height;
    [Export]
    public int resolution;


    private int GradientsMatrixWidth
    {
        get
        {
            return (int)Math.Ceiling((float)width / resolution) + 1;
        }
    }

    private int GradientsMatrixHeight
    {
        get
        {
            return (int)Math.Ceiling((float)height / resolution) + 1;
        }
    }

    /// <summary>
    /// Generates a Perlin Noise Map
    /// </summary>
    /// <param name="resolution">
    /// Width and height of each cell in the gradient matrix
    /// (resolution ^ 2 is the amount of points calculated per cell)
    /// </param>
    /// <param name="width">
    /// Width of the gradient matrix.
    /// </param>
    /// <param name="height">
    /// Height of the gradient matrix.
    /// </param>
    /// <returns>
    /// A [resolution * height, resolution * width] matrix of perlin noise points.
    /// </returns>
    public Array<Array<float>> GeneratePerlinMap()
    {
        Vector2[][] gradients = ComputeGradients().ToArray();

        float[][] perlinMap = new float[height][];

        for (var i = 0; i < height; i++)
            perlinMap[i] = new float[width];

        var halfResSpace = 1f / resolution / 2f;
        var halfResBlock = new Vector2(halfResSpace, halfResSpace);

        for (var i = 0; i < GradientsMatrixHeight - 1; i++)
            for (var j = 0; j < GradientsMatrixWidth - 1; j++)
            {
                var clockwiseGradients = new Vector2[] {
                    gradients[i][j],
                    gradients[i][j + 1],
                    gradients[i + 1][j + 1],
                    gradients[i + 1][j]
                };

                for (var x = 0; x < resolution && j * resolution + x < width; x++)
                    for (var y = 0; y < resolution && i * resolution + y < height; y++)
                    {
                        var pointCoords = new Vector2((float)x / resolution, (float)y / resolution) + halfResBlock;

                        perlinMap[i * resolution + y][j * resolution + x] = GeneratePerlinPoint(pointCoords, clockwiseGradients);
                    }
            }

        return new Array<Array<float>>(from subArr in perlinMap select new Array<float>(subArr));
    }

    private static float GeneratePerlinPoint(Vector2 coords, Vector2[] clockwiseGradients)
    {
        var clockwiseDots = new float[clockwiseGradients.Length];

        Vector2[] corners = new Vector2[] {
            Vector2.Zero,
            Vector2.Right,
            Vector2.Right + Vector2.Down,
            Vector2.Down
        };

        for (var i = 0; i < clockwiseGradients.Length; i++)
        {
            var offset = (coords - corners[i]).Normalized();

            clockwiseDots[i] = clockwiseGradients[i].Dot(offset);
        }

        var xInterpolation0 = Interpolate(clockwiseDots[0], clockwiseDots[1], coords.X);
        var xInterpolation1 = Interpolate(clockwiseDots[3], clockwiseDots[2], coords.X);

        return Interpolate(xInterpolation0, xInterpolation1, coords.Y);
    }

    private static float Interpolate(float x, float y, float w)
    {
        return x + w * (y - x);
    }

    private IEnumerable<Vector2[]> ComputeGradients()
    {
        IEnumerable<Vector2> ComputeRow()
        {
            for (var i = 0; i < GradientsMatrixWidth; i++)
                yield return GetRandomVector();
        }

        for (var j = 0; j < GradientsMatrixHeight; j++)
            yield return ComputeRow().ToArray();
    }

    private Vector2 GetRandomVector()
    {
        var vector = new Vector2(RandomInstance.NextSingle() - 0.5f, RandomInstance.NextSingle() - 0.5f);

        return vector.Normalized();
    }
}

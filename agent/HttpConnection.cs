using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using System.Text.Json;

#nullable enable

namespace Agent;

class HttpConnection
{
    private const string ApiKey = "AIzaSyCIdEIkEz9e2tKNnOja0tt4z2Dv_5Jqpoo";

    public static async Task<string?> SelectOption(string message, string[] options)
    {
        const string apiUrl = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key={ApiKey}";

        // Create an HttpClient instance
        using var client = new HttpClient();

        // Define your request data (in this case, the JSON payload)
        var requestData = new
        {
            contents = new[]
            {
                new
                {
                    parts = new[]
                    {
                        new
                        {
                            text = $"Dado este mensaje ingresado por el usuario en mi juego de simulacion de batallas:{message} ¿Cuál de las siguientes opciones es la más cercana a lo expresado?\n" +
                                   string.Join("\n", options)
                        }
                    }
                }
            }
        };

        // Serialize the request data to JSON
        var jsonContent = new StringContent(JsonSerializer.Serialize(requestData), Encoding.UTF8,
            "application/json");
        
        
        try
        {
            // Make the POST request
            var response = await client.PostAsync(apiUrl, jsonContent);

            // Handle the response
            if (response.IsSuccessStatusCode)
            {
                var responseContent = await response.Content.ReadAsStringAsync();
                var root = JsonSerializer.Deserialize<Root>(responseContent);
                return root?.candidates[0].content.parts[0].text;
            }

            throw new ApplicationException($"Error: {response.StatusCode} - {response.ReasonPhrase}");
        }
        catch (Exception ex)
        {
            throw new ApplicationException($"Exception: {ex.Message}");
        }
    }
}
using System.Collections.Generic;

namespace Agent;

public class SafetyRatings
{
    public string category { get; set; }
    public string probability { get; set; }
}

public class Candidate
{
    public Content content { get; set; }
    public string finishReason { get; set; }
    public int index { get; set; }
    public List<SafetyRatings> safetyRatings { get; set; }
}

public class Part
{
    public string text { get; set; }
}

public class Content
{
    public List<Part> parts { get; set; }
    public string role { get; set; }
}

public class Root
{
    public List<Candidate> candidates { get; set; }
}
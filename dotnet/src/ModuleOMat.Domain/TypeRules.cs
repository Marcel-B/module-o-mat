namespace ModuleOMat.Domain;

public static class TypeRules
{
    public const string FallbackTypeName = "Sonstiges";

    public static readonly IReadOnlyList<string> DefaultTypeNames =
    [
        "VCO",
        "VCA",
        "VCF",
        "LFO",
        "Envelope",
        "Sequencer",
        "Quantizer",
        "Clock",
        "Random",
        "Logic",
        "Mixer",
        "Effect",
        "Utility",
        "MIDI-Interface",
        "Multiple",
        "Attenuator",
        "Noise",
        FallbackTypeName
    ];

    public static bool IsFallback(string? name) =>
        string.Equals(name?.Trim(), FallbackTypeName, StringComparison.Ordinal);

    public static IReadOnlyList<string> NormalizeSubtypes(IEnumerable<string>? subtypes, string? haupttyp)
    {
        var type = haupttyp?.Trim();
        return (subtypes ?? [])
            .Select(value => value.Trim())
            .Where(value => value.Length > 0 && value != type)
            .Distinct(StringComparer.Ordinal)
            .ToArray();
    }

    public static IReadOnlyList<string> ReplaceSubtype(
        IEnumerable<string>? subtypes,
        string oldName,
        string newName,
        string haupttyp)
    {
        return NormalizeSubtypes(
            (subtypes ?? []).Select(value => value == oldName ? newName : value),
            haupttyp);
    }

    public static IReadOnlyList<string> RemoveSubtype(IEnumerable<string>? subtypes, string name) =>
        (subtypes ?? []).Where(value => value != name).ToArray();
}

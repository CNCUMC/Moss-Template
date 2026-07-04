using BepInEx;
using BepInEx.Logging;
using HarmonyLib;

namespace MossTemplate;

[BepInPlugin(Guid, Name, Version)]
public class Plugin : BaseUnityPlugin
{
    public const string Guid = "org.cncumc.mosstemplate";
    public const string Name = "Moss Template";
    public const string Version = "1.0.0";
    internal new static ManualLogSource Logger;
    private readonly Harmony _harmony = new(Guid);

    public void Awake()
    {
        Logger = base.Logger;
        _harmony.PatchAll();

        Logger.LogInfo("Moss Template loaded!");
    }
}
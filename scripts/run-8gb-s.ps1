# The title on an 8 GB NVIDIA card (measured on an RTX 3070 8 GB, i7 with 16
# logical processors, 31 GB of RAM) with the Series S profile: this tree's own
# launcher (play-foxhound.ps1, tuned on an RTX 4070 SUPER) with -SeriesS, and
# on top what the 8 GB work on the earlier line of this fork measured.
#
#   .\scripts\run-8gb-s.ps1 -Exe 'C:\path\to\game.exe' [-Build diag] [-More @{VICTORY_X='1'}]
#
# Logs go where play-foxhound.ps1 writes them: %LOCALAPPDATA%\victory\logs.
# Anything play-foxhound.ps1 takes can be given too (-Dlss off, -Fps 30, ...).

param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('diag', 'release')][string]$Build = 'release',
    [hashtable]$More = @{},
    [Parameter(ValueFromRemainingArguments = $true)]$Rest
)

$ErrorActionPreference = 'Stop'

$eightGb = @{
    # Copies of title buffers in the card's memory, read there by shaders
    # instead of over the bus. This tree gives an 8 GB card 512 MB of them;
    # on the earlier line of this fork, runs 2026-11-27 01:29 / 01:35 on this
    # card (same place, standing) took world frames from 251-255 ms with 512
    # to 174-187 ms with 1280. Not measured on this tree yet: '512' for its
    # own default.
    VICTORY_CARD_BUFFERS_MB = '1280'
}
# What the caller gives goes over these.
foreach ($k in $More.Keys) { $eightGb[$k] = $More[$k] }

# The page file. On the earlier line (runs 2026-11-27 11:35-13:59) the process
# held 21-23 GB of this 31 GB PC with 0.4-1.5 GB left to commit as the world
# loaded; Windows grows a system-managed page file while a process waits, and
# frames stalled for 1-8 s. Only said, never changed.
try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $commitGb = [math]::Round($os.TotalVirtualMemorySize / 1MB, 1)
    if ($cs.AutomaticManagedPagefile -or $commitGb -lt 48) {
        Write-Warning ("The page file is {0}, commit limit {1} GB. A fixed page file of 32768 MB (System > Advanced " +
            "system settings > Performance > Virtual memory) keeps Windows from growing it mid-game, which stalls frames.") -f $(if ($cs.AutomaticManagedPagefile) { 'system-managed' } else { 'fixed' }), $commitGb
    }
} catch { }

& (Join-Path $PSScriptRoot 'play-foxhound.ps1') -Exe $Exe -SeriesS -Build $Build -More $eightGb @Rest

# The title on an 8 GB NVIDIA card (measured on an RTX 3070 8 GB, i7 with 16
# logical processors, 31 GB of RAM) with the Series S profile: this tree's own
# launcher (play-foxhound.ps1, tuned on an RTX 4070 SUPER) with -SeriesS, and
# on top what the 8 GB work on the earlier line of this fork measured.
#
#   .\scripts\run-8gb-s.ps1 -Exe 'C:\path\to\game.exe' [-Build diag] [-More @{VICTORY_X='1'}]
#   .\scripts\run-8gb-s.ps1 -Exe ... -Options @{Dlss='off'; Fps=30}   other play-foxhound.ps1 options, by name
#
# Logs go where play-foxhound.ps1 writes them: %LOCALAPPDATA%\victory\logs.

param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('diag', 'release')][string]$Build = 'release',
    [hashtable]$More = @{},
    # Other options of play-foxhound.ps1, by name (passed on as they are).
    [hashtable]$Options = @{}
)

# No $ErrorActionPreference = 'Stop' here: play-foxhound.ps1 runs in this
# scope's child and inherits it, and Windows PowerShell then stops at the
# first line victory.exe writes to stderr (its 2>&1 makes each an error).

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

# The layer built from this tree every time. play-foxhound.ps1 builds it only
# when there is none, so after a change of branch it ran the old one: runs
# 2026-11-27 19:43-19:57 used a victory.exe from 18:29, of the earlier line
# (no Streamline, a black Series S picture, 1-2 fps). Cargo does nothing when
# it is current.
$repo = Split-Path $PSScriptRoot
if (Get-Command cargo -ErrorAction SilentlyContinue) {
    Push-Location $repo
    try {
        if ($Build -eq 'diag') { cargo build --locked --profile diag -p victory --features diagnostics }
        else { cargo build --release --locked -p victory }
        if ($LASTEXITCODE -ne 0) { Write-Host 'The build failed (above); not starting the old victory.exe.'; return }
    } finally { Pop-Location }
} else {
    Write-Warning 'No cargo: starting whatever victory.exe is in target\, which may be from another branch.'
}

# DLSS. On Series S the title upscales its picture with its own FidelityFX,
# whose compute programs do not translate (20 refused, run 2026-11-27 19:50;
# none on Series X), so without DLSS taking that step the 3D picture and the
# loading screens stay black under the interface. DLSS needs NVIDIA's files.
$sl = if ($env:VICTORY_STREAMLINE_DIR) { $env:VICTORY_STREAMLINE_DIR } else { Join-Path (Split-Path $PSScriptRoot) 'nvidia-sdk\Streamline\bin\x64' }
if ($Options['Dlss'] -eq 'off') {
    Write-Warning "-Options @{Dlss='off'} on Series S: the title's own upscaler does not run here, so the 3D picture stays black."
} elseif (-not (Test-Path (Join-Path $sl 'sl.interposer.dll'))) {
    Write-Warning ("No NVIDIA DLSS files in ${sl}: on Series S the 3D picture stays black without them. " +
        "Get-NVIDIA-DLSS.cmd in the repository folder fetches them from NVIDIA once (about 70 MB).")
}

# Every option by name: a positional one lands on whichever parameter comes
# next (an empty list of leftover arguments once did, on -Res).
$call = @{} + $Options
$call.Exe = $Exe
$call.SeriesS = $true
$call.Build = $Build
$call.More = $eightGb
& (Join-Path $PSScriptRoot 'play-foxhound.ps1') @call

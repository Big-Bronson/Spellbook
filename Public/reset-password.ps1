# reset-password.ps1
# Resets an M365 user's password. Generates a secure random password by default,
# or lets the engineer set one manually. Force-change on next login defaults to off.
# Requires: Graph (User.ReadWrite.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All" -ContextScope Process
}

$upn = Read-Host "User UPN"

$user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property "Id,DisplayName,UserPrincipalName" -ErrorAction SilentlyContinue
if (-not $user) {
    Write-Host "User not found: $upn" -ForegroundColor Red
    return
}

$setOwn    = (Read-Host "Set your own password? (y/n)") -eq "y"
$forceChange = (Read-Host "Require change on next login? (y/n)") -eq "y"

if ($setOwn) {
    $pwd = Read-Host "New password"
    if (-not $pwd) {
        Write-Host "No password entered. Aborted." -ForegroundColor Red
        return
    }
} else {
    # Cryptographic random password — same generator as offboard-user.ps1.
    # [System.Web.Security.Membership] is unavailable in PS 7; this portable
    # implementation guarantees M365 complexity rules (one of each char class).
    $upper = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower = [char[]]'abcdefghjkmnpqrstuvwxyz'
    $digit = [char[]]'23456789'
    $sym   = [char[]]'!@#$%^&*-_=+'
    $all   = @($upper + $lower + $digit + $sym)
    $rng   = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $buf   = [byte[]]::new(4)
    $pick  = {
        param($pool)
        $rng.GetBytes($buf)
        $pool[[BitConverter]::ToUInt32($buf, 0) % [uint32]$pool.Length]
    }
    $chars = [System.Collections.Generic.List[char]]::new()
    $chars.Add((& $pick $upper))
    $chars.Add((& $pick $lower))
    $chars.Add((& $pick $digit))
    $chars.Add((& $pick $sym))
    while ($chars.Count -lt 20) { $chars.Add((& $pick $all)) }
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $rng.GetBytes($buf)
        $j = [int]([BitConverter]::ToUInt32($buf, 0) % [uint32]($i + 1))
        $tmp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $tmp
    }
    $pwd = -join $chars
}

try {
    Update-MgUser -UserId $user.Id -PasswordProfile @{
        Password                      = $pwd
        ForceChangePasswordNextSignIn = $forceChange
    } -ErrorAction Stop

    Write-Host ""
    Write-Host "  [OK] Password reset for $($user.DisplayName) ($upn)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  New password:   $pwd" -ForegroundColor Green
    if ($forceChange) {
        Write-Host "  User will be required to change password on next sign-in." -ForegroundColor Yellow
    }
    Write-Host ""
} catch {
    Write-Host "  [FAILED] $_" -ForegroundColor Red
}

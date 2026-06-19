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

$isGenerated = -not $setOwn
$newPassword = $null

if ($setOwn) {
    # Engineer-supplied password: SecureString prompt, converted to plain
    # only at the point of use and cleared immediately after. Same pattern
    # as new-user.ps1. Never echoed — the engineer typed it, they know it.
    $securePw = Read-Host "New password" -AsSecureString
    if ($securePw.Length -eq 0) {
        Write-Host "No password entered. Aborted." -ForegroundColor Red
        return
    }
    $newPassword = [System.Net.NetworkCredential]::new('', $securePw).Password
} else {
    # Cryptographic random password — same generator as offboard-user.ps1.
    # [System.Web.Security.Membership] is unavailable in PS 7; this portable
    # implementation guarantees M365 complexity rules (one of each char class).
    # Unlike the engineer-supplied path, this one IS displayed once below —
    # the engineer doesn't know the value and has to relay it to the user.
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
    $newPassword = -join $chars
}

try {
    Update-MgUser -UserId $user.Id -PasswordProfile @{
        Password                      = $newPassword
        ForceChangePasswordNextSignIn = $forceChange
    } -ErrorAction Stop

    Write-Host ""
    Write-Host "  [OK] Password reset for $($user.DisplayName) ($upn)" -ForegroundColor Green
    if ($isGenerated) {
        Write-Host ""
        Write-Host "  New password:   $newPassword" -ForegroundColor Green
        Write-Host "  Relay this to the user now — it will not be shown again." -ForegroundColor Yellow
    }
    Write-Host ""
    if ($forceChange) {
        Write-Host "  User will be required to change password on next sign-in." -ForegroundColor Yellow
    }
    Write-Host ""
} catch {
    Write-Host "  [FAILED] $_" -ForegroundColor Red
} finally {
    $newPassword = $null
}

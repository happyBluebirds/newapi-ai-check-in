param()

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$EncryptedPasswordPath = Join-Path $ProjectRoot "local-secrets\linuxdo-password.dpapi"
$StorageStatePath = Join-Path $ProjectRoot "storage-states\linuxdo_local_storage_state.json"
$PythonPath = Join-Path $ProjectRoot ".venv\Scripts\python.exe"

# DPAPI binds this ciphertext to the current Windows user, so the scheduled job never stores a plaintext password.
if (-not (Test-Path -LiteralPath $EncryptedPasswordPath)) {
    throw "Encrypted Linux.do password is missing: $EncryptedPasswordPath"
}
$SecurePassword = Get-Content -Raw -LiteralPath $EncryptedPasswordPath | ConvertTo-SecureString
$PasswordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
try {
    $PlainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($PasswordPointer)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PasswordPointer)
}

# Each account names its real provider; base_url is not a supported account field in this project.
$Accounts = @(
    @{ name = "毛毛林"; provider = "maoyulin"; "linux.do" = $true },
    @{ name = "Elysiver"; provider = "elysiver"; "linux.do" = $true },
    @{ name = "2020111"; provider = "2020111_xyz"; "linux.do" = $true },
    @{ name = "7r.fit"; provider = "sevenr"; "linux.do" = $true },
    @{ name = "沉醉"; provider = "chenzui"; "linux.do" = $true },
    @{ name = "Jiuuij"; provider = "jiuuij"; "linux.do" = $true },
    @{ name = "X666"; provider = "x666"; "linux.do" = $true }
)
$LinuxDoAccounts = @(@{ username = "luckyQ"; password = $PlainPassword })
$StorageState = Get-Content -Raw -LiteralPath $StorageStatePath | ConvertFrom-Json
$StorageStates = [ordered]@{ luckyQ = $StorageState }

# Environment variables match the GitHub workflow contract while keeping execution entirely on this machine.
$env:ACCOUNTS = ConvertTo-Json -InputObject $Accounts -Depth 10 -Compress
$env:ACCOUNTS_LINUX_DO = ConvertTo-Json -InputObject $LinuxDoAccounts -Depth 10 -Compress
$env:STORATE_STATES_LINUXDO = ConvertTo-Json -InputObject $StorageStates -Depth 100 -Compress
$env:RUN_LINUXDO_LOGIN_MANUAL = "true"
$env:PYTHONIOENCODING = "utf-8"

# Windows may preserve download-zone metadata on virtual-environment executables; unblock before scheduled execution.
Get-ChildItem (Join-Path $ProjectRoot ".venv") -Recurse -File | Unblock-File
Push-Location $ProjectRoot
try {
    & $PythonPath -u main.py
    exit $LASTEXITCODE
} finally {
    $PlainPassword = $null
    Pop-Location
}

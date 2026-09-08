param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Continue"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
for ($index = 0; $index -lt $Arguments.Count; $index++) {
    switch ($Arguments[$index]) {
        "--project-root" {
            if ($index + 1 -ge $Arguments.Count) {
                Write-Host "ERROR: --project-root requires a path"
                exit 2
            }
            $index++
            if (-not (Test-Path -LiteralPath $Arguments[$index] -PathType Container)) {
                Write-Host "ERROR: project root does not exist: $($Arguments[$index])"
                exit 2
            }
            $projectRoot = (Resolve-Path -LiteralPath $Arguments[$index]).Path
        }
        "--help" {
            Write-Host "Usage: check-full-source-rules.ps1 [--project-root <path>]"
            exit 0
        }
        default {
            Write-Host "ERROR: unknown argument: $($Arguments[$index])"
            exit 2
        }
    }
}

$bash = Get-Command bash -ErrorAction SilentlyContinue
if ($null -ne $bash) {
    $script = Join-Path $PSScriptRoot "check-full-source-rules.sh"
    & $bash.Source $script --project-root $projectRoot
    exit $LASTEXITCODE
}

Write-Host "ERROR: bash is required to run the full-source rules bundle on iOS."
exit 2

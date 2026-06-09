#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-validate Salesforce Unlocked Package - detect errors BEFORE 30min build.
.EXAMPLE
    .\scripts\validate-package.ps1
    .\scripts\validate-package.ps1 -TargetDevHub prod -DefinitionFile config/project-scratch-def.json
#>
param(
    [string]$TargetDevHub = "prod",
    [string]$DefinitionFile = "config/project-scratch-def.json",
    [string]$PackagePath = "force-app"
)

$ErrorActionPreference = "Continue"
$script:errors = @()
$script:warnings = @()
$script:passed = @()

function Write-Check {
    param([string]$Name, [string]$Status, [string]$Detail = "")
    switch ($Status) {
        "PASS" { $script:passed += $Name; Write-Host "  [PASS] $Name" -ForegroundColor Green }
        "FAIL" { $script:errors += "${Name}: $Detail"; Write-Host "  [FAIL] $Name -- $Detail" -ForegroundColor Red }
        "WARN" { $script:warnings += "${Name}: $Detail"; Write-Host "  [WARN] $Name -- $Detail" -ForegroundColor Yellow }
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SF Package Pre-Validation Tool v1.0" -ForegroundColor Cyan
Write-Host "  Detect errors BEFORE wasting 30min on build" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
$startTime = Get-Date

# === CHECK 1: Project Structure ===
Write-Host "--- [1/9] Project Structure ---" -ForegroundColor White
if (Test-Path "sfdx-project.json") {
    try {
        $projectJson = Get-Content "sfdx-project.json" -Raw | ConvertFrom-Json
        Write-Check "sfdx-project.json parseable" "PASS"
        $pkgDir = $projectJson.packageDirectories | Where-Object { $_.package }
        if ($pkgDir) {
            Write-Check "Package: $($pkgDir.package)" "PASS"
            if ($pkgDir.versionNumber -match '^\d+\.\d+\.\d+\.NEXT$') {
                Write-Check "Version: $($pkgDir.versionNumber)" "PASS"
            } else { Write-Check "Version format" "FAIL" "Expected X.Y.Z.NEXT got $($pkgDir.versionNumber)" }
        } else { Write-Check "Package definition" "FAIL" "No package in packageDirectories" }
    } catch { Write-Check "sfdx-project.json" "FAIL" "Parse error" }
} else { Write-Check "sfdx-project.json" "FAIL" "Not found" }

if (Test-Path $DefinitionFile) {
    try { $scratchDef = Get-Content $DefinitionFile -Raw | ConvertFrom-Json; Write-Check "Scratch def" "PASS" }
    catch { Write-Check "Scratch def" "FAIL" "Parse error" }
} else { Write-Check "Scratch def" "FAIL" "Not found" }

if (Test-Path $PackagePath) { Write-Check "Package path" "PASS" }
else { Write-Check "Package path" "FAIL" "Not found" }


# === CHECK 2: .forceignore ===
Write-Host ""
Write-Host "--- [2/9] .forceignore vs Unsupported Metadata ---" -ForegroundColor White
$forceIgnoreContent = ""
if (Test-Path ".forceignore") { $forceIgnoreContent = Get-Content ".forceignore" -Raw; Write-Check ".forceignore" "PASS" }
else { Write-Check ".forceignore" "FAIL" "Not found" }

$unsupported = @("sharingRules","searchCustomizations","settings")
foreach ($t in $unsupported) {
    $dir = Join-Path $PackagePath "main/default/$t"
    $ignored = $forceIgnoreContent -match "\*\*/$t/\*\*"
    if ((Test-Path $dir) -and -not $ignored) { Write-Check "$t" "FAIL" "Exists but NOT in .forceignore" }
    elseif ((Test-Path $dir) -and $ignored) { Write-Check "$t excluded" "PASS" }
    else { Write-Check "$t not present" "PASS" }
}

$entDir = Join-Path $PackagePath "main/default/entitlementProcesses"
if ((Test-Path $entDir) -and -not ($forceIgnoreContent -match "\*\*/entitlementProcesses/\*\*")) {
    Write-Check "EntitlementProcesses" "WARN" "Not excluded, Active SLA may conflict"
} elseif (Test-Path $entDir) { Write-Check "EntitlementProcesses excluded" "PASS" }

# === CHECK 3: StandardValueSet vs BusinessProcess ===
Write-Host ""
Write-Host "--- [3/9] StandardValueSet vs BusinessProcess ---" -ForegroundColor White
$svsDir = Join-Path $PackagePath "main/default/standardValueSets"
$svsExcluded = ($forceIgnoreContent -split "`n" | Where-Object { $_ -notmatch '^\s*#' -and $_ -match "standardValueSets" }).Count -gt 0
if ($svsExcluded) {
    Write-Check "StandardValueSets" "FAIL" "EXCLUDED but BusinessProcess needs them"
} else {
    $bpDir = Join-Path $PackagePath "main/default/objects/Case/businessProcesses"
    if (Test-Path $bpDir) {
        foreach ($bp in (Get-ChildItem $bpDir -Filter "*.businessProcess-meta.xml")) {
            $bpContent = Get-Content $bp.FullName -Raw
            $allVals = [regex]::Matches($bpContent, '<fullName>(.+?)</fullName>') | ForEach-Object { $_.Groups[1].Value }
            # First fullName is the BP name itself, skip it
            $vals = $allVals | Select-Object -Skip 1
            $svf = Join-Path $svsDir "CaseStatus.standardValueSet-meta.xml"
            if (Test-Path $svf) {
                $svs = Get-Content $svf -Raw
                $miss = @(); foreach ($v in $vals) { if ($svs -notmatch "<fullName>$([regex]::Escape($v))</fullName>") { $miss += $v } }
                if ($miss.Count -eq 0) { Write-Check "BP $($bp.BaseName) values OK" "PASS" }
                else { Write-Check "BP $($bp.BaseName)" "FAIL" "Missing: $($miss -join ', ')" }
            }
        }
    } else { Write-Check "No BusinessProcesses" "PASS" }
}

# === CHECK 4: External Objects ===
Write-Host ""
Write-Host "--- [4/9] External Objects ---" -ForegroundColor White
$objDir = Join-Path $PackagePath "main/default/objects"
$dsDir = Join-Path $PackagePath "main/default/dataSources"
$extObjs = @()
if (Test-Path $objDir) { $extObjs = Get-ChildItem $objDir -Directory | Where-Object { $_.Name -like "*__x" } }
if ($extObjs.Count -gt 0) {
    Write-Check "External objects: $($extObjs.Name -join ', ')" "WARN" "Needs DataSource and PlatformConnect"
    if (Test-Path $dsDir) { Write-Check "DataSource present" "PASS" }
    else { Write-Check "DataSource" "FAIL" "No dataSources/ dir" }
    if ($scratchDef -and $scratchDef.features -and ($scratchDef.features | Where-Object { $_ -match "PlatformConnect" })) {
        Write-Check "PlatformConnect" "PASS"
    } else { Write-Check "PlatformConnect" "FAIL" "Not in scratch def features" }
} else { Write-Check "No external objects" "PASS" }

# === CHECK 5: Apex Metadata ===
Write-Host ""
Write-Host "--- [5/9] Apex Metadata ---" -ForegroundColor White
$classDir = Join-Path $PackagePath "main/default/classes"
if (Test-Path $classDir) {
    $clsFiles = Get-ChildItem $classDir -Filter "*.cls"
    $missingMeta = @(); $badApi = @()
    $expectedApi = $projectJson.sourceApiVersion
    foreach ($cls in $clsFiles) {
        $meta = "$($cls.FullName)-meta.xml"
        if (-not (Test-Path $meta)) { $missingMeta += $cls.Name }
        else {
            $mc = Get-Content $meta -Raw
            if ($mc -match '<apiVersion>(\d+\.\d+)</apiVersion>' -and [double]$Matches[1] -gt [double]$expectedApi) {
                $badApi += "$($cls.Name)(v$($Matches[1]))"
            }
        }
    }
    if ($missingMeta.Count -eq 0) { Write-Check "All $($clsFiles.Count) classes have meta" "PASS" }
    else { Write-Check "Missing -meta.xml" "FAIL" "$($missingMeta.Count) files" }
    if ($badApi.Count -eq 0) { Write-Check "API versions OK (<= $expectedApi)" "PASS" }
    else { Write-Check "API version high" "WARN" "$($badApi[0..2] -join ', ')" }
}
$triggerDir = Join-Path $PackagePath "main/default/triggers"
if (Test-Path $triggerDir) {
    $trigs = Get-ChildItem $triggerDir -Filter "*.trigger"
    $mt = @(); foreach ($t2 in $trigs) { if (-not (Test-Path "$($t2.FullName)-meta.xml")) { $mt += $t2.Name } }
    if ($mt.Count -eq 0) { Write-Check "All triggers have meta" "PASS" }
    else { Write-Check "Missing trigger meta" "FAIL" "$($mt -join ', ')" }
}

# === CHECK 6: LWC/Aura ===
Write-Host ""
Write-Host "--- [6/9] LWC/Aura ---" -ForegroundColor White
$lwcDir = Join-Path $PackagePath "main/default/lwc"
if (Test-Path $lwcDir) {
    $comps = Get-ChildItem $lwcDir -Directory | Where-Object { $_.Name -ne "__tests__" }
    $mj = @(); $mm = @()
    foreach ($c in $comps) {
        if (-not (Test-Path (Join-Path $c.FullName "$($c.Name).js"))) { $mj += $c.Name }
        if (-not (Test-Path (Join-Path $c.FullName "$($c.Name).js-meta.xml"))) { $mm += $c.Name }
    }
    if ($mj.Count -eq 0 -and $mm.Count -eq 0) { Write-Check "All $($comps.Count) LWC valid" "PASS" }
    else {
        if ($mj.Count -gt 0) { Write-Check "LWC missing .js" "FAIL" "$($mj[0..2] -join ', ')" }
        if ($mm.Count -gt 0) { Write-Check "LWC missing meta" "FAIL" "$($mm[0..2] -join ', ')" }
    }
}
$auraDir = Join-Path $PackagePath "main/default/aura"
if (Test-Path $auraDir) {
    $ac = Get-ChildItem $auraDir -Directory; $bad = @()
    foreach ($a in $ac) {
        $has = (Test-Path (Join-Path $a.FullName "$($a.Name).cmp")) -or (Test-Path (Join-Path $a.FullName "$($a.Name).app")) -or (Test-Path (Join-Path $a.FullName "$($a.Name).evt"))
        if (-not $has) { $bad += $a.Name }
    }
    if ($bad.Count -eq 0) { Write-Check "All $($ac.Count) Aura valid" "PASS" }
    else { Write-Check "Aura missing main" "FAIL" "$($bad[0..2] -join ', ')" }
}

# === CHECK 7: Duplicate API Names ===
Write-Host ""
Write-Host "--- [7/9] Duplicate API Names ---" -ForegroundColor White
$metaDirs = Get-ChildItem $PackagePath -Recurse -Directory | Where-Object { 
    $_.Name -match "^(fields|recordTypes|validationRules|webLinks|compactLayouts|listViews)$" 
}
$dups = @()
foreach ($md in $metaDirs) {
    $files = Get-ChildItem $md.FullName -Filter "*-meta.xml"
    $seen = @{}
    foreach ($f in $files) {
        $baseName = $f.BaseName -replace '-meta$', ''
        if ($seen.ContainsKey($baseName)) { $dups += "$($md.Parent.Name)/$($md.Name)/$baseName" }
        else { $seen[$baseName] = $true }
    }
}
if ($dups.Count -eq 0) { Write-Check "No duplicates" "PASS" }
else { Write-Check "Duplicates" "FAIL" "$($dups.Count): $($dups[0..2] -join ', ')" }

# === CHECK 8: Profile refs ===
Write-Host ""
Write-Host "--- [8/9] Profile Field References ---" -ForegroundColor White
$profileDir = Join-Path $PackagePath "main/default/profiles"
$permsetDir = Join-Path $PackagePath "main/default/permissionsets"
$pFiles = @()
if (Test-Path $profileDir) { $pFiles += Get-ChildItem $profileDir -Filter "*.profile-meta.xml" }
if (Test-Path $permsetDir) { $pFiles += Get-ChildItem $permsetDir -Filter "*.permissionset-meta.xml" }
$broken = @()
foreach ($pf in $pFiles) {
    $content = Get-Content $pf.FullName -Raw
    [regex]::Matches($content, '<field>(.+?)</field>') | ForEach-Object {
        $ref = $_.Groups[1].Value
        $parts = $ref -split '\.'
        if ($parts.Count -eq 2 -and $parts[0] -like "*__c" -and -not (Test-Path (Join-Path $objDir $parts[0]))) {
            $broken += "$ref ($($pf.Name))"
        }
    }
}
if ($broken.Count -eq 0) { Write-Check "Profile refs valid" "PASS" }
else {
    Write-Check "Broken refs" "WARN" "$($broken.Count) to objects not in package"
    $broken[0..3] | ForEach-Object { Write-Host "       -> $_" -ForegroundColor DarkYellow }
}

# === CHECK 9: DevHub ===
Write-Host ""
Write-Host "--- [9/9] DevHub ---" -ForegroundColor White
try {
    $oi = sf org display --target-org $TargetDevHub --json 2>$null | ConvertFrom-Json
    if ($oi.status -eq 0) {
        Write-Check "DevHub connected" "PASS"
        if ($oi.result.isDevHub -eq $true -or $oi.result.devHubId) {
            Write-Check "Is DevHub" "PASS"
        } else {
            if ($projectJson.packageAliases) { Write-Check "Is DevHub (inferred from package)" "PASS" }
            else { Write-Check "Is DevHub" "WARN" "Cannot confirm" }
        }
    } else { Write-Check "DevHub" "FAIL" "Cannot reach" }
} catch { Write-Check "DevHub" "FAIL" "$_" }

if ($projectJson.packageAliases) {
    $pkgName = ($projectJson.packageDirectories | Where-Object { $_.package }).package
    if ($projectJson.packageAliases.PSObject.Properties.Name -contains $pkgName) {
        Write-Check "Package registered" "PASS"
    } else { Write-Check "Package" "FAIL" "Not in packageAliases" }
}

# === SUMMARY ===
$elapsedSec = ((Get-Date) - $startTime).TotalSeconds
$elapsedRound = [int]$elapsedSec
Write-Host ""
Write-Host "================================================================" -ForegroundColor White
Write-Host "  PASSED: $($script:passed.Count)  WARNINGS: $($script:warnings.Count)  ERRORS: $($script:errors.Count)" -ForegroundColor White
Write-Host "  Time: ${elapsedRound}s" -ForegroundColor DarkGray
Write-Host ""
if ($script:errors.Count -gt 0) {
    Write-Host "  DO NOT BUILD - Fix errors:" -ForegroundColor Red
    $script:errors | ForEach-Object { Write-Host "     * $_" -ForegroundColor Red }
    exit 1
} elseif ($script:warnings.Count -gt 0) {
    Write-Host "  MAY SUCCEED - review warnings" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "  ALL CLEAR - Safe to build" -ForegroundColor Green
    exit 0
}

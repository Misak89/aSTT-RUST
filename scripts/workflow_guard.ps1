# workflow_guard.ps1
# Workflow Execution Guard - hlavni verifikacni skript
# Verze: 1.0
# Vytvoreno: 2026-02-15 18:05 (UTC+1)

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("pre-commit", "pre-push", "pre-build", "ci")]
    [string]$Trigger,
    
    [switch]$DryRun,
    [switch]$DetailedOutput,
    [switch]$Force,
    [string]$ConfigPath = "workflow-steps.json",
    [string]$SchemaPath = "workflow-steps.schema.json",
    [string]$LogPath = "logs/execution-log.json"
)

$ErrorActionPreference = "Stop"
$script:StartTime = Get-Date
$script:Results = @()
$script:Summary = @{
    Total = 0
    Passed = 0
    Failed = 0
    Errors = 0
    Skipped = 0
}

#region Funkce

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "STEP")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "Cyan" }
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        "STEP" { "White" }
        default { "White" }
    }
    
    if ($DetailedOutput -or $Level -in @("ERROR", "WARN", "SUCCESS")) {
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

function Test-JsonSchema {
    param(
        [object]$JsonData,
        [string]$SchemaPath
    )
    
    try {
        if (-not (Test-Path $SchemaPath)) {
            Write-Log "Schema file not found: $SchemaPath" -Level "WARN"
            return $true
        }
        
        $schema = Get-Content $SchemaPath | ConvertFrom-Json
        $errors = @()
        
        # Validace version
        if (-not $JsonData.version) {
            $errors += "Missing 'version' in configuration"
        } elseif ($JsonData.version -notmatch '^\d+\.\d+$') {
            $errors += "Invalid version format: '$($JsonData.version)' (expected: X.Y)"
        }
        
        # Validace steps
        if (-not $JsonData.steps -or $JsonData.steps.Count -eq 0) {
            $errors += "Missing or empty 'steps' in configuration"
        } else {
            $validTriggers = @("pre-commit", "pre-push", "pre-build", "ci")
            $validOnFailure = @("block", "warn", "ignore")
            $seenIds = @{}
            
            for ($i = 0; $i -lt $JsonData.steps.Count; $i++) {
                $step = $JsonData.steps[$i]
                $stepPrefix = "Step[$i]"
                
                # Required fields
                if (-not $step.id) {
                    $errors += "${stepPrefix}: missing 'id'"
                } elseif ($step.id -notmatch '^[a-z0-9-]+$') {
                    $errors += "${stepPrefix}: invalid id format '$($step.id)' (lowercase, numbers, hyphens only)"
                } elseif ($seenIds.ContainsKey($step.id)) {
                    $errors += "${stepPrefix}: duplicate id '$($step.id)'"
                } else {
                    $seenIds[$step.id] = $true
                }
                
                if (-not $step.name) {
                    $errors += "${stepPrefix}: missing 'name'"
                }
                
                if (-not $step.trigger) {
                    $errors += "${stepPrefix}: missing 'trigger'"
                } elseif ($step.trigger -notin $validTriggers) {
                    $errors += "${stepPrefix}: invalid trigger '$($step.trigger)' (valid: $($validTriggers -join ', '))"
                }
                
                if (-not $step.PSObject.Properties.Match('required')) {
                    $errors += "${stepPrefix}: missing 'required' property"
                }
                
                if (-not $step.command) {
                    $errors += "${stepPrefix}: missing 'command'"
                }
                
                # Optional fields validation
                if ($step.timeout -and $step.timeout -lt 1) {
                    $errors += "${stepPrefix}: timeout must be >= 1 (got: $($step.timeout))"
                }
                
                if ($step.onFailure -and $step.onFailure -notin $validOnFailure) {
                    $errors += "${stepPrefix}: invalid onFailure '$($step.onFailure)' (valid: $($validOnFailure -join ', '))"
                }
                
                # Retry validation
                if ($step.retry) {
                    if ($step.retry.maxAttempts -and $step.retry.maxAttempts -lt 1) {
                        $errors += "${stepPrefix}: retry.maxAttempts must be >= 1"
                    }
                    if ($step.retry.delaySeconds -and $step.retry.delaySeconds -lt 0) {
                        $errors += "${stepPrefix}: retry.delaySeconds must be >= 0"
                    }
                    if ($step.retry.retryOn) {
                        $validRetryOn = @("error", "timeout", "failed")
                        foreach ($ro in $step.retry.retryOn) {
                            if ($ro -notin $validRetryOn) {
                                $errors += "${stepPrefix}: invalid retryOn '$ro'"
                            }
                        }
                    }
                }
            }
        }
        
        if ($errors.Count -gt 0) {
            Write-Log "Schema validation failed with $($errors.Count) error(s):" -Level "ERROR"
            foreach ($err in $errors) {
                Write-Log "  - $err" -Level "ERROR"
            }
            return $false
        }
        
        Write-Log "Schema validation passed" -Level "INFO"
        return $true
    }
    catch {
        Write-Log "Schema validation error: $_" -Level "ERROR"
        return $false
    }
}

function Invoke-WorkflowStep {
    param(
        [object]$Step
    )
    
    $result = @{
        Id = $Step.id
        Name = $Step.name
        Status = "pending"
        StartTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
        EndTime = $null
        Duration = 0
        Output = ""
        Error = ""
        Attempts = 1
    }
    
    $maxAttempts = if ($Step.retry -and $Step.retry.maxAttempts) { $Step.retry.maxAttempts } else { 1 }
    $delaySeconds = if ($Step.retry -and $Step.retry.delaySeconds) { $Step.retry.delaySeconds } else { 0 }
    
    Write-Log "Executing: $($Step.name)" -Level "STEP"
    Write-Log "Command: $($Step.command)" -Level "INFO"
    
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $result.Attempts = $attempt
        
        if ($attempt -gt 1) {
            Write-Log "Retry attempt $attempt of $maxAttempts (delay: ${delaySeconds}s)" -Level "WARN"
            Start-Sleep -Seconds $delaySeconds
        }
        
        try {
            $stepStartTime = Get-Date
            $timeout = if ($Step.timeout) { $Step.timeout } else { 60 }
            
            if ($DryRun) {
                Write-Log "[DRY RUN] Would execute: $($Step.command)" -Level "INFO"
                $result.Status = "skipped"
                $result.Output = "[DRY RUN] Step skipped"
                $result.EndTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
                $result.Duration = 0
                $script:Summary.Skipped++
                return $result
            }
            
            # Spuštění příkazu
            $output = & cmd /c $Step.command 2>&1
            $exitCode = $LASTEXITCODE
            $stepEndTime = Get-Date
            $duration = ($stepEndTime - $stepStartTime).TotalSeconds
            
            $result.EndTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
            $result.Duration = [math]::Round($duration, 2)
            $result.Output = $output -join "`n"
            
            # Kontrola výstupu
            $success = $true
            
            if ($exitCode -ne 0) {
                $success = $false
                $result.Error = "Exit code: $exitCode"
            }
            
            if ($Step.expectedOutput -and ($result.Output -notmatch [regex]::Escape($Step.expectedOutput))) {
                $success = $false
                $result.Error = "Expected output not found: $($Step.expectedOutput)"
            }
            
            if ($success) {
                $result.Status = "passed"
                Write-Log "PASSED: $($Step.name) (${duration}s)" -Level "SUCCESS"
                return $result
            }
            else {
                $result.Status = "failed"
                Write-Log "FAILED: $($Step.name)" -Level "ERROR"
                
                # Kontrola, zda máme retryovat
                if ($attempt -lt $maxAttempts) {
                    $retryOn = if ($Step.retry -and $Step.retry.retryOn) { $Step.retry.retryOn } else { @() }
                    if ("error" -in $retryOn -or "failed" -in $retryOn) {
                        continue
                    }
                }
                
                return $result
            }
        }
        catch {
            $result.Status = "error"
            $result.Error = $_.Exception.Message
            $result.EndTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
            Write-Log "ERROR: $($Step.name) - $_" -Level "ERROR"
            
            if ($attempt -lt $maxAttempts) {
                continue
            }
            
            return $result
        }
    }
    
    return $result
}

function Save-ExecutionLog {
    param(
        [array]$Results,
        [hashtable]$Summary
    )
    
    try {
        # Vytvoření adresáře, pokud neexistuje
        $logDir = Split-Path $LogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        # Načtení existujícího logu nebo vytvoření nového
        $log = @{
            version = "1.0"
            executions = @()
        }
        
        if (Test-Path $LogPath) {
            $existingLog = Get-Content $LogPath | ConvertFrom-Json
            $log.executions = $existingLog.executions
        }
        
        # Přidání nového záznamu
        $newExecution = @{
            Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
            Trigger = $Trigger
            DryRun = $DryRun.IsPresent
            Duration = [math]::Round(((Get-Date) - $script:StartTime).TotalSeconds, 2)
            Summary = $Summary
            Results = $Results
        }
        
        $log.executions += $newExecution
        
        # Rotace logů - ponechat posledních N záznamů (konfigurovatelné)
        $maxEntries = if ($script:MaxLogEntries) { $script:MaxLogEntries } else { 30 }
        if ($log.executions.Count -gt $maxEntries) {
            $log.executions = $log.executions | Select-Object -Last $maxEntries
        }
        
        # Uložení
        $log | ConvertTo-Json -Depth 10 | Out-File $LogPath -Encoding UTF8
        Write-Log "Execution log saved to: $LogPath" -Level "INFO"
    }
    catch {
        Write-Log "Failed to save execution log: $_" -Level "WARN"
    }
}

#endregion

#region Hlavní logika

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Workflow Execution Guard v1.0" -ForegroundColor Cyan
Write-Host "  Trigger: $Trigger" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "  Mode: DRY RUN (no changes)" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Kontrola existence konfigurace
if (-not (Test-Path $ConfigPath)) {
    Write-Log "Configuration file not found: $ConfigPath" -Level "ERROR"
    Write-Log "Please create workflow-steps.json first" -Level "ERROR"
    exit 1
}

# Načtení konfigurace
try {
    $config = Get-Content $ConfigPath | ConvertFrom-Json
    Write-Log "Configuration loaded: $($config.steps.Count) steps defined" -Level "INFO"
    
    # Aplikace konfigurace, pokud existuje
    if ($config.config) {
        if ($config.config.logPath -and -not $PSBoundParameters.ContainsKey('LogPath')) {
            $LogPath = $config.config.logPath
        }
        if ($config.config.schemaPath -and -not $PSBoundParameters.ContainsKey('SchemaPath')) {
            $SchemaPath = $config.config.schemaPath
        }
        $script:MaxLogEntries = if ($config.config.maxLogEntries) { $config.config.maxLogEntries } else { 30 }
        $script:AuditLogPath = if ($config.config.auditLogPath) { $config.config.auditLogPath } else { "logs/force-audit.log" }
    } else {
        $script:MaxLogEntries = 30
        $script:AuditLogPath = "logs/force-audit.log"
    }
}
catch {
    Write-Log "Failed to load configuration: $_" -Level "ERROR"
    exit 1
}

# Validace proti schematu
if (-not (Test-JsonSchema -JsonData $config -SchemaPath $SchemaPath)) {
    Write-Log "Configuration validation failed" -Level "ERROR"
    exit 1
}

# Filtrování kroků podle triggeru
$stepsToRun = $config.steps | Where-Object { $_.trigger -eq $Trigger }
$script:Summary.Total = $stepsToRun.Count

if ($stepsToRun.Count -eq 0) {
    Write-Log "No steps defined for trigger: $Trigger" -Level "WARN"
    Write-Host ""
    Write-Host "--- WORKFLOW GUARD PASSED (no steps) ---" -ForegroundColor Green
    exit 0
}

Write-Log "Steps to execute: $($stepsToRun.Count)" -Level "INFO"
Write-Host ""

# Spuštění kroků
$allPassed = $true

foreach ($step in $stepsToRun) {
    $result = Invoke-WorkflowStep -Step $step
    $script:Results += $result
    
    switch ($result.Status) {
        "passed" { $script:Summary.Passed++ }
        "failed" { 
            $script:Summary.Failed++
            $allPassed = $false
        }
        "error" { 
            $script:Summary.Errors++
            $allPassed = $false
        }
        "skipped" { $script:Summary.Skipped++ }
    }
    
    # Pokud krok selhal a onFailure je block, ukončit
    if ($result.Status -in @("failed", "error") -and $step.onFailure -eq "block" -and -not $Force) {
        Write-Log "Step blocked the workflow: $($step.name)" -Level "ERROR"
        break
    }
}

# Uložení logu
Save-ExecutionLog -Results $script:Results -Summary $script:Summary

# Výpis souhrnu
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Total:   $($script:Summary.Total)" -ForegroundColor White
Write-Host "  Passed:  $($script:Summary.Passed)" -ForegroundColor Green
Write-Host "  Failed:  $($script:Summary.Failed)" -ForegroundColor Red
Write-Host "  Errors:  $($script:Summary.Errors)" -ForegroundColor Red
Write-Host "  Skipped: $($script:Summary.Skipped)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Výsledek
if ($allPassed -or $Force) {
    # Audit log pro Force přepínač
    if ($Force -and -not $allPassed) {
        $auditLogPath = if ($script:AuditLogPath) { $script:AuditLogPath } else { "logs/force-audit.log" }
        $failedStepNames = $script:Results | Where-Object { $_.Status -eq "failed" } | ForEach-Object { $_.Name }
        $auditEntry = @{
            Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
            User = $env:USERNAME
            Trigger = $Trigger
            FailedSteps = $failedStepNames
            Summary = $script:Summary
        }
        $auditLine = "$($auditEntry.Timestamp) | User: $($auditEntry.User) | Trigger: $($auditEntry.Trigger) | Failed: $($auditEntry.FailedSteps -join ', ') | Total: $($auditEntry.Summary.Total), Passed: $($auditEntry.Summary.Passed), Failed: $($auditEntry.Summary.Failed)"
        
        try {
            $auditDir = Split-Path $auditLogPath -Parent
            if (-not (Test-Path $auditDir)) {
                New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
            }
            Add-Content -Path $auditLogPath -Value $auditLine
            Write-Log "Force override logged to: $auditLogPath" -Level "WARN"
        } catch {
            Write-Log "Failed to write audit log: $_" -Level "WARN"
        }
    }
    
    Write-Host "--- WORKFLOW GUARD PASSED ---" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "--- WORKFLOW GUARD FAILED ---" -ForegroundColor Red
    Write-Host ""
    Write-Host "Use -Force to override (not recommended)" -ForegroundColor Yellow
    exit 1
}

#endregion

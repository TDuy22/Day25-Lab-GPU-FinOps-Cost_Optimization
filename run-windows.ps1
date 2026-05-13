param(
    [ValidateSet("start", "stop", "status", "logs", "test", "tunnel")]
    [string]$Command = "start",
    [string]$Service = ""
)

$ErrorActionPreference = "Stop"
$GatewayUrl = "http://localhost:8010"
$ComposeArgs = @(
    "--context", "desktop-linux",
    "compose",
    "-f", "docker-compose.yml",
    "-f", "docker-compose.powershell.yml"
)

function Invoke-Compose {
    param([string[]]$Args)
    & docker @ComposeArgs @Args
}

function Test-Endpoint {
    param([string]$Path)
    $url = "$GatewayUrl$Path"
    try {
        Invoke-RestMethod $url | Out-Null
        Write-Host "  [OK] $Path" -ForegroundColor Green
    }
    catch {
        Write-Host "  [FAIL] $Path" -ForegroundColor Red
        throw
    }
}

switch ($Command) {
    "start" {
        Write-Host "[STEP] Building and starting Docker services..."
        Invoke-Compose @("up", "--build", "-d")

        Write-Host "[STEP] Waiting for gateway..."
        Start-Sleep -Seconds 5
        Invoke-RestMethod "$GatewayUrl/" | Out-Null

        Write-Host ""
        Write-Host "ALL SERVICES RUNNING" -ForegroundColor Green
        Write-Host "Gateway:          $GatewayUrl"
        Write-Host "GPU Node Manager: http://localhost:8001"
        Write-Host "Billing API:      http://localhost:8002"
        Write-Host "Spot Manager:     http://localhost:8003"
        Write-Host "Autoscaler:       http://localhost:8004"
        Write-Host "Cost Tracker:     http://localhost:8005"
        Write-Host ""
        Write-Host "Next: .\run-windows.ps1 tunnel"
    }

    "stop" {
        Write-Host "[STEP] Stopping Docker services..."
        Invoke-Compose @("down")
        Write-Host "All lab services stopped." -ForegroundColor Green
    }

    "status" {
        Invoke-Compose @("ps")
        Write-Host ""
        Write-Host "Gateway health:"
        try {
            Invoke-RestMethod "$GatewayUrl/" | ConvertTo-Json -Depth 5
        }
        catch {
            Write-Host "  Gateway is not responding at $GatewayUrl" -ForegroundColor Yellow
        }
    }

    "logs" {
        if ($Service) {
            Invoke-Compose @("logs", "-f", "--tail=50", $Service)
        }
        else {
            Invoke-Compose @("logs", "-f", "--tail=50")
        }
    }

    "test" {
        Write-Host "[STEP] Testing gateway endpoints..."
        Test-Endpoint "/"
        Test-Endpoint "/cluster/nodes"
        Test-Endpoint "/cluster/metrics"
        Test-Endpoint "/billing/pricing"
        Test-Endpoint "/spot/pricing"
        Test-Endpoint "/autoscaler/policy"
        Test-Endpoint "/cost/dashboard"
    }

    "tunnel" {
        Write-Host "[STEP] Starting tunnel to expose gateway..."
        if (Get-Command cloudflared -ErrorAction SilentlyContinue) {
            Write-Host "Using cloudflared. Copy the trycloudflare.com URL into the notebook."
            & cloudflared tunnel --url $GatewayUrl
        }
        elseif (Get-Command ngrok -ErrorAction SilentlyContinue) {
            Write-Host "Using ngrok. Copy the forwarding HTTPS URL into the notebook."
            & ngrok http 8010
        }
        elseif (Get-Command ssh -ErrorAction SilentlyContinue) {
            Write-Host "Using localhost.run over SSH. Keep this terminal open."
            Write-Host "Copy the generated HTTPS URL into the notebook."
            & ssh -o StrictHostKeyChecking=accept-new -R 80:localhost:8010 nokey@localhost.run
        }
        else {
            Write-Host "No tunnel tool found." -ForegroundColor Yellow
            Write-Host "Install cloudflared, then run this command again:"
            Write-Host "  winget install --id Cloudflare.cloudflared"
        }
    }
}

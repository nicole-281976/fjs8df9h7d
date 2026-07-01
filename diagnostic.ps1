# Ensure .NET assemblies for screen capture are loaded
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host "Gathering system diagnostics... Please wait." -ForegroundColor Cyan

### 1. Collect System Info
$hostname   = $env:COMPUTERNAME
$username   = $env:USERNAME
$osVersion  = (Get-CimInstance Win32_OperatingSystem).Caption
# Grabs the first active internal IPv4 address
$ipAddress  = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.IPAddress -notlike "127.*" -and $_.InterfaceAlias -notlike "*Loopback*" 
}).IPAddress | Select-Object -First 1

### 2. Capture Screenshot
try {
    $screen    = [System.Windows.Forms.Screen]::PrimaryScreen
    $bounds    = $screen.Bounds
    $bitmap    = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
    $graphics  = [System.Drawing.Graphics]::FromImage($bitmap)
    
    # Copy screen to bitmap
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    
    # Convert image directly to Base64 in-memory (no local file cleanup needed)
    $ms = New-Object System.IO.MemoryStream
    $bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $ms.ToArray()
    $base64Screenshot = [Convert]::ToBase64String($bytes)
}
catch {
    Write-Warning "Failed to capture screenshot: $_"
    $base64Screenshot = $null
}
finally {
    # Clean up .NET objects
    if ($graphics) { $graphics.Dispose() }
    if ($bitmap) { $bitmap.Dispose() }
    if ($ms) { $ms.Dispose() }
}

### 3. Build the Payload
$payload = @{
    hostname   = $hostname
    username   = $username
    os         = $osVersion
    ip_address = $ipAddress
    timestamp  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    screenshot = $base64Screenshot # Base64 PNG string
} | ConvertTo-Json -Depth 4

### 4. Send to API Backend
# Replace this with your actual API endpoint when it's live
$apiUri = "https://api.claycorematters.com/v1/helpdesk/tickets" 

try {
    Write-Host "Sending data to helpdesk..." -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri $apiUri -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 15
    Write-Host "Success! Ticket created standardly." -ForegroundColor Green
}
catch {
    Write-Error "Failed to send data to helpdesk API. Error: $_"
}

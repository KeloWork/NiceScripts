# Define the URL for the SQLite amalgamation ZIP file
$headerUrl = "https://www.sqlite.org/2024/sqlite-amalgamation-3470000.zip"
$headerZipPath = "$env:TEMP\sqlite-amalgamation.zip"
$w64devkitPath = "$env:TEMP\w64devkit"

# Download and install w64devkit
$w64devkitInstallerUrl = "https://github.com/skeeto/w64devkit/releases/download/v2.0.0/w64devkit-x86_64.exe"
$w64devkitInstallerPath = "$env:TEMP\w64devkit-x86_64.exe"

Write-Output "Downloading w64devkit installer..."
Invoke-WebRequest -Uri $w64devkitInstallerUrl -OutFile $w64devkitInstallerPath

Write-Output "Installing w64devkit..."
Start-Process -FilePath $w64devkitInstallerPath -ArgumentList "/SILENT" -Wait

# Add w64devkit to the system PATH
$env:Path += ";$w64devkitPath\bin"

Write-Output "w64devkit installed and PATH updated."

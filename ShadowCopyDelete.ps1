# Function to delete shadow copies using vssadmin
function Delete-ShadowCopiesVssadmin {
    vssadmin delete shadows /all /quiet
}

# Function to delete shadow copies using wmic
function Delete-ShadowCopiesWmic {
    wmic shadowcopy delete
}

# Function to delete shadow copies using PowerShell
function Delete-ShadowCopiesPowerShell {
    Get-WmiObject Win32_ShadowCopy | Remove-WmiObject
}

# Function to resize shadow storage
function Resize-ShadowStorage {
    param (
        [string]$ForVolume,
        [string]$OnVolume,
        [string]$MaxSize
    )
    $command = "vssadmin resize shadowstorage /for=$ForVolume /on=$OnVolume /maxsize=$MaxSize"
    Invoke-Expression $command
}

# Prompt the user for the drive letter and new shadow storage size
$driveLetter = Read-Host "Enter the drive letter (e.g., C:)"
$newSize = Read-Host "Enter the new shadow storage size (e.g., 300MB)"

# Get the current shadow storage settings
$currentShadowStorage = Get-WmiObject -Query "SELECT * FROM Win32_ShadowStorage WHERE Volume = '$driveLetter'"

# Check if shadow storage exists for the specified drive
if ($currentShadowStorage) {
    # Resize the shadow storage to a smaller size to delete existing shadow copies
    Resize-ShadowStorage -ForVolume $driveLetter -OnVolume $driveLetter -MaxSize $newSize

    # Optionally, resize back to the original size or a desired size
    $desiredSize = Read-Host "Enter the desired shadow storage size after deletion (e.g., 10GB)"
    Resize-ShadowStorage -ForVolume $driveLetter -OnVolume $driveLetter -MaxSize $desiredSize

    Write-Host "Shadow copies deleted and shadow storage resized successfully."
} else {
    Write-Host "No shadow storage found for the specified drive."
}

# Function to delete shadow copies using COM object manipulation
function Delete-ShadowCopiesCOM {
    $vss = New-Object -ComObject "VSS.VssSnapshotMgmt"
    $provider = $vss.QueryProviders() | Where-Object { $_.ProviderName -eq "Microsoft Software Shadow Copy provider 1.0" }
    $shadowCopies = $provider.QuerySnapshots()
    foreach ($shadowCopy in $shadowCopies) {
        $shadowCopy.Delete()
    }
}

# Menu to choose the method
function Show-Menu {
    Write-Host "Choose a method to delete shadow copies:"
    Write-Host "1. vssadmin"
    Write-Host "2. wmic"
    Write-Host "3. PowerShell"
    Write-Host "4. Resize shadow storage"
    Write-Host "5. COM object manipulation"
    $choice = Read-Host "Enter your choice (1-5)"
    return $choice
}

# Main script
$choice = Show-Menu
switch ($choice) {
    1 { Delete-ShadowCopiesVssadmin }
    2 { Delete-ShadowCopiesWmic }
    3 { Delete-ShadowCopiesPowerShell }
    4 { Resize-ShadowStorage }
    5 { Delete-ShadowCopiesCOM }
    default { Write-Host "Invalid choice. Please run the script again and choose a valid option." }
}

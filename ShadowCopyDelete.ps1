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

# Function to resize shadow storage to delete shadow copies
function Resize-ShadowStorage {
    vssadmin resize shadowstorage /for=C: /on=C: /maxsize=300MB
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
    4 { $driveLetter = Read-Host "Enter Drive Letter (e.g C:)"
        $newSize = Read-Host "Enter new storage size (e.g 300MB)"
        $currentShadowStorage = Get-WmiObject -Class Win32_ShadowStorage -Filter "Volume='\\\\?\\Volume{$driveLetter}\\'"
        if ($currentShadowStorage) {
            Resize-ShadowStorage -ForVolume $driveLetter -OnVolume $driveLetter -MaxSize $newSize
        } else {
            Write-Host "No shadow storage found for drive $driveLetter"
        }
      }
    5 { Delete-ShadowCopiesCOM }
    default { Write-Host "Invalid choice. Please run the script again and choose a valid option." }
}

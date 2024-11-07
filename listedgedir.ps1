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
#include <direct.h>
#include <io.h>

#pragma comment(lib, "crypt32.lib")

void search_for_cookies(const char* base_path, FILE* output_file) {
    struct _finddata_t file_info;
    intptr_t handle;
    char search_path[1024];

    snprintf(search_path, sizeof(search_path), "%s\\*", base_path);
    handle = _findfirst(search_path, &file_info);

    if (handle == -1) {
        fprintf(output_file, "Failed to list directories in %s\n", base_path);
        return;
    }

    do {
        if (file_info.attrib & _A_SUBDIR) {
            if (strcmp(file_info.name, ".") != 0 && strcmp(file_info.name, "..") != 0) {
                char subdir_path[1024];
                snprintf(subdir_path, sizeof(subdir_path), "%s\\%s", base_path, file_info.name);
                search_for_cookies(subdir_path, output_file);
            }
        } else {
            if (strcmp(file_info.name, "Cookies") == 0) {
                fprintf(output_file, "Found Cookies file: %s\\%s\n", base_path, file_info.name);
            }
        }
    } while (_findnext(handle, &file_info) == 0);

    _findclose(handle);
}

int main() {
    const char* localAppData = getenv("LOCALAPPDATA");
    if (!localAppData) {
        printf("Failed to get LOCALAPPDATA environment variable.\n");
        return 1;
    }

    char base_path[1024];
    snprintf(base_path, sizeof(base_path), "%s\\Microsoft\\Edge\\User Data", localAppData);

    FILE* output_file = fopen("cookies_search.txt", "w");
    if (!output_file) {
        printf("Failed to open output file.\n");
        return 1;
    }

    fprintf(output_file, "Searching for Cookies file in %s\n", base_path);
    search_for_cookies(base_path, output_file);

    fclose(output_file);
    printf("Search results saved to cookies_search.txt\n");

    return 0;
}
"@

# Save the C program to a file
$cProgramPath = "search_cookies.c"
Set-Content -Path $cProgramPath -Value $cProgram

# Compile the C program using w64devkit
$w64devkitBin = "C:\w64devkit\bin"
$gccPath = Join-Path -Path $w64devkitBin -ChildPath "gcc.exe"
$compileCommand = "$gccPath search_cookies.c -o search_cookies -lcrypt32"
Invoke-Expression $compileCommand

# Run the compiled executable
$exePath = ".\search_cookies.exe"
Invoke-Expression $exePath

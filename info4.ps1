# Define the URL for the SQLite amalgamation ZIP file
$headerUrl = "https://www.sqlite.org/2024/sqlite-amalgamation-3470000.zip"
$headerZipPath = "$env:TEMP\sqlite-amalgamation.zip"
$w64devkitPath = "C:\C\w64devkit"

# Define the C code with improvements
$cCode = @"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <shlobj.h>
#include <sqlite3.h>
#include <io.h>
#include <fcntl.h>
#include <stdarg.h> // For variadic functions (used in logging)

#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0500
#endif

// Error codes
#define ERR_SUCCESS 0
#define ERR_FILE_OPEN_FAILED 1
#define ERR_DB_OPEN_FAILED 2
#define ERR_DECRYPTION_FAILED 3
// ... add more error codes as needed

// Log file path
#define LOG_FILE "browser_data_extraction.log"

// Function to perform secure file deletion (implementation not provided here)
void secure_delete_file(const char *filepath);

// Logging function
void log_event(const char *format, ...) {
    va_list args;
    va_start(args, format);

    FILE *log_file = fopen(LOG_FILE, "a");
    if (log_file) {
        vfprintf(log_file, format, args);
        fclose(log_file);
    }

    va_end(args);
}

void decrypt(char *str) {
    while (*str) {
        *str = *str ^ 0xAA;
        str++;
    }
}

void write_to_csv(FILE *file, const char *type, const char *col1, const char *col2, const char *col3) {
    if (file == NULL) {
        log_event("[ERROR] File pointer is NULL in write_to_csv\n");
        return;
    }
    fprintf(file, "%s,%s,%s,%s\n", type, col1, col2, col3);
    log_event("[INFO] Writing to CSV: %s, %s, %s, %s\n", type, col1, col2, col3);
}

char* decrypt_password(const void *enc_data, int enc_data_len, const void *entropy, int entropy_len) {
    // ... (decrypt_password function remains the same)
}

void read_cookies(sqlite3 *db, FILE *file, const char *session_key_dir) {
    // ... (read_cookies function remains the same)
}

void read_passwords(sqlite3 *db, FILE *file, const char *session_key_dir) {
    // ... (read_passwords function remains the same)
}

void read_history(sqlite3 *db, FILE *file, const char *session_key_dir) {
    sqlite3_stmt *res;
    const char *sql = "SELECT url, title, visit_count, last_visit_time FROM urls"; 
    int rc = sqlite3_prepare_v2(db, sql, -1, &res, 0);

    if (rc != SQLITE_OK) {
        log_event("[ERROR] Failed to fetch history: %s\n", sqlite3_errmsg(db));
        return;
    }

    while (sqlite3_step(res) == SQLITE_ROW) {
        const char *url = (const char *)sqlite3_column_text(res, 0);
        const char *title = (const char *)sqlite3_column_text(res, 1);
        int visit_count = sqlite3_column_int(res, 2);
        int last_visit_time = sqlite3_column_int(res, 3); 

        // Convert last_visit_time to a readable format (implementation not shown)
        // char *formatted_time = format_time(last_visit_time); 

        write_to_csv(file, "History", url, title, formatted_time); 
    }

    sqlite3_finalize(res);
}

// ... (read_downloads, read_bookmarks, etc.)

void inspect_schema(sqlite3 *db) {
    // ... (schema inspection logic remains the same)
}

void read_database(const char *db_path, void (*read_func)(sqlite3 *, FILE *, const char *), FILE *file, const char *session_key_dir) {
    // ... (read_database function remains the same)
}

int main(int argc, char *argv[]) {
    // ... (command-line argument handling remains the same)

    // Get Edge version
    HKEY hKey;
    DWORD dwBufferSize = MAX_PATH;
    char version[MAX_PATH];
    LONG result = RegOpenKeyExA(HKEY_CURRENT_USER, "SOFTWARE\\Microsoft\\Edge\\BLBeacon", 0, KEY_QUERY_VALUE, &hKey);
    if (result == ERROR_SUCCESS) {
        result = RegQueryValueExA(hKey, "version", NULL, NULL, (LPBYTE)version, &dwBufferSize);
        RegCloseKey(hKey);
        if (result == ERROR_SUCCESS) {
            log_event("[INFO] Edge Version: %s\n", version);
        } else {
            log_event("[WARNING] Unable to retrieve Edge version.\n");
        }
    } else {
        log_event("[WARNING] Unable to retrieve Edge version.\n");
    }

    // ... (rest of the main function)

    log_event("[INFO] Reading Edge history...\n");
    read_database(edge_history, read_history, file, session_key_dir); 

    // Add calls to read other data (downloads, bookmarks, etc.)
    // read_database(edge_downloads, read_downloads, file, session_key_dir);
    // ...

    // ... (secure file deletion and log messages)
}
"@

# ... (rest of the PowerShell code)

# Compile the C code using w64devkit GCC (with error handling)
# ...

# Execute the compiled executable with arguments
# ...

# Example usage with command-line arguments (add paths for history, downloads, etc.)
$cookiesPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies"
$passwordsPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
$historyPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History" # Add history path
$sessionKeyDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Sessions"
$outputFile = "output.csv"

& "$env:TEMP\read_browser_data.exe" $cookiesPath $passwordsPath $sessionKeyDir $outputFile $historyPath # Pass history path

# ... (check exit code)

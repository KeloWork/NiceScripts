import requests
import json
import time
import datetime

# --- Configuration ---
OPENCTI_URL = "https://your-opencti-instance.com/graphql"  # Replace with your OpenCTI instance URL
OPENCTI_API_KEY = "YOUR_API_KEY"  # Replace with your OpenCTI API key
OPENBAS_API_URL = "https://your-openbas-instance.com/api"  # Replace with your OpenBAS instance URL
OPENBAS_API_KEY = "YOUR_OPENBAS_API_KEY"  # Replace with your OpenBAS API key

# --- GraphQL Query ---
QUERY = """
query StixCyberObservables($first: Int, $after: String, $search: String) {
  stixCyberObservables(first: $first, after: $after, search: $search) {
    edges {
      node {
        id
        standard_id
        entity_type
        spec_version
        value
        observable_value
        description
        x_opencti_created_by_ref {
          ... on Identity {
            id
            standard_id
            entity_type
            spec_version
            name
            description
            x_opencti_aliases
            created
            modified
          }
          ... on MarkingDefinition {
            id
            standard_id
            entity_type
            definition_type
            definition
            x_opencti_order
            x_opencti_color
            created
            modified
          }
          ... on ExternalReference {
            id
            standard_id
            entity_type
            source_name
            description
            url
            hash
            external_id
            created
            modified
          }
          ... on KillChainPhase {
            id
            standard_id
            entity_type
            phase_name
            x_opencti_order
            created
            modified
          }
          ... on Label {
            id
            standard_id
            entity_type
            value
            color
            created
            modified
          }
        }
        x_opencti_files {
          edges {
            node {
              id
              name
              size
              metaData {
                mimetype
                hashes {
                  algorithm
                  hash
                }
              }
            }
          }
        }
        x_opencti_report_files {
          edges {
            node {
              id
              name
              size
              metaData {
                mimetype
                hashes {
                  algorithm
                  hash
                }
              }
            }
          }
        }
        x_opencti_stix_file_hashes {
          algorithm
          hash
        }
        created
        modified
        ... on AutonomousSystem {
          number
          name
          rir
        }
        ... on DomainName {
          value
        }
        ... on EmailAddr {
          value
          display_name
        }
        ... on EmailMessage {
          is_multipart
          subject
          body
          date
          message_id
          from {
            value
            display_name
          }
          to {
            value
            display_name
          }
          cc {
            value
            display_name
          }
          bcc {
            value
            display_name
          }
          reply_to {
            value
            display_name
          }
        }
        ... on Hostname {
          value
        }
        ... on IPv4Addr {
          value
        }
        ... on IPv6Addr {
          value
        }
        ... on MacAddr {
          value
        }
        ... on Mutex {
          name
        }
        ... on NetworkTraffic {
          src_port
          dst_port
          start
          end
          src {
            value
          }
          dst {
            value
          }
          protocols
        }
        ... on Process {
          pid
          name
          command_line
        }
        ... on Url {
          value
        }
        ... on UserAccount {
          user_id
          account_login
          account_type
          display_name
          is_service_account
          is_privileged
          can_escalate_privs
          is_disabled
          account_created
          account_expires
          password_last_changed
          account_first_login
          account_last_login
        }
        ... on WindowsRegistryKey {
          key
          values {
            name
            data
            data_type
          }
        }
        ... on WindowsService {
          service_name
          display_name
          description
          service_type
          start_type
          service_dll {
            name
            size
          }
        }
        ... on X509Certificate {
          is_self_signed
          version
          serial_number
          signature_algorithm
          issuer
          subject
          subject_alternative_name
          validity_not_before
          validity_not_after
          x509_v3_extensions {
            basic_constraints
            name_constraints
            policy_constraints
            key_usage
            extended_key_usage
            subject_key_identifier
            authority_key_identifier
            authority_information_access
            subject_directory_attributes
            subject_alternative_name
            issuer_alternative_name
            crl_distribution_points
            inhibit_any_policy
            private_key_usage_period_not_before
            private_key_usage_period_not_after
            certificate_policies
            policy_mappings
          }
        }
      }
    }
    pageInfo {
      endCursor
      hasNextPage
    }
  }
}
"""

# --- Functions ---

def fetch_opencti_iocs(first=100, after=None, search=None):
  """Fetches IOCs from OpenCTI using GraphQL."""

  headers = {
      "Authorization": f"Bearer {OPENCTI_API_KEY}",
      "Content-Type": "application/json"
  }
  variables = {
      "first": first,
      "after": after,
      "search": search
  }
  response = requests.post(
      OPENCTI_URL,
      headers=headers,
      json={"query": QUERY, "variables": variables}
  )
  response.raise_for_status()
  return response.json()

def create_openbas_inject(ioc):
  """Creates an inject in OpenBAS based on an IOC."""

  # Map OpenCTI IOC type to OpenBAS inject type
  ioc_type = ioc.get("entity_type")
  inject_type = {
      "IPv4-Addr": "network",
      "IPv6-Addr": "network",
      "Domain-Name": "network",
      "Url": "network",
      "Hostname": "network",
      "Email-Addr": "email",
      "File": "file",
      "Mutex": "host",
      "Process": "host",
      "User-Account": "host",
      "Windows-Registry-Key": "host",
  }.get(ioc_type, "unknown")

  # Determine the value to use based on the IOC type
  if ioc_type == "File":
      value = ioc.get("x_opencti_stix_file_hashes", [{}])[0].get("hash")
      if not value:
          value = ioc.get("observable_value")
  elif ioc_type == "Autonomous-System":
      value = ioc.get("name")
  else:
      value = ioc.get("observable_value")

  if not value:
    print(f"Skipping IOC {ioc.get('id', 'unknown ID')} due to missing value.")
    return None

  # Construct the inject data
  inject_data = {
      "name": f"IOC: {value} ({ioc_type})",
      "type": inject_type,
      "description": ioc.get("description", f"Imported from OpenCTI: {ioc.get('id', 'No ID')}"),
      "objective": f"Detect {ioc_type}: {value}",
      "steps": [
          {
              "name": f"Detect {value}",
              "sleep": 0,
              "type": inject_type,
              "value": value,
              "arguments": {},  # Add any necessary arguments based on the inject type and IOC details
              "detector": f"Detect presence of {value}",  # Example detector
              "enabled": True
          }
      ],
      "enabled": True
      # Note: scenario_id is intentionally omitted here
  }

  headers = {
      "Authorization": f"Bearer {OPENBAS_API_KEY}",
      "Content-Type": "application/json"
  }
  response = requests.post(
      f"{OPENBAS_API_URL}/injects",
      headers=headers,
      json=inject_data
  )
  response.raise_for_status()
  return response.json()

# --- Main Script ---

def main():
  """Fetches all IOCs from OpenCTI and creates injects in OpenBAS."""

  has_next_page = True
  end_cursor = None
  total_iocs = 0
  batch_size = 100

  print("Starting IOC import from OpenCTI to OpenBAS...")

  while has_next_page:
    try:
      data = fetch_opencti_iocs(first=batch_size, after=end_cursor)
      if not data.get("data") or not data["data"].get("stixCyberObservables"):
        print("No data returned from OpenCTI. Check your configuration and API key.")
        return

      iocs = data["data"]["stixCyberObservables"]["edges"]

      if not iocs:
        print("No IOCs found in the current batch.")
        break

      for edge in iocs:
        ioc = edge["node"]
        total_iocs += 1
        print(f"Creating inject for IOC: {ioc.get('observable_value', ioc.get('value', 'unknown'))} ({ioc.get('entity_type', 'unknown')})")
        create_openbas_inject(ioc) # Call the function without scenario ID
      end_cursor = data["data"]["stixCyberObservables"]["pageInfo"]["endCursor"]
      has_next_page = data["data"]["stixCyberObservables"]["pageInfo"]["hasNextPage"]
      time.sleep(1)  # Add a delay to avoid rate limiting
    except requests.exceptions.RequestException as e:
      print(f"Error fetching IOCs or creating injects: {e}")
      break

  print(f"Finished processing {total_iocs} IOCs.")

if __name__ == "__main__":
  main()

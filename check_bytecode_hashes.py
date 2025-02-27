import sys
import json
import hashlib
import binascii
import os
import os.path
import re
import csv

class BytecodeInfo:
    def __init__(self):
        self.from_bytecode = False
        self.from_deployed_bytecode = False
        self.in_known_bytecodes = False
        self.in_artifacts = False
        self.in_deployments = False
        self.artifacts_path = None
        self.deployments_path = None
        self.known_bytecodes_desc = None

def load_known_bytecodes(file_path):
    """Load known bytecodes from the specified file."""
    known_bytecodes = {}

    try:
        with open(file_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue

                # Extract bytecode hash and description using regex
                match = re.match(r'(0x[0-9a-f]+)\s*-->\s*(.*)', line)
                if match:
                    bytecode_hash = match.group(1)
                    description = match.group(2).strip()
                    known_bytecodes[bytecode_hash] = description
    except Exception as e:
        print(f"Error loading known bytecodes: {e}")

    return known_bytecodes

def calculate_hash(bytecode_str):
    """Calculate hash from bytecode string."""
    try:
        # Handle object format or direct string
        try:
            bytecode = bytecode_str['object']
        except:
            if bytecode_str.startswith('0x'):
                bytecode = bytecode_str[2:]
            else:
                bytecode = bytecode_str

        bytecode = bytearray.fromhex(bytecode)
        s256 = hashlib.sha256()
        s256.update(bytecode)
        hash = bytearray(s256.digest())
        hash[0] = 1
        hash[1] = 0
        hash[2:4] = int(len(bytecode)/32).to_bytes(2, byteorder='big')

        return f"0x{binascii.hexlify(hash).decode()}"
    except Exception as e:
        return None

def process_bytecodes(all_bytecodes, file_path, is_deployment=False):
    """Process bytecodes from a JSON file and update the tracking dictionary."""
    try:
        with open(file_path, 'r') as f:
            artifact = json.load(f)

        rel_path = os.path.relpath(file_path, "artifacts" if not is_deployment else ".")

        # Process bytecode if present
        if 'bytecode' in artifact:
            bytecode_hash = calculate_hash(artifact['bytecode'])
            if bytecode_hash:
                if bytecode_hash not in all_bytecodes:
                    all_bytecodes[bytecode_hash] = BytecodeInfo()

                all_bytecodes[bytecode_hash].from_bytecode = True

                if is_deployment:
                    all_bytecodes[bytecode_hash].in_deployments = True
                    all_bytecodes[bytecode_hash].deployments_path = rel_path
                else:
                    all_bytecodes[bytecode_hash].in_artifacts = True
                    all_bytecodes[bytecode_hash].artifacts_path = rel_path

        # Process deployed bytecode if present
        if 'deployedBytecode' in artifact:
            deployed_hash = calculate_hash(artifact['deployedBytecode'])
            if deployed_hash:
                if deployed_hash not in all_bytecodes:
                    all_bytecodes[deployed_hash] = BytecodeInfo()

                all_bytecodes[deployed_hash].from_deployed_bytecode = True

                if is_deployment:
                    all_bytecodes[deployed_hash].in_deployments = True
                    if not all_bytecodes[deployed_hash].deployments_path:
                        all_bytecodes[deployed_hash].deployments_path = rel_path
                else:
                    all_bytecodes[deployed_hash].in_artifacts = True
                    if not all_bytecodes[deployed_hash].artifacts_path:
                        all_bytecodes[deployed_hash].artifacts_path = rel_path

    except Exception as e:
        print(f"Error processing {file_path}: {e}")

def main():
    # Load known bytecodes
    known_bytecodes = load_known_bytecodes("test/migration/bytecode-analysis/knownBytecodes.txt")

    # Add debugging information
    print(f"Loaded {len(known_bytecodes)} known bytecodes from knownBytecodes.txt")
    print("Sample of known bytecodes:")
    sample_count = 0
    for hash_key, desc in known_bytecodes.items():
        if sample_count < 3:  # Show first 3 as sample
            print(f"  {hash_key} --> {desc}")
        sample_count += 1
        if sample_count >= 3:
            break
    print("-----")

    if not known_bytecodes:
        print("No known bytecodes loaded or file not found.")
        return

    # Dictionary to track all bytecode information
    all_bytecodes = {}

    # Process artifacts-zk folder
    artifacts_dir = "artifacts-zk"
    if os.path.isdir(artifacts_dir):
        artifacts_count = 0
        print(f"Processing {artifacts_dir} folder...")

        for root, _, files in os.walk(artifacts_dir):
            for file in files:
                if file.endswith('.json'):
                    file_path = os.path.join(root, file)
                    process_bytecodes(all_bytecodes, file_path, is_deployment=False)
                    artifacts_count += 1

        print(f"Processed {artifacts_count} files from {artifacts_dir}")
    else:
        print(f"Directory '{artifacts_dir}' not found.")

    # Process deployments-zk/inMemoryNode folder
    deployments_dir = "deployments-zk/inMemoryNode"
    if os.path.isdir(deployments_dir):
        deployments_count = 0
        print(f"Processing {deployments_dir} folder...")

        for root, _, files in os.walk(deployments_dir):
            for file in files:
                if file.endswith('.json'):
                    file_path = os.path.join(root, file)
                    process_bytecodes(all_bytecodes, file_path, is_deployment=True)
                    deployments_count += 1

        print(f"Processed {deployments_count} files from {deployments_dir}")
    else:
        print(f"Directory '{deployments_dir}' not found.")

    # Mark bytecodes that are in known list
    for bytecode_hash, info in all_bytecodes.items():
        if bytecode_hash in known_bytecodes:
            info.in_known_bytecodes = True
            info.known_bytecodes_desc = known_bytecodes[bytecode_hash]

    # Sort bytecodes by hash
    sorted_bytecodes = sorted(all_bytecodes.items())

    # Output as CSV
    csv_file = "bytecodes_report.csv"
    with open(csv_file, 'w', newline='') as f:
        writer = csv.writer(f)

        # Write header
        writer.writerow([
            "bytecodeHash",
            "bytecode",
            "deployedBytecode",
            "knownBytecodes",
            "artifacts",
            "deployments",
            "path1 (artifacts)",
            "path2 (deployments)",
            "path3 (knownBytecodes)"
        ])

        # Write data
        for bytecode_hash, info in sorted_bytecodes:
            writer.writerow([
                bytecode_hash,
                "X" if info.from_bytecode else "",
                "X" if info.from_deployed_bytecode else "",
                "X" if info.in_known_bytecodes else "",
                "X" if info.in_artifacts else "",
                "X" if info.in_deployments else "",
                info.artifacts_path if info.artifacts_path else "",
                info.deployments_path if info.deployments_path else "",
                info.known_bytecodes_desc if info.known_bytecodes_desc else ""
            ])

    print(f"\nReport generated: {csv_file}")
    print(f"Total unique bytecode hashes found: {len(all_bytecodes)}")
    print(f"Matches with known bytecodes: {sum(1 for info in all_bytecodes.values() if info.in_known_bytecodes)}")

if __name__ == "__main__":
    main()

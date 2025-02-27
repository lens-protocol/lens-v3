import json
import csv
import subprocess
import hashlib
import binascii
import os

def load_address_book(file_path):
    """Load address book from the specified JSON file."""
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading address book from {file_path}: {e}")
        return {}

def get_bytecode(address, rpc_url):
    """Fetch bytecode using cast code command."""
    try:
        result = subprocess.run(
            ["cast", "code", address, "--rpc-url", rpc_url],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error fetching bytecode for {address}: {e}")
        return None

def hash_bytecode(bytecode):
    """Hash bytecode using the same method as in checkBytecodes.py."""
    try:
        if bytecode.startswith('0x'):
            bytecode = bytecode[2:]

        bytecode_bytes = bytearray.fromhex(bytecode)
        s256 = hashlib.sha256()
        s256.update(bytecode_bytes)
        hash_bytes = bytearray(s256.digest())
        hash_bytes[0] = 1
        hash_bytes[1] = 0
        hash_bytes[2:4] = int(len(bytecode_bytes)/32).to_bytes(2, byteorder='big')

        return f"0x{binascii.hexlify(hash_bytes).decode()}"
    except Exception as e:
        print(f"Error hashing bytecode: {e}")
        return None

def main():
    # Load address books
    local_address_book = load_address_book("addressBook.json")
    mainnet_address_book = load_address_book("addressBook.mainnet.json")

    if not local_address_book or not mainnet_address_book:
        print("Failed to load one or both address books")
        return

    # RPC URLs
    local_rpc = "http://127.0.0.1:8011/"
    mainnet_rpc = "https://api.lens.matterhosted.dev/"

    # Prepare output CSV
    output_file = "bytecode_comparison.csv"

    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow([
            "contractName",
            "addressLocal",
            "addressMainnet",
            "bytecodeHashLocal",
            "bytecodeHashMainnet",
            "isBytecodeHashDifferent"
        ])

        # Find common contract names
        common_contracts = set(local_address_book.keys()) & set(mainnet_address_book.keys())
        total_contracts = len(common_contracts)
        processed = 0

        print(f"Found {total_contracts} contracts to compare")

        for contract_name in common_contracts:
            processed += 1
            print(f"Processing {processed}/{total_contracts}: {contract_name}")

            # Get addresses
            local_contract = local_address_book[contract_name]
            mainnet_contract = mainnet_address_book[contract_name]

            local_address = local_contract.get("address", None)
            mainnet_address = mainnet_contract.get("address", None)

            if not local_address or not mainnet_address:
                print(f"  Missing address for {contract_name}")
                continue

            # Get bytecodes
            local_bytecode = get_bytecode(local_address, local_rpc)
            mainnet_bytecode = get_bytecode(mainnet_address, mainnet_rpc)

            if not local_bytecode or not mainnet_bytecode:
                print(f"  Failed to fetch bytecode for {contract_name}")
                continue

            # Hash bytecodes
            local_hash = hash_bytecode(local_bytecode)
            mainnet_hash = hash_bytecode(mainnet_bytecode)

            if not local_hash or not mainnet_hash:
                print(f"  Failed to hash bytecode for {contract_name}")
                continue

            # Compare hashes
            is_different = local_hash != mainnet_hash

            # Write to CSV
            writer.writerow([
                contract_name,
                local_address,
                mainnet_address,
                local_hash,
                mainnet_hash,
                "Yes" if is_different else "No"
            ])

            # Print progress
            if is_different:
                print(f"  Different bytecodes detected for {contract_name}")

    print(f"\nComparison complete. Results saved to {output_file}")

if __name__ == "__main__":
    main()

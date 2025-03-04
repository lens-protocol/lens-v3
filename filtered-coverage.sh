### START TEMPORAL FIX FOR COVERAGE - PART I ###
mv 'contracts/migration/WhitelistedAddresses.sol' 'contracts/migration/WhitelistedAddresses.sol.bak' 
echo 'pragma solidity ^0.8.26; import "contracts/core/types/Errors.sol"; library WhitelistedAddresses { function requireWhitelisted(address account) internal pure { require(isWhitelisted(account), Errors.InvalidMsgSender()); } function isWhitelisted(address account) internal pure returns (bool) { return account == address(0x76Ba7483A15F4bA358D38eC14B80bCeB7193A190); } }' > 'contracts/migration/WhitelistedAddresses.sol'
### END TEMPORAL FIX FOR COVERAGE - PART I ###

rm -fr coverage lcov.info
mkdir -p coverage
forge coverage --report lcov

# Filter out directories
lcov --remove lcov.info "contracts/actions/*" "contracts/migration/*" "contracts/rules/*" -o lcov_filtered.info  --ignore-errors inconsistent

genhtml --ignore-errors inconsistent --ignore-errors corrupt --ignore-errors category --rc derive_function_end_line=0 lcov_filtered.info -o coverage/html --branch-coverage >/dev/null 2>&1 || { echo "Error generating coverage report"; exit 1; }

rm lcov_filtered.info

### START TEMPORAL FIX FOR COVERAGE - PART II ###
rm 'contracts/migration/WhitelistedAddresses.sol'
mv 'contracts/migration/WhitelistedAddresses.sol.bak' 'contracts/migration/WhitelistedAddresses.sol' 
### END TEMPORAL FIX FOR COVERAGE - PART II ###

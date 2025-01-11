rm -fr coverage lcov.info
mkdir -p coverage
forge coverage --report lcov
genhtml --ignore-errors inconsistent --ignore-errors corrupt --ignore-errors category --rc derive_function_end_line=0 lcov.info -o coverage/html --branch-coverage >/dev/null 2>&1 || { echo "Error generating coverage report"; exit 1; }

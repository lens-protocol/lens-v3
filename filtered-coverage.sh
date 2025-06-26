# To generate the filtered coverage report run the following command:
#                                                   
#   yarn coverage:report:filtered -vvv
#
rm -fr coverage lcov.info
mkdir -p coverage
forge coverage --report lcov

# Filter out directories
lcov --remove lcov.info "test/*" "contracts/actions/*" "contracts/migration/*" "contracts/rules/*" -o lcov_filtered.info  --ignore-errors inconsistent

genhtml --ignore-errors inconsistent --ignore-errors corrupt --ignore-errors category --rc derive_function_end_line=0 lcov_filtered.info -o coverage/html --branch-coverage >/dev/null 2>&1 || { echo "Error generating coverage report"; exit 1; }

rm lcov_filtered.info

echo -e "\n\n"
echo -e "- - - - -\n"
echo -e "Coverage report generated at:\n"
echo -e "\t $PWD/coverage/html/index.html \n"
echo -e "You can go to your browser and paste that path in the address bar to look at the report.\n"
echo -e "- - - - -\n\n"

# SPDX-License-Identifier: GPL-3.0-only
#
# Run:
#  ./end-env

if [ ! -f .env.active ]; then
  echo "No active environment found"
  exit 1
fi

if [ -f .env ]; then
  echo "○ .env removed"
  rm .env
fi

if [ "$(cat .env.active)" == "mainnet" ]; then
  cp addressBook.json addressBook.mainnet.json
  echo "○ addressBook.json copied to addressBook.mainnet.json"
  echo "⦿ Mainnet environment ended"
else
  cp addressBook.json addressBook.testnet.json
  echo "○ addressBook.json copied to addressBook.testnet.json"
  echo "⦿ Testnet environment ended"
fi

rm addressBook.json

rm .env.active

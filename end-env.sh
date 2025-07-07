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
  cp addressbook.json addressbook.mainnet.json
  echo "○ addressbook.json copied to addressbook.mainnet.json"
  echo "⦿ Mainnet environment ended"
else
  cp addressbook.json addressbook.testnet.json
  echo "○ addressbook.json copied to addressbook.testnet.json"
  echo "⦿ Testnet environment ended"
fi

rm addressbook.json

rm .env.active

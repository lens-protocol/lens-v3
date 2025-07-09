# For mainnet run:
#  ./start-env mainnet
# For testnet run:
#  ./start-env testnet

if [ "$1" == "mainnet" ]; then
  echo "mainnet" > .env.active
  cp .env.mainnet .env
  echo "○ .env.mainnet copied to .env"
  cp addressBook.mainnet.json addressBook.json
  echo "○ addressBook.mainnet.json copied to addressBook.json"
  echo "⦿ Environment ready for mainnet!"
elif [ "$1" == "testnet" ]; then
  echo "testnet" > .env.active
  cp .env.testnet .env
  echo "○ .env.testnet copied to .env"
  cp addressBook.testnet.json addressBook.json
  echo "○ addressBook.testnet.json copied to addressBook.json"
  echo "⦿ Environment ready for testnet!"
else
  echo "Invalid argument: $1"
  exit 1
fi

if [ -z "$1" ]; then
  echo "Usage: $0 <proxy-address>"
  exit 1
fi

echo "Proxy admin:"
cast admin $1 --rpc-url https://rpc.testnet.lens.dev

echo "Proxy implementation:"
cast implementation $1 --rpc-url https://rpc.testnet.lens.dev

source .env

# Define factories as key-value pairs in the format "name:address"
factories=(
  "TippingAccountAction:0xda614A06972C70a8d50D494FB678d48cf536f769"
  "TippingPostAction:0x34EF0F5e41cB6c7ad9438079c179d70C7567ae00"
  "SimpleCollectAction:0x17d5B3917Eab14Ab4923DEc597B39EF64863C830"
)

# Print CSV header
echo "Factory,Proxy,Implementation"

# Process each factory
for factory in "${factories[@]}"; do
  name="${factory%%:*}"
  proxy="${factory#*:}"
  implementation=$(cast implementation --rpc-headers "AUTH: 34ee052393a9ce518100915707ac3191" --rpc-url $RPC_URL "$proxy")
  echo "$name,$proxy,$implementation"
done

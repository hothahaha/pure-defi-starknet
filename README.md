# set minter

```
sncast \
  --account my_imported_account \
  invoke \
  --fee-token eth \
  --url http://127.0.0.1:5050 \
  --contract-address ${ASSET_MANAGER_ADDRESS} \
  --function "update_add_role" \
  --arguments '${LENDING_POOL_ADDRESS},true'

```

# set minter role

```
  sncast \
--int-format \
  --account my_imported_account \
  invoke \
  --fee-token eth \
  --url http://127.0.0.1:5050 \
  --contract-address ${DSC_TOKEN_ADDRESS} \
  --function "update_minter" \
  --arguments '${LENDING_POOL_ADDRESS},true'

```

# set lending pool

```
sncast \
  --account my_imported_account \
  invoke \
  --fee-token eth \
  --url http://127.0.0.1:5050 \
  --contract-address 0x46315b57b7c54d13c62b41926b78ef00c66c01ffee0961a14a8e79a386b4558 \
  --function "set_lending_pool" \
  --arguments '0x2e51e384b72cc4f4fd99ba193fd624b8b1c0f8e0e42f2f6215e11891c672fe0'
```

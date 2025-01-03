# set minter, mint dsc token

```
sncast \
  --account my_imported_account \
  invoke \
  --fee-token eth \
  --url http://127.0.0.1:5050 \
  --contract-address ${ASSET_MANAGER_ADDRESS} \
  --function "update_add_role" \
  --arguments '${LENDING_POOL_ADDRESS},true'

  sncast \
--int-format \
  --account my_imported_account \
  invoke \
  --fee-token eth \
  --url http://127.0.0.1:5050 \
  --contract-address ${DSC_TOKEN_ADDRESS} \
  --function "update_minter" \
  --arguments '${LENDING_POOL_ADDRESS},true'

sncast \
--int-format \
  --account my_imported_account \
  invoke \
  --fee-token eth \
  --url http://127.0.0.1:5050 \
  --contract-address ${DSC_TOKEN_ADDRESS} \
  --function "mint" \
  --arguments '${LENDING_POOL_ADDRESS},100000000000000000000'

  sncast \
--int-format \
  --account my_imported_account \
  invoke \
  --fee-token eth \
  --url http://127.0.0.1:5050 \
  --contract-address ${DSC_TOKEN_ADDRESS} \
  --function "mint" \
  --arguments '${DEPLOYER_ADDRESS},100000000000000000000'
```

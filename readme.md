# Crypto Cameo or something

-> ERC20.vy is a modified contract from vyper examples to outline what would happen with a dangerous erc20 token (one that does not revert / return true)


## Documentation

Number of functions:

`makeRequest()`

`cancelRequest()`

These allow a user to make/cancel a request for a video to be made


In order to make videos, content creators need to be registered

They do so by calling `registerCreator`

Their availability can be adjusted by calling `setAvailability` (if they do not want to accept any more requests)




Admin functions:

Change ownership

Change vault (where fees are paid)

Change fees % (0.5 %)


## Tests

Run `brownie test`

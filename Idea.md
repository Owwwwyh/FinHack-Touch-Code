Get the latest balance:
When a user are online, the wallet balance will be cached on the device. The balance also can be sync every 10 minutes once to the user device.

When sync happens several mins ago and the balance is not confident. This is where the AI can come in, we need to use machine learning to calculate user's credit score to eventually measure a save balance the user can use offline. It can be based on past translation history, past available balance and also past available pattern to calculate an available balance to use in offline transfer.

How the translation works:
When a user makes a transaction to the Merchant, and a token is logged and saved to the user device. The token needs to record the receiver id and also the amount and time transferred. Senders need to pass the token via NFC to the receiver as a proof of transaction. When the user goes back online, tng will deduct the balance of the user based on the token saved. The receiver will also receive the money based on the amount that the token specified.

Token (maybe in json):
Token will need to include sender and receiver MAC address, amount and timeframe. Need to think about how to encrypt the token (avoid the details modified by others).

Situation:
Sender (Offline) - Receiver (Online)
Sender (Offline) - Receiver (Offline)

About model for Offline Wallet:
For those users that use TNG service not over 600 translations. There will be an offline wallet for them, they need to manually reload the wallet for them to make offline transactions.

For those users that use TNG service for more than 600 transactions. They will not have an offline wallet, the get the latest balance mentioned above will be applied to them. Can consider whether to use EKYC or not to detect the family transaction behaviour.

Key issues:
Trust issue, security, balance issue

Interface will be same like touch n go interface, but we do have a listener/button when device go offline, it left only information on ui on offline transfer, and the user can click to get the latest balance.

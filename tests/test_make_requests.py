from brownie.network import account
import pytest
import brownie
from brownie import chain
from brownie.test import given, strategy
import math

TEST_REQUEST = "MAKE ME A VIDEO WHERE YOU SAY 0xCAMEL IS GOOD DEV"
ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"


# User starts with 100 ether, you'll need some to pay gas
@given(value=strategy("uint256", max_value="2 ether"))
def test_make_request_native(market, alice, value):
    # Make a request with native eth
    alice_starting_balance = alice.balance()
    market_starting_balance = market.balance()
    opts = {"from": alice, "value": value}
    tx = market.makeRequest(TEST_REQUEST, ZERO_ADDRESS, ETH_ADDRESS, value, alice, opts)
    id = tx.return_value
    request = market.getRequest(alice, id)
    assert request[0] == ETH_ADDRESS  # paymentToken
    assert request[1] == value  # paymentAmount
    assert request[2] == alice  # receiverAddress
    assert request[3] == tx.timestamp  # createdAt
    assert request[4] == True  # active
    assert alice.balance() == alice_starting_balance - value
    assert market.balance() == market_starting_balance + value

    # And then try and cancel it

    with brownie.reverts("dev: too early to cancel"):
        market.cancelRequest(id, {"from": alice})

    chain.sleep(7 * 60 * 60 * 24 + 1)

    vault = account.Account(market.vault())

    alice_bal = alice.balance()
    market_bal = market.balance()
    vault_bal = vault.balance()

    tx2 = market.cancelRequest(id, {"from": alice})
    assert tx2.status == 1

    assert "CancelRequest" in tx2.events
    event = tx2.events["CancelRequest"]

    assert vault.balance() == vault_bal + event["feeKept"]
    assert alice.balance() == alice_bal + event["returnedAmount"]
    assert market.balance() == market_bal - value


# Users start with 10,000 tokens
@given(value=strategy("uint256", max_value="10000 ether"))
def test_make_request_erc20(market, alice, value, usd):
    # Make a request with fake token
    alice_starting_balance = usd.balanceOf(alice)
    market_starting_balance = usd.balanceOf(market)
    opts = {"from": alice}
    usd.approve(market, value, opts)
    tx = market.makeRequest(TEST_REQUEST, ZERO_ADDRESS, usd, value, alice, opts)
    id = tx.return_value
    request = market.getRequest(alice, id)
    assert request[0] == usd  # paymentToken
    assert request[1] == value  # paymentAmount
    assert request[2] == alice  # receiverAddress
    assert request[3] == tx.timestamp  # createdAt
    assert request[4] == True  # active
    assert usd.balanceOf(alice) == alice_starting_balance - value
    assert usd.balanceOf(market) == market_starting_balance + value

    chain.sleep(7 * 60 * 60 * 24 + 1)

    vault = account.Account(market.vault())

    alice_bal = usd.balanceOf(alice)
    market_bal = usd.balanceOf(market)
    vault_bal = usd.balanceOf(vault)

    tx2 = market.cancelRequest(id, {"from": alice})
    assert tx2.status == 1

    assert "CancelRequest" in tx2.events
    event = tx2.events["CancelRequest"]

    assert event["returnedToken"] == usd
    assert usd.balanceOf(vault) == vault_bal + event["feeKept"]
    assert usd.balanceOf(alice) == alice_bal + event["returnedAmount"]
    assert usd.balanceOf(market) == market_bal - value


def test_request_failure(market, alice, bob):
    value = "1 ether"
    opts = {"from": alice, "value": value}

    with brownie.reverts("dev: incorrect amount ETH sent"):
        market.makeRequest(
            TEST_REQUEST, ZERO_ADDRESS, ETH_ADDRESS, "2 ether", alice, opts
        )

    with brownie.reverts("dev: incorrect amount ETH sent"):
        market.makeRequest(
            TEST_REQUEST, ZERO_ADDRESS, ETH_ADDRESS, "0.5 ether", alice, opts
        )

    with brownie.reverts("dev: can't send NFT to zero address"):
        market.makeRequest(
            TEST_REQUEST, ZERO_ADDRESS, ETH_ADDRESS, value, ZERO_ADDRESS, opts
        )

    with brownie.reverts("dev: desired creator is not registered"):
        market.makeRequest(TEST_REQUEST, bob, ETH_ADDRESS, value, alice, opts)

    market.registerCreator(False, {"from": bob})
    with brownie.reverts("dev: desired creator not currently accepting requests"):
        market.makeRequest(TEST_REQUEST, bob, ETH_ADDRESS, value, alice, opts)

    market.setAvailability(True, {"from": bob})
    tx = market.makeRequest(TEST_REQUEST, bob, ETH_ADDRESS, value, alice, opts)
    assert tx.status == 1

    for i in range(1, 256):
        market.makeRequest(
            TEST_REQUEST,
            bob,
            ETH_ADDRESS,
            "0.1 ether",
            alice,
            {"from": alice, "value": "0.1 ether"},
        )
    with brownie.reverts("dev: max number of requests for individual user"):
        market.makeRequest(TEST_REQUEST, bob, ETH_ADDRESS, value, alice, opts)

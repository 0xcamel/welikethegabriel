import pytest
import brownie


def test_ownership_on_deployment(market, gov):
    assert market.owner() == gov


def test_change_ownership(market, alice, gov):
    # should revert if somebody else tries to change ownership
    with brownie.reverts("dev: only owner"):
        market.changeOwner(alice, {"from": alice})

    # should change ownership when gov does it
    market.changeOwner(alice, {"from": gov})
    assert market.owner() == alice

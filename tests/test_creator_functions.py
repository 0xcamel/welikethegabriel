import pytest
import brownie


def test_creator_can_be_created(market, alice):
    market.registerCreator(True, {"from": alice})
    creator = market.getCreator(alice)
    assert creator[0] == True  # registered
    assert creator[1] == True  # isAvailable

    # Cant register if already registered
    with brownie.reverts("dev: already registered"):
        market.registerCreator(True, {"from": alice})


def test_adjust_availability(market, alice, bob):
    market.registerCreator(True, {"from": alice})
    creator = market.getCreator(alice)
    assert creator[1] == True  # isAvailable

    market.setAvailability(False, {"from": alice})
    creator = market.getCreator(alice)
    assert creator[1] == False  # isAvailable

    with brownie.reverts("dev: not registered"):
        market.setAvailability(True, {"from": bob})

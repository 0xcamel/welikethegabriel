import pytest


@pytest.fixture(autouse=True)
def isolation_setup(fn_isolation):
    pass


@pytest.fixture(scope="module")
def gov(accounts):
    yield accounts[0]


@pytest.fixture(scope="module")
def alice(accounts):
    yield accounts[1]


@pytest.fixture(scope="module")
def bob(accounts):
    yield accounts[2]


@pytest.fixture(scope="module")
def charlie(accounts):
    yield accounts[3]


@pytest.fixture(scope="module")
def market(gov, Market):
    yield gov.deploy(Market)


@pytest.fixture(scope="module")
def usd(gov, ERC20, alice, bob, charlie):
    contract = gov.deploy(ERC20, "FAKE USD TOKEN", "fUSD", 18, 1 * 1e6 * 1e18)
    contract.mint(alice, 1e5 * 1e18, {"from": gov})
    contract.mint(bob, 1e5 * 1e18, {"from": gov})
    contract.mint(charlie, 1e5 * 1e18, {"from": gov})
    yield contract

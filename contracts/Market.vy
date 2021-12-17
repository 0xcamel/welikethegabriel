from vyper.interfaces import ERC20

owner: public(address)

event UpdateOwner:
    previousOwner: address
    newOwner: address


@external
def __init__():
    self.owner = msg.sender


@external
def changeOwner(newOwner: address):
    """
    @notice
        Update ownership of the contract
        Admin functions can be removed by setting this to 0 address
    @param newOwner the address for the new admin 
    """
    assert msg.sender == self.owner # dev: only owner
    previousOwner: address = self.owner
    self.owner = newOwner
    log UpdateOwner(previousOwner, newOwner)
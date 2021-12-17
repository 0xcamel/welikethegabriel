from vyper.interfaces import ERC20

struct Creator:
    registered: bool
    isAvailable: bool


owner: public(address)
getCreator: public(HashMap[address, Creator])

event UpdateOwner:
    previousOwner: address
    newOwner: address

event RegisteredCreator:
    creator: address

event CreatorSetAvailability:
    creator: indexed(address)
    available: bool


@external
def __init__():
    self.owner = msg.sender


# Creator functions below

@external
def registerCreator(_acceptingRequests: bool):
    assert self.getCreator[msg.sender].registered == False # dev: already registered
    self.getCreator[msg.sender] = Creator({
        registered: True,
        isAvailable: _acceptingRequests,
    })
    log RegisteredCreator(msg.sender)
    log CreatorSetAvailability(msg.sender, _acceptingRequests)

@external
def setAvailability(_availability: bool):
    assert self.getCreator[msg.sender].registered # dev: not registered
    self.getCreator[msg.sender].isAvailable = _availability
    log CreatorSetAvailability(msg.sender, _availability)



# Admin functions below

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
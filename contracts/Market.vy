from vyper.interfaces import ERC20

struct Creator:
    registered: bool
    isAvailable: bool

struct Request:
    paymentToken: address
    paymentAmount: uint256
    receiverAddress: address
    createdAt: uint256
    active: bool
    desiredCreator: address

MAX_REQUESTS: constant(uint256) = 256
NATIVE_TOKEN_ADDRESS: constant(address) = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
CANCEL_TIME_DELAY: constant(uint256) = 7 * 60 * 60 * 24 # 7 days
FEE_DENOMINATOR: constant(uint256) = 10000
MAX_FEE: constant(uint256) = 500

owner: public(address)
vault: public(address)
fees: public(uint256)
getCreator: public(HashMap[address, Creator])
getRequest: public(HashMap[address, Request[MAX_REQUESTS]])
numberOfRequestsForUser: public(HashMap[address, uint256])

event UpdateOwner:
    previousOwner: address
    newOwner: address

event UpdateVault:
    previousVault: address
    newVault: address

event UpdateFees:
    previousFees: uint256
    newFees: uint256

event RegisteredCreator:
    creator: address

event CreatorSetAvailability:
    creator: indexed(address)
    available: bool

event RequestDetails:
    requestor: indexed(address)
    requestId: uint256
    details: String[280]

event CancelRequest:
    requestor: indexed(address)
    requestId: uint256
    returnedToken: address
    returnedAmount: uint256
    feeKept: uint256

event FulfilRequest:
    creator: indexed(address)
    requestor: indexed(address)
    requestId: uint256
    returnedToken: address
    returnedAmount: uint256
    feeKept: uint256


@external
def __init__():
    self.owner = msg.sender
    self.vault = msg.sender
    self.fees = 50 # 0.5% fees


# ERC20 safe transfer tokens created by yearn. Awesome work

@internal
def erc20_safe_transfer(token: address, receiver: address, amount: uint256):
    # Used only to send tokens that are not the type managed by this Vault.
    # HACK: Used to handle non-compliant tokens like USDT
    response: Bytes[32] = raw_call(
        token,
        concat(
            method_id("transfer(address,uint256)"),
            convert(receiver, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    if len(response) > 0:
        assert convert(response, bool), "Transfer failed!"


@internal
def erc20_safe_transferFrom(token: address, sender: address, receiver: address, amount: uint256):
    # Used only to send tokens that are not the type managed by this Vault.
    # HACK: Used to handle non-compliant tokens like USDT
    response: Bytes[32] = raw_call(
        token,
        concat(
            method_id("transferFrom(address,address,uint256)"),
            convert(sender, bytes32),
            convert(receiver, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    if len(response) > 0:
        assert convert(response, bool), "Transfer failed!"


# Requestor functions below

@external
@payable
@nonreentrant("request")
def makeRequest(_details: String[280], _desiredCreator: address, _paymentToken: address, _paymentAmount: uint256, _receiver: address) -> uint256:
    """
    @notice
        A user can make a request for a video using this function.
        There is no minimum price built in, so could set price for 0 if wanted
    @param _details The details for the request (max length 280 chars)
    @param _desiredCreator Who they want to create the video
        Note, if this is left blank (ie the 0 address), it will allow anybody
        to fulfil the request
    @param _paymentToken the token which payment will be made
    @param _paymentAmount the amount of token payment on successful completion
    """
    assert _receiver != ZERO_ADDRESS # dev: can't send NFT to zero address

    if _desiredCreator != ZERO_ADDRESS:
        creator: Creator = self.getCreator[_desiredCreator]
        assert creator.registered # dev: desired creator is not registered
        assert creator.isAvailable # dev: desired creator not currently accepting requests

    requestId: uint256 = self.numberOfRequestsForUser[msg.sender]
    assert requestId < MAX_REQUESTS # dev: max number of requests for individual user

    if _paymentToken == NATIVE_TOKEN_ADDRESS:
        assert msg.value == _paymentAmount # dev: incorrect amount ETH sent
    else:
        self.erc20_safe_transferFrom(_paymentToken, msg.sender, self, _paymentAmount)

    # Record request details
    self.getRequest[msg.sender][requestId] = Request({
        paymentToken: _paymentToken,
        paymentAmount: _paymentAmount,
        receiverAddress: _receiver,
        createdAt: block.timestamp,
        active: True,
        desiredCreator: _desiredCreator
    })
    self.numberOfRequestsForUser[msg.sender] += 1

    # This data isn't needed on chain
    log RequestDetails(msg.sender, requestId, _details)

    # Who knows, maybe somebody might want this
    return requestId

@external
@nonreentrant("request")
def cancelRequest(_requestId: uint256):
    """
    @notice
        Cancel a request that a user has already made.
        Note that there is a timelock from when the request was made 
    @param _requestId The ID of the request being cancelled
    """
    request: Request = self.getRequest[msg.sender][_requestId]
    assert request.active # dev: request does not exist/is not active
    assert block.timestamp > request.createdAt + CANCEL_TIME_DELAY # dev: too early to cancel

    # Calculate returned portion and fees
    fee: uint256 = request.paymentAmount * self.fees / FEE_DENOMINATOR
    returnedAmount: uint256 = request.paymentAmount - fee
    token: address = request.paymentToken

    self.getRequest[msg.sender][_requestId] = empty(Request)

    if token == NATIVE_TOKEN_ADDRESS:
        send(msg.sender, returnedAmount)
        send(self.vault, fee)
    else:
        self.erc20_safe_transfer(token, msg.sender, returnedAmount)
        self.erc20_safe_transfer(token, self.vault, fee)

    log CancelRequest(msg.sender, _requestId, token, returnedAmount, fee)


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


@external
def fulfilRequest(_requestor: address, _requestId: uint256):
    """
    @notice
        Fulfil a request that somebody has made
        TODO: Determine how to send NFT to user
    @param _requestor The address of the user making request
    @param _requestId The ID of the request being cancelled
    """
    request: Request = self.getRequest[_requestor][_requestId]
    assert request.active # dev: request does not exist/is not active
    if request.desiredCreator != ZERO_ADDRESS:
        assert request.desiredCreator == msg.sender # dev: not your request!
    
    # Calculate returned portion and fees
    fee: uint256 = request.paymentAmount * self.fees / FEE_DENOMINATOR
    payment: uint256 = request.paymentAmount - fee
    token: address = request.paymentToken

    self.getRequest[_requestor][_requestId] = empty(Request)

    if token == NATIVE_TOKEN_ADDRESS:
        send(msg.sender, payment)
        send(self.vault, fee)
    else:
        self.erc20_safe_transfer(token, msg.sender, payment)
        self.erc20_safe_transfer(token, self.vault, fee)

    log FulfilRequest(msg.sender, _requestor, _requestId, token, payment, fee)


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

@external
def changeVault(newVault: address):
    """
    @notice
        Fees will go to this vault
        Can be used to pay for hosting/whatever
    @param newVault new address for vault. Can't be zero address
    """
    assert msg.sender == self.owner # dev: only owner
    assert newVault != ZERO_ADDRESS # dev: can't change vault to zero address
    previousVault: address = self.vault
    self.vault = newVault
    log UpdateVault(previousVault, newVault)


@external
def changeFees(newFees: uint256):
    """
    @notice
        Adjust the fees. Note that fee denominator is 10,000
        Therefore fees are in "bips"
    @param newFees the fees as a 
    """
    assert msg.sender == self.owner # dev: only owner
    assert newFees < MAX_FEE # dev: fee is too high. be kind
    previousFees: uint256 = self.fees
    self.fees = newFees
    log UpdateFees(previousFees, newFees)

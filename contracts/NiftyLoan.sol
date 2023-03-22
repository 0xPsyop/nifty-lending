// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

//import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NiftyLoan {
    /*In V1 we can't suggest custom offers for listed loans. Only approve the already listed Loan terms. NO ERC20 loans. only ETH.

      1) The NFT owner can create a loan offer using their NFT as the collateral 
      2) The Lender can lend the required Amount for the borrower (NFT owner) and can earn an interest based on the loan specs
      3) The NFT is then escrowed in this contract and the funds are transferred to the borrower(NFT owner)
      4) The borrower should repay the (loan amount + interest + fees ) within the loan term 
      5) The interest charge is calculated based on the borrow time period and given APR
      6) If the loan is repayed the NFT is returned to the borrower
      7) If the loan isn't repayed the NFT is then transferred to the lender by the contract

     @dev
      req: the caller should own the nft, the caller should give permission to this contract for transfers
      
      creating a loan with the specific loan terms : the token , the collateral amount , the interest(apr),  the time period

      apr  = {[[(interest charges + fees )/ loan amt]/Number of days in loan]* 365} 100

    */

    error LoanAlreadyListed(address _nftAddress, uint256 _tokenId);
    error LoanNotListed(address _nftAddress, uint256 _tokenId);
    error LoanIsActive(address _nftAddress, uint256 _tokenId);
    error NotOwner();

    event NewLoanCreated(
        address indexed _nftAddress,
        address indexed _lender,
        uint256 indexed _tokenId,
        uint256 _requiredAmount,
        uint256 _interestPercentage,
        uint256 _loanTerm
    );
    event LoanUpdated(
        address indexed _nftAddress,
        uint256 indexed _tokenId,
        uint256 _newRequiredAmount,
        uint256 _newInterestPercentage,
        uint256 _newLoanTerm
    );
    event LoanActivated(Loan loan);
    event FundsEscrowed(Loan loan, uint256 Amount);
    event LoanFunded(Loan loan);

    // @dev checks whether the token is already listed as a loan
    modifier isListed(address _nftAddress, uint256 _tokenId) {
        Loan memory loan = loans[_nftAddress][_tokenId];
        if (loan.requiredAmount == 0)
            revert LoanNotListed(_nftAddress, _tokenId);
        _;
    }

    //@dev checks whether the token is not listed as a loan
    modifier isNotListed(address _nftAddress, uint256 _tokenId) {
        Loan memory loan = loans[_nftAddress][_tokenId];
        if (loan.requiredAmount > 0)
            revert LoanAlreadyListed(_nftAddress, _tokenId);
        _;
    }

    //@dev check if the caller is the owner of the specific token
    modifier isOwner(address _nftAddress, uint256 _tokenId) {
        if (IERC721(_nftAddress).ownerOf(_tokenId) != msg.sender)
            revert NotOwner();
        _;
    }

    modifier isNotActive(address _nftAddress, uint256 _tokenId) {
        Loan memory loan = loans[_nftAddress][_tokenId];
        if (loan.isActive) revert LoanIsActive(_nftAddress, _tokenId);
        _;
    }

    modifier isActive(address _nftAddress, uint256 _tokenId) {
        Loan memory loan = loans[_nftAddress][_tokenId];
        if (!loan.isActive) revert LoanIsActive(_nftAddress, _tokenId);
        _;
    }

    mapping(address => mapping(uint256 => Loan)) private loans;

    struct Loan {
        address nftAddress;
        address payable borrower;
        uint256 tokenId;
        uint256 requiredAmount;
        uint256 interestPercentage;
        uint256 loanTerm;
        bool isActive;
        uint256 activeTerm;
    }

    /* @dev create a loan listing with all the required details
      req: the specific token is not already listed for loan
   */

    function createLoan(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _requiredAmount,
        uint256 _interestPercentage,
        uint256 _loanTerm
    ) public isOwner(_nftAddress, _tokenId) isNotListed(_nftAddress, _tokenId) {
        require(
            _requiredAmount > 0 && _loanTerm > 0 && _interestPercentage > 0,
            "Not a valid loan"
        );

        //get the token approval here or do it before calling dis func
        Loan memory newLoan = Loan(
            _nftAddress,
            payable(msg.sender),
            _tokenId,
            _requiredAmount,
            _interestPercentage,
            _loanTerm,
            false,
            0
        );
        loans[_nftAddress][_tokenId] = newLoan;
        

        emit NewLoanCreated(
            _nftAddress,
            msg.sender,
            _tokenId,
            _requiredAmount,
            _interestPercentage,
            _loanTerm
        );
    }

    // @dev update the already listed loan details (literally changing the values in the Loan struct)
    function updateLoan(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _newRequiredAmount,
        uint256 _newInterestPercentage,
        uint256 _newLoanTerm
    )
        public
        isOwner(_nftAddress, _tokenId)
        isListed(_nftAddress, _tokenId)
        isNotActive(_nftAddress, _tokenId)
    {
        require(
            _newRequiredAmount > 0 &&
                _newLoanTerm > 0 &&
                _newInterestPercentage > 0,
            "Not a valid loan"
        );

        Loan memory loan = loans[_nftAddress][_tokenId];
        loan.requiredAmount = _newRequiredAmount;
        loan.interestPercentage = _newInterestPercentage;
        loan.loanTerm = _newLoanTerm;

        emit LoanUpdated(
            _nftAddress,
            _tokenId,
            _newRequiredAmount,
            _newInterestPercentage,
            _newLoanTerm
        );
    }

    // @dev transfer the loan amount from the lender to the contract and lock the ERC721 in the contract
    function escrow(
        address _nftAddress,
        uint256 _tokenId
    )
        external
        payable
        isListed(_nftAddress, _tokenId)
        isNotActive(_nftAddress, _tokenId)
    {
        Loan memory loan = loans[_nftAddress][_tokenId];
        require(msg.value >= loan.requiredAmount, "Not enough money to lend");
        
        IERC721(_nftAddress).safeTransferFrom(
            loan.borrower,
            address(this),
            _tokenId
        );
        loan.isActive == true;
        loan.activeTerm  = block.timestamp;
        emit FundsEscrowed(loan, msg.value);
    }

    // @dev transfers the money from the contract to the already escrowed NFT borrower
    function requestLoanAmount(
        address _nftAddress,
        uint256 _tokenId
    )
        external
        isOwner(_nftAddress, _tokenId)
        isListed(_nftAddress, _tokenId)
        isActive(_nftAddress, _tokenId)
    {
        Loan memory loan = loans[_nftAddress][_tokenId];
        require(address(this).balance >= loan.requiredAmount);
        (bool sent, ) = (loan.borrower).call{value: loan.requiredAmount}("");
        require(sent, "Failed to send Ether");

        emit LoanFunded(loan);
    }

    //@dev repay the loan by returning the interest+fees to the owner and recieving back the ERC721
    function repayLoan(
        address _nftAddress,
        uint256 _tokenId
    )
        external
        payable
        isOwner(_nftAddress, _tokenId)
        isListed(_nftAddress, _tokenId)
        isActive(_nftAddress, _tokenId)
    {
        Loan memory loan = loans[_nftAddress][_tokenId];
        require(block.timestamp >= loan.activeTerm +loan. );
        uint256 interestFee = getInterestFees(
            loan.requiredAmount,
            loan.interestPercentage,
            loan.loanTerm
        );
        require(msg.value >= (interestFee + loan.requiredAmount));
        loan.isActive = false;
    }

    //@dev liquidate the borrowers NFT if he didn't repay the loan in the specified time period
    function liquidate() external {}

    // calculate the fees required to facilitate the loan
    function getLoanFees() internal view returns (uint256 _swapFee) {}

    //@dev calculate the APR based on the loan time period, fees & interest
    /*    function getAPR(uint256 _requiredAmount, uint256  _interestPercentage, uint256 _loanTerm) public view returns(uint256 _apr){
          uint256 swapFee = getLoanFees();
          uint256 interestCharge = getInterestCharge(_requiredAmount,_interestPercentage, _loanTerm);
          uint256 apr = (interestCharge + swapFee)* 36500 /(_requiredAmount*_loanTerm);
          return apr;
        }*/

    //@dev calculate the total interest after the loan term based on the APR and loan Amount
    function getInterestFees(
        uint256 _requiredAmount,
        uint256 _interestPercentage,

        
        uint256 _loanTerm
    ) public view returns (uint256 _interestCharge) {}

    receive() external payable {}

    fallback() external payable {}
}

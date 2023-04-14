This is a simple solidity contract to facilitiate loans using ERC721 tokens as collateral. 

In V1 we can't suggest custom offers for listed loans. Only approve the already listed Loan terms. NO ERC20 loans. only ETH.
      1) The NFT owner can create a loan offer using their NFT as the collateral 
      2) The Lender can lend the required Amount for the borrower (NFT owner) and can earn an interest based on the loan specs
      3) The NFT is then escrowed in this contract and the funds are transferred to the borrower(NFT owner)
      4) The borrower should repay the (loan amount + interest + fees ) within the loan term 
      5) The interest charge is calculated based on the borrow time period and given APR
      6) If the loan is repayed the NFT is returned to the borrower
      7) If the loan isn't repayed the NFT is then transferred to the lender by the contract

V2 with ERC20 loans and custome terms is coming soon :)

Feel free to open issues on bugs.

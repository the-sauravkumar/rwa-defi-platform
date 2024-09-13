import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Error "mo:base/Error";

actor class Main(tokenizationCanister : Principal, lendingCanister : Principal, marketplaceCanister : Principal) {
    private let tokenization : actor {
        mintToken : (Text) -> async Text;
        getToken : (Text) -> async ?Text;
    } = actor(Principal.toText(tokenizationCanister));

    private let lending : actor {
        requestLoan : (Text, Nat) -> async Result.Result<Text, Text>;
        repayLoan : (Text) -> async Result.Result<Text, Text>;
        getBalance : (Principal) -> async Nat;
    } = actor(Principal.toText(lendingCanister));

    private let marketplace : actor {
        listToken : (Text, Nat) -> async Text;
        buyToken : (Text) -> async Result.Result<Text, Text>;
        deposit : () -> async ();
    } = actor(Principal.toText(marketplaceCanister));

    public func createAndListToken(assetDetails: Text, price: Nat) : async Result.Result<Text, Text> {
        try {
            let tokenId = await tokenization.mintToken(assetDetails);
            let listingId = await marketplace.listToken(tokenId, price);
            #ok(listingId)
        } catch (error) {
            #err("Failed to create and list token: " # Error.message(error))
        }
    };

    public func buyAndBorrowAgainst(listingId: Text, loanAmount: Nat) : async Result.Result<Text, Text> {
        try {
            let buyResult = await marketplace.buyToken(listingId);
            switch (buyResult) {
                case (#ok(_)) {
                    let loanResult = await lending.requestLoan(listingId, loanAmount);
                    switch (loanResult) {
                        case (#ok(loanId)) #ok("Token purchased and loan created. Loan ID: " # loanId);
                        case (#err(e)) #err("Token purchased but loan creation failed: " # e);
                    }
                };
                case (#err(e)) #err("Failed to purchase token: " # e);
            }
        } catch (error) {
            #err("Transaction failed: " # Error.message(error))
        }
    };

    public func repayLoanAndRelist(loanId: Text, newPrice: Nat) : async Result.Result<Text, Text> {
        try {
            let repayResult = await lending.repayLoan(loanId);
            switch (repayResult) {
                case (#ok(_)) {
                    let tokenResult = await tokenization.getToken(loanId);
                    switch (tokenResult) {
                        case (?tokenId) {
                            let listingId = await marketplace.listToken(tokenId, newPrice);
                            #ok("Loan repaid and token relisted. New listing ID: " # listingId)
                        };
                        case (null) #err("Loan repaid but token not found");
                    }
                };
                case (#err(e)) #err("Failed to repay loan: " # e);
            }
        } catch (error) {
            #err("Transaction failed: " # Error.message(error))
        }
    };

    public func getBalanceAndDeposit(user: Principal) : async Nat {
        try {
            let balance = await lending.getBalance(user);
            if (balance == 0) {
                await marketplace.deposit();
                let newBalance = await lending.getBalance(user);
                newBalance
            } else {
                balance
            }
        } catch (error) {
            Debug.print("Failed to get balance and deposit: " # Error.message(error));
            0
        }
    };
}
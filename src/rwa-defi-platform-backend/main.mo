import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Cycles "mo:base/ExperimentalCycles";
import Text "mo:base/Text";

actor RWADeFiPlatform {
    // Types
    type Token = {
        id: Text;
        details: Text;
        owner: Principal;
    };

    type Listing = {
        tokenId: Text;
        price: Nat;
        seller: Principal;
    };

    type Loan = {
        tokenId: Text;
        amount: Nat;
        borrower: Principal;
        isRepaid: Bool;
    };

    type Transaction = {
        id: Text;
        from: Principal;
        to: Principal;
        amount: Nat;
        transactionType: Text;
        timestamp: Int;
    };

    // State variables
    private stable var nextTokenId : Nat = 0;
    private stable var nextListingId : Nat = 0;
    private stable var nextLoanId : Nat = 0;
    private stable var nextTransactionId : Nat = 0;

    private let tokens = HashMap.HashMap<Text, Token>(0, Text.equal, Text.hash);
    private let listings = HashMap.HashMap<Text, Listing>(0, Text.equal, Text.hash);
    private let loans = HashMap.HashMap<Text, Loan>(0, Text.equal, Text.hash);
    private let balances = HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);
    private let ckBTCBalances = HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);
    private let transactionHistory = Buffer.Buffer<Transaction>(0);

    // Helper functions
    private func generateId(prefix: Text) : Text {
        let id = switch prefix {
            case "token" { nextTokenId += 1; nextTokenId };
            case "listing" { nextListingId += 1; nextListingId };
            case "loan" { nextLoanId += 1; nextLoanId };
            case "transaction" { nextTransactionId += 1; nextTransactionId };
            case _ { 0 };
        };
        prefix # "-" # Nat.toText(id)
    };

    private func addTransaction(from: Principal, to: Principal, amount: Nat, transactionType: Text) {
        let transaction : Transaction = {
            id = generateId("transaction");
            from = from;
            to = to;
            amount = amount;
            transactionType = transactionType;
            timestamp = Time.now();
        };
        transactionHistory.add(transaction);
    };

    // Main functions
    public func createAndListToken(user: Principal, assetDetails: Text, price: Nat) : async Result.Result<Text, Text> {
        let tokenId = generateId("token");
        let token : Token = {
            id = tokenId;
            details = assetDetails;
            owner = user;
        };
        tokens.put(tokenId, token);

        let listingId = generateId("listing");
        let listing : Listing = {
            tokenId = tokenId;
            price = price;
            seller = user;
        };
        listings.put(listingId, listing);

        addTransaction(user, Principal.fromActor(RWADeFiPlatform), 0, "CreateAndList");
        #ok(listingId)
    };

    public func buyToken(user: Principal, tokenId: Text, price: Nat) : async Result.Result<Text, Text> {
        switch (listings.get(tokenId)) {
            case null { #err("Listing not found") };
            case (?listing) {
                if (listing.price != price) {
                    return #err("Price mismatch");
                };
                switch (balances.get(user)) {
                    case null { return #err("Insufficient balance") };
                    case (?balance) {
                        if (balance < price) {
                            return #err("Insufficient balance");
                        };
                        balances.put(user, balance - price);
                        switch (balances.get(listing.seller)) {
                            case null { balances.put(listing.seller, price) };
                            case (?sellerBalance) { balances.put(listing.seller, sellerBalance + price) };
                        };
                        switch (tokens.get(listing.tokenId)) {
                            case null { return #err("Token not found") };
                            case (?token) {
                                let updatedToken : Token = {
                                    id = token.id;
                                    details = token.details;
                                    owner = user;
                                };
                                tokens.put(token.id, updatedToken);
                                listings.delete(tokenId);
                                addTransaction(user, listing.seller, price, "TokenPurchase");
                                #ok(token.id)
                            };
                        }
                    };
                }
            };
        }
    };

    public func buyTokenWithCkBTC(user: Principal, tokenId: Text, price: Nat) : async Result.Result<Text, Text> {
        switch (listings.get(tokenId)) {
            case null { #err("Listing not found") };
            case (?listing) {
                if (listing.price != price) {
                    return #err("Price mismatch");
                };
                switch (ckBTCBalances.get(user)) {
                    case null { return #err("Insufficient ckBTC balance") };
                    case (?balance) {
                        if (balance < price) {
                            return #err("Insufficient ckBTC balance");
                        };
                        ckBTCBalances.put(user, balance - price);
                        switch (ckBTCBalances.get(listing.seller)) {
                            case null { ckBTCBalances.put(listing.seller, price) };
                            case (?sellerBalance) { ckBTCBalances.put(listing.seller, sellerBalance + price) };
                        };
                        switch (tokens.get(listing.tokenId)) {
                            case null { return #err("Token not found") };
                            case (?token) {
                                let updatedToken : Token = {
                                    id = token.id;
                                    details = token.details;
                                    owner = user;
                                };
                                tokens.put(token.id, updatedToken);
                                listings.delete(tokenId);
                                addTransaction(user, listing.seller, price, "TokenPurchaseWithCkBTC");
                                #ok(token.id)
                            };
                        }
                    };
                }
            };
        }
    };

    public func buyAndBorrowAgainst(user: Principal, tokenId: Text, borrowAmount: Nat) : async Result.Result<Text, Text> {
        switch (await buyToken(user, tokenId, borrowAmount)) {
            case (#err(e)) { #err(e) };
            case (#ok(tokenId)) {
                let loanId = generateId("loan");
                let loan : Loan = {
                    tokenId = tokenId;
                    amount = borrowAmount;
                    borrower = user;
                    isRepaid = false;
                };
                loans.put(loanId, loan);
                switch (balances.get(user)) {
                    case null { balances.put(user, borrowAmount) };
                    case (?balance) { balances.put(user, balance + borrowAmount) };
                };
                addTransaction(Principal.fromActor(RWADeFiPlatform), user, borrowAmount, "Loan");
                #ok("Token bought and loan created: " # loanId)
            };
        }
    };

    public func buyAndBorrowAgainstWithCkBTC(user: Principal, tokenId: Text, borrowAmount: Nat) : async Result.Result<Text, Text> {
        switch (await buyTokenWithCkBTC(user, tokenId, borrowAmount)) {
            case (#err(e)) { #err(e) };
            case (#ok(tokenId)) {
                let loanId = generateId("loan");
                let loan : Loan = {
                    tokenId = tokenId;
                    amount = borrowAmount;
                    borrower = user;
                    isRepaid = false;
                };
                loans.put(loanId, loan);
                switch (ckBTCBalances.get(user)) {
                    case null { ckBTCBalances.put(user, borrowAmount) };
                    case (?balance) { ckBTCBalances.put(user, balance + borrowAmount) };
                };
                addTransaction(Principal.fromActor(RWADeFiPlatform), user, borrowAmount, "LoanWithCkBTC");
                #ok("Token bought and loan created with ckBTC: " # loanId)
            };
        }
    };

    public func repayLoanAndRelist(user: Principal, tokenId: Text, newPrice: Nat) : async Result.Result<Text, Text> {
        switch (tokens.get(tokenId)) {
            case null { #err("Token not found") };
            case (?token) {
                if (token.owner != user) {
                    return #err("You don't own this token");
                };
                
                let loanToRepay = Array.find<(Text, Loan)>(
                    Iter.toArray(loans.entries()),
                    func((_, loan)) = loan.tokenId == tokenId and loan.borrower == user and not loan.isRepaid
                );
                
                switch (loanToRepay) {
                    case null { return #err("No active loan found for this token") };
                    case (?(loanId, loan)) {
                        switch (balances.get(user)) {
                            case null { return #err("Insufficient balance to repay loan") };
                            case (?balance) {
                                if (balance < loan.amount) {
                                    return #err("Insufficient balance to repay loan");
                                };
                                balances.put(user, balance - loan.amount);
                                let updatedLoan : Loan = {
                                    tokenId = loan.tokenId;
                                    amount = loan.amount;
                                    borrower = loan.borrower;
                                    isRepaid = true;
                                };
                                loans.put(loanId, updatedLoan);
                                let listingId = generateId("listing");
                                let newListing : Listing = {
                                    tokenId = tokenId;
                                    price = newPrice;
                                    seller = user;
                                };
                                listings.put(listingId, newListing);
                                addTransaction(user, Principal.fromActor(RWADeFiPlatform), loan.amount, "LoanRepayment");
                                #ok("Loan repaid and token relisted: " # listingId)
                            };
                        }
                    };
                }
            };
        }
    };


    // public shared(msg) func deposit() : async () {
    //     // In a real implementation, this would interact with the ICP ledger
    //     // For this example, we'll just add some mock balance
    //     let depositAmount = 1000; // Mock deposit of 1000 ICP
    //     switch (balances.get(msg.caller)) {
    //         case null { balances.put(msg.caller, depositAmount) };
    //         case (?balance) { balances.put(msg.caller, balance + depositAmount) };
    //     };
    //     addTransaction(msg.caller, Principal.fromActor(RWADeFiPlatform), depositAmount, "Deposit");
    // };

    
    public func deposit(user: Principal) : async () {
        // In a real implementation, this would interact with the ICP ledger
        // For this example, we'll just add some mock balance
        let depositAmount = 1000; // Mock deposit of 1000 ICP
        switch (balances.get(user)) {
            case null { balances.put(user, depositAmount) };
            case (?balance) { balances.put(user, balance + depositAmount) };
        };
        addTransaction(user, Principal.fromActor(RWADeFiPlatform), depositAmount, "Deposit");
    };

    

    public func depositCkBTC(user: Principal, amount: Nat) : async Result.Result<Text, Text> {
        // In a real implementation, this would interact with the ckBTC ledger
        // For this example, we'll just add the specified amount to the balance
        switch (ckBTCBalances.get(user)) {
            case null { ckBTCBalances.put(user, amount) };
            case (?balance) { ckBTCBalances.put(user, balance + amount) };
        };
        addTransaction(user, Principal.fromActor(RWADeFiPlatform), amount, "ckBTCDeposit");
        #ok("ckBTC deposit successful")
    };

    public func transferCkBTC(from: Principal, to: Principal, amount: Nat) : async Result.Result<Text, Text> {
        switch (ckBTCBalances.get(from)) {
            case null { #err("Insufficient ckBTC balance") };
            case (?balance) {
                if (balance < amount) {
                    return #err("Insufficient ckBTC balance");
                };
                ckBTCBalances.put(from, balance - amount);
                switch (ckBTCBalances.get(to)) {
                    case null { ckBTCBalances.put(to, amount) };
                    case (?recipientBalance) { ckBTCBalances.put(to, recipientBalance + amount) };
                };
                addTransaction(from, to, amount, "ckBTCTransfer");
                #ok("ckBTC transfer successful")
            };
        }
    };

    public query func getBalance(user: Principal) : async Nat {
        switch (balances.get(user)) {
            case null { 0 };
            case (?balance) { balance };
        }
    };

    public query func getCkBTCBalance(user: Principal) : async Nat {
        switch (ckBTCBalances.get(user)) {
            case null { 0 };
            case (?balance) { balance };
        }
    };

    public query func getAllTokens() : async [(Text, Text)] {
        Iter.toArray(Iter.map<(Text, Token), (Text, Text)>(tokens.entries(), func ((id, token) : (Text, Token)) : (Text, Text) {
            (id, token.details)
        }))
    };

    public query func listAllTokens() : async [(Text, Listing)] {
        Iter.toArray(listings.entries())
    };

    public query func listLoans() : async [(Text, Loan)] {
        Iter.toArray(loans.entries())
    };

    public query func getTransactionHistory(user: Principal) : async [Transaction] {
        Buffer.toArray(Buffer.mapFilter<Transaction, Transaction>(transactionHistory, func (tx) {
            if (tx.from == user or tx.to == user) {
                ?tx
            } else {
                null
            }
        }))
    };

    public func resetICPBalance(user: Principal) : async () {
        balances.put(user, 0);
        addTransaction(user, Principal.fromActor(RWADeFiPlatform), 0, "ResetICPBalance");
};

    public func resetCkBTCBalance(user: Principal) : async () {
        ckBTCBalances.put(user, 0);
        addTransaction(user, Principal.fromActor(RWADeFiPlatform), 0, "ResetCkBTCBalance");
};

public func subtractICPBalance(user: Principal, amount: Nat) : async Result.Result<Text, Text> {
    switch (balances.get(user)) {
        case null { #err("User has no ICP balance") };
        case (?balance) {
            if (balance < amount) {
                #err("Insufficient ICP balance")
            } else {
                balances.put(user, balance - amount);
                addTransaction(user, Principal.fromActor(RWADeFiPlatform), amount, "SubtractICP");
                #ok("ICP balance subtracted successfully")
            }
        }
    }
};

public func subtractCkBTCBalance(user: Principal, amount: Nat) : async Result.Result<Text, Text> {
    switch (ckBTCBalances.get(user)) {
        case null { #err("User has no ckBTC balance") };
        case (?balance) {
            if (balance < amount) {
                #err("Insufficient ckBTC balance")
            } else {
                ckBTCBalances.put(user, balance - amount);
                addTransaction(user, Principal.fromActor(RWADeFiPlatform), amount, "SubtractCkBTC");
                #ok("ckBTC balance subtracted successfully")
            }
        }
    }
};

public shared func resetTransactionHistory() : async () {
    // Clear the transaction history buffer
    transactionHistory.clear();
};

 public func resetIds() : async () {
        nextTokenId := 0;
        nextListingId := 0;
        nextLoanId := 0;
        nextTransactionId := 0;
};

// Stable variable to store transactions
private stable var transactionHistoryID : [Transaction] = [];

// Function to reset the transaction history
public func resetTransactionHistoryID() : async () {
    transactionHistoryID := [];
};

public func payLoan(user: Principal, tokenId: Text) : async Result.Result<Text, Text> {
    // Find the active loan for the given token and user   
    return #ok("Loan paid successfully");
};

    // System method to accept cycles
    public func acceptCycles() : async () {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        assert (accepted == available);
    };

    // System method to get canister balance
    public query func getCanisterBalance() : async Nat {
        Cycles.balance()
    };
}
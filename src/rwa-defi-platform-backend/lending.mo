import TrieMap "mo:base/TrieMap";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Iter "mo:base/Iter";

actor Lending {
    private stable var loansEntries : [(Text, Loan)] = [];
    private var loans : TrieMap.TrieMap<Text, Loan> = TrieMap.fromEntries(loansEntries.vals(), Text.equal, Text.hash);

    private stable var balancesEntries : [(Principal, Nat)] = [];
    private var balances : TrieMap.TrieMap<Principal, Nat> = TrieMap.fromEntries(balancesEntries.vals(), Principal.equal, Principal.hash);

    type Loan = {
        borrower: Principal;
        tokenId: Text;
        amount: Nat;
        interestRate: Nat;  // Represented as basis points (e.g., 500 = 5%)
        dueDate: Int;
        isRepaid: Bool;
    };

    public shared(msg) func requestLoan(tokenId: Text, amount: Nat) : async Result.Result<Text, Text> {
        let loanId = "LOAN-" # Nat.toText(loans.size());
        let interestRate = 500; // 5% interest rate
        let loanDuration = 30 * 24 * 60 * 60 * 1000000000; // 30 days in nanoseconds
        let dueDate = Time.now() + loanDuration;

        loans.put(loanId, {
            borrower = msg.caller;
            tokenId = tokenId;
            amount = amount;
            interestRate = interestRate;
            dueDate = dueDate;
            isRepaid = false;
        });

        // Add the loan amount to the borrower's balance
        let currentBalance = switch (balances.get(msg.caller)) {
            case (?balance) balance;
            case null 0;
        };
        balances.put(msg.caller, currentBalance + amount);

        Debug.print("Loan requested: " # loanId);
        #ok(loanId)
    };

    public query func getLoan(loanId: Text) : async Result.Result<Loan, Text> {
        switch (loans.get(loanId)) {
            case (?loan) #ok(loan);
            case null #err("No loan found with ID: " # loanId);
        }
    };

    public shared(msg) func repayLoan(loanId: Text) : async Result.Result<Text, Text> {
        switch (loans.get(loanId)) {
            case (?loan) {
                if (loan.borrower != msg.caller) {
                    return #err("Only the borrower can repay the loan");
                };
                if (loan.isRepaid) {
                    return #err("Loan has already been repaid");
                };

                let repaymentAmount = calculateRepaymentAmount(loan);
                let borrowerBalance = switch (balances.get(msg.caller)) {
                    case (?balance) balance;
                    case null 0;
                };

                if (borrowerBalance < repaymentAmount) {
                    return #err("Insufficient balance to repay the loan");
                };

                // Update borrower's balance
                balances.put(msg.caller, borrowerBalance - repaymentAmount);

                // Mark loan as repaid
                loans.put(loanId, {
                    borrower = loan.borrower;
                    tokenId = loan.tokenId;
                    amount = loan.amount;
                    interestRate = loan.interestRate;
                    dueDate = loan.dueDate;
                    isRepaid = true;
                });

                Debug.print("Loan repaid: " # loanId);
                #ok("Loan successfully repaid")
            };
            case null #err("No loan found with ID: " # loanId);
        }
    };

    public query func listLoans() : async [(Text, Loan)] {
        Iter.toArray(loans.entries())
    };

    public shared(msg) func deposit(amount: Nat) : async () {
        let currentBalance = switch (balances.get(msg.caller)) {
            case (?balance) balance;
            case null 0;
        };
        balances.put(msg.caller, currentBalance + amount);
        Debug.print("Deposited " # Nat.toText(amount) # " for " # Principal.toText(msg.caller));
    };

    public query func getBalance(user: Principal) : async Nat {
        switch (balances.get(user)) {
            case (?balance) balance;
            case null 0;
        }
    };

    private func calculateRepaymentAmount(loan: Loan) : Nat {
        let principal : Nat64 = Nat64.fromNat(loan.amount);
        let interestRate : Nat64 = Nat64.fromNat(loan.interestRate); // Already in basis points
        let timeElapsed : Nat64 = Nat64.fromIntWrap(Int.abs(Time.now() - loan.dueDate));
        let daysElapsed : Nat64 = timeElapsed / (24 * 60 * 60 * 1000000000);
        let interest : Nat64 = (principal * interestRate * daysElapsed) / (100 * 100 * 365);
        Nat64.toNat(principal + interest)
    };

    system func preupgrade() {
        loansEntries := Iter.toArray(loans.entries());
        balancesEntries := Iter.toArray(balances.entries());
    };

    system func postupgrade() {
        loansEntries := [];
        balancesEntries := [];
    };
}
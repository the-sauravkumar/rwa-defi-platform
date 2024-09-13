import TrieMap "mo:base/TrieMap";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Result "mo:base/Result";
import Iter "mo:base/Iter";

actor Marketplace {
    private stable var listingsEntries : [(Text, Listing)] = [];
    private var listings : TrieMap.TrieMap<Text, Listing> = TrieMap.fromEntries(listingsEntries.vals(), Text.equal, Text.hash);

    private stable var balances : [(Principal, Nat)] = [];
    private var balancesMap : TrieMap.TrieMap<Principal, Nat> = TrieMap.fromEntries(balances.vals(), Principal.equal, Principal.hash);

    type Listing = {
        seller: Principal;
        tokenId: Text;
        price: Nat;
    };

    public shared(msg) func listToken(tokenId: Text, price: Nat) : async Text {
        let listingId = "LISTING-" # Nat.toText(listings.size());
        listings.put(listingId, {
            seller = msg.caller;
            tokenId = tokenId;
            price = price;
        });
        Debug.print("Token listed: " # listingId);
        listingId
    };

    public query func getListing(listingId: Text) : async ?Listing {
        listings.get(listingId)
    };

    public shared(msg) func buyToken(listingId: Text) : async Result.Result<Text, Text> {
        switch (listings.get(listingId)) {
            case (?listing) {
                if (msg.caller == listing.seller) {
                    return #err("Seller cannot buy their own token");
                };

                let buyerBalance = switch (balancesMap.get(msg.caller)) {
                    case (?balance) balance;
                    case null 0;
                };

                if (buyerBalance < listing.price) {
                    return #err("Insufficient balance");
                };

                // Update buyer's balance
                balancesMap.put(msg.caller, buyerBalance - listing.price);

                // Update seller's balance
                let sellerBalance = switch (balancesMap.get(listing.seller)) {
                    case (?balance) balance;
                    case null 0;
                };
                balancesMap.put(listing.seller, sellerBalance + listing.price);

                // Remove the listing
                ignore listings.remove(listingId);

                // Here you would typically transfer the token ownership
                // For this example, we'll just log it
                Debug.print("Token " # listing.tokenId # " transferred from " # Principal.toText(listing.seller) # " to " # Principal.toText(msg.caller));

                #ok("Token purchased successfully")
            };
            case null {
                #err("No listing found with ID: " # listingId)
            };
        }
    };

    public query func listAllTokens() : async [(Text, Listing)] {
        Iter.toArray(listings.entries())
    };

    public shared(msg) func deposit() : async () {
        let amount : Nat = 100; // For simplicity, each deposit adds 100 units
        let currentBalance = switch (balancesMap.get(msg.caller)) {
            case (?balance) balance;
            case null 0;
        };
        balancesMap.put(msg.caller, currentBalance + amount);
        Debug.print("Deposited " # Nat.toText(amount) # " for " # Principal.toText(msg.caller));
    };

    public query func getBalance(user: Principal) : async Nat {
        switch (balancesMap.get(user)) {
            case (?balance) balance;
            case null 0;
        }
    };

    system func preupgrade() {
        listingsEntries := Iter.toArray(listings.entries());
        balances := Iter.toArray(balancesMap.entries());
    };

    system func postupgrade() {
        listingsEntries := [];
        balances := [];
    };
}
import TrieMap "mo:base/TrieMap";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Iter "mo:base/Iter";

actor Tokenization {
    // A stable variable to store token IDs and their associated asset details
    private stable var tokensEntries : [(Text, Text)] = [];
    private var tokens : TrieMap.TrieMap<Text, Text> = TrieMap.fromEntries(tokensEntries.vals(), Text.equal, Text.hash);

    public func mintToken(assetDetails: Text) : async Text {
        // Generate a unique token ID based on the current size of the token map
        let tokenId = "TOKEN-" # Nat.toText(tokens.size());
        tokens.put(tokenId, assetDetails);

        Debug.print("Minted Token: " # tokenId # " with details: " # assetDetails);
        tokenId
    };

    public query func getToken(tokenId: Text) : async ?Text {
        // Retrieve token details by its ID
        tokens.get(tokenId)
    };

    public query func getAllTokens() : async [(Text, Text)] {
        // Return all tokens and their details
        Iter.toArray(tokens.entries())
    };

    system func preupgrade() {
        tokensEntries := Iter.toArray(tokens.entries());
    };

    system func postupgrade() {
        tokens := TrieMap.fromEntries(tokensEntries.vals(), Text.equal, Text.hash);
        tokensEntries := [];
    };
}
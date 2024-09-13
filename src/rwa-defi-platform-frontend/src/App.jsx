import React, { useState, useEffect, useCallback } from 'react';
import { AuthClient } from '@dfinity/auth-client';
import { Principal } from '@dfinity/principal';
import { rwa_defi_platform_backend } from 'declarations/rwa-defi-platform-backend';

function App() {
  const [authClient, setAuthClient] = useState(null);
  const [principal, setPrincipal] = useState(null);
  const [result, setResult] = useState('');
  const [balance, setBalance] = useState(0);
  const [ckBTCBalance, setCkBTCBalance] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [transactionHistory, setTransactionHistory] = useState([]);
  const [tokens, setTokens] = useState([]);
  const [listings, setListings] = useState([]);
  const [loans, setLoans] = useState([]);
  const [assetDetails, setAssetDetails] = useState('');
  const [tokenId, setTokenId] = useState('');
  const [price, setPrice] = useState('');
  const [loanAmount, setLoanAmount] = useState('');
  const [transferTo, setTransferTo] = useState('');
  const [transferAmount, setTransferAmount] = useState('');
  const [buyWithCkBTC, setBuyWithCkBTC] = useState(false);


  const resetAllValues = async () => {
    try {
      // Call backend function to reset the ICP and ckBTC balances
      await rwa_defi_platform_backend.resetICPBalance(Principal.fromText('2vxsx-fae'));
      await rwa_defi_platform_backend.resetCkBTCBalance(Principal.fromText('2vxsx-fae'));
      
      // Call backend function to reset the transaction history
      await rwa_defi_platform_backend.resetTransactionHistory();

      // Call backend function to reset the IDs shown in transaction table
      await rwa_defi_platform_backend.resetTransactionHistoryID();
      
      // Call backend function to reset the IDs
      await rwa_defi_platform_backend.resetIds();
  
      // Fetch updated balances from the backend
      const icpBalance = await rwa_defi_platform_backend.getBalance(Principal.fromText('2vxsx-fae'));
      const ckBTCBalance = await rwa_defi_platform_backend.getCkBTCBalance(Principal.fromText('2vxsx-fae'));
      
      // Update frontend state to reflect the reset
      setBalance(Number(icpBalance));
      setCkBTCBalance(Number(ckBTCBalance));
      setTransactionHistory([]);  // Clear frontend transaction history
      setTokens([]);
      setListings([]);
      setLoans([]);
      setAssetDetails('');
      setTokenId('');
      setPrice('');
      setLoanAmount('');
      setTransferTo('');
      setTransferAmount('');
      setResult('Reset successful');
      setError('');
    } catch (error) {
      setError(`Error resetting values: ${error.message}`);
    }
  };
  
  

  // const resetAllValues = () => {
  //   setBalance(0);
  //   setCkBTCBalance(0);
  //   setTransactionHistory([]);
  //   setTokens([]);
  //   setListings([]);
  //   setLoans([]);
  //   setAssetDetails('');
  //   setTokenId('');
  //   setPrice('');
  //   setLoanAmount('');
  //   setTransferTo('');
  //   setTransferAmount('');
  //   setResult('');
  //   setError('');
  // };
  

  const initAuth = async () => {
    const client = await AuthClient.create();
    setAuthClient(client);

    if (await client.isAuthenticated()) {
      handleAuthenticated(client);
    }
  };

  const handleAuthenticated = async (client) => {
    const identity = client.getIdentity();
    const userPrincipal = identity.getPrincipal();
    setPrincipal(userPrincipal);
  };

  const login = async () => {
    if (authClient) {
      authClient.login({
        identityProvider: process.env.II_URL,
        onSuccess: () => {
          handleAuthenticated(authClient);
        },
      });
    }
  };

  const logout = async () => {
    if (authClient) {
      await authClient.logout();
      setPrincipal(null);
      resetAllValues();
    }
  };

  const fetchTransactionHistory = async () => {
    try {
      const history = await rwa_defi_platform_backend.getTransactionHistory(Principal.fromText('2vxsx-fae'));
      console.log(history);
      setTransactionHistory(history);
      // Update balances
      const icpBalance = await rwa_defi_platform_backend.getBalance(Principal.fromText('2vxsx-fae'));
      const ckBTCBalance = await rwa_defi_platform_backend.getCkBTCBalance(Principal.fromText('2vxsx-fae'));
      setBalance(Number(icpBalance));
      setCkBTCBalance(Number(ckBTCBalance));
    } catch (error) {
      setError(`Error fetching transaction history: ${error.message}`);
    }
  };

  const fetchData = useCallback(async () => {
    if (!principal) return;

    setLoading(true);
    setError('');
    try {
      const [tokensResult, listingsResult, loansResult] = await Promise.all([
        rwa_defi_platform_backend.getAllTokens(),
        rwa_defi_platform_backend.listAllTokens(),
        rwa_defi_platform_backend.listLoans(),
      ]);

      setTokens(tokensResult);
      setListings(listingsResult);
      setLoans(loansResult);

      await fetchTransactionHistory();
    } catch (err) {
      console.error("Error fetching data:", err);
      setError(`Failed to fetch data. Please try again. Error: ${err.message}`);
    } finally {
      setLoading(false);
    }
  }, [principal]);

  useEffect(() => {
    initAuth();
  }, []);

  useEffect(() => {
    if (principal) {
      fetchData();
    }
  }, [principal, fetchData]);

  useEffect(() => {
    console.log("Updated ICP Balance:", balance);
}, [balance]); // This will log the balance whenever it's updated

  useEffect(() => {
    console.log("Updated ckBTC Balance:", ckBTCBalance);
}, [ckBTCBalance]); // This will log the ckBTC balance whenever it's updated


  async function handleCreateAndListToken(event) {
    event.preventDefault();
    setLoading(true);
    setError('');
    try {
      const response = await rwa_defi_platform_backend.createAndListToken(Principal.fromText('2vxsx-fae'), assetDetails, BigInt(price));
      if ('ok' in response) {
        setResult(`Token created and listed successfully. Listing ID: ${response.ok}`);
        await fetchTransactionHistory();
      } else {
        setError(`Error: ${response.err}`);
      }
    } catch (error) {
      setError(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  }



  async function handleBuyToken(event) {
    event.preventDefault();
    setLoading(true);
    setError('');
    try {
      const tokenPrice = BigInt(Number(price));
      const userPrincipal = Principal.fromText('2vxsx-fae');
  
      if (buyWithCkBTC) {
        if (ckBTCBalance < tokenPrice) {
          setError("Insufficient ckBTC balance");
          return;
        }
        const subtractResult = await rwa_defi_platform_backend.subtractCkBTCBalance(userPrincipal, tokenPrice);
        if ('err' in subtractResult) {
          setError(`Error: ${subtractResult.err}`);
          return;
        }
        const response = await rwa_defi_platform_backend.buyTokenWithCkBTC(userPrincipal, tokenId, tokenPrice);
        if ('ok' in response) {
          setResult(`Token bought successfully with ckBTC. Token ID: ${response.ok}`);
          const newCkBTCBalance = await rwa_defi_platform_backend.getCkBTCBalance(userPrincipal);
          setCkBTCBalance(Number(newCkBTCBalance));
        } else {
          setError(`Error: ${response.err}`);
          // Refund the subtracted amount if the buy operation failed
          await rwa_defi_platform_backend.depositCkBTC(userPrincipal, tokenPrice);
        }
      } else {
        if (balance < tokenPrice) {
          setError("Insufficient ICP balance");
          return;
        }
        const subtractResult = await rwa_defi_platform_backend.subtractICPBalance(userPrincipal, tokenPrice);
        if ('err' in subtractResult) {
          setError(`Error: ${subtractResult.err}`);
          return;
        }
        const response = await rwa_defi_platform_backend.buyToken(userPrincipal, tokenId, tokenPrice);
        if ('ok' in response) {
          setResult(`Token bought successfully with ICP. Token ID: ${response.ok}`);
          const newICPBalance = await rwa_defi_platform_backend.getBalance(userPrincipal);
          setBalance(Number(newICPBalance));
        } else {
          setError(`Error: ${response.err}`);
          // Refund the subtracted amount if the buy operation failed
          await rwa_defi_platform_backend.deposit(userPrincipal);
        }
      }
      await fetchTransactionHistory();
    } catch (error) {
      setError(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  }
  


  async function handleBuyAndBorrowAgainst(event) {
    event.preventDefault();
    setLoading(true);
    setError('');
    try {
      const borrowAmount = Number(loanAmount);
      if (buyWithCkBTC) {
        if (ckBTCBalance < borrowAmount) {
          setError("Insufficient ckBTC balance");
          return;
        }
        const response = await rwa_defi_platform_backend.buyAndBorrowAgainstWithCkBTC(Principal.fromText('2vxsx-fae'), tokenId, BigInt(borrowAmount));
        if ('ok' in response) {
          setResult(response.ok);
          const subtractResult = await rwa_defi_platform_backend.subtractCkBTCBalance(Principal.fromText('2vxsx-fae'), BigInt(borrowAmount));
          if ('ok' in subtractResult) {
            const newCkBTCBalance = await rwa_defi_platform_backend.getCkBTCBalance(Principal.fromText('2vxsx-fae'));
            setCkBTCBalance(Number(newCkBTCBalance));
          } else {
            setError(`Error subtracting ckBTC balance: ${subtractResult.err}`);
          }
        } else {
          setError(`Error: ${response.err}`);
        }
      } else {
        if (balance < borrowAmount) {
          setError("Insufficient ICP balance");
          return;
        }
        const response = await rwa_defi_platform_backend.buyAndBorrowAgainst(Principal.fromText('2vxsx-fae'), tokenId, BigInt(borrowAmount));
        if ('ok' in response) {
          setResult(response.ok);
          const subtractResult = await rwa_defi_platform_backend.subtractICPBalance(Principal.fromText('2vxsx-fae'), BigInt(borrowAmount));
          if ('ok' in subtractResult) {
            const newICPBalance = await rwa_defi_platform_backend.getBalance(Principal.fromText('2vxsx-fae'));
            setBalance(Number(newICPBalance));
          } else {
            setError(`Error subtracting ICP balance: ${subtractResult.err}`);
          }
        } else {
          setError(`Error: ${response.err}`);
        }
      }
      await fetchTransactionHistory();
    } catch (error) {
      setError(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  }

  async function handleRepayLoanAndRelist(event) {
    event.preventDefault();
    setLoading(true);
    setError('');
    try {
      const repayAmount = Number(price);
      if (balance < repayAmount) {
        setError("Insufficient ICP balance");
        return;
      }
      // const response = await rwa_defi_platform_backend.repayLoanAndRelist(Principal.fromText('2vxsx-fae'), tokenId, BigInt(repayAmount));
      const response = await rwa_defi_platform_backend.payLoan(Principal.fromText('2vxsx-fae'), tokenId);
      if ('ok' in response) {
        setResult(response.ok);
        const subtractResult = await rwa_defi_platform_backend.subtractICPBalance(Principal.fromText('2vxsx-fae'), BigInt(repayAmount));
        if ('ok' in subtractResult) {
          const newICPBalance = await rwa_defi_platform_backend.getBalance(Principal.fromText('2vxsx-fae'));
          setBalance(Number(newICPBalance));
          await fetchTransactionHistory();
        } else {
          setError(`Error subtracting ICP balance: ${subtractResult.err}`);
        }
      } else {
        setError(`Error: ${response.err}`);
      }
    } catch (error) {
      setError(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  }

  async function handleDeposit() {
    setLoading(true);
    setError('');
    try {
      await rwa_defi_platform_backend.deposit(Principal.fromText('2vxsx-fae'));
      await fetchTransactionHistory();
      setResult("Deposit successful");
    } catch (error) {
      setError(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  }

  async function handleCkBTCDeposit(event) {
    event.preventDefault();
    setLoading(true);
    setError('');
    try {
      const response = await rwa_defi_platform_backend.depositCkBTC(Principal.fromText('2vxsx-fae'), BigInt(transferAmount));
      if ('ok' in response) {
        await fetchTransactionHistory();
        setResult("ckBTC deposit successful");
      } else {
        setError(`Error: ${response.err}`);
      }
    } catch (error) {
      setError(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  }

  // async function handleTransferCkBTC(event) {
  //   event.preventDefault();
  //   setLoading(true);
  //   setError('');
  //   try {
  //     const toPrincipal = Principal.fromText(transferTo);
  //     const transferAmountBigInt = BigInt(transferAmount);
  //     // const subtractResult = await rwa_defi_platform_backend.subtractCkBTCBalance(Principal.fromText('2vxsx-fae'), transferAmountBigInt);
  //     if ('ok' in subtractResult) {
  //       const response = await rwa_defi_platform_backend.transferCkBTC(Principal.fromText('2vxsx-fae'), toPrincipal, transferAmountBigInt);
  //       if ('ok' in response) {
  //         await fetchTransactionHistory();
  //         setResult("ckBTC transfer successful");
  //         setTransferTo('');
  //         setTransferAmount('');
  //         const newCkBTCBalance = await rwa_defi_platform_backend.getCkBTCBalance(Principal.fromText('2vxsx-fae'));
  //         setCkBTCBalance(Number(newCkBTCBalance));
  //       } else {
  //         setError(`Error: ${response.err}`);
  //         // Revert the balance subtraction if transfer fails
  //         await rwa_defi_platform_backend.addCkBTCBalance(Principal.fromText('2vxsx-fae'), transferAmountBigInt);
  //       }
  //     } else {
  //       setError(`Error: ${subtractResult.err}`);
  //     }
  //   } catch (error) {
  //     setError(`Error: ${error.message}`);
  //   } finally {
  //     setLoading(false);
  //   }
  // }

  async function handleTransferCkBTC(event) {
    event.preventDefault();
    setLoading(true);
    setError('');
    
    try {
        const toPrincipal = Principal.fromText(transferTo);
        const transferAmountBigInt = BigInt(transferAmount);
        
        // Initiate the ckBTC transfer without manually subtracting balance first.
        const response = await rwa_defi_platform_backend.transferCkBTC(Principal.fromText('2vxsx-fae'), toPrincipal, transferAmountBigInt);
        
        if ('ok' in response) {
            // Update the transaction history
            await fetchTransactionHistory();
            setResult("ckBTC transfer successful");

            // Reset the transfer fields
            setTransferTo('');
            setTransferAmount('');

            // Fetch the updated balance and update the state
            const newCkBTCBalance = await rwa_defi_platform_backend.getCkBTCBalance(Principal.fromText('2vxsx-fae'));
            setCkBTCBalance(Number(newCkBTCBalance));
        } else {
            setError(`Error: ${response.err}`);
        }
    } catch (error) {
        setError(`Error: ${error.message}`);
    } finally {
        setLoading(false);
    }
}


  if (!principal) {
    return (
      <div className="container mx-auto p-4">
        <h1 className="text-2xl font-bold mb-4">Welcome</h1>
        <button onClick={login} className="bg-blue-500 text-white px-4 py-2 rounded">Login with Internet Identity</button>
      </div>
    );
  }

  return (
    <main className="container mx-auto p-4">
      {/* <h1 className="text-2xl font-bold mb-4">RWA DeFi Platform</h1> */}

      {error && <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative mb-4" role="alert">{error}</div>}

      {/* <div className="mb-8 p-4 bg-gray-100 rounded">
        <h2 className="text-xl font-semibold mb-2">Account</h2>
        <p>Principal: {principal.toString()}</p>
        <p>ICP Balance: {balance}</p>
        <p>ckBTC Balance: {ckBTCBalance}</p>
        <button onClick={handleDeposit} disabled={loading} className="mt-2 p-2 bg-green-500 text-white rounded mr-2">
          Deposit ICP
        </button>
        <button onClick={logout} className="mt-2 p-2 bg-red-500 text-white rounded">
          Logout
        </button>
      </div> */}
      <div className="account-info">
        <p>Principal: <span className="value">{principal.toString()}</span></p>
        <p>ICP Balance: <span className="value">{balance}</span></p>
        <p>ckBTC Balance: <span className="value">{ckBTCBalance}</span></p>
        <button onClick={handleDeposit} disabled={loading} className="bg-green-500">
          Deposit ICP
        </button>
        <button onClick={logout} className="bg-red-500">
          Logout
        </button>
      </div>

      <div className="mb-8">
        <h2 className="text-xl font-semibold mb-2">ckBTC Operations</h2>
        <form onSubmit={handleCkBTCDeposit} className="space-y-2 mb-4">
          <input
            type="number"
            value={transferAmount}
            onChange={(e) => setTransferAmount(e.target.value)}
            placeholder="Enter ckBTC amount"
            className="w-full p-2 border rounded"
            required
          />
          <button type="submit" disabled={loading} className="w-full p-2 bg-purple-500 text-white rounded">
            Deposit ckBTC
          </button>
        </form><br></br>
        <form onSubmit={handleTransferCkBTC} className="space-y-2">
          <input
            type="text"
            value={transferTo}
            onChange={(e) => setTransferTo(e.target.value)}
            placeholder="Enter recipient Principal"
            className="w-full p-2 border rounded"
            required
          />
          <input
            type="number"
            value={transferAmount}
            onChange={(e) => setTransferAmount(e.target.value)}
            placeholder="Enter ckBTC amount"
            className="w-full p-2 border rounded"
            required
          />
          <button type="submit" disabled={loading} className="w-full p-2 bg-indigo-500 text-white rounded">
            Transfer ckBTC
          </button>
        </form>
      </div>

      <div className="mb-8">
        <h2 className="text-xl font-semibold mb-2">Create and List Token</h2>
        <form onSubmit={handleCreateAndListToken} className="space-y-2">
          <input
            type="text"
            value={assetDetails}
            onChange={(e) => setAssetDetails(e.target.value)}
            placeholder="Enter asset details"
            className="w-full p-2 border rounded"
            required
          />
          <input
            type="number"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            placeholder="Enter price"
            className="w-full p-2 border rounded"
            required
          />
          <button type="submit" disabled={loading} className="w-full p-2 bg-blue-500 text-white rounded">
            Create and List Token
          </button>
        </form>
      </div>

      <div className="mb-8">
        <h2 className="text-xl font-semibold mb-2">Buy Token</h2>
        <form onSubmit={handleBuyToken} className="space-y-2">
          <input
            type="text"
            value={tokenId}
            onChange={(e) => setTokenId(e.target.value)}
            placeholder="Enter Token ID"
            className="w-full p-2 border rounded"
            required
          />
          <input
            type="number"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            placeholder="Enter price"
            className="w-full p-2 border rounded"
            required
          />
          <div className="flex items-center">
            <input
              type="checkbox"
              checked={buyWithCkBTC}
              onChange={(e) => setBuyWithCkBTC(e.target.checked)}
              className="mr-2"
            />
            <label>Buy with ckBTC</label>
          </div>
          <button type="submit" disabled={loading} className="w-full p-2 bg-green-500 text-white rounded">
            Buy Token
          </button>
        </form>
      </div>

      <div className="mb-8">
        <h2 className="text-xl font-semibold mb-2">Buy and Borrow Against Token</h2>
        <form onSubmit={handleBuyAndBorrowAgainst} className="space-y-2">
          <input
            type="text"
            value={tokenId}
            onChange={(e) => setTokenId(e.target.value)}
            placeholder="Enter Token ID"
            className="w-full p-2 border rounded"
            required
          />
          <input
            type="number"
            value={loanAmount}
            onChange={(e) => setLoanAmount(e.target.value)}
            placeholder="Enter loan amount"
            className="w-full p-2 border rounded"
            required
          />
          <div className="flex items-center">
            <input
              type="checkbox"
              checked={buyWithCkBTC}
              onChange={(e) => setBuyWithCkBTC(e.target.checked)}
              className="mr-2"
            />
            <label>Buy with ckBTC</label>
          </div>
          <button type="submit" disabled={loading} className="w-full p-2 bg-green-500 text-white rounded">
            Buy and Borrow
          </button>
        </form>
      </div>

      <div className="mb-8">
        <h2 className="text-xl font-semibold mb-2">Pay Loan</h2>
        <form onSubmit={handleRepayLoanAndRelist} className="space-y-2">
          <input
            type="text"
            value={tokenId}
            onChange={(e) => setTokenId(e.target.value)}
            placeholder="Enter Token ID"
            className="w-full p-2 border rounded"
            required
          />
          <input
            type="number"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            placeholder="Enter new price"
            className="w-full p-2 border rounded"
            required
          />
          <button type="submit" disabled={loading} className="w-full p-2 bg-yellow-500 text-white rounded">
            Repay and Relist
          </button>
        </form>
      </div>

      {/* <div className="mb-8">
        <h2 className="text-xl font-semibold mb-2">Tokens</h2>
        <ul className="list-disc pl-5">
          {tokens.map(([id, details]) => (
            <li key={id}>{id}: {details}</li>
          ))}
        </ul>
      </div>

      <div className="mb-8">
        <h2 className="text-xl font-semibold mb-2">Listings</h2>
        <ul className="list-disc pl-5">
          {listings.map(([id, listing]) => (
            <li key={id}>
              {id}: Token {listing.tokenId} for {listing.price.toString()}
            </li>
          ))}
        </ul>
      </div>

      <div className="mb-8">
        <h2 className="text-xl font-semibold mb-2">Loans</h2>
        <ul className="list-disc pl-5">
          {loans.map(([id, loan]) => (
            <li key={id}>
              {id}: {loan.amount.toString()} for Token {loan.tokenId} (Repaid: {loan.isRepaid ? 'Yes' : 'No'})
            </li>
          ))}
        </ul>
      </div> */}

      <div classname="mb-8">
      <h2 className="text-xl font-semibold mb-2">Reset All the Values</h2>
          <button onClick={resetAllValues} className="mt-2 p-2 bg-red-500 text-white rounded">
          Reset
        </button>
      </div>

      {/* <div className="mb-8">
        <h2 className="text-xl font-semibold mb-2">Transaction History</h2>
        <div className="overflow-auto max-h-64">
          <table className="min-w-full bg-white">
            <thead>
              <tr>
                <th className="py-2 px-4 border-b">Transaction ID</th>
                <th className="py-2 px-4 border-b">From</th>
                <th className="py-2 px-4 border-b">To</th>
                <th className="py-2 px-4 border-b">Amount</th>
                <th className="py-2 px-4 border-b">Type</th>
                <th className="py-2 px-4 border-b">Timestamp</th>
              </tr>
            </thead>
            <tbody>
              {transactionHistory.map((tx) => (
                <tr key={tx.id}>
                  <td className="py-2 px-4 border-b">{tx.id}</td>
                  <td className="py-2 px-4 border-b">{tx.from.toText()}</td>
                  <td className="py-2 px-4 border-b">{tx.to.toText()}</td>
                  <td className="py-2 px-4 border-b">{tx.amount.toString()}</td>
                  <td className="py-2 px-4 border-b">{tx.transactionType}</td>
                  <td className="py-2 px-4 border-b">{new Date(Number(tx.timestamp) / 1000000).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div> */}

<div className="mb-8">
        <h2 className="text-xl font-semibold mb-2">Transaction History</h2>
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th className="py-2 px-4 border-b">Transaction ID</th>
                <th className="py-2 px-4 border-b">From</th>
                <th className="py-2 px-4 border-b">To</th>
                <th className="py-2 px-4 border-b">Amount</th>
                <th className="py-2 px-4 border-b">Type</th>
                <th className="py-2 px-4 border-b">Timestamp</th>
              </tr>
            </thead>
            <tbody>
              {transactionHistory.map((tx) => (
                <tr key={tx.id}>
                  <td className="py-2 px-4 border-b">{tx.id}</td>
                  <td className="py-2 px-4 border-b">{tx.from.toText()}</td>
                  <td className="py-2 px-4 border-b">{tx.to.toText()}</td>
                  <td className="py-2 px-4 border-b">{tx.amount.toString()}</td>
                  <td className="py-2 px-4 border-b">{tx.transactionType}</td>
                  <td className="py-2 px-4 border-b">{new Date(Number(tx.timestamp) / 1000000).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {result && (
        <div className="mt-8 p-4 bg-green-100 border border-green-400 text-green-700 rounded">
          <h2 className="text-xl font-semibold mb-2">Result</h2>
          <p>{result}</p>
        </div>
      )}
    </main>
  );
}

export default App;
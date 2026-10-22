#!/usr/bin/env python3
"""Deploy Phi + PhiBridge to Ethereum L1. Private key from stdin ONLY.
Never prints the key. Aborts if base fee exceeds MAX_BASE_GWEI.
Steps: 1) Phi  2) PhiBridge(token, operator=FRESH)  3) setBridge  4) verify.

PHI hygiene (fixed from birth — the ATEX set was born with
operator=deployer and the deployer key was later exposed): the operator
address comes from the OPERATOR_ADDRESS env var and MUST be a fresh key
generated offline at deploy time; it is never the deployer. The bridge is
constructed with that operator directly, so no post-deploy rotation is
needed. The operator's private key never touches this script or machine
beyond its address.
Does NOT renounceOwnership (operator key hygiene decision is Lux's, post-deploy).
Usage: OPERATOR_ADDRESS=0x<fresh> python3 deploy_l1.py < key.txt
"""
import os
import sys, json, time
from web3 import Web3
from eth_account import Account

RPC = "https://ethereum-rpc.publicnode.com"
MAX_BASE_GWEI = 0.20
MAX_FEE_GWEI = 0.25
PRIORITY_GWEI = 0.10
OPERATOR = os.environ.get("OPERATOR_ADDRESS", "")  # FRESH key address, never the deployer

def main():
    key = sys.stdin.read().strip()
    assert key, "empty key"
    acct = Account.from_key(key)
    deployer = acct.address
    operator = OPERATOR
    assert operator, ("set OPERATOR_ADDRESS to the address of a FRESH "
                      "operator key generated offline (see PHI_DEPLOYMENT.md)")
    assert operator.lower() != deployer.lower(), \
        "operator must NOT be the deployer — generate a fresh key"
    operator = Web3.to_checksum_address(operator)
    w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 60}))
    assert w3.is_connected(), "rpc down"
    cid = w3.eth.chain_id
    assert cid == 1, f"not mainnet! chain_id={cid}"
    print(f"deployer={deployer} operator={operator} chain=mainnet", flush=True)

    def fee_ok():
        base = w3.eth.fee_history(1, "latest")["baseFeePerGas"][-1]
        g = float(w3.from_wei(base, "gwei"))
        print(f"baseFee={g:.4f} gwei", flush=True)
        return g <= MAX_BASE_GWEI

    def send(tx):
        tx["chainId"] = 1
        tx["maxFeePerGas"] = w3.to_wei(MAX_FEE_GWEI, "gwei")
        tx["maxPriorityFeePerGas"] = w3.to_wei(PRIORITY_GWEI, "gwei")
        signed = acct.sign_transaction(tx)
        h = w3.eth.send_raw_transaction(signed.raw_transaction)
        print(f"sent {h.hex()} nonce={tx['nonce']}", flush=True)
        r = w3.eth.wait_for_transaction_receipt(h, timeout=600)
        assert r["status"] == 1, f"tx failed: {h.hex()}"
        return r

    nonce = w3.eth.get_transaction_count(deployer)
    sk = json.load(open("/home/hatch/workspace/phi-bridge/contracts/out/Phi.sol/Phi.json"))
    br = json.load(open("/home/hatch/workspace/phi-bridge/contracts/out/PhiBridge.sol/PhiBridge.json"))

    assert fee_ok(), "base fee too high, aborting"
    print("deploying Phi...", flush=True)
    r1 = send({"from": deployer, "nonce": nonce, "gas": 700_000,
               "data": sk["bytecode"]["object"]})
    phi_addr = r1["contractAddress"]
    print(f"PHI={phi_addr}", flush=True)
    nonce += 1

    assert fee_ok(), "base fee too high, aborting"
    print("deploying PhiBridge...", flush=True)
    tmp = w3.eth.contract(abi=br["abi"], bytecode=br["bytecode"]["object"])
    data = tmp.constructor(phi_addr, operator).data_in_transaction
    r2 = send({"from": deployer, "nonce": nonce, "gas": 780_000, "data": data})
    bridge_addr = r2["contractAddress"]
    print(f"BRIDGE={bridge_addr}", flush=True)
    nonce += 1

    assert fee_ok(), "base fee too high, aborting"
    print("wiring setBridge...", flush=True)
    phi = w3.eth.contract(address=phi_addr, abi=sk["abi"])
    r3 = send({"from": deployer, "nonce": nonce, "gas": 100_000,
               "data": phi.functions.setBridge(bridge_addr)._encode_transaction_data()})
    print(f"setBridge tx={r3['transactionHash'].hex()}", flush=True)

    # verify
    assert phi.functions.bridge().call() == bridge_addr, "bridge wiring mismatch"
    bridge = w3.eth.contract(address=bridge_addr, abi=br["abi"])
    assert bridge.functions.operator().call() == operator, "operator mismatch"
    assert bridge.functions.token().call() == phi_addr, "token mismatch"
    rate = bridge.functions.mintRate().call()
    assert rate == 10**18, f"genesis rate wrong: {rate}"
    print(f"VERIFY_OK bridge={bridge_addr} operator={operator} mintRate=1.0", flush=True)
    print(f"TXS phi={r1['transactionHash'].hex()} bridge={r2['transactionHash'].hex()} wire={r3['transactionHash'].hex()}", flush=True)

if __name__ == "__main__":
    main()

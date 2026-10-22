// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Phi.sol";
import "../src/PhiBridge.sol";

contract PhiBridgeTest is Test {
    Phi token;
    PhiBridge bridge;

    address operator = address(0x0BEEF);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    uint256 constant ONE = 1e18;

    event PhixLocked(
        bytes32 indexed btcTxid, address indexed to, uint256 phixAmount, uint256 phiMinted
    );
    event PhiBurned(
        address indexed from, string btcAddress, uint256 phiBurned, uint256 phixReleased
    );

    function setUp() public {
        token = new Phi(); // test contract is owner
        bridge = new PhiBridge(address(token), operator); // test contract is owner
        token.setBridge(address(bridge));
    }

    // ---------- ln ----------

    function testLn2Accuracy() public view {
        // true ln(2) = 0.69314718055994530942... ; tolerance 1e12 (1e-6 relative)
        uint256 got = bridge.ln(2e18);
        assertApproxEqAbs(got, 693147180559945309, 1e12, "ln2");
    }

    function testLnKnownValues() public view {
        assertEq(bridge.ln(1e18), 0, "ln(1)");
        // ln(e) = 1 ; input is e truncated to 1e18 fixed point
        assertApproxEqAbs(bridge.ln(2718281828459045235), 1e18, 1e12, "ln(e)");
        // ln(10) = 2.30258509299404568402...
        assertApproxEqAbs(bridge.ln(10e18), 2302585092994045684, 1e12, "ln(10)");
        // ln(100) = 4.60517018598809136803...
        assertApproxEqAbs(bridge.ln(100e18), 4605170185988091368, 1e12, "ln(100)");
        // monotonic spot checks
        assertGt(bridge.ln(3e18), bridge.ln(2e18));
        assertGt(bridge.ln(2e18), bridge.ln(1e18));
    }

    function testLnOutOfDomainReverts() public {
        vm.expectRevert(PhiBridge.LnOutOfDomain.selector);
        bridge.ln(1e18 - 1);
    }

    // ---------- mintRate ----------

    function testMintRateGenesisIsExactlyOne() public view {
        assertEq(token.totalSupply(), 0);
        assertEq(bridge.mintRate(), 1e18, "genesis rate must be exactly 1:1");
    }

    function testMintRateDecreasesMonotonically() public {
        uint256 r0 = bridge.mintRate();
        assertEq(r0, 1e18);

        // Build S = 1M PHI via lockPhix at genesis rate (exactly 1:1).
        vm.prank(operator);
        bridge.lockPhix(bytes32(uint256(1)), 1_000_000e18, alice);
        assertEq(token.totalSupply(), 1_000_000e18);

        uint256 r1 = bridge.mintRate();
        // design: S=1M -> ~0.591 (1/(1+ln2))
        assertApproxEqAbs(r1, 0.591e18, 0.00591e18, "rate at 1M supply");
        assertLt(r1, r0, "rate must decrease");

        // Mint math at non-genesis supply: 1 PHIX -> exactly r1 PHI.
        vm.prank(operator);
        bridge.lockPhix(bytes32(uint256(2)), 1e18, bob);
        assertEq(token.balanceOf(bob), r1, "marginal mint math");

        // Push supply to ~6.4M PHI.
        vm.prank(operator);
        bridge.lockPhix(bytes32(uint256(3)), 9_143_100e18, alice);
        uint256 s = token.totalSupply();
        assertApproxEqAbs(s, 6_400_000e18, 100_000e18, "supply ~6.4M");

        uint256 r2 = bridge.mintRate();
        // design: S~6.4M -> ~0.333
        assertApproxEqAbs(r2, 0.333e18, 0.00333e18, "rate at 6.4M supply");
        assertLt(r2, r1, "rate must keep decreasing");
        assertGt(r2, 0, "rate stays positive");
    }

    // ---------- lockPhix ----------

    function testLockPhixMintsAndEmits() public {
        bytes32 txid = bytes32(uint256(0xabc));

        vm.expectEmit(true, true, false, true);
        emit PhixLocked(txid, alice, 100e18, 100e18); // genesis rate is exactly 1:1

        vm.prank(operator);
        bridge.lockPhix(txid, 100e18, alice);

        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.totalSupply(), 100e18);
        assertTrue(bridge.usedTxids(txid), "txid marked used");
    }

    function testLockPhixReplayReverts() public {
        bytes32 txid = bytes32(uint256(0xdef));
        vm.prank(operator);
        bridge.lockPhix(txid, 10e18, alice);

        vm.prank(operator);
        vm.expectRevert(PhiBridge.TxidAlreadyUsed.selector);
        bridge.lockPhix(txid, 10e18, alice);
    }

    function testLockPhixNonOperatorReverts() public {
        vm.prank(alice);
        vm.expectRevert(PhiBridge.OnlyOperator.selector);
        bridge.lockPhix(bytes32(uint256(1)), 10e18, alice);
    }

    function testLockPhixZeroChecks() public {
        vm.prank(operator);
        vm.expectRevert(PhiBridge.ZeroTxid.selector);
        bridge.lockPhix(bytes32(0), 10e18, alice);

        vm.prank(operator);
        vm.expectRevert(PhiBridge.ZeroAmount.selector);
        bridge.lockPhix(bytes32(uint256(1)), 0, alice);

        vm.prank(operator);
        vm.expectRevert(PhiBridge.ZeroAddress.selector);
        bridge.lockPhix(bytes32(uint256(1)), 10e18, address(0));
    }

    // ---------- burnForPhix ----------

    function testBurnForPhixBurnsAndEmits() public {
        vm.prank(operator);
        bridge.lockPhix(bytes32(uint256(7)), 1000e18, alice);

        uint256 rateBefore = bridge.mintRate(); // pre-burn supply
        uint256 expectedPhix = (100e18 * ONE) / rateBefore;

        vm.prank(alice);
        token.approve(address(bridge), 100e18);

        vm.expectEmit(true, false, false, true);
        emit PhiBurned(alice, "bc1qtestaddress", 100e18, expectedPhix);

        vm.prank(alice);
        bridge.burnForPhix(100e18, "bc1qtestaddress");

        assertEq(token.balanceOf(alice), 900e18, "caller burned");
        assertEq(token.totalSupply(), 900e18, "supply shrinks");
    }

    function testBurnForPhixEmptyBtcAddressReverts() public {
        vm.prank(alice);
        vm.expectRevert(PhiBridge.EmptyBtcAddress.selector);
        bridge.burnForPhix(1e18, "");
    }

    function testBurnForPhixZeroAmountReverts() public {
        vm.prank(alice);
        vm.expectRevert(PhiBridge.ZeroAmount.selector);
        bridge.burnForPhix(0, "bc1qtestaddress");
    }

    function testBurnForPhixNeedsApproval() public {
        vm.prank(operator);
        bridge.lockPhix(bytes32(uint256(8)), 50e18, alice);

        vm.prank(alice);
        vm.expectRevert(Phi.InsufficientAllowance.selector);
        bridge.burnForPhix(10e18, "bc1qtestaddress");
    }

    // ---------- operator / ownership ----------

    function testOnlyOwnerCanRotateOperator() public {
        vm.prank(alice);
        vm.expectRevert(PhiBridge.OnlyOwner.selector);
        bridge.setOperator(bob);

        bridge.setOperator(bob); // test contract is owner
        assertEq(bridge.operator(), bob);

        // new operator works, old one does not
        vm.prank(operator);
        vm.expectRevert(PhiBridge.OnlyOperator.selector);
        bridge.lockPhix(bytes32(uint256(11)), 1e18, alice);

        vm.prank(bob);
        bridge.lockPhix(bytes32(uint256(11)), 10e18, alice);
        assertEq(token.balanceOf(alice), 10e18);
    }

    function testSetOperatorZeroAddressReverts() public {
        vm.expectRevert(PhiBridge.ZeroAddress.selector);
        bridge.setOperator(address(0));
    }

    // ---------- mint path lockdown ----------

    function testNoOtherAccountCanMint() public {
        vm.prank(alice);
        vm.expectRevert(Phi.OnlyBridge.selector);
        token.mint(alice, 1e18);

        // mint is locked even before any bridge is wired
        Phi fresh = new Phi();
        vm.prank(alice);
        vm.expectRevert(Phi.OnlyBridge.selector);
        fresh.mint(alice, 1e18);
    }

    function testBridgeWiredExactlyOnce() public {
        vm.expectRevert(Phi.BridgeAlreadySet.selector);
        token.setBridge(address(bridge));

        vm.prank(alice);
        vm.expectRevert(Phi.OnlyOwner.selector);
        token.setBridge(alice);
    }

    function testPermissionlessBurn() public {
        vm.prank(operator);
        bridge.lockPhix(bytes32(uint256(12)), 50e18, alice);

        vm.prank(alice);
        token.burn(20e18);

        assertEq(token.balanceOf(alice), 30e18);
        assertEq(token.totalSupply(), 30e18);
    }

    // ---------- curve sanity at scale ----------

    function testRateAt147MApprox() public view {
        // Pure-math check of the documented sample: S=147M -> ~0.167.
        // rate = 1 / (1 + ln(1 + 147)) ; computed off-chain style via ln().
        uint256 x = ONE + 147_000_000e18 / 1e6; // 148e18
        uint256 rate = (ONE * ONE) / (ONE + bridge.ln(x));
        assertApproxEqAbs(rate, 0.167e18, 0.002e18, "rate at 147M supply");
    }
}

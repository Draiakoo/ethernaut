// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {CommonBase} from "forge-std/Base.sol";
import {Utils} from "test/utils/Utils.sol";

import {UniqueNFT} from "src/levels/UniqueNFT.sol";
import {UniqueNFTFactory} from "src/levels/UniqueNFTFactory.sol";
import {UniqueNFTAttack} from "src/attacks/UniqueNFTAttack.sol";
import {Level} from "src/levels/base/Level.sol";
import {Ethernaut} from "src/Ethernaut.sol";

import { IERC721Receiver } from "openzeppelin/token/ERC721/IERC721Receiver.sol";
import { ReentrancyGuard } from "openzeppelin/utils/ReentrancyGuard.sol";

contract TestUniqueNFT is StdInvariant, Test, Utils {
    Ethernaut ethernaut;
    UniqueNFT instance;

    address payable owner;
    address payable player;

    Vm.Wallet internal playerWallet;
    Handler internal handler;

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        address payable[] memory users = createUsers(1);

        owner = users[0];
        vm.label(owner, "Owner");

        playerWallet = vm.createWallet("player");
        player = payable(playerWallet.addr);
        vm.label(player, "Player");

        vm.startPrank(owner);
        ethernaut = getEthernautWithStatsProxy(owner);
        UniqueNFTFactory factory = new UniqueNFTFactory();
        ethernaut.registerLevel(Level(address(factory)));
        vm.stopPrank();

        vm.startPrank(player);
        instance = UniqueNFT(payable(createLevelInstance(ethernaut, Level(address(factory)), 0)));
        vm.stopPrank();

        // Set up invariant testing environment
        handler = new Handler(instance);
        vm.deal(address(handler), 1000 ether);
        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = Handler.mintNFT.selector;
        selectors[1] = Handler.transferNFT.selector;
        selectors[2] = Handler.setApprovalForAll.selector;
        selectors[3] = Handler.safeTransferFromWithoutData.selector;
        selectors[4] = Handler.safeTransferFromWithData.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check the intial state of the level and enviroment.
    function testInit() public {
        vm.startPrank(player);
        assertFalse(submitLevelInstance(ethernaut, address(instance)));
    }

    /// @notice Test the solution for the level.
    function testSolve() public {
        vm.startPrank(player, player);
        
        UniqueNFTAttack attacker = new UniqueNFTAttack();
        vm.signAndAttachDelegation(address(attacker), playerWallet.privateKey);
        instance.mintNFTEOA();

        assertTrue(submitLevelInstance(ethernaut, address(instance)));
    }

    function testSmartContractsCanNotSolveChallenge() public {
        address solverAddress = playerWallet.addr;
        vm.deal(solverAddress, 2 ether);
        vm.startPrank(solverAddress, solverAddress);
        SolverImplementationSmartContract contractSolver = new SolverImplementationSmartContract{value: 2 ether}();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        contractSolver.initiateFirstMint(address(instance));
        vm.stopPrank();
    }

    function test_manuallyTryTransferNFT() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        vm.prank(user1, user1);
        instance.mintNFTEOA();
        vm.startPrank(user2, user2);
        instance.mintNFTEOA();

        vm.expectRevert();
        instance.transferFrom(user2, user1, 2);

        vm.expectRevert();
        instance.safeTransferFrom(user2, user1, 2);

        vm.expectRevert();
        instance.safeTransferFrom(user2, user1, 2, "");

        vm.stopPrank();

        assertTrue(instance.balanceOf(user1) == 1);
    }

    function invariant_onlySingleNFTHolding() public view {
        uint256 totalSupply = instance.tokenId();
        for (uint256 i = 1; i < totalSupply; i++) {
            address NFTowner = instance.ownerOf(i);
            uint256 balance = instance.balanceOf(NFTowner);
            assertTrue(balance <= 1);
        }
    }
}

contract SolverImplementationSmartContract is IERC721Receiver{

    bool public entered;

    constructor() payable {}

    function initiateFirstMint(address target) external {
        UniqueNFT(target).mintNFTSmartContract{value: 1 ether}();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if(!entered){
            entered = true;
            UniqueNFT(msg.sender).mintNFTSmartContract{value: 1 ether}();
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract Handler is CommonBase, StdCheats, StdUtils, IERC721Receiver {
    UniqueNFT private target;

    constructor(UniqueNFT _target){
        target = _target;
    }

    function mintNFT() public {
        target.mintNFTSmartContract{value: 1 ether}();
    }

    function transferNFT(address receiver) public {
        uint256 mintedTokenId = target.mintNFTSmartContract{value: 1 ether}();
        target.transferFrom(address(this), receiver, mintedTokenId);
    }

    function setApprovalForAll(address spender, bool status) public {
        target.setApprovalForAll(spender, status);
    }

    function safeTransferFromWithoutData(address receiver) public {
        uint256 mintedTokenId = target.mintNFTSmartContract{value: 1 ether}();
        target.safeTransferFrom(address(this), receiver, mintedTokenId);
    }

    function safeTransferFromWithData(address receiver, bytes memory data) public {
        uint256 mintedTokenId = target.mintNFTSmartContract{value: 1 ether}();
        target.safeTransferFrom(address(this), receiver, mintedTokenId, data);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
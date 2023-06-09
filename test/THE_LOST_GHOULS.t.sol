// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {AmpliceGhouls} from "src/AmpliceGhouls.sol";
import "src/THE_LOST_GHOULS.sol";
import "src/Distributor.sol";

contract THE_LOST_GHOULS_Test is Test {

    THE_LOST_GHOULS public nft;
    Distributor public distributor;

    AmpliceGhouls public ampliceNft;

    address public constant alice = address(0xA11ce);
    address public constant dep = address(0xad1);

    address[101] public ampliceHolders;

    string RPC = vm.envString("RPC_URL");
    uint256 fork;
    
    function setUp() public {
        //fork = vm.createSelectFork(RPC);

        vm.warp(1680625200+1);

        vm.startPrank(dep);

            nft = new THE_LOST_GHOULS("www.test.com/");

            ampliceNft = new AmpliceGhouls();
            

        vm.stopPrank();

        for(uint256 i = 0; i<101; i++) {
            ampliceHolders[i] = address(uint160(100+i));
            vm.deal(ampliceHolders[i], 1000 ether);
            
            vm.startPrank(ampliceHolders[i]);
                payable(address(ampliceNft)).call{value: 1}("");
            vm.stopPrank();
        }

        vm.startPrank(dep);

            distributor = new Distributor(address(nft), address(ampliceNft), address(0x69), address(0x69), address(0x69));
            nft.setDistributor(address(distributor));

        vm.stopPrank();
    }

    
    function testMints() public {

        vm.deal(ampliceHolders[0], 10_000 ether);

        vm.startPrank(ampliceHolders[0]);

            distributor.ampliceMint{value: 169 ether}(0);

        vm.stopPrank();

        assertEq(nft.balanceOf(ampliceHolders[0]), 1);

        vm.deal(alice, 10_000 ether);

        vm.startPrank(alice);

            vm.expectRevert(bytes("public mint not open"));
            distributor.publicMint{value: 169 ether}(1);

        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(dep);
            distributor.openPublic();
        vm.stopPrank();

        vm.startPrank(alice);
        
            distributor.publicMint{value: 169 ether}(1);

        vm.stopPrank();

        assertEq(nft.balanceOf(alice), 1);

    }


    
    function testMintUnderpriced() public {

        vm.deal(alice, 10_000 ether);

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(dep);
            distributor.openPublic();
        vm.stopPrank();

        vm.startPrank(alice);
        
            vm.expectRevert(bytes("Insufficient payment"));
            distributor.publicMint{value: 168 ether*5}(5);

        vm.stopPrank();

        assertEq(nft.balanceOf(alice), 0);

    }

    function testMintTooMany() public {

        vm.deal(alice, 10_000 ether);

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(dep);
            distributor.openPublic();
        vm.stopPrank();

        vm.startPrank(alice);
        
            vm.expectRevert(bytes("Max 5 mints"));
            distributor.publicMint{value: 169 ether*6}(6);

        vm.stopPrank();

        assertEq(nft.balanceOf(alice), 0);

        vm.startPrank(alice);
            
            distributor.publicMint{value: 169 ether*5}(5);
            assertEq(nft.balanceOf(alice), 5);

            vm.expectRevert(bytes("Max 5 per address"));
            distributor.publicMint{value: 169 ether*1}(1);
            assertEq(nft.balanceOf(alice), 5);

        vm.stopPrank();

    }

    function testMintOwner() public {

        vm.warp(block.timestamp + 2 days);

        vm.startPrank(dep);
        
            distributor.publicMint(11);

        vm.stopPrank();

        assertEq(nft.balanceOf(dep), 11);

    }

    function testCanMintAll() public {

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(dep);
            distributor.openPublic();
        vm.stopPrank();

        for(uint256 i = 0; i<84; ++i) {

            vm.deal(address(uint160(i+1)), 10_000 ether);

            vm.startPrank(address(uint160(i+1)));

                distributor.publicMint{value: 169 ether*5}(5);
                
            vm.stopPrank();

            assertEq(nft.balanceOf(address(uint160(i+1))), 5);

            for(uint256 j = 0; j<5; ++j) {
                assert(nft.tokenOfOwnerByIndex(address(uint160(i+1)),j)<421);
                assert(nft.tokenOfOwnerByIndex(address(uint160(i+1)),j)>0);
            }
        }

        assertEq(nft.totalSupply(), 420);

        vm.deal(alice, 10_000 ether);

        vm.startPrank(alice);
        
            vm.expectRevert(bytes("Mint closed"));
            distributor.publicMint{value: 169 ether*1}(1);

        vm.stopPrank();

        assertEq(nft.balanceOf(alice), 0);

        vm.startPrank(dep);
            assertEq(address(distributor).balance, 0);
            assertEq(address(0x0152DE0F97Da0E2c00F9c228A9beC048981646c9).balance, 169 ether * 420);
        vm.stopPrank();

    }

    function testSupportsInterface() public {

        assert(nft.supportsInterface(type(IERC721).interfaceId));
        assert(nft.supportsInterface(type(IERC721Metadata).interfaceId));
        assert(nft.supportsInterface(type(IERC721Enumerable).interfaceId));
        assert(nft.supportsInterface(0x01ffc9a7)); //165
        assert(nft.supportsInterface(type(IERC2981).interfaceId));

    }

    function testMintFromContract() public {

        vm.startPrank(dep);
        
            vm.expectRevert("THE-LOST-GHOULS: caller is not the distributor");
            nft.mintFromDistributor(dep, 1);

        vm.stopPrank();

        assertEq(nft.balanceOf(dep), 0);

        vm.startPrank(alice);
        
            vm.expectRevert("THE-LOST-GHOULS: caller is not the distributor");
            nft.mintFromDistributor(alice, 1);

        vm.stopPrank();

        assertEq(nft.balanceOf(alice), 0);


    }

    function testUri() public {

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(dep);
            distributor.openPublic();
        vm.stopPrank();


        vm.deal(alice, 10_000 ether);

        vm.startPrank(alice);

            distributor.publicMint{value: 169 ether*1}(1);

        vm.stopPrank();

        uint256 id = nft.tokenOfOwnerByIndex(alice,0);

        assertEq(id,8);
        assertEq(nft.tokenURI(id),"www.test.com/8");

    }

    function testTooManyAmplices() public {

        for(uint256 i = 0; i< 100; ++i) {
            vm.startPrank(ampliceHolders[i]);
                distributor.ampliceMint{value: 169 ether}(i);
            vm.stopPrank();
        }

        vm.startPrank(ampliceHolders[100]);
            vm.expectRevert(bytes("Too many amplices."));
            distributor.ampliceMint{value: 169 ether}(100);
        vm.stopPrank();

    }



}

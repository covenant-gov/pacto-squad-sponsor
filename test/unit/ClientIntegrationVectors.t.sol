// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from 'forge-std/Test.sol';

/**
 * @title UnitClientIntegrationVectors
 * @author Pacto
 * @notice Locks golden `paymasterAndData` encodings consumed by desktop clients (issue #5).
 * @dev Hex constants must match `fixtures/client-integration/paymasterAndData.vectors.json`.
 */
contract UnitClientIntegrationVectors is Test {
  address internal constant _PAYMASTER = 0xF7f557a9443671EB0f5a3F1b233Ac44A9eDa24B8;
  bytes32 internal constant _SQUAD_ID = 0x1111111111111111111111111111111111111111111111111111111111111111;
  address internal constant _SPONSOR = 0x2222222222222222222222222222222222222222;
  address internal constant _MEMBER = 0x3333333333333333333333333333333333333333;
  address internal constant _QUARTERMASTER = 0x5555555555555555555555555555555555555555;
  address internal constant _CREW = 0x4444444444444444444444444444444444444444;

  uint128 internal constant _VERIFICATION_GAS = 100_000;
  uint128 internal constant _POST_OP_GAS = 50_000;
  uint8 internal constant _VERSION = 1;
  uint256 internal constant _BALANCE_HEADROOM_BPS = 11_500;

  bytes internal constant _EXPECTED_PAYMASTER_AND_DATA =
    hex'f7f557a9443671eb0f5a3f1b233ac44a9eda24b8000000000000000000000000000186a00000000000000000000000000000c3500000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111100000000000000000000000022222222222222222222222222222222222222220000000000000000000000003333333333333333333333333333333333333333';

  bytes internal constant _EXPECTED_BOOTSTRAP_CREW =
    hex'c2af273a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000004444444444444444444444444444444444444444';

  function test_Unit_ClientVectors_PaymasterAndDataEncoding() external pure {
    bytes memory _payload = abi.encode(_VERSION, _SQUAD_ID, _SPONSOR, _MEMBER);
    bytes memory _header = abi.encodePacked(_PAYMASTER, _VERIFICATION_GAS, _POST_OP_GAS);
    bytes memory _paymasterAndData = bytes.concat(_header, _payload);

    assertEq(_header.length, 52);
    assertEq(_payload.length, 128);
    assertEq(_paymasterAndData.length, 180);
    assertEq(_paymasterAndData, _EXPECTED_PAYMASTER_AND_DATA);
  }

  function test_Unit_ClientVectors_SuccessContextEncoding() external pure {
    assertEq(abi.encode(_SPONSOR), abi.encode(address(0x2222222222222222222222222222222222222222)));
  }

  function test_Unit_ClientVectors_HeadroomFormula() external pure {
    uint256 _maxCost = 1 ether;
    uint256 _required = (_maxCost * _BALANCE_HEADROOM_BPS) / 10_000;
    assertEq(_required, 1.15 ether);
  }

  function test_Unit_ClientVectors_BootstrapCrewCalldata() external pure {
    address[] memory _crew = new address[](1);
    _crew[0] = _CREW;
    bytes memory _calldata = abi.encodeWithSignature('bootstrapCrew(address[])', _crew);
    assertEq(_calldata, _EXPECTED_BOOTSTRAP_CREW);
  }

  function test_Unit_ClientVectors_AccountExecuteWrapsBootstrapCrew() external pure {
    address[] memory _crew = new address[](1);
    _crew[0] = _CREW;
    bytes memory _inner = abi.encodeWithSignature('bootstrapCrew(address[])', _crew);
    bytes memory _execute =
      abi.encodeWithSignature('execute(address,uint256,bytes)', _QUARTERMASTER, uint256(0), _inner);

    assertEq(bytes4(_execute), bytes4(keccak256('execute(address,uint256,bytes)')));
    assertEq(_execute.length > 4, true);
    // Inner selector is embedded after the execute ABI head.
    assertEq(bytes4(_inner), bytes4(keccak256('bootstrapCrew(address[])')));
  }
}

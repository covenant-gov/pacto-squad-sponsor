// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsor} from 'contracts/SquadSponsor.sol';
import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';

import {INavePirataRegistry} from '@pacto-gov/interfaces/factory/INavePirataRegistry.sol';

import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';

import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';

/**
 * @title UnitGasHotPaths
 * @author Pacto
 * @notice Hermetic gas baselines for squad sponsorship validation. Setup uses
 *         `pauseGasMetering` so `.gas-snapshot` reflects the measured call. Refresh with
 *         `pnpm snapshot:gas`; compare with `pnpm test:gas`.
 */
contract UnitGasHotPaths is UnitSquadSponsorBase {
  address internal constant _GOV_REGISTRY = address(uint160(uint256(keccak256('pacto.gas.REGISTRY'))));
  uint256 internal constant _TOP_HAT_ID = 1;
  uint256 internal constant _CAPTAIN_HAT = 10;
  uint256 internal constant _CREW_HAT = 11;

  address internal _crew = makeAddr('gasCrew');

  function test_Gas_CrewAndCaptainHatsEligibility() external {
    vm.pauseGasMetering();
    vm.etch(_GOV_REGISTRY, hex'00');
    vm.mockCall(
      _GOV_REGISTRY,
      abi.encodeWithSelector(INavePirataRegistry.crewAndCaptainHats.selector, _TOP_HAT_ID),
      abi.encode(_CAPTAIN_HAT, _CREW_HAT)
    );
    _mockHatWearer(_crew, _CREW_HAT, true);

    uint256[] memory _customHats = new uint256[](0);
    address _sponsorAddr = _factory.createSquadSponsor(keccak256('gas-squad'), _TOP_HAT_ID, _GOV_REGISTRY, _customHats);
    SquadSponsor _hatSponsor = SquadSponsor(payable(_sponsorAddr));
    vm.resumeGasMetering();

    _hatSponsor.isEligible(_crew);
  }

  function test_Gas_PaymasterValidation() external {
    vm.pauseGasMetering();
    address _member = makeAddr('gasMember');
    bytes32 _gasSquadId = keccak256('gas-paymaster');
    vm.deal(address(this), 5 ether);
    address _sponsor = _factory.createSquadSponsorExt{value: 5 ether}(_gasSquadId, address(this));
    SquadSponsorExt(payable(_sponsor)).setPermittedAddress(_member, true);

    bytes memory _payload = abi.encode(uint8(_paymaster.PAYMASTER_DATA_VERSION()), _gasSquadId, _sponsor, _member);
    bytes memory _header = abi.encodePacked(address(_paymaster), uint128(100_000), uint128(50_000));
    PackedUserOperation memory _userOp;
    _userOp.sender = _member;
    _userOp.paymasterAndData = bytes.concat(_header, _payload);
    vm.resumeGasMetering();

    vm.prank(_ENTRY_POINT);
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
  }
}

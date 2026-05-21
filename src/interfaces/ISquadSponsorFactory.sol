// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title ISquadSponsorFactory
 * @author Pacto
 * @notice Chain singleton that deploys per-squad sponsor clones.
 */
interface ISquadSponsorFactory {
  /*///////////////////////////////////////////////////////////////
                            ENUMS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Which sponsor implementation was cloned for a squad.
   * @param NONE Unregistered squad.
   * @param SPONSOR Hat-first `SquadSponsor` clone.
   * @param EXT Address-first `SquadSponsorExt` clone.
   */
  enum SquadVariant {
    NONE,
    SPONSOR,
    EXT
  }

  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice On-chain registry row for a squad's sponsor clone.
   * @param sponsor Sponsor clone address.
   * @param variant Which implementation was deployed.
   * @param topHatId Linked Hats top hat id (zero until wired on Ext clones).
   */
  struct SquadRecord {
    address sponsor;
    SquadVariant variant;
    uint256 topHatId;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a sponsor clone is created for a squad.
   * @param squadId Squad identifier registered by the factory.
   * @param sponsor New sponsor clone address.
   * @param variant Which implementation was deployed.
   * @param addressOwner First depositor and initial address-list admin (Ext path only).
   */
  event SquadCreated(bytes32 indexed squadId, address sponsor, SquadVariant variant, address indexed addressOwner);
  /**
   * @notice Emitted when hat sponsorship wiring is recorded.
   * @param squadId Squad identifier updated in the registry.
   * @param topHatId Linked Hats top hat id.
   */
  event HatsWiringRegistered(bytes32 indexed squadId, uint256 topHatId);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Zero address passed where forbidden.
   * @param field Name of the argument that was zero.
   */
  error SquadSponsorFactory_ZeroAddress(string field);
  /**
   * @notice Squad id already registered.
   * @param squadId Duplicate squad identifier.
   */
  error SquadSponsorFactory_SquadAlreadyExists(bytes32 squadId);
  /// @notice Caller is not the registered sponsor clone for this squad.
  error SquadSponsorFactory_NotSponsor();
  /**
   * @notice Unknown squad id.
   * @param squadId Squad identifier not found in the registry.
   */
  error SquadSponsorFactory_UnknownSquad(bytes32 squadId);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Deploy an Ext clone for `squadId` and set `msg.sender` as address owner.
   * @param squadId Squad identifier from the app.
   * @return sponsor New Ext clone address.
   */
  function createSquadSponsorExt(bytes32 squadId) external payable returns (address sponsor);

  /**
   * @notice Deploy a hat-first SquadSponsor clone for `squadId`.
   * @param squadId Squad identifier from the app.
   * @param topHatId Linked top hat id.
   * @param registry PactoGov registry (`address(0)` for custom hats only).
   * @param customEligibleHats Custom eligible hat ids.
   * @return sponsor New SquadSponsor clone address.
   */
  function createSquadSponsor(
    bytes32 squadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats
  ) external payable returns (address sponsor);

  /**
   * @notice Callback from a sponsor clone after successful `postInitialize`.
   * @param squadId Squad identifier.
   * @param topHatId Linked top hat id.
   */
  function registerHatsWiring(bytes32 squadId, uint256 topHatId) external;

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Wired paymaster for all squad sponsor clones.
   * @return paymaster Paymaster address.
   */
  function PAYMASTER() external view returns (address paymaster);

  /**
   * @notice Hats Protocol singleton used by sponsor clones.
   * @return hats Hats address.
   */
  function HATS() external view returns (address hats);

  /**
   * @notice SquadSponsor implementation used for EIP-1167 clones.
   * @return implementation Master copy address.
   */
  function sponsorImplementation() external view returns (address implementation);

  /**
   * @notice SquadSponsorExt implementation used for EIP-1167 clones.
   * @return implementation Master copy address.
   */
  function extImplementation() external view returns (address implementation);

  /**
   * @notice Registry row for a squad.
   * @param squadId Squad identifier.
   * @return record Sponsor clone, variant, and top hat id.
   */
  function squads(bytes32 squadId) external view returns (SquadRecord memory record);

  /**
   * @notice Resolve squad id from a sponsor clone address.
   * @param sponsor Sponsor clone address.
   * @return squadId Bound squad id.
   */
  function squadIdBySponsor(address sponsor) external view returns (bytes32 squadId);
}

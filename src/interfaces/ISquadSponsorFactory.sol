// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title ISquadSponsorFactory
 * @author Pacto
 * @notice Chain singleton that deploys per-squad vault and Ext clones.
 */
interface ISquadSponsorFactory {
  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice On-chain registry row for a squad's sponsor clones.
   * @param vault Vault clone address.
   * @param ext Ext clone address.
   * @param base Hat eligibility clone address (`address(0)` until wired).
   * @param topHatId Linked Hats top hat id (zero until wired).
   */
  struct SquadRecord {
    address vault;
    address ext;
    address base;
    uint256 topHatId;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when vault + Ext clones are created for a squad.
   * @param squadId Squad identifier registered by the factory.
   * @param vault New vault clone address.
   * @param ext New Ext clone address.
   * @param addressOwner First depositor and initial address-list admin.
   */
  event SquadCreated(bytes32 indexed squadId, address vault, address ext, address indexed addressOwner);
  /**
   * @notice Emitted when hat sponsorship wiring is recorded.
   * @param squadId Squad identifier updated in the registry.
   * @param topHatId Linked Hats top hat id.
   * @param base Hat eligibility clone address wired for this squad.
   */
  event HatsWiringRegistered(bytes32 indexed squadId, uint256 topHatId, address base);

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
  /// @notice Caller is not the paired Ext clone.
  error SquadSponsorFactory_NotExt();
  /**
   * @notice Unknown squad id.
   * @param squadId Squad identifier not found in the registry.
   */
  error SquadSponsorFactory_UnknownSquad(bytes32 squadId);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Deploy vault + Ext clones for `squadId` and set `msg.sender` as address owner.
   * @param squadId Squad identifier from the app.
   * @return vault New vault clone address.
   * @return ext New Ext clone address.
   */
  function createSquad(bytes32 squadId) external payable returns (address vault, address ext);

  /**
   * @notice Callback from an Ext clone after successful `postInitialize`.
   * @param squadId Squad identifier.
   * @param topHatId Linked top hat id.
   * @param base Hat eligibility clone address.
   */
  function registerHatsWiring(bytes32 squadId, uint256 topHatId, address base) external;

  /**
   * @notice Clone a hat eligibility module and wire it via the squad Ext clone.
   * @dev `msg.sender` must satisfy Ext `postInitialize` auth (factory, address owner, or Hats admin).
   * @param squadId Squad identifier.
   * @param topHatId Linked top hat id.
   * @param registry PactoGov registry (`address(0)` for custom hats only).
   * @param customEligibleHats Custom eligible hat ids.
   * @return base New hat clone address.
   */
  function cloneAndWireSquadSponsor(
    bytes32 squadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats
  ) external returns (address base);

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Wired paymaster for all squad vault clones.
   * @return paymaster Paymaster address.
   */
  function PAYMASTER() external view returns (address paymaster);

  /**
   * @notice Hats Protocol singleton used by Ext clones.
   * @return hats Hats address.
   */
  function HATS() external view returns (address hats);

  /**
   * @notice Vault implementation used for EIP-1167 clones.
   * @return implementation Master copy address.
   */
  function vaultImplementation() external view returns (address implementation);

  /**
   * @notice Ext implementation used for EIP-1167 clones.
   * @return implementation Master copy address.
   */
  function extImplementation() external view returns (address implementation);

  /**
   * @notice Hat eligibility implementation used for EIP-1167 clones.
   * @return implementation Master copy address.
   */
  function sponsorImplementation() external view returns (address implementation);

  /**
   * @notice Registry row for a squad.
   * @param squadId Squad identifier.
   * @return record Vault, Ext, optional base, and top hat id.
   */
  function squads(bytes32 squadId) external view returns (SquadRecord memory record);

  /**
   * @notice Resolve squad id from a vault clone address.
   * @param vault Vault clone address.
   * @return squadId Bound squad id.
   */
  function squadIdByVault(address vault) external view returns (bytes32 squadId);

  /**
   * @notice Resolve squad id from an Ext clone address.
   * @param ext Ext clone address.
   * @return squadId Bound squad id.
   */
  function squadIdByExt(address ext) external view returns (bytes32 squadId);
}

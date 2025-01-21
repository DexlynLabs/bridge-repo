module hp_isms::events {
  friend hp_isms::multisig_ism;

  // event resources
  struct OwnershipTransferStarted has store, drop {
    previous_owner:address,
    new_owner:address,
  }

  struct OwnershipTransferred has store, drop {
    previous_owner:address,
    new_owner:address,
  }


  // create events
  public(friend) fun new_initiate_transfer_event(
    previous_owner:address,
    new_owner:address,
  ): OwnershipTransferStarted {
    OwnershipTransferStarted { previous_owner, new_owner}
  }

  public(friend) fun new_transfer_event(
    previous_owner:address,
    new_owner:address,
  ): OwnershipTransferred {
    OwnershipTransferred { previous_owner, new_owner}
  }

}
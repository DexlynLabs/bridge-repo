module hp_router::events {
  
  friend hp_router::router;

  // event resources
  struct EnrollRemoteRouterEvent has store, drop {
    domain: u32,
    router: vector<u8>
  }

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


  public(friend) fun new_enroll_remote_router_event(
    domain: u32,
    router: vector<u8>
  ): EnrollRemoteRouterEvent {
    EnrollRemoteRouterEvent { domain, router }
  }

}
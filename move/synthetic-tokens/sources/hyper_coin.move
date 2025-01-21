///
///
/// This module itself is a token contract based on hyperlane token bridge standards
/// Its simillar to HyperERC20.sol
/// Required Hook -> None (may be we can implement Protocol Fee)
/// Default Hook -> Merkle Tree Message ID
/// ISM -> Multisig Merkle Tree Message ID
///
module synthetic_tokens::hyper_coin {

    use std::error;
    use std::vector;
    use std::string;
    use std::signer;
    use std::bcs;
    use aptos_std::type_info::type_of;
    use aptos_std::table;
    use aptos_std::table::Table;
    use hp_router::router;
    use hp_library::msg_utils;
    use hp_library::h256;

    use hp_library::token_msg_utils;
    use hp_mailbox::mailbox;
    use aptos_framework::coin;
    use aptos_framework::aptos_account;
    use aptos_framework::event::emit;
    use aptos_framework::account::{Self,SignerCapability};

    // Constants

    const DEFAULT_GAS_AMOUNT: u256 = 1_000_000_000;

    // Errors
    const ERROR_INVALID_DOMAIN: u64 = 0;
    const EDESTINATION_DECIMAL_NOT_SET: u64 = 1;
    const ESOURCE_DECIMAL_NOT_SET: u64 = 2;
    const EAMOUNT_TOO_SMALL: u64 = 3;

    struct HyperSupraCoin {} //Need to be the coin type

    struct State has key {
        cap: router::RouterCap<HyperSupraCoin>,
        destination_decimals: Table<u32, u8>,
        signer_cap: SignerCapability,
        last_id: vector<u8>
    }

    struct CoinCapability has key {
        burn_cap: coin::BurnCapability<HyperSupraCoin>,
        freeze_cap: coin::FreezeCapability<HyperSupraCoin>,
        mint_cap: coin::MintCapability<HyperSupraCoin>,
    }


    /// destination The identifier of the destination chain.
    /// recipient The address of the recipient on the destination chain.
    /// amount The amount of tokens burnt on the origin chain.
    #[event]
    struct SentTransferRemote has store,drop {
        destination: u32,
        receipient: vector<u8>,
        amount: u64,
    }

    /// origin The identifier of the origin chain.
    /// recipient The address of the recipient on the destination chain.
    /// amount The amount of tokens minted on the destination chain.
    #[event]
    struct ReceivedTransferRemote has store,drop {
        origin: u32,
        receipient: address,
        amount: u64,
    }

    /// Initialize Module
    fun init_module(account: &signer) {
        let cap = router::init<HyperSupraCoin>(account);

        let (resource_signer, signer_cap) = account::create_resource_account(account, bcs::to_bytes(&type_of<HyperSupraCoin>()));
        move_to<State>(&resource_signer, State {
            cap,
            destination_decimals: table::new(),
            signer_cap: signer_cap,
            last_id: vector::empty()
        });

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<HyperSupraCoin>(
            account,
            string::utf8(b"HyperSupraCoin"),
            string::utf8(b"HyperCoin"),
            6,
            true,
        );
        coin::register<HyperSupraCoin>(account);

        move_to(&resource_signer, CoinCapability {
            burn_cap,
            freeze_cap,
            mint_cap,
        });
    }

    /// This function can only be called by deployer
    /// It helps to set the decimals of the token in the destination domain thats going to be bridged
    public entry fun set_destination_token_decimal(admin: &signer, dest_domain: u32, dest_decimal: u8) acquires State {
        assert!(signer::address_of(admin) == @synthetic_tokens, 404);
        let state = borrow_global_mut<State>(generate_token_deposit_account_address());
        table::upsert(&mut state.destination_decimals, dest_domain, dest_decimal);
    }

    /// This function helps to transfer funds from source chain to destination chain without paying for destination gas
    public entry fun transfer_remote(
        account: &signer,
        dest_domain: u32,
        dest_receipient: vector<u8>,
        amount: u64) acquires CoinCapability, State {
        let state = borrow_global_mut<State>(generate_token_deposit_account_address());
        let data_amount: u256;
        let source_decimals = coin::decimals<HyperSupraCoin>();
        /// assert for destination decimals for graceful exit
        assert!(table::contains(&state.destination_decimals,dest_domain),error::not_found(EDESTINATION_DECIMAL_NOT_SET));
        let destination_decimals = *table::borrow(&state.destination_decimals, dest_domain);
        if (source_decimals < destination_decimals) {
            data_amount = (amount as u256) * calculate_power(10, ((destination_decimals - source_decimals) as u16));
        }
        else if (source_decimals == destination_decimals) {
            data_amount = (amount as u256);
        }
        else {
            data_amount = (amount as u256) / calculate_power(10, ((source_decimals - destination_decimals) as u16));
            assert!(data_amount > 0, EAMOUNT_TOO_SMALL);
            amount = (data_amount * calculate_power(10, ((source_decimals - destination_decimals) as u16)) as u64);
        };
        let sender = signer::address_of(account);
        let caps = borrow_global<CoinCapability>(generate_token_deposit_account_address());
        coin::burn_from<HyperSupraCoin>(sender, amount, &caps.burn_cap);
        state.last_id = mailbox::dispatch<HyperSupraCoin>(
            dest_domain,
            token_msg_utils::format_token_message_into_bytes(
                h256::from_bytes(&dest_receipient),
                data_amount,
                dest_receipient
            ),
            &state.cap
        );
        emit(SentTransferRemote{destination:dest_domain,receipient:dest_receipient,amount});
    }

    /// This function helps to transfer funds from source chain to destination chain by paying the destination gas
    public entry fun transfer_remote_with_gas(
        account: &signer,
        dest_domain: u32,
        dest_receipient: vector<u8>,
        amount: u64) acquires CoinCapability, State {
        let state = borrow_global_mut<State>(generate_token_deposit_account_address());
        let data_amount: u256;
        let source_decimals = coin::decimals<HyperSupraCoin>();
        /// assert for destination decimals for graceful exit
        assert!(table::contains(&state.destination_decimals,dest_domain),error::not_found(EDESTINATION_DECIMAL_NOT_SET));
        let destination_decimals = *table::borrow(&state.destination_decimals, dest_domain);
        if (source_decimals < destination_decimals) {
            data_amount = (amount as u256) * calculate_power(10, ((destination_decimals - source_decimals) as u16));
        }
        else if (source_decimals < destination_decimals) {
            data_amount = (amount as u256);
        }
        else {
            data_amount = (amount as u256) / calculate_power(10, ((source_decimals - destination_decimals) as u16));
            assert!(data_amount > 0, EAMOUNT_TOO_SMALL);
            amount = (data_amount * calculate_power(10, ((source_decimals - destination_decimals) as u16)) as u64);
        };
        let sender = signer::address_of(account);
        let caps = borrow_global<CoinCapability>(generate_token_deposit_account_address());
        coin::burn_from(sender, amount, &caps.burn_cap);
        state.last_id = mailbox::dispatch_with_gas<HyperSupraCoin>(
            account,
            dest_domain,
            token_msg_utils::format_token_message_into_bytes(
                h256::from_bytes(&dest_receipient),
                data_amount,
                dest_receipient
            ),
            DEFAULT_GAS_AMOUNT,
            &state.cap
        );
        emit(SentTransferRemote{destination:dest_domain,receipient:dest_receipient,amount});
    }


    /// This function helps to credit the bridged funds
    public entry fun handle_message(
        message: vector<u8>,
        metadata: vector<u8>
    ) acquires State, CoinCapability {
        let state = borrow_global_mut<State>(generate_token_deposit_account_address());

        mailbox::handle_message<HyperSupraCoin>(
            message,
            metadata,
            &state.cap
        );

        let src_domain = msg_utils::origin_domain(&message);

        let message_body = msg_utils::body(&message);

        let receipient_address = token_msg_utils::recipient(&message_body);
        let receipient_amount = token_msg_utils::amount(&message_body);


        let destination_decimals = coin::decimals<HyperSupraCoin>();

        /// assert for source decimals for graceful exit
        assert!(table::contains(&state.destination_decimals,src_domain),error::not_found(ESOURCE_DECIMAL_NOT_SET));
        let source_decimals = *table::borrow(&state.destination_decimals, src_domain);

        let amount;

        if (source_decimals < destination_decimals) {
            amount = (receipient_amount * calculate_power(
                10,
                ((destination_decimals - source_decimals) as u16)
            ) as u64);
        }
        else if (source_decimals == destination_decimals) {
            amount = (receipient_amount as u64);
        }
        else {
            amount = ((receipient_amount / calculate_power(
                10,
                ((source_decimals - destination_decimals) as u16)
            )) as u64);
        };


        let caps = borrow_global<CoinCapability>(generate_token_deposit_account_address());
        let coins = coin::mint<HyperSupraCoin>(
            amount,
            &caps.mint_cap
        ); // Here we need to take care of overflow underflow
        aptos_account::deposit_coins<HyperSupraCoin>(receipient_address, coins);
        emit(ReceivedTransferRemote{origin:src_domain,receipient:receipient_address ,amount});
    }

    #[view]
    public fun view_last_id(): vector<u8> acquires State {
        let state = borrow_global<State>(generate_token_deposit_account_address());
        state.last_id
    }



    #[view]
    /// Calculates the power of a base raised to an exponent. The result ofbaseraised to the power ofexponent
    public fun calculate_power(base: u128, exponent: u16): u256 {
        let result: u256 = 1;
        let base: u256 = (base as u256);
        assert!((base | (exponent as u256)) != 0, 3);
        if (base == 0) { return 0 };
        while (exponent != 0)
            {
                if ((exponent & 0x1) == 1)
                    {
                        result = result * base;
                    };
                base = base * base;
                exponent = (exponent >> 1);
            };
        result
    }

    #[view]
    public fun generate_token_deposit_account_address(): address {
        account::create_resource_address(&@synthetic_tokens, bcs::to_bytes(&type_of<HyperSupraCoin>()))
    }


}
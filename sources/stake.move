// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A position holding share tokens registered against a `RoyaltyPool`.
///
/// Stakes are owned objects with an immutable balance — to increase a holder's
/// total staked amount, mint additional Stake objects rather than modify an
/// existing one. This mirrors Sui's native staking model.
///
/// Each stake tracks the royalty pools it is currently registered with via an
/// inline `VecMap<TypeName, Registration>`, keyed by the pool's `Currency`
/// `TypeName`. The stake cannot be destroyed while any registrations remain.
/// Pool registrations are mutated by `royalty_pool::pool` through the
/// package-private accessors below.
module royalty_pool::stake;

use std::type_name::TypeName;
use sui::balance::Balance;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};

// === Errors ===

const EZeroBalance: u64 = 0;
const EPoolsRegistered: u64 = 1;

// === Structs ===

public struct Stake<phantom Share> has key, store {
    id: UID,
    /// The staked balance. Immutable after creation.
    balance: Balance<Share>,
    /// Active royalty-pool registrations, keyed by `Currency` `TypeName`.
    /// Must be empty to destroy.
    registrations: VecMap<TypeName, Registration>,
}

/// Per-stake registration record. One entry per pool the stake is registered
/// with, stored inline on the stake.
public struct Registration has copy, drop, store {
    pool_id: ID,
    last_claim_index: u256,
}

// === Events ===

public struct StakeCreatedEvent<phantom Share> has copy, drop {
    stake_id: ID,
    amount: u64,
}

public struct StakeDestroyedEvent<phantom Share> has copy, drop {
    stake_id: ID,
    amount: u64,
}

// === Public Functions ===

/// Create a new stake with the given balance.
///
/// Aborts if `balance` is zero.
public fun new<Share>(balance: Balance<Share>, ctx: &mut TxContext): Stake<Share> {
    assert!(balance.value() > 0, EZeroBalance);

    let stake = Stake<Share> {
        id: object::new(ctx),
        balance,
        registrations: vec_map::empty(),
    };

    emit(StakeCreatedEvent<Share> {
        stake_id: stake.id(),
        amount: stake.value(),
    });

    stake
}

/// Destroy a stake and reclaim its balance.
///
/// Aborts if the stake is still registered with any royalty pools.
public fun destroy<Share>(stake: Stake<Share>): Balance<Share> {
    let Stake { id, balance, registrations } = stake;

    assert!(registrations.is_empty(), EPoolsRegistered);
    registrations.destroy_empty();

    emit(StakeDestroyedEvent<Share> {
        stake_id: id.to_inner(),
        amount: balance.value(),
    });

    id.delete();
    balance
}

// === View Functions ===

public fun id<Share>(self: &Stake<Share>): ID {
    self.id.to_inner()
}

public fun balance<Share>(self: &Stake<Share>): &Balance<Share> {
    &self.balance
}

public fun value<Share>(self: &Stake<Share>): u64 {
    self.balance.value()
}

/// Number of royalty pools this stake is currently registered with.
public fun registration_count<Share>(self: &Stake<Share>): u64 {
    self.registrations.length()
}

public fun has_registration<Share>(self: &Stake<Share>, currency: &TypeName): bool {
    self.registrations.contains(currency)
}

public fun get_registration<Share>(self: &Stake<Share>, currency: &TypeName): &Registration {
    self.registrations.get(currency)
}

public fun registration_pool_id(r: &Registration): ID {
    r.pool_id
}

public fun registration_last_claim_index(r: &Registration): u256 {
    r.last_claim_index
}

// === Package Functions ===

/// Construct a fresh `Registration` value. Package-private so only the pool
/// module can mint registrations (always paired with `add_registration`).
public(package) fun new_registration(pool_id: ID, last_claim_index: u256): Registration {
    Registration {
        pool_id,
        last_claim_index,
    }
}

/// Insert a registration for `currency`. The pool module is expected to check
/// `has_registration` first; this function will abort on duplicate insert via
/// `VecMap::insert`.
public(package) fun add_registration<Share>(
    self: &mut Stake<Share>,
    currency: TypeName,
    registration: Registration,
) {
    self.registrations.insert(currency, registration);
}

/// Remove and return the registration for `currency`. Aborts if absent.
public(package) fun remove_registration<Share>(
    self: &mut Stake<Share>,
    currency: &TypeName,
): Registration {
    let (_, registration) = self.registrations.remove(currency);
    registration
}

/// Mutable access to a registration. Aborts if absent.
public(package) fun registration_mut<Share>(
    self: &mut Stake<Share>,
    currency: &TypeName,
): &mut Registration {
    self.registrations.get_mut(currency)
}

public(package) fun set_last_claim_index(r: &mut Registration, idx: u256) {
    r.last_claim_index = idx;
}

// === Test Functions ===
//
// Accessors for this module's event payloads — the event structs' fields are
// module-private and carry no other public reader.

#[test_only]
public fun created_event_fields<Share>(event: &StakeCreatedEvent<Share>): (ID, u64) {
    (event.stake_id, event.amount)
}

#[test_only]
public fun destroyed_event_fields<Share>(event: &StakeDestroyedEvent<Share>): (ID, u64) {
    (event.stake_id, event.amount)
}

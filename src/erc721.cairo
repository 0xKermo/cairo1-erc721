#[contract]
mod erc721 {
    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;
    use starknet::ContractAddressIntoFelt252;
    use traits::Into;
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use starknet::ContractAddressZeroable;
    use integer::u128_safe_divmod;
    use integer::u128_as_non_zero;
    use gas::withdraw_gas;
    use gas::withdraw_gas_all;
    use array::array_new;
    use array::array_append;
    use hash::LegacyHash;
    
    const MAX_SUPPLY:felt252 = 1000;
    const WL_SUPPLY:felt252 = 100;
    const WL_PER_ADDRESS:felt252= 1;
    const PUBLIC_PER_ADDRESS:felt252= 1;
    

    struct Storage {
        _name: felt252,
        _symbol: felt252,
        owners: LegacyMap::<u256, ContractAddress>,
        balances: LegacyMap::<ContractAddress, u256>,
        _total_supply: u256,
        token_approvals: LegacyMap::<u256, ContractAddress>,
        // (owner, operator)
        operator_approvals: LegacyMap::<(ContractAddress, ContractAddress), bool>,
        base_uri: LegacyMap::<felt252, felt252>, // (id, uri)
        base_uri_len: felt252,
        contract_owner: ContractAddress,
        _merkle_root:felt252,
    }

    #[event]
    fn Approval(owner: ContractAddress, to: ContractAddress, token_id: u256) {}

    #[event]
    fn Transfer(from: ContractAddress, to: ContractAddress, token_id: u256) {}

    #[event]
    fn ApprovalForAll(owner: ContractAddress, operator: ContractAddress, approved: bool) {}

    #[constructor]
    fn constructor(name_: felt252, symbol_: felt252, owner_: ContractAddress,root:felt252) {
        _name::write(name_);
        _symbol::write(symbol_);
        contract_owner::write(owner_);
        _merkle_root::write(root);
    }

    #[view]
    fn name() -> felt252 {
        _name::read()
    }

    #[view]
    fn symbol() -> felt252 {
        _symbol::read()
    }

    #[view]
    fn balance_of(account: ContractAddress) -> u256 {
        assert(!account.is_zero(), 'ERC721: address zero');
        balances::read(account)
    }

    #[view]
    fn owner_of(token_id: u256) -> ContractAddress {
        let owner = _owner_of(token_id);
        _require_minted(token_id);
        assert(!owner.is_zero(), 'owner nonexistent');
        owner
    }

    #[view]
    fn get_approved(token_id: u256) -> ContractAddress {
        _require_minted(token_id);
        token_approvals::read(token_id)
    }

    #[view]
    fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool {
        operator_approvals::read((owner, operator))
    }

    #[view]
    fn total_supply() -> u256 {
        _total_supply::read()
    }

    #[view]
    fn token_uri(token_id: u256) -> Array::<felt252> {
        _require_minted(token_id);
        let mut base_uri_array = ArrayTrait::<felt252>::new();
        let index = 0;
        let json_extension = '.json';
        _base_uri(index, base_uri_len::read(), ref base_uri_array);
        let mut splitted_token_id = ArrayTrait::<felt252>::new();
        split_digits(token_id.low, 10_u128, ref splitted_token_id);
        merge_arrays(
            ref base_uri_array, base_uri_array.len(), ref splitted_token_id, splitted_token_id.len()
        );
        base_uri_array.append(json_extension);
        base_uri_array
    }


    fn _base_uri(index: felt252, array_len: felt252, ref uri_array: Array::<felt252>) {
        match gas::withdraw_gas_all(get_builtin_costs()) {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = ArrayTrait::new();
                data.append('Out of gas');
                panic(data);
            },
        }
        if (index == array_len) {
            return ();
        }
        let uri = base_uri::read(index);
        uri_array.append(uri);
        return _base_uri(index + 1, array_len, ref uri_array);
    }

    #[view]
    fn owner() -> ContractAddress {
        contract_owner::read()
    }

    #[view]
    fn merkle_root() -> felt252 {
        _merkle_root::read()
    }

    #[external]
    fn set_base_uri(mut uri: Array::<felt252>) {
        only_owner();
        let uri_len = uri.len();
        let mut index = 0_u32;
        _set_base_uri(index, uri_len, ref uri);
        base_uri_len::write(uri_len.into());
    }

    fn _set_base_uri(index: u32, uri_len: u32, ref uri: Array::<felt252>) {
        match gas::withdraw_gas_all(get_builtin_costs()) {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = ArrayTrait::new();
                data.append('Out of gas');
                panic(data);
            },
        }
        if (index == uri_len) {
            return ();
        }
        base_uri::write(index.into(), *uri.at(index));
        _set_base_uri(index + 1_u32, uri_len, ref uri);
    }

    #[external]
    fn set_approval_for_all(operator: ContractAddress, approved: bool) {
        _set_approval_for_all(get_caller_address(), operator, approved);
    }

    #[external]
    fn approve(to: ContractAddress, token_id: u256) {
        let owner = _owner_of(token_id);
        _require_minted(token_id);
        assert(!to.is_zero(), 'approve to the zero address');
        assert(to.into() != owner.into(), 'Approval to current owner');
        assert(
            get_caller_address().into() == owner.into() | is_approved_for_all(
                owner, get_caller_address()
            ),
            'ERC721:Not token owner'
        );
        _approve(to, token_id);
    }

    #[external]
    fn transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256) {
        _require_minted(token_id);
        let is_approved = _is_approved_or_owner(get_caller_address(), token_id);
        assert(is_approved, 'ERC721: transfer caller is not owner nor approved');
        _transfer(from, to, token_id);
    }

    #[external]
    fn burn(token_id: u256) {
        let owner = _owner_of(token_id);
        _require_minted(token_id);
        assert(
            get_caller_address().into() == owner.into() | is_approved_for_all(
                owner, get_caller_address()
            ),
            'ERC721:Not token owner'
        );
        _burn(token_id);
    }

    #[external]
    fn wl_mint(mut proof: Array::<felt252>) {
        let token_id = _total_supply::read();
        let mut root = _merkle_root::read();
        let leaf = LegacyHash::hash(get_caller_address().into(),get_caller_address().into());
        let res = merkle_verify(root,leaf, ref proof);
        assert(res, 'proof verification failed');
        _mint(get_caller_address(), token_id + 1.into());
    }
    
     #[external]
    fn mint() {
        let token_id = _total_supply::read();
        _mint(get_caller_address(), token_id + 1.into());
    }

    #[external]
    fn set_merkle_root(merkle_root_:felt252) {
        only_owner();
        _merkle_root::write(merkle_root_);
    }

    fn _approve(to: ContractAddress, token_id: u256) {
        token_approvals::write(token_id, to);
        Approval(owner_of(token_id), to, token_id);
    }

    fn _set_approval_for_all(owner: ContractAddress, operator: ContractAddress, approved: bool) {
        // ContractAddress equation is not supported so into() is used here
        assert(owner.into() != operator.into(), 'ERC721: approve to caller');
        assert(!owner.is_zero() | !operator.is_zero(), 'caller or operator zero address');
        assert(approved | !approved, 'ERC721: approve value invalid');
        operator_approvals::write((owner, operator), approved);
        ApprovalForAll(owner, operator, approved);
    }

    fn _exists(token_id: u256) -> bool {
        !_owner_of(token_id).is_zero()
    }


    fn _owner_of(token_id: u256) -> ContractAddress {
        owners::read(token_id)
    }


    fn _mint(to: ContractAddress, token_id: u256) {
        assert(!to.is_zero(), 'ERC721: mint to 0');
        assert(!_exists(token_id), 'ERC721: already minted');
        balances::write(to, balances::read(to) + 1.into());
        owners::write(token_id, to);
        _total_supply::write(_total_supply::read() + 1.into());
        Transfer(contract_address_const::<0>(), to, token_id);
    }


    fn _burn(token_id: u256) {
        let owner = owner_of(token_id);
        token_approvals::write(token_id, contract_address_const::<0>());

        balances::write(owner, balances::read(owner) - 1.into());
        owners::write(token_id, contract_address_const::<0>());
        _total_supply::write(_total_supply::read() - 1.into());
        Transfer(owner, contract_address_const::<0>(), token_id);
    }


    fn _require_minted(token_id: u256) {
        assert(_exists(token_id), 'ERC721: invalid token ID');
    }


    fn _is_approved_or_owner(spender: ContractAddress, token_id: u256) -> bool {
        let owner = owners::read(token_id);
        spender.into() == owner.into() | is_approved_for_all(
            owner, spender
        ) | get_approved(token_id).into() == spender.into()
    }

    fn _transfer(from: ContractAddress, to: ContractAddress, token_id: u256) {
        assert(from.into() == owner_of(token_id).into(), 'Transfer from incorrect owner');
        assert(!to.is_zero(), 'ERC721: transfer to 0');

        token_approvals::write(token_id, contract_address_const::<0>());

        balances::write(from, balances::read(from) - 1.into());
        balances::write(to, balances::read(to) + 1.into());

        owners::write(token_id, to);

        Transfer(from, to, token_id);
    }

    fn only_owner() {
        assert(get_caller_address().into() == owner().into(), 'ERC721:Not contract owner');
    }

    fn split_digits(mut num: u128, base: u128, ref data: Array::<felt252>) {
        match withdraw_gas() {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = array_new::<felt252>();
                array_append::<felt252>(ref data, 'OOG');
                panic(data);
            },
        }

        if (num == 0_u128) {
            return ();
        }
        let (res, rem) = u128_safe_divmod(num, u128_as_non_zero(base));
        data.append(rem.into());
        num = res;
        return split_digits(num, base, ref data);
    }


    fn merge_arrays(
        ref array_1: Array::<felt252>,
        array_1_len: u32,
        ref array_2: Array::<felt252>,
        array_2_len: u32
    ) {
        match withdraw_gas() {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = array_new::<felt252>();
                array_append::<felt252>(ref data, 'OOG');
                panic(data);
            },
        }
        if (array_2_len == 0_u32) {
            return ();
        }
        array_1.append(*array_2.at(array_2_len - 1_u32));
        return merge_arrays(ref array_1, array_1_len, ref array_2, array_2_len - 1_u32);
    }

// Merkle tree verification
    fn merkle_verify(root:felt252, leaf: felt252, ref proof: Array::<felt252>) -> bool {
        let proof_len = proof.len();
        let calc_root = _merkle_verify_body(leaf, ref proof, proof_len, 0_u32);
        if (calc_root == root) {
            return true;
        } else {
            return false;
        }
    }


    fn _merkle_verify_body(
        leaf: felt252, ref proof: Array::<felt252>, proof_len: u32, index: u32
    ) -> felt252 {
       match gas::withdraw_gas_all(get_builtin_costs()) {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = ArrayTrait::new();
                data.append('Out of gas');
                panic(data);
            },
        }
        if (proof_len == 0_u32) {
            return leaf;
        }
        let n = _hash_sorted(leaf, *proof.at(index));
        return _merkle_verify_body(n, ref proof, proof_len - 1_u32, index + 1_u32);
    }

    fn _hash_sorted(a: felt252, b: felt252) -> felt252 {
          match withdraw_gas() {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = array_new::<felt252>();
                array_append::<felt252>(ref data, 'OOG');
                panic(data);
            },
        }
        if (a.into() < b.into()) {
            return LegacyHash::hash(a, b);
        } else {
            return LegacyHash::hash(b, a);
        }
    }

}

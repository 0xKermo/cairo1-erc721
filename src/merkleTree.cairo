use hash::LegacyHash;
use traits::Into;
use gas::withdraw_gas_all;
use array::array_new;
use array::array_append;
use array::ArrayTrait;

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
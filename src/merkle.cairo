use hash::LegacyHash;
use array::ArrayTrait;


fn merkle_verify(leaf: felt252, root: felt252, mut proof: Array::<felt252>) -> bool {
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
    // gas
    if (proof_len == 0_u32) {
        return leaf;
    }
    let n = _hash_sorted_pair(leaf, *proof.at(index));
    let res = _merkle_verify_body(n, ref proof, proof_len - 1_u32, index + 1_u32);
    return res;
}

fn _hash_sorted_pair(a: felt252, b: felt252) -> felt252 {
    if (a < b) {
        return LegacyHash::hash(a, b);
    } else {
        return LegacyHash::hash(b, a);
    }
}

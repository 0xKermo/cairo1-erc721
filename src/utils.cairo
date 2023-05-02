use integer::u128_safe_divmod;
use integer::u128_as_non_zero;
use gas::withdraw_gas;
use array::array_new;
use array::array_append;
use array::ArrayTrait;
use result::ResultTrait;
use traits::Into;

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
    return split_digits(res, base, ref data);
}


fn merge_arrays(
    ref array_1: Array::<felt252>, array_1_len: u32, ref array_2: Array::<felt252>, array_2_len: u32
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

use starknet::ContractAddress;
use starknet::account::Call;

#[starknet::interface]
trait IView<TContractState> {
    fn standard_multicall(self: @TContractState, calls: Array<Call>) -> Array<Span<felt252>>;
// fn composable_multicall(
//     self: @TContractState,  calls: Array<Call>
// ) -> Array<Span<felt252>>;
}


#[starknet::contract]
mod View {
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};
    use traits::Into;
    use array::{ArrayTrait};
    use zeroable::Zeroable;
    use starknet::class_hash::ClassHash;
    use integer::{u256_safe_divmod, u256_as_non_zero};
    use starknet::account::Call;
    use super::IView;

    #[storage]
    struct Storage {}


    #[external(v0)]
    impl MulticallsView of IView<ContractState> {
        fn standard_multicall(self: @ContractState, calls: Array<Call>) -> Array<Span<felt252>> {
            _execute_calls(calls)
        }
    }

    #[internal]
    fn _execute_calls(mut calls: Array<Call>) -> Array<Span<felt252>> {
        let mut res = ArrayTrait::new();
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    let _res = _execute_single_call(call);
                    res.append(_res);
                },
                Option::None(_) => {
                    break ();
                },
            };
        };
        res
    }

    #[internal]
    fn _execute_single_call(call: Call) -> Span<felt252> {
        let Call{to, selector, calldata } = call;
        starknet::call_contract_syscall(to, selector, calldata.span()).unwrap()
    }
}

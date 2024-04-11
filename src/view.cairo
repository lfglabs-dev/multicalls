use starknet::ContractAddress;
use starknet::account::Call;

#[starknet::interface]
trait IView<TContractState> {
    fn standard_multicall(self: @TContractState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn composable_multicall(self: @TContractState, calls: Array<Call>) -> Array<Span<felt252>>;
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


    #[abi(embed_v0)]
    impl MulticallsView of IView<ContractState> {
        fn standard_multicall(self: @ContractState, calls: Array<Call>) -> Array<Span<felt252>> {
            execute_sequence(calls)
        }

        fn composable_multicall(self: @ContractState, calls: Array<Call>) -> Array<Span<felt252>> {
            execute_composition(calls)
        }
    }

    fn execute_composition(mut calls: Array<Call>) -> Array<Span<felt252>> {
        let mut res = ArrayTrait::new();
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    let Call{to, selector, calldata } = call;
                    let _compiled_calldata = compile_calldata(res.span(), calldata);
                    let _res = starknet::call_contract_syscall(to, selector, calldata).unwrap();
                    res.append(_res);
                },
                Option::None(_) => { break (); },
            };
        };
        res
    }

    fn compile_calldata(res: Span<Span<felt252>>, mut calldata: Span<felt252>) -> Array<felt252> {
        match calldata.pop_front() {
            Option::Some(felt) => {
                let mut _output_calldata = (if *felt == 0 {
                    *calldata.pop_front().expect('expected a felt after prefix 0')
                } else if *felt == 1 {
                    *(*(res
                        .get(
                            (*calldata.pop_front().expect('expected a felt after prefix 1'))
                                .try_into()
                                .expect('invalid call_id value')
                        )
                        .expect('no call found for this call_id')
                        .unbox()))
                        .get(
                            (*calldata.pop_front().expect('expected 2 felts after prefix 1'))
                                .try_into()
                                .expect('invalid value_id value')
                        )
                        .expect('no felt found at this value_id')
                        .unbox()
                } else {
                    panic_with_felt252('unexpected prefix')
                });
                compile_calldata(res, calldata);
                ArrayTrait::new()
            },
            Option::None(_) => ArrayTrait::new(),
        }
    }

    fn execute_sequence(mut calls: Array<Call>) -> Array<Span<felt252>> {
        let mut res = ArrayTrait::new();
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    let _res = _execute_single_call(call);
                    res.append(_res);
                },
                Option::None(_) => { break (); },
            };
        };
        res
    }

    fn _execute_single_call(call: Call) -> Span<felt252> {
        let Call{to, selector, calldata } = call;
        starknet::call_contract_syscall(to, selector, calldata).unwrap()
    }
}

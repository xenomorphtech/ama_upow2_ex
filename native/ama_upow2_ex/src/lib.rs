#[macro_use]
extern crate rustler;
extern crate rustler_codegen;

use rustler::{Binary, Env, NifResult, OwnedBinary};
mod upow2;
use rustler::types::atom::ok; // returns {:ok, …}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn tensormath<'a>(
    env: Env<'a>,
    epoch: u32,
    segment_vr_hash: Binary<'a>,
    trainer: Binary<'a>,
    pop: Binary<'a>,
    computor: Binary<'a>,
) -> NifResult<(rustler::types::atom::Atom, Binary<'a>, Binary<'a>)> {
    // ---- call your CPU-heavy function ---------------------------------------
    let (hash, solution) = upow2::tensormath(
        epoch,
        segment_vr_hash.as_slice(),
        trainer.as_slice(),
        pop.as_slice(),
        computor.as_slice(),
    );

    let hash_bin = {
        let mut ob = OwnedBinary::new(hash.as_bytes().len()).unwrap();
        ob.as_mut_slice().copy_from_slice(hash.as_bytes());
        ob.release(env) // -> Binary<'env>
    };

    let sol_bin = {
        let mut ob = OwnedBinary::new(solution.len()).unwrap();
        ob.as_mut_slice().copy_from_slice(&solution);
        ob.release(env) // -> Binary<'env>
    };

    // {:ok, hash, solution}
    Ok((ok(), hash_bin, sol_bin))
}


use rustler::Term;

fn on_load(_env: Env, _info: Term) -> bool {
    true
}

rustler::init!(
    "Elixir.Upow2.Native", load = on_load
);



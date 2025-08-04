defmodule Upow2.Native do
  @moduledoc """
  Thin Elixir façade for the Rust `tensormath/5` NIF.

  Usage:  
      { :ok, hash, solution } =
        Upow2.Native.tensormath(
          epoch,
          segment_vr_hash,
          trainer,
          pop,
          computor
        )
  """

  use Rustler, otp_app: :ama_upow2_ex

  # The actual NIF will be loaded at runtime. This clause is only hit
  # if the NIF failed to load (e.g. compilation issues or wrong ABI).
  def tensormath(_epoch, _seg_hash, _trainer, _pop, _computor),
    do: :erlang.nif_error(:nif_not_loaded)
end

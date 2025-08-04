defmodule AmaUpow2Ex do
  @moduledoc """
  Documentation for `AmaUpow2Ex`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> AmaUpow2Ex.hello()
      :world

  """
  def hello do
    :world
  end
end

defmodule UPOW do
  def compute_for(epoch, trainer, pop, computor, segment_vr, itrs \\ 30)
  def compute_for(epoch, trainer, pop, computor, segment_vr, 0), do: nil

  def compute_for(epoch, trainer, pop, computor, segment_vr, itrs) do
    {hash, sol} = branch_sol(epoch, trainer, pop, computor, segment_vr)
    valid = BIC.Sol.verify_hash(epoch, hash)

    if valid do
      sol
    else
      compute_for(epoch, trainer, pop, computor, segment_vr, itrs - 1)
    end
  end

  def branch_sol(epoch, trainer, pop, computor, segment_vr) do
    cond do
      epoch >= 156 -> UPOW2.tensormath(epoch, Blake3.hash(segment_vr), trainer, pop, computor)
      epoch >= 1 -> UPOW1.tensormath(epoch, trainer, pop, computor, segment_vr)
      true -> UPOW0.tensormath(epoch, trainer, pop, computor)
    end
  end

  def test() do
    Enum.reduce(1..10, {<<0xFF>>, <<0xFF>>}, fn itr, {h, best} ->
      IO.inspect({"pow #{itr} so far best sol", best})

      pk = <<0::integer-size(48 * 8)>>
      pop = <<0::integer-size(96 * 8)>>
      vr = <<0::integer-size(96 * 8)>>
      epoch = 200

      {hash, sol} = branch_sol(epoch, pk, pop, pk, vr)

      if hash < h do
        {hash, sol}
      else
        {h, best}
      end
    end)
  end

  def test_one(epoch \\ 156) do
    pk = Application.fetch_env!(:ama, :trainer_pk)
    pop = Application.fetch_env!(:ama, :trainer_pop)

    :timer.tc(fn ->
      branch_sol(epoch, pk, pop, pk, :crypto.strong_rand_bytes(96))
    end)
  end

  def test_until_find() do
    pk = Application.fetch_env!(:ama, :trainer_pk)
    pop = Application.fetch_env!(:ama, :trainer_pop)
    start = :os.system_time(1)
    r = UPOW.compute_for(156, pk, pop, pk, :crypto.strong_rand_bytes(96), 10_000_000)
    {r, :os.system_time(1) - start}
  end
end

defmodule UPOW0 do
  # 1024 #262144
  def tensormath(epoch, trainer, pop, computor) do
    nonce = :crypto.strong_rand_bytes(32)
    sol_seed = <<epoch::32-little, trainer::binary, pop::binary, computor::binary, nonce::binary>>
    sol_seed = sol_seed <> :binary.copy(<<0>>, 256 - byte_size(sol_seed))
    {calculate(sol_seed), sol_seed}
  end

  def calculate(sol_seed) do
    b = Blake3.new()
    Blake3.update(b, sol_seed)

    tensor =
      Enum.reduce(0..1023, %{}, fn idx, acc ->
        acc = Map.put(acc, idx, Blake3.finalize_xof(b, 1024))
        Blake3.update(b, Blake3.finalize(b))
        acc
      end)

    random_walk_bin = Blake3.finalize_xof(b, 1024 * 8 * 2)
    walk_mul(random_walk_bin, tensor)
  end

  def walk_mul(<<>>, tensor) do
    b = Blake3.new()

    tensor =
      Enum.each(0..1023, fn idx ->
        Blake3.update(b, tensor[idx])
      end)

    Blake3.finalize(b)
  end

  def walk_mul(<<index::16-little, rest::binary>>, tensor) do
    index = rem(index, 1024)

    {_row, new_row} =
      Enum.reduce(0..1023, {tensor[index], <<>>}, fn idx, {row, new_row} ->
        element = :binary.at(row, idx)
        {row, <<new_row::binary, element * element>>}
      end)

    tensor = Map.put(tensor, index, new_row)
    walk_mul(rest, tensor)
  end
end

defmodule UPOW1 do
  # 1024 #262144
  def tensormath(epoch, trainer, pop, computor, segment_vr) do
    nonce = :crypto.strong_rand_bytes(16)

    sol_seed =
      <<epoch::32-little, trainer::binary, pop::binary, computor::binary, segment_vr::binary,
        nonce::binary>>

    sol_seed = sol_seed <> :binary.copy(<<0>>, 320 - byte_size(sol_seed))
    {calculate(sol_seed), sol_seed}
  end

  def calculate(sol_seed) do
    b = Blake3.new()
    Blake3.update(b, sol_seed)

    tensor =
      Enum.reduce(0..(256 - 1), %{}, fn idx, acc ->
        acc = Map.put(acc, idx, Blake3.finalize_xof(b, 256))
        Blake3.update(b, Blake3.finalize(b))
        acc
      end)

    random_walk_bin = Blake3.finalize_xof(b, 512 * 8 * 2)
    walk_mul(random_walk_bin, tensor)
  end

  def walk_mul(<<>>, tensor) do
    b = Blake3.new()

    tensor =
      Enum.each(0..(256 - 1), fn idx ->
        Blake3.update(b, tensor[idx])
      end)

    Blake3.finalize(b)
  end

  def walk_mul(<<index::16-little, rest::binary>>, tensor) do
    index = rem(index, 256)

    {_row, new_row} =
      Enum.reduce(0..(256 - 1), {tensor[index], <<>>}, fn idx, {row, new_row} ->
        element = :binary.at(row, idx)
        {row, <<new_row::binary, element * element>>}
      end)

    tensor = Map.put(tensor, index, new_row)
    walk_mul(rest, tensor)
  end
end

defmodule UPOW2 do
  def tensormath(epoch, segment_vr_hash, trainer, pop, computor) do
    nonce = <<0::size(12*8)>> 

    sol_seed =
      <<epoch::32-little, segment_vr_hash::binary, trainer::binary, pop::binary, computor::binary,
        nonce::binary>>

    tensor_c = calculate_matmul(sol_seed)
    sol = sol_seed <> tensor_c
    res = IO.inspect(Blake3.hash(sol))
    {res, sol}
  end

  def calculate_matmul(sol_seed) when byte_size(sol_seed) == 240 do
    b = Blake3.new()
    Blake3.update(b, sol_seed)

    <<
      matrix_a::binary-size(16 * 50240),
      matrix_b::binary-size(50240 * 16),
      matrix_b2::binary-size(16 * 64)
    >> = Blake3.finalize_xof(b, 16 * 50240 + 50240 * 16 + 16 * 64)

    MatrixMul.multiply(matrix_a, matrix_b) |> MatrixMul.map_to_binary()
  end
end

defmodule MatrixMul do
  @rows 16
  @cols 16
  @k_dim 50_240

  @spec multiply(binary(), binary()) :: %{integer() => %{integer() => integer()}}
  def multiply(a_bin, b_bin) when is_binary(a_bin) and is_binary(b_bin) do
    0..(@rows - 1)
    |> Enum.reduce(%{}, fn i, acc ->
      row_map =
        0..(@cols - 1)
        |> Enum.reduce(%{}, fn j, row_acc ->
          sum = dot_product(a_bin, b_bin, i, j)
          Map.put(row_acc, j, sum)
        end)

      Map.put(acc, i, row_map)
    end)
  end

  defp dot_product(a_bin, b_bin, i, j) do
    0..(@k_dim - 1)
    |> Enum.reduce(0, fn k, sum ->
      a_val = :binary.at(a_bin, i * @k_dim + k)
      b_val = get_signed_byte(b_bin, k * @cols + j)
      sum + a_val * b_val
    end)
  end

  def get_signed_byte(bin, idx) do
    <<_::binary-size(idx), x::signed-integer-size(8), _::binary>> = bin
    x
  end

  def map_to_binary(c_map) when is_map(c_map) do
    iodata =
      for i <- 0..(@rows - 1),
          j <- 0..(@cols - 1) do
        # fetch! will raise if out of bounds
        row = Map.fetch!(c_map, i)
        val = Map.fetch!(row, j)
        <<val::signed-little-integer-size(32)>>
      end

    IO.iodata_to_binary(iodata)
  end
end

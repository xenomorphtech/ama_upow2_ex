defmodule AmaUpow2Ex.MixProject do
  use Mix.Project

  def project do
    [
      app: :ama_upow2_ex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:blake3, git: "https://github.com/vans163/blake3", branch: "finalize_xof"}
    ]
  end
end

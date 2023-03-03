defmodule AlohaDeltaUpdater.MixProject do
  use Mix.Project

  def project do
    [
      app: :aloha_delta_updater,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto, :inets]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nerves, "~> 1.8", runtime: false}
    ]
  end
end

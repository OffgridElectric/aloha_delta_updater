defmodule Aloha.DeltaUpdater do
  @moduledoc """
  Documentation for `Aloha.DeltaUpdater`.
  """
  alias Aloha.DeltaUpdater.DeltaFile
  alias Aloha.DeltaUpdater.UUID

  @doc """
  Returns patch file path
  """
  @spec create_firmware_delta_file(String.t(), String.t()) :: String.t()
  def create_firmware_delta_file(source_url, target_url) do
    uuid = UUID.generate()
    work_dir = Path.join(System.tmp_dir(), uuid) |> Path.expand()
    File.mkdir_p(work_dir)

    source_path = Path.join(work_dir, "source.fw") |> Path.expand()
    target_path = Path.join(work_dir, "target.fw") |> Path.expand()

    {:ok, :saved_to_file} =
      :httpc.request(
        :get,
        {source_url |> to_charlist, []},
        [],
        stream: source_path |> to_charlist
      )

    {:ok, :saved_to_file} =
      :httpc.request(
        :get,
        {target_url |> to_charlist, []},
        [],
        stream: target_path |> to_charlist
      )

    output_filename = uuid <> ".fw"
    output_path = Path.join(work_dir, output_filename) |> Path.expand()

    DeltaFile.create(source_path, target_path, output_path, work_dir)
  end

  def cleanup_firmware_delta_files(firmware_delta_path) do
    firmware_delta_path
    |> Path.dirname()
    |> File.rm_rf!()

    :ok
  end

  def delta_updatable?(file_path) do
    {meta, 0} = System.cmd("unzip", ["-qqp", file_path, "meta.conf"])
    meta =~ "delta-source-raw-offset" && meta =~ "delta-source-raw-count"
  end
end

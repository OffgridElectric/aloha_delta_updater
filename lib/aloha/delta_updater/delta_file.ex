defmodule Aloha.DeltaUpdater.DeltaFile do
  @moduledoc """
  Handle delta files

  Firmware upgrade files are treated in the following way:
  * `rootfs.img`: generates diff with xdelta3
  * `meta.conf`, `uboot-env.bin`: copied as is
  * other (`zImage`, uBoot, ...): copied entirely if they differ from source,
    not included if identical
  """

  @doc """
  Creates delta file from source and target firmware paths

  Returns path to created delta file
  """
  @spec create(Path.t(), Path.t(), Path.t(), Path.t()) :: Path.t()
  def create(source_path, target_path, output_path, work_dir) do
    File.mkdir_p(work_dir)

    source_work_dir = Path.join(work_dir, "source")
    target_work_dir = Path.join(work_dir, "target")
    output_work_dir = Path.join(work_dir, "output")

    File.mkdir_p(source_work_dir)
    File.mkdir_p(target_work_dir)
    File.mkdir_p(output_work_dir)

    {_, 0} = System.cmd("unzip", ["-qq", source_path, "-d", source_work_dir])
    {_, 0} = System.cmd("unzip", ["-qq", target_path, "-d", target_work_dir])

    for path <- Path.wildcard(target_work_dir <> "/**") do
      path = Regex.replace(~r/^#{target_work_dir}\//, path, "")
      unless File.dir?(Path.join(target_work_dir, path)) do
        :ok = handle_content(path, source_work_dir, target_work_dir, output_work_dir)
      end
    end

    {_, 0} = System.cmd("zip", ["-r", "-qq", output_path, "."], cd: output_work_dir)
    output_path
  end

  defp handle_content("meta." <> _ = path, _source_dir, target_dir, out_dir) do
    do_copy(Path.join(target_dir, path), Path.join(out_dir, path))
  end

  defp handle_content("data/rootfs.img" = path, source_dir, target_dir, out_dir) do
    do_delta(Path.join(source_dir, path), Path.join(target_dir, path), Path.join(out_dir, path))
  end

  defp handle_content("data/uboot-env.bin" = path, _source_dir, target_dir, out_dir) do
    do_copy(Path.join(target_dir, path), Path.join(out_dir, path))
  end

  defp handle_content(path, source_dir, target_dir, out_dir) do
    maybe_copy(Path.join(source_dir, path), Path.join(target_dir, path), Path.join(out_dir, path))
  end

  defp do_copy(source, target) do
    target |> Path.dirname() |> File.mkdir_p!()
    File.cp(source, target)
  end

  defp maybe_copy(source, target, out) do
    case System.cmd("diff", [source, target]) do
      {_, 1} -> do_copy(target, out)
      {_, 0} -> :ok
    end
  end

  defp do_delta(source, target, out) do
    out |> Path.dirname() |> File.mkdir_p!()

    with {_, 0} <-
           System.cmd("xdelta3", ["-A", "-S", "-f", "-s", source, target, out]) do
      :ok
    else
      {_, code} ->
        {:error, code}
    end
  end
end

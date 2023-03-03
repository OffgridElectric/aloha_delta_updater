defmodule Aloha.DeltaUpdater.DeltaFileTest do
  use ExUnit.Case

  alias Aloha.DeltaUpdater.DeltaFile
  alias Aloha.DeltaUpdater.UUID

  describe ".create_delta/4" do
    setup do
      id = UUID.generate()
      work_dir = Path.join(System.tmp_dir(), id)
      source_path = Path.join(work_dir, "source.fw")
      target_path = Path.join(work_dir, "target.fw")
      output_path = Path.join(work_dir, "patch.fw")

      content = %{
        "meta.conf" => "A1",
        "data/MLO" => "B1",
        "data/u-boot.img" => "C1",
        "data/uboot-env.bin" => "D1",
        "data/zImage" => "E1",
        "data/rootfs.img" => "F1"
      }

      on_exit fn ->
        File.rm_rf(work_dir)
      end

      %{source_path: source_path, target_path: target_path, output_path: output_path, work_dir: work_dir, content: content}
    end

    test "no change", ctx do
      :ok = create_fw(ctx.source_path, ctx.content)
      :ok = create_fw(ctx.target_path, ctx.content)

      _ = DeltaFile.create(ctx.source_path, ctx.target_path, ctx.output_path, ctx.work_dir)

      assert {:ok, "A1"} == read_content(ctx.output_path, "meta.conf")
      assert {:error, :enoent} == read_content(ctx.output_path, "data/MLO")
      assert {:error, :enoent} == read_content(ctx.output_path, "data/u-boot.img")
      assert {:ok, "D1"} == read_content(ctx.output_path, "data/uboot-env.bin")
      assert {:error, :enoent} == read_content(ctx.output_path, "data/zImage")
      assert {:ok, _} = read_content(ctx.output_path, "data/rootfs.img")
    end

    test "zImage change", ctx do
      :ok = create_fw(ctx.source_path, ctx.content)
      :ok = create_fw(ctx.target_path, %{ctx.content | "data/zImage" => "E2"})

      _ = DeltaFile.create(ctx.source_path, ctx.target_path, ctx.output_path, ctx.work_dir)

      assert {:ok, "A1"} == read_content(ctx.output_path, "meta.conf")
      assert {:error, :enoent} == read_content(ctx.output_path, "data/MLO")
      assert {:error, :enoent} == read_content(ctx.output_path, "data/u-boot.img")
      assert {:ok, "D1"} == read_content(ctx.output_path, "data/uboot-env.bin")
      assert {:ok, "E2"} == read_content(ctx.output_path, "data/zImage")
      assert {:ok, _} = read_content(ctx.output_path, "data/rootfs.img")
    end


  end

  defp create_fw(path, archive) do
    tmpdir = Path.join(System.tmp_dir(), UUID.generate())
    File.mkdir_p!(tmpdir)
    File.mkdir_p!(Path.dirname(path))

    for {name, content} <- archive do
      File.cd!(tmpdir, fn ->
        name |> Path.dirname() |> File.mkdir_p!()
        File.write!(name, content)
      end)
    end

    {_, 0} = System.cmd("zip", ["-r", "-qq", path, "."], cd: tmpdir)

    File.rm_rf(tmpdir)

    :ok
  end

  defp read_content(zipfile, name) do
    case System.cmd("unzip", ["-qqp", zipfile, name], stderr_to_stdout: true) do
      {out, 0} -> {:ok, out}
      {_, 11} -> {:error, :enoent}
    end
  end
end

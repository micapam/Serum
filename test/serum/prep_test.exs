defmodule PrepTest do
  use ExUnit.Case, async: true
  alias Serum.Build.Preparation
  alias Serum.BuildDataStorage

  setup_all do
    pid = spawn_link __MODULE__, :looper, []
    on_exit fn -> send pid, :stop end
    {:ok, [null_io: pid]}
  end

  describe "load_templates/1" do
    test "all ok", %{null_io: null} do
      Process.group_leader self(), null
      {:ok, _pid} = BuildDataStorage.start_link self()
      assert :ok == Preparation.load_templates priv("testsite_good/")
      BuildDataStorage.stop self()
    end

    test "some templates are missing", %{null_io: null} do
      Process.group_leader self(), null
      {:ok, _pid} = BuildDataStorage.start_link self()
      priv = fn x -> priv("test_templates/missing/templates/" <> x) end
      result = Preparation.load_templates priv("test_templates/missing/")
      expected =
        {:error, :child_tasks,
         {:load_templates,
          [{:error, :file_error, {:enoent, priv.("list.html.eex"), 0}},
           {:error, :file_error, {:enoent, priv.("post.html.eex"), 0}}]}}
      assert expected == result
      BuildDataStorage.stop self()
    end

    test "some templates contain errors 1", %{null_io: null} do
      Process.group_leader self(), null
      {:ok, _pid} = BuildDataStorage.start_link self()
      result = Preparation.load_templates priv("test_templates/eex_error/")
      {:error, :child_tasks, {:load_templates, errors}} = result
      Enum.each errors, fn e ->
        assert elem(e, 0) == :error
        assert elem(e, 1) == :invalid_template
      end
      BuildDataStorage.stop self()
    end

    test "some templates contain errors 2", %{null_io: null} do
      Process.group_leader self(), null
      {:ok, _pid} = BuildDataStorage.start_link self()
      result = Preparation.load_templates priv("test_templates/elixir_error/")
      {:error, :child_tasks, {:load_templates, errors}} = result
      Enum.each errors, fn e ->
        assert elem(e, 0) == :error
        assert elem(e, 1) == :invalid_template
      end
      BuildDataStorage.stop self()
    end
  end

  describe "scan_pages/2" do
    test "successfully scanned", %{null_io: null} do
      Process.group_leader self(), null
      BuildDataStorage.start_link self()
      BuildDataStorage.put self(), "pages_file", []
      uniq = <<System.monotonic_time()::size(48)>> |> Base.url_encode64()
      tmpname = "/tmp/serum_#{uniq}/"
      File.mkdir_p! tmpname
      assert :ok == Preparation.scan_pages priv("testsite_good/"), tmpname
      assert 4 == length BuildDataStorage.get(self(), "pages_file")
      File.rm_rf! tmpname
      BuildDataStorage.stop self()
    end

    test "source dir does not exist", %{null_io: null} do
      Process.group_leader self(), null
      result = Preparation.scan_pages "/nonexistent_123/", ""
      expected = {:error, :file_error, {:enoent, "/nonexistent_123/pages/", 0}}
      assert expected == result
    end
  end

  defp priv(path) do
    "#{:code.priv_dir :serum}/#{path}"
  end

  def looper do
    receive do
      {:io_request, from, reply_as, _} when is_pid(from) ->
        send from, {:io_reply, reply_as, :ok}
        looper()
      :stop -> :stop
      _ -> looper()
    end
  end
end
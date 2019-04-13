defmodule Serum.DevServer.Service do
  @moduledoc """
  A GenServer that provides some utility functions while the Serum development
  server is running.
  """

  use GenServer
  import Serum.Util
  alias Serum.Result
  alias Serum.SiteBuilder

  #
  # GenServer Implementation - Client
  #

  @doc "Starts `Serum.DevServer.Service` GenServer."
  @spec start_link(pid, binary, binary, pos_integer) :: {:ok, pid} | {:error, atom}
  def start_link(builder, dir, site, portnum) do
    args = [builder, dir, site, portnum]
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc "Rebuilds the current Serum project."
  @spec rebuild() :: :ok
  def rebuild, do: GenServer.call(__MODULE__, :rebuild)

  @doc "Returns the source directory."
  @spec source_dir() :: binary
  def source_dir, do: GenServer.call(__MODULE__, :source_dir)

  @doc "Returns the output directory (under `/tmp`)."
  @spec site_dir() :: binary
  def site_dir, do: GenServer.call(__MODULE__, :site_dir)

  @doc "Returns the port number the server currently listening on."
  @spec port() :: pos_integer
  def port, do: GenServer.call(__MODULE__, :port)

  @doc "Checks if the source directory is marked as dirty."
  @spec dirty?() :: boolean
  def dirty?, do: GenServer.call(__MODULE__, :is_dirty)

  #
  # GenServer Implementation - Server
  #

  @doc false
  def init([builder, dir, site, portnum]) do
    {:ok, watcher} = FileSystem.start_link(dirs: [Path.absname(dir)])

    state = %{
      builder: builder,
      watcher: watcher,
      dir: dir,
      site: site,
      portnum: portnum,
      is_dirty: false
    }

    do_rebuild(builder)
    FileSystem.subscribe(watcher)

    {:ok, state}
  end

  @doc false
  def handle_call(msg, from, state)

  def handle_call(:rebuild, _from, state) do
    builder = state.builder
    do_rebuild(builder)
    {:reply, :ok, state}
  end

  def handle_call(:source_dir, _from, state), do: {:reply, state.dir, state}
  def handle_call(:site_dir, _from, state), do: {:reply, state.site, state}
  def handle_call(:port, _from, state), do: {:reply, state.portnum, state}

  def handle_call(:is_dirty, _from, state),
    do: {:reply, state.is_dirty, %{state | is_dirty: false}}

  @doc false
  def handle_info(msg, state)

  def handle_info({:file_event, pid, {path, _}}, %{watcher: pid} = state) do
    ignore? =
      path
      |> Path.relative_to(state.dir)
      |> Path.split()
      |> Enum.any?(&dotfile?/1)

    if ignore? do
      {:noreply, state}
    else
      {:noreply, %{state | is_dirty: true}}
    end
  end

  def handle_info({:file_event, pid, :stop}, %{watcher: pid} = state) do
    {:noreply, state}
  end

  @spec do_rebuild(pid) :: :ok
  defp do_rebuild(builder) do
    with {:ok, _info} <- SiteBuilder.load_info(builder),
         {:ok, _} <- SiteBuilder.build(builder) do
      :ok
    else
      {:error, _} = error -> build_failed(error)
    end
  end

  @spec dotfile?(binary()) :: boolean()
  defp dotfile?(item)
  defp dotfile?(<<?.::8, _::binary>>), do: true
  defp dotfile?(_), do: false

  @spec build_failed(Result.t()) :: :ok
  defp build_failed(error) do
    Result.show(error)
    warn("Error occurred while building the website.")
    warn("The website may not be displayed correctly.")
  end
end

defmodule NSQ.ConnectionSupervisor do
  @moduledoc """
  A consumer or producer will initialize this supervisor empty to start.
  Candidate nsqd connections will be discovered elsewhere and added with
  start_child.
  """

  # ------------------------------------------------------- #
  # Directives                                              #
  # ------------------------------------------------------- #
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  # ------------------------------------------------------- #
  # Behaviour Implementation                                #
  # ------------------------------------------------------- #
  def start_child(parent, nsqd, parent_state \\ nil, opts \\ []) do
    parent_state = parent_state || GenServer.call(parent, :state)
    conn_sup_pid = parent_state.conn_sup_pid
    args = [
      parent,
      nsqd,
      parent_state.config,
      parent_state.topic,
      parent_state.channel
    ]
    conn_id = NSQ.Connection.connection_id(parent, nsqd)

    # When using nsqlookupd, we expect connections will be naturally
    # rediscovered if they fail. When using nsqd directly, we don't have any
    # recourse, so might as well try restarting the connection if it fails.
    if length(parent_state.config.nsqlookupds) > 0 do
      opts = [restart: :temporary, id: conn_id] ++ opts
    else
      opts = [restart: :permanent, id: conn_id] ++ opts
    end

    child = worker(NSQ.Connection, args, opts)
    Supervisor.start_child(conn_sup_pid, child)
  end

  def init(:ok) do
    supervise([], strategy: :one_for_one)
  end
end
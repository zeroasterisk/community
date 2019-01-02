# lib/house_party/room_worker.ex
defmodule HouseParty.RoomWorker do
  use GenServer
  alias HouseParty.RoomWorker
  @timeout :infinity

  defstruct [
    name: nil, # atom
    max: 10, # int, max people in room
    count: 0, # int, count of people currently in room
    people: %{}, # MapSet of list of people in rooms as [atom]
  ]

  # Helpul external API
  def start_link(name) when is_bitstring(name) or is_atom(name), do: start_link(%RoomWorker{name: name})
  def start_link(%RoomWorker{name: name} = state) when is_atom(name) do
    GenServer.start_link(__MODULE__, state, [timeout: @timeout])
  end
  def start_link(%{} = state), do: %RoomWorker{} |> Map.merge(state) |> start_link()
  def take(pid, fields), do: GenServer.call(pid, {:take, fields})
  def add_person([], _person), do: :ok
  def add_person([pid | rest], person) do
    case add_person(pid, person) do
      :ok -> add_person(rest, person)
      :full -> :full
      :error -> :error
    end
  end
  def add_person(pid, person), do: GenServer.call(pid, {:add_person, person})
  def rm_person([], _person), do: :ok
  def rm_person([pid | rest], person) do
    case rm_person(pid, person) do
      :ok -> rm_person(rest, person)
      :error -> :error
    end
  end
  def rm_person(pid, person), do: GenServer.call(pid, {:rm_person, person})

  # GenServer internal API
  def init(%RoomWorker{people: people} = state) do
    {:ok, state |> Map.put(:people, MapSet.new(people))}
  end
  def handle_call({:take, fields}, _from, state) do
    {:reply, {:ok, Map.take(state, fields)}, state}
  end
  def handle_call({:add_person, _new_people}, _from, %RoomWorker{count: count, max: max} = state) when count >= max do
    {:reply, :full, state}
  end
  def handle_call({:add_person, person_name}, _from, %RoomWorker{people: people, max: max} = state) when is_atom(person_name) do
    people = people |> MapSet.put(person_name)
    count = Enum.count(people)
    if count <= max do
      new_state = state
                  |> Map.put(:count, count)
                  |> Map.put(:people, people)
      {:reply, :ok, new_state}
    else
      {:reply, :full, state}
    end
  end
  def handle_call({:rm_person, person_name}, _from, %RoomWorker{people: people} = state) when is_atom(person_name) do
    people = people |> MapSet.delete(person_name)
    count = Enum.count(people)
    new_state = state
                |> Map.put(:count, count)
                |> Map.put(:people, people)
    {:reply, :ok, new_state}
  end

  # These are special swarm interfaces to control handoff and migration
  def handle_call({:swarm, :begin_handoff}, _from, state) do
    {:reply, {:resume, state}, state}
  end
  def handle_cast({:swarm, :end_handoff, state}, _init_state) do
    {:noreply, state}
  end
  def handle_cast({:swarm, :resolve_conflict, other_node_state}, state) do
    {:noreply, state}
  end
  def handle_info({:swarm, :die}, %RoomWorker{name: name, people: people} = state) do
    # should do cleanup...?  maybe swarm will auto-move?
    {:stop, :shutdown, state}
  end
end

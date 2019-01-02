# lib/house_party/person_worker.ex
defmodule HouseParty.PersonWorker do
  use GenServer
  alias HouseParty.PersonWorker
  @timeout :infinity

  defstruct [
    name: nil, # atom
    current_room: nil, # nil = not yet entered, :left_party = gone, or a room name
    count: 0, # how many rooms person has entered
    max: 100, # how many rooms until person leaves
    wander_delay_ms: 1000, # when wandering, move rooms after this delay (in ms)
    log: [], # [{<time>, <room>}, ...]
  ]

  # Helpul external API
  def start_link(name) when is_atom(name), do: start_link(%PersonWorker{name: name})
  def start_link(%PersonWorker{name: name} = state) when is_atom(name) do
    GenServer.start_link(__MODULE__, state, [timeout: @timeout])
  end
  def stop(pid, reason \\ :normal), do: GenServer.stop(pid, reason)
  def take(pid, fields), do: GenServer.call(pid, {:take, fields})
  def walk_into(pid, room) when is_pid(pid) and is_atom(room), do: GenServer.call(pid, {:walk_into, room})
  def wanderlust(pid), do: GenServer.call(pid, {:wanderlust})

  # GenServer internal API
  def init(%PersonWorker{} = state) do
    {:ok, state}
  end
  def handle_call({:take, fields}, _from, state) do
    {:reply, {:ok, Map.take(state, fields)}, state}
  end
  def handle_call({:walk_into, new_room}, _from, %PersonWorker{} = state) when is_atom(:new_room) do
    movement = HouseParty.PersonMovement.lookup_pids_for_move(state, new_room)
    new_state = HouseParty.PersonMovement.walk_into(state, movement)
    {:reply, :ok, new_state}
  end
  def handle_call({:wanderlust}, _from, %PersonWorker{} = state) do
    wanderlust_schedule_next(state)
    {:reply, :ok, state}
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
  def handle_info({:swarm, :die}, %PersonWorker{name: name} = state) do
    {:stop, :shutdown, state}
  end


  # start wandering between rooms
  def handle_info({:wander}, %PersonWorker{} = state) do
    new_state = wander(state)
    wanderlust_schedule_next(new_state)
    {:noreply, new_state}
  end


  # Private Internal Functions, for wander/wanderlust (exposed via GenServer)
  def wanderlust_schedule_next(%PersonWorker{current_room: :left_party} = person) do
    :ok
  end
  def wanderlust_schedule_next(%PersonWorker{current_room: nil, wander_delay_ms: wander_delay_ms} = _person) do
    # 10x the normal delay, with up to 1x random added
    add = :rand.uniform(wander_delay_ms)
    delay = ((wander_delay_ms * 10) + add)
    Process.send_after(self(), {:wander}, delay)
  end
  def wanderlust_schedule_next(%PersonWorker{wander_delay_ms: wander_delay_ms} = _person) do
    # +/- up to 10% randomized
    subtract = :rand.uniform(Kernel.trunc(wander_delay_ms / 20))
    add = :rand.uniform(Kernel.trunc(wander_delay_ms / 10))
    delay = ((wander_delay_ms - subtract) + add)
    Process.send_after(self(), {:wander}, delay)
  end
  def wander(%PersonWorker{} = person) do
    room_names = HouseParty.get_all_rooms()
    wander(person, room_names)
  end
  def wander(%PersonWorker{} = person, room_names) when is_list(room_names) do
    new_room = wander_pick_new_room(person, room_names)
    movement = HouseParty.PersonMovement.lookup_pids_for_move(person, new_room)
    HouseParty.PersonMovement.walk_into(person, movement)
  end
  def wander_pick_new_room(%PersonWorker{count: count, max: max} = _person, _room_names) when count >= max do
    :leave
  end
  def wander_pick_new_room(%PersonWorker{current_room: :left_party} = _person, _room_names) do
    :left_party
  end
  def wander_pick_new_room(%PersonWorker{current_room: nil} = _person, room_names) do
    room_names |> Enum.random()
  end
  def wander_pick_new_room(%PersonWorker{current_room: current_room} = _person, room_names) do
    room_names = room_names |> Enum.reject(fn(room) -> room == current_room end)
    if Enum.empty?(room_names) do
      nil
    else
      room_names |> Enum.random()
    end
  end
end

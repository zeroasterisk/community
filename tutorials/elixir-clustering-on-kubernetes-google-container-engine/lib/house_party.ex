# lib/house_party.ex
defmodule HouseParty do
  require Logger
  alias HouseParty.PersonWorker
  alias HouseParty.RoomWorker

  # easy setup for party configurations
  def setup_party(:small) do
    template_person = %PersonWorker{max: 20, wander_delay_ms: 100}
    template_room = %RoomWorker{max: 10}
    build_party_from_templates(template_room, 5, template_person, 100)
    Swarm.multi_call(:house_party_people, {:wanderlust})
  end
  def setup_party(:big) do
    template_person = %PersonWorker{max: 10, wander_delay_ms: 100}
    template_room = %RoomWorker{max: 25}
    build_party_from_templates(template_room, 50, template_person, 2_000)
    Swarm.multi_call(:house_party_people, {:wanderlust})
  end
  def build_party_from_templates(template_room, n_rooms, template_person, n_people) when is_integer(n_rooms) and is_integer(n_people) do
    reset()
    Range.new(1, n_rooms)
    |> Enum.map(fn(i) -> String.to_atom("room_#{i}") end)
    |> Enum.map(fn(name) -> Map.merge(template_room, %{name: name}) end)
    |> add_rooms()
    Range.new(1, n_people)
    |> Enum.map(fn(i) -> String.to_atom("person_#{i}") end)
    |> Enum.map(fn(name) -> Map.merge(template_person, %{name: name}) end)
    |> add_people()
    :ok
  end

  def add_rooms([]), do: :ok
  def add_rooms(rooms) when is_list(rooms), do: add_rooms(:ok, rooms)
  def add_rooms(room) when is_atom(room), do: add_rooms(:ok, [room])
  def add_rooms(:ok, []), do: :ok
  def add_rooms(:ok, [room | rest]) do
    {status, _} = room |> add_room()
    status |> add_rooms(rest)
  end
  def add_rooms(:error, _list), do: :error

  defp add_room(%RoomWorker{name: room_name} = room) when is_atom(room_name) do
    name = build_process_name(:room, room_name)
    name |> Swarm.register_name(RoomWorker, :start_link, [room]) |> add_room_finish()
  end
  defp add_room(room) when is_atom(room) do
    name = build_process_name(:room, room)
    name |> Swarm.register_name(RoomWorker, :start_link, [room]) |> add_room_finish()
  end
  # handle the output from Swarm.register_name and auto-join the group if possible
  defp add_room_finish({:ok, pid}) do
    {Swarm.join(:house_party_rooms, pid), pid}
  end
  defp add_room_finish({:error, {:already_registered, pid}}), do: {:ok, pid}
  defp add_room_finish(:error), do: add_room_finish({:error, "unknown reason"})
  defp add_room_finish({:error, reason}) do
    {:error, reason}
  end

  def add_people([]), do: :ok
  def add_people(people) when is_list(people), do: add_people(:ok, people)
  def add_people(person) when is_atom(person), do: add_people(:ok, [person])
  # process all people in a loop, until empty or error
  def add_people(:ok, []), do: :ok
  def add_people(:ok, [person | rest]) do
    {status, _} = person |> add_person()
    status |> add_people(rest)
  end
  def add_people(:error, _list), do: :error

  defp add_person(%PersonWorker{name: person_name} = person) when is_atom(person_name) do
    name = build_process_name(:person, person_name)
    name |> Swarm.register_name(PersonWorker, :start_link, [person]) |> add_person_finish()
  end
  defp add_person(person) when is_atom(person) do
    name = build_process_name(:person, person)
    name |> Swarm.register_name(PersonWorker, :start_link, [person]) |> add_person_finish()
  end
  # handle the output from Swarm.register_name and auto-join the group if possible
  defp add_person_finish({:ok, pid}) do
    {Swarm.join(:house_party_people, pid), pid}
  end
  defp add_person_finish({:error, {:already_registered, pid}}), do: {:ok, pid}
  defp add_person_finish(:error), do: add_person_finish({:error, "unknown reason"})
  defp add_person_finish({:error, reason}) do
    Logger.error("add_people() failure for #{reason}")
    {:error, reason}
  end

  def get_person_pid(nil), do: nil
  def get_person_pid(person_name) when is_atom(person_name) do
    typed_name = build_process_name(:person, person_name)
    house_party_pids = Swarm.members(:house_party_people)
    Swarm.registered()
    |> Enum.filter(fn({_name, pid}) -> Enum.member?(house_party_pids, pid) end)
    |> Enum.filter(fn({name, _pid}) -> name == typed_name end)
    |> Enum.map(fn({_name, pid}) -> pid end)
    |> List.first()
  end
  def get_room_pid(nil), do: nil
  def get_room_pid(room_name) when is_atom(room_name) do
    typed_name = build_process_name(:room, room_name)
    house_party_pids = Swarm.members(:house_party_rooms)
    Swarm.registered()
    |> Enum.filter(fn({_name, pid}) -> Enum.member?(house_party_pids, pid) end)
    |> Enum.filter(fn({name, _pid}) -> name == typed_name end)
    |> Enum.map(fn({_name, pid}) -> pid end)
    |> List.first()
  end
  def get_all_rooms() do
    house_party_pids = Swarm.members(:house_party_rooms)
    Swarm.registered()
    |> Enum.filter(fn({_name, pid}) -> Enum.member?(house_party_pids, pid) end)
    |> Enum.map(fn({name, _pid}) -> name |> Atom.to_string() |> String.slice(5, 99) |> String.to_atom end)
    |> Enum.sort()
  end
  def get_all_people() do
    house_party_pids = Swarm.members(:house_party_people)
    Swarm.registered()
    |> Enum.filter(fn({_name, pid}) -> Enum.member?(house_party_pids, pid) end)
    |> Enum.map(fn({name, _pid}) -> name |> Atom.to_string() |> String.slice(7, 99) |> String.to_atom end)
    |> Enum.sort()
  end

  def build_process_name(type, name) do
    Atom.to_string(type) <> "_" <> Atom.to_string(name) |> String.to_atom()
  end
  def reset() do
    :house_party_rooms |> Swarm.publish({:swarm, :die})
    :house_party_people |> Swarm.publish({:swarm, :die})
  end
end

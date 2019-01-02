# lib/house_party/person_movement.ex
defmodule HouseParty.PersonMovement do
  alias HouseParty.PersonWorker
  def lookup_pids_for_move(%PersonWorker{current_room: current_room}, new_room) when is_atom(new_room) do
    %{
      new_room: new_room,
      new_room_pid: HouseParty.get_room_pid(new_room),
      current_room: current_room,
      current_room_pid: HouseParty.get_room_pid(current_room),
    }
  end
  def walk_into(%PersonWorker{} = person, movement) do
    case enter_new_room(person, movement) do
      :ok ->
        case depart_current_room(person, movement) do
          :ok ->
            update_person_on_success(person, movement)
          :cannot_leave_nil ->
            update_person_on_success(person, movement)
          :error ->
            person
        end
      :full ->
        update_person_on_failed_too_full(person, movement)
      :error ->
        person
    end
  end
  defp enter_new_room(%PersonWorker{name: person_name}, %{new_room_pid: nil, new_room: :leave}) do
    :ok
  end
  defp enter_new_room(%PersonWorker{name: person_name}, %{new_room_pid: nil} = movement) do
    :error
  end
  defp enter_new_room(%PersonWorker{name: person_name}, %{new_room_pid: new_room_pid}) when is_pid(new_room_pid) do
    HouseParty.RoomWorker.add_person(new_room_pid, person_name)
  end
  defp depart_current_room(%PersonWorker{current_room: nil}, _movement) do
    :ok
  end
  defp depart_current_room(%PersonWorker{name: person_name}, %{current_room_pid: nil} = movement) do
    :error
  end
  defp depart_current_room(%PersonWorker{name: person_name}, %{current_room_pid: current_room_pid}) when is_pid(current_room_pid) do
    HouseParty.RoomWorker.rm_person(current_room_pid, person_name)
  end
  def update_person_on_success(%PersonWorker{log: log, count: count} = person, %{new_room: :leave}) do
    person |> Map.merge(%{
      current_room: :left_party,
      log: [{DateTime.utc_now, :leave, :leave} | log],
    })
  end
  def update_person_on_success(%PersonWorker{log: log, count: count} = person, %{new_room: new_room}) do
    person |> Map.merge(%{
      current_room: new_room,
      count: count + 1,
      log: [{DateTime.utc_now, new_room, :entered} | log],
    })
  end
  def update_person_on_failed_too_full(%PersonWorker{log: log, count: count} = person, %{new_room: new_room}) do
    person |> Map.merge(%{
      count: count + 1,
      log: [{DateTime.utc_now, new_room, :was_full} | log],
    })
  end
end

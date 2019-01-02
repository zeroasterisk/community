
defmodule HouseParty.Invites do
  def setup_party(:small) do
    template_person = %HouseParty.PersonWorker{max: 20, wander_delay_ms: 100}
    template_room = %HouseParty.RoomWorker{max: 10}
    build_party_from_templates(template_room, 5, template_person, 100)
    Swarm.multi_call(:house_party_people, {:wanderlust})
  end
  def setup_party(:big) do
    template_person = %HouseParty.PersonWorker{max: 10, wander_delay_ms: 100}
    template_room = %HouseParty.RoomWorker{max: 25}
    build_party_from_templates(template_room, 50, template_person, 2_000)
    Swarm.multi_call(:house_party_people, {:wanderlust})
  end
  def build_party_from_templates(template_room, n_rooms, template_person, n_people) when is_integer(n_rooms) and is_integer(n_people) do
    HouseParty.reset()
    Range.new(1, n_rooms)
    |> Enum.map(fn(i) -> String.to_atom("room_#{i}") end)
    |> Enum.map(fn(name) -> Map.merge(template_room, %{name: name}) end)
    |> HouseParty.add_rooms()
    Range.new(1, n_people)
    |> Enum.map(fn(i) -> String.to_atom("person_#{i}") end)
    |> Enum.map(fn(name) -> Map.merge(template_person, %{name: name}) end)
    |> HouseParty.add_people()
    :ok
  end
end

/// A minimal person reference used in timeline entries and detail views.
///
/// Avoids coupling the timeline layer to the full [PeopleData] model.
class LinkedPerson {
  final String id;
  final String name;

  const LinkedPerson({required this.id, required this.name});

  @override
  bool operator ==(Object other) =>
      other is LinkedPerson && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

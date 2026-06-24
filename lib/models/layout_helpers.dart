/// Row/column nesting rules for section-based layout.
///
/// When [sectionLayoutEnabled] is false, or the parent container uses
/// [parentFreePlacement], any child type may be added.
bool canNestLayoutChild({
  required String parentType,
  required String childType,
  required bool parentFreePlacement,
  required bool sectionLayoutEnabled,
}) {
  if (!sectionLayoutEnabled || parentFreePlacement) return true;
  if (childType == 'row' && parentType == 'row') return false;
  if (childType == 'col' && parentType == 'col') return false;
  return true;
}

bool canAddRowToParent({
  required String parentType,
  required bool parentFreePlacement,
  required bool sectionLayoutEnabled,
}) =>
    canNestLayoutChild(
      parentType: parentType,
      childType: 'row',
      parentFreePlacement: parentFreePlacement,
      sectionLayoutEnabled: sectionLayoutEnabled,
    );

bool canAddColToParent({
  required String parentType,
  required bool parentFreePlacement,
  required bool sectionLayoutEnabled,
}) =>
    canNestLayoutChild(
      parentType: parentType,
      childType: 'col',
      parentFreePlacement: parentFreePlacement,
      sectionLayoutEnabled: sectionLayoutEnabled,
    );

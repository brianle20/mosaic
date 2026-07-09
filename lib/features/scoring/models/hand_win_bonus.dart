enum HandWinBonus {
  concealedHand(id: 'concealed_hand', label: 'Concealed Hand', fanValue: 1),
  moonUnderTheSea(
    id: 'moon_under_the_sea',
    label: 'Moon Under the Sea',
    fanValue: 1,
  ),
  robbingTheKong(
    id: 'robbing_the_kong',
    label: 'Robbing the Kong',
    fanValue: 1,
  ),
  winByKongReplacement(
    id: 'win_by_kong_replacement',
    label: 'Win by Kong Replacement',
    fanValue: 2,
  ),
  doubleKongReplacement(
    id: 'double_kong_replacement',
    label: 'Double Kong Replacement',
    fanValue: 9,
  ),
  blessingOfHeaven(
    id: 'blessing_of_heaven',
    label: 'Blessing of Heaven',
    fanValue: 13,
  ),
  blessingOfEarth(
    id: 'blessing_of_earth',
    label: 'Blessing of Earth',
    fanValue: 13,
  ),
  blessingOfMan(
    id: 'blessing_of_man',
    label: 'Blessing of Man',
    fanValue: 13,
  );

  const HandWinBonus({
    required this.id,
    required this.label,
    required this.fanValue,
  });

  final String id;
  final String label;
  final int fanValue;

  static HandWinBonus fromId(String id) {
    for (final bonus in values) {
      if (bonus.id == id) {
        return bonus;
      }
    }
    throw FormatException('Unknown hand win bonus: $id');
  }
}

List<HandWinBonus> handWinBonusesFromIds(Iterable<String> ids) {
  final seen = <String>{};
  final bonuses = <HandWinBonus>[];
  for (final id in ids) {
    if (!seen.add(id)) {
      throw FormatException('Duplicate hand win bonus: $id');
    }
    bonuses.add(HandWinBonus.fromId(id));
  }
  return List.unmodifiable(bonuses);
}

List<String> handWinBonusIds(Iterable<HandWinBonus> bonuses) {
  return List.unmodifiable(bonuses.map((bonus) => bonus.id));
}

int handWinBonusFanTotal(Iterable<HandWinBonus> bonuses) {
  return bonuses.fold<int>(0, (total, bonus) => total + bonus.fanValue);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/scoring/models/hand_win_bonus.dart';

void main() {
  group('HandWinBonus', () {
    test('defines supported bonuses in display order', () {
      expect(
        HandWinBonus.values.map((bonus) => bonus.id).toList(),
        [
          'concealed_hand',
          'moon_under_the_sea',
          'robbing_the_kong',
          'win_by_kong_replacement',
          'double_kong_replacement',
          'blessing_of_heaven',
          'blessing_of_earth',
          'blessing_of_man',
        ],
      );
      expect(HandWinBonus.concealedHand.label, 'Concealed Hand');
      expect(HandWinBonus.concealedHand.fanValue, 1);
      expect(HandWinBonus.winByKongReplacement.fanValue, 2);
      expect(HandWinBonus.doubleKongReplacement.fanValue, 9);
      expect(HandWinBonus.blessingOfMan.fanValue, 13);
    });

    test('parses serializes rejects duplicates and totals fan', () {
      expect(
        HandWinBonus.fromId('robbing_the_kong'),
        HandWinBonus.robbingTheKong,
      );
      expect(
        handWinBonusesFromIds(['concealed_hand', 'moon_under_the_sea']),
        [HandWinBonus.concealedHand, HandWinBonus.moonUnderTheSea],
      );
      expect(
        handWinBonusIds([HandWinBonus.blessingOfEarth]),
        ['blessing_of_earth'],
      );
      expect(
        () => HandWinBonus.fromId('self_pick'),
        throwsFormatException,
      );
      expect(
        () => handWinBonusesFromIds(['concealed_hand', 'concealed_hand']),
        throwsFormatException,
      );
      expect(
        handWinBonusFanTotal([
          HandWinBonus.concealedHand,
          HandWinBonus.winByKongReplacement,
        ]),
        3,
      );
    });
  });
}

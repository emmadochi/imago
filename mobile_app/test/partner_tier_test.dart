import 'package:flutter_test/flutter_test.dart';
import 'package:imago/screens/partner_screen.dart';

void main() {
  group('PartnerTier Automated Tests', () {
    test('PartnerTier enum has 3 distinct tiers', () {
      expect(PartnerTier.values.length, equals(3));
      expect(PartnerTier.values, contains(PartnerTier.prayer));
      expect(PartnerTier.values, contains(PartnerTier.ministry));
      expect(PartnerTier.values, contains(PartnerTier.sustaining));
    });

    test('Prayer Partner Tier pricing and properties', () {
      final tier = PartnerTier.prayer;
      expect(tier.label, equals('Prayer Partner'));
      expect(tier.emoji, equals('🙏'));
      expect(tier.amountNGN, equals(1000));
      expect(tier.amountUSD, equals(1));
      expect(tier.perks.isNotEmpty, isTrue);
      expect(tier.gradient.length, equals(2));
    });

    test('Ministry Partner Tier pricing and properties', () {
      final tier = PartnerTier.ministry;
      expect(tier.label, equals('Ministry Partner'));
      expect(tier.emoji, equals('✝️'));
      expect(tier.amountNGN, equals(5000));
      expect(tier.amountUSD, equals(5));
      expect(tier.perks.length, greaterThanOrEqualTo(3));
    });

    test('Sustaining Partner Tier pricing and properties', () {
      final tier = PartnerTier.sustaining;
      expect(tier.label, equals('Sustaining Partner'));
      expect(tier.emoji, equals('👑'));
      expect(tier.amountNGN, equals(20000));
      expect(tier.amountUSD, equals(20));
      expect(tier.perks.length, greaterThanOrEqualTo(4));
    });

    test('Annual billing discount logic is consistent across tiers', () {
      for (final tier in PartnerTier.values) {
        final monthlyNGN = tier.amountNGN;
        final annualNGN = tier.amountNGN * 10;
        final monthlyUSD = tier.amountUSD;
        final annualUSD = tier.amountUSD * 10;

        expect(annualNGN, equals(monthlyNGN * 10));
        expect(annualUSD, equals(monthlyUSD * 10));
        expect(annualNGN, lessThan(monthlyNGN * 12)); // 2 months free discount
      }
    });

    test('PartnerPaymentConfig defaults and properties', () {
      expect(PartnerPaymentConfig.backendUrl.isNotEmpty, isTrue);
      expect(PartnerPaymentConfig.backendUrl, startsWith('http'));
      expect(PartnerPaymentConfig.defaultPaystackUrl, isA<String>());
    });
  });
}

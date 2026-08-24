import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/deezer_client.dart';

void main() {
  group('DeezerAccountStatus', () {
    test('valid ARL with missing offer metadata is not reported expired', () {
      final status = DeezerAccountStatus.fromUserJson({
        'USER_ID': 12345,
        'NAME': 'Listener',
      });

      expect(status.arlValid, isTrue);
      expect(status.hasPaidOffer, isNull);
      expect(status.canDownload, isFalse);
      expect(status.subscriptionStatusKnown, isFalse);
      expect(status.offerLabel, 'Deezer account verified');
    });

    test('accepts string response values from Deezer', () {
      final status = DeezerAccountStatus.fromUserJson({
        'USER_ID': '12345',
        'OFFER_ID': '4',
        'NAME': 'Listener',
      });

      expect(status.arlValid, isTrue);
      expect(status.offerId, 4);
      expect(status.hasPaidOffer, isTrue);
      expect(status.canDownload, isTrue);
      expect(status.offerLabel, 'Deezer HiFi');
    });

    test('zero offer metadata does not falsely report expiration', () {
      final status = DeezerAccountStatus.fromUserJson({
        'USER_ID': 12345,
        'OFFER_ID': 0,
      });

      expect(status.arlValid, isTrue);
      expect(status.hasPaidOffer, isNull);
      expect(status.canDownload, isFalse);
      expect(status.subscriptionStatusKnown, isFalse);
      expect(status.offerLabel, 'Deezer account verified');
    });

    test('normalizes boolean freemium metadata', () {
      final status = DeezerAccountStatus.fromUserJson({
        'USER_ID': '12345',
        'OFFER_ID': 0,
        'IS_FREEMIUM_COUNTRY': 'true',
      });

      expect(status.arlValid, isTrue);
      expect(status.isFreemiumCountry, isTrue);
      expect(status.canDownload, isTrue);
    });

    test('zero user id is invalid regardless of offer metadata', () {
      final status = DeezerAccountStatus.fromUserJson({
        'USER_ID': 0,
        'OFFER_ID': 4,
      });

      expect(status.arlValid, isFalse);
      expect(status.canDownload, isFalse);
    });
  });
}

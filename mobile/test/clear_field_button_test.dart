// The ✕ that empties a from/to field in one tap.
//
// Driven through the real widgets rather than a copy of their logic, because
// the thing that can break is the wiring: the button has to appear as soon as
// there is text, empty BOTH the box and the place that was resolved for it,
// and disappear again afterwards. Clearing only the text would leave the
// parent holding coordinates for an address the box no longer shows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:gora_cabs/core/di/injection.dart';
import 'package:gora_cabs/core/network/api_client.dart';

import 'package:gora_cabs/core/widgets/clear_field_button.dart';
import 'package:gora_cabs/core/widgets/address_autocomplete_field.dart';
import 'package:gora_cabs/core/widgets/city_autocomplete_field.dart';
import 'package:gora_cabs/core/widgets/places_city_field.dart';

/// ScreenUtil is initialised by the app at startup; the widgets use `.w`/`.r`
/// so a test has to stand that up too.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );

void main() {
  // AddressAutocompleteField resolves its ApiClient through get_it at build
  // time. Registering a real one is enough: no request is ever made here,
  // because every assertion happens before the 350ms search debounce fires.
  setUpAll(() {
    if (!getIt.isRegistered<ApiClient>()) {
      getIt.registerSingleton(ApiClient(const FlutterSecureStorage()));
    }
  });

  group('from/to fields can be cleared in one tap', () {
    testWidgets('AddressAutocompleteField — the pickup/drop box', (tester) async {
      final controller = TextEditingController();
      String? selectedAddress = 'STALE';
      double? selectedLat = 99;

      await tester.pumpWidget(host(
        AddressAutocompleteField(
          controller: controller,
          label: 'Pickup',
          prefixIcon: Icons.place,
          onSelected: (address, lat, lng, city) {
            selectedAddress = address;
            selectedLat = lat;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ClearFieldButton), findsNothing,
          reason: 'an empty field has nothing to clear');

      await tester.enterText(find.byType(TextFormField), 'Jodhpur Railway Station');
      await tester.pump();

      expect(find.byType(ClearFieldButton), findsOneWidget,
          reason: 'the button must appear as soon as there is text, not after the search lands');

      await tester.tap(find.byType(ClearFieldButton));
      await tester.pump();

      expect(controller.text, isEmpty, reason: 'the whole field goes at once');
      expect(find.byType(ClearFieldButton), findsNothing,
          reason: 'nothing left to clear, so the button goes too');
      expect(selectedAddress, '',
          reason: 'the parent must be told the place is gone, not just the text');
      expect(selectedLat, 0,
          reason: 'stale coordinates would book a trip to an address no longer shown');
    });

    testWidgets('CityAutocompleteField', (tester) async {
      String? reportedCity = 'STALE';

      await tester.pumpWidget(host(
        CityAutocompleteField(
          label: 'Pickup city',
          icon: Icons.location_city,
          onChanged: (city, state) => reportedCity = city,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ClearFieldButton), findsNothing);

      await tester.enterText(find.byType(TextFormField), 'Jodhpur');
      await tester.pump();
      expect(find.byType(ClearFieldButton), findsOneWidget);

      await tester.tap(find.byType(ClearFieldButton));
      await tester.pump();

      expect(find.text('Jodhpur'), findsNothing);
      expect(reportedCity, '', reason: 'the chosen city is dropped along with the text');
      expect(find.byType(ClearFieldButton), findsNothing);
    });

    testWidgets('PlacesCityField', (tester) async {
      String? reportedCity = 'STALE';

      await tester.pumpWidget(host(
        PlacesCityField(
          label: 'City',
          icon: Icons.location_city,
          onChanged: (city, state) => reportedCity = city,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ClearFieldButton), findsNothing);

      await tester.enterText(find.byType(TextFormField), 'Jaipur');
      await tester.pump();
      expect(find.byType(ClearFieldButton), findsOneWidget);

      await tester.tap(find.byType(ClearFieldButton));
      await tester.pump();

      expect(find.text('Jaipur'), findsNothing);
      expect(reportedCity, '');
      expect(find.byType(ClearFieldButton), findsNothing);
    });
  });
}

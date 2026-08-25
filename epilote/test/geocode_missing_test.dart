import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/admin_groupe/providers/admin_regional_provider.dart';

void main() {
  test('un pin sans GPS mais avec ville est éligible au géocodage', () {
    const pin = AdminSchoolPin(
      id: '1',
      name: 'EP Test',
      type: 'public',
      isActive: true,
      students: 0,
      city: 'Ouésso',
      department: 'Sangha',
    );
    expect(pin.hasGps, isFalse);
    expect(pin.city, isNotNull);
  });

  test('un pin avec GPS n\'est pas éligible', () {
    const pin = AdminSchoolPin(
      id: '2',
      name: 'EP GPS',
      type: 'public',
      isActive: true,
      students: 10,
      latitude: -4.26,
      longitude: 15.27,
    );
    expect(pin.hasGps, isTrue);
    expect(pin.gpsCoords, isNotNull);
  });
}

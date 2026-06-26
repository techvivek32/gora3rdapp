/// Single source of truth for selectable vehicle types (value + display label).
const kVehicleTypes = <Map<String, String>>[
  {'value': 'hatchback', 'label': 'Hatchback Car'},
  {'value': 'eeco', 'label': 'Ecco Car'},
  {'value': 'sedan', 'label': 'Sedan Car'},
  {'value': 'ertiga', 'label': 'SUV Ertiga Car'},
  {'value': 'rumion', 'label': 'Toyota Rumion'},
  {'value': 'carens', 'label': 'Kia Carens'},
  {'value': 'innova', 'label': 'SUV Innova Car'},
  {'value': 'crysta', 'label': 'SUV Crysta Car'},
  {'value': 'hycross', 'label': 'Toyota Hycross'},
  {'value': 'tempo_traveller', 'label': 'Tempo Traveller'},
  {'value': 'urbania', 'label': 'Force Urbania'},
  {'value': 'trax_cruiser', 'label': 'Force Trax Cruiser'},
  {'value': 'small_coach', 'label': 'Small Coach'},
  {'value': 'luxury_coach', 'label': 'Luxury Coach'},
  {'value': 'premium', 'label': 'Premium Car'},
];

/// Returns the display label for a stored vehicle-type value (falls back to a
/// title-cased version for legacy/unknown values).
String vehicleTypeLabel(String? value) {
  if (value == null || value.isEmpty) return 'Vehicle';
  for (final t in kVehicleTypes) {
    if (t['value'] == value) return t['label']!;
  }
  return value.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}

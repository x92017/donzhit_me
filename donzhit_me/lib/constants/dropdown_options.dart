/// All dropdown options for the DonzHit.me app
class DropdownOptions {
  // Road Usage Types
  static const List<String> roadUsageTypes = [
    'Auto',
    'Cyclist',
    'Pedestrian',
    'Commercial',
    'Public Transit',
  ];

  // Event Types
  static const List<String> eventTypes = [
    'Pedestrian Intersection',
    'Red Light',
    'Speeding',
    'On Phone',
    'Reckless',
  ];

  // U.S. States
  static const List<String> usStates = [
    'Alabama',
    'Alaska',
    'Arizona',
    'Arkansas',
    'California',
    'Colorado',
    'Connecticut',
    'Delaware',
    'Florida',
    'Georgia',
    'Hawaii',
    'Idaho',
    'Illinois',
    'Indiana',
    'Iowa',
    'Kansas',
    'Kentucky',
    'Louisiana',
    'Maine',
    'Maryland',
    'Massachusetts',
    'Michigan',
    'Minnesota',
    'Mississippi',
    'Missouri',
    'Montana',
    'Nebraska',
    'Nevada',
    'New Hampshire',
    'New Jersey',
    'New Mexico',
    'New York',
    'North Carolina',
    'North Dakota',
    'Ohio',
    'Oklahoma',
    'Oregon',
    'Pennsylvania',
    'Rhode Island',
    'South Carolina',
    'South Dakota',
    'Tennessee',
    'Texas',
    'Utah',
    'Vermont',
    'Virginia',
    'Washington',
    'West Virginia',
    'Wisconsin',
    'Wyoming',
    'District of Columbia',
  ];

  // Canadian Provinces
  static const List<String> canadianProvinces = [
    'Alberta',
    'British Columbia',
    'Manitoba',
    'New Brunswick',
    'Newfoundland and Labrador',
    'Northwest Territories',
    'Nova Scotia',
    'Nunavut',
    'Ontario',
    'Prince Edward Island',
    'Quebec',
    'Saskatchewan',
    'Yukon',
  ];

  // Combined States and Provinces
  static List<String> get allStatesAndProvinces {
    return [
      '--- United States ---',
      ...usStates,
      '--- Canada ---',
      ...canadianProvinces,
    ];
  }

  // Selectable States and Provinces (without headers)
  static List<String> get selectableStatesAndProvinces {
    return [...usStates, ...canadianProvinces];
  }
}

/// Service for Google Places API integration
class PlacesService {
  /// Google Places API key - replace with your actual key
  static const String apiKey = 'AIzaSyDlBmY577eFgW_PNljTPKtTw72xZYcp7OQ';

  /// Map of US state names to abbreviations
  static const Map<String, String> usStateAbbreviations = {
    'Alabama': 'AL',
    'Alaska': 'AK',
    'Arizona': 'AZ',
    'Arkansas': 'AR',
    'California': 'CA',
    'Colorado': 'CO',
    'Connecticut': 'CT',
    'Delaware': 'DE',
    'Florida': 'FL',
    'Georgia': 'GA',
    'Hawaii': 'HI',
    'Idaho': 'ID',
    'Illinois': 'IL',
    'Indiana': 'IN',
    'Iowa': 'IA',
    'Kansas': 'KS',
    'Kentucky': 'KY',
    'Louisiana': 'LA',
    'Maine': 'ME',
    'Maryland': 'MD',
    'Massachusetts': 'MA',
    'Michigan': 'MI',
    'Minnesota': 'MN',
    'Mississippi': 'MS',
    'Missouri': 'MO',
    'Montana': 'MT',
    'Nebraska': 'NE',
    'Nevada': 'NV',
    'New Hampshire': 'NH',
    'New Jersey': 'NJ',
    'New Mexico': 'NM',
    'New York': 'NY',
    'North Carolina': 'NC',
    'North Dakota': 'ND',
    'Ohio': 'OH',
    'Oklahoma': 'OK',
    'Oregon': 'OR',
    'Pennsylvania': 'PA',
    'Rhode Island': 'RI',
    'South Carolina': 'SC',
    'South Dakota': 'SD',
    'Tennessee': 'TN',
    'Texas': 'TX',
    'Utah': 'UT',
    'Vermont': 'VT',
    'Virginia': 'VA',
    'Washington': 'WA',
    'West Virginia': 'WV',
    'Wisconsin': 'WI',
    'Wyoming': 'WY',
    'District of Columbia': 'DC',
  };

  /// Map of Canadian province names to abbreviations
  static const Map<String, String> canadianProvinceAbbreviations = {
    'Alberta': 'AB',
    'British Columbia': 'BC',
    'Manitoba': 'MB',
    'New Brunswick': 'NB',
    'Newfoundland and Labrador': 'NL',
    'Northwest Territories': 'NT',
    'Nova Scotia': 'NS',
    'Nunavut': 'NU',
    'Ontario': 'ON',
    'Prince Edward Island': 'PE',
    'Quebec': 'QC',
    'Saskatchewan': 'SK',
    'Yukon': 'YT',
  };

  /// Get state/province abbreviation from full name
  static String? getAbbreviation(String stateOrProvince) {
    return usStateAbbreviations[stateOrProvince] ??
        canadianProvinceAbbreviations[stateOrProvince];
  }

  /// Check if a state/province is in the US
  static bool isUSState(String stateOrProvince) {
    return usStateAbbreviations.containsKey(stateOrProvince);
  }

  /// Check if a state/province is in Canada
  static bool isCanadianProvince(String stateOrProvince) {
    return canadianProvinceAbbreviations.containsKey(stateOrProvince);
  }

  /// Get the country code for a state/province
  static String? getCountryCode(String stateOrProvince) {
    if (isUSState(stateOrProvince)) return 'us';
    if (isCanadianProvince(stateOrProvince)) return 'ca';
    return null;
  }
}

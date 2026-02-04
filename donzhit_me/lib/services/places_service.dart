import 'dart:convert';
import 'package:http/http.dart' as http;

/// City prediction from Google Places API
class CityPrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  CityPrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });

  factory CityPrediction.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] as Map<String, dynamic>?;
    return CityPrediction(
      placeId: json['place_id'] as String? ?? '',
      mainText: structuredFormatting?['main_text'] as String? ?? json['description'] as String? ?? '',
      secondaryText: structuredFormatting?['secondary_text'] as String? ?? '',
      fullText: json['description'] as String? ?? '',
    );
  }
}

/// Service for Google Places API integration
class PlacesService {
  /// Google Places API key - replace with your actual key
  static const String apiKey = 'AIzaSyDlBmY577eFgW_PNljTPKtTw72xZYcp7OQ';

  /// Search for cities within a specific state/province
  /// Appends state name to query for better regional results
  static Future<List<CityPrediction>> searchCities(String query, String stateOrProvince) async {
    if (query.isEmpty) return [];

    final countryCode = getCountryCode(stateOrProvince);
    if (countryCode == null) return [];

    // Append state name to query to bias results to that state
    final biasedQuery = '$query, $stateOrProvince';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(biasedQuery)}'
      '&types=(cities)'
      '&components=country:$countryCode'
      '&key=$apiKey'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final predictions = data['predictions'] as List<dynamic>? ?? [];

        // Filter to only include cities that match the selected state
        final stateAbbr = getAbbreviation(stateOrProvince);
        return predictions
            .map((p) => CityPrediction.fromJson(p as Map<String, dynamic>))
            .where((city) {
              // Check if the secondary text contains the state name or abbreviation
              final secondary = city.secondaryText.toLowerCase();
              final stateLower = stateOrProvince.toLowerCase();
              final abbrLower = stateAbbr?.toLowerCase() ?? '';
              return secondary.contains(stateLower) ||
                     secondary.contains(', $abbrLower') ||
                     secondary.endsWith(' $abbrLower');
            })
            .toList();
      }
    } catch (e) {
      // Silently fail - return empty list
    }
    return [];
  }

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

/// Same labels the backend uses (see /meta). Keep them identical.
const List<String> kLanguages = [
  'English',
  'हिंदी (Hindi)',
  'मराठी (Marathi)',
  'தமிழ் (Tamil)',
  'తెలుగు (Telugu)',
  'বাংলা (Bengali)',
  'ગુજરાતી (Gujarati)',
  'ಕನ್ನಡ (Kannada)',
  'മലയാളം (Malayalam)',
  'ਪੰਜਾਬੀ (Punjabi)',
  'ଓଡ଼ିଆ (Odia)',
  'اردو (Urdu)',
  'অসমীয়া (Assamese)',
  'कोंकणी (Konkani)',
];
 
const List<String> kCategories = [
  'Textiles & Sarees',
  'Pottery & Terracotta',
  'Wooden Crafts',
  'Bamboo & Cane',
  'Jewelry',
  'Home Décor',
  'Bags & Accessories',
  'Paintings & Wall Art',
  'Toys & Dolls',
  'Other Handicraft',
];
 
const List<String> kSizes = ['Small', 'Medium', 'Large / Detailed'];
 
/// Mobile number: 10 digits, or +91 followed by 10 digits.
final RegExp kPhoneRegex = RegExp(r'^(\+91)?\d{10}$');
final RegExp kEmailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
 
String cleanPhone(String input) => input.replaceAll(RegExp(r'[\s\-()]'), '');
 
/// 'తెలుగు (Telugu)' -> 'Telugu'
String languageEnglishName(String label) {
  final match = RegExp(r'\(([^)]+)\)').firstMatch(label);
  return match != null ? match.group(1)! : label;
}
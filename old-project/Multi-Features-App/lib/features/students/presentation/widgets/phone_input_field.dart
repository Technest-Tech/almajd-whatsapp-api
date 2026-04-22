import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneInputField extends StatefulWidget {
  final String? initialValue;
  final String? countryCode;
  final Function(String, String) onChanged;
  final String? Function(String?)? validator;
  final String? label;

  const PhoneInputField({
    super.key,
    this.initialValue,
    this.countryCode,
    required this.onChanged,
    this.validator,
    this.label,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  late TextEditingController _controller;
  Country? _selectedCountry;
  String _localNumber = '';

  @override
  void initState() {
    super.initState();
    
    // Initialize country
    if (widget.countryCode != null) {
      try {
        _selectedCountry = Country.parse(widget.countryCode!);
      } catch (e) {
        _selectedCountry = Country.parse('EG'); // Default to Egypt
      }
    } else {
      _selectedCountry = Country.parse('EG');
    }
    
    // Parse initial value to extract country code and local number
    String displayValue = '';
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      final fullNumber = widget.initialValue!.replaceAll(RegExp(r'[^\d]'), '');
      
      // Try to extract country code from the number
      if (fullNumber.startsWith(_selectedCountry!.phoneCode)) {
        _localNumber = fullNumber.substring(_selectedCountry!.phoneCode.length);
        displayValue = '+${_selectedCountry!.phoneCode} $_localNumber';
      } else {
        // Check if it matches any known country code
        final matchedCountry = _findCountryByPhoneCode(fullNumber);
        if (matchedCountry != null) {
          _selectedCountry = matchedCountry;
          _localNumber = fullNumber.substring(matchedCountry.phoneCode.length);
          displayValue = '+${matchedCountry.phoneCode} $_localNumber';
        } else {
          // Assume it's a local number
          _localNumber = fullNumber;
          displayValue = '+${_selectedCountry!.phoneCode} $_localNumber';
        }
      }
    } else {
      displayValue = '+${_selectedCountry!.phoneCode} ';
    }
    
    _controller = TextEditingController(text: displayValue);
  }

  Country? _findCountryByPhoneCode(String phoneNumber) {
    // Common country codes to check
    final commonCountries = ['EG', 'SA', 'AE', 'US', 'GB', 'CA'];
    for (var countryCode in commonCountries) {
      try {
        final country = Country.parse(countryCode);
        if (phoneNumber.startsWith(country.phoneCode)) {
          return country;
        }
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onCountrySelected(Country country) {
    setState(() {
      _selectedCountry = country;
      final maxLocalDigits = _getMaxLocalDigits();
      
      // Truncate local number if it exceeds the new country's max length
      if (maxLocalDigits != null && _localNumber.length > maxLocalDigits) {
        _localNumber = _localNumber.substring(0, maxLocalDigits);
      }
      
      // Update the input to show new country code with existing local number
      _controller.text = '+${country.phoneCode} $_localNumber';
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
    _updatePhoneNumber();
  }

  void _updatePhoneNumber() {
    if (_selectedCountry == null) return;
    
    // Extract local number from the input (remove country code prefix)
    String inputText = _controller.text;
    final expectedPrefix = '+${_selectedCountry!.phoneCode} ';
    
    // Extract the local number part (everything after the prefix)
    if (inputText.startsWith(expectedPrefix)) {
      _localNumber = inputText.substring(expectedPrefix.length).trim();
    } else {
      // If prefix is missing, try to extract from digits
      final digits = inputText.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.startsWith(_selectedCountry!.phoneCode)) {
        _localNumber = digits.substring(_selectedCountry!.phoneCode.length);
      } else {
        _localNumber = digits;
      }
    }
    
    // Update display to show country code + local number
    final displayText = '+${_selectedCountry!.phoneCode} $_localNumber';
    if (_controller.text != displayText) {
      final cursorPosition = _controller.selection.base.offset;
      final wasAtEnd = cursorPosition >= _controller.text.length;
      
      _controller.text = displayText;
      
      // Restore cursor position
      if (wasAtEnd) {
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: displayText.length),
        );
      } else {
        // Try to maintain relative position
        final newPosition = cursorPosition <= displayText.length 
            ? cursorPosition 
            : displayText.length;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: newPosition),
        );
      }
    }
    
    final fullNumber = '${_selectedCountry!.phoneCode}${_localNumber.replaceAll(RegExp(r'[^\d]'), '')}';
    widget.onChanged(fullNumber, _selectedCountry!.countryCode);
  }

  int? _getMaxLocalDigits() {
    if (_selectedCountry == null) return null;
    
    switch (_selectedCountry!.countryCode) {
      case 'EG': // Egypt
        return 10; // Max 10 digits
      case 'SA': // Saudi Arabia
        return 9;
      case 'AE': // UAE
        return 9;
      case 'US': // United States
      case 'CA': // Canada
        return 10;
      case 'GB': // United Kingdom
        return 11; // Max 11 digits
      default:
        return 15; // Generic max for other countries
    }
  }

  int? _getMaxLength() {
    if (_selectedCountry == null) return null;
    final maxLocalDigits = _getMaxLocalDigits();
    if (maxLocalDigits == null) return null;
    // Format: "+{countryCode} {localNumber}"
    // + sign + country code + space + max local digits
    return 1 + _selectedCountry!.phoneCode.length + 1 + maxLocalDigits;
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Let parent validator handle required validation
    }
    
    if (_selectedCountry == null) {
      return 'Please select a country';
    }
    
    // Extract digits only for validation
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    final localDigits = digits.startsWith(_selectedCountry!.phoneCode)
        ? digits.substring(_selectedCountry!.phoneCode.length)
        : digits;
    
    // Country-specific validation
    switch (_selectedCountry!.countryCode) {
      case 'EG': // Egypt
        if (localDigits.length < 9 || localDigits.length > 10) {
          return 'Egyptian phone number must be 9-10 digits';
        }
        if (!localDigits.startsWith('1')) {
          return 'Egyptian mobile numbers must start with 1';
        }
        break;
      case 'SA': // Saudi Arabia
        if (localDigits.length != 9) {
          return 'Saudi phone number must be 9 digits';
        }
        if (!localDigits.startsWith('5')) {
          return 'Saudi mobile numbers must start with 5';
        }
        break;
      case 'AE': // UAE
        if (localDigits.length != 9) {
          return 'UAE phone number must be 9 digits';
        }
        if (!localDigits.startsWith('5')) {
          return 'UAE mobile numbers must start with 5';
        }
        break;
      case 'US': // United States
      case 'CA': // Canada
        if (localDigits.length != 10) {
          return 'Phone number must be 10 digits';
        }
        break;
      case 'GB': // United Kingdom
        if (localDigits.length < 10 || localDigits.length > 11) {
          return 'UK phone number must be 10-11 digits';
        }
        break;
      default:
        // Generic validation for other countries
        if (localDigits.length < 7 || localDigits.length > 15) {
          return 'Phone number must be 7-15 digits';
        }
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          textDirection: TextDirection.ltr,
          children: [
            // Country Code Selector - LTR design
            InkWell(
              onTap: () {
                showCountryPicker(
                  context: context,
                  onSelect: _onCountrySelected,
                  favorite: ['EG', 'SA', 'AE', 'US', 'GB'],
                  showPhoneCode: true,
                  countryListTheme: CountryListThemeData(
                    flagSize: 25,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    textStyle: Theme.of(context).textTheme.bodyLarge,
                    inputDecoration: InputDecoration(
                      labelText: 'Search',
                      hintText: 'Search country',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.ltr,
                  children: [
                    if (_selectedCountry != null) ...[
                      Text(
                        _selectedCountry!.flagEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+${_selectedCountry!.phoneCode}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.public, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Select',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 20,
                      color: Theme.of(context).iconTheme.color,
                    ),
                  ],
                ),
              ),
            ),
            // Phone Number Input - LTR design
            Expanded(
              child: TextFormField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                enabled: true,
                readOnly: false,
                enableInteractiveSelection: true,
                maxLength: _getMaxLength(),
                inputFormatters: [
                  // Allow digits, spaces, and + sign
                  FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+]')),
                ],
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 1,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                  ),
                  hintText: 'Enter phone number',
                  hintTextDirection: TextDirection.ltr,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  counterText: '',
                ),
                onChanged: (value) {
                  if (_selectedCountry == null) return;
                  
                  final expectedPrefix = '+${_selectedCountry!.phoneCode} ';
                  final maxLocalDigits = _getMaxLocalDigits();
                  
                  // Ensure the country code prefix is always present
                  if (value.isEmpty || !value.startsWith(expectedPrefix)) {
                    // If user deleted the prefix or it's missing, restore it
                    if (value.isEmpty) {
                      _controller.text = expectedPrefix;
                      _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: expectedPrefix.length),
                      );
                    } else {
                      // Extract digits and rebuild with prefix
                      final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                      String localNum = '';
                      if (digits.startsWith(_selectedCountry!.phoneCode)) {
                        localNum = digits.substring(_selectedCountry!.phoneCode.length);
                      } else {
                        localNum = digits;
                      }
                      
                      // Limit local number to max digits for the country
                      if (maxLocalDigits != null && localNum.length > maxLocalDigits) {
                        localNum = localNum.substring(0, maxLocalDigits);
                      }
                      
                      _controller.text = '$expectedPrefix$localNum';
                      _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: _controller.text.length),
                      );
                    }
                  } else {
                    // Check if input exceeds max length for the country
                    final localPart = value.substring(expectedPrefix.length);
                    final localDigits = localPart.replaceAll(RegExp(r'[^\d]'), '');
                    
                    if (maxLocalDigits != null && localDigits.length > maxLocalDigits) {
                      // Truncate to max length
                      final truncatedLocal = localDigits.substring(0, maxLocalDigits);
                      _controller.text = '$expectedPrefix$truncatedLocal';
                      _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: _controller.text.length),
                      );
                    }
                  }
                  
                  _updatePhoneNumber();
                },
                validator: widget.validator ?? _validatePhoneNumber,
              ),
            ),
          ],
        ),
      ],
    );
  }
}


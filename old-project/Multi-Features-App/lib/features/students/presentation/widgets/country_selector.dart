import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';

class CountrySelector extends StatelessWidget {
  final String? selectedCountryCode;
  final Function(Country) onCountrySelected;
  final String? label;

  const CountrySelector({
    super.key,
    this.selectedCountryCode,
    required this.onCountrySelected,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    Country? selectedCountry;
    if (selectedCountryCode != null) {
      try {
        selectedCountry = Country.parse(selectedCountryCode!);
      } catch (e) {
        // Invalid country code, ignore
      }
    }

    return InkWell(
      onTap: () {
        showCountryPicker(
          context: context,
          onSelect: onCountrySelected,
          favorite: ['EG', 'SA', 'AE', 'US', 'GB'],
          showPhoneCode: true,
          countryListTheme: CountryListThemeData(
            flagSize: 25,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            textStyle: Theme.of(context).textTheme.bodyLarge,
            inputDecoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.search,
              hintText: AppLocalizations.of(context)!.search,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
          ),
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label ?? AppLocalizations.of(context)!.country,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Row(
          children: [
            if (selectedCountry != null) ...[
              Text(
                selectedCountry.flagEmoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Text(selectedCountry.name),
            ] else
              Text(
                'اختر البلد',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}


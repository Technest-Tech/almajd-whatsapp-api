import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CurrencyHourPriceField extends StatefulWidget {
  final String? initialCurrency;
  final String? initialHourPrice;
  final Function(String?, String?) onChanged;
  final String? Function(String?)? validator;
  final String? label;
  final Map<String, String>? currencies;

  const CurrencyHourPriceField({
    super.key,
    this.initialCurrency,
    this.initialHourPrice,
    required this.onChanged,
    this.validator,
    this.label,
    this.currencies,
  });

  @override
  State<CurrencyHourPriceField> createState() => _CurrencyHourPriceFieldState();
}

class _CurrencyHourPriceFieldState extends State<CurrencyHourPriceField> {
  late TextEditingController _priceController;
  String? _selectedCurrency;

  Map<String, String> get _currencies {
    return widget.currencies ?? {
      'EGP': 'EGP - جنيه مصري',
      'USD': 'USD - US Dollar',
    };
  }

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.initialCurrency ?? 'EGP';
    _priceController = TextEditingController(text: widget.initialHourPrice ?? '');
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _onCurrencySelected(String currency) {
    setState(() {
      _selectedCurrency = currency;
    });
    _notifyChange();
  }

  void _notifyChange() {
    widget.onChanged(
      _selectedCurrency,
      _priceController.text.isEmpty ? null : _priceController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            // Currency Selector
            InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: AlertDialog(
                      title: const Text('اختر العملة'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _currencies.length,
                          itemBuilder: (context, index) {
                            final currency = _currencies.keys.elementAt(index);
                            final label = _currencies[currency]!;
                            final isSelected = _selectedCurrency == currency;
                            return ListTile(
                              title: Text(label),
                              leading: Radio<String>(
                                value: currency,
                                groupValue: _selectedCurrency,
                                onChanged: (value) {
                                  if (value != null) {
                                    _onCurrencySelected(value);
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                              selected: isSelected,
                              onTap: () {
                                _onCurrencySelected(currency);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCurrency ?? 'EGP',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).hintColor,
                    ),
                  ],
                ),
              ),
            ),
            // Hour Price Input
            Expanded(
              child: TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  hintText: 'أدخل السعر بالساعة',
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) => _notifyChange(),
                validator: widget.validator,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

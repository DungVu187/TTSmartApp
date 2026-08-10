import 'package:flutter/material.dart';

import '../../../../core/widgets/searchable_autocomplete_field.dart';
import '../../data/models/company_models.dart';

class CompanyAutocompleteField extends StatelessWidget {
  const CompanyAutocompleteField({
    super.key,
    required this.companies,
    required this.selectedCompanyId,
    required this.onSelected,
    this.onCleared,
    this.enabled = true,
    this.hintText = 'Gõ tên hoặc mã công ty',
    this.labelText = 'Công ty',
    this.compact = false,
    this.borderColor,
    this.borderWidth = 1,
    this.errorText,
    this.validator,
  });

  final List<CompanyResponse> companies;
  final int? selectedCompanyId;
  final ValueChanged<CompanyResponse> onSelected;
  final VoidCallback? onCleared;
  final bool enabled;
  final String hintText;
  final String? labelText;
  final bool compact;
  final Color? borderColor;
  final double borderWidth;
  final String? errorText;
  final String? Function(int? companyId)? validator;

  @override
  Widget build(BuildContext context) {
    return SearchableAutocompleteField<CompanyResponse>(
      options: companies,
      selectedOption: _findSelectedCompany(),
      displayStringForOption: (company) => company.displayName,
      searchStringForOption: (company) {
        final code = company.code?.trim();
        return code == null || code.isEmpty
            ? company.displayName
            : '${company.displayName} $code';
      },
      optionSubtitle: (company) => company.code?.trim(),
      onSelected: onSelected,
      onCleared: onCleared,
      enabled: enabled,
      hintText: hintText,
      labelText: labelText,
      prefixIcon: Icons.apartment_outlined,
      compact: compact,
      borderColor: borderColor,
      borderWidth: borderWidth,
      errorText: errorText,
      validator: validator == null
          ? null
          : (company) => validator!(company?.id),
    );
  }

  CompanyResponse? _findSelectedCompany() {
    for (final company in companies) {
      if (company.id == selectedCompanyId) return company;
    }
    return null;
  }
}

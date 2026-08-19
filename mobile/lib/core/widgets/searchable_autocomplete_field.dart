import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SearchableAutocompleteField<T extends Object> extends StatefulWidget {
  const SearchableAutocompleteField({
    super.key,
    required this.options,
    required this.selectedOption,
    required this.displayStringForOption,
    required this.onSelected,
    required this.hintText,
    required this.labelText,
    required this.prefixIcon,
    this.searchStringForOption,
    this.optionSubtitle,
    this.onCleared,
    this.enabled = true,
    this.compact = false,
    this.loading = false,
    this.showDropdownIcon = false,
    this.borderColor,
    this.borderWidth = 1,
    this.errorText,
    this.validator,
  });

  final List<T> options;
  final T? selectedOption;
  final String Function(T option) displayStringForOption;
  final String Function(T option)? searchStringForOption;
  final String? Function(T option)? optionSubtitle;
  final ValueChanged<T> onSelected;
  final VoidCallback? onCleared;
  final bool enabled;
  final bool compact;
  final bool loading;
  final bool showDropdownIcon;
  final Color? borderColor;
  final double borderWidth;
  final String hintText;
  final String? labelText;
  final IconData prefixIcon;
  final String? errorText;
  final String? Function(T? option)? validator;

  @override
  State<SearchableAutocompleteField<T>> createState() =>
      _SearchableAutocompleteFieldState<T>();
}

class _SearchableAutocompleteFieldState<T extends Object>
    extends State<SearchableAutocompleteField<T>> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  late String _selectedText;

  @override
  void initState() {
    super.initState();
    _selectedText = _displaySelectedOption();
    _textController = TextEditingController(text: _selectedText);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant SearchableAutocompleteField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousSelectedText = _selectedText;
    final nextSelectedText = _displaySelectedOption();
    if (nextSelectedText == previousSelectedText) return;
    _selectedText = nextSelectedText;
    if (!_focusNode.hasFocus || _textController.text == previousSelectedText) {
      _textController.value = TextEditingValue(
        text: nextSelectedText,
        selection: TextSelection.collapsed(offset: nextSelectedText.length),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;
        return RawAutocomplete<T>(
          textEditingController: _textController,
          focusNode: _focusNode,
          displayStringForOption: widget.displayStringForOption,
          optionsBuilder: _optionsBuilder,
          onSelected: (option) {
            _selectedText = widget.displayStringForOption(option);
            widget.onSelected(option);
            _focusNode.unfocus();
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              enabled: widget.enabled,
              textInputAction: TextInputAction.search,
              style: widget.compact
                  ? const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w400,
                    )
                  : null,
              decoration: _decoration(),
              onTap: _selectCurrentText,
              onTapOutside: (_) => focusNode.unfocus(),
              onFieldSubmitted: (_) => onFieldSubmitted(),
              validator: widget.validator == null
                  ? null
                  : (_) => widget.validator!(widget.selectedOption),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final matches = options.toList(growable: false);
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SizedBox(
                    width: fieldWidth.clamp(0.0, 520.0).toDouble(),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final option = matches[index];
                        final subtitle = widget.optionSubtitle?.call(option);
                        return ListTile(
                          dense: widget.compact,
                          leading: Icon(widget.prefixIcon, size: 20),
                          title: Text(widget.displayStringForOption(option)),
                          subtitle: subtitle == null || subtitle.trim().isEmpty
                              ? null
                              : Text(subtitle),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Iterable<T> _optionsBuilder(TextEditingValue textEditingValue) {
    if (!widget.enabled) return Iterable<T>.empty();
    final query = textEditingValue.text.trim().toLowerCase();
    if (query.isEmpty || query == _selectedText.trim().toLowerCase()) {
      return widget.options;
    }
    return widget.options.where((option) {
      final searchableText =
          widget.searchStringForOption?.call(option) ??
          widget.displayStringForOption(option);
      return searchableText.toLowerCase().contains(query);
    });
  }

  InputDecoration _decoration() {
    final suffixIcon = _suffixIcon();
    final borderSide = BorderSide(
      color: widget.borderColor ?? AppColors.border,
      width: widget.borderWidth,
    );
    return InputDecoration(
      labelText: widget.labelText,
      hintText: widget.hintText,
      isDense: widget.compact,
      floatingLabelBehavior: widget.compact
          ? FloatingLabelBehavior.always
          : null,
      contentPadding: widget.compact
          ? const EdgeInsets.symmetric(horizontal: 10)
          : null,
      prefixIcon: Icon(widget.prefixIcon, size: widget.compact ? 16 : 24),
      prefixIconConstraints: widget.compact
          ? const BoxConstraints(minWidth: 36, minHeight: 38)
          : null,
      suffixIcon: suffixIcon,
      suffixIconConstraints: widget.compact
          ? const BoxConstraints(minWidth: 36, minHeight: 38)
          : null,
      labelStyle: widget.compact
          ? const TextStyle(
              color: Color(0xFF374151),
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w500,
            )
          : null,
      floatingLabelStyle: widget.compact
          ? const TextStyle(
              color: Color(0xFF374151),
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w500,
            )
          : null,
      hintStyle: widget.compact
          ? const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w400,
            )
          : null,
      border: widget.compact
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: borderSide,
            )
          : null,
      enabledBorder: widget.compact
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: borderSide,
            )
          : null,
      disabledBorder: widget.compact
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: borderSide,
            )
          : null,
      focusedBorder: widget.compact
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.brandBlue,
                width: 1.5,
              ),
            )
          : null,
      errorText: widget.errorText,
    );
  }

  Widget _suffixIcon() {
    if (widget.loading) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (widget.onCleared != null && widget.selectedOption != null) {
      return SizedBox.square(
        dimension: widget.compact ? 36 : 48,
        child: IconButton(
          tooltip: 'Xóa lựa chọn',
          onPressed: widget.enabled ? _clearSelection : null,
          padding: EdgeInsets.zero,
          icon: Icon(Icons.close, size: widget.compact ? 16 : 18),
        ),
      );
    }
    if (!widget.showDropdownIcon) {
      return Icon(Icons.search, size: widget.compact ? 16 : 18);
    }
    return SizedBox.square(
      dimension: widget.compact ? 36 : 48,
      child: IconButton(
        tooltip: 'Mở danh sách',
        onPressed: widget.enabled ? _openOptions : null,
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: widget.compact ? 18 : 22,
        ),
      ),
    );
  }

  void _openOptions() {
    _focusNode.requestFocus();
    _selectCurrentText();
  }

  void _selectCurrentText() {
    if (_selectedText.isEmpty || _textController.text != _selectedText) return;
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _textController.text.length,
    );
  }

  void _clearSelection() {
    _selectedText = '';
    _textController.clear();
    widget.onCleared?.call();
    _focusNode.requestFocus();
  }

  String _displaySelectedOption() {
    final selectedOption = widget.selectedOption;
    return selectedOption == null
        ? ''
        : widget.displayStringForOption(selectedOption);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons.dart';
import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';
import 'clay_surface.dart';

/// Text field (`.lp-field`): visible label above, pressed-clay pill input,
/// helper or error text below. Errors are shown with text and an icon, not
/// colour alone.
class ClayTextField extends StatelessWidget {
  const ClayTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.enabled = true,
    this.autofillHints,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final theme = Theme.of(context).textTheme;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(
                left: ClaySpace.s2, bottom: ClaySpace.s1),
            child: Text(label,
                style: theme.labelSmall!.copyWith(color: p.ink)),
          ),
        ),
        ClaySurface(
          radius: ClayRadii.pill,
          color: enabled ? p.card : p.line,
          elevation: ClayElevation.pressed,
          borderColor: hasError ? p.dangerDeep : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: ClaySize.touch),
            child: Row(
              children: [
                if (prefixIcon != null)
                  Padding(
                    padding: const EdgeInsets.only(left: ClaySpace.s4),
                    child: Icon(prefixIcon, size: 20, color: p.primaryDeep),
                  ),
                Expanded(
                  child: Semantics(
                    label: label,
                    textField: true,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      obscureText: obscureText,
                      keyboardType: keyboardType,
                      textInputAction: textInputAction,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      inputFormatters: inputFormatters,
                      autofillHints: autofillHints,
                      cursorColor: p.primaryDeep,
                      style: theme.bodyLarge,
                      decoration: InputDecoration(
                        isCollapsed: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: hint,
                        hintStyle:
                            theme.bodyLarge!.copyWith(color: p.quiet),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: ClaySpace.s4, vertical: ClaySpace.s3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError || helperText != null)
          Padding(
            padding: const EdgeInsets.only(
                left: ClaySpace.s2, top: ClaySpace.s1),
            child: Semantics(
              liveRegion: hasError,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasError) ...[
                    Icon(ClayIcons.warning, size: 16, color: p.dangerDeep),
                    const SizedBox(width: ClaySpace.s1),
                  ],
                  Expanded(
                    child: Text(
                      errorText ?? helperText!,
                      style: theme.bodySmall!.copyWith(
                          color: hasError ? p.dangerDeep : p.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

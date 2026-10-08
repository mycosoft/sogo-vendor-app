import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';

class SogoButton extends StatelessWidget {
  const SogoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.variant = SogoButtonVariant.primary,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final SogoButtonVariant variant;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final btn = _buildButton();
    if (!fullWidth) return btn;
    return SizedBox(width: double.infinity, child: btn);
  }

  Widget _buildButton() {
    switch (variant) {
      case SogoButtonVariant.primary:
        return ElevatedButton(
          onPressed: loading ? null : onPressed,
          child: _content(),
        );
      case SogoButtonVariant.outline:
        return OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: SogoSpacing.xl,
              vertical: SogoSpacing.md + 4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SogoRadius.md),
            ),
            side: const BorderSide(color: SogoColors.primary, width: 1.5),
            foregroundColor: SogoColors.primary,
            textStyle: SogoText.button.copyWith(color: SogoColors.primary),
          ),
          child: _content(),
        );
      case SogoButtonVariant.danger:
        return ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: SogoColors.danger,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: SogoSpacing.xl,
              vertical: SogoSpacing.md + 4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SogoRadius.md),
            ),
          ),
          child: _content(color: Colors.white),
        );
      case SogoButtonVariant.text:
        return TextButton(
          onPressed: loading ? null : onPressed,
          style: TextButton.styleFrom(foregroundColor: SogoColors.primary),
          child: _content(),
        );
    }
  }

  Widget _content({Color? color}) {
    if (loading) {
      return SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: color ?? Colors.white),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: SogoText.button.copyWith(color: color)),
        ],
      );
    }
    return Text(label, style: SogoText.button.copyWith(color: color));
  }
}

enum SogoButtonVariant { primary, outline, danger, text }

class SogoCard extends StatelessWidget {
  const SogoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SogoSpacing.lg),
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? SogoColors.surface,
        borderRadius: BorderRadius.circular(SogoRadius.lg),
        boxShadow: const [SogoShadows.card],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SogoRadius.lg),
        child: card,
      ),
    );
  }
}

class SogoTextField extends StatelessWidget {
  const SogoTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label,
                style: SogoText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
          ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: obscureText ? 1 : maxLines,
          validator: validator,
          onChanged: onChanged,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          style: SogoText.bodyLg,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: SogoColors.textMuted)
                : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class SogoBadge extends StatelessWidget {
  const SogoBadge(
      {super.key,
      required this.label,
      this.color = SogoColors.primary,
      this.bgColor});

  final String label;
  final Color color;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(SogoRadius.pill),
      ),
      child: Text(
        label.toUpperCase(),
        style: SogoText.labelMd.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

class SogoStatCard extends StatelessWidget {
  const SogoStatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = SogoColors.primary,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SogoCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(SogoRadius.md),
            ),
            child: Icon(icon ?? Icons.star, color: color, size: 22),
          ),
          const SizedBox(width: SogoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: SogoText.bodySm
                        .copyWith(color: SogoColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: SogoText.headlineMd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SogoSectionTitle extends StatelessWidget {
  const SogoSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SogoSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(title, style: SogoText.headlineMd)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class SogoEmptyState extends StatelessWidget {
  const SogoEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SogoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: SogoColors.textMuted),
          const SizedBox(height: SogoSpacing.md),
          Text(title, style: SogoText.headlineMd, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style:
                    SogoText.bodyMd.copyWith(color: SogoColors.textSecondary),
                textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: SogoSpacing.lg),
            action!
          ],
        ],
      ),
    );
  }
}

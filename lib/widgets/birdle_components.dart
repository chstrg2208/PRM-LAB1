import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Primary action button (Solid Emerald, 8px radius)
class BirdlePrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? height;

  const BirdlePrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.height = 38,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: BirdleColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: BirdleColors.brand.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BirdleRadius.smBorder),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: BirdleTypography.fontFamily,
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// Secondary action button (White surface, thin border #E5E7EB)
class BirdleSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final double? height;
  final bool isLoading;

  const BirdleSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.iconColor,
    this.height = 38,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: BirdleColors.surface,
          foregroundColor: BirdleColors.textPrimary,
          disabledBackgroundColor: BirdleColors.surface,
          disabledForegroundColor: BirdleColors.textDisabled,
          side: const BorderSide(color: BirdleColors.border, width: 1),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BirdleRadius.smBorder),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFamily: BirdleTypography.fontFamily,
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BirdleColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
            ] else if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor ?? BirdleColors.textSecondary),
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Ghost / Subtle text action button
class BirdleGhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;

  const BirdleGhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? BirdleColors.textSecondary;
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: c,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BirdleRadius.smBorder),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          fontFamily: BirdleTypography.fontFamily,
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
  }
}

/// Standard Container Card (12px radius, #FFFFFF, border #E5E7EB)
class BirdleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderSide? border;

  const BirdleCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? BirdleColors.surface,
        borderRadius: BirdleRadius.mdBorder,
        border: Border.fromBorderSide(border ?? const BorderSide(color: BirdleColors.border, width: 1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Section Header with title, optional subtitle, and actions
class BirdleSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const BirdleSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: BirdleTypography.sectionTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: BirdleTypography.metadata),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Search text field
class BirdleSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final double width;

  const BirdleSearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText = 'Search...',
    this.width = 240,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 36,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: BirdleColors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 12.5, color: BirdleColors.textMuted),
          prefixIcon: const Icon(Icons.search, size: 16, color: BirdleColors.textMuted),
          prefixIconConstraints: const BoxConstraints(minWidth: 32),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 14, color: BirdleColors.textMuted),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    controller.clear();
                    if (onChanged != null) onChanged!('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
          filled: true,
          fillColor: BirdleColors.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BirdleRadius.smBorder,
            borderSide: const BorderSide(color: BirdleColors.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BirdleRadius.smBorder,
            borderSide: const BorderSide(color: BirdleColors.brand, width: 1.2),
          ),
        ),
      ),
    );
  }
}

/// Empty state presentation
class BirdleEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  const BirdleEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BirdleColors.surfaceSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: BirdleColors.border),
              ),
              child: Icon(icon, size: 32, color: BirdleColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(title, style: BirdleTypography.cardTitle),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: BirdleTypography.metadata,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

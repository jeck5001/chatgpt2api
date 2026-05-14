import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

/// Kiln dark theme — the only theme the app ships with for now.
///
/// Pulls every color, radius, shadow, and font from [KilnColors], [KilnRadii],
/// [KilnShadows], and [KilnTypography]. Adjust those token files to retune
/// the app's look; this file should rarely need to change.
ThemeData buildImageStudioTheme() {
  final scheme = const ColorScheme.dark(
    primary: KilnColors.ember500,
    onPrimary: Color(0xFF1A0E04),
    primaryContainer: KilnColors.ember700,
    onPrimaryContainer: KilnColors.ember300,
    secondary: KilnColors.ember400,
    onSecondary: Color(0xFF1A0E04),
    surface: KilnColors.ink900,
    onSurface: KilnColors.ink100,
    surfaceContainerLowest: KilnColors.ink950,
    surfaceContainerLow: KilnColors.ink900,
    surfaceContainer: KilnColors.ink850,
    surfaceContainerHigh: KilnColors.ink800,
    surfaceContainerHighest: KilnColors.ink700,
    onSurfaceVariant: KilnColors.ink300,
    outline: KilnColors.ink600,
    outlineVariant: KilnColors.ink700,
    error: KilnColors.danger,
    onError: Color(0xFF1A0807),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: KilnColors.ink950,
    canvasColor: KilnColors.ink950,
    splashFactory: InkSparkle.splashFactory,
    textTheme: KilnTypography.textTheme,
    primaryTextTheme: KilnTypography.textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: KilnColors.ink950,
      foregroundColor: KilnColors.ink100,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: KilnTypography.titleL,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: KilnColors.ink900,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KilnRadii.card),
        side: const BorderSide(color: KilnColors.hairline, width: 1),
      ),
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: KilnColors.hairline,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KilnColors.ink900,
      hintStyle: KilnTypography.ui(color: KilnColors.ink500),
      labelStyle: KilnTypography.label,
      floatingLabelStyle: KilnTypography.label.copyWith(
        color: KilnColors.ember400,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KilnSpacing.md,
        vertical: KilnSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KilnRadii.input),
        borderSide: const BorderSide(color: KilnColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KilnRadii.input),
        borderSide: const BorderSide(color: KilnColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KilnRadii.input),
        borderSide: const BorderSide(color: KilnColors.ember500, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KilnRadii.input),
        borderSide: const BorderSide(color: KilnColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KilnColors.ember500,
        foregroundColor: const Color(0xFF1A0E04),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: KilnSpacing.xl),
        textStyle: KilnTypography.ui(
          size: 14,
          weight: FontWeight.w600,
          color: const Color(0xFF1A0E04),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KilnRadii.button),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: KilnColors.ink800,
        foregroundColor: KilnColors.ink100,
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: KilnSpacing.xl),
        textStyle: KilnTypography.ui(size: 14, weight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KilnRadii.button),
          side: const BorderSide(color: KilnColors.hairline),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KilnColors.ink200,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: KilnSpacing.xl),
        textStyle: KilnTypography.ui(size: 14, weight: FontWeight.w600),
        side: const BorderSide(color: KilnColors.hairlineStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KilnRadii.button),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KilnColors.ember400,
        textStyle: KilnTypography.ui(size: 14, weight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KilnRadii.button),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: KilnColors.ink200,
        backgroundColor: KilnColors.overlayWeak,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KilnRadii.md),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: KilnColors.ink800,
      selectedColor: const Color(0x1FE8A84A),
      labelStyle: KilnTypography.chipMono,
      secondaryLabelStyle: KilnTypography.chipMono.copyWith(
        color: KilnColors.ember400,
      ),
      side: const BorderSide(color: KilnColors.hairlineStrong),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: KilnSpacing.sm),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: KilnColors.ink900,
      indicatorColor: const Color(0x1FE8A84A),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return KilnTypography.ui(
          size: 11,
          weight: FontWeight.w600,
          color: selected ? KilnColors.ember400 : KilnColors.ink400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? KilnColors.ember400 : KilnColors.ink400,
          size: 22,
        );
      }),
      height: 68,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: KilnColors.ink900,
      indicatorColor: const Color(0x1FE8A84A),
      selectedIconTheme: const IconThemeData(
        color: KilnColors.ember400,
        size: 24,
      ),
      unselectedIconTheme: const IconThemeData(
        color: KilnColors.ink400,
        size: 22,
      ),
      selectedLabelTextStyle: KilnTypography.ui(
        size: 12,
        weight: FontWeight.w600,
        color: KilnColors.ember400,
      ),
      unselectedLabelTextStyle: KilnTypography.ui(
        size: 12,
        color: KilnColors.ink400,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: KilnColors.ink800,
      contentTextStyle: KilnTypography.ui(size: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KilnRadii.md),
        side: const BorderSide(color: KilnColors.hairline),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: KilnColors.ember500,
      linearTrackColor: KilnColors.ink700,
      circularTrackColor: KilnColors.ink700,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: KilnColors.ember500,
      inactiveTrackColor: KilnColors.ink700,
      thumbColor: KilnColors.ember400,
      overlayColor: const Color(0x33E8A84A),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? Colors.white
            : KilnColors.ink300;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? KilnColors.ember500
            : KilnColors.ink700;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: KilnColors.ink300,
      textColor: KilnColors.ink100,
      titleTextStyle: KilnTypography.ui(size: 14, weight: FontWeight.w500),
      subtitleTextStyle: KilnTypography.metaMono,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KilnRadii.md),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: KilnColors.ink900,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KilnRadii.card),
        side: const BorderSide(color: KilnColors.hairline),
      ),
      titleTextStyle: KilnTypography.display(size: 20, weight: FontWeight.w500),
      contentTextStyle: KilnTypography.bodyM,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: KilnColors.ink900,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KilnRadii.xl)),
      ),
      modalBarrierColor: const Color(0xB3000000),
    ),
  );
}

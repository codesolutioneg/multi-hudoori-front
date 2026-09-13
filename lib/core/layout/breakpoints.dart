import 'package:flutter/material.dart';

bool isMobile(BuildContext context) => MediaQuery.sizeOf(context).width < 768;

/// Collapse the sidebar / use denser layout below this window width.
/// Kept above ~1100 so medium laptop widths (with DevTools open) still
/// leave enough room for page headers with many action buttons.
bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width < 1280;

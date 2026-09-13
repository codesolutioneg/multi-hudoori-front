const double employeesShortViewportThreshold = 560;

/// Android removes the software-keyboard inset from the layout height.
/// Adding it back keeps structural responsive decisions stable while typing.
bool useShortEmployeesViewport({
  required double layoutHeight,
  required double keyboardInset,
}) => layoutHeight + keyboardInset < employeesShortViewportThreshold;

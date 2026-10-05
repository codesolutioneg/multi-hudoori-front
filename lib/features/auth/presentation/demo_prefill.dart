import 'demo_prefill_stub.dart'
    if (dart.library.html) 'demo_prefill_web.dart' as impl;

Map<String, String>? readDemoPrefillFromBrowser() =>
    impl.readDemoPrefillFromBrowser();

void clearDemoPrefillInBrowser() => impl.clearDemoPrefillInBrowser();

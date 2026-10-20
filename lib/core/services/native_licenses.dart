import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerNativeLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Lobe Icons (AI brand SVGs)',
    ], await rootBundle.loadString('assets/licenses/lobe-icons.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'CrispASR native 0.8.37 and bundled components',
    ], await rootBundle.loadString('assets/licenses/crispasr-native.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'LLVM native runtime (Android NDK 27.0.12077973)',
    ], await rootBundle.loadString('assets/licenses/llvm-native.txt'));
  });
}

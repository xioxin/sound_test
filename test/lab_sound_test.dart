import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lab_sound/lab_sound.dart';

void main() {
  const MethodChannel channel = MethodChannel('lab_sound');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

}

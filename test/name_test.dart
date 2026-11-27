import 'package:flutter_test/flutter_test.dart';
import 'package:sliceofgourmet/core/profile/display_name.dart';

void main() {
  test('firstNameOf trims, takes the first word and capitalizes it', () {
    expect(firstNameOf(null), isNull);
    expect(firstNameOf(''), isNull);
    expect(firstNameOf('   '), isNull);
    expect(firstNameOf('imran'), 'Imran');
    expect(firstNameOf('  mary jane '), 'Mary');
    expect(firstNameOf('McDonald'), 'McDonald');
    expect(firstNameOf('i'), 'I');
  });

  test('homeGreeting uses the first name or a fallback', () {
    expect(homeGreeting(null), 'Hi there');
    expect(homeGreeting(''), 'Hi there');
    expect(homeGreeting('   '), 'Hi there');
    expect(homeGreeting('imran khan'), 'Hi, Imran');
    expect(homeGreeting('Sammy'), 'Hi, Sammy');
  });
}

import 'dart:convert';
import 'dart:io';

/// Raw text of a fixture captured from the live API.
String fixtureText(String name) =>
    File('test/fixtures/$name').readAsStringSync();

Object? fixture(String name) => jsonDecode(fixtureText(name));

Map<String, dynamic> fixtureMap(String name) =>
    Map<String, dynamic>.from(fixture(name) as Map);

List<Map<String, dynamic>> fixtureList(String name) => (fixture(name) as List)
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

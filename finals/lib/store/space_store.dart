import 'package:flutter/material.dart';
import '../models/space.dart';

class SpaceStore extends ChangeNotifier {
  SpaceStore._();

  static final SpaceStore instance = SpaceStore._();

  final List<Space> _spaces = [];

  List<Space> get spaces => _spaces;

  void addSpace(Space space) {
    _spaces.add(space);
    notifyListeners();
  }

  void removeSpace(Space space) {
    _spaces.remove(space);
    notifyListeners();
  }
}
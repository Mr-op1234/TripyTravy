import 'dart:convert';
import '../../domain/entities/trip_package.dart';

class ProtobufTripMapper {
  const ProtobufTripMapper();

  List<int> toWireBytes(TripPackage trip) {
    return utf8.encode(jsonEncode(trip.toJson()));
  }

  TripPackage fromWireBytes(List<int> bytes) {
    final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return TripPackage.fromJson(map);
  }
}

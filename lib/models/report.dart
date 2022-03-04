import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final GeoPoint location;
  final Timestamp created_at;
  final int num;


  Report(this.location, this.created_at, this.num);

  Report.fromJson(Map<String, dynamic> json)
      : location = json['location'],
        created_at = json['created_at'],
        num = json['num'];

  Map<String, dynamic> toJson() => {
    'location': location,
    'created_at': created_at,
    'num': num
  };
}
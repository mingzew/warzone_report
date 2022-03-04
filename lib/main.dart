import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:warzone_report/utils.dart';
import 'package:intl/intl.dart';

import 'models/exceptions/no_marker_exception.dart';
import 'models/report.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseRemoteConfig.instance.ensureInitialized();
  await FirebaseRemoteConfig.instance.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(seconds: 10),
    minimumFetchInterval: const Duration(hours: 1),
  ));
  await FirebaseRemoteConfig.instance.setDefaults(<String, dynamic>{
    'database_coll': 'reports',
    'hello': 'default hello',
  });
  await FirebaseRemoteConfig.instance.fetchAndActivate();
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'War zone Report',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FirebaseRemoteConfig firebaseRemoteConfig = FirebaseRemoteConfig.instance;
  Completer<GoogleMapController> _controller = Completer();
  late CollectionReference reports;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool ukrainian = false;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(50.4501, 30.5234),
    zoom: 14.4746,
  );

  Map<MarkerId, Marker> existingMarkers = <MarkerId, Marker>{};
  LatLng? reportLatLng;
  Marker? myMarker;
  late final Stream<QuerySnapshot> _recordStream;

  String title = "War Zone Self Report System";
  String reportStr = "Report";
  String warningMsg = "Please press and hold to select a new location or select an existing marker";
  double titleSize = 24.0;

  @override
  void initState() {
    super.initState();

    reports = FirebaseFirestore.instance.collection(FirebaseRemoteConfig.instance.getString('database_coll'));
    _recordStream = reports
        .where('created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))))
        .orderBy('created_at')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    _recordStream.listen((event) {
      onData:
      (data) {
        int i = 1;
      };
    });
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontSize: titleSize),),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.emoji_flags,color: Colors.yellow,),
            tooltip: 'Change language',
            onPressed: () {
              setState(() {
                if (ukrainian) {
                  title = "War Zone Self Report System";
                  reportStr = "Report";
                  warningMsg = "Please press and hold to select a new location or select an existing marker";
                  titleSize = 24;
                  ukrainian = false;
                } else {
                  title = "Система самодоповіді в зоні бойових дій";
                  reportStr = "Звіт";
                  warningMsg = "Натисніть і утримуйте, щоб вибрати нове місце або вибрати наявний маркер";
                  titleSize = 16;
                  ukrainian = true;
                }
              });
              // handle the press
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
                child: StreamBuilder<QuerySnapshot>(
              stream: _recordStream,
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return const Text('Something went wrong');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text("Loading");
                }
                existingMarkers = <MarkerId, Marker>{};
                snapshot.data!.docs.map((DocumentSnapshot document) {
                  Marker tmpMarker;
                  Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
                  final MarkerId markerId = MarkerId("[${data['location'].latitude},${data['location'].longitude}]");
                  Timestamp lastUpdate = data['created_at'];
                  int count = 1;
                  if (existingMarkers.containsKey(markerId)) {
                    count = (int.parse(existingMarkers[markerId]!.infoWindow.snippet!)) + 1;
                    // if((markers[markerId]!.infoWindow.title as Timestamp).millisecondsSinceEpoch < lastUpdate.millisecondsSinceEpoch) {
                    //   lastUpdate
                    // }
                  }
                  tmpMarker = Marker(
                      markerId: markerId,
                      draggable: true,
                      position: LatLng(data['location'].latitude as double, data['location'].longitude as double),
                      //With this parameter you automatically obtain latitude and longitude
                      infoWindow: InfoWindow(
                          title: DateFormat.jm()
                              .format(DateTime.fromMillisecondsSinceEpoch(lastUpdate.millisecondsSinceEpoch)),
                          snippet: count.toString()),
                      icon: BitmapDescriptor.defaultMarker,
                      onTap: () => reportLatLng =
                          LatLng(data['location'].latitude as double, data['location'].longitude as double));
                  existingMarkers[markerId] = tmpMarker;
                  return tmpMarker;
                }).toList();
                return GoogleMap(
                    mapType: MapType.hybrid,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    initialCameraPosition: _kGooglePlex,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                    compassEnabled: true,
                    tiltGesturesEnabled: false,
                    onLongPress: (latlang) {
                      _addMarkerLongPressed(latlang); //we will call this function when pressed on the map
                    },
                    markers: myMarker == null
                        ? Set.of(existingMarkers.values)
                        : (Set.of(existingMarkers.values)..addAll([myMarker!])));
              },
            )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addReport(),
        label: Text(reportStr),
        icon: const Icon(Icons.directions_boat),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future _addMarkerLongPressed(LatLng latlang) async {
    setState(() {
      if (myMarker != null) {
        //remove previous marker
        // existingMarkers.remove(MarkerId("[${myMarker!.position.latitude},${myMarker!.position.longitude}]"));
        myMarker = null;
      }
      final MarkerId markerId = MarkerId("[${latlang.latitude},${latlang.longitude}]");
      myMarker = Marker(
        markerId: markerId,
        draggable: false,
        position: latlang,
        icon: BitmapDescriptor.defaultMarker,
      );
      reportLatLng = myMarker!.position;
    });

    //This is optional, it will zoom when the marker has been created
    GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(latlang, 17.0));
  }

  Future<String?> getUserCountryName() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    debugPrint('location: ${position.latitude}');
    var addresses = await placemarkFromCoordinates(position.latitude, position.longitude);
    var first = addresses.first;
    return first.country?.toLowerCase(); // this will return country name
  }

  Future<void> getReports() {
    return reports
        .where('created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))))
        .get()
        .then((QuerySnapshot querySnapshot) {
      querySnapshot.docs.asMap().forEach((index, doc) {
        final c = doc['location'] as GeoPoint;
        print("${c.latitude},${c.longitude}");
      });
    }).catchError((error) => print("Failed to add user: $error"));
  }

  Future<void> addReport() {
    if (reportLatLng == null) {
      showInSnackBar(_scaffoldKey, warningMsg);
      throw NoMarkerException("No marker selected");
    } else {
      return reports
          .add(Report(GeoPoint(reportLatLng!.latitude, reportLatLng!.longitude), Timestamp.now(), 1).toJson())
          .then((value) => print("Point Added"))
          .catchError((error) => print("Failed to add user: $error"));
    }
  }
}

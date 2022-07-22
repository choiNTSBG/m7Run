import 'dart:async';
import 'dart:math';

import 'package:permission_handler/permission_handler.dart';

import 'package:flutter/material.dart';
import 'package:health/health.dart';

void main() => runApp(HealthApp());

class HealthApp extends StatefulWidget {
  @override
  _HealthAppState createState() => _HealthAppState();
}

enum AppState {
  DATA_NOT_FETCHED,
  FETCHING_DATA,
  DATA_READY,
  NO_DATA,
  AUTH_NOT_GRANTED,
  DATA_ADDED,
  DATA_NOT_ADDED,
  STEPS_READY,
}

class _HealthAppState extends State<HealthApp> {
  List<HealthDataPoint> _healthDataList = [];
  AppState _state = AppState.DATA_NOT_FETCHED;
  int _nofSteps = 10;
  double _mgdl = 10.0;

  // create a HealthFactory for use in the app
  HealthFactory health = HealthFactory();

  /// Fetch data points from the health plugin and show them in the app.
  Future fetchData() async {
    setState(() => _state = AppState.FETCHING_DATA);

    // define the types to get
    final types = [
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_ASLEEP,
      // HealthDataType.STEPS,
      // HealthDataType.WEIGHT,
      // HealthDataType.HEIGHT,
      // HealthDataType.BLOOD_GLUCOSE,
      // HealthDataType.WORKOUT,
      // Uncomment these lines on iOS - only available on iOS
      // HealthDataType.AUDIOGRAM
    ];

    // with coresponsing permissions
    final permissions = [
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      // HealthDataAccess.READ,
      // HealthDataAccess.READ,
    ];

    // get data within the last 24 hours
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 5));
    // requesting access to the data types before reading them
    // note that strictly speaking, the [permissions] are not
    // needed, since we only want READ access.
    bool requested =
    await health.requestAuthorization(types, permissions: permissions);
    print('requested: $requested');

    // If we are trying to read Step Count, Workout, Sleep or other data that requires
    // the ACTIVITY_RECOGNITION permission, we need to request the permission first.
    // This requires a special request authorization call.
    //
    // The location permission is requested for Workouts using the Distance information.
    await Permission.activityRecognition.request();
    await Permission.location.request();

    if (requested) {
      try {
        // fetch health data
        List<HealthDataPoint> healthData =
        await health.getHealthDataFromTypes(yesterday, now, types);
        // save all the new data points (only the first 100)
        _healthDataList.addAll((healthData.length < 100)
            ? healthData
            : healthData.sublist(0, 100));
      } catch (error) {
        print("Exception in getHealthDataFromTypes: $error");
      }

      // filter out duplicates
      _healthDataList = HealthFactory.removeDuplicates(_healthDataList);

      // print the results
      _healthDataList.forEach((x) => print(x));

      // update the UI to display the results
      setState(() {
        _state =
        _healthDataList.isEmpty ? AppState.NO_DATA : AppState.DATA_READY;
      });
    } else {
      print("Authorization not granted");
      setState(() => _state = AppState.DATA_NOT_FETCHED);
    }
  }

  /// Add some random health data.
  Future addData() async {
    final now = DateTime.now();
    final earlier = now.subtract(Duration(minutes: 20));

    final types = [
      HealthDataType.STEPS,
      HealthDataType.HEIGHT,
      HealthDataType.BLOOD_GLUCOSE,
      HealthDataType.WORKOUT, // Requires Google Fit on Android
      // Uncomment these lines on iOS - only available on iOS
      // HealthDataType.AUDIOGRAM,
    ];
    final rights = [
      HealthDataAccess.WRITE,
      HealthDataAccess.WRITE,
      HealthDataAccess.WRITE,
      HealthDataAccess.WRITE,
      // HealthDataAccess.WRITE
    ];
    final permissions = [
      HealthDataAccess.READ_WRITE,
      HealthDataAccess.READ_WRITE,
      HealthDataAccess.READ_WRITE,
      HealthDataAccess.READ_WRITE,
      // HealthDataAccess.READ_WRITE,
    ];
    late bool perm;
    bool? hasPermissions =
    await HealthFactory.hasPermissions(types, permissions: rights);
    if (hasPermissions == false) {
      perm = await health.requestAuthorization(types, permissions: permissions);
    }

    // Store a count of steps taken
    _nofSteps = Random().nextInt(10);
    bool success = await health.writeHealthData(
        _nofSteps.toDouble(), HealthDataType.STEPS, earlier, now);

    // Store a height
    success &=
    await health.writeHealthData(1.93, HealthDataType.HEIGHT, earlier, now);

    // Store a Blood Glucose measurement
    _mgdl = Random().nextInt(10) * 1.0;
    success &= await health.writeHealthData(
        _mgdl, HealthDataType.BLOOD_GLUCOSE, now, now);

    // Store a workout eg. running
    success &= await health.writeWorkoutData(
      HealthWorkoutActivityType.RUNNING, earlier, now,
      // The following are optional parameters
      // and the UNITS are functional on iOS ONLY!
      totalEnergyBurned: 230,
      totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      totalDistance: 1234,
      totalDistanceUnit: HealthDataUnit.FOOT,
    );

    // Store an Audiogram
    // Uncomment these on iOS - only available on iOS
    // const frequencies = [125.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0];
    // const leftEarSensitivities = [49.0, 54.0, 89.0, 52.0, 77.0, 35.0];
    // const rightEarSensitivities = [76.0, 66.0, 90.0, 22.0, 85.0, 44.5];

    // success &= await health.writeAudiogram(
    //   frequencies,
    //   leftEarSensitivities,
    //   rightEarSensitivities,
    //   now,
    //   now,
    //   metadata: {
    //     "HKExternalUUID": "uniqueID",
    //     "HKDeviceName": "bluetooth headphone",
    //   },
    // );

    setState(() {
      _state = success ? AppState.DATA_ADDED : AppState.DATA_NOT_ADDED;
    });
  }

  /// Fetch steps from the health plugin and show them in the app.
  Future fetchStepData() async {
    int? steps;

    // get steps for today (i.e., since midnight)
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    bool requested = await health.requestAuthorization([HealthDataType.STEPS]);

    if (requested) {
      try {
        steps = await health.getTotalStepsInInterval(midnight, now);
      } catch (error) {
        print("Caught exception in getTotalStepsInInterval: $error");
      }

      print('Total number of steps: $steps');

      setState(() {
        _nofSteps = (steps == null) ? 0 : steps;
        _state = (steps == null) ? AppState.NO_DATA : AppState.STEPS_READY;
      });
    } else {
      print("Authorization not granted - error in authorization");
      setState(() => _state = AppState.DATA_NOT_FETCHED);
    }
  }

  Widget _contentFetchingData() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(
              strokeWidth: 10,
            )),
        Text('Fetching data...')
      ],
    );
  }

  Widget _contentDataReady() {
    return ListView.builder(
        itemCount: _healthDataList.length,
        itemBuilder: (_, index) {
          HealthDataPoint p = _healthDataList[index];
          if (p.value is AudiogramHealthValue) {
            return ListTile(
              title: Text("${p.typeString}: ${p.value}"),
              trailing: Text('${p.unitString}'),
              subtitle: Text('${p.dateFrom} - ${p.dateTo}'),
            );
          }
          if (p.value is WorkoutHealthValue) {
            return ListTile(
              title: Text(
                  "${p.typeString}: ${(p.value as WorkoutHealthValue).totalEnergyBurned} ${(p.value as WorkoutHealthValue).totalEnergyBurnedUnit?.typeToString()}"),
              trailing: Text(
                  '${(p.value as WorkoutHealthValue).workoutActivityType.typeToString()}'),
              subtitle: Text('${p.dateFrom} - ${p.dateTo}'),
            );
          }
          return ListTile(
            title: Text("${p.typeString}: ${p.value}"),
            trailing: Text('${p.unitString}'),
            subtitle: Text('${p.dateFrom} - ${p.dateTo}'),
          );
        });
  }

  Widget _contentNoData() {
    return Text('No Data to show');
  }

  Widget _contentNotFetched() {
    return Column(
      children: [
        Text('Press the download button to fetch data.'),
        Text('Press the plus button to insert some random data.'),
        Text('Press the walking button to get total step count.'),
      ],
      mainAxisAlignment: MainAxisAlignment.center,
    );
  }

  Widget _authorizationNotGranted() {
    return Text('Authorization not given. '
        'For Android please check your OAUTH2 client ID is correct in Google Developer Console. '
        'For iOS check your permissions in Apple Health.');
  }

  Widget _dataAdded() {
    return Text('Data points inserted successfully!');
  }

  Widget _stepsFetched() {
    return Text('Total number of steps: $_nofSteps');
  }

  Widget _dataNotAdded() {
    return Text('Failed to add data');
  }

  Widget _content() {
    if (_state == AppState.DATA_READY)
      return _contentDataReady();
    else if (_state == AppState.NO_DATA)
      return _contentNoData();
    else if (_state == AppState.FETCHING_DATA)
      return _contentFetchingData();
    else if (_state == AppState.AUTH_NOT_GRANTED)
      return _authorizationNotGranted();
    else if (_state == AppState.DATA_ADDED)
      return _dataAdded();
    else if (_state == AppState.STEPS_READY)
      return _stepsFetched();
    else if (_state == AppState.DATA_NOT_ADDED) return _dataNotAdded();

    return _contentNotFetched();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Health Example'),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.file_download),
                onPressed: () {
                  fetchData();
                },
              ),
              IconButton(
                onPressed: () {
                  addData();
                },
                icon: Icon(Icons.add),
              ),
              IconButton(
                onPressed: () {
                  fetchStepData();
                },
                icon: Icon(Icons.nordic_walking),
              )
            ],
          ),
          body: Center(
            child: _content(),
          )),
    );
  }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// import 'dart:async';
// import 'dart:io' show Platform;
//
// import 'package:baseflow_plugin_template/baseflow_plugin_template.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:m7run/utility/calculator.dart';
//
// /// Defines the main theme color.
// final MaterialColor themeMaterialColor =
// BaseflowPluginExample.createMaterialColor(
//     const Color.fromRGBO(48, 49, 60, 1));
//
// void main() {
//   runApp(const GeolocatorWidget());
// }
//
// /// Example [Widget] showing the functionalities of the geolocator plugin
// class GeolocatorWidget extends StatefulWidget {
//   /// Creates a new GeolocatorWidget.
//   const GeolocatorWidget({Key? key}) : super(key: key);
//
//   /// Utility method to create a page with the Baseflow templating.
//   static ExamplePage createPage() {
//     return ExamplePage(
//         Icons.location_on, (context) => const GeolocatorWidget());
//   }
//
//   @override
//   _GeolocatorWidgetState createState() => _GeolocatorWidgetState();
// }
//
// class _GeolocatorWidgetState extends State<GeolocatorWidget> {
//   static const String _kLocationServicesDisabledMessage =
//       'Location services are disabled.';
//   static const String _kPermissionDeniedMessage = 'Permission denied.';
//   static const String _kPermissionDeniedForeverMessage =
//       'Permission denied forever.';
//   static const String _kPermissionGrantedMessage = 'Permission granted.';
//
//   final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
//   final List<_PositionItem> _positionItems = <_PositionItem>[];
//   final List<Position> _positions = <Position>[];
//   StreamSubscription<Position>? _positionStreamSubscription;
//   StreamSubscription<ServiceStatus>? _serviceStatusStreamSubscription;
//   bool positionStreamStarted = false;
//
//   Timer? timer;
//   @override
//   void initState() {
//     super.initState();
//     _toggleServiceStatusStream();
//     timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _calculateSpeed());
//   }
//
//   PopupMenuButton _createActions() {
//     return PopupMenuButton(
//       elevation: 40,
//       onSelected: (value) async {
//         switch (value) {
//           case 1:
//             _getLocationAccuracy();
//             break;
//           case 2:
//             _requestTemporaryFullAccuracy();
//             break;
//           case 3:
//             _openAppSettings();
//             break;
//           case 4:
//             _openLocationSettings();
//             break;
//           case 5:
//             setState(_positionItems.clear);
//             break;
//           default:
//             break;
//         }
//       },
//       itemBuilder: (context) => [
//         if (Platform.isIOS)
//           const PopupMenuItem(
//             child: Text("Get Location Accuracy"),
//             value: 1,
//           ),
//         if (Platform.isIOS)
//           const PopupMenuItem(
//             child: Text("Request Temporary Full Accuracy"),
//             value: 2,
//           ),
//         const PopupMenuItem(
//           child: Text("Open App Settings"),
//           value: 3,
//         ),
//         if (Platform.isAndroid || Platform.isWindows)
//           const PopupMenuItem(
//             child: Text("Open Location Settings"),
//             value: 4,
//           ),
//         const PopupMenuItem(
//           child: Text("Clear"),
//           value: 5,
//         ),
//       ],
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     const sizedBox = SizedBox(
//       height: 10,
//     );
//
//     return BaseflowPluginExample(
//         pluginName: 'Geolocator',
//         githubURL: 'https://github.com/Baseflow/flutter-geolocator',
//         pubDevURL: 'https://pub.dev/packages/geolocator',
//         appBarActions: [
//           _createActions()
//         ],
//         pages: [
//           ExamplePage(
//             Icons.location_on,
//                 (context) => Scaffold(
//               backgroundColor: Theme.of(context).backgroundColor,
//               body: ListView.builder(
//                 itemCount: _positionItems.length,
//                 itemBuilder: (context, index) {
//                   final positionItem = _positionItems[index];
//
//                   if (positionItem.type == _PositionItemType.log) {
//                     return ListTile(
//                       title: Text(positionItem.displayValue,
//                           textAlign: TextAlign.center,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                           )),
//                     );
//                   } else {
//                     return Card(
//                       child: ListTile(
//                         tileColor: themeMaterialColor,
//                         title: Text(
//                           positionItem.displayValue,
//                           style: const TextStyle(color: Colors.white),
//                         ),
//                       ),
//                     );
//                   }
//                 },
//               ),
//               floatingActionButton: Column(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   // FloatingActionButton(
//                   //   child: (_positionStreamSubscription == null ||
//                   //       _positionStreamSubscription!.isPaused)
//                   //       ? const Icon(Icons.play_arrow)
//                   //       : const Icon(Icons.pause),
//                   //   onPressed: () {
//                   //     positionStreamStarted = !positionStreamStarted;
//                   //     _toggleListening();
//                   //   },
//                   //   tooltip: (_positionStreamSubscription == null)
//                   //       ? 'Start position updates'
//                   //       : _positionStreamSubscription!.isPaused
//                   //       ? 'Resume'
//                   //       : 'Pause',
//                   //   backgroundColor: _determineButtonColor(),
//                   // ),
//                   // sizedBox,
//                   // FloatingActionButton(
//                   //   child: const Icon(Icons.my_location),
//                   //   onPressed: _getCurrentPosition,
//                   // ),
//                   // sizedBox,
//                   FloatingActionButton(
//                     child: const Icon(Icons.bookmark),
//                     onPressed: _getLastKnownPosition,
//                   ),
//                 ],
//               ),
//             ),
//           )
//         ]);
//   }
//
//   Future<void> _calculateSpeed()  async {
//
//     if(_positions.isEmpty) {
//       Position position = await _getCurrentPosition();
//       _positions.add(position);
//       return;
//     }
//
//     Position position = await _getCurrentPosition();
//     var speed = getSpeed(Geolocator.distanceBetween(_positions.last.latitude, _positions.last.longitude, position.latitude, position.longitude));
//     _positions.add(position);
//
//
//     if(_positions.length >= 2) {
//       _positions.removeAt(0);
//     }
//
//     if(speed < 10) {
//       _updatePositionList(
//         _PositionItemType.log,
//         '${speed.toStringAsFixed(2)} km/hr',
//       );
//     }
//
//   }
//
//   Future<Position> _getCurrentPosition() async {
//     final hasPermission = await _handlePermission();
//
//     // if (!hasPermission) {
//     //   return null;
//     // }
//
//     final position = await _geolocatorPlatform.getCurrentPosition();
//     // _updatePositionList(
//     //   _PositionItemType.position,
//     //   position.toString(),
//     // );
//
//     return position;
//   }
//
//   Future<bool> _handlePermission() async {
//     bool serviceEnabled;
//     LocationPermission permission;
//
//     // Test if location services are enabled.
//     serviceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       // Location services are not enabled don't continue
//       // accessing the position and request users of the
//       // App to enable the location services.
//       // _updatePositionList(
//       //   _PositionItemType.log,
//       //   _kLocationServicesDisabledMessage,
//       // );
//
//       return false;
//     }
//
//     permission = await _geolocatorPlatform.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await _geolocatorPlatform.requestPermission();
//       if (permission == LocationPermission.denied) {
//         // Permissions are denied, next time you could try
//         // requesting permissions again (this is also where
//         // Android's shouldShowRequestPermissionRationale
//         // returned true. According to Android guidelines
//         // your App should show an explanatory UI now.
//         // _updatePositionList(
//         //   _PositionItemType.log,
//         //   _kPermissionDeniedMessage,
//         // );
//
//         return false;
//       }
//     }
//
//     if (permission == LocationPermission.deniedForever) {
//       // Permissions are denied forever, handle appropriately.
//       // _updatePositionList(
//       //   _PositionItemType.log,
//       //   _kPermissionDeniedForeverMessage,
//       // );
//
//       return false;
//     }
//
//     // When we reach here, permissions are granted and we can
//     // continue accessing the position of the device.
//     // _updatePositionList(
//     //   _PositionItemType.log,
//     //   _kPermissionGrantedMessage,
//     // );
//     return true;
//   }
//
//   void _updatePositionList(_PositionItemType type, String displayValue) {
//     _positionItems.clear();
//     _positionItems.add(_PositionItem(type, displayValue));
//     setState(() {});
//   }
//
//   bool _isListening() => !(_positionStreamSubscription == null ||
//       _positionStreamSubscription!.isPaused);
//
//   Color _determineButtonColor() {
//     return _isListening() ? Colors.green : Colors.red;
//   }
//
//   void _toggleServiceStatusStream() {
//     if (_serviceStatusStreamSubscription == null) {
//       final serviceStatusStream = _geolocatorPlatform.getServiceStatusStream();
//       _serviceStatusStreamSubscription =
//           serviceStatusStream.handleError((error) {
//             _serviceStatusStreamSubscription?.cancel();
//             _serviceStatusStreamSubscription = null;
//           }).listen((serviceStatus) {
//             String serviceStatusValue;
//             if (serviceStatus == ServiceStatus.enabled) {
//               if (positionStreamStarted) {
//                 _toggleListening();
//               }
//               serviceStatusValue = 'enabled';
//             } else {
//               if (_positionStreamSubscription != null) {
//                 setState(() {
//                   _positionStreamSubscription?.cancel();
//                   _positionStreamSubscription = null;
//                   // _updatePositionList(
//                   //     _PositionItemType.log, 'Position Stream has been canceled');
//                 });
//               }
//               serviceStatusValue = 'disabled';
//             }
//             // _updatePositionList(
//             //   _PositionItemType.log,
//             //   'Location service has been $serviceStatusValue',
//             // );
//           });
//     }
//   }
//
//   void _toggleListening() {
//     if (_positionStreamSubscription == null) {
//       final positionStream = _geolocatorPlatform.getPositionStream();
//       // _positionStreamSubscription = positionStream.handleError((error) {
//       //   _positionStreamSubscription?.cancel();
//       //   _positionStreamSubscription = null;
//       // }).listen((position) => _updatePositionList(
//       //   _PositionItemType.position,
//       //   position.toString(),
//       // ));
//       // _positionStreamSubscription?.pause();
//     }
//
//     setState(() {
//       if (_positionStreamSubscription == null) {
//         return;
//       }
//
//       String statusDisplayValue;
//       if (_positionStreamSubscription!.isPaused) {
//         _positionStreamSubscription!.resume();
//         statusDisplayValue = 'resumed';
//       } else {
//         _positionStreamSubscription!.pause();
//         statusDisplayValue = 'paused';
//       }
//
//       // _updatePositionList(
//       //   _PositionItemType.log,
//       //   'Listening for position updates $statusDisplayValue',
//       // );
//     });
//   }
//
//   @override
//   void dispose() {
//     if (_positionStreamSubscription != null) {
//       _positionStreamSubscription!.cancel();
//       _positionStreamSubscription = null;
//     }
//
//     super.dispose();
//   }
//
//   void _getLastKnownPosition() async {
//     final position = await _geolocatorPlatform.getLastKnownPosition();
//     if (position != null) {
//       _updatePositionList(
//         _PositionItemType.position,
//         position.toString(),
//       );
//     } else {
//       _updatePositionList(
//         _PositionItemType.log,
//         'No last known position available',
//       );
//     }
//   }
//
//   void _getLocationAccuracy() async {
//     final status = await _geolocatorPlatform.getLocationAccuracy();
//     _handleLocationAccuracyStatus(status);
//   }
//
//   void _requestTemporaryFullAccuracy() async {
//     final status = await _geolocatorPlatform.requestTemporaryFullAccuracy(
//       purposeKey: "TemporaryPreciseAccuracy",
//     );
//     _handleLocationAccuracyStatus(status);
//   }
//
//   void _handleLocationAccuracyStatus(LocationAccuracyStatus status) {
//     String locationAccuracyStatusValue;
//     if (status == LocationAccuracyStatus.precise) {
//       locationAccuracyStatusValue = 'Precise';
//     } else if (status == LocationAccuracyStatus.reduced) {
//       locationAccuracyStatusValue = 'Reduced';
//     } else {
//       locationAccuracyStatusValue = 'Unknown';
//     }
//     _updatePositionList(
//       _PositionItemType.log,
//       '$locationAccuracyStatusValue location accuracy granted.',
//     );
//   }
//
//   void _openAppSettings() async {
//     final opened = await _geolocatorPlatform.openAppSettings();
//     String displayValue;
//
//     if (opened) {
//       displayValue = 'Opened Application Settings.';
//     } else {
//       displayValue = 'Error opening Application Settings.';
//     }
//
//     _updatePositionList(
//       _PositionItemType.log,
//       displayValue,
//     );
//   }
//
//   void _openLocationSettings() async {
//     final opened = await _geolocatorPlatform.openLocationSettings();
//     String displayValue;
//
//     if (opened) {
//       displayValue = 'Opened Location Settings';
//     } else {
//       displayValue = 'Error opening Location Settings';
//     }
//
//     _updatePositionList(
//       _PositionItemType.log,
//       displayValue,
//     );
//   }
// }
//
// enum _PositionItemType {
//   log,
//   position,
// }
//
// class _PositionItem {
//   _PositionItem(this.type, this.displayValue);
//
//   final _PositionItemType type;
//   final String displayValue;
// }
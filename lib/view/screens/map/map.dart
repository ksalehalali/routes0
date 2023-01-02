import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import '../../../Assistants/assistantMethods.dart';
import '../../../Assistants/globals.dart';
import '../../../Data/current_data.dart';
import '../../../controller/location_controller.dart';
import '../../../controller/payment_controller.dart';
import '../../../controller/route_map_controller.dart';
import '../../../model/location.dart';
import '../../widgets/QRCodeScanner.dart';
import '../../widgets/add_address_to_favorite.dart';
import '../../widgets/flutter_toast.dart';
import '../routes/destination_selection_screen.dart';
import 'multi-route-details.dart';
import 'one-route-details.dart';


class Map extends StatefulWidget {
  @override
  _MapState createState() => _MapState();
}

google_maps.GoogleMapController? newGoogleMapController;
PanelController panelController = PanelController();

class _MapState extends State<Map> {
  final routeMapController = Get.put(RouteMapController());
  final LocationController locationController = Get.find();
  final PaymentController paymentController = Get.find();

  ///DateFormat('yyyy-MM-dd-HH:mm').format(DateTime.now());
  ///
  String? addressText;
  bool getingAddress = true;
  bool showMap = false;
  bool showStops = false;
  var assistantMethods = AssistantMethods();
  double? sizeOfSheet = 0.0;
  double rotation = 0.0;
  var stops = [];
  var stopsLineEx = [];
  DateTime? timeDrew = DateTime.now();
  late final MapController mapController;
  Completer<google_maps.GoogleMapController> _controllerMaps = Completer();
  double bottomPaddingOfMap = 0;
  double heightLineStops = 100.0;
  late final StreamSubscription<MapEvent> mapEventSubscription;
  int _eventKey = 0;

  google_maps.CameraPosition cameraPosition =google_maps.CameraPosition(target: google_maps.LatLng(initialPoint.latitude, initialPoint.longitude),zoom: 14.0);


  late google_maps.BitmapDescriptor mapMarker;
  late google_maps.BitmapDescriptor mapMarker2;



  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setCustomIconMarker();
    mapController = MapController();
    mapEventSubscription = mapController.mapEventStream.listen(onMapEvent);
    routeMapController.startPointLatLng.value =
        LatLng(trip.startPoint.latitude, trip.startPoint.longitude);

    Timer(Duration(milliseconds: 1), () {
      setState(() {
        showMap = true;
      });
    });
    if(locationController.startAddingPickUp.value) {
      routeMapController.startPointLatLng.value.longitude =initialPoint.longitude;
      routeMapController.startPointLatLng.value.latitude =initialPoint.latitude;
    }else {

      routeMapController.endPointLatLng.value.longitude =initialPoint.longitude;
      routeMapController.endPointLatLng.value.latitude =initialPoint.latitude;
    }

    initLocationService();

  }

  //custom icon
  void setCustomIconMarker()async{
    mapMarker = await google_maps.BitmapDescriptor.fromAssetImage(ImageConfiguration(size: Size(20,20)),'assets/icons/icons8-bus-96.png',) ;
    mapMarker2 = await google_maps.BitmapDescriptor.fromAssetImage(ImageConfiguration(size: Size(1,1)),'assets/icons/icons8-get-on-bus-100.png') ;

  }
  void onMapEvent(MapEvent mapEvent) {
    if (mapEvent is MapEventMove && mapEvent.id == _eventKey.toString()) {}
  }

  void _moveToCurrent() async {
    _eventKey++;
    try {
      var moved = mapController.move(
        LatLng(routeMapController.centerOfDirRoute.value.latitude,
            routeMapController.centerOfDirRoute.value.longitude),
        13,
        id: _eventKey.toString(),
      );

      if (moved) {
        //setIcon(Icons.gps_fixed);
      } else {
        //setIcon(Icons.gps_not_fixed);
      }
    } catch (e) {
      //setIcon(Icons.gps_off);
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    mapEventSubscription.cancel();
  }

  //live location
  loc.LocationData? _currentLocation;

  bool _liveUpdate = false;
  bool _permission = false;
  bool showPin=false;
  bool showDot= false;
  String? _serviceError = '';

  var interActiveFlags = InteractiveFlag.all;

  final loc.Location _locationService = loc.Location();

  void initLocationService() async {
    await _locationService.changeSettings(
      accuracy: loc.LocationAccuracy.high,
      interval: 1000,
    );

    loc.LocationData? location;
    bool serviceEnabled;
    bool serviceRequestResult;
    try {
      serviceEnabled = await _locationService.serviceEnabled();

      if (serviceEnabled) {
        var permission = await _locationService.requestPermission();
        _permission = permission == loc.PermissionStatus.granted;

        if (_permission) {
          location = await _locationService.getLocation();
          _currentLocation = location;
          _locationService.onLocationChanged
              .listen((loc.LocationData result) async {
            if (mounted) {
              setState(() {
                _currentLocation = result;
                locationController.updateLiveLoc(LatLng(
                    _currentLocation!.latitude!, _currentLocation!.longitude!));
                // If Live Update is enabled, move map center
                if (_liveUpdate) {
                  mapController.move(
                      LatLng(_currentLocation!.latitude!,
                          _currentLocation!.longitude!),
                      14.5);
                }
              });
            }
          });
        }
      } else {
        serviceRequestResult = await _locationService.requestService();
        if (serviceRequestResult) {
          initLocationService();
          return;
        }
      }
    } on PlatformException catch (e) {
      print(e);
      if (e.code == 'PERMISSION_DENIED') {
        _serviceError = e.message;
      } else if (e.code == 'SERVICE_STATUS_ERROR') {
        _serviceError = e.message;
      }
      location = null;
    }
  }

  //
  void locatePosition() async {
    print("on crate map");
    Position position = Position(
        longitude: initialPoint.longitude,
        latitude: initialPoint.latitude,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 1,
        heading: 1,
        speed: 1,
        speedAccuracy: 1);
    google_maps.LatLng latLngPosition =
    google_maps.LatLng(initialPoint.latitude, initialPoint.longitude);

    google_maps.CameraPosition cameraPosition =
    new google_maps.CameraPosition(target: latLngPosition, zoom: 15);
    print("init point $initialPoint");
    newGoogleMapController!.animateCamera(
        google_maps.CameraUpdate.newCameraPosition(cameraPosition));
    var assistantMethods = AssistantMethods();
    String address = await assistantMethods.searchCoordinateAddress(
        position,  false);
    print(address);
  }

  @override
  Widget build(BuildContext context) {
    final String timeC = DateTime.now().hour > 11 ? 'PM' : 'AM';
    final screenSize = MediaQuery.of(context).size;

    return Container(
      color: routes_color,
      child: SafeArea(
        child: Obx(
              () => Scaffold(
            body: Stack(
              alignment: AlignmentDirectional.topEnd,
              children: [

                SlidingUpPanel(
                  isDraggable: false,
                  controller: panelController,
                  maxHeight: screenSize.height * 0.4 + 66,
                  minHeight: screenSize.height * 0.2 - 20.0,
                  panelBuilder: (scrollContainer) =>
                  routeMapController.isMultiMode.value == true
                      ? MultiRouteDetails()
                      : DetailsOneRoute(),
                  body: Stack(children: [


                    Obx(()=>google_maps.GoogleMap(
                      initialCameraPosition: cameraPosition,
                      mapToolbarEnabled: true,
                     // trafficEnabled: true,
                      indoorViewEnabled: true,
                      padding: EdgeInsets.only(top: 10,bottom: 140),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,

                      markers: {
                        // google_maps.Marker(markerId: google_maps.MarkerId('a'),position: locationController.currentLocationG.value,onTap: (){
                        //   print('object');
                        // }),
                        ( locationController.tripCreatedDone.value == false && locationController.showPinOnMap.value == true)
                            ? google_maps.Marker(
                          flat:true,
                          draggable: false,
                          markerId: google_maps.MarkerId('center'),
                          anchor :  Offset(0.5, 1.0),
                          rotation: 6.0,
                          alpha : 0.8,
                          position: google_maps.LatLng(locationController.currentLocationG.value.latitude,locationController.currentLocationG.value.longitude),
                          onTap: () {
                            print('object');
                          },
                          icon:google_maps.BitmapDescriptor.defaultMarkerWithHue(
                              google_maps.BitmapDescriptor.hueRose),
                        )
                            :locationController.tripCreatedDone.value == false? google_maps.Marker(
                          markerId: google_maps.MarkerId('center2'),
                          position: locationController.currentLocationG.value,

                          onTap: () {
                            print('object');
                          },
                          icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
                              google_maps.BitmapDescriptor.hueYellow),
                        ):google_maps.Marker(markerId: google_maps.MarkerId('center')),

                        //picking marker
                        locationController.tripCreatedDone.value == true
                            ? google_maps.Marker(
                            icon: mapMarker2,
                            flat:true,
                            draggable: false,
                            anchor :  Offset(0.5, 1.0),
                            rotation: 6.0,
                            alpha : 0.8,
                            infoWindow: google_maps.InfoWindow(
                                title:
                                '${routeMapController.startStation['title'].toString()}',
                                snippet: routeMapController.startStation['station']
                                    .toString()),
                            position: google_maps.LatLng(
                                routeMapController.startStation['latitude'],
                                routeMapController.startStation['longitude']),
                            markerId: google_maps.MarkerId("pickUpId"))
                            : google_maps.Marker(
                            markerId: google_maps.MarkerId("pickUpId")),

                        //multi route marker shared station
                        locationController.tripCreatedDone.value == true &&
                            routeMapController.isMultiMode.value == true
                            ? google_maps.Marker(
                            icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
                                google_maps.BitmapDescriptor.hueOrange),
                            infoWindow: google_maps.InfoWindow(
                                title:
                                '${routeMapController.sharedStation['title'].toString()}',
                                snippet:
                                routeMapController.sharedStation['station']),
                            position: google_maps.LatLng(
                                routeMapController.sharedStation['latitude'],
                                routeMapController.sharedStation['longitude']),
                            markerId: google_maps.MarkerId("sharedId"))
                            : google_maps.Marker(
                            markerId: google_maps.MarkerId("sharedId")),

                        //multi route marker2 shared station2
                        locationController.tripCreatedDone.value == true &&
                            routeMapController.isMultiMode.value == true
                            ? google_maps.Marker(
                            icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
                              google_maps.BitmapDescriptor.hueOrange,
                            ),
                            infoWindow: google_maps.InfoWindow(
                                title:
                                '${routeMapController.sharedStation2['title'].toString()}',
                                snippet:
                                routeMapController.sharedStation2['station']),
                            position: google_maps.LatLng(
                                routeMapController.sharedStation2['latitude'],
                                routeMapController.sharedStation2['longitude']),
                            markerId: google_maps.MarkerId("shared2Id"))
                            : google_maps.Marker(
                            markerId: google_maps.MarkerId("shared2Id")),

                        //correct bus 1
                        locationController.myCorrectBusesGot == true
                            ? google_maps.Marker(
                            icon: mapMarker,

                            infoWindow: google_maps.InfoWindow(
                                title:
                                '${locationController.myCorrectBuses[2]['busID']}',
                                snippet: locationController.myCorrectBuses[2]['busID']),
                            position: google_maps.LatLng(
                                locationController.myCorrectBuses[2]['latitude1'],
                                locationController.myCorrectBuses[2]['longitude2']),
                            markerId: google_maps.MarkerId(locationController.myCorrectBuses[2]['busID']),
                            onTap: () {
                              print(routeMapController.endStation['station']
                                  .toString());
                            })
                            : google_maps.Marker(
                            markerId: google_maps.MarkerId(locationController.myCorrectBuses[2]['busID'])),

                        //correct bus 2
                        locationController.myCorrectBusesGot == true
                            ? google_maps.Marker(
                            icon: mapMarker,

                            infoWindow: google_maps.InfoWindow(
                                title:
                                '${locationController.myCorrectBuses[1]['busID']}',
                                snippet: locationController.myCorrectBuses[1]['busID']),
                            position: google_maps.LatLng(
                                locationController.myCorrectBuses[1]['latitude1'],
                                locationController.myCorrectBuses[1]['longitude2']),
                            markerId: google_maps.MarkerId(locationController.myCorrectBuses[1]['busID']),
                            onTap: () {
                              print(routeMapController.endStation['station']
                                  .toString());
                            })
                            : google_maps.Marker(
                            markerId: google_maps.MarkerId(locationController.myCorrectBuses[1]['busID'])),

                        //drop off marker
                        locationController.tripCreatedDone.value == true
                            ? google_maps.Marker(
                            icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
                                google_maps.BitmapDescriptor.hueBlue),
                            infoWindow: google_maps.InfoWindow(
                                title:
                                '${routeMapController.endStation['title'].toString()}',
                                snippet: routeMapController.endStation['station']),
                            position: google_maps.LatLng(
                                routeMapController.endStation['latitude'],
                                routeMapController.endStation['longitude']),
                            markerId: google_maps.MarkerId("dropOffId"),
                            onTap: () {
                              print(routeMapController.endStation['station']
                                  .toString());
                            })
                            : google_maps.Marker(
                            markerId: google_maps.MarkerId("dropOffId")),


                      },


                      polylines: {
                        google_maps.Polyline(
                          color: Colors.blue.withOpacity(0.7),
                          polylineId: google_maps.PolylineId("PolylineID"),
                          jointType: google_maps.JointType.round,
                          width: 5,
                          startCap: google_maps.Cap.roundCap,
                          points: routeMapController.tripStationWayPointsG,
                          endCap: google_maps.Cap.roundCap,
                          geodesic: true,
                        ),

                        //2
                        locationController.tripCreatedDone.value==true? google_maps.Polyline(
                          color: Colors.blue.withOpacity(0.9),
                          polylineId: google_maps.PolylineId("PolylineRoute2ID"),
                          jointType: google_maps.JointType.round,
                          width: 4,
                          startCap: google_maps.Cap.roundCap,
                          points: routeMapController.tripStationWayPointsRoute2,
                          endCap: google_maps.Cap.roundCap,
                          geodesic: true,
                        ):google_maps.Polyline(polylineId:google_maps.PolylineId("PolylineRoute2ID"), ),

                        //1
                        google_maps.Polyline(
                          color: Colors.blue.withOpacity(0.9),
                          polylineId: google_maps.PolylineId("PolylineRoute1ID"),
                          jointType: google_maps.JointType.round,
                          width: 4,
                          startCap: google_maps.Cap.roundCap,
                          points: routeMapController.tripStationWayPointsRoute1,
                          endCap: google_maps.Cap.roundCap,
                          geodesic: true,
                        ),

                        google_maps.Polyline(
                          color: Colors.red.withOpacity(0.6),
                          polylineId: google_maps.PolylineId("FirstWalkPolylineID"),
                          jointType: google_maps.JointType.round,
                          width: 5,
                          startCap: google_maps.Cap.roundCap,
                          points: routeMapController.tripFirstWalkWayPointsG,
                          endCap: google_maps.Cap.roundCap,
                          geodesic: true,
                        ),
                        google_maps.Polyline(
                          color: Colors.green.withOpacity(0.7),
                          polylineId: google_maps.PolylineId("SecondWalkPolylineID"),
                          jointType: google_maps.JointType.round,
                          width: 5,
                          startCap: google_maps.Cap.roundCap,
                          points: routeMapController.tripSecondWalkWayPointsG,
                          endCap: google_maps.Cap.roundCap,
                          geodesic: true,
                        ),
                        google_maps.Polyline(
                          color: Colors.blue.withOpacity(0.7),
                          polylineId: google_maps.PolylineId("StationWayPolyline2ID"),
                          jointType: google_maps.JointType.mitered,
                          width: 5,
                          startCap: google_maps.Cap.roundCap,
                          points: routeMapController.tripStationWayPoints2G,
                          endCap: google_maps.Cap.roundCap,
                          geodesic: true,
                        ),
                      },
                      onCameraMoveStarted: () {
                        print('onCameraMoveStarted');
                      },
                      onCameraIdle: ()async{
                        print('onCameraIdle');
                        locationController.showPinOnMap.value = true;
                        addressText = await assistantMethods.searchCoordinateAddress(
                            locationController.positionFromPin.value, false);
                        getingAddress = true;
                        if (locationController.addDropOff.value == true &&
                            locationController.addPickUp.value == true) {

                        } else {
                          if (locationController.startAddingPickUp.value == true) {
                            trip.startPointAddress = addressText!;

                          } else {
                            trip.endPointAddress = addressText!;

                          }
                        }
                      },
                      onCameraMove: (camera) async {
                        locationController.showPinOnMap.value = false;
                        locationController.updatePinPos(
                            camera.target.latitude, camera.target.longitude);
                        locationController.positionFromPin.value = Position(
                          longitude: camera.target.longitude,
                          latitude: camera.target.latitude,
                          speedAccuracy: 1.0,
                          altitude: camera.target.latitude,
                          speed: 1.0,
                          heading: 1.0,
                          timestamp: DateTime.now(),
                          accuracy: 1.0,
                        );


                      },
                      onMapCreated: (google_maps.GoogleMapController controller) {
                        _controllerMaps.complete(controller);
                        newGoogleMapController = controller;
                        locationController.positionFromPin.value = Position(
                          longitude: initialPoint.longitude,
                          latitude: initialPoint.latitude,
                          speedAccuracy: 1.0,
                          altitude:initialPoint.latitude,
                          speed: 1.0,
                          heading: 1.0,
                          timestamp: DateTime.now(),
                          accuracy: 1.0,
                        );
                        locationController.showPinOnMap.value = true;

                        setState(() {
                          bottomPaddingOfMap = 320.0;
                        });
                        // locatePosition();
                      },
                    ),
                    ),

                    //HamburgerButton for drawer
                    Positioned(
                      top: 12.0,
                      left:  22.0,

                      child: Column(

                        children: [
                          InkWell(
                            onTap: () {
                              locationController.addDropOff.value = false;
                              //locationController.addPickUp.value = false;
                              locationController.tripCreatedStatus(false);
                              routeMapController.resetAll();
                              paymentController.paymentDone.value = false;
                              locationController.startAddingDropOffStatus(true);
                              locationController.startAddingPickUpStatus(false);
                              routeMapController.isMultiMode.value = false;
                              locationController.showPinOnMap.value =false;
                              //locationController.changePickUpAddress('set pick up');
                              //trip = Trip('', '', LocationModel(0.0,0.0), LocationModel(0.0,0.0), '', '', '', '', '');
                              Navigator.pushReplacement(context,
                                  MaterialPageRoute(builder: (context) => SearchScreen()));
                            },
                            child: Container(
                              //height: 300.0,
                              decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(22.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 6.0,
                                      spreadRadius: 0.5,
                                      offset: Offset(0.7, 0.7),
                                    ),
                                  ]),
                              child: CircleAvatar(
                                backgroundColor: Colors.white.withOpacity(.9),
                                child:Icon(
                                  Icons.close,
                                  color: Colors.black,
                                ),
                                radius: 20.0,
                              ),
                            ),
                          ),
                          SizedBox(height:12.w),
                          InkWell(
                            onTap: () {

                              addFavoriteAddress(context ,screenSize,addressText!,LocationModel(locationController.positionFromPin.value.latitude,locationController.positionFromPin.value.longitude));
                            },
                            child: Container(
                              //height: 300.0,
                              decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(22.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 6.0,
                                      spreadRadius: 0.5,
                                      offset: Offset(0.7, 0.7),
                                    ),
                                  ]),
                              child: CircleAvatar(
                                backgroundColor: Colors.white.withOpacity(.9),
                                child:Icon(
                                  Icons.favorite_border,
                                  color: Colors.black,
                                ),
                                radius: 20.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),


                  ]),
                ),
                locationController.tripCreatedDone.value == true
                    ?Positioned(
                    bottom: 26.0,
                    // right: screenSize.width  ,
                    child: buildActionButton(screenSize) ): Container(),
              ],
            ),
            // floatingActionButton: locationController.tripCreatedDone.value == true
            //     ? buildActionButton()
            //     : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          ),
        ),
      ),
    );
  }

  int index = 0;

  Widget buildActionButton(screenSize) {
    switch (index) {
      case 0:
        return buildStartTheTripButton(screenSize);
      case 1:
        return buildPayButton(screenSize);
      default:
        return buildStartTheTripButton(screenSize);
    }
  }

  Widget buildStartTheTripButton(screenSize) => Center(
    child: Container(
      width: screenSize.width ,
      child: Padding(
        padding:  EdgeInsets.symmetric(horizontal: screenSize.width*0.3),
        child: FloatingActionButton.extended(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          foregroundColor: Colors.white,
          backgroundColor: routes_color.withOpacity(0.9),
          extendedPadding: EdgeInsets.symmetric(horizontal: 0,vertical: 0.0),
          icon: Icon(Icons.not_started_outlined),
          label: Text(
            'start_trip_txt'.tr,
            style: TextStyle(
                shadows: [
                  Shadow(
                      color: Colors.black12,
                      offset: Offset(4.0,3.0),
                      blurRadius: 6
                  )
                ],
                fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            routeMapController.callSaveTrip();
            setState(() {
              index = 1;
            });
          },
        ),
      ),
    ),
  );

  Widget buildPayButton(screenSize) =>  Container(
    width: screenSize.width,
    child: Center(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [

          OutlinedButton.icon(
            style: ButtonStyle(
              backgroundColor:MaterialStateProperty.all(routes_color),
              foregroundColor: MaterialStateProperty.all(Colors.white),
              padding: MaterialStateProperty.all(EdgeInsets.symmetric(vertical: 10,horizontal: 3)),

            ) ,
            onPressed: ()async{
              String balance = await checkWallet();
              double balanceNum = double.parse(balance);
              if(balanceNum >= 0.200) {
                paymentController.ticketPayed.value = false;

                scanQRCodeToPay(context,false,0);

              } else {
                Fluttertoast.showToast(
                    msg: "msg_0_balance".tr,
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.CENTER,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.white70,
                    textColor: Colors.black,
                    fontSize: 16.0.sp);
              }
            }, label: Text(
            "Pay via scan QR code_txt".tr,
            style: TextStyle(
                fontSize: 13.sp,
                letterSpacing: 0,
                fontWeight: FontWeight.bold

            ),
          ), icon: Icon(Icons.qr_code), ),
          OutlinedButton.icon(
            style: ButtonStyle(
              backgroundColor:MaterialStateProperty.all(routes_color),
              foregroundColor: MaterialStateProperty.all(Colors.white),
              padding: MaterialStateProperty.all(EdgeInsets.symmetric(vertical: 10,horizontal: 3)),
            ) ,
            onPressed: ()async{
              SharedPreferences prefs =
              await SharedPreferences.getInstance();
              String codeDate =
              DateFormat('yyyy-MM-dd-HH:mm-ss')
                  .format(DateTime.now());

              String balance = await checkWallet();
              double balanceNum = double.parse(balance);
              String? code;
              if (balanceNum > 0.200) {
                code =
                await paymentController.getEncryptedCode(0);
                Get.dialog(Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        15.0,
                      ),
                    ),
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    child: Container(
                      height: 380.h,
                      color: Colors.white,
                      child: Center(
                        child: QrImage(
                          data:
                          "{\"lastToken\":\"${prefs.getString('lastToken')}\",\"paymentCode\":\"$codeDate${prefs.getString('lastPhone')!}\",\"userName\":\"${prefs.getString('userName')!}\"}",
                          version: QrVersions.auto,
                          size: 322.0.sp,
                        ),
                      ),
                    )));
              } else {
                showFlutterToast(
                    message: "msg_0_balance",
                    backgroundColor: Colors.redAccent,
                    isLong: true,
                    textColor: Colors.white);
              }}, icon: Icon(Icons.qr_code),
            label:Text(
              "Pay via show QR code_txt".tr,
              style: TextStyle(
                  fontSize: 13.sp,
                  letterSpacing: 0,
                  fontWeight: FontWeight.bold
              ),
            ), ),
        ],
      ),
    ),
  );


  Future<String> checkWallet() async{
    await paymentController.getMyWallet();
    return paymentController.myBalance.value;
  }
}
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:background_location/background_location.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:geolocator/geolocator.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:location/location.dart' as loc;
import 'package:signalr_core/signalr_core.dart';
import '../Assistants/assistantMethods.dart';
import '../Assistants/distance_calculator.dart';
import '../Assistants/globals.dart';
import '../Assistants/request-assistant.dart';
import '../Data/current_data.dart';
import '../config-maps.dart';
import '../model/Destination.dart';
import '../model/address.dart';
import '../model/location.dart';
import '../model/placePredictions.dart';
import '../services/audio_player.dart';
import 'dart:math' show cos, sqrt, asin;

class LocationController extends GetxController {
  var pickUpAddress = ''.obs;
  var dropOffAddress = ''.obs;
  List placePredictionList = [].obs;
  var latPinLoc = 0.0.obs;
  var lngPinLoc = 0.0.obs;
  var startAddingPickUp = false.obs;
  var startAddingDropOff = false.obs;
  var buttonString = ''.obs;
  var addDropOff = false.obs;
  var addPickUp = false.obs;
  var tripCreatedDone = false.obs;
  var showPinOnMap =false.obs;
  var liveLocation = new LatLng(0.0, 0.0).obs;
  var currentLocation = new LatLng(29.376291619820897, 47.98638395798397).obs;
  var currentLocationG = new google_maps.LatLng(0.0, 0.0).obs;
  var liveLocationG = new google_maps.LatLng(0.0, 0.0).obs;
  var pickUpLocationAddress =''.obs;
  var dropOffLocationAddress = ''.obs;
  Address? pickUpLocation;
  Address? dropOffLocation ;
  Rx<Position> positionFromPin =Position(latitude: 29.37631633045168, accuracy: 0.0, altitude: 0.0, speed: 0.0, speedAccuracy: 0.0, longitude: 47.98637351560368, heading: 0.0, timestamp: null).obs;
  AudioPlayerService audioPlayerService = AudioPlayerService();
  bool isLocationUpdated = false;

  var myCorrectBuses =[].obs;
  var myRouteBuses =[].obs;
  var myCorrectBusesGot = false.obs;
  var bussesList = [].obs;
  var points = [];
  var myFavAddresses =[].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
    Timer(Duration(milliseconds: 100), () {
      getCurrentLocationFromChannel();
      signalRInit();
      signalRTRacking();
    });
    getLocation();
  }

  //get current location from ios channel
  static const locationChannel = MethodChannel('location');
  final arguments = {'name': 'khaled'};
  Future getCurrentLocationFromChannel() async {
    var value;
    try {
      value = await locationChannel.invokeMethod("getCurrentLocation", arguments);
      var lat = value['lat'];
      var lng = value['lng'];
      if (lng > 0.0) {
        user.currentLocation = LocationModel(value['lat'], value['lng']);

        print("value  , main :: ${value.toString()}");
       changePickUpAddress('Current Location');
        currentPosition = geo.Position(
          latitude: lat,
          longitude: lng,
          accuracy: 0.0,
          altitude: lat,
          speedAccuracy: 0.0,
          heading: 0.0,
          timestamp: DateTime.now(),
          speed: 0.0,
        );
        searchCoordinateAddress(LocationModel(lat, lng));

        addPickUp.value = true;
      } else {
        print('Wrong coordinates ###');
      }
    } catch (err) {
      print(err);
    }
  }

  Future updateMyLocationInSystem(LocationModel location)async{
    var headers = {
      'Authorization': 'bearer ${user.accessToken}',
      'Content-Type': 'application/json'
    };
    var request = http.Request('POST', Uri.parse('$baseURL/api/UserTracking'));
    request.body = json.encode({
      "Longitude": location.longitude,
      "Latitude": location.latitude
    });
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      print(await response.stream.bytesToString());
      print("......... send location update in system done  .......");


    }
    else {
      print(response.reasonPhrase);
    }

  }

 // send location signal
  HubConnection? connection;
  HubConnection? connectionTracking;

  final liveServerUrl = "https://route.click68.com/ChatHub";
  final liveServerTrackingUrl = "https://route.click68.com/trackinghub";

  //tracking hub
  Future<void> signalRTRacking()async{
    //tracking hub
    connectionTracking = HubConnectionBuilder().withUrl(liveServerTrackingUrl,
        HttpConnectionOptions(
          // accessTokenFactory: () async => await liveTransactionAccessToken,
            transport: HttpTransportType.webSockets,
            logging: (level, message){
              if(message.contains('HubTransaction tracking connected successfully')){
                print('connected tracking successfully');
              }
              print("SignalR tracking Level: $level, Message: ${message.toString()}");
            }
        )).build();

    connectionTracking?.serverTimeoutInMilliseconds = Duration(minutes: 122).inMilliseconds;
    connectionTracking?.onclose((exception) {

      print("onclose.tracking. Exception: $exception");
    });
    connectionTracking?.onreconnected((connectionId){

      print("-----tracking-- ConnectionId: $connectionId");
    });

    connectionTracking?.on('NearestLocation', (message) async {
      print("---------- NearestLocation ..---------... Message: ${message!.first}");
      myCorrectBuses.value = message.first;
      myCorrectBusesGot.value = true;
      update();
    });

    await connectionTracking?.start();


  }

  Future detectingCorrectBus() async{
    print("-------------trip created------------------- $tripCreatedDone");
    if(tripCreatedDone.value ==true){
      var invoke = await connectionTracking?.invoke("NearestBusLocation",args:
      [
          {"BusID":[bussesList[0].name,bussesList[1].name]},
      ]);
    }
  }

  Future<void> signalRInit() async {
      connection = HubConnectionBuilder().withUrl(liveServerUrl,
          HttpConnectionOptions(
            // accessTokenFactory: () async => await liveTransactionAccessToken,
              transport: HttpTransportType.webSockets,
              logging: (level, message){
                if(message.contains('HubConnection connected successfully')){
                 print('connected successfully');
                }
                print("SignalR Level: $level, Message: ${message.toString()}");
              }
          )).build();



      connection?.serverTimeoutInMilliseconds = Duration(minutes: 122).inMilliseconds;
      connection?.onclose((exception) {

        print("onclose.. Exception: $exception");
      });
      connection?.onreconnected((connectionId){

        print("------- ConnectionId: $connectionId");
      });

      await connection?.start();

    }



  // send user location signalr
  sendUserLocationSignalR(LocationModel location)async {
    print({"UserID":"${user.id}","Longitude":location.longitude,"Latitude":location.latitude});
    await connection?.invoke('SendUserLocation', args: [{"UserID":"${user.id}","Longitude":location.longitude,"Latitude":location.latitude}]);

  }

  var location = loc.Location();
  geo.Position? currentPosition;
  double bottomPaddingOfMap = 0;
  late loc.PermissionStatus _permissionGranted;
//get location for all
  Future getLocation() async {
    loc.Location location = loc.Location.instance;

    geo.Position? currentPos;
    loc.PermissionStatus permissionStatus = await location.hasPermission();
    _permissionGranted = permissionStatus;
    if (_permissionGranted != loc.PermissionStatus.granted) {
      final loc.PermissionStatus permissionStatusReqResult =
      await location.requestPermission();

      _permissionGranted = permissionStatusReqResult;
    }
    loc.LocationData loca = await location.getLocation();
    user.currentLocation = LocationModel(loca.latitude!, loca.longitude!);

    print(" ##@@@@@@## current  location ##@@@@@@@## ${loca.heading} ,, ${loca.headingAccuracy}");

    BackgroundLocation.startLocationService(distanceFilter : 1);

    BackgroundLocation.getLocationUpdates((location) async {
      //print(" #### get Location Updates #### $location");
      if (!isLocationUpdated){
        isLocationUpdated =true;
      Timer(Duration(seconds:3), () {
        user.currentLocation = LocationModel(location.latitude!, location.longitude!);

        print("......... send location update counter .......");
        //  updateMyLocationInSystem(LocationModel(location.latitude!, location.longitude!));
         // sendUserLocationSignalR(LocationModel(location.latitude!, location.longitude!));
          isLocationUpdated =false;

      });

      }
     // print("location ....... background update ${location.longitude} - ${location.latitude}");
      //audioPlayerService.audio1Play();
    });

    if (loca.latitude != null) {
     changePickUpAddress('Current Location');
      currentPosition = geo.Position(
        latitude: loca.latitude!,
        longitude: loca.longitude!,
        accuracy: loca.accuracy!,
        altitude: loca.altitude!,
        speedAccuracy: loca.speedAccuracy!,
        heading: loca.heading!,
        timestamp: DateTime.now(),
        speed: loca.speed!,
      );
     searchCoordinateAddress(LocationModel(loca.latitude!,loca.longitude!));
      addPickUp.value = true;
    }

    geo.Position position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high);
    gotMyLocation(true);
    addPickUp.value = true;
    changePickUpAddress('Current Location');

    print("--------------------========== position controller $position");
    LatLng latLngPosition = LatLng(position.latitude, position.longitude);

    addPickUp.value = true;
  }

  Future searchCoordinateAddress(LocationModel location) async {
    AssistantMethods assistantMethods = AssistantMethods();
    String address = await assistantMethods.searchCoordinateAddress(currentPosition!, true);
    trip.startPointAddress = address;
    trip.startPoint = LocationModel(location.latitude, location.longitude);
    gotMyLocation(true);
    changePickUpAddress(address);
  }

  void changePickUpAddress(String pickUpAddressV) {
    pickUpAddress.value = pickUpAddressV;
    update();
  }

  void changeDropOffAddress(String dropOffAddressV) {
    dropOffAddress.value = dropOffAddressV;
    update();
  }

  void startAddingPickUpStatus(bool status){
    startAddingPickUp.value = status;
    update();
  }

  void startAddingDropOffStatus(bool status){
    startAddingDropOff.value = status;
    update();
  }

  void tripCreatedStatus(bool status){
    tripCreatedDone.value = status;
    update();
  }

  refreshPlacePredictionList(){
    placePredictionList.clear();
    placePredictionList.add(
        PlaceShort(
            placeId: '0',
            mainText: 'set_location_on_map_txt'.tr,
            secondText: 'choose_txt'.tr,
    ));
    getMyFavAddresses();
  }

  void updatePickUpLocationAddress( Address pickUpAddress){
    pickUpLocation = pickUpAddress;
    update();
  }

  void updateDropOffLocationAddress( Address dropOffAddress){
    dropOffLocation = dropOffAddress;
    update();
  }

  updateLiveLoc(LatLng latLng){
    liveLocation.value = latLng;
  }

  void findPlace(String placeName) async {
    if (placeName.length > 1) {

      placePredictionList.clear();
      String autoCompleteUrl =
          "https://api.mapbox.com/geocoding/v5/mapbox.places/$placeName.json?worldview=us&country=kw&access_token=$mapbox_token";

      var res = await RequestAssistant.getRequest(autoCompleteUrl);


      if (res == "failed") {
        print('failed');
        return;
      }
      if (res["features"].length <1) {
        print('failed');
        return;
      }
      if (res["features"] != null) {
        print("res features  ===== :: ${res["features"]}");

        print(res['status']);
        var predictions = res["features"];

        var placesList = (predictions as List)
            .map((e) => PlacePredictions.fromJson(e))
            .toList();

        //placePredictionList = placesList;
        placesList.forEach((element) {
          placePredictionList.add(PlaceShort(
              placeId: element.id,
              mainText: element.text,
              secondText: element.place_name,
            lat: element.lat,
            lng: element.lng
          ));
        });
        print(placePredictionList.first);
        update();
      }
    }
  }

  //
  RxBool gotMyLocation = false.obs;
  addMyLocation(bool got){
    gotMyLocation.value = got;
    update();
}

updatePinPos(double lat , double lng){
    latPinLoc.value = lat;
    lngPinLoc.value = lng;
    currentLocationG.value=google_maps.LatLng(lat,lng);
    update();
}

//address
  Future getMyFavAddresses() async {

    var headers = {
      'Authorization': 'bearer ${user.accessToken}',
      'Content-Type': 'application/json'
    };
    var request = http.Request('Get', Uri.parse(baseURL +'/api/ListLocationByUser'));

    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();
    var json = jsonDecode(await response.stream.bytesToString());

    if (response.statusCode == 200 &&json['status'] ==true) {
      print("res ====----==== ${json}");
      myFavAddresses.value = json["description"];

      placePredictionList.add(
          PlaceShort(
              placeId: '1',
              mainText: "${myFavAddresses[1]['name']}",
              secondText: '${myFavAddresses[1]['desc']}',
              lat:myFavAddresses[1]['latitude'],
              lng:myFavAddresses[1]['longitude'],
          ));
      return myFavAddresses;
    }
    else {
      print(response.reasonPhrase);
      return false;
    }

  }


  //get route's busses
Future getRouteBusses(String routeId)async{
  myCorrectBusesGot.value =false;

  points.clear();
  var headers = {
    'Authorization': 'bearer ${user.accessToken}',
    'Content-Type': 'application/json'
  };
  var request = http.Request('POST', Uri.parse(baseURL +'/api/divice/BusInRoute'));
  request.body = json.encode({
    "RouteID": routeId
  });
  request.headers.addAll(headers);

  http.StreamedResponse response = await request.send();
  var jsonResponse = jsonDecode(await response.stream.bytesToString());

  if (response.statusCode == 200 &&jsonResponse['status'] ==true) {
    print("res ====--.......................length : ${jsonResponse["description"].length} ..................................--==== ${jsonResponse}");

    for(var p in jsonResponse["description"]){
      var busToEndP1 = calculateDistance(LocationModel(double.parse(p["latitude1"].toString()), double.parse(p["longitude1"].toString())), LocationModel(trip.endPoint.latitude,trip.endPoint.longitude));
      var busToEndP2 = calculateDistance(LocationModel(double.parse(p["latitude2"].toString()), double.parse(p["longitude2"].toString())), LocationModel(trip.endPoint.latitude,trip.endPoint.longitude));

      var userToEnd = calculateDistance(LocationModel(double.parse(trip.endPoint.latitude.toString()), double.parse(trip.endPoint.longitude.toString())), LocationModel(user.currentLocation!.latitude,user.currentLocation!.longitude));

      print("l1 = ${busToEndP1} ............. ..........");
     print("l2 = ${busToEndP2}");

      if(busToEndP1>busToEndP2 && busToEndP2 >= userToEnd){
        points.add( Point(p["latitude2"], p["longitude2"], p["busID"],distance: busToEndP2),);
        bussesList.clear();
        await distanceCalculation();

        for(var i = 0; i < bussesList.length; i++){
          print("busses =bus: $i==.= ${bussesList[i].name}");
          print("busses =bus: $i==.= ${bussesList[i].distance}");

          print("busses =bus: $i==.= ${bussesList[i].lat}");
        }

      }

    }
    print("points length =====--== ${points.length}");
    if(points.length>0){
      Timer.periodic(Duration(seconds: 4), (Timer t) => detectingCorrectBus());
    }
    update();
  }else {
    print("routeId ${trip.routeId}");
    print("Error getRouteBusses $jsonResponse");
  }
  }


  //calculate the distance between tow points and
 double calculateDistance(LocationModel point1 ,LocationModel point2){
   double calculateDistance(lat1, lon1, lat2, lon2){
     var p = 0.017453292519943295;
     var c = cos;
     var a = 0.5 - c((lat2 - lat1) * p)/2 +
         c(lat1 * p) * c(lat2 * p) *
             (1 - c((lon2 - lon1) * p))/2;
     return 12742 * asin(sqrt(a));
   }

   List<dynamic> data = [
     {
       "lat": point1.latitude,
       "lng": point1.longitude
     },{
       "lat": point2.latitude,
       "lng": point2.longitude
     }
   ];
   double totalDistance = 0;
   for(var i = 0; i < data.length-1; i++){
     totalDistance += calculateDistance(data[i]["lat"], data[i]["lng"], data[i+1]["lat"], data[i+1]["lng"]);
   }
   print(totalDistance);
   return totalDistance;
 }

 //2
  distanceCalculation() {
    for(var d in points){
      var km = getDistanceFromLatLonInKm(trip.startPoint.longitude,trip.startPoint.longitude, d.lat,d.lng);
      // var m = Geolocator.distanceBetween(position.latitude,position.longitude, d.lat,d.lng);
      // d.distance = m/1000;
      d.distance = km;
      bussesList.add(d);

      print("*********busses list length************ ${bussesList.length}");

      print("*********#########************ ${d.name}");
      // print(getDistanceFromLatLonInKm(position.latitude,position.longitude, d.lat,d.lng));
    }

      bussesList.sort((a, b) {
        return a.distance.compareTo(b.distance);
      });
  }
}

class PlaceShort {
  String? placeId;
  String? mainText;
  String? secondText;
  double? lat;
  double? lng;

  PlaceShort({this.mainText, this.placeId, this.secondText,this.lat,this.lng});

}

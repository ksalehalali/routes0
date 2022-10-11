import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../Assistants/globals.dart';
import '../../../Data/current_data.dart';
import '../../../controller/lang_controller.dart';
import '../../../controller/payment_controller.dart';
import '../../widgets/dialogs.dart';
import 'balance_calculator.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final PaymentController walletController = Get.find();
  final LangController langController = Get.find();

  int navIndex = 2;
  final box = GetStorage();
  bool? thereIsCard = false;
  var wallet;
  Color? _color = routes_color;
  Color? _color2 = Colors.grey[700];
  bool showPayments = true;
  bool showRecharges = false;
  double amount = 0.0;
  TextEditingController amountController = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getData();
  }

  getData() async {
    walletController.getMyWallet();
    walletController.getMyListOfRecharges();
    walletController.getMyListOfPayments();
  }


  Future<void> scanQRCode(screenSize) async {
    Navigator.of(context).pop();

    try {
      final qrCode = await FlutterBarcodeScanner.scanBarcode(
          '#5fa693', "Cancel", true, ScanMode.QR);
      print(qrCode);
      final jsonData = jsonDecode(qrCode);

      if (jsonData != null) {
        _confirmInfoDialog(jsonData,screenSize);
      }

      //  walletController.send(user.id!);
      if (!mounted) return;
    } on PlatformException {
      Get.snackbar('Scan Failed', "Scan Failed try again");
    }
  }

  //show send result dialog
  showSendResultDialog(var res,screenSize){
    Get.dialog(Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          height: screenSize.height * 0.3+30,
          width: screenSize.width * 0.7,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

            Align(
                alignment: Alignment.topCenter,
                child:res['status'] ==true?SvgPicture.asset(
                  "assets/icons/done.svg",
                  width: 60,
                  height: 60,
                  color: Colors.green[700],
                ):SvgPicture.asset(
          "assets/icons/feild.svg",
          width: 60,
          height: 60,
          color: Colors.green[700],
        )),
          SizedBox(height: 14.0,),
           Align(
              alignment: Alignment.topCenter,
              child:Text(res['status']==true?'The amount has been transferred_txt'.tr:'The amount has not been transferred_txt'.tr,textAlign: TextAlign.center,style: const TextStyle(color: Colors.black,fontSize: 18,fontWeight: FontWeight.bold),)),

            Spacer(),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                Navigator.pop(context);

              },
              style: ButtonStyle(
                backgroundColor:
                MaterialStateProperty.all(Colors.white),
                foregroundColor:
                MaterialStateProperty.all(routes_color),
                padding: MaterialStateProperty.all(
                    EdgeInsets.symmetric(
                        vertical: 12, horizontal: 22)),
              ),
              child: Text('Close_txt'.tr,style: TextStyle(color: Colors.black,fontSize: 14,fontWeight: FontWeight.bold),),
            ),
          ]),
        ),
      ),
    ));
  }
  showEnterAmountDialog(screenSize) {
    Get.dialog(Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          height: screenSize.height * 0.4-40,
          width: screenSize.width * 0.8,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Center(
              child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: const Icon(
                      Icons.close_sharp,
                      size: 39,
                      color: Colors.redAccent,
                    )),
              ),
              SizedBox(
                height: 18.0,
              ),
              Text('Send some credit to your friends_txt'.tr),
              SizedBox(
                height: 28.0,
              ),
              Align(
                  alignment: Alignment.center,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        child: TextFormField(
                          decoration: InputDecoration(
                              hintText: 'Amount ...(1.500)_txt'.tr),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          controller: amountController,
                          validator: (val) {
                            if (double.parse(val!) < 0.500)
                              return "Wrong amount";
                          },
                          onChanged: (val){
                            amount =  double.parse(val);
                          },
                        ),
                      ),
                      SizedBox(
                        height: 38.0,
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: ElevatedButton(
                          onPressed: () {
                            if(amountController.text !=''&& !amountController.text.isEmpty){
                              if (double.parse(amountController.text) > 0.499) {
                                print(
                                    'amount is ${double.parse(amountController.text)}');
                                Navigator.of(context).pop();
                                showEnterUserPhoneDialog(screenSize);
                              } else {
                                print(
                                    'amount is ${double.parse(amountController.text)}');
                                Get.snackbar("Wrong Value_txt".tr,
                                    "please enter amount at last 0.500_txt".tr);
                              }
                            }else{
                              Fluttertoast.showToast(
                                  msg: "wrong value",
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.CENTER,
                                  timeInSecForIosWeb: 1,
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                  fontSize: 16.0.sp);

                            }

                          },
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(routes_color),
                            foregroundColor:
                                MaterialStateProperty.all(Colors.white),
                            padding: MaterialStateProperty.all(
                                EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 22)),
                          ),
                          child: Text('Continue_txt'.tr),
                        ),
                      ),
                    ],
                  )),
            ],
          )),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.blue[50]!.withOpacity(0.5),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: screenSize.height * .1 - 70.h,
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'available_balance_txt'.tr,
                        style: TextStyle(
                            fontSize: 15.sp, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(
                        height: 5.0.h,
                      ),
                      Obx(
                        () => walletController.gotMyBalance.value == true
                            ? Text(
                                walletController.myBalance.value,
                                style: TextStyle(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.bold),
                              )
                            : SizedBox(
                                height: 18.h,
                                width: 18.w,
                                child: CircularProgressIndicator.adaptive(
                                  backgroundColor: Colors.black,
                                  strokeWidth: 3.w,
                                )),
                      ),
                    ],
                  ),
                  Spacer(),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => BalanceCalculator()));
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_box_sharp,
                          color: Colors.green[900],
                          size: 28.sp,
                        ),
                        SizedBox(
                          height: 5.0.h,
                        ),
                        Text(
                          'add_redit_btn'.tr,
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        )
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: screenSize.height * 0.1 - 42.h,
              ),

              Container(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () async {

                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        String codeDate = DateFormat('yyyy-MM-dd-HH:mm-ss').format(DateTime.now());
                        Get.dialog(Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                15.0,
                              ),
                            ),
                            elevation: 0,
                            backgroundColor: Colors.transparent,
                            child: Container(
                              height: 360.h,
                              color: Colors.white,
                              child: Center(
                                child: QrImage(
                                  data: "{\"lastToken\":\"${prefs.getString('lastToken')}\",\"paymentCode\":\"$codeDate${prefs.getString('lastPhone')!}\",\"userName\":\"${prefs.getString('userName')!}\"}",
                                  version: QrVersions.auto,
                                  size: 250.0.sp,
                                ),
                              ),
                            )));
                        print(
                            "{\"userId\":\"${user.id!}\",\"userName\":\"${user.name}\",\"paymentCode\":\"${user.PaymentCode}\"}");
                      },
                      child: Text(
                        "pay_btn".tr,
                        style: TextStyle(fontSize: 17.sp, letterSpacing: 1),
                      ),
                      style: ElevatedButton.styleFrom(
                          maximumSize: Size(
                              Get.size.width * 0.4.w, Get.size.width * 0.4.w),
                          minimumSize: Size(Get.size.width * 0.4.w, 40.w),
                          primary: routes_color2,
                          onPrimary: Colors.white,
                          alignment: Alignment.center),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        showEnterAmountDialog(screenSize);
                      },
                      child: Text(
                        "Send_txtBtn".tr,
                        style: TextStyle(fontSize: 17.sp, letterSpacing: 1),
                      ),
                      style: ElevatedButton.styleFrom(
                          maximumSize: Size(
                              Get.size.width * 0.4.w, Get.size.width * 0.4.w),
                          minimumSize: Size(Get.size.width * 0.4.w, 40.w),
                          primary: routes_color2,
                          onPrimary: Colors.white,
                          alignment: Alignment.center),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 12.0.h,
              ),
              //trans3131

              Container(
                decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 10.0.h,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _color = routes_color;
                                _color2 = Colors.grey[700];
                                showPayments = true;
                                showRecharges = false;
                              });
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                    duration: 11.seconds,
                                    curve: Curves.easeIn,
                                    child: Text('payments_txt'.tr,
                                        style: TextStyle(
                                            color: _color,
                                            fontWeight: FontWeight.w600))),
                                SizedBox(
                                  height: 10.0.h,
                                ),
                                AnimatedContainer(
                                  curve: Curves.easeInOut,
                                  width: screenSize.width / 2 - 15.w,
                                  height: 2.5.h,
                                  color: _color,
                                  duration: 900.milliseconds,
                                )
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _color2 = routes_color;
                                _color = Colors.grey[700];
                                showPayments = false;
                                showRecharges = true;
                              });
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                    curve: Curves.easeIn,
                                    duration: 14.seconds,
                                    child: Text(
                                      'recharges_txt'.tr,
                                      style: TextStyle(
                                          color: _color2,
                                          fontWeight: FontWeight.w600),
                                    )),
                                SizedBox(
                                  height: 10.0.h,
                                ),
                                AnimatedContainer(
                                  curve: Curves.easeInOut,
                                  width: screenSize.width / 2 - 15.w,
                                  height: 2.5.h,
                                  color: _color2,
                                  duration: 900.milliseconds,
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                      SizedBox(
                        height: screenSize.height * 0.1 - 62.h,
                      ),
                      Obx(() => (walletController.gotPayments.value == false &&
                              walletController.gotRecharges.value == false)
                          ? Center(
                              child: Image.asset(
                                'assets/animation/Logo animated-loop-fast.gif',
                                fit: BoxFit.fill,
                                color: routes_color,
                              ),
                            )
                          : Container()),
                      showPayments
                          ? SizedBox(
                              height: screenSize.height - 200.h,
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 122.0.h),
                                child: CustomScrollView(
                                  slivers: [
                                    Obx(
                                      () => SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                            (context, index) {
                                          return Column(
                                            children: [
                                              ListTile(
                                                title: Text(
                                                  'route ${walletController.payments[index].routeName.toString()}',
                                                  style: TextStyle(
                                                      color: Colors.black),
                                                ),
                                                subtitle: Text(
                                                  DateFormat(
                                                          'yyyy-MM-dd  HH:mm :ss')
                                                      .format(DateTime.parse(
                                                          walletController
                                                              .payments[index]
                                                              .date!)),
                                                  style: TextStyle(height: 2),
                                                ),
                                                trailing: Text(
                                                  walletController
                                                      .payments[index].value!
                                                      .toStringAsFixed(3),
                                                  style: TextStyle(
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                                onTap: () {
                                                  showDialog(
                                                      context: context,
                                                      builder: (context) =>
                                                          CustomDialog(
                                                            payment:
                                                                walletController
                                                                        .payments[
                                                                    index],
                                                            fromPaymentLists:
                                                                false,
                                                            failedPay: false,
                                                          ));
                                                },
                                              ),
                                              Divider(
                                                thickness: 1,
                                                height: 10.h,
                                              ),
                                            ],
                                          );
                                        },
                                            childCount: walletController
                                                .payments.length),
                                      ),
                                    )
                                  ],
                                ),
                              ))
                          : Container(),
                      showRecharges
                          ? SizedBox(
                              height: screenSize.height - 200.h,
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 122.0.h),
                                child: CustomScrollView(
                                  slivers: [
                                    Obx(
                                      () => SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                            (context, index) {
                                          // print( DateFormat('yyyy-MM-dd-HH:mm').format(walletController.allTrans[0].time as DateTime));
                                          //final sortedCars = walletController.allTrans..sort((a, b) => a.time!.compareTo(b.time!));
                                          //print(sortedCars);
                                          return Column(
                                            children: [
                                              ListTile(
                                                //leading: Icon(Icons.payments_outlined),
                                                title: Text(
                                                  walletController
                                                      .recharges[index]
                                                      .paymentGateway
                                                      .toString(),
                                                  style: TextStyle(
                                                      color: Colors.black),
                                                ),
                                                subtitle: Text(
                                                  DateFormat(
                                                          'yyyy-MM-dd  HH:mm :ss')
                                                      .format(DateTime.parse(
                                                          walletController
                                                              .recharges[index]
                                                              .createdDate!)),
                                                  style: TextStyle(height: 2),
                                                ),
                                                trailing: Text(
                                                  walletController
                                                      .recharges[index]
                                                      .invoiceValue!
                                                      .toStringAsFixed(3),
                                                  style: TextStyle(
                                                      color: routes_color,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ),
                                              Divider(
                                                thickness: 1,
                                                height: 10.h,
                                              )
                                            ],
                                          );
                                        },
                                            childCount: walletController
                                                .recharges.length),
                                      ),
                                    )
                                  ],
                                ),
                              ))
                          : Container(),
                      SizedBox(
                        height: 10.0.h,
                      ),
                      Container(
                        width: screenSize.width - 20.w,
                        height: 2,
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showEnterUserPhoneDialog(screenSize) {
    TextEditingController phoneTextEditingController =  TextEditingController();
    Get.dialog(Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          height: screenSize.height * 0.5,
          width: screenSize.width * 0.8,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Center(
              child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: const Icon(
                      Icons.close_sharp,
                      size: 39,
                      color: Colors.redAccent,
                    )),
              ),
              const SizedBox(
                height: 18.0,
              ),
              Text('Send some credit to your friends_txt'.tr),
              SizedBox(
                height: 28.0,
              ),
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: screenSize.width / 2-10,
                        child: TextFormField(
                          controller: phoneTextEditingController,
                            keyboardType:TextInputType.number,
                          maxLength: 12,
                          maxLines: 1,
                          decoration:
                              InputDecoration(hintText: 'Enter User Phone_txt'.tr),

                        ),
                      ),
                      SizedBox(
                        height: 12.0,
                      ),
                      Align(
                          alignment: Alignment.center,
                          child: Text('OR_txt'.tr)),
                      const SizedBox(
                        height: 12.0,
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          scanQRCode(screenSize);
                        },
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all(Colors.white),
                          foregroundColor:
                              MaterialStateProperty.all(routes_color),
                          padding: MaterialStateProperty.all(
                              EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 22)),
                        ),
                        icon: Icon(Icons.camera_alt),
                        label: Text('Scan QRCode_txt'.tr),
                      ),
                      const SizedBox(
                        height: 52.0,
                      ),

                      ElevatedButton(
                        onPressed: () {
                          if(phoneTextEditingController.text.length > 0 && !phoneTextEditingController.text.isEmpty){
                            _confirmInfoDialog({"phone": phoneTextEditingController.text,"userName": phoneTextEditingController.text,},screenSize);
                          }
                        },
                        style: ButtonStyle(
                          backgroundColor:
                          MaterialStateProperty.all(routes_color),
                          foregroundColor:
                          MaterialStateProperty.all(Colors.white),
                          padding: MaterialStateProperty.all(
                              EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 42)),
                        ),
                         child: Text('Continue_txt'.tr),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )),
        ),
      ),
    ));
  }

  void _confirmInfoDialog(jsonData ,screenSize) {
    Get.dialog(
      Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            height: screenSize.height * 0.3,
            width: screenSize.width * 0.8,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: const Icon(
                        Icons.close_sharp,
                        size: 39,
                        color: Colors.redAccent,
                      )),
                ),
                SizedBox(
                  height: screenSize.height * .1 - 70.h,
                ),
                Align(
                  alignment: langController.appLocal == "en"
                      ? Alignment.topLeft
                      : Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0),
                    child: Column(
                      crossAxisAlignment: langController.appLocal == "en"
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      mainAxisAlignment: langController.appLocal == "en"
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.end,
                      children: [
                        const SizedBox(
                          height: 10,
                        ),
                        RichText(
                            text: TextSpan(children: [
                              TextSpan(
                                  text: 'amount'.tr,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black)),
                              TextSpan(
                                  text: ": ${amountController.text}",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black))
                            ])),
                        SizedBox(
                          height: 10,
                        ),
                        RichText(
                            text: TextSpan(children: [
                              TextSpan(
                                  text: 'The recipient name_txt'.tr,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black)),
                              TextSpan(
                                  text: " ${jsonData['userName']} ",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black))
                            ])),
                        SizedBox(
                          height: 10,
                        ),
                        RichText(
                            text: TextSpan(children: [
                              TextSpan(
                                  text: 'The recipient ID_txt'.tr,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black)),
                              TextSpan(
                                  text: " ${jsonData['phoneNumber']} ",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black))
                            ])),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: screenSize.height * 0.1 - 40,
                ),
                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    onPressed: () async {
                      amountController.clear();
                      var res = await walletController.send(jsonData['phone'],amount);
                      Navigator.pop(context);
                      showSendResultDialog(res,screenSize);
                    },
                    style: ButtonStyle(
                      backgroundColor:
                      MaterialStateProperty.all(Colors.white),
                      foregroundColor:
                      MaterialStateProperty.all(routes_color),
                      padding: MaterialStateProperty.all(
                          EdgeInsets.symmetric(
                              vertical: 12, horizontal: 22)),
                    ),
                    child: Text('Confirm_txt'.tr),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

  }
}

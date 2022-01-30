import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:esptouch_flutter/esptouch_flutter.dart';
import 'package:flutter/material.dart';
import 'package:wifi_info_flutter/wifi_info_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_configuration_2/wifi_configuration_2.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController ssid = TextEditingController();
  final TextEditingController bssid = TextEditingController();
  final TextEditingController password = TextEditingController();
  String? selectedNetwork;
  ESPTouchPacket packet = ESPTouchPacket.broadcast;

  @override
  void dispose() {
    ssid.dispose();
    bssid.dispose();
    password.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ESP - WiFi Configuration',
            style: TextStyle(
              fontFamily: 'serif-monospace',
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Builder(builder: (context) => Center(child: form(context))),
      ),
    );
  }

  bool fetchingWifiInfo = false;

  void fetchWifiInfo() async {
    var locationStatus = Permission.locationWhenInUse;
    if (await locationStatus.isDenied) {
      locationStatus.request();
    } else {
      setState(() => fetchingWifiInfo = true);
      try {
        ssid.text = await WifiInfo().getWifiName() ?? '';
        selectedNetwork = await WifiInfo().getWifiName() ?? '';
        bssid.text = await WifiInfo().getWifiBSSID() ?? '';
      } finally {
        setState(() => fetchingWifiInfo = false);
      }
    }
  }

  createTask() {
    return ESPTouchTask(
      ssid: ssid.text,
      bssid: '0',
      password: password.text,
      packet: ESPTouchPacket.multicast,
    );
  }

  Widget form(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: <Widget>[
        Center(
          child: OutlinedButton(
            onPressed: fetchingWifiInfo ? null : fetchWifiInfo,
            child: Text(
              fetchingWifiInfo ? 'Fetching WiFi info' : 'Use current Wi-Fi',
            ),
          ),
        ),
        FutureBuilder(
            future: WifiConfiguration().getWifiList(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              List<String> wifiSSIDList = [];
              List<WifiNetwork> wifiList = snapshot.data as List<WifiNetwork>;
              for (int i = 0; i < wifiList.length; i++) {
                wifiSSIDList.add(wifiList[i].ssid!);
              }

              return DropdownButton<String>(
                // isDense: true,
                isExpanded: true,
                value: selectedNetwork,
                hint: const Text("Select a Wifi"),
                items: wifiSSIDList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    selectedNetwork = v;
                    ssid.text = v!;
                  });
                },
              );
            }),
        TextFormField(
          controller: password,
          decoration: const InputDecoration(
            labelText: 'Password',
            hintText: r'V3Ry.S4F3-P@$$w0rD',
          ),
        ),
        Center(
          child: ElevatedButton(
            onPressed: () {
              Get.to(() => ConnectionScreen(task: createTask()));
            },
            child: const Text('Connect'),
          ),
        ),
      ],
    );
  }
}

class ConnectionScreen extends StatefulWidget {
  final ESPTouchTask task;
  const ConnectionScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ConnectionScreenState();
}

class ConnectionScreenState extends State<ConnectionScreen> {
  late final Stream<ESPTouchResult> stream;
  late final StreamSubscription<ESPTouchResult> streamSubscription;
  late final Timer timer;

  final List<ESPTouchResult> results = [];

  @override
  void initState() {
    stream = widget.task.execute();
    streamSubscription = stream.listen(results.add);
    final receiving = widget.task.taskParameter.waitUdpReceiving;
    final sending = widget.task.taskParameter.waitUdpSending;
    final cancelLatestAfter = receiving + sending;
    timer = Timer(
      cancelLatestAfter,
      () {
        streamSubscription.cancel();
        if (results.isEmpty && mounted) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('No devices found'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Get
                      ..back()
                      ..back(),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      },
    );
    super.initState();
  }

  @override
  dispose() {
    timer.cancel();
    streamSubscription.cancel();
    super.dispose();
  }

  Widget waitingState(BuildContext context) {
    return CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
    );
  }

  Widget error(BuildContext context, String s) {
    return Center(child: Text(s, style: const TextStyle(color: Colors.red)));
  }

  Widget noneState(BuildContext context) {
    return const Text('None');
  }

  Widget resultList(BuildContext context) {
    return const Center(
      child: Text('Connected!'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<ESPTouchResult>(
        stream: stream,
        builder: (context, AsyncSnapshot<ESPTouchResult> snapshot) {
          if (snapshot.hasError) {
            return error(context, 'Cannot connect!');
          }
          if (!snapshot.hasData) {
            final primaryColor = Theme.of(context).primaryColor;
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(primaryColor),
              ),
            );
          }
          switch (snapshot.connectionState) {
            case ConnectionState.active:
              return resultList(context);
            case ConnectionState.none:
              return noneState(context);
            case ConnectionState.done:
              return resultList(context);
            case ConnectionState.waiting:
              return waitingState(context);
          }
        },
      ),
    );
  }
}

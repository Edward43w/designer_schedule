import 'package:flutter/material.dart'; 
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Designer Schedule',
      theme: ThemeData.dark(),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void _enter(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CalendarPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 背景黑色
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 中文名稱
              const Text(
                '溢  聖  慈',
                style: TextStyle(
                  fontSize: 40,
                  color: Colors.white,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // 分隔線
              Container(
                height: 2,
                width: 200,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              // 英文名稱
              const Text(
                'ISSUANCE',
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () => _enter(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 51, 113, 247), 
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  '進入排程',
                  style: TextStyle(
                    fontSize: 25,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int adjustHour(int rawHour) {
  // 若輸入 01 ~ 06 視為 13 ~ 18，代表「下午」
  if (rawHour >= 1 && rawHour <= 6) return rawHour + 12;
  return rawHour;
}

class Appointment {
  final TimeOfDay start;
  final TimeOfDay end;
  final String customer;
  final String designer;
  final String service;

  Appointment({
    required this.start,
    required this.end,
    required this.customer,
    required this.designer,
    required this.service,
  });

  Map<String, dynamic> toJson() => {
        'start': '${start.hour.toString().padLeft(2, '0')}${start.minute.toString().padLeft(2, '0')}',
        'end': '${end.hour.toString().padLeft(2, '0')}${end.minute.toString().padLeft(2, '0')}',
        'customer': customer,
        'designer': designer,
        'service': service,
      };

  static Appointment fromJson(Map<String, dynamic> json) {
    final startStr = json['start'] as String;
    final endStr = json['end'] as String;
    return Appointment(
      start: TimeOfDay(hour: int.parse(startStr.substring(0, 2)), minute: int.parse(startStr.substring(2, 4))),
      end: TimeOfDay(hour: int.parse(endStr.substring(0, 2)), minute: int.parse(endStr.substring(2, 4))),
      customer: json['customer'],
      designer: json['designer'],
      service: json['service'],
    );
  }
}

class _AppointmentLayout {
  final Appointment appointment;
  final int column;
  int columnCount;
  _AppointmentLayout(this.appointment, this.column, this.columnCount);
}

List<_AppointmentLayout> layoutAppointments(List<Appointment> appointments, double Function(TimeOfDay) timeToDouble) {
  // 按開始時間排序
  appointments.sort((a, b) => timeToDouble(a.start).compareTo(timeToDouble(b.start)));

  List<_AppointmentLayout> layouts = [];
  List<List<Appointment>> clusters = [];

  for (final a in appointments) {
    bool placed = false;
    // 找有重疊的 cluster
    for (final cluster in clusters) {
      if (cluster.any((b) => _isOverlap(a, b, timeToDouble))) {
        cluster.add(a);
        placed = true;
        break;
      }
    }
    if (!placed) {
      clusters.add([a]);
    }
  }

  // 每個 cluster 都再做欄位分配
  for (final cluster in clusters) {
    // 按照開始時間排序
    cluster.sort((a, b) => timeToDouble(a.start).compareTo(timeToDouble(b.start)));
    List<List<Appointment>> columns = [];
    for (final a in cluster) {
      bool placed = false;
      for (int i = 0; i < columns.length; i++) {
        if (!_isOverlap(a, columns[i].last, timeToDouble)) {
          columns[i].add(a);
          layouts.add(_AppointmentLayout(a, i, columns.length));
          placed = true;
          break;
        }
      }
      if (!placed) {
        columns.add([a]);
        layouts.add(_AppointmentLayout(a, columns.length - 1, columns.length));
      }
    }
    // 最終同 cluster 內都要共用最大 columnCount
    int maxColumnCount = columns.length;
    for (final l in layouts.where((l) => cluster.contains(l.appointment))) {
      l.columnCount = maxColumnCount;
    }
  }
  return layouts;
}


bool _isOverlap(Appointment a, Appointment b, double Function(TimeOfDay) timeToDouble) {
  return timeToDouble(a.start) < timeToDouble(b.end) && timeToDouble(a.end) > timeToDouble(b.start);
}


class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime selectedDate = DateTime.now();
  List<String> designers = [];
  Map<String, List<Appointment>> dailyAppointments = {};

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late StreamSubscription<DocumentSnapshot> _designerSub;
  StreamSubscription<DocumentSnapshot>? _appointmentSub;

  // ---------------- 新增：同步捲動用的控制器 ----------------
  late final LinkedScrollControllerGroup _hGroup;
  late final LinkedScrollControllerGroup _vGroup;
  late final ScrollController _bodyH;
  late final ScrollController _headerH;
  late final ScrollController _bodyV;
  late final ScrollController _timeV;
  // --------------------------------------------------------
  
  final List<Color> _customerColors = [
    Colors.lightBlueAccent,
    Colors.amber,
    Colors.lightGreen,
    Colors.pinkAccent,
    Colors.deepOrangeAccent,
    Colors.purpleAccent,
    Colors.cyan,
    Colors.lime,
    Colors.teal,
    Colors.indigoAccent,
  ];

  Color _getColorForCustomer(String name) {
    final idx = name.hashCode.abs() % _customerColors.length;
    return _customerColors[idx].withOpacity(0.7);
  }

  @override
  void initState() {
    super.initState();
    // ---------- 新增：初始化控制器 ----------
    _hGroup  = LinkedScrollControllerGroup();
    _vGroup  = LinkedScrollControllerGroup();
    _bodyH   = _hGroup.addAndGet();
    _headerH = _hGroup.addAndGet();
    _bodyV   = _vGroup.addAndGet();
    _timeV   = _vGroup.addAndGet();

    // --------------------------------------
    _listenToDesignerUpdates();
    _listenToAppointmentUpdates();
  }

  void _nextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
    });
    _listenToAppointmentUpdates();
  }

  void _prevDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
    });
    _listenToAppointmentUpdates();
  }

  void _listenToDesignerUpdates() {
    _designerSub = firestore.collection('settings').doc('designers').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['list'] is List) {
          setState(() {
            designers = List<String>.from(data['list']);
          });
        }
      }
    });
  }

  void _listenToAppointmentUpdates() {
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    _appointmentSub?.cancel();
    _appointmentSub = firestore.collection('appointments').doc(key).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        final list = (data?['list'] as List<dynamic>?)?.map((e) => Appointment.fromJson(e as Map<String, dynamic>)).toList();
        if (list != null) {
          setState(() {
            dailyAppointments[key] = list;
          });
        }
      }
    });
  }

  void _onTapTimeSlot(TimeOfDay tapTime, String designer) async {
    final String key = DateFormat('yyyy-MM-dd').format(selectedDate);
    final appointments = dailyAppointments[key] ?? [];
    final overlapped = appointments.where((a) {
      if (a.designer != designer) return false;
      final start = _timeToDouble(a.start);
      final end = _timeToDouble(a.end);
      final tap = _timeToDouble(tapTime);
      return tap >= start && tap < end;
    }).toList();

    if (overlapped.isEmpty) {
      await _editAppointment(designer, existing: null);
    }
    // overlapped 不為空時，不需要做任何事
  }

  Future<void> _updateDesigners(List<String> updatedList) async {
    await firestore.collection('settings').doc('designers').set({'list': updatedList});
  }

  Future<void> _saveAppointments(String key) async {
    final list = dailyAppointments[key] ?? [];
    final jsonList = list.map((e) => e.toJson()).toList();
    await firestore.collection('appointments').doc(key).set({'list': jsonList});
  }

  String pad12(TimeOfDay t) {
    int hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return hour.toString().padLeft(2, '0') + t.minute.toString().padLeft(2, '0');
  }
  String formatTimeRange(TimeOfDay start, TimeOfDay end) {
    return "${pad12(start)}~${pad12(end)}";
  }

  String formatTime12(TimeOfDay t) {
    int hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
  Future<void> _editAppointment(String designer, {Appointment? existing}) async {
    final nameController = TextEditingController(text: existing?.customer ?? '');
    final startController = TextEditingController(
      text: existing != null ? formatTime12(existing.start) : '',
    );
    final endController = TextEditingController(
      text: existing != null ? formatTime12(existing.end) : '',
    );
    final serviceController = TextEditingController(text: existing?.service ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(existing == null ? '$designer 設計師' : '編輯預約'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (existing != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    formatTimeRange(existing.start, existing.end),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '顧客名稱'),
              ),
              TextField(
                controller: serviceController,
                decoration: const InputDecoration(labelText: '服務項目'),
              ),
              TextField(
                controller: startController,
                decoration: const InputDecoration(labelText: '開始時間 (如 0900)'),
              ),
              TextField(
                controller: endController,
                decoration: const InputDecoration(labelText: '結束時間 (如 1230)'),
              ),
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(context, 'delete'),
                child: const Text('刪除', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('儲存')),
          ],
        );
      },
    );

    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    final list = dailyAppointments[key] ?? [];

    if (result == 'save') {
      try {
        final name = nameController.text;
        final service = serviceController.text;
        final startStr = startController.text;
        final endStr = endController.text;

        final startHour = adjustHour(int.parse(startStr.substring(0, 2)));
        final startMinute = int.parse(startStr.substring(2, 4));
        final endHour = adjustHour(int.parse(endStr.substring(0, 2)));
        final endMinute = int.parse(endStr.substring(2, 4));

        final start = TimeOfDay(hour: startHour, minute: startMinute);
        final end = TimeOfDay(hour: endHour, minute: endMinute);

        if (_timeToDouble(start) < 9 || _timeToDouble(end) > 19 || _timeToDouble(start) >= _timeToDouble(end)) {
          throw Exception();
        }

        setState(() {
          if (existing != null) list.remove(existing);
          list.add(Appointment(
            start: start,
            end: end,
            customer: name,
            designer: designer,
            service: service,
          ));
          dailyAppointments[key] = list;
        });
        await _saveAppointments(key);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("請輸入正確時間格式 (0900 ~ 0700)")));
      }
    } else if (result == 'delete' && existing != null) {
      setState(() {
        list.remove(existing);
        dailyAppointments[key] = list;
      });
      await _saveAppointments(key);
    }
  }

  String _formattedHourLabel(int hour) {
    final adjustedHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${adjustedHour.toString().padLeft(2, '0')}:30';
  }

  void _editDesigners() async {
    final controller = TextEditingController(text: designers.join(', '));
    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("編輯設計師列表"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '用逗號分隔（如 A, B, C）'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("儲存")),
          ],
        );
      },
    );

    if (result == true) {
      final updated = controller.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      setState(() {
        designers = updated;
      });
      await _updateDesigners(updated);
    }
  }

  double _timeToDouble(TimeOfDay t) => t.hour + t.minute / 60.0;

  @override
  void dispose() {
    _designerSub.cancel();
    _appointmentSub?.cancel();
    _bodyH.dispose();
    _headerH.dispose();
    _bodyV.dispose();
    _timeV.dispose();
    super.dispose();
  }

  Widget _buildAppointmentBox(Appointment a, double width, double height, double top) {
    return GestureDetector(
      onTap: () => _editAppointment(a.designer, existing: a),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _getColorForCustomer(a.customer),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(a.customer, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            Text(a.service, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- 常數 ---
    const double hourHeight = 80;
    const double startHour = 9;
    const double endHour = 19;
    const double timeColW = 60;
    const double designerColW = 120;
    const double headerH = 40;

    final String key = DateFormat('yyyy-MM-dd').format(selectedDate);
    final apps = dailyAppointments[key] ?? [];

    final double contentW = designerColW * designers.length;
    final double contentH = (endHour - startHour) * hourHeight;

    // ------- 頂端設計師列 -------
    Widget header() => SizedBox(
          height: headerH,
          child: SingleChildScrollView(
            controller: _headerH,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: designers
                  .map((d) => Container(
                        width: designerColW,
                        height: headerH,
                        alignment: Alignment.center,
                        decoration:
                            BoxDecoration(border: Border.all(color: Colors.grey)),
                        child:
                            Text(d, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ))
                  .toList(),
            ),
          ),
        );

    // ------- 左側時間欄 -------
    Widget timeColumn() => SizedBox(
      width: timeColW,
      child: SingleChildScrollView(
        controller: _timeV,
        child: Column(
          children: List.generate((endHour - startHour).toInt(), (i) {
            final h = (startHour + i).toInt();
            return Container(
              height: hourHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: Text(_formattedHourLabel(h)),
            );
          }),
        ),
      ),
    );

    // ------- 主體排程格 -------
    Widget scheduleBody() {
      // 背景 half-hour cells
      final List<Widget> bgCells = [];
      for (int d = 0; d < designers.length; d++) {
        for (int i = 0; i < (endHour - startHour) * 2; i++) {
          final hour = startHour.toInt() + (i ~/ 2);
          final minute = (i % 2) * 30;
          final tapTime = TimeOfDay(hour: hour, minute: minute);
          bgCells.add(Positioned(
            left: d * designerColW,
            top: i * (hourHeight / 2),
            child: GestureDetector(
              onTap: () => _onTapTimeSlot(tapTime, designers[d]),
              child: Container(
                width: designerColW,
                height: hourHeight / 2,
                decoration:
                    BoxDecoration(border: Border.all(color: Colors.grey)),
              ),
            ),
          ));
        }
      }

      // 預約方塊
      final boxes = designers.asMap().entries.expand((entry) {
        final dIdx = entry.key;
        final dName = entry.value;
        final layouts = layoutAppointments(
            apps.where((a) => a.designer == dName).toList(), _timeToDouble);
        return layouts.map((l) {
          final a = l.appointment;
          final boxW = designerColW / l.columnCount;
          final left = dIdx * designerColW + l.column * boxW;
          final top = (_timeToDouble(a.start) - startHour) * hourHeight;
          final boxH =
              (_timeToDouble(a.end) - _timeToDouble(a.start)) * hourHeight;
          return Positioned(
              left: left,
              top: top,
              child: _buildAppointmentBox(a, boxW, boxH, top));
        });
      }).toList();

      return SingleChildScrollView(
        controller: _bodyH,
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          controller: _bodyV,
          child: SizedBox(
            width: contentW,
            height: contentH,
            child: Stack(children: [...bgCells, ...boxes]),
          ),
        ),
      );
    }

    // ------- Scaffold -------
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('yyyy/MM/dd').format(selectedDate)),
        actions: [
          IconButton(onPressed: _prevDay, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: _nextDay, icon: const Icon(Icons.chevron_right)),
          IconButton(onPressed: _editDesigners, icon: const Icon(Icons.edit)),
        ],
      ),
      body: Stack(
        children: [
          // 左上交叉
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: timeColW,
              height: headerH,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: const Text('時間', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          // 頂端 header
          Positioned(left: timeColW, top: 0, right: 0, child: header()),
          // 左側時間欄
          Positioned(left: 0, top: headerH, bottom: 0, child: timeColumn()),
          // 主體
          Positioned(
              left: timeColW,
              top: headerH,
              right: 0,
              bottom: 0,
              child: scheduleBody()),
        ],
      ),
    );
  }

}

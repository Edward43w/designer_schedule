import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

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

class Appointment {
  final TimeOfDay start;
  final TimeOfDay end;
  final String customer;
  final String designer;

  Appointment({
    required this.start,
    required this.end,
    required this.customer,
    required this.designer,
  });

  Map<String, dynamic> toJson() => {
        'start': '${start.hour}:${start.minute}',
        'end': '${end.hour}:${end.minute}',
        'customer': customer,
        'designer': designer,
      };

  static Appointment fromJson(Map<String, dynamic> json) {
    final startParts = (json['start'] as String).split(':');
    final endParts = (json['end'] as String).split(':');
    return Appointment(
      start: TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1])),
      end: TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1])),
      customer: json['customer'],
      designer: json['designer'],
    );
  }
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

  @override
  void initState() {
    super.initState();
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

  Future<void> _updateDesigners(List<String> updatedList) async {
    await firestore.collection('settings').doc('designers').set({'list': updatedList});
  }

  Future<void> _saveAppointments(String key) async {
    final list = dailyAppointments[key] ?? [];
    final jsonList = list.map((e) => e.toJson()).toList();
    await firestore.collection('appointments').doc(key).set({'list': jsonList});
  }

  Future<void> _editAppointment(String designer, {Appointment? existing}) async {
    final nameController = TextEditingController(text: existing?.customer ?? '');
    final startController = TextEditingController(
      text: existing != null ? '${existing.start.hour.toString().padLeft(2, '0')}:${existing.start.minute.toString().padLeft(2, '0')}' : '',
    );
    final endController = TextEditingController(
      text: existing != null ? '${existing.end.hour.toString().padLeft(2, '0')}:${existing.end.minute.toString().padLeft(2, '0')}' : '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(existing == null ? '安排設計師 $designer 的顧客' : '編輯預約'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '顧客名稱'),
              ),
              TextField(
                controller: startController,
                decoration: const InputDecoration(labelText: '開始時間 (HH:mm)'),
              ),
              TextField(
                controller: endController,
                decoration: const InputDecoration(labelText: '結束時間 (HH:mm)'),
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
        final startParts = startController.text.split(':');
        final endParts = endController.text.split(':');

        final start = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
        final end = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));

        if (_timeToDouble(start) < 9 || _timeToDouble(end) > 19 || _timeToDouble(start) >= _timeToDouble(end)) {
          throw Exception();
        }

        bool hasConflict = list.any((other) {
          if (existing != null && identical(other, existing)) return false;
          return other.designer == designer &&
              !(_timeToDouble(end) <= _timeToDouble(other.start) || _timeToDouble(start) >= _timeToDouble(other.end));
        });

        if (hasConflict) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('該時段已有預約，請選擇其他時間')),
          );
          return;
        }

        setState(() {
          if (existing != null) list.remove(existing);
          list.add(Appointment(start: start, end: end, customer: name, designer: designer));
          dailyAppointments[key] = list;
        });
        await _saveAppointments(key);
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("請輸入正確時間格式 (09:00 ~ 19:00)")));
      }
    } else if (result == 'delete' && existing != null) {
      setState(() {
        list.remove(existing);
        dailyAppointments[key] = list;
      });
      await _saveAppointments(key);
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double hourHeight = 80.0;
    const double startHour = 9.0;
    const double endHour = 19.0;
    const double timeColumnWidth = 60.0;
    const double designerColumnWidth = 120.0;

    final double contentHeight = (endHour - startHour) * hourHeight;
    final double contentWidth = designerColumnWidth * designers.length;
    final String key = DateFormat('yyyy-MM-dd').format(selectedDate);
    final appointments = dailyAppointments[key] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('yyyy/MM/dd').format(selectedDate)),
        actions: [
          IconButton(onPressed: _prevDay, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: _nextDay, icon: const Icon(Icons.chevron_right)),
          IconButton(onPressed: _editDesigners, icon: const Icon(Icons.edit)),
        ],
      ),
      body: InteractiveViewer(
        constrained: false,
        minScale: 0.5,
        maxScale: 2.5,
        child: SizedBox(
          width: timeColumnWidth + contentWidth,
          height: contentHeight + 40,
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: timeColumnWidth,
                          height: 40,
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                          alignment: Alignment.center,
                          child: const Text('時間', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...List.generate((endHour - startHour).toInt(), (i) {
                          final hour = startHour + i;
                          final timeLabel = '${hour.toInt().toString().padLeft(2, '0')}:00';
                          return Container(
                            width: timeColumnWidth,
                            height: hourHeight,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                            child: Text(timeLabel),
                          );
                        })
                      ],
                    ),
                    ...designers.map((designer) {
                      return GestureDetector(
                        onTap: () => _editAppointment(designer),
                        child: Column(
                          children: [
                            Container(
                              width: designerColumnWidth,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                              child: Text(designer, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            ...List.generate((endHour - startHour).toInt(), (_) {
                              return Container(
                                width: designerColumnWidth,
                                height: hourHeight,
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                              );
                            }),
                          ],
                        ),
                      );
                    })
                  ],
                ),
              ),
              ...appointments.map((a) {
                final left = timeColumnWidth + designers.indexOf(a.designer) * designerColumnWidth;
                final top = 40 + (_timeToDouble(a.start) - startHour) * hourHeight;
                final height = (_timeToDouble(a.end) - _timeToDouble(a.start)) * hourHeight;
                return Positioned(
                  top: top,
                  left: left,
                  child: GestureDetector(
                    onTap: () => _editAppointment(a.designer, existing: a),
                    child: Container(
                      width: designerColumnWidth,
                      height: height,
                      color: Colors.lightBlueAccent.withOpacity(0.6),
                      alignment: Alignment.center,
                      child: Text(
                        a.customer,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              })
            ],
          ),
        ),
      ),
    );
  }
}

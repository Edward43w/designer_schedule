import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() => runApp(const MyApp());

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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _login() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CalendarPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('設計師登入', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密碼'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _login, child: const Text('登入')),
          ],
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
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime selectedDate = DateTime.now();
  final List<String> designers = ['A', 'V', 'E', 'G', 'Q', 'J', 'H', 'P'];
  final Map<String, List<Appointment>> dailyAppointments = {};

  void _nextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
    });
  }

  void _prevDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
    });
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

        final key = DateFormat('yyyy-MM-dd').format(selectedDate);
        final list = dailyAppointments[key] ?? [];

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
          if (existing != null) {
            list.remove(existing);
          }
          list.add(Appointment(start: start, end: end, customer: name, designer: designer));
          dailyAppointments[key] = list;
        });
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("請輸入正確時間格式 (09:00 ~ 19:00)")));
      }
    } else if (result == 'delete' && existing != null) {
      final key = DateFormat('yyyy-MM-dd').format(selectedDate);
      setState(() {
        dailyAppointments[key]?.remove(existing);
      });
    }
  }

  double _timeToDouble(TimeOfDay t) => t.hour + t.minute / 60.0;

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
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
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
      ),
    );
  }
}

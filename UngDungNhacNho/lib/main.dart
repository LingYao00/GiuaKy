import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin notificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);

  await notificationsPlugin.initialize(settings);

  runApp(const MyApp());
}

class Task {
  String title;
  String location;
  DateTime time;
  bool remind;
  String remindBefore;
  List<String> types;

  Task({
    required this.title,
    required this.location,
    required this.time,
    required this.remind,
    required this.remindBefore,
    required this.types,
  });

  Map<String, dynamic> toJson() => {
    "title": title,
    "location": location,
    "time": time.toIso8601String(),
    "remind": remind,
    "remindBefore": remindBefore,
    "types": types
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    title: json["title"],
    location: json["location"],
    time: DateTime.parse(json["time"]),
    remind: json["remind"],
    remindBefore: json["remindBefore"],
    types: List<String>.from(json["types"]),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Task> tasks = [];

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = tasks.map((e) => jsonEncode(e.toJson())).toList();
    prefs.setStringList("tasks", data);
  }

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList("tasks");

    if (data != null) {
      setState(() {
        tasks = data.map((e) => Task.fromJson(jsonDecode(e))).toList();
      });
    }
  }

  void addTask(Task t) {
    setState(() {
      tasks.add(t);
    });
    saveTasks();
    scheduleNotification(t);
  }

  Future<void> scheduleNotification(Task task) async {
    if (!task.remind || !task.types.contains("Chuông")) return;

    int minutes = 5;
    if (task.remindBefore.contains("10")) minutes = 10;
    if (task.remindBefore.contains("30")) minutes = 30;
    if (task.remindBefore.contains("1 giờ")) minutes = 60;
    if (task.remindBefore.contains("1 ngày")) minutes = 1440;

    final notifyTime = tz.TZDateTime.from(
      task.time.subtract(Duration(minutes: minutes)),
      tz.local,
    );

    await notificationsPlugin.zonedSchedule(
      task.hashCode,
      "Nhắc việc",
      task.title,
      notifyTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id',
          'Nhắc việc',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void deleteTask(int i) {
    setState(() {
      tasks.removeAt(i);
    });
    saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nhắc việc")),
      body: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (_, i) {
          final t = tasks[i];
          return Card(
            child: ListTile(
              title: Text(t.title),
              subtitle: Text(
                  "${t.time}\n${t.location}\n${t.remind ? t.types.join(", ") : "Không nhắc"}"),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => deleteTask(i),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddScreen(onSave: addTask),
            ),
          );
        },
      ),
    );
  }
}

class AddScreen extends StatefulWidget {
  final Function(Task) onSave;

  const AddScreen({super.key, required this.onSave});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final title = TextEditingController();
  final location = TextEditingController();

  DateTime? selectedDateTime;
  bool remind = false;
  String remindBefore = "5 phút";
  List<String> types = [];

  Future<void> pickDateTime() async {
    DateTime? d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (d == null) return;

    TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (t == null) return;

    setState(() {
      selectedDateTime =
          DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  void save() {
    if (title.text.isEmpty || selectedDateTime == null) return;

    widget.onSave(Task(
      title: title.text,
      location: location.text,
      time: selectedDateTime!,
      remind: remind,
      remindBefore: remindBefore,
      types: types,
    ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thêm")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: "Tên")),
            TextField(controller: location, decoration: const InputDecoration(labelText: "Địa điểm")),

            ListTile(
              title: Text(selectedDateTime == null
                  ? "Chọn thời gian"
                  : selectedDateTime.toString()),
              trailing: const Icon(Icons.calendar_today),
              onTap: pickDateTime,
            ),

            SwitchListTile(
              title: const Text("Nhắc"),
              value: remind,
              onChanged: (v) => setState(() => remind = v),
            ),

            if (remind) ...[
              DropdownButton<String>(
                value: remindBefore,
                items: const [
                  DropdownMenuItem(value: "5 phút", child: Text("5 phút")),
                  DropdownMenuItem(value: "10 phút", child: Text("10 phút")),
                  DropdownMenuItem(value: "30 phút", child: Text("30 phút")),
                  DropdownMenuItem(value: "1 giờ", child: Text("1 giờ")),
                  DropdownMenuItem(value: "1 ngày", child: Text("1 ngày")),
                ],
                onChanged: (v) => setState(() => remindBefore = v!),
              ),

              CheckboxListTile(
                title: const Text("Chuông"),
                value: types.contains("Chuông"),
                onChanged: (v) {
                  setState(() {
                    v! ? types.add("Chuông") : types.remove("Chuông");
                  });
                },
              ),

              CheckboxListTile(
                title: const Text("Gmail"),
                value: types.contains("Gmail"),
                onChanged: (v) {
                  setState(() {
                    v! ? types.add("Gmail") : types.remove("Gmail");
                  });
                },
              ),

              CheckboxListTile(
                title: const Text("Thông báo"),
                value: types.contains("Thông báo"),
                onChanged: (v) {
                  setState(() {
                    v! ? types.add("Thông báo") : types.remove("Thông báo");
                  });
                },
              ),
            ],

            ElevatedButton(onPressed: save, child: const Text("Lưu"))
          ],
        ),
      ),
    );
  }
}
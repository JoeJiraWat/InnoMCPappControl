import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'esp32_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => Esp32Service(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temperature & Fruit List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  List<Map<String, String>> fruitList = [];
  String currentTime = DateFormat('hh:mm a, dd MMM yyyy').format(DateTime.now());

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        currentTime = DateFormat('hh:mm a, dd MMM yyyy').format(DateTime.now());
      });
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToAddFruit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFruitPage()),
    );
    if (result != null && result is Map<String, String>) {
      fruitList.insert(0, result);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          Consumer<Esp32Service>(
            builder: (context, espService, child) {
              IconData icon;
              Color color;
              String tooltip;

              switch (espService.status) {
                case ConnectionStatus.connected:
                  icon = Icons.wifi;
                  color = Colors.green;
                  tooltip = 'Connected to ESP32';
                  break;
                case ConnectionStatus.connecting:
                  icon = Icons.wifi_find;
                  color = Colors.orange;
                  tooltip = 'Connecting...';
                  break;
                case ConnectionStatus.error:
                  icon = Icons.wifi_off;
                  color = Colors.red;
                  tooltip = 'Connection Error';
                  break;
                case ConnectionStatus.disconnected:
                  icon = Icons.wifi_off_outlined;
                  color = Colors.grey;
                  tooltip = 'Disconnected. Tap to connect.';
                  break;
              }

              if (espService.status == ConnectionStatus.connecting) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.0,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                );
              }

              return Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        espService.status == ConnectionStatus.connected
                            ? 'Connected'
                            : (espService.status == ConnectionStatus.connecting ? 'Connecting' : 'Disconnected'),
                        style: TextStyle(
                          color: espService.status == ConnectionStatus.connected
                              ? Colors.green
                              : (espService.status == ConnectionStatus.connecting ? Colors.orange : Colors.red),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (espService.status == ConnectionStatus.error && espService.lastError.isNotEmpty)
                        SizedBox(
                          width: 160,
                          child: Text(
                            espService.lastError,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(icon, color: color),
                    tooltip: tooltip,
                    onPressed: () {
                      if (espService.status == ConnectionStatus.disconnected ||
                          espService.status == ConnectionStatus.error) {
                        espService.connect();
                      } else if (espService.status == ConnectionStatus.connected) {
                        espService.disconnect();
                      }
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(Icons.access_time, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  currentTime,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ], 
            ),
          ),
          Consumer<Esp32Service>(
            builder: (context, espService, child) {
              final isConnected = espService.status == ConnectionStatus.connected;
              final temp = isConnected ? espService.temperature.toStringAsFixed(1) : '--';
              final hum = isConnected ? espService.humidity.toStringAsFixed(1) : '--';

              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24.0),
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade300, Colors.teal.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.thermostat, color: Colors.white, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              '$temp°C',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Temperature',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.water_drop, color: Colors.white, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              '$hum%',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Humidity',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Consumer<Esp32Service>(
            builder: (context, espService, child) {
              if (espService.status != ConnectionStatus.connected) {
                return const SizedBox.shrink(); // Don't show controls if not connected
              }
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Controls',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Relay 1'),
                        value: espService.isRelay1On,
                        onChanged: (bool value) {
                          espService.updateRelayState(1, value);
                        },
                        secondary: const Icon(Icons.power_settings_new),
                      ),
                      SwitchListTile(
                        title: const Text('Relay 2'),
                        value: espService.isRelay2On,
                        onChanged: (bool value) {
                          espService.updateRelayState(2, value);
                        },
                        secondary: const Icon(Icons.power_settings_new),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
            child: Text(
              'Fruit Log',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: fruitList.isEmpty
                ? const Center(
                    child: Text(
                      'No fruits added yet. Tap the + button to add.',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : AnimatedList(
                    key: _listKey,
                    initialItemCount: fruitList.length,
                    itemBuilder: (context, index, animation) {
                      final fruit = fruitList[index];
                      return SizeTransition(
                        sizeFactor: animation,
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 6.0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            side: BorderSide(color: Colors.grey.shade200, width: 1),
                          ),
                          child: ListTile(
                            title: Text(
                              fruit['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                                'Type: ${fruit['type']}, Date: ${fruit['date']}'),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: const Icon(Icons.local_florist, color: Colors.teal),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddFruit,
        tooltip: 'Add Fruit',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddFruitPage extends StatefulWidget {
  const AddFruitPage({super.key});

  @override
  State<AddFruitPage> createState() => _AddFruitPageState();
}

class _AddFruitPageState extends State<AddFruitPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  DateTime? _selectedDate;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation1;
  late Animation<Offset> _slideAnimation2;
  late Animation<Offset> _slideAnimation3;
  late Animation<Offset> _slideAnimation4;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation1 = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.ease),
    ));

    _slideAnimation2 = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.6, curve: Curves.ease),
    ));

    _slideAnimation3 = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.8, curve: Curves.ease),
    ));

    _slideAnimation4 = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.ease),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      Navigator.pop(context, {
        'name': _nameController.text,
        'type': _typeController.text,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Fruit'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SlideTransition(
                position: _slideAnimation1,
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Fruit Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a fruit name';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              SlideTransition(
                position: _slideAnimation2,
                child: TextFormField(
                  controller: _typeController,
                  decoration: const InputDecoration(
                    labelText: 'Fruit Type',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a fruit type';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              SlideTransition(
                position: _slideAnimation3,
                child: Row(
                  children: [
                    Text(_selectedDate == null
                        ? 'No Date Chosen'
                        : 'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}'),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _selectedDate = pickedDate;
                          });
                        }
                      },
                      child: const Text('Choose Date'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SlideTransition(
                position: _slideAnimation4,
                child: Center(
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    child: const Text('Add Fruit'),
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

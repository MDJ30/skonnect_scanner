import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'QRScannerPage.dart';

// API Configuration with fallback
class ApiConfig {
  static const String primaryApi = 'https://vynceianoani.helioho.st/skonnect-api';
  static const String fallbackApi = 'https://vynceianoani.helioho.st/skonnect-api';
  
  static Future<http.Response> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$primaryApi$endpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return response;
      }
    } catch (_) {
      print('Primary API failed for GET $endpoint, trying fallback...');
    }
    
    try {
      return await http.get(
        Uri.parse('$fallbackApi$endpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('Fallback API also failed for GET $endpoint: $e');
      rethrow;
    }
  }
  
  static Future<http.Response> post(String endpoint, {required String body}) async {
    try {
      final response = await http.post(
        Uri.parse('$primaryApi$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return response;
      }
    } catch (_) {
      print('Primary API failed for POST $endpoint, trying fallback...');
    }
    
    try {
      return await http.post(
        Uri.parse('$fallbackApi$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('Fallback API also failed for POST $endpoint: $e');
      rethrow;
    }
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Events',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const EventsPage(),
    );
  }
}

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  Future<List<dynamic>> fetchEvents() async {
    try {
      final response = await ApiConfig.get('/fetch_events.php');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['status'] == 'success' && data['events'] is List) {
          return data['events'];
        }
      }
    } catch (e) {
      print('Error fetching events: $e');
    }
    // Return a sample event if DB is empty or error occurs
    return [
      {
        'title': 'Sample Event',
        'description': 'This is a sample event for testing.',
        'date': '2025-08-18',
        'time': '10:00',
        'location': 'Sample Hall',
        'image': '',
        'status': 'upcoming',
      }
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const EventsPage()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: fetchEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildSampleEventList(context);
          }
          final events = snapshot.data!;
          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: event['image'] != null && event['image'].toString().isNotEmpty
                      ? Image.memory(
                          base64Decode(
                            event['image'].toString().replaceFirst(RegExp(r'data:image/[^;]+;base64,'), ''),
                          ),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.event),
                  title: Text(event['title']?.toString() ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event['description']?.toString() ?? ''),
                      Text('Date: ${event['date']}  Time: ${event['time']}'),
                      Text('Location: ${event['location']}'),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailPage(event: event),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSampleEventList(BuildContext context) {
    final sampleEvent = {
      'title': 'Sample Event',
      'description': 'This is a sample event for testing.',
      'date': '2025-08-18',
      'time': '10:00',
      'location': 'Sample Hall',
      'image': '',
      'status': 'upcoming',
    };
    return ListView(
      children: [
        Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: const Icon(Icons.event),
            title: Text(sampleEvent['title']!),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sampleEvent['description']!),
                Text('Date: ${sampleEvent['date']}  Time: ${sampleEvent['time']}'),
                Text('Location: ${sampleEvent['location']}'),
              ],
            ),
            isThreeLine: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailPage(event: sampleEvent),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class EventDetailPage extends StatefulWidget {
  final dynamic event;
  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  Map<String, dynamic>? scannedDetails;
  List<Map<String, dynamic>> attendanceRecords = [];
  List<Map<String, dynamic>> subevents = [];
  bool loadingSubevents = true;

  @override
  void initState() {
    super.initState();
    _fetchSubevents();
    _fetchAttendance();
    _fetchSubeventAttendance();
  }

  Future<void> _fetchSubevents() async {
    setState(() => loadingSubevents = true);
    final eventId = widget.event['id']?.toString() ?? '';
    if (eventId.isEmpty) {
      setState(() => loadingSubevents = false);
      return;
    }
    try {
      final response = await ApiConfig.get('/subevents.php?event_id=${Uri.encodeComponent(eventId)}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          setState(() {
            subevents = data.cast<Map<String, dynamic>>();
          });
        } else if (data is Map && data['subevents'] is List) {
          setState(() {
            subevents = (data['subevents'] as List).cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (e) {
      print('Error fetching subevents: $e');
    } finally {
      setState(() => loadingSubevents = false);
    }
  }

  Future<void> _fetchAttendance() async {
    final eventId = widget.event['id']?.toString() ?? '';
    if (eventId.isEmpty) {
        print('Error: No event ID available');
        return;
    }

    try {
        print('Fetching attendance for event ID: $eventId');
        final response = await ApiConfig.get('/get_attendance.php?event_id=${Uri.encodeComponent(eventId)}');
        
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
        
        if (response.statusCode == 200) {
            final jsonResponse = jsonDecode(response.body);
            
            if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
                setState(() {
                    attendanceRecords = (jsonResponse['data'] as List)
                        .cast<Map<String, dynamic>>();
                });
            } else {
                print('Error in response: ${jsonResponse['message']}');
            }
        } else {
            print('Error fetching attendance: ${response.statusCode}');
        }
    } catch (e) {
        print('Exception fetching attendance: $e');
    }
  }

  Future<void> _fetchSubeventAttendance() async {
    final eventId = widget.event['id']?.toString() ?? '';
    if (eventId.isEmpty) return;

    try {
      if (subevents.isEmpty) {
        await _fetchSubevents();
      }

      List<Map<String, dynamic>> allAttendance = [];

      for (var subevent in subevents) {
        final subeventId = subevent['id']?.toString() ?? '';
        if (subeventId.isEmpty) continue;

        try {
          final response = await ApiConfig.get('/get_subevent_attendance.php?subevent_id=$subeventId');
          if (response.statusCode == 200) {
            final List<dynamic> data = jsonDecode(response.body);
            final records = data.map((record) {
              final map = Map<String, dynamic>.from(record);
              map['subevent_title'] = subevent['title'] ?? 'Unknown Subevent';
              return map;
            }).toList();
            allAttendance.addAll(records.cast<Map<String, dynamic>>());
          }
        } catch (e) {
          print('Error fetching subevent $subeventId attendance: $e');
        }
      }

      setState(() {
        attendanceRecords = allAttendance;
      });
    } catch (e) {
      print('Error fetching subevent attendance: $e');
    }
  }

  Map<String, dynamic> _parseScannedResult(String raw) {
    if (raw.startsWith('result:')) {
      final mapStr = raw.substring(7).trim();
      final match = RegExp(r'\{.*\}').firstMatch(mapStr);
      if (match != null) {
        return _parseMapString(match.group(0)!);
      }
      return _parseMapString(mapStr);
    }
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    } catch (_) {
      if (raw.startsWith('{') && raw.endsWith('}')) {
        return _parseMapString(raw);
      }
    }
    return {'Result': raw};
  }

  Map<String, dynamic> _parseMapString(String mapStr) {
    final cleaned = mapStr.replaceAll(RegExp(r'^{|}$'), '');
    final entries = cleaned.split(',').map((e) => e.split(':')).where((e) => e.length == 2);
    return {for (var pair in entries) pair[0].trim(): pair[1].trim()};
  }

  Future<void> _sendAttendanceToServer(Map<String, dynamic> attendance) async {
    final userId = attendance['user_id']?.toString() ?? attendance['id']?.toString() ?? '';
    final subeventId = widget.event['id']?.toString() ?? '';
    
    final firstName = attendance['first_name']?.toString() ?? '';
    final middleName = attendance['middle_name']?.toString() ?? '';
    final lastName = attendance['last_name']?.toString() ?? '';
    
    final fullName = [firstName, middleName, lastName]
        .where((part) => part.isNotEmpty)
        .join(' ');
    
    final finalFullName = fullName.isNotEmpty 
        ? fullName 
        : (attendance['full_name']?.toString() ?? attendance['name']?.toString() ?? '');

    final payload = {
      'user_id': userId,
      'full_name': finalFullName,
      'subevent_id': subeventId,
      'attended_at': DateTime.now().toIso8601String(),
    };
    
    print('Sending attendance payload:');
    print('Payload: $payload');
    
    try {
      final response = await ApiConfig.post(
        '/attendance.php',
        body: jsonEncode(payload),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final resp = jsonDecode(response.body);
        if (resp is Map<String, dynamic>) {
          if (resp['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attendance recorded successfully')),
            );
            await _fetchAttendance();
          } else {
            throw Exception(resp['message'] ?? 'Failed to record attendance');
          }
        }
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error sending attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<bool> _isUserRegistered(String userId, String eventId) async {
    try {
      final response = await ApiConfig.get(
        '/check_registration.php?user_id=$userId&event_id=$eventId',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['registered'] == true;
      }
    } catch (e) {
      print('Registration check error: $e');
    }
    return false;
  }

  Future<bool> _isUserRegisteredForSubevent(String userId, String subeventId) async {
    try {
      final response = await ApiConfig.get(
        '/check_subevent_registrations.php?user_id=$userId&subevent_id=$subeventId',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['registered'] == true;
      }
    } catch (e) {
      print('Subevent registration check error: $e');
    }
    return false;
  }

  Future<void> _sendSubeventAttendanceToServer(String subeventId, Map<String, dynamic> attendance) async {
    final userId = attendance['user_id']?.toString() ?? attendance['id']?.toString() ?? '';
    
    final firstName = attendance['first_name']?.toString() ?? '';
    final middleName = attendance['middle_name']?.toString() ?? '';
    final lastName = attendance['last_name']?.toString() ?? '';
    
    final fullName = [firstName, middleName, lastName]
        .where((part) => part.isNotEmpty)
        .join(' ');
    
    final finalFullName = fullName.isNotEmpty 
        ? fullName 
        : (attendance['full_name']?.toString() ?? attendance['name']?.toString() ?? '');

    final payload = {
      'subevent_id': subeventId,
      'user_id': userId,
      'full_name': finalFullName,
      'attended_at': DateTime.now().toIso8601String(),
    };
    
    print('Sending subevent attendance payload:');
    print('Payload: $payload');
    
    try {
      final response = await ApiConfig.post(
        '/subevent_attendance.php',
        body: jsonEncode(payload),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final resp = jsonDecode(response.body);
        if (resp is Map<String, dynamic> && resp['success'] == false && resp['message'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resp['message'].toString())),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subevent attendance recorded')),
          );
          await _fetchSubeventAttendance();
        }
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error sending subevent attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<bool> _showConfirmationDialog(Map<String, dynamic> data, {bool isSubevent = false}) async {
    final userId = data['user_id']?.toString() ?? data['id']?.toString() ?? 'N/A';
    final firstName = data['first_name']?.toString() ?? '';
    final middleName = data['middle_name']?.toString() ?? '';
    final lastName = data['last_name']?.toString() ?? '';
    final subeventId = data['subevent_id']?.toString() ?? 'N/A';
    
    final fullName = [firstName, middleName, lastName]
        .where((part) => part.isNotEmpty)
        .join(' ');
    final finalFullName = fullName.isNotEmpty 
        ? fullName 
        : (data['full_name']?.toString() ?? data['name']?.toString() ?? 'N/A');

    print('Confirmation Dialog Data:');
    print('User ID: $userId');
    print('Full Name: $finalFullName');
    print('Subevent ID: $subeventId');
    
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isSubevent ? 'Confirm Subevent Attendance' : 'Confirm Event Attendance'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('User ID: $userId', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Full Name: $finalFullName'),
                const SizedBox(height: 8),
                if (isSubevent) ...[
                  Text('Subevent ID: $subeventId', 
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                ],
                const Divider(),
                const Text('Raw Data (Debug):', 
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(data.toString(), 
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                const Text('Is this information correct?'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _handleAttendance(Map<String, dynamic> parsed) async {
    final userId = (parsed['user_id'] ?? parsed['id'] ?? '').toString();
    
    String subeventId = '';
    if (parsed.containsKey('subevent_id') && parsed['subevent_id'] != null) {
      subeventId = parsed['subevent_id'].toString();
    } else if (parsed['subevent'] is Map && parsed['subevent']['id'] != null) {
      subeventId = parsed['subevent']['id'].toString();
    }
    
    final eventId = widget.event['id']?.toString() ?? '';

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid user information.')),
      );
      return;
    }

    if (subeventId.isNotEmpty) {
      final confirmed = await _showConfirmationDialog(parsed, isSubevent: true);
      if (!confirmed) return;

      final registered = await _isUserRegisteredForSubevent(userId, subeventId);
      if (!registered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User is not registered for this subevent.')),
        );
        return;
      }

      final attendanceData = Map<String, dynamic>.from(parsed);
      attendanceData['subevent_id'] = subeventId;
      attendanceData['user_id'] = userId;
      
      await _sendSubeventAttendanceToServer(subeventId, attendanceData);
      await _fetchSubeventAttendance();
      return;
    }
    
    if (eventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid event information.')),
      );
      return;
    }

    final confirmed = await _showConfirmationDialog(
        {
            ...parsed,
            'event_id': eventId,
        }
    );
    if (!confirmed) return;

    final registered = await _isUserRegistered(userId, eventId);
    if (!registered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User is not registered for this event.')),
      );
      return;
    }

    final attendanceData = {
        ...parsed,
        'subevent_id': widget.event['id']?.toString() ?? '',
        'user_id': userId,
    };

    await _sendAttendanceToServer(attendanceData);
    await _fetchAttendance(); 
  }

  Future<void> _scanForSubevent(Map<String, dynamic> subevent) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerPage()),
    );
    if (result == null) return;
    
    final parsed = _parseScannedResult(result);
    print('Raw scanned data: $parsed');
    
    final subeventId = subevent['id']?.toString() ?? '';
    if (subeventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid subevent ID')),
      );
      return;
    }

    final attendanceData = {
      ...parsed,
      'subevent_id': subeventId,
      'user_id': parsed['user_id'] ?? parsed['id'] ?? '',
    };
    
    print('Attendance data prepared: $attendanceData');
    
    setState(() {
      scannedDetails = attendanceData;
    });
    
    await _handleAttendance(attendanceData);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return Scaffold(
      appBar: AppBar(title: Text(event['title'] ?? 'Event Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event['image'] != null && event['image'].toString().isNotEmpty)
              Center(
                child: Image.memory(
                  base64Decode(event['image'].toString().replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '')),
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 12),
            Text(event['description']?.toString() ?? '', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Date: ${event['date']}  Time: ${event['time']}'),
            Text('Location: ${event['location']}'),
            Text('Status: ${event['status']}'),
            const SizedBox(height: 16),

            if (loadingSubevents)
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Loading subevents...'))
            else if (subevents.isNotEmpty) ...[
              const Text('Sub-events:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: subevents.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final s = subevents[i];
                    return Card(
                      child: Container(
                        width: 260,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['title']?.toString() ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('Points: ${s['points'] ?? '0'}'),
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.qr_code_scanner),
                                    label: const Text('Scan for this subevent'),
                                    onPressed: () => _scanForSubevent(s),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            const Text('Attendance:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: attendanceRecords.isEmpty
                  ? const Text('No attendance records yet.')
                  : ListView(
                      children: attendanceRecords.map((record) {
                        final userId = record['user_id'] ?? '';
                        final userName = record['full_name'] ?? '';
                        final timestamp = record['attended_at'] ?? '';
                        
                        return Card(
                          child: ListTile(
                            title: Text(userName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('User ID: $userId'),
                                Text('Full Name: $userName'), 
                                if (timestamp.isNotEmpty) Text('Time: $timestamp'),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR for Event Attendance'),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QRScannerPage()),
                  );
                  if (result != null) {
                    final parsed = _parseScannedResult(result);
                    setState(() {
                      scannedDetails = parsed;
                    });
                    await _handleAttendance(parsed);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

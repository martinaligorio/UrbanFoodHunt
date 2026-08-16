import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Main entry point of the Flutter application.
void main() {
  runApp(const UrbanFoodHuntApp());
}

class UrbanFoodHuntApp extends StatelessWidget {
  const UrbanFoodHuntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urban Food Hunt',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Sostituito l'URL remoto con il backend locale FastAPI (Requisito 9)
  // Nota: Se usi l'emulatore Android in futuro, usa 'http://10.0.2.2:8000'
  final String backendUrl = "http://10.0.2.2:8000";
  
  String _serverStatus = "Not connected";
  List<dynamic> _spotsList = [];
  bool _isLoading = false;

  /// Funzione asincrona per testare la connessione al server locale (Concurrency & REST API)
  Future<void> _checkServerConnection() async {
    setState(() {
      _isLoading = true;
      _serverStatus = "Connecting to local backend...";
    });

    try {
      final response = await http.get(Uri.parse('$backendUrl/'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _serverStatus = "Connected! Server says:\n${data['message']}";
        });
        // Carica anche la lista dei food spots dopo la connessione
        _fetchFoodSpots();
      } else {
        setState(() {
          _serverStatus = "Server error: Status code ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _serverStatus = "Connection failed: $e\nAssicurati che Uvicorn sia attivo!";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Funzione per recuperare i dati dal database SQLite tramite l'API REST (/spots/)
  Future<void> _fetchFoodSpots() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/spots/'));
      if (response.statusCode == 200) {
        setState(() {
          _spotsList = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Errore nel recupero degli spots: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Urban Food Hunt - Local Cloud'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.fastfood,
              size: 80,
              color: Colors.deepOrange,
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to Urban Food Hunt!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Box di stato del server
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _serverStatus,
                style: const TextStyle(fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // Pulsante di test connessione
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _checkServerConnection,
                    icon: const Icon(Icons.cloud_sync),
                    label: const Text('Test Local Backend Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
            const SizedBox(height: 20),
            const Text(
              'Food Spots dal Database Locale:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Lista dinamica dei chioschi presi dal database SQLite
            Expanded(
              child: _spotsList.isEmpty
                  ? const Center(child: Text("Nessun locale caricato o connessione non ancora testata."))
                  : ListView.builder(
                      itemCount: _spotsList.length,
                      itemBuilder: (context, index) {
                        final spot = _spotsList[index];
                        return Card(
                          elevation: 2,
                          child: ListTile(
                            leading: const Icon(Icons.storefront, color: Colors.orange),
                            title: Text(spot['name'] ?? ''),
                            subtitle: Text(spot['address'] ?? ''),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
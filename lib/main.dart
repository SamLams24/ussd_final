import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sim_data_plus/sim_data.dart';
import 'package:ussd_advanced/ussd_advanced.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  SimData? _simData;
  String exception = '';
  int? _selectedSimIndex;
  String? _response;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    initSimData();
  }

  Future<void> initSimData() async {
    try {
      // Vérifier les permissions d'accès au téléphone
      var status = await Permission.phone.status;
      if (!status.isGranted) {
        bool isGranted = await Permission.phone.request().isGranted;
        if (!isGranted) return;
      }

      // Récupérer les données des cartes SIM
      await SimDataPlugin.getSimData().then((simData) {
        setState(() {
          _isLoading = false;
          _simData = simData;
        });
      });

    } catch (e) {
      debugPrint(e.toString());
      setState(() {
        _isLoading = false;
        _simData = null;
        exception = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var cards = _simData?.cards;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Sim and USSD demo')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: <Widget>[
            // Afficher la liste des SIMs disponibles
            if (cards != null)
              DropdownButton<int>(
                hint: const Text("Sélectionnez une SIM"),
                value: _selectedSimIndex,
                items: cards.map((SimCard card) {
                  return DropdownMenuItem<int>(
                    value: card.slotIndex,
                    child: Text('SIM ${card.slotIndex}: ${card.carrierName}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSimIndex = value;
                  });
                },
              ),

            // Champ pour entrer le code USSD
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Code USSD'),
              ),
            ),

            // Afficher la réponse du USSD
            if (_response != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_response!),
              ),

            // Boutons pour envoyer les requêtes USSD
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _selectedSimIndex != null
                      ? () {
                    UssdAdvanced.sendUssd(
                      code: _controller.text,
                      subscriptionId: _selectedSimIndex!,
                    );
                  }
                      : null,
                  child: const Text('Requête USSD'),
                ),
                ElevatedButton(
                  onPressed: _selectedSimIndex != null
                      ? () async {
                    String? res = await UssdAdvanced.sendAdvancedUssd(
                      code: _controller.text,
                      subscriptionId: _selectedSimIndex!,
                    );
                    setState(() {
                      _response = res;
                    });
                  }
                      : null,
                  child: const Text('Requête session simple'),
                ),
                ElevatedButton(
                  onPressed: _selectedSimIndex != null
                      ? () async {
                    String? res = await UssdAdvanced.multisessionUssd(
                      code: _controller.text,
                      subscriptionId: _selectedSimIndex!,
                    );
                    setState(() {
                      _response = res;
                    });
                    String? res2 = await UssdAdvanced.sendMessage('0');
                    setState(() {
                      _response = res2;
                    });
                    await UssdAdvanced.cancelSession();
                  }
                      : null,
                  child: const Text('Requête multi-session'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

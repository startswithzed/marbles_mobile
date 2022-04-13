import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

import '../model/game.dart';
import 'gameplay_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String _baseUrl = '10.0.2.2:8080';

  late TextEditingController _usernameEditingController;
  late TextEditingController _gameIdEditingController;
  bool _isValidUsername = true;
  bool _isValidGameId = true;
  String? _username;
  String? _gameId;

  final ButtonStyle _buttonStyle = TextButton.styleFrom(
    textStyle: GoogleFonts.quicksand(
      fontSize: 25,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
    ),
    minimumSize: const Size(120.0, 60.0),
    primary: Colors.white,
    backgroundColor: Colors.black87,
  );

  Future<http.Response> _createGame(String username) async {
    return await http.post(Uri.http(_baseUrl, 'api/v1/create'),
        headers: Map<String, String>.of({'player': _username!}));
  }

  Future<http.Response> _joinGame(String username, String gameId) async {
    return await http.post(Uri.http(_baseUrl, 'api/v1/join/$gameId'),
        headers: Map<String, String>.of({'player': _username!}));
  }

  @override
  void initState() {
    super.initState();
    _usernameEditingController = TextEditingController();
    _gameIdEditingController = TextEditingController();
  }

  @override
  void dispose() {
    super.dispose();
    _usernameEditingController.dispose();
    _gameIdEditingController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            reverse: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                //Game Title
                Text(
                  'MARBLES',
                  style: GoogleFonts.quicksand(
                      fontSize: 45, fontWeight: FontWeight.bold),
                ),

                const SizedBox(
                  height: 40.0,
                ),

                //Username Text Field
                SizedBox(
                  width: _width * 0.75,
                  child: TextField(
                    controller: _usernameEditingController,
                    keyboardType: TextInputType.name,
                    onChanged: (name) {
                      //Validate username
                      RegExp exp = RegExp(r"^[a-z0-9_-]{3,15}$");
                      if (exp.hasMatch(name)) {
                        setState(() {
                          _isValidUsername = true;
                        });
                      } else {
                        setState(() {
                          _isValidUsername = false;
                        });
                      }
                      //If username is valid update state
                      if (_isValidUsername) {
                        setState(() {
                          _username = name;
                        });
                      } else {
                        setState(() {
                          _username = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0)),
                      hintText: 'Username',
                      errorText: _isValidUsername ? null : 'Invalid username',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 40.0,
                ),

                //Start Game Button
                TextButton(
                  onPressed: () async {
                    //Check if valid username is present
                    if (_isValidUsername && _username != null) {
                      //Send request to create game
                      var response = await _createGame(_username!);
                      //If request is successful then get game id and navigate to gameplay page
                      if (response.statusCode == 200) {
                        String gameId = response.body
                            .replaceAll('$_username started a new game: ', '');
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => GameplayPage(
                              gameId: gameId,
                              player: _username!,
                              gamestate: Game(
                                  gameId: gameId,
                                  status: 'NEW',
                                  player1: _username!,
                                  player2: null,
                                  stake1: 10,
                                  stake2: 10,
                                  turn: 'PLAYER_1',
                                  move: 'HIDE',
                                  hidden: 0,
                                  bet: 0,
                                  winner: null),
                            ),
                          ),
                        );
                      }
                    } else {
                      //Show error text if username is invalid
                      setState(() {
                        _isValidUsername = false;
                      });
                    }
                  },
                  child: const Text('Start Game'),
                  style: _buttonStyle,
                ),

                const SizedBox(
                  height: 40.0,
                ),

                Text(
                  'Or',
                  style: GoogleFonts.quicksand(
                      fontSize: 20, fontWeight: FontWeight.w500),
                ),

                const SizedBox(
                  height: 40.0,
                ),

                //Game Id Text Field
                SizedBox(
                  width: _width * 0.75,
                  child: TextField(
                    keyboardType: TextInputType.text,
                    onChanged: (gameId) {
                      //Check if game id is valid
                      try {
                        Uuid.parse(gameId);
                        setState(() {
                          _isValidGameId = true;
                        });
                      } on FormatException {
                        setState(() {
                          _isValidGameId = false;
                        });
                      }
                      //If valid then update state
                      if (_isValidGameId && gameId.isNotEmpty) {
                        setState(() {
                          _gameId = gameId;
                        });
                      } else {
                        setState(() {
                          _gameId = null;
                        });
                      }
                      //If game id is deleted then update state and remove error text
                      if (gameId.isEmpty) {
                        setState(() {
                          _isValidGameId = true;
                          _gameId = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0)),
                        hintText: 'Game Id',
                        errorText: _isValidGameId ? null : 'Invalid Game id'),
                  ),
                ),

                const SizedBox(
                  height: 40.0,
                ),

                //Join Game Button
                TextButton(
                  onPressed: () async {
                    //Check if valid username and game id are present
                    if (_isValidUsername && _username != null) {
                      if (_isValidGameId && _gameId != null) {
                        //Send join game request
                        var response = await _joinGame(_username!, _gameId!);
                        if (response.statusCode == 200) {
                          //If request is successful then get game id and navigate to gameplay page
                          Game gamestate =
                              Game.fromJson(jsonDecode(response.body));

                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => GameplayPage(
                                gameId: gamestate.gameId,
                                player: _username!,
                                gamestate: gamestate,
                              ),
                            ),
                          );
                        }
                      } else {
                        //Show error text if button is tapped without game id
                        setState(() {
                          _isValidGameId = false;
                        });
                      }
                    } else {
                      //Show error text if button is tapped without username
                      setState(() {
                        _isValidUsername = false;
                      });
                    }
                  },
                  child: const Text('Join Game'),
                  style: _buttonStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

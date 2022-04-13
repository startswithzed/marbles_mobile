import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import 'package:http/http.dart' as http;

import '../model/game.dart';
import 'home_page.dart';

class GameplayPage extends StatefulWidget {
  final String gameId;
  final String player;
  final Game gamestate;
  const GameplayPage(
      {Key? key,
      required this.gameId,
      required this.player,
      required this.gamestate})
      : super(key: key);

  @override
  State<GameplayPage> createState() => _GameplayPageState();
}

class _GameplayPageState extends State<GameplayPage> {
  final String _baseUrl = '10.0.2.2:8080';

  late StompClient stompClient;
  late Game? game;
  late String playerId;
  int count = 0;

  //Requests to server
  //Hide marbles
  Future<http.Response> _hide(int count) async {
    return await http.post(
      Uri.http(_baseUrl, 'api/v1/' + widget.gameId + '/hide'),
      headers: {
        'player': widget.player,
        HttpHeaders.contentTypeHeader: "application/json",
      },
      body: jsonEncode({"count": count}),
    );
  }

  //Bet marbles
  Future<http.Response> _bet(int count) async {
    return await http.post(
      Uri.http(_baseUrl, 'api/v1/' + widget.gameId + '/bet'),
      headers: {
        'player': widget.player,
        HttpHeaders.contentTypeHeader: "application/json",
      },
      body: jsonEncode({"count": count}),
    );
  }

  //Guess marbles
  Future<http.Response> _guess(String guess) async {
    return await http.post(
      Uri.http(_baseUrl, 'api/v1/' + widget.gameId + '/guess'),
      headers: {
        'player': widget.player,
        HttpHeaders.contentTypeHeader: "application/json",
      },
      body: jsonEncode({"guess": guess}),
    );
  }

  //Quit game
  Future<http.Response> _quit() async {
    return await http.post(
      Uri.http(_baseUrl, 'api/v1/' + widget.gameId + '/quit'),
      headers: {'player': widget.player},
    );
  }

  //Restart game
  Future<http.Response> _restart() async {
    return await http.post(
      Uri.http(_baseUrl, 'api/v1/' + widget.gameId + '/restart'),
      headers: {'player': widget.player},
    );
  }

  @override
  void initState() {
    super.initState();
    //Set up STOMP client
    stompClient = StompClient(
      config: StompConfig.SockJS(
        url: 'http://10.0.2.2:8080/game',
        onConnect: onConnect,
      ),
    );
    stompClient.activate();
    game = widget.gamestate;
    //Set player id
    if (game!.player2 == null) {
      playerId = 'PLAYER_1';
    } else {
      playerId = 'PLAYER_2';
    }
  }

  @override
  void dispose() {
    stompClient.deactivate();
    super.dispose();
  }

  //When the client is connected, subscribe to the topic
  onConnect(StompFrame frame) {
    stompClient.subscribe(
        destination: '/topic/gamestate/' + widget.gameId,
        callback: (StompFrame frame) {
          //Get the response and convert it into Game object and set state
          final gameState = jsonDecode(frame.body!);
          setState(() {
            game = Game.fromJson(gameState);
            count = 1;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //Appbar
      appBar: AppBar(
        title: Text(
          'Marbles',
          style:
              GoogleFonts.quicksand(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white24,
        foregroundColor: Colors.black,
        actions: [
          //Quit game button
          Container(
            margin: const EdgeInsets.all(8.0),
            child: TextButton(
              onPressed: () async {
                // Quit game after game ended
                if (game!.status == 'ENDED' && game!.winner == null) {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (context) => const HomePage()));
                } else {
                  // End game and navigate
                  final response = await _quit();
                  if (response.statusCode == 200) {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) => const HomePage()));
                  }
                }
              },
              child: Text(
                'Quit Game',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                  backgroundColor: Colors.red.shade600, primary: Colors.white),
            ),
          ),
        ],
      ),
      body: _gameplayBody(),
    );
  }

  //Main body
  Widget _gameplayBody() {
    if (game!.player2 == null) {
      // Waiting for second player to join
      return Column(
        children: [
          //Add space
          const SizedBox(
            height: 20.0,
          ),

          Text(
            'Waiting for player 2 to join game : ',
            style: GoogleFonts.quicksand(
              fontSize: 20.0,
            ),
            textAlign: TextAlign.center,
          ),

          //Add space
          const SizedBox(
            height: 20.0,
          ),

          // Show game id and copy button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                game!.gameId,
                style: GoogleFonts.quicksand(
                  fontSize: 18.0,
                ),
                textAlign: TextAlign.center,
              ),
              IconButton(
                //Copy gameId to clipboard
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: game!.gameId));
                },
                icon: const Icon(
                  Icons.content_copy_rounded,
                  size: 20.0,
                ),
                splashRadius: 15.0,
              ),
            ],
          ),
        ],
      );
    } else if (game!.status == 'IN_PROGRESS' && game!.turn == playerId) {
      //Game started and users turn
      return Column(
        children: [
          //Add space
          const SizedBox(
            height: 20.0,
          ),

          //Show stakes
          _stakes(),

          //Add space
          const SizedBox(
            height: 20.0,
          ),

          //Show Move status
          Text(
            game!.move + ' MARBLES',
            style: GoogleFonts.quicksand(
              fontSize: 20.0,
            ),
          ),

          //Add space
          const Expanded(child: SizedBox()),

          //Check move and show body
          game!.move == 'HIDE'
              ?
              //Hide marbles
              _marbleCount('Hide')
              : game!.move == 'BET'
                  ?
                  //Bet marbles
                  _marbleCount('Bet')
                  :
                  //Guess marbles
                  SizedBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          //Guess ODD
                          TextButton(
                            onPressed: () async {
                              final response = await _guess('ODD');
                              if (response.statusCode != 200) {
                                print('Something went wrong');
                              }
                            },
                            child: Text(
                              'Odd',
                              style: GoogleFonts.quicksand(
                                fontSize: 25.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black87,
                              primary: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              minimumSize: const Size(120.0, 60.0),
                            ),
                          ),

                          const SizedBox(
                            height: 20.0,
                          ),

                          //Guess EVEN
                          TextButton(
                            onPressed: () async {
                              final response = await _guess('EVEN');
                              if (response.statusCode != 200) {
                                print('Something went wrong');
                              }
                            },
                            child: Text(
                              'Even',
                              style: GoogleFonts.quicksand(
                                fontSize: 25.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black87,
                              primary: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              minimumSize: const Size(120.0, 60.0),
                            ),
                          ),
                        ],
                      ),
                    ),

          //Add space
          const Expanded(child: SizedBox()),
        ],
      );
    } else if (game!.status == 'IN_PROGRESS' && game!.turn != playerId) {
      //Other player's turn

      return Column(
        children: [
          //Add space
          const SizedBox(
            height: 20.0,
          ),

          //Show stakes
          _stakes(),

          //Add space
          const SizedBox(
            height: 20.0,
          ),

          //Show game status
          Text(
            'WAITING FOR ' +
                (playerId == 'PLAYER_1'
                    ? game!.player2!.toUpperCase()
                    : game!.player1.toUpperCase()) +
                ' TO ' +
                game!.move +
                ' MARBLES',
            style: GoogleFonts.quicksand(
              fontSize: 20.0,
            ),
          ),
        ],
      );
    } else if (game!.status == 'ENDED' && game!.winner != null) {
      // Somebody won the game
      return Column(
        children: [
          //Add space
          const SizedBox(
            height: 20.0,
          ),

          //Show stakes
          _stakes(),

          //Add space
          const SizedBox(
            height: 20.0,
          ),

          Text(
            game!.winner!.toUpperCase() + ' WON!',
            style: GoogleFonts.quicksand(
              fontSize: 20.0,
            ),
          ),

          //Add space
          const Expanded(child: SizedBox()),

          //Restart game button
          TextButton(
            onPressed: () async {
              final response = await _restart();
              if (response.statusCode != 200) {
                print('Something went wrong');
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                'Restart',
                style: GoogleFonts.quicksand(
                  fontSize: 30.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.black87,
              primary: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),

          //Add space
          const Expanded(child: SizedBox()),
        ],
      );
    } else {
      // Somebody quit the game
      return SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Text(
            'Player 2 quit the game',
            style: GoogleFonts.quicksand(
              fontSize: 20.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  //Show the number of marbles held by both players
  Widget _stakes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Player 1 name and stake
        Column(
          children: [
            Text(
              game!.player1,
              style: GoogleFonts.quicksand(
                fontSize: 20.0,
              ),
            ),
            Text(
              game!.stake1.toString(),
              style: GoogleFonts.quicksand(
                fontSize: 40.0,
              ),
            ),
          ],
        ),

        // Player 2 name and stake
        Column(
          children: [
            Text(
              game!.player2!,
              style: GoogleFonts.quicksand(
                fontSize: 20.0,
              ),
            ),
            Text(
              game!.stake2.toString(),
              style: GoogleFonts.quicksand(
                fontSize: 40.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  //Hide marbles and bet marbles body
  Widget _marbleCount(String move) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 60.0,
              height: 75.0,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey,
                ),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Center(
                child: Text(
                  count.toString(),
                  style: GoogleFonts.quicksand(
                    fontSize: 35,
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //Increase count button
                IconButton(
                  onPressed: () {
                    //If player 1 is playing alter player1's stake
                    if (playerId == 'PLAYER_1') {
                      if (count + 1 <= game!.stake1) {
                        setState(() {
                          count++;
                        });
                      }
                    } else {
                      // else alter player2's stake
                      if (count + 1 <= game!.stake2) {
                        setState(() {
                          count++;
                        });
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 40.0,
                  ),
                  splashRadius: 15.0,
                ),
                //Decrease count button
                IconButton(
                  onPressed: () {
                    if (count - 1 > 0) {
                      setState(() {
                        count--;
                      });
                    }
                  },
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 40.0,
                  ),
                  splashRadius: 15.0,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(
          width: 20.0,
        ),
        TextButton(
          onPressed: () async {
            if (move == 'Hide') {
              final response = await _hide(count);
              if (response.statusCode != 200) {
                print('Something went wrong');
              }
            } else {
              final response = await _bet(count);
              if (response.statusCode != 200) {
                print('Something went wrong');
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              move,
              style: GoogleFonts.quicksand(
                fontSize: 30.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          style: TextButton.styleFrom(
            backgroundColor: Colors.black87,
            primary: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }
}

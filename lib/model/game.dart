class Game {
  final String gameId;
  final String status;
  final String player1;
  final String? player2;
  final int stake1;
  final int stake2;
  final String turn;
  final String move;
  final int hidden;
  final int bet;
  final String? winner;

  const Game(
      {required this.gameId,
      required this.status,
      required this.player1,
      required this.player2,
      required this.stake1,
      required this.stake2,
      required this.turn,
      required this.move,
      required this.hidden,
      required this.bet,
      required this.winner});

  static Game fromJson(json) => Game(
      gameId: json['gameId'],
      status: json['status'],
      player1: json['player1'],
      player2: json['player2'],
      stake1: json['stake1'],
      stake2: json['stake2'],
      turn: json['turn'],
      move: json['move'],
      hidden: json['hidden'],
      bet: json['bet'],
      winner: json['winner']);
}

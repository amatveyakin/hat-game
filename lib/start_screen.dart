import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hatgame/game_config_view.dart';
import 'package:hatgame/game_controller.dart';
import 'package:hatgame/game_data.dart';
import 'package:hatgame/util/invalid_operation.dart';
import 'package:hatgame/widget/invalid_operation_dialog.dart';
import 'package:hatgame/widget/wide_button.dart';

Future<String> _newGameOnlineDialog(BuildContext context) async {
  String playerName = '';
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('New Game'),
        content: TextField(
          autofocus: true,
          decoration: new InputDecoration(
            labelText: 'Name',
          ),
          onChanged: (value) {
            playerName = value;
          },
        ),
        actions: <Widget>[
          FlatButton(
            child: Text('Create'),
            onPressed: () {
              Navigator.of(context).pop(playerName);
            },
          ),
        ],
      );
    },
  );
}

class JoinGameParams {
  String playerName = '';
  String gameID = '';
}

Future<JoinGameParams> _joinGameDialog(BuildContext context) async {
  final params = JoinGameParams();
  return showDialog<JoinGameParams>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Join Game'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: new InputDecoration(
                labelText: 'Game ID',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [WhitelistingTextInputFormatter.digitsOnly],
              onChanged: (value) {
                params.gameID = value;
              },
            ),
            TextField(
              autofocus: true,
              decoration: new InputDecoration(
                labelText: 'Name',
              ),
              onChanged: (value) {
                params.playerName = value;
              },
            ),
          ],
        ),
        actions: <Widget>[
          FlatButton(
            child: Text('Join'),
            onPressed: () {
              Navigator.of(context).pop(params);
            },
          ),
        ],
      );
    },
  );
}

class StartScreen extends StatelessWidget {
  Future<void> _newGameOnline(BuildContext context) async {
    final String playerName = await _newGameOnlineDialog(context);
    LocalGameData localGameData;
    try {
      localGameData = await GameController.newLobby(playerName);
    } on InvalidOperation catch (e) {
      showInvalidOperationDialog(context: context, error: e);
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => GameConfigView(
                  localGameData: localGameData,
                )));
  }

  Future<void> _joinGame(BuildContext context) async {
    final JoinGameParams params = await _joinGameDialog(context);
    LocalGameData localGameData;
    try {
      localGameData =
          await GameController.joinLobby(params.playerName, params.gameID);
    } on InvalidOperation catch (e) {
      showInvalidOperationDialog(context: context, error: e);
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => GameConfigView(
                  localGameData: localGameData,
                )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hat Game'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WideButton(
              onPressed: () => _newGameOnline(context),
              child: Text('New Game Online'),
            ),
            SizedBox(height: 24),
            WideButton(
              onPressed: () => _joinGame(context),
              child: Text('Join Game'),
            ),
          ],
        ),
      ),
    );
  }
}

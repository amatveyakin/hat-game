import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hatgame/game_controller.dart';
import 'package:hatgame/game_data.dart';
import 'package:hatgame/game_navigator.dart';
import 'package:hatgame/local_storage.dart';
import 'package:hatgame/util/invalid_operation.dart';
import 'package:hatgame/util/local_str.dart';
import 'package:hatgame/widget/checked_text_field.dart';
import 'package:hatgame/widget/constrained_scaffold.dart';
import 'package:hatgame/widget/dialog.dart';
import 'package:hatgame/widget/invalid_operation_dialog.dart';
import 'package:hatgame/widget/wide_button.dart';

// TODO: Consider using Form + TextFormField instead.

// Local checks only
InvalidOperation? checkGameID(String gameID) {
  if (gameID.isEmpty) {
    return InvalidOperation(LocalStr.tr('game_id_is_empty'));
  }
  return null;
}

class NewGameOnlineScreen extends StatefulWidget {
  static const String routeName = '/new-game-online';

  final playerNameController =
      CheckedTextFieldController(checker: checkPlayerName);

  NewGameOnlineScreen({super.key});

  @override
  State<StatefulWidget> createState() => NewGameOnlineScreenState();
}

class NewGameOnlineScreenState extends State<NewGameOnlineScreen> {
  LocalStorage get localStorage => LocalStorage.instance;
  CheckedTextFieldController get playerNameController =>
      widget.playerNameController;
  bool navigatedToGame = false;

  Future<void> _createGame(BuildContext context) async {
    if (navigatedToGame) {
      return;
    }
    if (!checkTextFields([
      playerNameController,
    ])) {
      return;
    }
    LocalGameData localGameData;
    try {
      localGameData = await GameController.newLobby(
          FirebaseFirestore.instance, playerNameController.textController.text);
    } on InvalidOperation catch (e) {
      if (context.mounted) {
        showInvalidOperationDialog(context: context, error: e);
      }
      return;
    }
    if (context.mounted) {
      // Work around: text field `onSubmitted` triggered on focus lost on web.
      navigatedToGame = true;
      await GameNavigator.navigateToGame(
          context: context, localGameData: localGameData);
    }
  }

  @override
  void initState() {
    playerNameController.textController.text =
        localStorage.get<String?>(LocalColPlayerName()) ?? '';
    playerNameController.textController.addListener(() {
      localStorage.set(
          LocalColPlayerName(), playerNameController.textController.text);
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    playerNameController.focusNode.requestFocus();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    playerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      appBar: AppBar(
        title: Text(context.tr('new_game_online')),
      ),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
              child: CheckedTextField(
                textInputAction: TextInputAction.go,
                labelText: context.tr('your_name'),
                controller: playerNameController,
                // TODO: Uncomment; disable auto-submit on unfocus on web.
                // onSubmitted: (_) => _createGame(context),
              ),
            ),
            Expanded(child: Container()),
            WideButton(
              onPressed: () => _createGame(context),
              coloring: WideButtonColoring.secondary,
              margin: WideButton.bottomButtonMargin,
              child: Text(context.tr('create_game')),
            ),
          ],
        ),
      ),
    );
  }
}

class JoinGameOnlineScreen extends StatefulWidget {
  static const String routeName = '/join-game-online';

  final gameIDController = CheckedTextFieldController(checker: checkGameID);
  final playerNameController =
      CheckedTextFieldController(checker: checkPlayerName);

  JoinGameOnlineScreen({super.key});

  static JoinGameOnlineScreen? fromRoute(RouteSettings settings) {
    final String? gameID = LocalGameData.parseRoute(settings.name!);
    if (gameID == null) {
      return null;
    }
    final screen = JoinGameOnlineScreen();
    screen.gameIDController.textController.text = gameID;
    return screen;
  }

  @override
  State<StatefulWidget> createState() => JoinGameOnlineScreenState();
}

class JoinGameOnlineScreenState extends State<JoinGameOnlineScreen> {
  LocalStorage get localStorage => LocalStorage.instance;
  CheckedTextFieldController get gameIDController => widget.gameIDController;
  CheckedTextFieldController get playerNameController =>
      widget.playerNameController;
  bool navigatedToGame = false;

  Future<bool> confirmReconnect(
      {required String playerName, required bool gameStarted}) {
    return multipleChoiceDialog<bool>(
      context: context,
      contentText: gameStarted
          ? context.tr('reconnect_as', namedArgs: {'name': playerName})
          : context.tr('player_exists_confirm_reconnect',
              namedArgs: {'name': playerName}),
      choices: [
        DialogChoice(false, context.tr('cancel')),
        DialogChoice(true, context.tr('reconnect')),
      ],
      defaultChoice: false,
    );
  }

  Future<void> _joinGame(BuildContext context) async {
    if (navigatedToGame) {
      return;
    }
    if (!checkTextFields([
      gameIDController,
      playerNameController,
    ])) {
      return;
    }
    final String playerName = playerNameController.textController.text;
    JoinGameResult joinGameResult;
    try {
      joinGameResult = await GameController.joinLobby(
          FirebaseFirestore.instance,
          playerName,
          gameIDController.textController.text);
    } on InvalidOperation catch (e) {
      if (context.mounted) {
        showInvalidOperationDialog(context: context, error: e);
      }
      if (e.tag<JoinGameErrorSource>() == JoinGameErrorSource.playerName) {
        playerNameController.focusNode.requestFocus();
      } else {
        gameIDController.focusNode.requestFocus();
      }
      return;
    }

    navigateToGame() {
      navigatedToGame = true;
      return GameNavigator.navigateToGame(
          context: context, localGameData: joinGameResult.localGameData);
    }

    switch (joinGameResult.reconnection) {
      case Reconnection.connectForTheFirstTime:
        await navigateToGame();
        break;
      case Reconnection.reconnectBeforeGame:
        final bool reconnectConfirmed =
            await confirmReconnect(playerName: playerName, gameStarted: false);
        if (reconnectConfirmed) {
          await navigateToGame();
        }
        break;
      case Reconnection.reconnectDuringName:
        final bool reconnectConfirmed =
            await confirmReconnect(playerName: playerName, gameStarted: true);
        if (reconnectConfirmed) {
          await navigateToGame();
        }
        break;
    }
  }

  @override
  void initState() {
    playerNameController.textController.text =
        localStorage.get<String?>(LocalColPlayerName()) ?? '';
    playerNameController.textController.addListener(() {
      localStorage.set(
          LocalColPlayerName(), playerNameController.textController.text);
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    if (gameIDController.textController.text.isEmpty) {
      gameIDController.focusNode.requestFocus();
    } else {
      playerNameController.focusNode.requestFocus();
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    playerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      appBar: AppBar(
        title: Text(context.tr('join_game_online')),
      ),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
              child: Column(
                // TODO: Field order?
                children: [
                  CheckedTextField(
                    textInputAction: TextInputAction.next,
                    labelText: context.tr('game_id'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[.0-9]+'))
                    ],
                    controller: gameIDController,
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  CheckedTextField(
                    textInputAction: TextInputAction.go,
                    labelText: context.tr('your_name'),
                    controller: playerNameController,
                    // TODO: Uncomment; disable auto-submit on unfocus on web.
                    // onSubmitted: (_) => _joinGame(context),
                  ),
                ],
              ),
            ),
            Expanded(child: Container()),
            WideButton(
              onPressed: () => _joinGame(context),
              coloring: WideButtonColoring.secondary,
              margin: WideButton.bottomButtonMargin,
              child: Text(context.tr('join_game')),
            ),
          ],
        ),
      ),
    );
  }
}

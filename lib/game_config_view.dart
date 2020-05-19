import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hatgame/built_value/game_config.dart';
import 'package:hatgame/game_config_controller.dart';
import 'package:hatgame/game_controller.dart';
import 'package:hatgame/game_data.dart';
import 'package:hatgame/game_view.dart';
import 'package:hatgame/kicked_screen.dart';
import 'package:hatgame/offline_player_config_view.dart';
import 'package:hatgame/online_player_config_view.dart';
import 'package:hatgame/partying_strategy.dart';
import 'package:hatgame/rules_config_view.dart';
import 'package:hatgame/start_game_online_screen.dart';
import 'package:hatgame/teaming_config_view.dart';
import 'package:hatgame/theme.dart';
import 'package:hatgame/util/assertion.dart';
import 'package:hatgame/util/invalid_operation.dart';
import 'package:hatgame/widget/async_snapshot_error.dart';
import 'package:hatgame/widget/invalid_operation_dialog.dart';
import 'package:hatgame/widget/sections_scaffold.dart';
import 'package:hatgame/widget/wide_button.dart';
import 'package:outline_material_icons/outline_material_icons.dart';

// TODO: 'Revert to default' button.

class GameConfigView extends StatefulWidget {
  static const String routeName = '/game-config';

  final GameConfigController configController;
  final LocalGameData localGameData;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  GameConfigView({@required this.localGameData})
      : configController = GameConfigController.fromDB(localGameData);

  @override
  createState() => _GameConfigViewState();
}

class _GameConfigViewState extends State<GameConfigView>
    with SingleTickerProviderStateMixin {
  // TODO: Consider: change 'Start Game' button to:
  //   - advance to the next screen unless on the last screen alreay; OR
  //   - move to player tab if players empty or incorrect
  //     - this can be half-official, e.g. the button would be disabled and
  //       display a warning, but still change the tab.
  // (Are there best practices?)

  SectionTitleData rulesSectionTitle() => SectionTitleData(
        text: 'Rules',
        icon: Icon(Icons.settings),
      );
  SectionTitleData teamingSectionTitle() => SectionTitleData(
        text: 'Teaming',
        // TODO: Add arrows / several groups of people / gearwheel.
        icon: Icon(Icons.people),
      );
  SectionTitleData playersSectionTitle(int numPlayers) => SectionTitleData(
        text: 'Players: $numPlayers',
        // TODO: Replace squares with person icons.
        icon: Icon(OMIcons.ballot),
      );

  static const int rulesTabIndex = 0;
  static const int teamingTabIndex = 1;
  static const int playersTabIndex = 2;
  static const int numTabs = 3;

  LocalGameData get localGameData => widget.localGameData;
  GameConfigController get configController => widget.configController;
  bool get isAdmin => localGameData.isAdmin;
  bool _navigatedToKicked = false;
  bool _navigatedToGame = false;

  TabController _tabController;
  final _rulesConfigViewController = RulesConfigViewController();

  @override
  void initState() {
    _tabController = TabController(vsync: this, length: numTabs);
    _tabController.addListener(() {
      // Hide virtual keyboard
      FocusScope.of(context).unfocus();
    });
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rulesConfigViewController.dispose();
    super.dispose();
  }

  void _getJoinLink(GlobalKey<ScaffoldState> scaffoldKey) {
    final String link = JoinGameOnlineScreen.makeLink(localGameData.gameID);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Game join link'),
          content: Row(
            children: [
              Expanded(
                child: Text(link),
              ),
              IconButton(
                icon: Icon(Icons.content_copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link)).then((_) {
                    scaffoldKey.currentState.showSnackBar(
                        SnackBar(content: Text('Link copied to clipboard')));
                  }, onError: (error) {
                    // TODO: Log to firebase.
                    debugPrint('Cannot copy to clipboard. Error: $error');
                    scaffoldKey.currentState.showSnackBar(SnackBar(
                        content: Text('Cannot copy link to clipboard :(')));
                  });
                },
              ),
            ],
          ),
          actions: [
            FlatButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _goToKicked() {
    // Hide virtual keyboard
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => KickedScreen(),
          settings: RouteSettings(name: KickedScreen.routeName),
        ),
        ModalRoute.withName('/'));
  }

  void _startGame(GameConfig gameConfig) {
    try {
      GameController.startGame(localGameData.gameReference, gameConfig);
    } on InvalidOperation catch (e) {
      showInvalidOperationDialog(context: context, error: e);
      _tabController.animateTo(playersTabIndex);
      return;
    }
  }

  void _goToGame() {
    // Hide virtual keyboard
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => GameView(
            localGameData: localGameData,
          ),
          settings: RouteSettings(name: GameView.routeName),
        ),
        ModalRoute.withName('/'));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameConfigPlus>(
      stream: configController.stateUpdatesStream,
      builder: (BuildContext context, AsyncSnapshot<GameConfigPlus> snapshot) {
        if (snapshot.hasError) {
          return AsyncSnapshotError(snapshot, dataName: 'game config');
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final GameConfigPlus gameConfigPlus = snapshot.data;
        if (gameConfigPlus.kicked) {
          // Cannot navigate from within `build`.
          if (!_navigatedToKicked) {
            Future(_goToKicked);
            _navigatedToKicked = true;
          }
          return Center(child: CircularProgressIndicator());
        }
        if (gameConfigPlus.gameHasStarted) {
          // Cannot navigate from within `build`.
          if (!_navigatedToGame) {
            Future(_goToGame);
            _navigatedToGame = true;
          }
          return Center(child: CircularProgressIndicator());
        }
        final GameConfig gameConfig = gameConfigPlus.config;
        Assert.holds(gameConfig != null);

        _rulesConfigViewController.updateFromConfig(gameConfig.rules);
        final sections = [
          SectionData(
            title: rulesSectionTitle(),
            body: RulesConfigView(
              viewController: _rulesConfigViewController,
              configController: configController,
            ),
          ),
          SectionData(
            title: teamingSectionTitle(),
            body: TeamingConfigView(
              onlineMode: localGameData.onlineMode,
              config: gameConfig.teaming,
              configController: configController,
            ),
          ),
          SectionData(
            title: playersSectionTitle(gameConfig.players.names.length),
            body: localGameData.onlineMode
                ? OnlinePlayersConfigView(
                    localGameData: localGameData,
                    playersConfig: gameConfig.players,
                  )
                : OfflinePlayersConfigView(
                    teamingConfig: gameConfig.teaming,
                    initialPlayersConfig: gameConfig.players,
                    configController: configController,
                  ),
          ),
        ];
        final startButton = WideButton(
          onPressed: isAdmin ? () => _startGame(gameConfig) : null,
          onPressedDisabled: () {
            final snackBar =
                SnackBar(content: Text('Only the host can start the game.'));
            Scaffold.of(context).showSnackBar(snackBar);
          },
          color: MyTheme.accent,
          child: Text('Start Game'),
          margin: WideButton.bottomButtonMargin,
        );

        return SectionsScaffold(
          scaffoldKey: widget.scaffoldKey,
          appBarAutomaticallyImplyLeading: false,
          appTitle: localGameData.onlineMode
              ? 'Hat Game ID: ${localGameData.gameID}'
              : 'Hat Game',
          appTitlePresentInNarrowMode: localGameData.onlineMode,
          actions: localGameData.onlineMode
              ? [
                  IconButton(
                    icon: Icon(Icons.link),
                    onPressed: () => _getJoinLink(widget.scaffoldKey),
                  )
                ]
              : [],
          sections: sections,
          tabController: _tabController,
          bottomWidget: startButton,
        );
      },
    );
  }
}

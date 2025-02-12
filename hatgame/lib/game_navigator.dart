import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hatgame/built_value/game_phase.dart';
import 'package:hatgame/built_value/game_state.dart';
import 'package:hatgame/db/db_document.dart';
import 'package:hatgame/game_config_view.dart';
import 'package:hatgame/game_controller.dart';
import 'package:hatgame/game_data.dart';
import 'package:hatgame/game_phase_reader.dart';
import 'package:hatgame/game_view.dart';
import 'package:hatgame/kicked_screen.dart';
import 'package:hatgame/score_view.dart';
import 'package:hatgame/team_compositions_view.dart';
import 'package:hatgame/util/assertion.dart';
import 'package:hatgame/widget/async_snapshot_error.dart';
import 'package:hatgame/widget/dialog.dart';
import 'package:hatgame/write_words_view.dart';

class RouteArguments {
  final GamePhase phase;

  RouteArguments({required this.phase});
}

// OPTIMIZATION POTENTIAL: This class might be simplified when Navigator 2.0
//   is out: https://github.com/flutter/flutter/issues/45938.
// TODO: Consider setting maintainState == false.
// TODO: Is it ok that GameNavigator smuggles state into StalelessWidget?
//   May be GameNavigator should be a mixin on top of StatefulWidget.
class GameNavigator {
  final GamePhase currentPhase;

  GameNavigator({
    required this.currentPhase,
  });

  // TODO: Disable bonus turn timer after reconnect.
  static Future<void> navigateToGame({
    required BuildContext context,
    required LocalGameData localGameData,
  }) async {
    final snapshot = await localGameData.gameReference.get();
    final gamePhase = GamePhaseReader.fromSnapshot(localGameData, snapshot);
    if (context.mounted) {
      _navigateTo(
        context: context,
        localGameData: localGameData,
        snapshot: snapshot,
        oldPhase: null,
        newPhase: gamePhase,
      );
    }
  }

  Widget buildWrapper({
    required BuildContext context,
    required LocalGameData localGameData,
    required Widget Function(BuildContext, DBDocumentSnapshot) buildBody,
  }) {
    return StreamBuilder<DBDocumentSnapshot>(
      stream: localGameData.gameReference.snapshots(),
      builder:
          (BuildContext context, AsyncSnapshot<DBDocumentSnapshot> snapshot) {
        if (snapshot.hasError) {
          return AsyncSnapshotError(snapshot, gamePhase: currentPhase);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final snapshotData = snapshot.data!;
        final newPhase =
            GamePhaseReader.fromSnapshot(localGameData, snapshotData);
        if (newPhase != currentPhase) {
          if (newPhase != localGameData.navigationState.lastSeenGamePhase &&
              !localGameData.navigationState.exitingGame) {
            _navigateTo(
              context: context,
              localGameData: localGameData,
              snapshot: snapshotData,
              oldPhase: currentPhase,
              newPhase: newPhase,
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        Assert.eq(newPhase, currentPhase);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop) {
              return;
            }
            await _onPop(context,
                localGameData: localGameData, snapshot: snapshotData);
          },
          child: buildBody(context, snapshotData),
        );
      },
    );
  }

  // TODO: Remove or fix how it looks. Don't show loading indicator when
  //   loading is very fast. Idea: prefetch the first state for half-second
  //   and start navigation afterwards; show a screenshot meanwhile or show
  //   widgets based on the latest state for the current phase and block
  //   interactions.
  /*
  void setNavigationExpected() {
    Assert.eq(_navigationState, _GameNavigationState.none);
    _navigationState = _GameNavigationState.expected;
  }
  */

  static void _navigateTo({
    required BuildContext context,
    required LocalGameData localGameData,
    required DBDocumentSnapshot snapshot,
    required GamePhase? oldPhase,
    required GamePhase newPhase,
  }) {
    localGameData.navigationState.lastSeenGamePhase = newPhase;
    localGameData.gameReference.clearLocalCache();
    if (newPhase == GamePhase.rematch) {
      localGameData.navigationState.exitingGame = true;
      final LocalGameData newLocalGameData =
          GameController.joinRematch(localGameData, snapshot);
      // Use `Future` because it's not allowed to navigate from `build`.
      Future(() =>
          navigateToGame(context: context, localGameData: newLocalGameData));
      return;
    }
    // Use `Future` because it's not allowed to navigate from `build`.
    Future(() => _navigateToImpl(
          context: context,
          localGameData: localGameData,
          snapshot: snapshot,
          oldPhase: oldPhase,
          newPhase: newPhase,
        ));
  }

  // TODO: Seems like `snapshot` is not needed from here down.
  static void _navigateToImpl({
    required BuildContext context,
    required LocalGameData localGameData,
    required DBDocumentSnapshot snapshot,
    required GamePhase? oldPhase,
    required GamePhase newPhase,
  }) {
    // Hide virtual keyboard
    FocusScope.of(context).unfocus();
    if (_isGrandparentPhase(newPhase, oldPhase)) {
      // Note: does not trigger `onWillPop`.
      Navigator.of(context).popUntil((route) =>
          (route.settings.arguments as RouteArguments).phase == newPhase);
    } else {
      GamePhase? pushFrom;
      if (_isGrandparentPhase(oldPhase, newPhase)) {
        // TODO: Also `pushAndRemoveUntil` in case there was a subscreen
        pushFrom = oldPhase;
      } else {
        pushFrom = _firstGrandparentPhase(newPhase);
        final route = _route(
          localGameData: localGameData,
          snapshot: snapshot,
          phase: pushFrom,
        );
        Navigator.of(context).pushAndRemoveUntil(
          route,
          ModalRoute.withName('/'),
        );
      }
      _pushPhases(
        context: context,
        localGameData: localGameData,
        snapshot: snapshot,
        fromPhase: pushFrom!,
        toPhase: newPhase,
      );
    }
  }

  static void _pushPhases({
    required BuildContext context,
    required LocalGameData localGameData,
    required DBDocumentSnapshot snapshot,
    required GamePhase fromPhase, // non-inclusive
    required GamePhase toPhase, // inclusive
  }) {
    if (fromPhase != toPhase) {
      _pushPhases(
        context: context,
        localGameData: localGameData,
        snapshot: snapshot,
        fromPhase: fromPhase,
        toPhase: _parentPhase(toPhase)!,
      );
    }
    _pushPhase(
      context: context,
      localGameData: localGameData,
      snapshot: snapshot,
      phase: toPhase,
    );
  }

  static void _pushPhase({
    required BuildContext context,
    required LocalGameData localGameData,
    required DBDocumentSnapshot snapshot,
    required GamePhase phase,
  }) {
    final route = _route(
      localGameData: localGameData,
      snapshot: snapshot,
      phase: phase,
    );
    Navigator.of(context).push(route);
  }

  static MaterialPageRoute<void> _route({
    required LocalGameData localGameData,
    required DBDocumentSnapshot snapshot,
    required GamePhase phase,
  }) {
    final routeSettings = RouteSettings(
      name: localGameData.gameRoute,
      arguments: RouteArguments(phase: phase),
    );
    switch (phase) {
      case GamePhase.configure:
        return MaterialPageRoute(
          builder: (context) => GameConfigView(localGameData: localGameData),
          settings: routeSettings,
        );
      case GamePhase.writeWords:
        return MaterialPageRoute(
          builder: (context) => WriteWordsView(localGameData: localGameData),
          settings: routeSettings,
        );
      case GamePhase.composeTeams:
        return MaterialPageRoute(
          builder: (context) =>
              TeamCompositionsView(localGameData: localGameData),
          settings: routeSettings,
        );
      case GamePhase.play:
        return MaterialPageRoute(
          builder: (context) => GameView(localGameData: localGameData),
          settings: routeSettings,
        );
      case GamePhase.gameOver:
        return MaterialPageRoute(
          builder: (context) => ScoreView(localGameData: localGameData),
          settings: routeSettings,
        );
      case GamePhase.kicked:
        return MaterialPageRoute(
          builder: (context) => const KickedScreen(),
          settings: routeSettings,
        );
      case GamePhase.rematch:
        Assert.fail('There is no route for GamePhase.rematch');
    }
    Assert.unexpectedValue(phase);
  }

  static GamePhase _firstGrandparentPhase(GamePhase phase) {
    final parent = _parentPhase(phase);
    return parent != null ? _firstGrandparentPhase(parent) : phase;
  }

  static bool _isGrandparentPhase(GamePhase? phaseA, GamePhase? phaseB) {
    if (phaseA == null || phaseB == null) {
      return false;
    }
    final phaseBParent = _parentPhase(phaseB);
    return phaseBParent == phaseA
        ? true
        : _isGrandparentPhase(phaseA, phaseBParent);
  }

  static GamePhase? _parentPhase(GamePhase phase) {
    return switch (phase) {
      GamePhase.configure => null,
      GamePhase.writeWords => GamePhase.configure,
      GamePhase.composeTeams =>
        GamePhase.configure, // TODO: Should we go back to writeWords?
      GamePhase.play => null,
      GamePhase.gameOver => null,
      GamePhase.kicked => null,
      GamePhase.rematch => null,
      _ => Assert.unexpectedValue(phase),
    };
  }

  static void leaveGame(
    BuildContext context, {
    required LocalGameData localGameData,
  }) {
    localGameData.navigationState.exitingGame = true;
    if (context.mounted) {
      Navigator.of(context).popUntil(ModalRoute.withName('/'));
    }
  }

  static Future<void> leaveGameWithConfirmation(
    BuildContext context, {
    required LocalGameData localGameData,
  }) async {
    // TODO: Replace with a description of how to continue when it's
    // possible to continue.
    final leave = await multipleChoiceDialog(
      context: context,
      titleText: context.tr('leave_game'),
      contentText: localGameData.onlineMode
          ? '${context.tr('reconnect_link_hint')}\n${localGameData.gameUrl}'
          : "You wouldn't be able to continue (this is not implemented yet)",
      choices: [
        DialogChoice(false, context.tr('stay')),
        DialogChoice(true, context.tr('leave')),
      ],
      defaultChoice: false,
    );
    if (leave) {
      leaveGame(context, localGameData: localGameData);
    }
  }

  Future<void> _onPop(
    BuildContext context, {
    required LocalGameData localGameData,
    required DBDocumentSnapshot snapshot,
  }) async {
    switch (currentPhase) {
      case GamePhase.configure:
        return localGameData.isAdmin
            ? leaveGame(context, localGameData: localGameData)
            : leaveGameWithConfirmation(context, localGameData: localGameData);
      case GamePhase.composeTeams:
        return localGameData.isAdmin
            ? GameController.discardTeamCompositions(
                localGameData.gameReference)
            : leaveGameWithConfirmation(context, localGameData: localGameData);
      case GamePhase.writeWords:
        return localGameData.isAdmin
            ? GameController.backFromWordWritingPhase(
                localGameData.gameReference)
            : leaveGameWithConfirmation(context, localGameData: localGameData);
      case GamePhase.play:
        final gameController =
            GameController.fromSnapshot(localGameData, snapshot);
        if (gameController.turnState!.turnPhase == TurnPhase.prepare) {
          if (gameController.turnIndex > 0) {
            gameController.backToRereview();
          } else {
            leaveGameWithConfirmation(context, localGameData: localGameData);
          }
        }
        return;
      case GamePhase.gameOver:
      case GamePhase.kicked:
      case GamePhase.rematch:
        return leaveGame(context, localGameData: localGameData);
    }
    Assert.unexpectedValue(currentPhase);
  }
}

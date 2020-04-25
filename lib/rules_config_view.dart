import 'package:flutter/material.dart';
import 'package:hatgame/built_value/game_config.dart';
import 'package:hatgame/game_config_controller.dart';
import 'package:hatgame/numeric_field.dart';

class RulesConfigView extends StatefulWidget {
  final RulesConfig config;
  final GameConfigController configController;

  RulesConfigView({@required this.config, @required this.configController});

  @override
  State<StatefulWidget> createState() => RulesConfigViewState();
}

class RulesConfigViewState extends State<RulesConfigView> {
  static const List<int> turnTimeGoldenValues = [
    10,
    15,
    20,
    25,
    30,
    40,
    50,
    60,
    90,
    120,
    150,
    180,
    240,
    300,
  ];

  static const List<int> bonusTimeGoldenValues = [
    0,
    3,
    5,
    7,
    10,
    15,
    20,
    25,
    30,
    40,
    50,
    60,
    90,
  ];

  final _turnTimeController = TextEditingController();
  final _bonusTimeController = TextEditingController();

  RulesConfig get config => widget.config;
  GameConfigController get configController => widget.configController;

  @override
  void initState() {
    super.initState();

    _turnTimeController.text = config.turnSeconds.toString();
    _turnTimeController.addListener(() => configController.updateRules(
          config.rebuild(
              (b) => b..turnSeconds = int.tryParse(_turnTimeController.text)),
        ));

    _bonusTimeController.text = config.bonusSeconds.toString();
    _bonusTimeController.addListener(() => configController.updateRules(
          config.rebuild(
              (b) => b..bonusSeconds = int.tryParse(_bonusTimeController.text)),
        ));
  }

  @override
  void dispose() {
    _turnTimeController.dispose();
    _bonusTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: 4),
        ListTile(
          title: Row(
            children: [
              Expanded(
                child: Text('Turn time'),
              ),
              NumericField(
                controller: _turnTimeController,
                goldenValues: turnTimeGoldenValues,
              ),
            ],
          ),
        ),
        ListTile(
          title: Row(
            children: [
              Expanded(
                child: Text('Bonus time'),
              ),
              NumericField(
                controller: _bonusTimeController,
                goldenValues: bonusTimeGoldenValues,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

library serializers;

import 'package:built_collection/built_collection.dart';
import 'package:built_value/serializer.dart';
import 'package:hatgame/built_value/game_config.dart';
import 'package:hatgame/built_value/game_phase.dart';
import 'package:hatgame/built_value/game_state.dart';
import 'package:hatgame/built_value/personal_state.dart';
import 'package:hatgame/built_value/rematch_source.dart';
import 'package:hatgame/built_value/team_compositions.dart';
import 'package:hatgame/built_value/word.dart';

part 'serializers.g.dart';

@SerializersFor([
  GameConfig,
  GamePhase,
  TeamCompositions,
  InitialGameState,
  TurnRecord,
  TurnState,
  PersonalState,
  RematchSource,
])
final Serializers serializers = _$serializers;

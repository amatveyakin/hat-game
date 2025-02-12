import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hatgame/app_version.dart';
import 'package:hatgame/rules_screen.dart';
import 'package:hatgame/util/markdown.dart';
import 'package:hatgame/widget/constrained_scaffold.dart';

class AboutScreen extends StatelessWidget {
  static const String routeName = '/about';
  static const String supportEmail = 'contact.hatgame@gmail.com';

  // TODO: Include technical info (app version, device) in support email body.
  // TODO: Add links to web version, Play Store and App Store.
  // TODO: tr
  static const String content = '''
## What is this?

This app allows to play the hat game offline or online.

Hat is a Russian word-based party game. You can learn more about the rules
in [“Hat game rules”](internal:${RulesScreen.routeName}).


## Contact

Author: Andrei Matveiakin

For questions email [$supportEmail](mailto:$supportEmail)


## Technical information

App version: $appVersion

The app is written in Flutter.
''';

  const AboutScreen({super.key});

  // TODO: Add: acknowledgments:
  //
  // Russian:
  // О. Н. Ляшевская, С. А. Шаров, Частотный словарь современного русского языка
  // (на материалах Национального корпуса русского языка). М.: Азбуковник, 2009.
  //
  // English:
  //   - https://wordnet.princeton.edu/
  //   - https://github.com/first20hours/google-10000-english

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      appBar: AppBar(
        title: Text(context.tr('about_hat_game')),
      ),
      body: Markdown(
        data: content,
        styleSheet: MarkdownUtil.defaultStyle(context),
        onTapLink: (text, href, title) =>
            MarkdownUtil.onLinkTapped(context, href!),
      ),
    );
  }
}

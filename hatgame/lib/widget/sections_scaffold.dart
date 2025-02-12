import 'package:flutter/material.dart';
import 'package:hatgame/theme.dart';
import 'package:hatgame/util/assertion.dart';
import 'package:hatgame/widget/constrained_scaffold.dart';

const double _minBoxWidth = 360;
const double _maxBoxWidth = 480;
const double _boxMargin = 16;

double _minWideLayoutWidth(int numSections) =>
    (_minBoxWidth + 2 * _boxMargin) * numSections;
double _maxWideLayoutWidth(int numSections) =>
    (_maxBoxWidth + 2 * _boxMargin) * numSections;

class SectionTitleData {
  final Widget icon;

  SectionTitleData({required this.icon});
}

class SectionData {
  final SectionTitleData title;
  final Widget body;

  SectionData({required this.title, required this.body});
}

class SectionsScaffold extends StatelessWidget {
  final Key? scaffoldKey;
  final bool appBarAutomaticallyImplyLeading;
  final String appTitle;
  final bool appTitlePresentInNarrowMode;
  final bool wideLayout;
  final List<SectionData> sections;
  final List<Widget>? actions;
  final TabController? tabController;
  final Widget? bottomWidget;

  static bool useWideLayout(BuildContext context, int numSections) =>
      MediaQuery.of(context).size.width >= _minWideLayoutWidth(numSections);

  SectionsScaffold({
    super.key,
    this.scaffoldKey,
    required this.appBarAutomaticallyImplyLeading,
    required this.appTitle,
    required this.appTitlePresentInNarrowMode,
    required this.wideLayout,
    required this.sections,
    this.actions,
    this.tabController,
    this.bottomWidget,
  }) {
    if (appBarAutomaticallyImplyLeading) {
      Assert.holds(appTitlePresentInNarrowMode);
    }
    if (actions?.isNotEmpty ?? false) {
      Assert.holds(appTitlePresentInNarrowMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!wideLayout) {
      // One-column view for phones and tablets in portrait mode.
      // TODO: Automatically increase padding on large screens.
      final tabBar = TabBar(
        controller: tabController,
        labelColor: MyTheme.onPrimary,
        unselectedLabelColor: MyTheme.onPrimary.withAlpha(0xb0),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: sections
            .map((s) => Tab(
                  icon: s.title.icon,
                ))
            .toList(),
      );
      final scaffold = ConstrainedScaffold(
        scaffoldKey: scaffoldKey,
        resizeToAvoidBottomInset: false,
        appBar: appTitlePresentInNarrowMode
            ? AppBar(
                automaticallyImplyLeading: appBarAutomaticallyImplyLeading,
                title: Text(appTitle),
                actions: actions,
                // For some reason PreferredSize affects not only the bottom of
                // the AppBar but also the title, making it misaligned with the
                // normal title text position. Hopefully this is not too
                // noticeable. Without PreferredSize the AppBar is just too fat.
                bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(48.0), child: tabBar),
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(48.0),
                child: AppBar(
                  automaticallyImplyLeading: appBarAutomaticallyImplyLeading,
                  flexibleSpace: SafeArea(child: tabBar),
                ),
              ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: sections.map((s) => s.body).toList(),
              ),
            ),
            if (bottomWidget != null) bottomWidget!,
          ],
        ),
      );
      return tabController != null
          ? scaffold
          : DefaultTabController(
              length: sections.length,
              child: scaffold,
            );
    } else {
      // Multi-column view for tablets in landscape mode and desktops.
      final List<Widget> boxes = [];
      for (int i = 0; i < sections.length; i++) {
        boxes.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(_boxMargin),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: MyTheme.primary,
                      padding: const EdgeInsets.all(16.0),
                      child: IconTheme(
                        data: Theme.of(context).primaryIconTheme,
                        child: sections[i].title.icon,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: sections[i].body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return Scaffold(
        key: scaffoldKey,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          automaticallyImplyLeading: appBarAutomaticallyImplyLeading,
          title: Text(appTitle),
          actions: actions,
        ),
        body: Center(
          child: Column(
            children: [
              Expanded(
                child: SizedBox(
                  width: _maxWideLayoutWidth(sections.length),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: boxes,
                  ),
                ),
              ),
              if (bottomWidget != null)
                SizedBox(
                  width: ConstrainedScaffold.defaultWidth,
                  child: bottomWidget,
                ),
            ],
          ),
        ),
      );
    }
  }
}

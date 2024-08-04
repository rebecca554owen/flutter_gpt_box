part of 'home.dart';

final class _Drawer extends StatelessWidget {
  const _Drawer();

  static List<Widget> getEntries(BuildContext context) => [
        ListTile(
          onTap: () async {
            final ret = await Routes.setting.go(context);
            if (ret?.rebuild == true) {
              Scaffold.maybeOf(context)?.closeDrawer();
            }
          },
          onLongPress: () => _onLongTapSetting(context),
          leading: const Icon(Icons.settings),
          title: Text(libL10n.setting),
        ).cardx,
        ListTile(
          onTap: () => Routes.profile.go(context),
          leading: const Icon(Icons.person),
          title: Text(l10n.profile),
        ).cardx,
        ListTile(
          leading: const Icon(MingCute.tool_fill),
          title: Text(l10n.tool),
          onTap: () => Routes.tool.go(context),
        ).cardx,
        ListTile(
          onTap: () async {
            final ret = await Routes.backup.go(context);

            if (ret?.isRestoreSuc == true) {
              Scaffold.maybeOf(context)?.closeDrawer();
              HomePage.afterRestore();
            }
          },
          leading: const Icon(Icons.backup),
          title: Text(libL10n.backup),
        ).cardx,
        ListTile(
          leading: const Icon(BoxIcons.bxs_videos),
          title: Text(l10n.res),
          onTap: () => Routes.res.go(context),
        ).cardx,
        ListTile(
          onTap: () => Routes.about.go(context),
          leading: const Icon(Icons.info),
          title: Text(libL10n.about),
        ).cardx,
      ];

  @override
  Widget build(BuildContext context) {
    return RNodes.dark.listenVal(
      (isDark) {
        return LayoutBuilder(
          builder: (context, cons) {
            final verticalPad = ((cons.maxHeight - 600) / 2).abs();
            return Container(
              width: _isWide.value ? 270 : (_media?.size.width ?? 300) * 0.7,
              color: UIs.bgColor.fromBool(isDark),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                // Disable overscroll glow on iOS
                physics: const ClampingScrollPhysics(),
                children: [
                  SizedBox(height: verticalPad),
                  SizedBox(
                    height: 47,
                    width: 47,
                    child: UIs.appIcon,
                  ),
                  UIs.height13,
                  const Text(
                    'GPT Box\nv1.0.${Build.build}',
                    textAlign: TextAlign.center,
                  ),
                  UIs.height77,
                  ...getEntries(context),
                  SizedBox(height: verticalPad),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

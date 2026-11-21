import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'firebase_options_web.dart';
import 'admin.dart';

const Color bgColor = Color(0xFF080D18);
const Color cardColor = Color(0xFF111B2B);
const Color cardLight = Color(0xFF172438);
const Color greenColor = Color(0xFF19D69B);
const Color cyanColor = Color(0xFF36C5F0);
const Color purpleColor = Color(0xFF9B7BFF);
const Color mutedColor = Color(0xFF91A0B5);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: kIsWeb
        ? WebFirebaseOptions.currentPlatform
        : DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const FootballAnalyticsApp());
}


class FootballAnalyticsApp extends StatelessWidget {
  const FootballAnalyticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Football Analytics BI',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: greenColor,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const DashboardPage(),
    );
  }
}

// ======================================================
// PLAYER MODEL
// ======================================================

class Player {
  final int id;
  final String name;
  final String nation;
  final String position;
  final String league;
  final String team;
  final double? age;
  final double? matches;
  final double? starts;
  final double? goals;
  final double? assists;
  final double? yellowCards;
  final double? redCards;
  final double? xG;
  final double? goalsAssistsPerMatch;

  Player({
    required this.id,
    required this.name,
    required this.nation,
    required this.position,
    required this.league,
    required this.team,
    this.age,
    this.matches,
    this.starts,
    this.goals,
    this.assists,
    this.yellowCards,
    this.redCards,
    this.xG,
    this.goalsAssistsPerMatch,
  });

  factory Player.fromCsv(List<dynamic> row, Map<String, int> columns) {
    String? textValue(String key) {
      final index = columns[key];
      if (index == null || index >= row.length) return null;

      final value = row[index]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    double? number(String key) {
      final value = textValue(key);
      if (value == null) return null;
      return double.tryParse(value.replaceAll(',', '.'));
    }

    return Player(
      id: number('id_joueur')?.toInt() ?? 0,
      name: textValue('Player') ?? 'Unknown',
      nation: textValue('Nation') ?? 'N/A',
      position: textValue('Pos') ?? 'N/A',
      league: textValue('nom_ligue') ?? 'N/A',
      team: textValue('nom_equipe') ?? 'N/A',
      age: number('Age'),
      matches: number('MP'),
      starts: number('Playing_Time_Starts'),
      goals: number('Performance_Gls'),
      assists: number('Performance_1_Ast'),
      yellowCards: number('Performance_6_CrdY'),
      redCards: number('Performance_7_CrdR'),
      xG: number('Expected_xG'),
      goalsAssistsPerMatch: number('Avg_Performance_GA'),
    );
  }

  double get efficiency {
    if (goals == null || xG == null) return 0;
    return goals! - xG!;
  }

  double get totalCards => (yellowCards ?? 0) + (redCards ?? 0);
}

// ======================================================
// DASHBOARD
// ======================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;

  final List<String> menuItems = [
    'Dashboard',
    'Players',
    'Compare',
    'Rankings',
    'Profile',
  ];

  final List<IconData> menuIcons = [
    Icons.dashboard_rounded,
    Icons.groups_rounded,
    Icons.compare_arrows_rounded,
    Icons.leaderboard_rounded,
    Icons.person_rounded,
  ];

  late Future<List<Player>> playersFuture;

  @override
  void initState() {
    super.initState();
    playersFuture = loadPlayers();
  }

  Future<List<Player>> loadPlayers() async {
    final content = await rootBundle.loadString('assets/fixedBI.csv');

    final rows = const CsvToListConverter(
      fieldDelimiter: ';',
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(content);

    if (rows.isEmpty) return [];

    final headers = rows.first.map((value) => value.toString().trim()).toList();

    final columns = <String, int>{
      for (var i = 0; i < headers.length; i++) headers[i]: i,
    };

    return rows
        .skip(1)
        .where((row) => row.isNotEmpty)
        .map((row) => Player.fromCsv(row, columns))
        .where((player) => player.name != 'Unknown')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF080D18),
                  Color(0xFF0D1726),
                  Color(0xFF080D18),
                ],
              ),
            ),
            child: Row(
              children: [
                if (isDesktop) _buildSidebar(),
                Expanded(
                  
                  child: FutureBuilder<List<Player>>(
                    future: playersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: greenColor,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Data loading error:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final players = snapshot.data ?? [];

                      return _buildMainContent(
                        isDesktop,
                        players,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: isDesktop ? null : _buildBottomNavigation(),
        );
      },
    );
  }

  // SIDEBAR

  Widget _buildSidebar() {
    return Container(
      width: 245,
      decoration: const BoxDecoration(
        color: Color(0xFF0C1422),
        border: Border(
          right: BorderSide(color: Colors.white10),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [greenColor, cyanColor],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: greenColor.withOpacity(0.25),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  color: Color(0xFF07111B),
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'FOOTBALL BI',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 55),
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: mutedColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 17),
          ...List.generate(menuItems.length, _menuItem),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  greenColor.withOpacity(0.13),
                  cyanColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: greenColor.withOpacity(0.2),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.insights_rounded,
                  color: greenColor,
                  size: 25,
                ),
                SizedBox(height: 10),
                Text(
                  'Football Analytics BI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Performance Intelligence',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'VERSION 3.0.0',
            style: TextStyle(
              color: mutedColor,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(int index) {
    final selected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    greenColor.withOpacity(0.19),
                    cyanColor.withOpacity(0.05),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? greenColor.withOpacity(0.22) : Colors.transparent,
          ),
        ),
        child: InkWell(
          onTap: () => setState(() => selectedIndex = index),
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            child: Row(
              children: [
                Icon(
                  menuIcons[index],
                  color: selected ? greenColor : mutedColor,
                  size: 21,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    menuItems[index],
                    style: TextStyle(
                      color: selected ? Colors.white : mutedColor,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: greenColor,
                    size: 12,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // MAIN CONTENT

  Widget _buildMainContent(
    bool isDesktop,
    List<Player> players,
  ) {
    Widget page;

    switch (selectedIndex) {
      case 0:
        page = _buildDashboard(players, isDesktop);
        break;
      case 1:
        page = PlayersPageContent(players: players);
        break;
      case 2:
        page = ComparePageContent(players: players);
        break;
      case 3:
        page = RankingsPageContent(players: players);
        break;
      default:
        page = _buildProfile(players);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 35 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDesktop),
          const SizedBox(height: 35),
          KeyedSubtree(
            key: ValueKey(selectedIndex),
            child: page,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                menuItems[selectedIndex],
                style: TextStyle(
                  fontSize: isDesktop ? 25 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Football performance intelligence',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white10),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white70,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [greenColor, cyanColor, purpleColor],
            ),
          ),
          child: const CircleAvatar(
            radius: 20,
            backgroundColor: cardColor,
            child: Icon(
              Icons.person_rounded,
              color: greenColor,
            ),
          ),
        ),
      ],
    );
  }

  double sumValues(
    List<Player> players,
    double? Function(Player) selector,
  ) {
    return players.fold(
      0,
      (sum, player) => sum + (selector(player) ?? 0),
    );
  }

  double averageValues(
    List<Player> players,
    double? Function(Player) selector,
  ) {
    final values = players.map(selector).whereType<double>().toList();

    if (values.isEmpty) return 0;

    return values.reduce((a, b) => a + b) / values.length;
  }

  // DASHBOARD PAGE

  Widget _buildDashboard(
    List<Player> players,
    bool isDesktop,
  ) {
    final goals = sumValues(players, (p) => p.goals);
    final assists = sumValues(players, (p) => p.assists);
    final starts = sumValues(players, (p) => p.starts);
    final yellow = sumValues(players, (p) => p.yellowCards);
    final red = sumValues(players, (p) => p.redCards);

    final efficiencyPlayers =
        players.where((p) => p.goals != null && p.xG != null).toList();

    final efficiency = efficiencyPlayers.fold<double>(
      0,
      (sum, p) => sum + p.efficiency,
    );

    final averageGoalsAssists =
        averageValues(players, (p) => p.goalsAssistsPerMatch);

    final stats = [
      [
        'Total Goals',
        goals.toStringAsFixed(0),
        Icons.sports_soccer,
        greenColor
      ],
      [
        'Assists',
        assists.toStringAsFixed(0),
        Icons.handshake_outlined,
        cyanColor
      ],
      [
        'G+A / Match',
        averageGoalsAssists.toStringAsFixed(2),
        Icons.speed_rounded,
        purpleColor
      ],
      [
        'Goals - xG',
        efficiency.toStringAsFixed(1),
        Icons.track_changes_rounded,
        cyanColor
      ],
      ['Starts', starts.toStringAsFixed(0), Icons.timer_outlined, greenColor],
      [
        'Yellow / Red',
        '${yellow.toStringAsFixed(0)} / ${red.toStringAsFixed(0)}',
        Icons.style_outlined,
        purpleColor
      ],
    ];

    final topScorers = players.where((p) => p.goals != null).toList()
      ..sort((a, b) => (b.goals ?? 0).compareTo(a.goals ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${players.length} player records loaded from your dataset',
          style: const TextStyle(
            color: mutedColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 27),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 950
                ? 3
                : constraints.maxWidth >= 520
                    ? 2
                    : 1;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 145,
              ),
              itemBuilder: (context, index) {
                final stat = stats[index];

                return AnimatedStatCard(
                  title: stat[0] as String,
                  value: stat[1] as String,
                  icon: stat[2] as IconData,
                  color: stat[3] as Color,
                  index: index,
                );
              },
            );
          },
        ),
        const SizedBox(height: 30),
        _sectionTitle('Top Scorers', 'Best goal scorers in your dataset'),
        const SizedBox(height: 16),
        _buildTopPlayers(topScorers),
        const SizedBox(height: 25),
        _buildDataNote(),
      ],
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: mutedColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTopPlayers(List<Player> players) {
    final top = players.take(5).toList();

    return PremiumPanel(
      child: Column(
        children: [
          if (top.isEmpty)
            const Text(
              'No scoring data available.',
              style: TextStyle(color: mutedColor),
            ),
          ...top.asMap().entries.map((entry) {
            return PlayerRow(
              player: entry.value,
              value: '${entry.value.goals!.toStringAsFixed(0)} goals',
              rank: entry.key + 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDataNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cyanColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: cyanColor.withOpacity(0.17),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: cyanColor,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les totaux utilisent les valeurs disponibles dans le fichier. '
              'Les valeurs manquantes ne sont pas remplacées par zéro.',
              style: TextStyle(
                color: mutedColor,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // PROFILE

  


Widget _buildProfile(List<Player> players) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Profile & Account',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 22),

      PremiumPanel(
        title: 'Administrator Access',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.admin_panel_settings_rounded,
              color: greenColor,
              size: 45,
            ),
            const SizedBox(height: 15),
            const Text(
              'Manage Football Analytics BI',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect as administrator to add, edit and delete '
              'football players using Firebase.',
              style: TextStyle(
                color: mutedColor,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminLoginPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text(
                  'LOGIN AS ADMIN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenColor,
                  foregroundColor: bgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 25),

      PremiumPanel(
        title: 'User Account',
        child: const UserProfileSection(),
      ),
    ],
  );
}




  // MOBILE NAVIGATION

  Widget _buildBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C1422),
        border: Border(
          top: BorderSide(color: Colors.white10),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => setState(() => selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0C1422),
        selectedItemColor: greenColor,
        unselectedItemColor: mutedColor,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: List.generate(
          menuItems.length,
          (index) => BottomNavigationBarItem(
            icon: Icon(menuIcons[index]),
            label: menuItems[index],
          ),
        ),
      ),
    );
  }
}

// ======================================================
// ANIMATED STATISTICS CARD
// ======================================================

class AnimatedStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final int index;

  const AnimatedStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.index,
  });

  @override
  State<AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<AnimatedStatCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 450 + widget.index * 100),
        curve: Curves.easeOutCubic,
        builder: (context, animation, child) {
          return Opacity(
            opacity: animation,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - animation)),
              child: child,
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          transform: Matrix4.translationValues(
            0,
            hovered ? -5 : 0,
            0,
          ),
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardLight,
                cardColor,
                widget.color.withOpacity(0.045),
              ],
            ),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: hovered
                  ? widget.color.withOpacity(0.55)
                  : Colors.white.withOpacity(0.07),
            ),
            boxShadow: [
              BoxShadow(
                color: hovered
                    ? widget.color.withOpacity(0.13)
                    : Colors.black.withOpacity(0.15),
                blurRadius: hovered ? 24 : 12,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                widget.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 3,
                width: 45,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================
// REUSABLE PANEL
// ======================================================

class PremiumPanel extends StatelessWidget {
  final String? title;
  final Widget child;

  const PremiumPanel({
    super.key,
    this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardLight, cardColor],
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: mutedColor),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class PlayerRow extends StatelessWidget {
  final Player player;
  final String value;
  final int rank;

  const PlayerRow({
    super.key,
    required this.player,
    required this.value,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [greenColor, cyanColor, purpleColor];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: colors[(rank - 1) % colors.length].withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                color: colors[(rank - 1) % colors.length],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${player.position} • ${player.nation}',
                  style: const TextStyle(
                    color: mutedColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: greenColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// PLAYERS PAGE
// ======================================================

class PlayersPageContent extends StatefulWidget {
  final List<Player> players;

  const PlayersPageContent({
    super.key,
    required this.players,
  });

  @override
  State<PlayersPageContent> createState() => _PlayersPageContentState();
}

class _PlayersPageContentState extends State<PlayersPageContent> {
  String search = '';
  String position = 'All';
  String league = 'All';
  String team = 'All';
  static const int pageSize = 20;
  int visiblePlayers = pageSize;

  @override
  Widget build(BuildContext context) {
    final leagues = widget.players
        .map((p) => p.league)
        .where((v) => v.isNotEmpty && v != 'N/A')
        .toSet()
        .toList()
      ..sort();

    final teams = widget.players
        .where((p) => league == 'All' || p.league == league)
        .map((p) => p.team)
        .where((v) => v.isNotEmpty && v != 'N/A')
        .toSet()
        .toList()
      ..sort();

    final selectedTeam = teams.contains(team) ? team : 'All';

    final filtered = widget.players.where((player) {
      final matchesName =
          player.name.toLowerCase().contains(search.toLowerCase());
      final matchesPosition = position == 'All' || player.position == position;
      final matchesLeague = league == 'All' || player.league == league;
      final matchesTeam = selectedTeam == 'All' || player.team == selectedTeam;

      return matchesName && matchesPosition && matchesLeague && matchesTeam;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Players Explorer',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          'Showing ${filtered.length < visiblePlayers ? filtered.length : visiblePlayers} of ${filtered.length} players',
          style: const TextStyle(color: mutedColor),
        ),
        const SizedBox(height: 22),
        PremiumPanel(
          title: 'Search & Filters',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                onChanged: (v) {
                  setState(() {
                    search = v;
                    visiblePlayers = pageSize;
                  });
                },
                decoration: _inputDecoration(
                  'Search player...',
                  Icons.search_rounded,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'League',
                style: TextStyle(color: mutedColor, fontSize: 12),
              ),
              const SizedBox(height: 7),
              DropdownButtonFormField<String>(
                value: league,
                isExpanded: true,
                dropdownColor: cardLight,
                decoration: _inputDecoration(
                  'Select league',
                  Icons.emoji_events_rounded,
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'All',
                    child: Text('All Leagues'),
                  ),
                  ...leagues.map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(v, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      league = v;
                      team = 'All';
                      visiblePlayers = pageSize;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Team',
                style: TextStyle(color: mutedColor, fontSize: 12),
              ),
              const SizedBox(height: 7),
              DropdownButtonFormField<String>(
                key: ValueKey('team-$league-$selectedTeam'),
                value: selectedTeam,
                isExpanded: true,
                dropdownColor: cardLight,
                decoration: _inputDecoration(
                  'Select team',
                  Icons.shield_rounded,
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'All',
                    child: Text('All Teams'),
                  ),
                  ...teams.map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(v, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      team = v;
                      visiblePlayers = pageSize;
                    });
                  }
                },
              ),
              const SizedBox(height: 17),
              const Text(
                'Position',
                style: TextStyle(color: mutedColor, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['All', 'FW', 'MF', 'DF', 'GK'].map((item) {
                  final selected = position == item;

                  return ChoiceChip(
                    label: Text(item),
                    selected: selected,
                    selectedColor: greenColor.withOpacity(0.2),
                    backgroundColor: cardLight,
                    side: BorderSide(
                      color: selected
                          ? greenColor.withOpacity(0.5)
                          : Colors.white10,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? greenColor : mutedColor,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) {
                      setState(() {
                        position = item;
                        visiblePlayers = pageSize;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      search = '';
                      position = 'All';
                      league = 'All';
                      team = 'All';
                      visiblePlayers = pageSize;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reset Filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: greenColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (filtered.isEmpty)
          const PremiumPanel(
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    color: mutedColor,
                    size: 40,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No players found',
                    style: TextStyle(color: mutedColor),
                  ),
                ],
              ),
            ),
          )
        else
          ...filtered
              .take(visiblePlayers)
              .map((player) => _playerCard(player)),
          if (filtered.length > visiblePlayers)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      visiblePlayers += pageSize;
                    });
                  },
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Charger plus'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: greenColor,
                    foregroundColor: bgColor,
                  ),
                ),
              ),
            ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: greenColor, size: 20),
      filled: true,
      fillColor: const Color(0xFF0D1726),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: greenColor),
      ),
    );
  }

  Widget _playerCard(Player player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: PremiumPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [greenColor, cyanColor],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF07111B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${player.team} • ${player.league}',
                        style: const TextStyle(
                          color: mutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: greenColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    player.position,
                    style: const TextStyle(
                      color: greenColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: Colors.white10),
            const SizedBox(height: 13),
            Wrap(
              spacing: 12,
              runSpacing: 15,
              children: [
                _smallStat('Goals', player.goals, greenColor),
                _smallStat('Assists', player.assists, cyanColor),
                _smallStat(
                    'G+A/Match', player.goalsAssistsPerMatch, purpleColor),
                _smallStat('Starts', player.starts, cyanColor),
                _smallStat('Yellow', player.yellowCards, purpleColor),
                _smallStat('Red', player.redCards, greenColor),
                _smallStat(
                  'Goals - xG',
                  player.goals != null && player.xG != null
                      ? player.efficiency
                      : null,
                  greenColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallStat(String label, double? value, Color color) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: mutedColor,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value == null ? 'N/A' : value.toStringAsFixed(1),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// COMPARE PAGE
// ======================================================

class ComparePageContent extends StatefulWidget {
  final List<Player> players;

  const ComparePageContent({
    super.key,
    required this.players,
  });

  @override
  State<ComparePageContent> createState() => _ComparePageContentState();
}

class _ComparePageContentState extends State<ComparePageContent> {
  int? firstId;
  int? secondId;

  late List<DropdownMenuItem<int>> _playerItems;
  late Map<int, Player> _playersById;

  @override
  void initState() {
    super.initState();
    _preparePlayers();

    if (widget.players.isNotEmpty) {
      firstId = widget.players.first.id;
      secondId = widget.players.length > 1
          ? widget.players[1].id
          : widget.players.first.id;
    }
  }

  void _preparePlayers() {
    _playersById = {
      for (final player in widget.players) player.id: player,
    };

    _playerItems = widget.players.map((player) {
      return DropdownMenuItem<int>(
        value: player.id,
        child: Text(
          '${player.name} (${player.position})',
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList(growable: false);
  }

  @override
  void didUpdateWidget(covariant ComparePageContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.players, widget.players)) {
      _preparePlayers();

      if (widget.players.isEmpty) {
        firstId = null;
        secondId = null;
      } else {
        firstId = _playersById.containsKey(firstId)
            ? firstId
            : widget.players.first.id;
        secondId = _playersById.containsKey(secondId)
            ? secondId
            : widget.players.last.id;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.players.isEmpty) {
      return const Text('No player data available.');
    }

    final first = _playersById[firstId] ?? widget.players.first;
    final second = _playersById[secondId] ?? widget.players.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compare Players',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Analyze and compare player performance',
          style: TextStyle(color: mutedColor),
        ),
        const SizedBox(height: 22),
        PremiumPanel(
          title: 'Select Players',
          child: Column(
            children: [
              _playerSelector('Player 1', firstId, (v) {
                setState(() => firstId = v);
              }),
              const SizedBox(height: 15),
              _playerSelector('Player 2', secondId, (v) {
                setState(() => secondId = v);
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PremiumPanel(
          title: 'Performance Comparison',
          child: Column(
            children: [
              _compareRow('Goals', first.goals, second.goals),
              _compareRow('Assists', first.assists, second.assists),
              _compareRow(
                'G+A / Match',
                first.goalsAssistsPerMatch,
                second.goalsAssistsPerMatch,
              ),
              _compareRow(
                'Goals - xG',
                first.goals != null && first.xG != null
                    ? first.efficiency
                    : null,
                second.goals != null && second.xG != null
                    ? second.efficiency
                    : null,
              ),
              _compareRow('Starts', first.starts, second.starts),
              _compareRow('Yellow cards', first.yellowCards, second.yellowCards),
              _compareRow('Red cards', first.redCards, second.redCards),
            ],
          ),
        ),
      ],
    );
  }

  Widget _playerSelector(
    String label,
    int? selected,
    ValueChanged<int?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: mutedColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: selected,
          isExpanded: true,
          dropdownColor: cardLight,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.person_search_rounded,
              color: greenColor,
            ),
            filled: true,
            fillColor: const Color(0xFF0D1726),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
          ),
          items: _playerItems,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _compareRow(String label, double? a, double? b) {
    final firstWins = a != null && b != null && a > b;
    final secondWins = a != null && b != null && b > a;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              a == null ? 'N/A' : a.toStringAsFixed(2),
              style: TextStyle(
                color: firstWins ? greenColor : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: mutedColor,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              b == null ? 'N/A' : b.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: secondWins ? cyanColor : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// RANKINGS PAGE
// ======================================================

class RankingsPageContent extends StatefulWidget {
  final List<Player> players;

  const RankingsPageContent({
    super.key,
    required this.players,
  });

  @override
  State<RankingsPageContent> createState() => _RankingsPageContentState();
}


class UserProfileSection extends StatefulWidget {
  const UserProfileSection({super.key});

  @override
  State<UserProfileSection> createState() =>
      _UserProfileSectionState();
}

class _UserProfileSectionState extends State<UserProfileSection> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential credential;

      if (_isLogin) {
        credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      if (credential.user?.uid == adminUid) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        setState(() {
          _errorMessage = 'Veuillez utiliser Admin Login.';
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = 'Cette adresse email existe déjà.';
            break;

          case 'invalid-email':
            _errorMessage = 'Adresse email invalide.';
            break;

          case 'weak-password':
            _errorMessage =
                'Mot de passe trop faible (6 caractères minimum).';
            break;

          case 'user-not-found':
          case 'wrong-password':
          case 'invalid-credential':
            _errorMessage = 'Email ou mot de passe incorrect.';
            break;

          default:
            _errorMessage =
                e.message ?? 'Une erreur est survenue.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Erreur : $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: greenColor,
            ),
          );
        }

        if (user != null) {
          if (user.uid == adminUid) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  color: greenColor,
                  size: 42,
                ),
                SizedBox(height: 12),
                Text(
                  'Administrator account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please use the dedicated Admin Panel.',
                  style: TextStyle(color: mutedColor),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.account_circle,
                color: greenColor,
                size: 42,
              ),
              const SizedBox(height: 12),
              const Text(
                'Mon compte',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.email ?? '',
                style: const TextStyle(color: mutedColor),
              ),
              const SizedBox(height: 8),
              const Text(
                'Accès utilisateur : consultation uniquement.',
                style: TextStyle(color: greenColor),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Déconnexion'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: greenColor,
                    foregroundColor: bgColor,
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isLogin ? 'Connexion' : 'Créer un compte',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLogin
                  ? 'Connectez-vous à votre compte.'
                  : 'Créez votre compte utilisateur.',
              style: const TextStyle(color: mutedColor),
            ),
            const SizedBox(height: 20),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Adresse email',
                      labelStyle: TextStyle(color: mutedColor),
                      prefixIcon: Icon(
                        Icons.email,
                        color: greenColor,
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          !RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                              .hasMatch(value.trim())) {
                        return 'Entrez une adresse email valide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      labelStyle: TextStyle(color: mutedColor),
                      prefixIcon: Icon(
                        Icons.lock,
                        color: greenColor,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return '6 caractères minimum.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenColor,
                  foregroundColor: bgColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: bgColor,
                        ),
                      )
                    : Text(
                        _isLogin
                            ? 'Se connecter'
                            : "S'inscrire",
                      ),
              ),
            ),

            Center(
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _errorMessage = null;
                        });
                      },
                child: Text(
                  _isLogin
                      ? 'Pas encore de compte ? Créer un compte'
                      : 'Déjà un compte ? Se connecter',
                  style: const TextStyle(color: greenColor),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}


class _RankingsPageContentState extends State<RankingsPageContent> {
  String selectedMetric = 'Goals';

  @override
  Widget build(BuildContext context) {
    final metrics = <String, double? Function(Player)>{
      'Goals': (p) => p.goals,
      'Assists': (p) => p.assists,
      'G+A / Match': (p) => p.goalsAssistsPerMatch,
      'Starts': (p) => p.starts,
      'Yellow cards': (p) => p.yellowCards,
      'Red cards': (p) => p.redCards,
    };

    final selector = metrics[selectedMetric]!;

    final ranked = widget.players.where((p) => selector(p) != null).toList()
      ..sort((a, b) => selector(b)!.compareTo(selector(a)!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Player Rankings',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Discover the best performing players',
          style: TextStyle(color: mutedColor),
        ),
        const SizedBox(height: 22),
        PremiumPanel(
          title: 'Ranking Metric',
          child: DropdownButtonFormField<String>(
            value: selectedMetric,
            isExpanded: true,
            dropdownColor: cardLight,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.leaderboard_rounded,
                color: greenColor,
              ),
              filled: true,
              fillColor: const Color(0xFF0D1726),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
            ),
            items: metrics.keys.map((metric) {
              return DropdownMenuItem(
                value: metric,
                child: Text(metric),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => selectedMetric = v);
              }
            },
          ),
        ),
        const SizedBox(height: 20),
        PremiumPanel(
          title: 'Top ${ranked.length} Players',
          child: Column(
            children: [
              ...ranked.take(50).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final player = entry.value;
                final value = selector(player)!;

                return PlayerRow(
                  player: player,
                  rank: index + 1,
                  value: value.toStringAsFixed(2),
                );
              }),
              if (ranked.isEmpty)
                const Text(
                  'No ranking data available.',
                  style: TextStyle(color: mutedColor),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

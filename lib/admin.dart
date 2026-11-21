
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

// ======================================================
// COLORS & FIREBASE
// ======================================================

const Color adminBg = Color(0xFF080D18);
const Color adminCard = Color(0xFF111B2B);
const Color adminGreen = Color(0xFF19D69B);
const Color adminMuted = Color(0xFF91A0B5);

const String adminUid = 'TFq2GabKIwOtnjdi6h9CfKkkLEV2';

final CollectionReference<Map<String, dynamic>> playersCollection =
    FirebaseFirestore.instance.collection('players');

// ======================================================
// ADMIN LOGIN PAGE
// ======================================================

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter your email and password.');
      return;
    }

    setState(() => loading = true);

    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null || user.uid != adminUid) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        showMessage('Access denied. Admin account only.');
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminDashboardPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Try again later.';
          break;
        default:
          message = e.message ?? 'Login failed.';
      }

      showMessage(message);
    } catch (e) {
      if (!mounted) return;
      showMessage('An error occurred: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF26364A),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 65,
                    height: 65,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [adminGreen, Color(0xFF36C5F0)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: adminBg,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Admin Portal',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to manage Football Analytics BI',
                    style: TextStyle(color: adminMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Email Address',
                    style: TextStyle(color: adminMuted),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration(
                      'Enter your email',
                      Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Password',
                    style: TextStyle(color: adminMuted),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: passwordController,
                    obscureText: hidePassword,
                    onSubmitted: (_) => login(),
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration(
                      'Enter your password',
                      Icons.lock_outline_rounded,
                    ).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            hidePassword = !hidePassword;
                          });
                        },
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: adminMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: loading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: adminGreen,
                        foregroundColor: adminBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(
                              color: adminBg,
                            )
                          : const Text(
                              'LOGIN AS ADMIN',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: adminGreen,
                        size: 16,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Restricted administrator access',
                        style: TextStyle(
                          color: adminMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: adminMuted),
      prefixIcon: Icon(icon, color: adminGreen),
      filled: true,
      fillColor: adminBg,
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
        borderSide: const BorderSide(color: adminGreen),
      ),
    );
  }
}

// ======================================================
// ADMIN DASHBOARD
// ======================================================

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminLoginPage(),
      ),
      (route) => false,
    );
  }

  void showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF26364A),
      ),
    );
  }

  // ======================================================
  // CSV VALUE CONVERSION
  // ======================================================

  dynamic parseCsvValue(String key, String value) {
    if (value.isEmpty) return null;

    const integerFields = {
      'id_joueur',
      'id_equipe',
      'id_ligue',
    };

    const numericFields = {
      'Age',
      'MP',
      'Playing_Time_Starts',
      'Performance_Gls',
      'Performance_1_Ast',
      'Performance_6_CrdY',
      'Performance_7_CrdR',
      'Expected_xG',
      'Total_G_A',
      'Avg_Performance_GA',
      'Avg_Cards_Per_Match',
    };

    if (integerFields.contains(key)) {
      return int.tryParse(value) ?? value;
    }

    if (numericFields.contains(key)) {
      return double.tryParse(value) ?? value;
    }

    return value;
  }

  // ======================================================
  // IMPORT DATASET INTO FIRESTORE
  // ======================================================

  Future<void> importDataset(BuildContext context) async {
    bool dialogOpened = false;

    try {
      // Loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          backgroundColor: adminCard,
          content: Row(
            children: [
              CircularProgressIndicator(
                color: adminGreen,
              ),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Importing dataset...',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );

      dialogOpened = true;

      // Read CSV
      final csvString =
          await rootBundle.loadString('assets/fixedBI.csv');

      final normalizedCsv = csvString
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n');

final rows = const CsvToListConverter(
  fieldDelimiter: ';',
  eol: '\n',
  shouldParseNumbers: false,
).convert(normalizedCsv);

      if (rows.length < 2) {
        throw Exception('CSV file is empty.');
      }

      // CSV headers
      final headers = rows.first.map((e) {
        return e.toString().replaceAll('\uFEFF', '').trim();
      }).toList();

      final idIndex = headers.indexOf('id_joueur');

      if (idIndex == -1) {
        throw Exception('Column id_joueur not found.');
      }

      // Check existing Firestore records
      final existingSnapshot = await playersCollection.get();

      final existingIds = <String>{};

      for (final doc in existingSnapshot.docs) {
        existingIds.add(doc.id);

        final data = doc.data();
        final existingPlayerId = data['id_joueur'];

        if (existingPlayerId != null) {
          existingIds.add(existingPlayerId.toString());
        }
      }

      int imported = 0;
      int skipped = 0;
      int invalid = 0;

      WriteBatch batch = FirebaseFirestore.instance.batch();

      int batchCount = 0;

      // Process CSV rows
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        if (row.length <= idIndex) {
          invalid++;
          continue;
        }

        final playerId = row[idIndex].toString().trim();

        if (playerId.isEmpty) {
          invalid++;
          continue;
        }

        // Never overwrite existing players
        if (existingIds.contains(playerId)) {
          skipped++;
          continue;
        }

        final Map<String, dynamic> playerData = {};

        // Import all original CSV columns
        for (int j = 0; j < headers.length; j++) {
          if (j >= row.length) continue;

          final key = headers[j];

          if (key.isEmpty) continue;

          final value = row[j].toString().trim();

          playerData[key] = parseCsvValue(key, value);
        }

        // Map CSV fields to application fields
        playerData['name'] =
            playerData['Player']?.toString() ?? '';

        playerData['nation'] =
            playerData['Nation']?.toString() ?? '';

        playerData['position'] =
            playerData['Pos']?.toString() ?? '';

        playerData['team'] =
            playerData['nom_equipe']?.toString() ?? '';

        playerData['league'] =
            playerData['nom_ligue']?.toString() ?? '';

        final goalsValue =
            num.tryParse('${playerData['Performance_Gls'] ?? 0}');

        final assistsValue =
            num.tryParse('${playerData['Performance_1_Ast'] ?? 0}');

        playerData['goals'] = goalsValue?.toInt() ?? 0;
        playerData['assists'] = assistsValue?.toInt() ?? 0;

        // Stable Firestore document ID
        final docRef = playersCollection.doc(playerId);

        batch.set(docRef, playerData);

        existingIds.add(playerId);

        imported++;
        batchCount++;

        // Commit every 450 operations
        if (batchCount >= 450) {
          await batch.commit();

          batch = FirebaseFirestore.instance.batch();
          batchCount = 0;
        }
      }

      // Commit remaining operations
      if (batchCount > 0) {
        await batch.commit();
      }

      if (!context.mounted) return;

      if (dialogOpened) {
        Navigator.pop(context);
        dialogOpened = false;
      }

      showMessage(
        context,
        'Import completed: $imported imported, '
        '$skipped skipped, $invalid invalid.',
      );
    } catch (e) {
      if (!context.mounted) return;

      if (dialogOpened) {
        Navigator.pop(context);
      }

      showMessage(
        context,
        'Import error: $e',
      );
    }
  }

  // ======================================================
  // ADD / EDIT PLAYER
  // ======================================================

  Future<void> openPlayerForm(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? player,
  }) async {
    final data = player?.data() ?? {};

    final name = TextEditingController(
      text: data['name']?.toString() ?? '',
    );

    final nation = TextEditingController(
      text: data['nation']?.toString() ?? '',
    );

    final position = TextEditingController(
      text: data['position']?.toString() ?? '',
    );

    final team = TextEditingController(
      text: data['team']?.toString() ?? '',
    );

    final league = TextEditingController(
      text: data['league']?.toString() ?? '',
    );

    final goals = TextEditingController(
      text: (data['goals'] ?? 0).toString(),
    );

    final assists = TextEditingController(
      text: (data['assists'] ?? 0).toString(),
    );

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          player == null ? 'Add Player' : 'Edit Player',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Player name'),
                  _field(nation, 'Nation'),
                  _field(position, 'Position'),
                  _field(team, 'Team'),
                  _field(league, 'League'),
                  _field(goals, 'Goals', number: true),
                  _field(assists, 'Assists', number: true),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: adminMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: adminGreen,
              foregroundColor: adminBg,
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;

              final goalsValue = int.tryParse(goals.text.trim());
              final assistsValue = int.tryParse(assists.text.trim());

              if (goalsValue == null ||
                  assistsValue == null ||
                  goalsValue < 0 ||
                  assistsValue < 0) {
                return;
              }

              Navigator.pop(dialogContext, {
                'name': name.text.trim(),
                'nation': nation.text.trim(),
                'position': position.text.trim(),
                'team': team.text.trim(),
                'league': league.text.trim(),
                'goals': goalsValue,
                'assists': assistsValue,
              });
            },
            child: Text(player == null ? 'Add' : 'Save changes'),
          ),
        ],
      ),
    );

    name.dispose();
    nation.dispose();
    position.dispose();
    team.dispose();
    league.dispose();
    goals.dispose();
    assists.dispose();

    if (result == null || !context.mounted) return;

    try {
      if (player == null) {
        await playersCollection.add(result);
        showMessage(context, 'Player added successfully!');
      } else {
        await playersCollection.doc(player.id).update(result);
        showMessage(context, 'Player updated successfully!');
      }
    } catch (e) {
      if (!context.mounted) return;
      showMessage(context, 'Firestore error: $e');
    }
  }

  // ======================================================
  // FORM FIELD
  // ======================================================

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextFormField(
        controller: controller,
        keyboardType: number
            ? TextInputType.number
            : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: adminMuted),
          filled: true,
          fillColor: adminBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: adminGreen),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'This field is required';
          }

          if (number) {
            final parsed = int.tryParse(value.trim());

            if (parsed == null || parsed < 0) {
              return 'Enter a valid positive number';
            }
          }

          return null;
        },
      ),
    );
  }

  // ======================================================
  // DELETE PLAYER
  // ======================================================

  Future<void> deletePlayer(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> player,
  ) async {
    final name = player.data()?['name'] ?? 'this player';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: adminCard,
        title: const Text(
          'Delete Player',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete $name?',
          style: const TextStyle(color: adminMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: adminMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await playersCollection.doc(player.id).delete();

      if (!context.mounted) return;

      showMessage(context, 'Player deleted successfully!');
    } catch (e) {
      if (!context.mounted) return;
      showMessage(context, 'Delete error: $e');
    }
  }

  // ======================================================
  // DASHBOARD UI
  // ======================================================

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1422),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => logout(context),
            icon: const Icon(
              Icons.logout_rounded,
              color: adminGreen,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: adminGreen,
        foregroundColor: adminBg,
        onPressed: () => openPlayerForm(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Player'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: playersCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: adminGreen),
            );
          }

          final players = snapshot.data?.docs ?? [];

          return CustomScrollView(
            cacheExtent: 300,
            slivers: [
              // HEADER
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome, Administrator!',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Manage your football dataset and player records.',
                        style: TextStyle(color: adminMuted),
                      ),
                      const SizedBox(height: 18),

                      // IMPORT BUTTON
                      ElevatedButton.icon(
                        onPressed: () => importDataset(context),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Import Dataset'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: adminGreen,
                          foregroundColor: adminBg,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // DATABASE INFORMATION
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: adminCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.sports_soccer,
                              color: adminGreen,
                              size: 35,
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              'Football Analytics BI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${players.length} players in database',
                              style: const TextStyle(
                                color: adminGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      const Text(
                        'Player Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),

              // EMPTY STATE
              if (players.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(25),
                    child: Center(
                      child: Text(
                        'No players found. Add your first player!',
                        style: TextStyle(color: adminMuted),
                      ),
                    ),
                  ),
                ),

              // LAZY PLAYERS LIST
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final player = players[index];
                      final data = player.data();

                      return RepaintBoundary(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(17),
                          decoration: BoxDecoration(
                            color: adminCard,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFF1A3540),
                                child: Icon(
                                  Icons.person,
                                  color: adminGreen,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['name']?.toString() ?? 'Unknown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${data['team'] ?? '-'} • '
                                      '${data['position'] ?? '-'}',
                                      style: const TextStyle(
                                        color: adminMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Goals: ${data['goals'] ?? 0}  |  '
                                      'Assists: ${data['assists'] ?? 0}',
                                      style: const TextStyle(
                                        color: adminGreen,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => openPlayerForm(
                                  context,
                                  player: player,
                                ),
                                icon: const Icon(
                                  Icons.edit,
                                  color: adminGreen,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => deletePlayer(
                                  context,
                                  player,
                                ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: players.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 90),
              ),
            ],
          );
        },
      ),
    );
  }
}

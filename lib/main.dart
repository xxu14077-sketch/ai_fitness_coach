import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/storage.dart';
import 'ui/theme.dart';
import 'core/config.dart';
import 'ui/chat_page.dart';
import 'ui/plan_page.dart';
import 'ui/vision_page.dart';
import 'ui/widgets/trend_chart.dart';
import 'ui/widgets/activity_heatmap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Fitness Coach',
      theme: AppTheme.light,
      home: Supabase.instance.client.auth.currentUser == null
          ? const LoginPage()
          : const MainScreen(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.fitness_center,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'AI Fitness Coach',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: '邮箱',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text('登录'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loading ? null : _signUp,
                child: const Text('注册账号'),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ChatPage(),
    HomePage(), // The Dashboard
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'AI 教练',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '功能',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _showRecordWeightDialog() async {
    final weightCtrl = TextEditingController();
    final fatCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记录今日数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '体重 (kg)',
                suffixText: 'kg',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fatCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '体脂率 (%)',
                suffixText: '%',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final w = double.tryParse(weightCtrl.text);
              final f = double.tryParse(fatCtrl.text);
              if (w != null) {
                final uid = Supabase.instance.client.auth.currentUser?.id;
                if (uid != null) {
                  await Supabase.instance.client.from('body_metrics').insert({
                    'user_id': uid,
                    'weight_kg': w,
                    'body_fat_pct': f,
                    'date': DateTime.now().toIso8601String().substring(0, 10),
                  });
                }
              }
              if (mounted) Navigator.pop(context);
              // Trigger refresh? The chart has a refresh button.
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('记录已保存，请刷新图表')));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健身仪表盘'),
        actions: [
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const _HomeBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRecordWeightDialog,
        icon: const Icon(Icons.add),
        label: const Text('记录体重'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}

class _HomeBody extends StatefulWidget {
  const _HomeBody();
  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  String _status = 'none';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final res = await Supabase.instance.client
          .from('subscriptions')
          .select('status')
          .eq('user_id', uid)
          .maybeSingle();
      if (res == null) {
        _status = 'none';
      } else {
        _status = res['status'] as String? ?? 'none';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _activateDemo() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('subscriptions').upsert({
        'user_id': uid,
        'status': 'active',
        'tier': 'pro',
      });
      await _fetchStatus();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    String? subtitle,
  }) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isPro = _status == 'active';

    return RefreshIndicator(
      onRefresh: _fetchStatus,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Welcome Card
          Card(
            color: AppTheme.secondaryColor,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '欢迎回来',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              user?.email?.split('@')[0] ?? 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isPro)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: _loading ? null : _activateDemo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.secondaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text('开启试用'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          const SizedBox(height: 16),
          const TrendChart(),
          const SizedBox(height: 16),
          const ActivityHeatmap(),

          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'v1.1 - Charts Enabled',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'AI 功能',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              _buildFeatureCard(
                context,
                title: '今日专属计划',
                subtitle: '根据状态实时调整',
                icon: Icons.monitor_heart,
                color: Colors.redAccent,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PlanPage()),
                ),
              ),
              _buildFeatureCard(
                context,
                title: '动作矫正',
                subtitle: 'AI 视觉分析',
                icon: Icons.camera_enhance,
                color: Colors.teal,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => VisionPage()),
                ),
              ),
              _buildFeatureCard(
                context,
                title: '饮食估算',
                subtitle: '拍照算热量',
                icon: Icons.restaurant_menu,
                color: Colors.orange,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NutritionEstimatePage(),
                  ),
                ),
              ),
              _buildFeatureCard(
                context,
                title: '器械助手',
                subtitle: '拍照查用法',
                icon: Icons.fitness_center,
                color: Colors.blue,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EquipmentInfoPage()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
            '我的记录',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildFeatureCard(
                context,
                title: '我的计划',
                icon: Icons.calendar_today,
                color: Colors.indigo,
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const MyPlansPage())),
                subtitle: null,
              ),
              _buildFeatureCard(
                context,
                title: '训练日志',
                icon: Icons.history,
                color: Colors.green,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyWorkoutsPage()),
                ),
                subtitle: null,
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class PlanOverviewPage extends StatefulWidget {
  const PlanOverviewPage({super.key});
  @override
  State<PlanOverviewPage> createState() => _PlanOverviewPageState();
}

class _PlanOverviewPageState extends State<PlanOverviewPage> {
  Map<String, dynamic>? _cycle;
  String? _planId;
  bool _loading = false;
  String? _error;

  Future<void> _generatePlan() async {
    setState(() {
      _loading = true;
      _error = null;
      _cycle = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        setState(() {
          _error = '请先登录';
          _loading = false;
        });
        return;
      }
      final body = {
        'user_id': uid,
        'goals': {'type': 'muscle_gain'},
        'constraints': {'days_per_week': 4},
        'equipment': ['barbell', 'dumbbell'],
      };
      final res = await Supabase.instance.client.functions.invoke(
        'plan-generate',
        body: body,
      );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _planId = data['plan_id'] as String?;
        _cycle = data['cycle'] as Map<String, dynamic>?;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('生成训练计划')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _generatePlan,
                icon: const Icon(Icons.auto_awesome),
                label: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('一键生成基础计划'),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            Expanded(
              child: _cycle == null
                  ? const Center(
                      child: Text(
                        '点击上方按钮生成计划',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView(
                      children: [
                        _SessionLogger(planId: _planId, cycle: _cycle!),
                        const SizedBox(height: 12),
                        ...List.generate(
                          (_cycle?['daily_sessions'] as List).length,
                          (index) {
                            final session = (_cycle?['daily_sessions']
                                as List)[index] as Map<String, dynamic>;
                            final items = session['items'] as List<dynamic>;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session['name'] as String,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.secondaryColor,
                                      ),
                                    ),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    for (final it in items)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.circle,
                                              size: 8,
                                              color: AppTheme.primaryColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${it['name']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${it['sets']}x${it['reps']} | ${it['load_strategy']}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyPlansPage extends StatefulWidget {
  const MyPlansPage({super.key});
  @override
  State<MyPlansPage> createState() => _MyPlansPageState();
}

class _MyPlansPageState extends State<MyPlansPage> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final since =
          DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final res = await Supabase.instance.client
          .from('training_plans')
          .select('id, cycle_json, created_at')
          .eq('user_id', uid)
          .gte('created_at', since)
          .order('created_at', ascending: false);
      final list = (res as List).map((e) => e as Map<String, dynamic>).toList();
      setState(() {
        _plans = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的计划')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final p = _plans[index];
                    final cycle = p['cycle_json'] as Map<String, dynamic>;
                    final days = (cycle['daily_sessions'] as List).length;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(
                          '${cycle['split']} 训练',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '包含 $days 个训练日\n创建于 ${p['created_at'].toString().substring(0, 10)}',
                        ),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlanDetailPage(cycle: cycle),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

class PlanDetailPage extends StatelessWidget {
  final Map<String, dynamic> cycle;
  const PlanDetailPage({super.key, required this.cycle});
  @override
  Widget build(BuildContext context) {
    final sessions = cycle['daily_sessions'] as List<dynamic>;
    return Scaffold(
      appBar: AppBar(title: const Text('计划详情')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final session = sessions[index] as Map<String, dynamic>;
          final items = session['items'] as List<dynamic>;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session['name'] as String,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${it['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${it['sets']}x${it['reps']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class MyWorkoutsPage extends StatefulWidget {
  const MyWorkoutsPage({super.key});
  @override
  State<MyWorkoutsPage> createState() => _MyWorkoutsPageState();
}

class _MyWorkoutsPageState extends State<MyWorkoutsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      var query = Supabase.instance.client
          .from('workout_sessions')
          .select('id, date, completion_pct, feedback_json, created_at')
          .eq('user_id', uid);
      if (_from != null) {
        query = query.gte('created_at', _from!.toIso8601String());
      }
      if (_to != null) {
        final end = DateTime(
          _to!.year,
          _to!.month,
          _to!.day,
        ).add(const Duration(days: 1));
        query = query.lt('created_at', end.toIso8601String());
      }
      final res = await query.order('created_at', ascending: false);
      final list = (res as List).map((e) => e as Map<String, dynamic>).toList();
      setState(() {
        _items = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _from = picked);
      await _fetch();
    }
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _to = picked);
      await _fetch();
    }
  }

  Future<void> _delete(String id) async {
    try {
      await Supabase.instance.client
          .from('workout_sessions')
          .delete()
          .eq('id', id);
      await _fetch();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的训练日志')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _pickFrom,
                              child: Text(
                                _from != null
                                    ? _from!.toIso8601String().substring(0, 10)
                                    : '开始日期',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _pickTo,
                              child: Text(
                                _to != null
                                    ? _to!.toIso8601String().substring(0, 10)
                                    : '结束日期',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              setState(() {
                                _from = null;
                                _to = null;
                              });
                              await _fetch();
                            },
                            icon: const Icon(Icons.clear_all),
                            tooltip: '清除筛选',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final it = _items[index];
                          final pct = it['completion_pct'] as int?;
                          final notes = (it['feedback_json']
                              as Map<String, dynamic>?)?['notes'] as String?;
                          return Card(
                            child: ListTile(
                              leading: CircularProgressIndicator(
                                value: (pct ?? 0) / 100,
                                backgroundColor: Colors.grey.shade200,
                              ),
                              title: Text(
                                '完成度 ${pct ?? 0}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${it['date'] ?? it['created_at'].substring(0, 10)}\n${notes ?? "无备注"}',
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _delete(it['id'] as String),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SessionLogger extends StatefulWidget {
  final String? planId;
  final Map<String, dynamic> cycle;
  const _SessionLogger({required this.planId, required this.cycle});
  @override
  State<_SessionLogger> createState() => _SessionLoggerState();
}

class _SessionLoggerState extends State<_SessionLogger> {
  double _pct = 80;
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  String? _msg;

  Future<void> _save() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _msg = '请先登录';
      });
      return;
    }
    setState(() {
      _saving = true;
      _msg = null;
    });
    try {
      await Supabase.instance.client.from('workout_sessions').insert({
        'user_id': uid,
        'plan_id': widget.planId,
        'completion_pct': _pct.round(),
        'feedback_json': {'notes': _notesCtrl.text},
        'exercises_json': widget.cycle['daily_sessions'],
      });
      setState(() {
        _msg = '已保存';
      });
    } catch (e) {
      setState(() {
        _msg = e.toString();
      });
    } finally {
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '记录本次完成度',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 100,
                    divisions: 20,
                    value: _pct,
                    label: '${_pct.round()}%',
                    onChanged: _saving ? null : (v) => setState(() => _pct = v),
                  ),
                ),
                Text(
                  '${_pct.round()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: '备注',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text('保存记录'),
              ),
            ),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _msg!,
                  style: TextStyle(
                    color: _msg == '已保存' ? Colors.green : Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AiPlanEnhancePage extends StatefulWidget {
  const AiPlanEnhancePage({super.key});
  @override
  State<AiPlanEnhancePage> createState() => _AiPlanEnhancePageState();
}

class _AiPlanEnhancePageState extends State<AiPlanEnhancePage> {
  String _goal = 'muscle_gain';
  int _days = 4;
  final _equipmentCtrl = TextEditingController(text: 'barbell,dumbbell');
  final _heightCtrl = TextEditingController(text: '175');
  final _weightCtrl = TextEditingController(text: '70');
  final _bfCtrl = TextEditingController(text: '18');
  Map<String, dynamic>? _cycle;
  String? _error;
  bool _loading = false;

  Future<void> _invoke() async {
    setState(() {
      _loading = true;
      _error = null;
      _cycle = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final equipment = _equipmentCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final body = {
        'height_cm': int.tryParse(_heightCtrl.text),
        'weight_kg': int.tryParse(_weightCtrl.text),
        'bf_pct': int.tryParse(_bfCtrl.text),
      };
      final payload = {
        'user_id': uid,
        'goals': {'type': _goal},
        'constraints': {'days_per_week': _days},
        'equipment': equipment,
        'body': body,
      };
      final res = await Supabase.instance.client.functions.invoke(
        'plan-ai-enhance',
        body: payload,
      );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _cycle = data['cycle'] as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI增强训练计划')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _goal,
                      decoration: const InputDecoration(labelText: '训练目标'),
                      items: const [
                        DropdownMenuItem(
                          value: 'muscle_gain',
                          child: Text('增肌'),
                        ),
                        DropdownMenuItem(value: 'fat_loss', child: Text('减脂')),
                        DropdownMenuItem(value: 'strength', child: Text('力量')),
                      ],
                      onChanged: (v) => setState(() => _goal = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _days,
                      decoration: const InputDecoration(labelText: '每周天数'),
                      items: List.generate(7, (i) => i + 1)
                          .map(
                            (d) =>
                                DropdownMenuItem(value: d, child: Text('$d 天')),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _days = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _equipmentCtrl,
                      decoration: const InputDecoration(
                        labelText: '可用器械',
                        hintText: '逗号分隔',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _heightCtrl,
                            decoration: const InputDecoration(
                              labelText: '身高cm',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _weightCtrl,
                            decoration: const InputDecoration(
                              labelText: '体重kg',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _bfCtrl,
                            decoration: const InputDecoration(labelText: '体脂%'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _invoke,
                        icon: const Icon(Icons.auto_awesome),
                        label: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('生成 AI 计划'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 12),
            if (_cycle != null) ...[
              Text('AI 为您定制的计划', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (_cycle!['daily_sessions'] as List).length,
                itemBuilder: (context, index) {
                  final s = (_cycle!['daily_sessions'] as List)[index]
                      as Map<String, dynamic>;
                  final items = s['items'] as List<dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      title: Text(
                        s['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: [
                        for (final it in items)
                          ListTile(
                            dense: true,
                            title: Text('${it['name']}'),
                            trailing: Text('${it['sets']}x${it['reps']}'),
                            subtitle: Text(
                              '休息: ${it['rest_s']}s | ${it['load_strategy']}',
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NutritionEstimatePage extends StatefulWidget {
  const NutritionEstimatePage({super.key});
  @override
  State<NutritionEstimatePage> createState() => _NutritionEstimatePageState();
}

class _NutritionEstimatePageState extends State<NutritionEstimatePage> {
  final _urlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  Map<String, dynamic>? _estimate;
  String? _error;
  bool _loading = false;
  bool _uploading = false;

  Future<void> _invoke() async {
    setState(() {
      _loading = true;
      _error = null;
      _estimate = null;
    });
    try {
      final payload = {
        'image_url': _urlCtrl.text.trim(),
        'context': {'notes': _notesCtrl.text},
      };
      final res = await Supabase.instance.client.functions.invoke(
        'nutrition-estimate',
        body: payload,
      );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _estimate = data['estimate'] as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('饮食估算')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_urlCtrl.text.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _urlCtrl.text,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _uploading
                                ? null
                                : () async {
                                    setState(() => _uploading = true);
                                    final url = await StorageHelper
                                        .pickAndUploadImage();
                                    setState(() {
                                      _uploading = false;
                                      if (url != null) _urlCtrl.text = url;
                                    });
                                  },
                            icon: _uploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt),
                            label: const Text('拍照/上传'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlCtrl,
                      decoration: const InputDecoration(labelText: '或输入图片URL'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(labelText: '备注 (可选)'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _invoke,
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('开始估算'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_estimate != null) ...[
              const SizedBox(height: 24),
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '${_estimate!['total_calories'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const Text(
                        'KCAL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const Divider(),
                      if (_estimate!['notes'] != null)
                        Text(
                          '${_estimate!['notes']}',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final it in (_estimate!['items'] as List? ?? []))
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.restaurant, size: 16),
                    ),
                    title: Text('${it['name']}'),
                    subtitle: Text(
                      '热量: ${it['calories']} | P:${it['protein_g']} C:${it['carbs_g']} F:${it['fat_g']}',
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class EquipmentInfoPage extends StatefulWidget {
  const EquipmentInfoPage({super.key});
  @override
  State<EquipmentInfoPage> createState() => _EquipmentInfoPageState();
}

class _EquipmentInfoPageState extends State<EquipmentInfoPage> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  Map<String, dynamic>? _info;
  String? _error;
  bool _loading = false;
  bool _uploading = false;

  Future<void> _invoke() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final payload = {
        'name': _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        'image_url': _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      };
      final res = await Supabase.instance.client.functions.invoke(
        'equipment-info',
        body: payload,
      );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _info = data['info'] as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vids = (_info?['video_urls'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('器械助手')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_urlCtrl.text.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _urlCtrl.text,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _uploading
                                ? null
                                : () async {
                                    setState(() => _uploading = true);
                                    final url = await StorageHelper
                                        .pickAndUploadImage();
                                    setState(() {
                                      _uploading = false;
                                      if (url != null) _urlCtrl.text = url;
                                    });
                                  },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('上传图片'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: '或者输入器械名称'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _invoke,
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('查询用法'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_info != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _info!['equipment'] ?? '未知器械',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_info!['usage'] != null) ...[
                        const Text(
                          '用法',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_info!['usage']}',
                          style: const TextStyle(color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_info!['mistakes'] != null) ...[
                        const Text(
                          '常见错误',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          '${_info!['mistakes']}',
                          style: const TextStyle(color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (vids.isNotEmpty) ...[
                        const Text(
                          '推荐教程',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        for (final u in vids)
                          InkWell(
                            onTap: () {}, // Launch URL logic here if needed
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                u.toString(),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

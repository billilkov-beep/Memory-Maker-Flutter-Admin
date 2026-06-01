import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnv();
  final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
  final anon = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
  if (url.isNotEmpty && anon.isNotEmpty) {
    await Supabase.initialize(url: url, anonKey: anon);
  }
  runApp(const MemoryMakerAdminApp());
}

Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // The app will show a clean configuration message if env is missing.
  }
}

SupabaseClient? get db {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

class MemoryMakerAdminApp extends StatelessWidget {
  const MemoryMakerAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Maker Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF5F1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9B5367)),
        fontFamily: 'Roboto',
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: const TextScaler.linear(1.0),
            boldText: false,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashGate(),
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SplashScreen();
    final client = db;
    if (client == null) return const LoginScreen(configMissing: true);
    return client.auth.currentSession == null
        ? const LoginScreen()
        : const AdminShell();
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF7F3), Color(0xFFF7DFDA), Color(0xFFFFFBF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 112,
                height: 112,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.75),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: const Color(0xFF9B5367).withOpacity(.35)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9B5367).withOpacity(.20),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Image.asset('assets/admin_icon.png'),
              ),
              const SizedBox(height: 22),
              const Text(
                'Memory Maker Admin',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3B2B30),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Secure control panel',
                style: TextStyle(fontSize: 14, color: Color(0xFF8A6B73)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final bool configMissing;
  const LoginScreen({super.key, this.configMissing = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'bill@abp.ca');
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (widget.configMissing || db == null) {
      setState(() => _message = 'App configuration is missing. Please add Supabase environment variables and rebuild.');
      return;
    }
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _message = 'Please enter admin email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final client = db!;
      await client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final allowed = await AdminApi.checkAdminAccess();
      if (!allowed) {
        await client.auth.signOut();
        setState(() => _message = 'This account is not authorized for admin access.');
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminShell()));
    } catch (_) {
      setState(() => _message = 'Unable to sign in. Please check admin access and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (db == null || _email.text.trim().isEmpty) {
      setState(() => _message = 'Enter your admin email first.');
      return;
    }
    try {
      await db!.auth.resetPasswordForEmail(_email.text.trim());
      setState(() => _message = 'Password reset email sent.');
    } catch (_) {
      setState(() => _message = 'Could not send reset email. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AdminBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4F2),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0xFF9B5367).withOpacity(.32)),
                            ),
                            child: Image.asset('assets/admin_icon.png'),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Memory Maker Admin',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF3A292F)),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Secure admin dashboard',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: Color(0xFF866A72)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Sign in',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF3A292F)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Manage support, users, galleries and uploads from one place.',
                        style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF7A6269)),
                      ),
                      const SizedBox(height: 22),
                      AdminInput(
                        controller: _email,
                        label: 'Admin email',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      AdminInput(
                        controller: _password,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _hidePassword,
                        suffix: IconButton(
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(_hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE5EA),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFB23448).withOpacity(.12)),
                          ),
                          child: Text(
                            _message!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF9C2339), height: 1.35),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _loading ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF9B5367),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(_loading ? 'Signing in...' : 'Login'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading ? null : _resetPassword,
                        child: const Text('Forgot password? Send reset email'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  late Future<void> _future;
  Map<String, dynamic> _me = <String, dynamic>{};
  Map<String, dynamic> _overview = <String, dynamic>{};
  List<Map<String, dynamic>> _tickets = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _users = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _load() async {
    try {
      final me = await AdminApi.adminMe();
      final overview = await AdminApi.overview();
      final tickets = await AdminApi.listTickets();
      final users = await AdminApi.listUsers();
      final events = await AdminApi.listEvents();
      if (!mounted) return;
      setState(() {
        _me = me;
        _overview = overview;
        _tickets = tickets;
        _users = users;
        _events = events;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load admin data. Please confirm SQL migration and admin access.');
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _signOut() async {
    await db?.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(overview: _overview, me: _me),
      TicketsPage(tickets: _tickets, onReply: _replyTicket),
      UsersPage(users: _users, isSuperAdmin: _isSuperAdmin, onRole: _setRole),
      GalleriesPage(events: _events),
    ];

    return Scaffold(
      body: AdminBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.72),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF9B5367).withOpacity(.15)),
                      ),
                      child: Image.asset('assets/admin_icon.png'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Memory Maker Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF34262B))),
                          Text(
                            (_me['email'] ?? 'Admin dashboard').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF80656D)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
                    IconButton(onPressed: _signOut, icon: const Icon(Icons.logout_rounded)),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<void>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && _overview.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (_error != null) return ErrorPanel(message: _error!, onRetry: _refresh);
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: pages[_tab],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.support_agent_rounded), label: 'Tickets'),
          NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.collections_rounded), label: 'Galleries'),
        ],
      ),
    );
  }

  bool get _isSuperAdmin {
    final role = (_me['role'] ?? '').toString().toLowerCase();
    return _me['is_super_admin'] == true || role == 'super_admin';
  }

  Future<void> _replyTicket(Map<String, dynamic> ticket) async {
    final controller = TextEditingController(text: (ticket['admin_reply'] ?? '').toString());
    final reply = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply to ticket'),
        content: TextField(
          controller: controller,
          minLines: 4,
          maxLines: 7,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Write reply'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Send Reply')),
        ],
      ),
    );
    controller.dispose();
    if (reply == null || reply.trim().isEmpty) return;
    try {
      await AdminApi.replyTicket(ticket['id'].toString(), reply.trim());
      await _refresh();
      _toast('Reply sent.');
    } catch (_) {
      _toast('Could not send reply.');
    }
  }

  Future<void> _setRole(Map<String, dynamic> user, String role) async {
    try {
      await AdminApi.setUserRole(user['id'].toString(), role);
      await _refresh();
      _toast('Role updated.');
    } catch (_) {
      _toast('Could not update role.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class DashboardPage extends StatelessWidget {
  final Map<String, dynamic> overview;
  final Map<String, dynamic> me;
  const DashboardPage({super.key, required this.overview, required this.me});

  @override
  Widget build(BuildContext context) {
    final cards = [
      StatItem('Users', overview['users_count'], Icons.people_alt_rounded),
      StatItem('Galleries', overview['events_count'], Icons.collections_rounded),
      StatItem('Uploads', overview['uploads_count'], Icons.photo_library_rounded),
      StatItem('Open Tickets', overview['open_tickets_count'], Icons.support_agent_rounded),
    ];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF33262B))),
        const SizedBox(height: 6),
        const Text('Monitor Memory Maker activity in one clean admin panel.', style: TextStyle(color: Color(0xFF7E646C), fontSize: 14)),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.25),
          itemCount: cards.length,
          itemBuilder: (_, i) => StatCard(item: cards[i]),
        ),
        const SizedBox(height: 18),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Admin access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Role: ${me['role'] ?? 'admin'}', style: const TextStyle(fontSize: 14, color: Color(0xFF6B535B))),
              const SizedBox(height: 4),
              Text('Email: ${me['email'] ?? '-'}', style: const TextStyle(fontSize: 14, color: Color(0xFF6B535B))),
            ],
          ),
        ),
      ],
    );
  }
}

class TicketsPage extends StatelessWidget {
  final List<Map<String, dynamic>> tickets;
  final Future<void> Function(Map<String, dynamic>) onReply;
  const TicketsPage({super.key, required this.tickets, required this.onReply});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Support Tickets', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF33262B))),
        const SizedBox(height: 14),
        if (tickets.isEmpty) const EmptyCard(icon: Icons.support_agent_rounded, title: 'No tickets yet', subtitle: 'New user support requests will appear here.'),
        for (final ticket in tickets) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text((ticket['subject'] ?? 'Support request').toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    Chip(label: Text((ticket['status'] ?? 'open').toString())),
                  ],
                ),
                const SizedBox(height: 6),
                Text((ticket['user_email'] ?? '').toString(), style: const TextStyle(color: Color(0xFF7B646B), fontSize: 13)),
                const SizedBox(height: 10),
                Text((ticket['message'] ?? '').toString(), style: const TextStyle(fontSize: 14, height: 1.35)),
                if ((ticket['admin_reply'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFECE8), borderRadius: BorderRadius.circular(14)),
                    child: Text('Reply: ${ticket['admin_reply']}', style: const TextStyle(fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(onPressed: () => onReply(ticket), icon: const Icon(Icons.reply_rounded), label: const Text('Reply')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class UsersPage extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final bool isSuperAdmin;
  final Future<void> Function(Map<String, dynamic>, String) onRole;
  const UsersPage({super.key, required this.users, required this.isSuperAdmin, required this.onRole});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Users', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF33262B))),
        const SizedBox(height: 14),
        if (users.isEmpty) const EmptyCard(icon: Icons.people_alt_rounded, title: 'No users found', subtitle: 'Registered users will appear here.'),
        for (final user in users) ...[
          GlassCard(
            child: Row(
              children: [
                CircleAvatar(backgroundColor: const Color(0xFFFFE4E1), child: Text(_initial(user['full_name'] ?? user['email']))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((user['full_name'] ?? 'User').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text((user['email'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF7B646B))),
                      Text('Role: ${user['role'] ?? 'user'}', style: const TextStyle(fontSize: 12, color: Color(0xFF7B646B))),
                    ],
                  ),
                ),
                if (isSuperAdmin)
                  PopupMenuButton<String>(
                    onSelected: (role) => onRole(user, role),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'user', child: Text('User')),
                      PopupMenuItem(value: 'sub_admin', child: Text('Sub admin')),
                      PopupMenuItem(value: 'super_admin', child: Text('Super admin')),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class GalleriesPage extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  const GalleriesPage({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Galleries', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF33262B))),
        const SizedBox(height: 14),
        if (events.isEmpty) const EmptyCard(icon: Icons.collections_rounded, title: 'No galleries found', subtitle: 'Created event galleries will appear here.'),
        for (final event in events) ...[
          GlassCard(
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: const Color(0xFFFFE4E1), borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.collections_rounded, color: Color(0xFF9B5367)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((event['title'] ?? event['name'] ?? 'Gallery').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('${event['event_type'] ?? event['event_kind'] ?? 'Event'} • ${event['media_count'] ?? 0} uploads', style: const TextStyle(fontSize: 12, color: Color(0xFF7B646B))),
                      Text((event['owner_email'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF7B646B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class AdminApi {
  static Future<bool> checkAdminAccess() async {
    try {
      final me = await adminMe();
      return me['allowed'] == true;
    } catch (_) {
      final client = db;
      final user = client?.auth.currentUser;
      if (client == null || user == null) return false;
      try {
        final profile = await client.from('profiles').select('role,is_super_admin').eq('id', user.id).maybeSingle();
        final role = (profile?['role'] ?? '').toString().toLowerCase();
        return profile?['is_super_admin'] == true || role == 'super_admin' || role == 'sub_admin' || role == 'admin';
      } catch (_) {
        return false;
      }
    }
  }

  static Future<Map<String, dynamic>> adminMe() async {
    final result = await db!.rpc('app_admin_me');
    return _asMap(result);
  }

  static Future<Map<String, dynamic>> overview() async {
    final result = await db!.rpc('app_admin_overview');
    return _asMap(result);
  }

  static Future<List<Map<String, dynamic>>> listTickets() async {
    final result = await db!.rpc('app_admin_list_tickets');
    return _asList(result);
  }

  static Future<List<Map<String, dynamic>>> listUsers() async {
    final result = await db!.rpc('app_admin_list_users');
    return _asList(result);
  }

  static Future<List<Map<String, dynamic>>> listEvents() async {
    final result = await db!.rpc('app_admin_list_events');
    return _asList(result);
  }

  static Future<void> replyTicket(String id, String reply) async {
    await db!.rpc('app_admin_reply_ticket', params: {'p_ticket_id': id, 'p_reply': reply});
  }

  static Future<void> setUserRole(String id, String role) async {
    await db!.rpc('app_admin_set_user_role', params: {'p_user_id': id, 'p_role': role});
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value.map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)).toList();
    }
    return <Map<String, dynamic>>[];
  }
}

class AdminBackground extends StatelessWidget {
  final Widget child;
  const AdminBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF8F5), Color(0xFFF8E1DD), Color(0xFFFFFBF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -80, right: -70, child: _Glow(size: 190, color: Color(0xFFE8A7A5))),
          Positioned(bottom: 120, left: -90, child: _Glow(size: 220, color: Color(0xFFF0C7BC))),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.25)),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.78),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(.55)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF9B5367).withOpacity(.10), blurRadius: 28, offset: const Offset(0, 14)),
        ],
      ),
      child: child,
    );
  }
}

class AdminInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  const AdminInput({super.key, required this.controller, required this.label, required this.icon, this.obscureText = false, this.suffix, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(.82),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: const Color(0xFF9B5367).withOpacity(.18))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF9B5367), width: 1.4)),
      ),
    );
  }
}

class StatItem {
  final String title;
  final dynamic value;
  final IconData icon;
  StatItem(this.title, this.value, this.icon);
}

class StatCard extends StatelessWidget {
  final StatItem item;
  const StatCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(item.icon, color: const Color(0xFF9B5367)),
          Text('${item.value ?? 0}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF33262B))),
          Text(item.title, style: const TextStyle(fontSize: 13, color: Color(0xFF7B646B))),
        ],
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyCard({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          CircleAvatar(radius: 28, backgroundColor: const Color(0xFFFFE4E1), child: Icon(icon, color: const Color(0xFF9B5367))),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF7B646B))),
        ],
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const ErrorPanel({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFF9C2339), size: 36),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF7B2635))),
              const SizedBox(height: 14),
              FilledButton(onPressed: onRetry, child: const Text('Try Again')),
            ],
          ),
        ),
      ),
    );
  }
}

String _initial(dynamic value) {
  final text = (value ?? 'A').toString().trim();
  if (text.isEmpty) return 'A';
  return text.substring(0, 1).toUpperCase();
}

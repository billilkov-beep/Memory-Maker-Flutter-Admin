import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env').catchError((_) async {});
  final url = dotenv.env['SUPABASE_URL'] ?? '';
  final anon = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (url.isEmpty || anon.isEmpty) {
    runApp(const MissingEnvApp());
    return;
  }
  await Supabase.initialize(url: url, anonKey: anon);
  runApp(const MemoryMakerAdminApp());
}

class MissingEnvApp extends StatelessWidget {
  const MissingEnvApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Missing .env values. Add SUPABASE_URL and SUPABASE_ANON_KEY, then rebuild.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9F5A6C)),
        scaffoldBackgroundColor: const Color(0xFFFFF7F2),
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

class AdminApi {
  AdminApi(this.client);
  final SupabaseClient client;

  Future<Map<String, dynamic>?> me() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final res = await client.rpc('app_admin_me');
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }

  Future<Map<String, dynamic>> overview() async => Map<String, dynamic>.from(await client.rpc('app_admin_overview'));
  Future<List<Map<String, dynamic>>> tickets() async => _list(await client.rpc('app_admin_list_tickets'));
  Future<List<Map<String, dynamic>>> users() async => _list(await client.rpc('app_admin_list_users'));
  Future<List<Map<String, dynamic>>> events() async => _list(await client.rpc('app_admin_list_events'));
  Future<List<Map<String, dynamic>>> notifications() async => _list(await client.rpc('app_admin_list_notifications'));
  Future<List<Map<String, dynamic>>> media(String eventId) async => _list(await client.rpc('app_admin_list_media', params: {'p_event_id': eventId}));

  Future<void> replyTicket(String ticketId, String reply) async {
    await client.rpc('app_admin_reply_ticket', params: {'p_ticket_id': ticketId, 'p_reply': reply});
  }

  Future<void> updateTicketStatus(String ticketId, String status) async {
    await client.rpc('app_admin_update_ticket_status', params: {'p_ticket_id': ticketId, 'p_status': status});
  }

  Future<void> setUserRole(String userId, String role) async {
    await client.rpc('app_admin_set_user_role', params: {'p_user_id': userId, 'p_role': role});
  }

  List<Map<String, dynamic>> _list(dynamic res) {
    if (res is List) return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return <Map<String, dynamic>>[];
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _sub;
  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) => setState(() {}));
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session == null ? const LoginPage() : const AdminAccessCheck();
  }
}

class AdminAccessCheck extends StatefulWidget {
  const AdminAccessCheck({super.key});
  @override
  State<AdminAccessCheck> createState() => _AdminAccessCheckState();
}

class _AdminAccessCheckState extends State<AdminAccessCheck> {
  late final AdminApi api;
  Future<Map<String, dynamic>?>? future;
  @override
  void initState() {
    super.initState();
    api = AdminApi(Supabase.instance.client);
    future = api.me();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingScreen(text: 'Checking admin access...');
        if (snap.hasError || snap.data == null || snap.data!['allowed'] != true) {
          return AccessDenied(error: snap.error?.toString());
        }
        return AdminHome(me: snap.data!);
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool showPassword = false;
  String? error;

  Future<void> login() async {
    setState(() { loading = true; error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'Login failed. Please check your email and password.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    final mail = email.text.trim();
    if (mail.isEmpty) {
      setState(() => error = 'Enter your admin email first.');
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(mail);
      if (mounted) showToast(context, 'Password reset email sent.');
    } catch (_) {
      if (mounted) showToast(context, 'Could not send reset email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShellBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: GlassCard(
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LogoHeader(title: 'Memory Maker Admin', subtitle: 'Secure control panel for support, users and galleries.'),
                  const SizedBox(height: 26),
                  AdminTextField(controller: email, label: 'Admin email', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  AdminTextField(
                    controller: password,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscure: !showPassword,
                    suffix: IconButton(
                      onPressed: () => setState(() => showPassword = !showPassword),
                      icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    ErrorBox(error!),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: loading ? null : login,
                    icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                    label: Text(loading ? 'Signing in...' : 'Login'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xFF9F5A6C)),
                  ),
                  TextButton(onPressed: resetPassword, child: const Text('Forgot password? Send reset email')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccessDenied extends StatelessWidget {
  const AccessDenied({super.key, this.error});
  final String? error;
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return ShellBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 56, color: Color(0xFF9F5A6C)),
                const SizedBox(height: 14),
                const Text('Admin access required', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('Signed in as ${user?.email ?? 'unknown'} but this account is not marked as super_admin or sub_admin.', textAlign: TextAlign.center),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                const SizedBox(height: 20),
                FilledButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Logout')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.me});
  final Map<String, dynamic> me;
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int index = 0;
  late final AdminApi api;
  @override
  void initState() {
    super.initState();
    api = AdminApi(Supabase.instance.client);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      OverviewPage(api: api),
      TicketsPage(api: api),
      UsersPage(api: api, isSuperAdmin: widget.me['is_super_admin'] == true || widget.me['role'] == 'super_admin'),
      GalleriesPage(api: api),
      SettingsPage(me: widget.me),
    ];
    return ShellBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Memory Maker Admin', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh)),
            IconButton(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout)),
          ],
        ),
        body: SafeArea(child: pages[index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Tickets'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
            NavigationDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library), label: 'Galleries'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Future<Map<String, dynamic>>? future;
  @override
  void initState() { super.initState(); future = widget.api.overview(); }
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => future = widget.api.overview()),
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingList();
          final d = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const PageTitle('Overview', 'Live public beta operations dashboard.'),
              GridWrap(children: [
                StatCard(title: 'Users', value: '${d['users_count'] ?? 0}', icon: Icons.people),
                StatCard(title: 'Galleries', value: '${d['events_count'] ?? 0}', icon: Icons.photo_library),
                StatCard(title: 'Uploads', value: '${d['uploads_count'] ?? 0}', icon: Icons.cloud_upload),
                StatCard(title: 'Open Tickets', value: '${d['open_tickets_count'] ?? 0}', icon: Icons.support_agent),
              ]),
              const SizedBox(height: 16),
              const GlassCard(
                child: ListTile(
                  leading: Icon(Icons.verified_user_outlined),
                  title: Text('Admin app is connected'),
                  subtitle: Text('Use Tickets to reply, Users to view accounts, and Galleries to inspect public beta event spaces.'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  Future<List<Map<String, dynamic>>>? future;
  @override
  void initState() { super.initState(); future = widget.api.tickets(); }
  Future<void> refresh() async => setState(() => future = widget.api.tickets());

  Future<void> reply(Map<String, dynamic> t) async {
    final c = TextEditingController(text: (t['admin_reply'] ?? '').toString());
    final reply = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply to ${t['user_email'] ?? 'user'}'),
        content: TextField(controller: c, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'Admin reply')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Send reply')),
        ],
      ),
    );
    if (reply == null || reply.trim().isEmpty) return;
    try {
      await widget.api.replyTicket(t['id'].toString(), reply.trim());
      if (mounted) showToast(context, 'Reply sent and notification created.');
      refresh();
    } catch (_) {
      if (mounted) showToast(context, 'Could not send reply.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => refresh(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingList();
          final items = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const PageTitle('Support Tickets', 'Read user issues, send replies, and close resolved tickets.'),
              if (items.isEmpty) const EmptyCard(icon: Icons.support_agent, title: 'No tickets yet', subtitle: 'New support requests will appear here.'),
              for (final t in items) TicketCard(ticket: t, onReply: () => reply(t), onClose: () async { await widget.api.updateTicketStatus(t['id'].toString(), 'closed'); refresh(); }),
            ],
          );
        },
      ),
    );
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.api, required this.isSuperAdmin});
  final AdminApi api;
  final bool isSuperAdmin;
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  Future<List<Map<String, dynamic>>>? future;
  @override
  void initState() { super.initState(); future = widget.api.users(); }
  Future<void> refresh() async => setState(() => future = widget.api.users());
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => refresh(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingList();
          final users = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const PageTitle('Users', 'View registered users and assign admin roles.'),
              if (users.isEmpty) const EmptyCard(icon: Icons.people, title: 'No users found', subtitle: 'Registered users will appear here.'),
              for (final u in users) UserCard(user: u, canEdit: widget.isSuperAdmin, onSetRole: (role) async { await widget.api.setUserRole(u['id'].toString(), role); refresh(); }),
            ],
          );
        },
      ),
    );
  }
}

class GalleriesPage extends StatefulWidget {
  const GalleriesPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<GalleriesPage> createState() => _GalleriesPageState();
}

class _GalleriesPageState extends State<GalleriesPage> {
  Future<List<Map<String, dynamic>>>? future;
  @override
  void initState() { super.initState(); future = widget.api.events(); }
  Future<void> refresh() async => setState(() => future = widget.api.events());
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => refresh(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingList();
          final events = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const PageTitle('Galleries', 'Inspect event spaces and upload counts.'),
              if (events.isEmpty) const EmptyCard(icon: Icons.photo_library, title: 'No galleries yet', subtitle: 'User-created galleries will show here.'),
              for (final e in events) GalleryCard(event: e),
            ],
          );
        },
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.me});
  final Map<String, dynamic> me;
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const PageTitle('Settings', 'Admin session and account details.'),
        GlassCard(
          child: Column(
            children: [
              ListTile(
                leading: Avatar(profile: me),
                title: Text(me['full_name']?.toString().isNotEmpty == true ? me['full_name'] : 'Admin'),
                subtitle: Text(user?.email ?? ''),
              ),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.shield_outlined), title: const Text('Role'), subtitle: Text('${me['role'] ?? 'admin'}')),
              ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: () => Supabase.instance.client.auth.signOut()),
            ],
          ),
        ),
      ],
    );
  }
}

class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.ticket, required this.onReply, required this.onClose});
  final Map<String, dynamic> ticket;
  final VoidCallback onReply;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(ticket['subject']?.toString() ?? 'Support request', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
            Chip(label: Text(ticket['status']?.toString() ?? 'open')),
          ]),
          Text(ticket['user_email']?.toString() ?? 'No email', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Text(ticket['message']?.toString() ?? ''),
          if ((ticket['admin_reply'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8E9E8), borderRadius: BorderRadius.circular(16)),
              child: Text('Reply: ${ticket['admin_reply']}'),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: onReply, icon: const Icon(Icons.reply), label: const Text('Reply'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(onPressed: onClose, icon: const Icon(Icons.check), label: const Text('Close'))),
          ]),
        ]),
      ),
    );
  }
}

class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.user, required this.canEdit, required this.onSetRole});
  final Map<String, dynamic> user;
  final bool canEdit;
  final Future<void> Function(String role) onSetRole;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Avatar(profile: user),
        title: Text(user['full_name']?.toString().isNotEmpty == true ? user['full_name'] : user['email'] ?? 'User'),
        subtitle: Text('${user['email'] ?? ''}\nRole: ${user['role'] ?? 'user'}'),
        isThreeLine: true,
        trailing: canEdit ? PopupMenuButton<String>(
          onSelected: (v) => onSetRole(v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'user', child: Text('Make user')),
            PopupMenuItem(value: 'sub_admin', child: Text('Make sub admin')),
            PopupMenuItem(value: 'super_admin', child: Text('Make super admin')),
          ],
        ) : null,
      ),
    );
  }
}

class GalleryCard extends StatelessWidget {
  const GalleryCard({super.key, required this.event});
  final Map<String, dynamic> event;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFFF5DDE0), child: Icon(Icons.photo_library, color: Color(0xFF9F5A6C))),
        title: Text(event['title']?.toString() ?? 'Memory Gallery', style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${event['event_kind'] ?? event['event_type'] ?? 'Event'} • ${event['owner_email'] ?? 'No owner'}\nUploads: ${event['media_count'] ?? 0} • Status: ${event['status'] ?? 'active'}'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.profile});
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) {
    final image = avatarProvider(profile);
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFF5DDE0),
      backgroundImage: image,
      child: image == null ? const Icon(Icons.person, color: Color(0xFF9F5A6C)) : null,
    );
  }
}

ImageProvider? avatarProvider(Map<String, dynamic> p) {
  final base64 = (p['avatar_base64'] ?? '').toString();
  if (base64.startsWith('data:image')) return NetworkImage(base64);
  if (base64.length > 100) return NetworkImage('data:image/jpeg;base64,$base64');
  for (final k in ['avatar_url', 'profile_picture_url', 'profile_photo_url', 'image_url', 'photo_url']) {
    final v = (p[k] ?? '').toString();
    if (v.startsWith('http') || v.startsWith('data:image')) return NetworkImage(v);
  }
  return null;
}

class ShellBackground extends StatelessWidget {
  const ShellBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF7F2), Color(0xFFFCE4DF), Color(0xFFFFFBF7)],
        ),
      ),
      child: child,
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding, this.margin});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(.9)),
        boxShadow: [BoxShadow(color: const Color(0xFF9F5A6C).withOpacity(.13), blurRadius: 34, offset: const Offset(0, 18))],
      ),
      child: child,
    );
  }
}

class LogoHeader extends StatelessWidget {
  const LogoHeader({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFB87281), width: 2)),
          child: const Icon(Icons.admin_panel_settings, color: Color(0xFF9F5A6C), size: 34),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
      ]),
      const SizedBox(height: 10),
      Text(subtitle, style: const TextStyle(color: Colors.black54)),
    ]);
  }
}

class AdminTextField extends StatelessWidget {
  const AdminTextField({super.key, required this.controller, required this.label, required this.icon, this.obscure = false, this.suffix, this.keyboard});
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboard;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ]),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFF9F5A6C)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          Text(title, style: const TextStyle(color: Colors.black54)),
        ]),
      ),
    );
  }
}

class GridWrap extends StatelessWidget {
  const GridWrap({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: children,
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        CircleAvatar(radius: 34, backgroundColor: const Color(0xFFF5DDE0), child: Icon(icon, color: const Color(0xFF9F5A6C), size: 34)),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
      ]),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => ShellBackground(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(text)])));
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFFFE1E5), borderRadius: BorderRadius.circular(16)),
    child: Text(text, style: const TextStyle(color: Color(0xFF9D2636))),
  );
}

void showToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

String fmt(dynamic v) {
  if (v == null) return '-';
  final dt = DateTime.tryParse(v.toString());
  if (dt == null) return v.toString();
  return DateFormat('MMM d, y • h:mm a').format(dt.toLocal());
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kInk = Color(0xFF231A1D);
const kPrimary = Color(0xFF8D5062);
const kPrimaryDark = Color(0xFF5E2C3A);
const kGold = Color(0xFFD8A05F);
const kBlush = Color(0xFFFFF7F2);
const kSoft = Color(0xFFF6DFE3);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);
  await dotenv.load(fileName: '.env').catchError((_) async {});
  final url = dotenv.env['SUPABASE_URL'] ?? '';
  final anon = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (url.trim().isEmpty || anon.trim().isEmpty) {
    runApp(const SimpleMessageApp(message: 'App setup is not complete. Please contact the system owner.'));
    return;
  }
  try {
    await Supabase.initialize(url: url.trim(), anonKey: anon.trim());
    runApp(const AdminApp());
  } catch (_) {
    runApp(const SimpleMessageApp(message: 'Could not connect to Memory Maker Admin. Please try again later.'));
  }
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Maker Admin',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final data = MediaQuery.of(context);
        return MediaQuery(data: data.copyWith(textScaleFactor: 1.0), child: child ?? const SizedBox.shrink());
      },
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBlush,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, primary: kPrimary, surface: Colors.white),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, centerTitle: false, foregroundColor: kInk),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(.94),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: kPrimary.withOpacity(.18))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: kPrimary.withOpacity(.16))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SimpleMessageApp extends StatelessWidget {
  const SimpleMessageApp({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0), child: child ?? const SizedBox.shrink()),
      home: AdminBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GlassCard(child: Padding(padding: const EdgeInsets.all(22), child: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)))),
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    Timer(const Duration(milliseconds: 1250), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const AuthGate()));
    });
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AdminBackground(
      child: Center(
        child: ScaleTransition(
          scale: CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
          child: Column(mainAxisSize: MainAxisSize.min, children: const <Widget>[
            BrandLogo(size: 112),
            SizedBox(height: 18),
            Text('Memory Maker Admin', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kInk)),
            SizedBox(height: 6),
            Text('Secure control panel', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? authSub;
  @override
  void initState() {
    super.initState();
    authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { authSub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session == null ? const LoginPage() : const AccessGate();
  }
}

class AdminApi {
  AdminApi(this.client);
  final SupabaseClient client;
  List<Map<String, dynamic>> asList(dynamic value) {
    if (value is List) return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return <Map<String, dynamic>>[];
  }
  Future<Map<String, dynamic>> me() async => Map<String, dynamic>.from(await client.rpc('app_admin_me') as Map);
  Future<Map<String, dynamic>> overview() async => Map<String, dynamic>.from(await client.rpc('app_admin_overview') as Map);
  Future<List<Map<String, dynamic>>> tickets() async => asList(await client.rpc('app_admin_list_tickets'));
  Future<List<Map<String, dynamic>>> users() async => asList(await client.rpc('app_admin_list_users'));
  Future<List<Map<String, dynamic>>> events() async => asList(await client.rpc('app_admin_list_events'));
  Future<List<Map<String, dynamic>>> media(String eventId) async => asList(await client.rpc('app_admin_list_media', params: <String, dynamic>{'p_event_id': eventId}));
  Future<void> replyTicket(String id, String reply) async { await client.rpc('app_admin_reply_ticket', params: <String, dynamic>{'p_ticket_id': id, 'p_reply': reply}); }
  Future<void> closeTicket(String id) async { await client.rpc('app_admin_update_ticket_status', params: <String, dynamic>{'p_ticket_id': id, 'p_status': 'closed'}); }
  Future<void> setRole(String id, String role) async { await client.rpc('app_admin_set_user_role', params: <String, dynamic>{'p_user_id': id, 'p_role': role}); }
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
  bool show = false;
  String? error;
  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> login() async {
    FocusScope.of(context).unfocus();
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Please enter admin email and password.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
    } on AuthException catch (e) {
      setState(() => error = cleanError(e.message));
    } catch (_) {
      setState(() => error = 'Login failed. Please check admin access and try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    if (email.text.trim().isEmpty) { showToast(context, 'Enter your admin email first.'); return; }
    try { await Supabase.instance.client.auth.resetPasswordForEmail(email.text.trim()); if (mounted) showToast(context, 'Password reset email sent.'); }
    catch (_) { if (mounted) showToast(context, 'Could not send reset email.'); }
  }

  @override
  Widget build(BuildContext context) {
    return AdminBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                    const Center(child: BrandLogo(size: 86)),
                    const SizedBox(height: 16),
                    const Text('Memory Maker Admin', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, height: 1.08, fontWeight: FontWeight.w900, color: kInk)),
                    const SizedBox(height: 8),
                    Center(child: Container(width: 88, height: 3, decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(99)))),
                    const SizedBox(height: 18),
                    const Text('Admin Console', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, height: 1.06, fontWeight: FontWeight.w900, color: kInk)),
                    const SizedBox(height: 8),
                    const Text('Manage support tickets, users, galleries and uploads from one secure mobile dashboard.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, height: 1.4, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 22),
                    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Admin email', prefixIcon: Icon(Icons.email_outlined))),
                    const SizedBox(height: 14),
                    TextField(controller: password, obscureText: !show, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => show = !show), icon: Icon(show ? Icons.visibility_off : Icons.visibility)))),
                    if (error != null) ...<Widget>[const SizedBox(height: 14), ErrorBox(error!)],
                    const SizedBox(height: 18),
                    FilledButton.icon(onPressed: loading ? null : login, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded), label: Text(loading ? 'Signing in...' : 'Login')),
                    TextButton(onPressed: loading ? null : resetPassword, child: const Text('Forgot password? Send reset email')),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccessGate extends StatefulWidget {
  const AccessGate({super.key});
  @override
  State<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<AccessGate> {
  late Future<Map<String, dynamic>> future;
  late final AdminApi api;
  @override
  void initState() { super.initState(); api = AdminApi(Supabase.instance.client); future = api.me(); }
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingScreen(text: 'Opening secure admin panel...');
        if (snap.hasError) return AccessDenied(message: 'Admin setup is not complete. Please run the admin SQL migration and try again.', onRetry: () => setState(() => future = api.me()));
        final data = snap.data ?? <String, dynamic>{};
        if (data['allowed'] != true) return AccessDenied(message: 'This account does not have admin access.', onRetry: () => Supabase.instance.client.auth.signOut());
        return AdminHome(api: api, me: data);
      },
    );
  }
}

class AccessDenied extends StatelessWidget {
  const AccessDenied({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return AdminBackground(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: GlassCard(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      const BrandLogo(size: 78),
      const SizedBox(height: 16),
      const Text('Access not available', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kInk)),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.4)),
      const SizedBox(height: 18),
      FilledButton(onPressed: onRetry, child: const Text('Continue')),
    ])))));
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.api, required this.me});
  final AdminApi api;
  final Map<String, dynamic> me;
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final superAdmin = widget.me['is_super_admin'] == true || widget.me['role']?.toString() == 'super_admin';
    final pages = <Widget>[
      OverviewPage(api: widget.api),
      TicketsPage(api: widget.api),
      UsersPage(api: widget.api, superAdmin: superAdmin),
      GalleriesPage(api: widget.api),
      SettingsPage(me: widget.me),
    ];
    return AdminBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Row(children: <Widget>[BrandLogo(size: 36), SizedBox(width: 10), Expanded(child: Text('Memory Maker Admin', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900)))]),
          actions: <Widget>[IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh_rounded)), IconButton(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout_rounded))],
        ),
        body: SafeArea(child: pages[index]),
        bottomNavigationBar: NavigationBar(
          height: 72,
          selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
          backgroundColor: Colors.white.withOpacity(.94),
          destinations: const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent_rounded), label: 'Tickets'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Users'),
            NavigationDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library_rounded), label: 'Galleries'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class OverviewPage extends StatefulWidget { const OverviewPage({super.key, required this.api}); final AdminApi api; @override State<OverviewPage> createState() => _OverviewPageState(); }
class _OverviewPageState extends State<OverviewPage> { late Future<Map<String, dynamic>> future; @override void initState(){ super.initState(); future = widget.api.overview(); } void refresh(){ setState(() => future = widget.api.overview()); }
  @override Widget build(BuildContext context){ return FutureBuilder<Map<String, dynamic>>(future: future, builder: (context, snap){ if(snap.hasError) return ErrorState(onRetry: refresh); if(!snap.hasData) return const LoadingList(); final d=snap.data!; return ListView(padding: const EdgeInsets.all(18), children: <Widget>[const PageTitle('Overview','Live beta operations dashboard.'), GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.18, children: <Widget>[StatCard('Users', '${d['users_count']??0}', Icons.people_rounded), StatCard('Galleries', '${d['events_count']??0}', Icons.photo_library_rounded), StatCard('Uploads', '${d['uploads_count']??0}', Icons.cloud_upload_rounded), StatCard('Open Tickets', '${d['open_tickets_count']??0}', Icons.support_agent_rounded)]), const SizedBox(height: 16), const GlassCard(child: ListTile(leading: Icon(Icons.verified_user_outlined, color: kPrimary), title: Text('Admin app connected', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Manage tickets, users and galleries securely.')))]); }); }}

class TicketsPage extends StatefulWidget { const TicketsPage({super.key, required this.api}); final AdminApi api; @override State<TicketsPage> createState() => _TicketsPageState(); }
class _TicketsPageState extends State<TicketsPage> { late Future<List<Map<String,dynamic>>> future; @override void initState(){ super.initState(); future = widget.api.tickets(); } void refresh(){ setState(() => future = widget.api.tickets()); }
  Future<void> reply(Map<String,dynamic> t) async { final c=TextEditingController(text:(t['admin_reply']??'').toString()); final r=await showDialog<String>(context: context, builder: (dialogContext)=>AlertDialog(title: const Text('Send support reply'), content: TextField(controller:c, minLines:4, maxLines:8, decoration: const InputDecoration(labelText:'Reply message')), actions:<Widget>[TextButton(onPressed:()=>Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed:()=>Navigator.pop(dialogContext,c.text.trim()), child: const Text('Send'))])); c.dispose(); if(r==null||r.isEmpty)return; try{ await widget.api.replyTicket(t['id'].toString(), r); if(mounted) showToast(context,'Reply sent.'); refresh(); }catch(_){ if(mounted) showToast(context,'Could not send reply.'); } }
  @override Widget build(BuildContext context){ return FutureBuilder<List<Map<String,dynamic>>>(future: future, builder:(context,snap){ if(snap.hasError) return ErrorState(onRetry: refresh); if(!snap.hasData) return const LoadingList(); final items=snap.data!; return RefreshIndicator(onRefresh:() async=>refresh(), child: ListView(padding: const EdgeInsets.all(18), children:<Widget>[const PageTitle('Support Tickets','Read user requests and send replies.'), if(items.isEmpty) const EmptyCard(icon: Icons.support_agent_rounded, title:'No tickets yet', subtitle:'New support requests will appear here.'), for(final t in items) TicketCard(ticket:t, onReply:()=>reply(t), onClose:() async{ try{ await widget.api.closeTicket(t['id'].toString()); refresh(); }catch(_){ if(mounted) showToast(context,'Could not close ticket.'); }})])); }); }}

class UsersPage extends StatefulWidget { const UsersPage({super.key, required this.api, required this.superAdmin}); final AdminApi api; final bool superAdmin; @override State<UsersPage> createState() => _UsersPageState(); }
class _UsersPageState extends State<UsersPage> { late Future<List<Map<String,dynamic>>> future; @override void initState(){ super.initState(); future=widget.api.users(); } void refresh(){ setState(()=>future=widget.api.users()); }
  @override Widget build(BuildContext context){ return FutureBuilder<List<Map<String,dynamic>>>(future: future, builder:(context,snap){ if(snap.hasError)return ErrorState(onRetry:refresh); if(!snap.hasData)return const LoadingList(); final users=snap.data!; return RefreshIndicator(onRefresh:() async=>refresh(), child: ListView(padding: const EdgeInsets.all(18), children:<Widget>[const PageTitle('Users','View accounts and assign admin roles.'), if(users.isEmpty) const EmptyCard(icon: Icons.people_rounded, title:'No users found', subtitle:'Registered users will show here.'), for(final u in users) UserCard(user:u, canEdit:widget.superAdmin, onRole:(role) async{ try{ await widget.api.setRole(u['id'].toString(), role); refresh(); }catch(_){ if(mounted) showToast(context,'Could not update role.'); }})])); }); }}

class GalleriesPage extends StatefulWidget { const GalleriesPage({super.key, required this.api}); final AdminApi api; @override State<GalleriesPage> createState()=>_GalleriesPageState(); }
class _GalleriesPageState extends State<GalleriesPage> { late Future<List<Map<String,dynamic>>> future; @override void initState(){ super.initState(); future=widget.api.events(); } void refresh(){ setState(()=>future=widget.api.events()); }
  @override Widget build(BuildContext context){ return FutureBuilder<List<Map<String,dynamic>>>(future: future, builder:(context,snap){ if(snap.hasError)return ErrorState(onRetry:refresh); if(!snap.hasData)return const LoadingList(); final events=snap.data!; return RefreshIndicator(onRefresh:() async=>refresh(), child: ListView(padding: const EdgeInsets.all(18), children:<Widget>[const PageTitle('Galleries','Inspect event spaces and upload counts.'), if(events.isEmpty) const EmptyCard(icon: Icons.photo_library_rounded, title:'No galleries yet', subtitle:'User galleries will appear here.'), for(final e in events) GalleryCard(event:e, onTap:()=>Navigator.push(context, MaterialPageRoute<void>(builder:(_)=>GalleryMediaPage(api:widget.api, event:e))))])); }); }}

class GalleryMediaPage extends StatefulWidget { const GalleryMediaPage({super.key, required this.api, required this.event}); final AdminApi api; final Map<String,dynamic> event; @override State<GalleryMediaPage> createState()=>_GalleryMediaPageState(); }
class _GalleryMediaPageState extends State<GalleryMediaPage> { late Future<List<Map<String,dynamic>>> future; @override void initState(){ super.initState(); future=widget.api.media(widget.event['id'].toString()); } void refresh(){ setState(()=>future=widget.api.media(widget.event['id'].toString())); }
  @override Widget build(BuildContext context){ return AdminBackground(child: Scaffold(backgroundColor: Colors.transparent, appBar: AppBar(title: Text(widget.event['title']?.toString()??'Gallery')), body: FutureBuilder<List<Map<String,dynamic>>>(future: future, builder:(context,snap){ if(snap.hasError)return ErrorState(onRetry:refresh); if(!snap.hasData)return const LoadingList(); final items=snap.data!; return ListView(padding: const EdgeInsets.all(18), children:<Widget>[if(items.isEmpty) const EmptyCard(icon:Icons.image_rounded, title:'No uploads yet', subtitle:'Uploads will show here.'), for(final m in items) MediaTile(item:m)]); }))); }}

class SettingsPage extends StatelessWidget { const SettingsPage({super.key, required this.me}); final Map<String,dynamic> me; @override Widget build(BuildContext context){ final user=Supabase.instance.client.auth.currentUser; return ListView(padding: const EdgeInsets.all(18), children:<Widget>[const PageTitle('Settings','Admin account and session.'), GlassCard(child: Column(children:<Widget>[ListTile(leading: Avatar(profile:me), title: Text(nonEmpty(me['full_name']) ? me['full_name'].toString() : 'Admin', style: const TextStyle(fontWeight:FontWeight.w900)), subtitle: Text(user?.email??'')), const Divider(height:1), ListTile(leading: const Icon(Icons.shield_outlined, color:kPrimary), title: const Text('Role'), subtitle: Text(me['role']?.toString()??'admin')), ListTile(leading: const Icon(Icons.logout_rounded, color:kPrimary), title: const Text('Logout'), onTap:()=>Supabase.instance.client.auth.signOut())]))]); }}

class TicketCard extends StatelessWidget { const TicketCard({super.key, required this.ticket, required this.onReply, required this.onClose}); final Map<String,dynamic> ticket; final VoidCallback onReply; final VoidCallback onClose; @override Widget build(BuildContext context){ return GlassCard(margin: const EdgeInsets.only(bottom:14), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:<Widget>[Row(children:<Widget>[Expanded(child: Text(ticket['subject']?.toString()??'Support request', style: const TextStyle(fontWeight: FontWeight.w900, fontSize:17, color:kInk))), StatusPill(ticket['status']?.toString()??'open')]), const SizedBox(height:4), Text(ticket['user_email']?.toString()??'No email', style: const TextStyle(color:Colors.black54)), const SizedBox(height:10), Text(ticket['message']?.toString()??'', style: const TextStyle(height:1.35)), if(nonEmpty(ticket['admin_reply'])) ...<Widget>[const SizedBox(height:12), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color:kSoft.withOpacity(.5), borderRadius: BorderRadius.circular(16)), child: Text('Reply: ${ticket['admin_reply']}', style: const TextStyle(fontWeight: FontWeight.w600)))], const SizedBox(height:12), Row(children:<Widget>[Expanded(child: OutlinedButton.icon(onPressed:onReply, icon: const Icon(Icons.reply_rounded), label: const Text('Reply'))), const SizedBox(width:10), Expanded(child: FilledButton.icon(onPressed:onClose, icon: const Icon(Icons.check_rounded), label: const Text('Close')))])]))); }}
class UserCard extends StatelessWidget { const UserCard({super.key, required this.user, required this.canEdit, required this.onRole}); final Map<String,dynamic> user; final bool canEdit; final Future<void> Function(String role) onRole; @override Widget build(BuildContext context){ return GlassCard(margin: const EdgeInsets.only(bottom:12), child: ListTile(leading: Avatar(profile:user), title: Text(nonEmpty(user['full_name']) ? user['full_name'].toString() : (user['email']?.toString()??'User'), style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${user['email']??''}\nRole: ${user['role']??'user'}'), isThreeLine: true, trailing: canEdit ? PopupMenuButton<String>(onSelected:onRole, itemBuilder:(_)=>const <PopupMenuEntry<String>>[PopupMenuItem(value:'user', child:Text('Make user')), PopupMenuItem(value:'sub_admin', child:Text('Make sub admin')), PopupMenuItem(value:'super_admin', child:Text('Make super admin'))]) : null)); }}
class GalleryCard extends StatelessWidget { const GalleryCard({super.key, required this.event, required this.onTap}); final Map<String,dynamic> event; final VoidCallback onTap; @override Widget build(BuildContext context){ return GlassCard(margin: const EdgeInsets.only(bottom:12), child: ListTile(onTap:onTap, leading: const CircleAvatar(backgroundColor:kSoft, child: Icon(Icons.photo_library_rounded, color:kPrimary)), title: Text(event['title']?.toString()??'Memory Gallery', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${event['event_kind']??event['event_type']??'Event'} • ${event['owner_email']??'No owner'}\nUploads: ${event['media_count']??0} • Guests: ${event['guests_count']??0}'), isThreeLine: true, trailing: const Icon(Icons.chevron_right_rounded))); }}
class MediaTile extends StatelessWidget { const MediaTile({super.key, required this.item}); final Map<String,dynamic> item; @override Widget build(BuildContext context){ final data=(item['data_url']??'').toString(); Widget image = const CircleAvatar(backgroundColor:kSoft, child: Icon(Icons.image_rounded, color:kPrimary)); if(data.startsWith('data:image')){ try{ image = Image.memory(base64Decode(data.split(',').last), width:58, height:58, fit:BoxFit.cover); }catch(_){ } } return GlassCard(margin: const EdgeInsets.only(bottom:12), child: ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(14), child:image), title: Text(item['original_filename']?.toString()??'Upload', style: const TextStyle(fontWeight:FontWeight.w900)), subtitle: Text('${item['status']??'approved'} • ${shortDate(item['created_at'])}\n${item['caption']??''}'), isThreeLine: true)); }}

class BrandLogo extends StatelessWidget { const BrandLogo({super.key, this.size = 72}); final double size; @override Widget build(BuildContext context){ return Container(width:size, height:size, decoration: BoxDecoration(color:Colors.white.withOpacity(.78), borderRadius: BorderRadius.circular(size*.28), border: Border.all(color:kPrimary.withOpacity(.52), width:2), boxShadow:<BoxShadow>[BoxShadow(color:kPrimary.withOpacity(.14), blurRadius:22, offset: const Offset(0,10))]), child: Stack(alignment: Alignment.center, children:<Widget>[Icon(Icons.admin_panel_settings_rounded, size:size*.48, color:kPrimary), Positioned(right:size*.17, bottom:size*.18, child: Container(width:size*.25, height:size*.25, decoration: const BoxDecoration(shape:BoxShape.circle, color:kPrimary), child: Icon(Icons.lock_rounded, size:size*.14, color:Colors.white)))])); }}
class Avatar extends StatelessWidget { const Avatar({super.key, required this.profile}); final Map<String,dynamic> profile; @override Widget build(BuildContext context){ final bytes=avatarBytes(profile); final provider=avatarProvider(profile); return CircleAvatar(radius:24, backgroundColor:kSoft, backgroundImage: bytes != null ? MemoryImage(bytes) : provider, child: bytes==null && provider==null ? const Icon(Icons.person_rounded, color:kPrimary) : null); }}
class AdminBackground extends StatelessWidget { const AdminBackground({super.key, required this.child}); final Widget child; @override Widget build(BuildContext context){ return Container(decoration: const BoxDecoration(gradient: LinearGradient(begin:Alignment.topLeft, end:Alignment.bottomRight, colors:<Color>[Color(0xFFFFF8F4), Color(0xFFFFE8E2), Color(0xFFFFFBF8)])), child: Stack(children:<Widget>[Positioned(top:-90,right:-70,child:DecorBlob(size:220)), Positioned(bottom:-80,left:-90,child:DecorBlob(size:240)), child])); }}
class DecorBlob extends StatelessWidget { const DecorBlob({super.key, required this.size}); final double size; @override Widget build(BuildContext context){ return Container(width:size,height:size,decoration:BoxDecoration(shape:BoxShape.circle, gradient:RadialGradient(colors:<Color>[kPrimary.withOpacity(.18), kPrimary.withOpacity(0)]))); }}
class GlassCard extends StatelessWidget { const GlassCard({super.key, required this.child, this.margin}); final Widget child; final EdgeInsetsGeometry? margin; @override Widget build(BuildContext context){ return Container(margin: margin, decoration: BoxDecoration(color:Colors.white.withOpacity(.84), borderRadius: BorderRadius.circular(28), border: Border.all(color:Colors.white.withOpacity(.92)), boxShadow:<BoxShadow>[BoxShadow(color:kPrimary.withOpacity(.12), blurRadius:34, offset: const Offset(0,18))]), child: child); }}
class PageTitle extends StatelessWidget { const PageTitle(this.title, this.subtitle, {super.key}); final String title; final String subtitle; @override Widget build(BuildContext context){ return Padding(padding: const EdgeInsets.only(bottom:16), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:<Widget>[Text(title, style: const TextStyle(fontSize:28, fontWeight:FontWeight.w900, color:kInk)), const SizedBox(height:4), Text(subtitle, style: const TextStyle(color:Colors.black54, height:1.35, fontWeight:FontWeight.w600))])); }}
class StatCard extends StatelessWidget { const StatCard(this.title, this.value, this.icon, {super.key}); final String title; final String value; final IconData icon; @override Widget build(BuildContext context){ return GlassCard(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:<Widget>[Icon(icon, color:kPrimary), const Spacer(), Text(value, style: const TextStyle(fontSize:27, fontWeight:FontWeight.w900, color:kInk)), Text(title, style: const TextStyle(color:Colors.black54, fontWeight:FontWeight.w700))]))); }}
class EmptyCard extends StatelessWidget { const EmptyCard({super.key, required this.icon, required this.title, required this.subtitle}); final IconData icon; final String title; final String subtitle; @override Widget build(BuildContext context){ return GlassCard(child: Padding(padding: const EdgeInsets.all(30), child: Column(children:<Widget>[CircleAvatar(radius:34, backgroundColor:kSoft, child: Icon(icon, color:kPrimary, size:34)), const SizedBox(height:16), Text(title, style: const TextStyle(fontSize:20, fontWeight:FontWeight.w900, color:kInk)), const SizedBox(height:6), Text(subtitle, textAlign:TextAlign.center, style: const TextStyle(color:Colors.black54))]))); }}
class ErrorState extends StatelessWidget { const ErrorState({super.key, required this.onRetry}); final VoidCallback onRetry; @override Widget build(BuildContext context){ return ListView(padding: const EdgeInsets.all(24), children:<Widget>[GlassCard(child: Padding(padding: const EdgeInsets.all(24), child: Column(children:<Widget>[const Icon(Icons.cloud_off_rounded, size:52, color:kPrimary), const SizedBox(height:12), const Text('Could not load data', style: TextStyle(fontSize:22, fontWeight:FontWeight.w900, color:kInk)), const SizedBox(height:6), const Text('Please run the latest admin SQL migration and refresh.', textAlign:TextAlign.center, style: TextStyle(color:Colors.black54)), const SizedBox(height:16), FilledButton(onPressed:onRetry, child: const Text('Refresh'))]))) ]); }}
class LoadingScreen extends StatelessWidget { const LoadingScreen({super.key, required this.text}); final String text; @override Widget build(BuildContext context){ return AdminBackground(child: Center(child: Column(mainAxisSize:MainAxisSize.min, children:<Widget>[const CircularProgressIndicator(color:kPrimary), const SizedBox(height:12), Text(text, style: const TextStyle(fontWeight:FontWeight.w800))]))); }}
class LoadingList extends StatelessWidget { const LoadingList({super.key}); @override Widget build(BuildContext context){ return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color:kPrimary))); }}
class ErrorBox extends StatelessWidget { const ErrorBox(this.text, {super.key}); final String text; @override Widget build(BuildContext context){ return Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFFE1E5), borderRadius: BorderRadius.circular(16)), child: Text(cleanError(text), maxLines:3, overflow:TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF9D2636), height:1.35, fontWeight:FontWeight.w800))); }}
class StatusPill extends StatelessWidget { const StatusPill(this.status, {super.key}); final String status; @override Widget build(BuildContext context){ return Container(padding: const EdgeInsets.symmetric(horizontal:10, vertical:6), decoration: BoxDecoration(color:kSoft, borderRadius: BorderRadius.circular(99)), child: Text(status.toUpperCase(), style: const TextStyle(color:kPrimaryDark, fontWeight:FontWeight.w900, fontSize:11))); }}

Uint8List? avatarBytes(Map<String,dynamic> p){ final v=(p['avatar_base64']??'').toString(); if(v.isEmpty)return null; try{return base64Decode(v.contains(',')?v.split(',').last:v);}catch(_){return null;} }
ImageProvider? avatarProvider(Map<String,dynamic> p){ for(final key in <String>['avatar_url','profile_picture_url','profile_photo_url','image_url','photo_url']){ final v=(p[key]??'').toString(); if(v.startsWith('http')) return NetworkImage(v); } return null; }
bool nonEmpty(dynamic value) => value != null && value.toString().trim().isNotEmpty;
String cleanError(String raw){ final r=raw.toLowerCase(); if(r.contains('invalid')||r.contains('credentials')||r.contains('email')) return 'Invalid admin email or password.'; if(r.contains('schema')||r.contains('database')||r.contains('postgrest')||r.contains('{')||r.contains('}')) return 'Admin setup is not ready. Please run the latest admin SQL and try again.'; return 'Something went wrong. Please try again.'; }
String shortDate(dynamic value){ final s=value?.toString()??''; if(s.length>=10) return s.substring(0,10); return '-'; }
void showToast(BuildContext context, String text){ ScaffoldMessenger.of(context).hideCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text), behavior:SnackBarBehavior.floating, backgroundColor:kPrimaryDark)); }

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color kInk = Color(0xFF231A1D);
const Color kPrimary = Color(0xFF8D5062);
const Color kPrimaryDark = Color(0xFF5E2C3A);
const Color kAccent = Color(0xFFD8A05F);
const Color kBlush = Color(0xFFFFF7F2);
const Color kSoft = Color(0xFFF6DFE3);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await dotenv.load(fileName: '.env').catchError((_) async {});
  final url = dotenv.env['SUPABASE_URL'] ?? '';
  final anon = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (url.isEmpty || anon.isEmpty) {
    runApp(const PublicErrorApp(message: 'App setup is not complete. Please contact the system owner.'));
    return;
  }
  try {
    await Supabase.initialize(url: url, anonKey: anon);
    runApp(const MemoryMakerAdminApp());
  } catch (_) {
    runApp(const PublicErrorApp(message: 'Could not connect to the secure admin service. Please try again later.'));
  }
}

class MemoryMakerAdminApp extends StatelessWidget {
  const MemoryMakerAdminApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Maker Admin',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(data: mq.copyWith(textScaler: const TextScaler.linear(1.0), boldText: false), child: child ?? const SizedBox());
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: kBlush,
        fontFamily: null,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, primary: kPrimary, surface: Colors.white),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(.94),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFEBD9D7))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFEBD9D7))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: kPrimary, width: 1.6)),
        ),
      ),
      home: const SplashGate(),
    );
  }
}

class PublicErrorApp extends StatelessWidget {
  const PublicErrorApp({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)), child: child!),
    home: ShellBackground(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: GlassCard(padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))))),
  );
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin {
  late final AnimationController c;
  late final Animation<double> scale;
  @override
  void initState() {
    super.initState();
    c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    scale = CurvedAnimation(parent: c, curve: Curves.easeOutBack);
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
    });
  }
  @override
  void dispose() { c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ShellBackground(
    child: Center(
      child: ScaleTransition(
        scale: scale,
        child: Column(mainAxisSize: MainAxisSize.min, children: const [
          BrandMark(size: 112, admin: true),
          SizedBox(height: 18),
          Text('Memory Maker Admin', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: kInk)),
          SizedBox(height: 6),
          Text('Secure control panel', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? sub;
  @override
  void initState() {
    super.initState();
    sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { sub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Supabase.instance.client.auth.currentSession == null ? const LoginPage() : const AdminAccessCheck();
}

class AdminApi {
  AdminApi(this.client);
  final SupabaseClient client;
  List<Map<String, dynamic>> _list(dynamic res) => res is List ? res.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  Future<Map<String, dynamic>?> me() async { final r = await client.rpc('app_admin_me'); return r is Map ? Map<String, dynamic>.from(r) : null; }
  Future<Map<String, dynamic>> overview() async => Map<String, dynamic>.from(await client.rpc('app_admin_overview'));
  Future<List<Map<String, dynamic>>> tickets() async => _list(await client.rpc('app_admin_list_tickets'));
  Future<List<Map<String, dynamic>>> users() async => _list(await client.rpc('app_admin_list_users'));
  Future<List<Map<String, dynamic>>> events() async => _list(await client.rpc('app_admin_list_events'));
  Future<List<Map<String, dynamic>>> notifications() async => _list(await client.rpc('app_admin_list_notifications'));
  Future<List<Map<String, dynamic>>> media(String eventId) async => _list(await client.rpc('app_admin_list_media', params: {'p_event_id': eventId}));
  Future<void> replyTicket(String ticketId, String reply) => client.rpc('app_admin_reply_ticket', params: {'p_ticket_id': ticketId, 'p_reply': reply});
  Future<void> updateTicketStatus(String ticketId, String status) => client.rpc('app_admin_update_ticket_status', params: {'p_ticket_id': ticketId, 'p_status': status});
  Future<void> setUserRole(String userId, String role) => client.rpc('app_admin_set_user_role', params: {'p_user_id': userId, 'p_role': role});
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
  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> login() async {
    FocusScope.of(context).unfocus();
    if (email.text.trim().isEmpty || password.text.isEmpty) { setState(() => error = 'Please enter admin email and password.'); return; }
    setState(() { loading = true; error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
    } on AuthException catch (e) {
      setState(() => error = cleanAuthMessage(e.message));
    } on PostgrestException {
      setState(() => error = 'Admin service is not ready. Please run the latest admin SQL and try again.');
    } catch (e) {
      setState(() => error = cleanAuthMessage(e.toString()));
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> resetPassword() async {
    final mail = email.text.trim();
    if (mail.isEmpty) { setState(() => error = 'Enter your admin email first.'); return; }
    try { await Supabase.instance.client.auth.resetPasswordForEmail(mail); if (mounted) showToast(context, 'Password reset email sent.'); }
    catch (_) { if (mounted) showToast(context, 'Could not send reset email.'); }
  }

  @override
  Widget build(BuildContext context) => ShellBackground(
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: BrandMark(size: 88, admin: true)),
                const SizedBox(height: 16),
                const Text('Memory Maker Admin', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, height: 1.05, fontWeight: FontWeight.w900, color: kInk, decoration: TextDecoration.none)),
                const SizedBox(height: 8),
                Container(height: 3, width: 84, margin: const EdgeInsets.only(left: 164, right: 164), decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.all(Radius.circular(999)))),
                const SizedBox(height: 18),
                const Text('Admin Console', textAlign: TextAlign.center, style: TextStyle(fontSize: 31, height: 1.04, fontWeight: FontWeight.w900, color: kInk, decoration: TextDecoration.none)),
                const SizedBox(height: 8),
                const Text('Manage support tickets, users, galleries and uploads from one secure mobile dashboard.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, height: 1.45, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                const SizedBox(height: 24),
                AdminTextField(controller: email, label: 'Admin email', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 14),
                AdminTextField(controller: password, label: 'Password', icon: Icons.lock_outline, obscure: !showPassword, suffix: IconButton(onPressed: () => setState(() => showPassword = !showPassword), icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility))),
                if (error != null) ...[const SizedBox(height: 14), ErrorBox(error!)],
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: loading ? null : login, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded), label: Text(loading ? 'Signing in...' : 'Login')),
                TextButton(onPressed: loading ? null : resetPassword, child: const Text('Forgot password? Send reset email')),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminAccessCheck extends StatefulWidget { const AdminAccessCheck({super.key}); @override State<AdminAccessCheck> createState() => _AdminAccessCheckState(); }
class _AdminAccessCheckState extends State<AdminAccessCheck> {
  late Future<Map<String, dynamic>?> future;
  late final AdminApi api;
  @override void initState() { super.initState(); api = AdminApi(Supabase.instance.client); future = api.me(); }
  @override Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(future: future, builder: (context, snap) {
    if (snap.connectionState != ConnectionState.done) return const LoadingScreen(text: 'Opening secure admin panel...');
    if (snap.hasError) return AccessDenied(message: 'Admin setup is not complete. Run the admin SQL migration and try again.');
    if (snap.data == null || snap.data!['allowed'] != true) return const AccessDenied(message: 'This account does not have admin access.');
    return AdminHome(me: snap.data!);
  });
}

class AccessDenied extends StatelessWidget { const AccessDenied({super.key, required this.message}); final String message;
  @override Widget build(BuildContext context) => ShellBackground(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: GlassCard(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const BrandMark(size: 78, admin: true), const SizedBox(height: 16), const Text('Access not available', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kInk)), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.4)), const SizedBox(height: 18), FilledButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Back to login'))
  ])))));
}

class AdminHome extends StatefulWidget { const AdminHome({super.key, required this.me}); final Map<String, dynamic> me; @override State<AdminHome> createState() => _AdminHomeState(); }
class _AdminHomeState extends State<AdminHome> {
  int index = 0; late final AdminApi api;
  @override void initState() { super.initState(); api = AdminApi(Supabase.instance.client); }
  @override Widget build(BuildContext context) {
    final pages = [OverviewPage(api: api), TicketsPage(api: api), UsersPage(api: api, isSuperAdmin: isSuper(widget.me)), GalleriesPage(api: api), SettingsPage(me: widget.me)];
    return ShellBackground(child: Scaffold(backgroundColor: Colors.transparent, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Row(children: const [BrandMark(size: 36, admin: true), SizedBox(width: 10), Expanded(child: Text('Memory Maker Admin', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: kInk)))]), actions: [IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh_rounded)), IconButton(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout_rounded))]), body: SafeArea(child: pages[index]), bottomNavigationBar: NavigationBar(height: 72, backgroundColor: Colors.white.withOpacity(.94), selectedIndex: index, onDestinationSelected: (i) => setState(() => index = i), destinations: const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent_rounded), label: 'Tickets'),
      NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Users'),
      NavigationDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library_rounded), label: 'Galleries'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
    ])));
  }
}

class OverviewPage extends StatefulWidget { const OverviewPage({super.key, required this.api}); final AdminApi api; @override State<OverviewPage> createState() => _OverviewPageState(); }
class _OverviewPageState extends State<OverviewPage> { late Future<Map<String, dynamic>> future; @override void initState() { super.initState(); future = widget.api.overview(); } Future<void> refresh() async => setState(() => future = widget.api.overview());
  @override Widget build(BuildContext context) => RefreshIndicator(onRefresh: () async => refresh(), child: FutureBuilder<Map<String, dynamic>>(future: future, builder: (context, snap) {
    if (snap.hasError) return ErrorState(onRetry: refresh);
    if (!snap.hasData) return const LoadingList(); final d = snap.data!;
    return ListView(padding: const EdgeInsets.all(18), children: [const PageTitle('Overview', 'Live public beta operations dashboard.'), GridWrap(children: [StatCard(title: 'Users', value: '${d['users_count'] ?? 0}', icon: Icons.people_rounded), StatCard(title: 'Galleries', value: '${d['events_count'] ?? 0}', icon: Icons.photo_library_rounded), StatCard(title: 'Uploads', value: '${d['uploads_count'] ?? 0}', icon: Icons.cloud_upload_rounded), StatCard(title: 'Open Tickets', value: '${d['open_tickets_count'] ?? 0}', icon: Icons.support_agent_rounded)]), const SizedBox(height: 16), const GlassCard(child: ListTile(leading: Icon(Icons.verified_user_outlined, color: kPrimary), title: Text('Admin app is connected', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Manage tickets, users and galleries from this secure admin app.')))]);
  }));
}

class TicketsPage extends StatefulWidget { const TicketsPage({super.key, required this.api}); final AdminApi api; @override State<TicketsPage> createState() => _TicketsPageState(); }
class _TicketsPageState extends State<TicketsPage> { late Future<List<Map<String, dynamic>>> future; @override void initState(){super.initState(); future = widget.api.tickets();} Future<void> refresh() async => setState(() => future = widget.api.tickets());
  Future<void> reply(Map<String, dynamic> t) async { final c = TextEditingController(text: (t['admin_reply'] ?? '').toString()); final r = await showDialog<String>(context: context, builder: (_) => AlertDialog(title: const Text('Send support reply'), content: TextField(controller: c, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'Reply message')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Send'))])); if (r == null || r.isEmpty) return; try { await widget.api.replyTicket(t['id'].toString(), r); if (mounted) showToast(context, 'Reply sent.'); refresh(); } catch (_) { if (mounted) showToast(context, 'Could not send reply.'); } }
  @override Widget build(BuildContext context) => RefreshIndicator(onRefresh: () async => refresh(), child: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snap){ if(snap.hasError) return ErrorState(onRetry: refresh); if(!snap.hasData) return const LoadingList(); final items=snap.data!; return ListView(padding: const EdgeInsets.all(18), children:[const PageTitle('Support Tickets','Read user issues and send replies.'), if(items.isEmpty) const EmptyCard(icon: Icons.support_agent_rounded,title:'No tickets yet',subtitle:'New support requests will appear here.'), for(final t in items) TicketCard(ticket:t,onReply:()=>reply(t),onClose:() async {try{await widget.api.updateTicketStatus(t['id'].toString(),'closed'); refresh();}catch(_){showToast(context,'Could not close ticket.');}})]); }));
}

class UsersPage extends StatefulWidget { const UsersPage({super.key, required this.api, required this.isSuperAdmin}); final AdminApi api; final bool isSuperAdmin; @override State<UsersPage> createState()=>_UsersPageState(); }
class _UsersPageState extends State<UsersPage>{ late Future<List<Map<String,dynamic>>> future; @override void initState(){super.initState(); future=widget.api.users();} Future<void> refresh() async=>setState(()=>future=widget.api.users()); @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:() async=>refresh(),child:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,snap){ if(snap.hasError)return ErrorState(onRetry:refresh); if(!snap.hasData)return const LoadingList(); final users=snap.data!; return ListView(padding:const EdgeInsets.all(18),children:[const PageTitle('Users','View accounts and assign roles.'), if(users.isEmpty) const EmptyCard(icon:Icons.people_rounded,title:'No users found',subtitle:'Registered users will appear here.'), for(final u in users) UserCard(user:u,canEdit:widget.isSuperAdmin,onSetRole:(role) async{try{await widget.api.setUserRole(u['id'].toString(),role); refresh();}catch(_){showToast(context,'Could not update role.');}})]); }));}

class GalleriesPage extends StatefulWidget { const GalleriesPage({super.key, required this.api}); final AdminApi api; @override State<GalleriesPage> createState()=>_GalleriesPageState(); }
class _GalleriesPageState extends State<GalleriesPage>{ late Future<List<Map<String,dynamic>>> future; @override void initState(){super.initState(); future=widget.api.events();} Future<void> refresh() async=>setState(()=>future=widget.api.events()); @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:() async=>refresh(),child:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,snap){ if(snap.hasError)return ErrorState(onRetry:refresh); if(!snap.hasData)return const LoadingList(); final events=snap.data!; return ListView(padding:const EdgeInsets.all(18),children:[const PageTitle('Galleries','Inspect event spaces and upload counts.'), if(events.isEmpty) const EmptyCard(icon:Icons.photo_library_rounded,title:'No galleries yet',subtitle:'User-created galleries will show here.'), for(final e in events) GalleryCard(event:e,onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>GalleryMediaPage(api:widget.api,event:e))))]); }));}

class GalleryMediaPage extends StatefulWidget{ const GalleryMediaPage({super.key, required this.api, required this.event}); final AdminApi api; final Map<String,dynamic> event; @override State<GalleryMediaPage> createState()=>_GalleryMediaPageState();}
class _GalleryMediaPageState extends State<GalleryMediaPage>{ late Future<List<Map<String,dynamic>>> future; @override void initState(){super.initState(); future=widget.api.media(widget.event['id'].toString());} @override Widget build(BuildContext context)=>ShellBackground(child:Scaffold(backgroundColor:Colors.transparent,appBar:AppBar(backgroundColor:Colors.transparent,title:Text(widget.event['title']?.toString()??'Gallery')),body:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,snap){ if(snap.hasError)return ErrorState(onRetry:()=>setState(()=>future=widget.api.media(widget.event['id'].toString()))); if(!snap.hasData)return const LoadingList(); final media=snap.data!; return ListView(padding:const EdgeInsets.all(18),children:[if(media.isEmpty) const EmptyCard(icon:Icons.image_rounded,title:'No uploads yet',subtitle:'Uploads for this gallery will show here.'), for(final m in media) MediaTile(item:m)]); })) );}

class SettingsPage extends StatelessWidget { const SettingsPage({super.key, required this.me}); final Map<String, dynamic> me; @override Widget build(BuildContext context){ final user=Supabase.instance.client.auth.currentUser; return ListView(padding:const EdgeInsets.all(18), children:[const PageTitle('Settings','Admin session and account details.'), GlassCard(child:Column(children:[ListTile(leading:Avatar(profile:me), title:Text(me['full_name']?.toString().isNotEmpty==true?me['full_name']:'Admin',style:const TextStyle(fontWeight:FontWeight.w900)), subtitle:Text(user?.email??'')), const Divider(height:1), ListTile(leading:const Icon(Icons.shield_outlined,color:kPrimary),title:const Text('Role'),subtitle:Text('${me['role']??'admin'}')), ListTile(leading:const Icon(Icons.logout_rounded,color:kPrimary),title:const Text('Logout'),onTap:()=>Supabase.instance.client.auth.signOut())]))]);}}

class TicketCard extends StatelessWidget{ const TicketCard({super.key,required this.ticket,required this.onReply,required this.onClose}); final Map<String,dynamic> ticket; final VoidCallback onReply; final VoidCallback onClose; @override Widget build(BuildContext context)=>GlassCard(margin:const EdgeInsets.only(bottom:14),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(ticket['subject']?.toString()??'Support request',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17,color:kInk))),StatusPill(ticket['status']?.toString()??'open')]), const SizedBox(height:4), Text(ticket['user_email']?.toString()??'No email',style:const TextStyle(color:Colors.black54)), const SizedBox(height:10), Text(ticket['message']?.toString()??'',style:const TextStyle(height:1.35)), if((ticket['admin_reply']??'').toString().isNotEmpty)...[const SizedBox(height:12),Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:kSoft.withOpacity(.45),borderRadius:BorderRadius.circular(16)),child:Text('Reply: ${ticket['admin_reply']}',style:const TextStyle(fontWeight:FontWeight.w600)))], const SizedBox(height:12),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:onReply,icon:const Icon(Icons.reply_rounded),label:const Text('Reply'))),const SizedBox(width:10),Expanded(child:FilledButton.icon(onPressed:onClose,icon:const Icon(Icons.check_rounded),label:const Text('Close')))])])));}
class UserCard extends StatelessWidget{ const UserCard({super.key,required this.user,required this.canEdit,required this.onSetRole}); final Map<String,dynamic> user; final bool canEdit; final Future<void> Function(String role) onSetRole; @override Widget build(BuildContext context)=>GlassCard(margin:const EdgeInsets.only(bottom:12),child:ListTile(leading:Avatar(profile:user),title:Text(user['full_name']?.toString().isNotEmpty==true?user['full_name']:(user['email']??'User'),style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${user['email']??''}\nRole: ${user['role']??'user'}'),isThreeLine:true,trailing:canEdit?PopupMenuButton<String>(onSelected:onSetRole,itemBuilder:(_)=>const[PopupMenuItem(value:'user',child:Text('Make user')),PopupMenuItem(value:'sub_admin',child:Text('Make sub admin')),PopupMenuItem(value:'super_admin',child:Text('Make super admin'))]):null));}
class GalleryCard extends StatelessWidget{ const GalleryCard({super.key,required this.event,required this.onTap}); final Map<String,dynamic> event; final VoidCallback onTap; @override Widget build(BuildContext context)=>GlassCard(margin:const EdgeInsets.only(bottom:12),child:ListTile(onTap:onTap,leading:const CircleAvatar(backgroundColor:kSoft,child:Icon(Icons.photo_library_rounded,color:kPrimary)),title:Text(event['title']?.toString()??'Memory Gallery',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${event['event_kind']??event['event_type']??'Event'} • ${event['owner_email']??'No owner'}\nUploads: ${event['media_count']??0} • Guests: ${event['guests_count']??0}'),isThreeLine:true,trailing:const Icon(Icons.chevron_right_rounded)));}
class MediaTile extends StatelessWidget{ const MediaTile({super.key,required this.item}); final Map<String,dynamic> item; @override Widget build(BuildContext context){ final data=(item['data_url']??'').toString(); return GlassCard(margin:const EdgeInsets.only(bottom:12),child:ListTile(leading:ClipRRect(borderRadius:BorderRadius.circular(14),child:data.startsWith('data:image')?Image.memory(base64Decode(data.split(',').last),width:58,height:58,fit:BoxFit.cover):const CircleAvatar(backgroundColor:kSoft,child:Icon(Icons.image_rounded,color:kPrimary))),title:Text(item['original_filename']?.toString()??'Upload',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${item['status']??'approved'} • ${fmt(item['created_at'])}\n${item['caption']??''}'),isThreeLine:true));}}

class BrandMark extends StatelessWidget{ const BrandMark({super.key,this.size=72,this.admin=false}); final double size; final bool admin; @override Widget build(BuildContext context)=>Container(width:size,height:size,decoration:BoxDecoration(color:Colors.white.withOpacity(.72),borderRadius:BorderRadius.circular(size*.28),border:Border.all(color:kPrimary.withOpacity(.55),width:2),boxShadow:[BoxShadow(color:kPrimary.withOpacity(.14),blurRadius:22,offset:const Offset(0,10))]),child:Center(child:Stack(alignment:Alignment.center,children:[Icon(Icons.admin_panel_settings_rounded,size:size*.46,color:kPrimary),if(admin) Positioned(right:size*.19,bottom:size*.20,child:Container(width:size*.24,height:size*.24,decoration:const BoxDecoration(color:kPrimary,shape:BoxShape.circle),child:Icon(Icons.lock_rounded,size:size*.14,color:Colors.white)))])));}
class Avatar extends StatelessWidget{ const Avatar({super.key,required this.profile}); final Map<String,dynamic> profile; @override Widget build(BuildContext context){ final bytes=avatarBytes(profile); final provider=avatarProvider(profile); return CircleAvatar(radius:24,backgroundColor:kSoft,backgroundImage:bytes!=null?MemoryImage(bytes):(provider),child:bytes==null&&provider==null?const Icon(Icons.person_rounded,color:kPrimary):null);}}
Uint8List? avatarBytes(Map<String,dynamic> p){ final b=(p['avatar_base64']??'').toString(); if(b.isEmpty)return null; try{return base64Decode(b.contains(',')?b.split(',').last:b);}catch(_){return null;}}
ImageProvider? avatarProvider(Map<String,dynamic> p){ for(final k in ['avatar_url','profile_picture_url','profile_photo_url','image_url','photo_url']){final v=(p[k]??'').toString(); if(v.startsWith('http')) return NetworkImage(v);} return null; }
class ShellBackground extends StatelessWidget{ const ShellBackground({super.key,required this.child}); final Widget child; @override Widget build(BuildContext context)=>Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFFFF8F4),Color(0xFFFFE7E2),Color(0xFFFFFBF8)])),child:Stack(children:[const Positioned(top:-90,right:-70,child:DecorBlob(size:210)),const Positioned(bottom:-70,left:-80,child:DecorBlob(size:230)),child]));}
class DecorBlob extends StatelessWidget{ const DecorBlob({super.key,required this.size}); final double size; @override Widget build(BuildContext context)=>Container(width:size,height:size,decoration:BoxDecoration(shape:BoxShape.circle,gradient:RadialGradient(colors:[kPrimary.withOpacity(.18),kPrimary.withOpacity(0)])));}
class GlassCard extends StatelessWidget{ const GlassCard({super.key,required this.child,this.padding,this.margin}); final Widget child; final EdgeInsetsGeometry? padding; final EdgeInsetsGeometry? margin; @override Widget build(BuildContext context)=>Container(margin:margin,padding:padding,decoration:BoxDecoration(color:Colors.white.withOpacity(.84),borderRadius:BorderRadius.circular(28),border:Border.all(color:Colors.white.withOpacity(.92)),boxShadow:[BoxShadow(color:kPrimary.withOpacity(.13),blurRadius:34,offset:const Offset(0,18))]),child:child);}
class AdminTextField extends StatelessWidget{ const AdminTextField({super.key,required this.controller,required this.label,required this.icon,this.obscure=false,this.suffix,this.keyboard}); final TextEditingController controller; final String label; final IconData icon; final bool obscure; final Widget? suffix; final TextInputType? keyboard; @override Widget build(BuildContext context)=>TextField(controller:controller,obscureText:obscure,keyboardType:keyboard,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600),decoration:InputDecoration(labelText:label,prefixIcon:Icon(icon),suffixIcon:suffix));}
class PageTitle extends StatelessWidget{ const PageTitle(this.title,this.subtitle,{super.key}); final String title; final String subtitle; @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:kInk)),const SizedBox(height:4),Text(subtitle,style:const TextStyle(color:Colors.black54,height:1.35,fontWeight:FontWeight.w600))]));}
class StatCard extends StatelessWidget{ const StatCard({super.key,required this.title,required this.value,required this.icon}); final String title; final String value; final IconData icon; @override Widget build(BuildContext context)=>GlassCard(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:kPrimary),const Spacer(),Text(value,style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900,color:kInk)),Text(title,style:const TextStyle(color:Colors.black54,fontWeight:FontWeight.w600))])));}
class GridWrap extends StatelessWidget{ const GridWrap({super.key,required this.children}); final List<Widget> children; @override Widget build(BuildContext context)=>GridView.count(crossAxisCount:MediaQuery.sizeOf(context).width>700?4:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.25,children:children);}
class EmptyCard extends StatelessWidget{ const EmptyCard({super.key,required this.icon,required this.title,required this.subtitle}); final IconData icon; final String title; final String subtitle; @override Widget build(BuildContext context)=>GlassCard(padding:const EdgeInsets.all(32),child:Column(children:[CircleAvatar(radius:34,backgroundColor:kSoft,child:Icon(icon,color:kPrimary,size:34)),const SizedBox(height:16),Text(title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:kInk)),const SizedBox(height:6),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54))]));}
class ErrorState extends StatelessWidget{ const ErrorState({super.key,required this.onRetry}); final VoidCallback onRetry; @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(24),children:[GlassCard(padding:const EdgeInsets.all(24),child:Column(children:[const Icon(Icons.cloud_off_rounded,size:52,color:kPrimary),const SizedBox(height:12),const Text('Could not load data',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:kInk)),const SizedBox(height:6),const Text('Please run the latest admin SQL migration and refresh.',textAlign:TextAlign.center,style:TextStyle(color:Colors.black54)),const SizedBox(height:16),FilledButton(onPressed:onRetry,child:const Text('Refresh'))]))]);}
class LoadingScreen extends StatelessWidget{ const LoadingScreen({super.key,required this.text}); final String text; @override Widget build(BuildContext context)=>ShellBackground(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const CircularProgressIndicator(color:kPrimary),const SizedBox(height:12),Text(text,style:const TextStyle(fontWeight:FontWeight.w700))])));}
class LoadingList extends StatelessWidget{ const LoadingList({super.key}); @override Widget build(BuildContext context)=>const Center(child:Padding(padding:EdgeInsets.all(30),child:CircularProgressIndicator(color:kPrimary)));}
class ErrorBox extends StatelessWidget{ const ErrorBox(this.text,{super.key}); final String text; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:const Color(0xFFFFE1E5),borderRadius:BorderRadius.circular(16)),child:Text(cleanAuthMessage(text), maxLines: 3, overflow: TextOverflow.ellipsis, style:const TextStyle(color:Color(0xFF9D2636),height:1.35,fontWeight:FontWeight.w700, decoration: TextDecoration.none)));}
class StatusPill extends StatelessWidget{ const StatusPill(this.status,{super.key}); final String status; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:kSoft,borderRadius:BorderRadius.circular(999)),child:Text(status.toUpperCase(),style:const TextStyle(color:kPrimaryDark,fontWeight:FontWeight.w900,fontSize:11)));}
void showToast(BuildContext context,String text){ ScaffoldMessenger.of(context).hideCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text),behavior:SnackBarBehavior.floating,backgroundColor:kPrimaryDark));}
String cleanAuthMessage(String raw){ final r=raw.toLowerCase(); if(r.contains('database')||r.contains('schema')||r.contains('unexpected')||r.contains('postgrest')||r.contains('relation')||r.contains('{')||r.contains('}')||r.contains('json')) return 'Admin login is not ready yet. Please run the latest admin SQL migration and try again.'; if(r.contains('invalid')||r.contains('credentials')||r.contains('email not confirmed')) return 'Invalid admin email or password.'; return 'Login failed. Please check your details and try again.'; }
bool isSuper(Map<String,dynamic> me)=>me['is_super_admin']==true||me['role']?.toString()=='super_admin';
String fmt(dynamic v){ if(v==null)return '-'; final dt=DateTime.tryParse(v.toString()); if(dt==null)return v.toString(); return DateFormat('MMM d, y • h:mm a').format(dt.toLocal()); }

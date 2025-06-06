import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/app_auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/minister/presentation/screens/minister_home_screen.dart';
import 'features/floor_manager/presentation/screens/floor_manager_home_screen_new.dart';
import 'core/presentation/screens/standard_home_screen.dart';
import 'features/auth/presentation/screens/signup_screen.dart';
import 'features/minister/presentation/screens/minister_choice_screen.dart';
import 'features/minister/presentation/screens/appointment_booking_screen.dart';
import 'features/operational_manager/presentation/screens/operational_manager_home_screen.dart';
import 'features/consultant/presentation/screens/consultant_home_screen_attendance.dart';
import 'features/concierge/presentation/screens/concierge_home_screen_attendance.dart' as concierge_attendance;
import 'features/cleaner/presentation/screens/cleaner_home_screen_attendance.dart';
import 'features/marketing_agent/presentation/screens/marketing_agent_home_screen.dart';
import 'features/staff/presentation/screens/staff_home_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/services/fcm_service.dart';
import 'core/services/vip_notification_service.dart';
import 'features/floor_manager/presentation/screens/appointment_details_screen.dart';
import 'core/services/vip_messaging_service.dart';
import 'core/widgets/unified_appointment_search_screen.dart';

class App extends StatefulWidget {
  final bool isLoggedIn;
  final Widget? child;
  const App({Key? key, this.isLoggedIn = false, this.child}) : super(key: key);

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  @override
  void initState() {
    super.initState();
    
    // Complete FCM initialization after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? ctx = navigatorKey.currentContext;
      if (ctx != null) {
        FCMService().completeInitialization(ctx);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'VIP Lounge',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      darkTheme: AppTheme.lightTheme,
      themeMode: ThemeMode.dark,
      initialRoute: widget.isLoggedIn ? '/' : '/login',
      onGenerateRoute: (settings) {
        final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;

        // If not logged in, redirect to login
        if (user == null && settings.name != '/login' && settings.name != '/signup') {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }

        // If logged in, redirect to appropriate home screen based on role
        if (settings.name == '/') {
          if (user == null) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }

          // Debug print user role during routing
          print(' APP.DART ROUTING - USER ROLE: ${user.role}');

          // Use proper role-based routing
          switch (user.role) {
            case 'minister':
              return MaterialPageRoute(builder: (_) => const MinisterHomeScreen());
            case 'floor_manager':
            case 'supervisor':
              return MaterialPageRoute(builder: (_) => const FloorManagerHomeScreenNew());
            case 'consultant':
              print('DEBUG: Loading ConsultantHomeScreenAttendance for consultant role');
              // FORCE USE OF ENHANCED DASHBOARD - DO NOT MODIFY THIS LINE
              return MaterialPageRoute(builder: (_) => const ConsultantHomeScreenAttendance());
            case 'concierge':
              // Route to new attendance-based concierge home screen (with query date fixed)
              return MaterialPageRoute(builder: (_) => const concierge_attendance.ConciergeHomeScreenAttendance());
            case 'cleaner':
              return MaterialPageRoute(builder: (_) => const CleanerHomeScreenAttendance());
            default:
              return MaterialPageRoute(builder: (_) => const StandardHomeScreen());
          }
        }

        // Handle other named routes
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/signup':
            return MaterialPageRoute(builder: (_) => SignupScreen());
          case '/minister/home':
            return MaterialPageRoute(builder: (_) => MinisterHomeScreen());
          case '/minister/choice':
            return MaterialPageRoute(builder: (_) => const MinisterChoiceScreen());
          case '/minister/appointment':
            return MaterialPageRoute(builder: (_) => const AppointmentBookingScreen());
          case '/floor_manager/home':
            return MaterialPageRoute(builder: (_) => const FloorManagerHomeScreenNew());
          case '/operational_manager/home':
            return MaterialPageRoute(builder: (_) => const OperationalManagerHomeScreen());
          case '/consultant/home':
            print('DEBUG: Loading ConsultantHomeScreenAttendance for /consultant/home route');
            return MaterialPageRoute(builder: (_) => const ConsultantHomeScreenAttendance());
          case '/concierge/home':
            return MaterialPageRoute(builder: (_) => const concierge_attendance.ConciergeHomeScreenAttendance());
          case '/cleaner/home':
            return MaterialPageRoute(builder: (_) => const CleanerHomeScreenAttendance());
          case '/marketing_agent/home':
            return MaterialPageRoute(builder: (_) => const MarketingAgentHomeScreen());
          case '/staff/home':
            return MaterialPageRoute(builder: (_) => const StaffHomeScreen());
          case '/minister/home/chat':
            // Extract appointmentId from arguments
            final args = settings.arguments as Map<String, dynamic>?;
            final appointmentId = args?['appointmentId'] as String?;
            
            if (appointmentId != null) {
              print('Navigating to minister chat with appointmentId: $appointmentId');
              return MaterialPageRoute(builder: (_) => MinisterHomeScreen(
                initialChatAppointmentId: appointmentId,
              ));
            } else {
              return MaterialPageRoute(builder: (_) => MinisterHomeScreen());
            }
          case '/concierge/chat':
            // Extract appointmentId and other params from arguments
            final conciergeArgs = settings.arguments as Map<String, dynamic>?;
            final conciergeAppointmentId = conciergeArgs?['appointmentId'] as String?;
            final conciergeId = conciergeArgs?['conciergeId'] as String?;
            final conciergeName = conciergeArgs?['conciergeName'] as String?;
            final conciergeRole = conciergeArgs?['conciergeRole'] as String? ?? 'concierge';
            if (conciergeAppointmentId != null && conciergeId != null && conciergeName != null) {
              return MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    title: const Text('Chat'),
                    backgroundColor: Colors.black,
                  ),
                  body: VipMessagingService().buildChatInterface(
                    context: _,
                    appointmentId: conciergeAppointmentId,
                    currentUserId: conciergeId,
                    currentUserName: conciergeName,
                    currentUserRole: conciergeRole,
                  ),
                ),
              );
            } else {
              return MaterialPageRoute(
                builder: (_) => const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: Text('Missing chat parameters', style: TextStyle(color: Colors.red))),
                ),
              );
            }
          case '/consultant/chat':
            // Extract appointmentId and other params from arguments
            final consultantArgs = settings.arguments as Map<String, dynamic>?;
            final consultantAppointmentId = consultantArgs?['appointmentId'] as String?;
            final consultantId = consultantArgs?['consultantId'] as String?;
            final consultantName = consultantArgs?['consultantName'] as String?;
            final consultantRole = consultantArgs?['consultantRole'] as String? ?? 'consultant';
            if (consultantAppointmentId != null && consultantId != null && consultantName != null) {
              return MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    title: const Text('Chat'),
                    backgroundColor: Colors.black,
                  ),
                  body: VipMessagingService().buildChatInterface(
                    context: _,
                    appointmentId: consultantAppointmentId,
                    currentUserId: consultantId,
                    currentUserName: consultantName,
                    currentUserRole: consultantRole,
                  ),
                ),
              );
            } else {
              return MaterialPageRoute(
                builder: (_) => const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: Text('Missing chat parameters', style: TextStyle(color: Colors.red))),
                ),
              );
            }
          case '/floor_manager/appointment_details':
            final args = settings.arguments as Map<String, dynamic>?;
            final appointmentId = args?['appointmentId'] as String?;
            final notification = args?['notification'] as Map<String, dynamic>?;
            if (appointmentId != null) {
              return MaterialPageRoute(
                builder: (_) => AppointmentDetailsScreen(
                  appointmentId: appointmentId,
                  notification: notification,
                ),
              );
            } else {
              return MaterialPageRoute(builder: (_) => const StandardHomeScreen());
            }
          case '/unified_appointment_search':
            return MaterialPageRoute(builder: (_) => UnifiedAppointmentSearchScreen());
          default:
            return MaterialPageRoute(builder: (_) => const StandardHomeScreen());
        }
      },
    );
  }
}

//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<add_2_calendar/Add2CalendarPlugin.h>)
#import <add_2_calendar/Add2CalendarPlugin.h>
#else
@import add_2_calendar;
#endif

#if __has_include(<cloud_firestore/FLTFirebaseFirestorePlugin.h>)
#import <cloud_firestore/FLTFirebaseFirestorePlugin.h>
#else
@import cloud_firestore;
#endif

#if __has_include(<connectivity_plus/ConnectivityPlusPlugin.h>)
#import <connectivity_plus/ConnectivityPlusPlugin.h>
#else
@import connectivity_plus;
#endif

#if __has_include(<file_picker/FilePickerPlugin.h>)
#import <file_picker/FilePickerPlugin.h>
#else
@import file_picker;
#endif

#if __has_include(<firebase_auth/FLTFirebaseAuthPlugin.h>)
#import <firebase_auth/FLTFirebaseAuthPlugin.h>
#else
@import firebase_auth;
#endif

#if __has_include(<firebase_core/FLTFirebaseCorePlugin.h>)
#import <firebase_core/FLTFirebaseCorePlugin.h>
#else
@import firebase_core;
#endif

#if __has_include(<firebase_messaging/FLTFirebaseMessagingPlugin.h>)
#import <firebase_messaging/FLTFirebaseMessagingPlugin.h>
#else
@import firebase_messaging;
#endif

#if __has_include(<firebase_storage/FLTFirebaseStoragePlugin.h>)
#import <firebase_storage/FLTFirebaseStoragePlugin.h>
#else
@import firebase_storage;
#endif

#if __has_include(<flutter_local_notifications/FlutterLocalNotificationsPlugin.h>)
#import <flutter_local_notifications/FlutterLocalNotificationsPlugin.h>
#else
@import flutter_local_notifications;
#endif

#if __has_include(<flutter_native_splash/FlutterNativeSplashPlugin.h>)
#import <flutter_native_splash/FlutterNativeSplashPlugin.h>
#else
@import flutter_native_splash;
#endif

#if __has_include(<fluttertoast/FluttertoastPlugin.h>)
#import <fluttertoast/FluttertoastPlugin.h>
#else
@import fluttertoast;
#endif

#if __has_include(<google_maps_flutter_ios/FLTGoogleMapsPlugin.h>)
#import <google_maps_flutter_ios/FLTGoogleMapsPlugin.h>
#else
@import google_maps_flutter_ios;
#endif

#if __has_include(<image_picker_ios/FLTImagePickerPlugin.h>)
#import <image_picker_ios/FLTImagePickerPlugin.h>
#else
@import image_picker_ios;
#endif

#if __has_include(<package_info_plus/FPPPackageInfoPlusPlugin.h>)
#import <package_info_plus/FPPPackageInfoPlusPlugin.h>
#else
@import package_info_plus;
#endif

#if __has_include(<path_provider_foundation/PathProviderPlugin.h>)
#import <path_provider_foundation/PathProviderPlugin.h>
#else
@import path_provider_foundation;
#endif

#if __has_include(<permission_handler_apple/PermissionHandlerPlugin.h>)
#import <permission_handler_apple/PermissionHandlerPlugin.h>
#else
@import permission_handler_apple;
#endif

#if __has_include(<shared_preferences_foundation/SharedPreferencesPlugin.h>)
#import <shared_preferences_foundation/SharedPreferencesPlugin.h>
#else
@import shared_preferences_foundation;
#endif

#if __has_include(<sqflite_darwin/SqflitePlugin.h>)
#import <sqflite_darwin/SqflitePlugin.h>
#else
@import sqflite_darwin;
#endif

#if __has_include(<url_launcher_ios/URLLauncherPlugin.h>)
#import <url_launcher_ios/URLLauncherPlugin.h>
#else
@import url_launcher_ios;
#endif

#if __has_include(<workmanager/WorkmanagerPlugin.h>)
#import <workmanager/WorkmanagerPlugin.h>
#else
@import workmanager;
#endif

@implementation GeneratedPluginRegistrant
 
 + (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
   @try {
     [Add2CalendarPlugin registerWithRegistrar:[registry registrarForPlugin:@"Add2CalendarPlugin"]];
   } @catch (NSException *e) {
     NSLog(@"[PluginGuard] add_2_calendar registration crashed: %@", e);
   }
   [FLTFirebaseFirestorePlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseFirestorePlugin"]];
   [ConnectivityPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"ConnectivityPlusPlugin"]];
   [FilePickerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FilePickerPlugin"]];
   [FLTFirebaseAuthPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseAuthPlugin"]];
   [FLTFirebaseCorePlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseCorePlugin"]];
   [FLTFirebaseMessagingPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseMessagingPlugin"]];
   [FLTFirebaseStoragePlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseStoragePlugin"]];
   [FlutterLocalNotificationsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterLocalNotificationsPlugin"]];
   [FlutterNativeSplashPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterNativeSplashPlugin"]];
   [FluttertoastPlugin registerWithRegistrar:[registry registrarForPlugin:@"FluttertoastPlugin"]];
   [FLTGoogleMapsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTGoogleMapsPlugin"]];
   [FLTImagePickerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTImagePickerPlugin"]];
   [FPPPackageInfoPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPPackageInfoPlusPlugin"]];
   [PathProviderPlugin registerWithRegistrar:[registry registrarForPlugin:@"PathProviderPlugin"]];
   [PermissionHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
   [SharedPreferencesPlugin registerWithRegistrar:[registry registrarForPlugin:@"SharedPreferencesPlugin"]];
   [SqflitePlugin registerWithRegistrar:[registry registrarForPlugin:@"SqflitePlugin"]];
   [URLLauncherPlugin registerWithRegistrar:[registry registrarForPlugin:@"URLLauncherPlugin"]];
   [WorkmanagerPlugin registerWithRegistrar:[registry registrarForPlugin:@"WorkmanagerPlugin"]];
 }

@end

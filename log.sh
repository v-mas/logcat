#!/usr/bin/perl
use strict;
use Getopt::Long;

##
# script to fasten usage of adb command, in particular to reference device by alias
# and to filter common logs coming from system
##

my $serialId = '';
my $clean = '';
my $help = '';
my $wifi = '';
my $info = '';
my $dump = '';
my $verbose = '';
my $pid = '';

my $network_address = "192.168.1.";

GetOptions (
    "clean"       => \$clean,
    "serialId=s"  => \$serialId,
    "help"        => \$help,
    "wifi"        => \$wifi,
    "info"        => \$info,
    "dump"        => \$dump,
	"pid=s"       => \$pid,
    "verbose"     => \$verbose
  );

my $isCygwin = `uname` == 'CYGWIN*';

my $ip = '';
#array of aliases for known devices
my @serials = (
# [['alias1', 'alias2'], 'device id as in logcat devices'],
  );

if($serialId ne "") {
  my @matches = $serialId =~ '^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$';
  if(scalar @matches gt 0) {
    $ip = $network_address.$matches[0];
    print 'trying to use IP address: '.$ip."\n";
  } else {
    for my $row (@serials) {
      my @rawr = @$row;
      my @keys = @{@rawr[0]};
      my $serial = @rawr[1];
      if(grep lc $_ eq lc $serialId, @keys) {
        if($verbose) {
          print 'serials hit: '.$serial."\n";
        }
        $serialId = $serial;
        last;
      }
    }
    $serialId = ' -s '.$serialId;
  }
}

if($ip eq "" and $wifi) {
  my $interfaceStatus = `adb $serialId shell netcfg | grep wlan0 | awk '{print \$2}'`;
  chomp $interfaceStatus;
  if($verbose) {
    print 'wifi status: '.$interfaceStatus."\n";
  }
  if($interfaceStatus eq "UP") {
    $ip = `adb $serialId shell ifconfig wlan0 | awk '{print \$3}'`;
    chomp $ip;
    if($verbose) {
      print 'device ip: '.$ip."\n";
    }
    my $comm = 'adb '.$serialId.' tcpip 5555';
    if($verbose) {
      print 'turning on wifi adb: '.$comm."\n";
    }
    print `$comm`;
    print 'you can use " -s '.$ip.':5555" from now on'."\n";
  } else {
    print 'wifi on device is down. please turn it on and connect manually or run this command again'."\n";
    exit;
  }
}
if($ip ne "") {
  my $comm = 'adb connect '.$ip.':5555';
  if($verbose) {
    print 'connecting to '.$ip.':  '.$comm."\n";
  }
  print `$comm`;
  $serialId = ' -s '.$ip.':5555';
}

if($info) {
  my $interfaceStatus = `adb $serialId shell netcfg | grep wlan0 | awk '{print \$2}'`;
  chomp $interfaceStatus;
  my $ip = `adb $serialId shell ifconfig wlan0 | awk '{print \$3}'`;
  chomp $ip;
  if($interfaceStatus eq "UP") {
    print 'wifi in on, ip: '.$ip."\n";
  } else {
    print 'wifi is off'."\n";
  }
  exit;
}

my $command = 'adb'.$serialId.' logcat -v threadtime ';

if($dump) {
  $command = $command.'-d ';
}

my $cutPid = "awk '{print \$2}'";

if($pid) {
  my $pid_command = "adb $serialId shell ps | grep $pid | $cutPid | head -n1";
  if($verbose) {
    print $pid_command."\n";
  }
  $pid = `adb $serialId shell ps | grep $pid | $cutPid | head -n1`;
  if(!$pid) {
    print "application is not running";
	exit -1;
  }
  if($verbose) {
    print 'found pid: '.$pid;
  }
  $command = $command.'| grep -a --color '.$pid;
}

my @devices = (
    [['', 'all'], $command.''],

    [['devices'], 'adb devices'],
    [['appops'], 'adb'.$serialId.' shell am start -n com.android.settings/com.android.settings.Settings -e :android:show_fragment com.android.settings.applications.AppOpsSummary --activity-clear-task --activity-exclude-from-recents'],
    [['record'], 'filename=/storage/emulated/legacy/Download/`date +"%Y%m%d_%H%M"`.mp4; echo $filename; adb'.$serialId.' shell screenrecord $filename --bit-rate 8000000'],
    [['recordSD'], 'filename=/sdcard/Download/`date +"%Y%m%d_%H%M"`.mp4; echo $filename; adb'.$serialId.' shell screenrecord $filename --bit-rate 8000000'],
    [['screenshot', 'screen', 'ss'], 'filename="`date +"%Y%m%d_%H%M%S"`.png"; adb start-server; adb'.$serialId.' exec-out screencap -p > $filename && echo "saved as $filename"'.($isCygwin?' && explorer /select, `cygpath -w $filename`':'')],
    [['monkey'], 'adb'.$serialId.' shell monkey -p '.$pid.' -v 30000 -s 1000 --pct-touch 20 --pct-motion 20 --pct-nav 40 --pct-majornav 60 --pct-syskeys 20 --pct-appswitch 50 --ignore-security-exceptions > /dev/zero &'],
    [['monkeykill'], 'adb'.$serialId.' shell kill -s 9 `adb'.$serialId.' shell ps | grep monkey | '.$cutPid.'`'],

  # adb logcat filters
    [['excep', 'err'], $command.' | grep -ai "at \|exception\|runtime\|err\| E "'],

    [['lg'], $command.' | grep -avi "SignalStrength\|Bright\|LG\|PhoneInterfaceManager\|Keyguard\|PowerManager\|Wifi\|Theme\|Weather\|xt9\|wpa_supplicant\|QRemote\|MusicBrowser\|GpsLocationProvider\|Netd\|DownloadManager\|LFT\|ConnectivityService\|EAS\|SurfaceFlinger\|NetworkStats\|Tethering\|Usb\|Picasa\|OSP\|NFC\|AccessPoint\|LocSvc\|QMI\|MediaPlayer\|HttpPlayerDriver\|MediaPlayerService\|NexPlayerMPI\|NEXSTREAMING\|qcom_audio_policy_hal\|AwesomePlayer\|AudioSink\|ForecastDataCache\|KInfoc\|NtpTrustedTime\|GCoreUlr\|ALSA\|AudioTrack\|OMXCodec\|InputMethodManagerService\|AudioFlinger\|SoundPool\|AudioPolicyManagerBase\|SoundPool\|LocationManagerService"'],
    [['moto', 'motorola'], $command.' | grep -avi "WiFiState\|WiFiService\|mobileData\|Diag_lib\|Ulp\|SBar\|SFPerf\|MDMCTBK\|fb4a\|GCore\|AlarmManager\|KeyGuard\|audio_a2dp\|AonLT\|ModemStatus\|msm8974\|3CDM\|qdhwcomposer\|LaunchCheckin\|JavaBinder\|Documents\|AuthorizationBluetoothService\|LocationSettingsChecker\|DocsApplication\|MultiDex\|MediaFocusControl\|GAV2\|LocationInitializer\|keystore\|PackageBroadcastService\|Installe\|PackageInfoHelper\|CrossAppStateProvider\|Finsky\|PackageManager\|Mtp\|Picasa\|FingerprintManager\|Uploads\|Usb\|Entropy\|LBS"'],
    [['nexus5', '5'], $command.' | grep -avi "CalendarProvider2\|libprocessgroup\|WifiService\|wpa\|Connectivity\|wifi\|ThermalEngine\|InputMethodInfo\|audio_hw_primary\|LocationOracleImpl\|ContentResolver\|fb4a\|BluetoothAdapter\|HHXmlParser\|GAV4\|GCoreUlr\|Fitness\|avc: denied\|GATimingLogger\|ACDB-LOADER\|GpsLocationProvider\|dhcpcd\|GCM\|GAV3\|FiksuTracking\|MicrophoneInputStream\|AudioFlinger\|TelephonyNetworkFactory\|Nat464Xlat\|TaskPersister\|CommandListener\|msm8974_platform\|Tethering\|iu.SyncManager\|iu.UploadsManager\|Babel\|ConfigClient\|ConfigFetchService\|Finsky\|Gmail\|CalendarProvider\|AbstractGoogleClient\|SQLiteLog\|GAV\|DrmWidevineDash\|SyncWapiModule\|ActiveOrDefaultContextProvider\|QSEECOMAPI\|AnalyticsLogBase\|WVCdm\|NewsWeather\|GHttpClientFactory"'],
    [['nexus5x', '5x'], $command.' | grep -avi "AdvertisingIdClient\|zygote64\|CheckinRequestBuilder\|QC-time-services\|WifiService\|Adreno\|TelephonySpam\|Conscrypt\|ModuleInitIntentOp\|AsyncOpDispatcher\|PhenotypeFlagCommitter"'],
    [['nexus7', '7', 'tab7'], $command.' | grep -avi "OMX.google.mp3.decoder\|libgps\|BluetoothSocket\|ThrottleService\|UsageStats"'],
    [['redmi'], $command.' | grep -avi "ThermalEngine\|ScanImpl\|WLAN_PSA\|ActivityManager\|WifiService\|cnss_diag\|WifiHAL\|wpa_supplicant\|AlarmManager\|ProximitySensorWrapper\|IzatSvc_PassiveLocListener\|MiuiPerfServiceClient\|BaseMiuiPhoneWindowManager\|qti_sensors_hal"'],
    [['sony ultra', 'paletka', 'sonyultra', 'z ultra'], $command.' | grep -avi "ProcessCpuTracker\|QcConnect\|HSM\|CameraAddon\|InternalIcing\|GoogleTag\|StatusBar\|ConfigFetch\|ConfigService\|PhotoSyncService\|HttpOperation\|GLSUser\|Gmail\|CalendarSyncAdapter\|ContactsSyncAdapter\|Babel\|GAV\|rmt_storage\|appoxee\|Adreno-EGL\|Vold\|WebViewChromium\|ConnectivityMonitor\|QCNEA\|EsTileSync\|SizeAdaptiveLayout\|libcamera\|ControllerSDK\|MobileDataStateTracker\|WiFi\|sony\|wpa_\|ACDB\|alsa\|Tethering\|AsahiSignature"'],
    [['sony z', 'sony', 'sonyz', 'z'], $command.' | grep -avi "wifi_gbk2utf\|StatusBar.NetworkController\|QC-QMI\|wpa_supplicant\|KInfoc\|ProcessStatsService\|Settings\|ConnectivityServiceHSM\|docs.net.Status\|NDK_NativeApplicationBuilder\|JSVM\|QcConnectivityService\|GAV\|Vold\|NetworkChangeReceiver\|ALSA\|ACDB-LOADER\|CustomizationProcess\|SoLoader\|Icing\|MultiDex\|SocialEngine\|fb4a\|ConfigFetchService\|ConfigService\|SystemClassLoaderAdder\|sony\|GpsXtraDownloader\|ConfigFetchTask\|AudioTrack\|UserLocationProducer\|FA-SVC\|WifiHAL\|Finsky\|ProcessCpuTracker"'],
    [['sonyj', 'sony j', 'j'], $command.' | grep -avi "SignalStrength\|BatteryService\|ConnectivityService\|StatusBar.NetworkController\|AudioHardwareMSM76XXA\|SecureClock\|Icing\|WifiStateMachine\|ConfigFetchService\|PeopleDatabaseHelper\|MobileDataStateTracker\|com.sonyericsson.updatecenter\|Finsky\|ConfigFetchTask\|PowerManagerService\|ThrottleService\|Adreno200-EGL\|AudioTrack\|RPC\|LocSvc_\|WifiStateMachine\|wpa_supplicant\|StateMachine\|Tethering"'],
    [['samsung', 'sgs3', 's3'], $command.' | grep -avi "MediaPlayer-JNI\|MediaPlayer\|STATUSBAR-\|AwesomePlayer\|StagefrightPlayer\|ProgressBar\|AlarmManager\|Watchdog\|SensorService\|SSRMv2\|BatteryService\|KeyguardClockWidgetService\|AbsListView\|InputDispatcher\|InputReader\|AudioPolicyManagerBase\|LvOutput\|PowerManagerService\|Samsung TTS:\|ContexualWidgetMonitor\|NetworkStats\|LockPatternUtils\|iNemoSensor\|AkmSensor"'],
    [['k1', 'shield', 'nV', 'nVidia'], $command.' | grep -avi "BaseInterceptor\|WifiUtil\|WifiService\|ContentHelper\|NvOsDebugPrintf"'],
    [['asus'], $command.' | grep -avi "upi_ug31xx\|<UG31/E>\|wpa_supplicant\|PowerUI\|KeyguardUpdateMonitor\|DownloadManagerWrapper\|PowerSaverUpdateIcon\|CarrierText\|Telecom\|SignalClusterView\|StatusBar.NetworkController\|WifiWatchdog\|WifiStateMachine\|lights\|audio-parameter-manager\|FA-SVC\|KeyguardSecurityView\|ImageWallpaper\|Asus"']
    [['sgsa', 'alpha'], $command.' | grep -avi "StatusBar.NetworkController\|wpa_supplicant\|BatteryService\|ActivityManager\|AudioPolicyManager\|BatteryMeterView\|MotionRecognitionService\|KeyguardUpdateMonitor\|STATUSBAR-WifiQuickSettingButton\|FaceInterface\|AwesomePlayer\|OMXCodec\|AudioCache\|OggExtractor\|StagefrightPlayer\|smd Interface\|KeyguardMessageArea\|KeyguardEffectViewController"'],
	[['sgs8'], $command.' | grep -avi "dex2oat\|LiveIconLoader\|ConnectivityService\|WifiConnectivityMonitor\|APM_AudioPolicyManager\|SamsungAlarmManager\|DisplayPowerController\|SEC LightsHAL:\|KeyguardViewMediator\|bauth_FPBAuth\|TeeSysClient\|ContactsProvider_EventLog\|NetworkController.MobileSignalController\|TLC_TIMA_PKM\|mc_tlc_communication\|GLAnimatorManager\|GyroRender\|SurfaceFlinger\|LiveClock\|GalaxyWallpaper\|WallpaperManager\|PowerManagerService\|AODWindowManager\|oneconnect\|PluginPlatform\|BixbyApi_0\|SamsungAnalytics\|ResourceType\|Knox\|SSRM:\|SsacManager\|GOS:\|MotionRecognitionService\|AudioService\|audio_hw_primary_abox\|SdpLogService\|ResourceManagerService\|ACodec\|OMX\|InputMethodManagerService\|libexynosv4l2\|tlc_communication\|TrayVisibilityController\|CocktailBarUiController\|AccessibilityManagerService\|LightsService\|UcmService\|audio_hw\|audio_route\|SDPLog.d\|LauncherApp\|InputReader\|VRLauncherManager\|DragLayer\|soundtrigger_hw\|WeatherWidget\|android.hardware.\|SamsungPhone\|BeaconBle\|PackageManager\|skia"'],
  );
my $arg = join(' ', @ARGV);


if($help) {
  print '    -c --clean        clean device logs                          '."\n";
  print '    -s deviceId       use given device or last IP quartet        '."\n";
  print '    -w --wifi         turn on wifi adb on device and connect     '."\n";
  print '    -i --info         display various info about selected device '."\n";
  print '    -d --dump         run once and exit                          '."\n";
  print '    -p --pid package  name of the process to watch (TODO)        '."\n";
  print '    -h --help         print this help message                    '."\n";
  
  print "\n available devices/modes:\n";
  for my $row (@devices) {
    my @rawr = @$row;
    my @keys = @{@rawr[0]};
    print "    [".join('], [', @keys)."]\n";
  }
  exit 0;
}

if($clean) {
  my $comm = 'adb'.$serialId.' logcat -c';
  if($verbose) {
    print $comm."\n";
  }
  system($comm);
}

for my $row (@devices) {
  my @rawr = @$row;
  my @keys = @{@rawr[0]};
  my $comm = @rawr[1];
  if(grep lc $_ eq lc $arg, @keys) {
    if($verbose) {
      print $comm."\n";
    }
    system($comm);
    print "finished\n";
    exit 0;
  }
}

system($command.$arg);

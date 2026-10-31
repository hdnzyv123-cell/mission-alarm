import UIKit
import Flutter
import UserNotifications
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

    private var audioPlayer: AVAudioPlayer?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "com.opensource.missionalarm/scheduler",
            binaryMessenger: controller.binaryMessenger
        )

        UNUserNotificationCenter.current().delegate = self

        channel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "requestCriticalAlertPermission":
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge, .criticalAlert]
                ) { granted, error in
                    result(granted)
                }
            case "scheduleIosCriticalAlarm":
                guard let args = call.arguments as? [String: Any],
                      let alarmId = args["alarmId"] as? Int,
                      let hour = args["hour"] as? Int,
                      let minute = args["minute"] as? Int,
                      let soundFile = args["soundFile"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                    return
                }
                self?.scheduleCriticalNotification(alarmId: alarmId, hour: hour, minute: minute, soundFile: soundFile)
                result(true)
            case "startBackgroundAudioLoop":
                guard let args = call.arguments as? [String: Any],
                      let soundFile = args["soundFile"] as? String else {
                    result(false)
                    return
                }
                self?.startCriticalAudioSession(soundFile: soundFile)
                result(true)
            case "stopRingingService":
                self?.audioPlayer?.stop()
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func scheduleCriticalNotification(alarmId: Int, hour: Int, minute: Int, soundFile: String) {
        let content = UNMutableNotificationContent()
        content.title = "MISSION ALARM ACTIVE"
        content.body = "Open and complete your mission immediately to stop the alarm."
        content.interruptionLevel = .critical
        content.sound = UNNotificationSound.criticalSoundNamed(
            UNNotificationSoundName(rawValue: soundFile),
            withAudioVolume: 1.0
        )

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "mission_alarm_\(alarmId)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func startCriticalAudioSession(soundFile: String) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)

            if let url = Bundle.main.url(forResource: soundFile, withExtension: nil) {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.volume = 1.0
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            }
        } catch {
            print("Failed to start iOS critical audio session: \(error)")
        }
    }
}

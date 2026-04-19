import Foundation
import AppKit
import Carbon.HIToolbox

/// Registers a global ⌥⌘F hotkey using Carbon. Fires a notification when pressed.
/// No accessibility permission required.
final class HotkeyService {
    static let shared = HotkeyService()
    static let hotkeyPressed = Notification.Name("org.frontiercommons.shot-maker.hotkey")

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func register() {
        let signature: FourCharCode = 0x534D4B52 // 'SMKR'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)

        // ⌥⌘F
        let modifiers: UInt32 = UInt32(cmdKey | optionKey)
        let keyCode: UInt32 = UInt32(kVK_ANSI_F)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            NotificationCenter.default.post(name: HotkeyService.hotkeyPressed, object: nil)
            return noErr
        }, 1, &eventType, nil, &eventHandler)
        if handlerStatus != noErr {
            print("[ShotMaker] HotkeyService: InstallEventHandler failed with status \(handlerStatus)")
        }

        let hotkeyStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                               GetApplicationEventTarget(), 0, &hotKeyRef)
        if hotkeyStatus != noErr {
            print("[ShotMaker] HotkeyService: RegisterEventHotKey failed with status \(hotkeyStatus) — ⌥⌘F may already be taken by another app")
        }
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
        hotKeyRef = nil
        eventHandler = nil
    }
}

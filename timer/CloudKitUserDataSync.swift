#if os(iOS)
import CloudKit
import Combine
import Foundation

/// Syncs Upzo user data to **iCloud CloudKit private database** (`iCloud.com.amay.timer`).
///
/// What is stored remotely (encrypted by Apple, tied to the user's iCloud account):
/// - Alarms, wake history, onboarding flags/profile, commitment flag
/// - App settings, notification preferences, subscription cache metadata
///
/// Requires: Sign in with Apple (app gate) + iCloud signed in on the device.
@MainActor
final class CloudKitUserDataSync: ObservableObject {
    static let shared = CloudKitUserDataSync()

    static let containerIdentifier = "iCloud.com.amay.timer"

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: String?

    private let container = CKContainer(identifier: containerIdentifier)
    private let recordID = CKRecord.ID(recordName: "primaryUserBackup")
    private let recordType = "UpzoUserBackup"
    private let payloadField = "payloadJSON"
    private let modifiedAtField = "modifiedAt"

    private enum Keys {
        static let localModifiedAt = "cloudBackup.localModifiedAt"
    }

    private var uploadTask: Task<Void, Never>?
    static var isApplyingRemoteSnapshot = false

    private init() {}

    static var localModifiedAt: Date {
        let interval = UserDefaults.standard.double(forKey: Keys.localModifiedAt)
        if interval > 0 {
            return Date(timeIntervalSince1970: interval)
        }
        return Date.distantPast
    }

    static func setLocalModifiedAt(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: Keys.localModifiedAt)
    }

    static func markLocalDataChanged() {
        guard !isApplyingRemoteSnapshot else { return }
        setLocalModifiedAt(Date())
        shared.scheduleUpload()
    }

    func bootstrap(alarmStore: AlarmStore, wakeHistory: WakeHistoryStore) async {
        guard AccountStore.shared.isSignedIn,
              let appleUserID = UserDefaults.standard.string(forKey: "account.appleUserID"),
              !appleUserID.isEmpty
        else { return }

        guard await isCloudAvailable() else {
            lastSyncError = nil
            return
        }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        let local = UserDataSnapshot.capture(appleUserID: appleUserID)

        do {
            if let remote = try await fetchRemote() {
                if remote.modifiedAt > local.modifiedAt {
                    await UserDataSnapshot.apply(remote, alarmStore: alarmStore, wakeHistory: wakeHistory)
                } else if local.hasMeaningfulData, local.modifiedAt >= remote.modifiedAt {
                    try await upload(local)
                }
            } else if local.hasMeaningfulData {
                try await upload(local)
            }
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func scheduleUpload() {
        guard AccountStore.shared.isSignedIn else { return }
        uploadTask?.cancel()
        uploadTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await uploadIfPossible()
        }
    }

    func deleteRemoteBackup() async {
        guard await isCloudAvailable() else { return }
        do {
            try await database.deleteRecord(withID: recordID)
            lastSyncError = nil
        } catch let error as CKError where error.code == .unknownItem {
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func uploadIfPossible() async {
        guard AccountStore.shared.isSignedIn,
              let appleUserID = UserDefaults.standard.string(forKey: "account.appleUserID"),
              !appleUserID.isEmpty,
              await isCloudAvailable()
        else { return }

        let snapshot = UserDataSnapshot.capture(appleUserID: appleUserID)
        guard snapshot.hasMeaningfulData else { return }

        do {
            try await upload(snapshot)
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func isCloudAvailable() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    private func fetchRemote() async throws -> CloudUserBackupPayload? {
        do {
            let record = try await database.record(for: recordID)
            return try decode(record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func upload(_ payload: CloudUserBackupPayload) async throws {
        var payload = payload
        payload.modifiedAt = Date()
        CloudKitUserDataSync.setLocalModifiedAt(payload.modifiedAt)

        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }

        let data = try JSONEncoder().encode(payload)
        guard let json = String(data: data, encoding: .utf8) else { return }
        record[payloadField] = json as CKRecordValue
        record[modifiedAtField] = payload.modifiedAt as CKRecordValue

        _ = try await database.save(record)
    }

    private func decode(_ record: CKRecord) throws -> CloudUserBackupPayload {
        guard let json = record[payloadField] as? String,
              let data = json.data(using: .utf8)
        else {
            throw CKError(.internalError)
        }
        return try JSONDecoder().decode(CloudUserBackupPayload.self, from: data)
    }

    private var database: CKDatabase {
        container.privateCloudDatabase
    }
}
#endif

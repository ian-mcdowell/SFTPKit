//
//  SFTPConnection.swift
//  SFTPKit
//
//  Created by Ian McDowell on 4/9/18.
//  Copyright © 2018 Ian McDowell. All rights reserved.
//

import ConnectionKit
import NMSSH

private enum SFTPError: LocalizedError {
	case unableToConnectSSH
	case unableToConnectSFTP
	case authentication
	
	var errorDescription: String? {
		switch self {
		case .unableToConnectSSH: return "Unable to connect via SSH."
		case .unableToConnectSFTP: return "Unable to connect via SFTP."
		case .authentication: return "Unable to authenticate via SSH."
		}
	}
}

public class SFTPConnection: ServerConnection {
	
	public static let properties: ServerConnectionProperties = .init(
		displayName: "SFTP",
		defaultPort: 22,
		allowsCustomPort: true,
		bonjourServiceType: "_ssh._tcp"
	)
	
	private let session: NMSFTP
	private let queue = DispatchQueue(label: "SSHConnection")
	
	public required init(address: String, port: Int16, username: String, password: String) throws {
		
		// Connect to SSH
		guard let sshSession = NMSSHSession.connect(toHost: address, port: Int(port), withUsername: username) else {
			throw SFTPError.unableToConnectSSH
		}
		
		// Authenticate
		guard sshSession.authenticate(byPassword: password) else {
			throw SFTPError.authentication
		}
		
		// Connect to SFTP
		guard let sftpSession = NMSFTP.connect(with: sshSession) else {
			throw SFTPError.unableToConnectSFTP
		}
		
		self.session = sftpSession
	}
	
	public func contents(ofDirectory directory: RemotePath, _ completion: @escaping (Result<[RemoteItem]>) -> Void) {
		
		queue.async {
			
			guard let items = self.session.contentsOfDirectory(atPath: directory) as? [NMSFTPFile] else {
				DispatchQueue.main.async { completion(.error(ServerConnectionError.cantListDirectory)) }
				return
			}
			
			DispatchQueue.main.async {
				
				let remoteItems: [RemoteItem] = items.map { item in
					self.remoteItemFromInfo(item)
				}
				completion(.value(remoteItems))
			}
		}
	}
	
	public func download(file: RemotePath, to destination: URL, _ completion: @escaping (Error?) -> Void) -> Progress {
		let progress = Progress()
		progress.kind = ProgressKind.file
		progress.setUserInfoObject(Progress.FileOperationKind.downloading, forKey: ProgressUserInfoKey.fileOperationKindKey)
		progress.setUserInfoObject(1, forKey: ProgressUserInfoKey.fileTotalCountKey)
		progress.setUserInfoObject(destination, forKey: ProgressUserInfoKey.fileURLKey)
		progress.isCancellable = true
		
		print("SSHConnection: Downloading file: \(file) to \(destination).")
		queue.async {
			do {
				let fileData = self.session.contents(atPath: file, progress: { done, total -> Bool in
					progress.completedUnitCount = Int64(done)
					progress.totalUnitCount = Int64(total)
					return !progress.isCancelled
				})
				try fileData?.write(to: destination)
				
				DispatchQueue.main.async { completion(nil) }
			} catch {
				return DispatchQueue.main.async { completion(error) }
			}
		}
		return progress
	}
	
	public func upload(file: URL, renameTo newName: String?, to destination: RemotePath, _ completion: @escaping (Result<RemoteFile>) -> Void) {
		
//		if file.isDirectory {
//			return completion(.error(ServerConnectionError.cantUploadDirectory))
//		}
		
		// Path + / + fileName
		let destinationPath = (destination as NSString).appendingPathComponent(newName ?? file.lastPathComponent)
		
		print("SSHConnection: Uploading file: \(file) to \(destinationPath)")
		
		queue.async {
			let success = self.session.writeFile(atPath: file.path, toFileAtPath: destinationPath)
			
			// Get created file information
			guard let file = self.session.infoForFile(atPath: destinationPath) else {
				return DispatchQueue.main.async { completion(.error(ServerConnectionError.cantListDirectory)) }
			}
			
			DispatchQueue.main.async {
				
				if !success {
					return completion(.error(ServerConnectionError.uploadError))
				}
				
				guard let remoteFile = self.remoteItemFromInfo(file) as? RemoteFile else {
					return completion(.error(ServerConnectionError.uploadError))
				}
				completion(.value(remoteFile))
			}
		}
	}
	
	public func move(item: RemotePath, to destination: RemotePath, _ completion: @escaping (Error?) -> Void) {
		
		let path = item
		
		// Path + / + fileName
		let destinationPath = (destination as NSString).appendingPathComponent((item as NSString).lastPathComponent)
		
		print("SSHConnection: Moving item: \(item) to \(destinationPath).")
		
		queue.async {
			let success = self.session.moveItem(atPath: path, toPath: destinationPath)
			
			DispatchQueue.main.async {
				completion(success ? nil : ServerConnectionError.moveError)
			}
		}
	}
	
	public func rename(item: RemotePath, to newName: String, _ completion: @escaping (Error?) -> Void) {
		let path = item
		
		let destinationPath = ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent(newName)
		
		print("SSHConnection: Moving item: \(item) to \(destinationPath).")
		
		queue.async {
			let success = self.session.moveItem(atPath: path, toPath: destinationPath)
			
			DispatchQueue.main.async {
				completion(success ? nil : ServerConnectionError.moveError)
			}
		}
	}
	
	public func createDirectory(in directory: RemotePath, named name: String, _ completion: @escaping (Result<RemoteFolder>) -> Void) {
		let path = directory
		
		let folderPath = (path as NSString).appendingPathComponent(name)
		
		print("SSHConnection: Creating directory: \(folderPath)")
		
		queue.async {
			if !self.session.createDirectory(atPath: folderPath) {
				return DispatchQueue.main.async { completion(.error(ServerConnectionError.createDirectoryError)) }
			}
			
			guard let info = self.session.infoForFile(atPath: folderPath), let remoteFolder = self.remoteItemFromInfo(info) as? RemoteFolder else {
				return DispatchQueue.main.async { completion(.error(ServerConnectionError.createDirectoryError)) }
			}
			
			DispatchQueue.main.async {
				completion(.value(remoteFolder))
			}
			
		}
	}
	
	public func delete(at path: RemotePath, type: RemoteItemType, _ completion: @escaping (Error?) -> Void) {
	
		print("SSHConnection: Deleting item: \(path)")
		
		queue.async {
			let success: Bool
			switch type {
			case .folder:
				success = self.session.removeDirectory(atPath: path)
			case .file:
				success = self.session.removeFile(atPath: path)
			}
			
			DispatchQueue.main.async {
				if success {
					completion(nil)
				} else {
					completion(ServerConnectionError.deleteError)
				}
			}
		}
	}
	
}

private extension SFTPConnection {
	func remoteItemFromInfo(_ item: NMSFTPFile) -> RemoteItem {
		guard let name = item.filename else { fatalError("Item received with no file name.") }
		let sizeNumber = item.fileSize ?? 0
		let metadata = RemoteItemMetadata(size: sizeNumber.uint64Value, lastModified: item.modificationDate, created: nil)
		if item.isDirectory {
			return RemoteFolder(name: name, metadata: metadata)
		} else {
			return RemoteFile(name: name, metadata: metadata)
		}
	}
}

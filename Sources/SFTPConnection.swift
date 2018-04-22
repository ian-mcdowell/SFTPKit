//
//  SFTPConnection.swift
//  SFTPKit
//
//  Created by Ian McDowell on 4/9/18.
//  Copyright © 2018 Ian McDowell. All rights reserved.
//

import ConnectionKit
import NMSSH

public class SFTPConnection: ServerConnection {
	public static var displayName: String { return "SFTP" }
	public static var defaultPort: Int { return 22 }
	public static var allowsCustomPort: Bool { return true }
	public static var bonjourServiceType: String? { return "_ssh._tcp" }
	
	public required init(address: String, port: Int16, username: String, password: String) throws {
		
	}
	
	public func contents(ofDirectory directory: RemotePath, _ completion: @escaping (Result<[RemoteItem]>) -> Void) {
		
	}
	
	public func download(file: RemotePath, to destination: URL, _ completion: @escaping (Error?) -> Void) -> Progress {
		return Progress()
	}
	
	public func upload(file: URL, renameTo newName: String?, to destination: RemotePath, _ completion: @escaping (Result<RemoteFile>) -> Void) {
		
	}
	
	public func move(item: RemotePath, to destination: RemotePath, _ completion: @escaping (Error?) -> Void) {
		
	}
	
	public func rename(item: RemotePath, to newName: String, _ completion: @escaping (Error?) -> Void) {
		
	}
	
	public func createDirectory(in directory: RemotePath, named name: String, _ completion: @escaping (Result<RemoteFolder>) -> Void) {
		
	}
	
	public func delete(item: RemotePath, _ completion: @escaping (Error?) -> Void) {
		
	}
	
}


//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_BUILDING_WITH_CMAKE
@_implementationOnly import _TestingInternals
#else
private import _TestingInternals
#endif

extension CommandLine {
  /// Get the command-line arguments passed to this process.
  ///
  /// - Returns: An array of command-line arguments.
  ///
  /// This function works around a bug in the Swift standard library that causes
  /// the built-in `CommandLine.arguments` property to not be concurrency-safe.
  /// ([swift-#66213](https://github.com/apple/swift/issues/66213))
  static func arguments() -> [String] {
    UnsafeBufferPointer(start: unsafeArgv, count: Int(argc)).lazy
      .compactMap { $0 }
      .compactMap { String(validatingUTF8CString: $0) }
  }

  /// The path to the current process' executable.
  static var executablePath: String {
    get throws {
#if os(macOS)
      var result: String?
      var bufferCount = UInt32(1024)
      while result == nil {
        result = withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(bufferCount)) { buffer in
          // _NSGetExecutablePath returns 0 on success and -1 if bufferCount is
          // too small. If that occurs, we'll return nil here and loop with the
          // new value of bufferCount.
          if 0 == _NSGetExecutablePath(buffer.baseAddress, &bufferCount) {
            return String(cString: buffer.baseAddress!)
          }
          return nil
        }
      }
      return result!
#elseif os(Linux)
      return try withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(PATH_MAX) * 2) { buffer in
        let readCount = readlink("/proc/\(getpid())/exe", buffer.baseAddress!, buffer.count - 1)
        guard readCount >= 0 else {
          throw CError(rawValue: swt_errno())
        }
        buffer[readCount] = 0 // NUL-terminate the string.
        return String(cString: buffer.baseAddress!)
      }
#elseif os(Windows)
      return try withUnsafeTemporaryAllocation(of: wchar_t.self, capacity: Int(MAX_PATH) * 2) { buffer in
        guard 0 != GetModuleFileNameW(nil, buffer.baseAddress!, DWORD(buffer.count)) else {
          throw Win32Error(rawValue: GetLastError())
        }
        guard let path = String.decodeCString(buffer.baseAddress!, as: UTF16.self)?.result else {
          throw Win32Error(rawValue: DWORD(ERROR_ILLEGAL_CHARACTER))
        }
        return path
      }
#else
#warning("Platform-specific implementation missing: executable path unavailable")
      return ""
#endif
    }
  }
}

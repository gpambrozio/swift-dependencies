@_transparent
@usableFromInline
@inline(__always)
func runtimeWarn(
  _ message: @autoclosure () -> String,
  category: String? = "Dependencies",
  file: StaticString? = nil,
  line: UInt? = nil
) {
  #if DEBUG
    let message = message()
    let category = category ?? "Runtime Warning"
    if _XCTIsTesting {
      if let file, let line {
        XCTFail(message, file: file, line: line)
      } else {
        XCTFail(message)
      }
    } else {
      #if canImport(os)
        os_log(
          .fault,
          dso: dso.wrappedValue,
          log: OSLog(subsystem: "com.apple.runtime-issues", category: category),
          "%@",
          message
        )
      #elseif os(WASI)
        print("[\(category)] \(message)")
      #else
        fputs("\(formatter.string(from: Date())) [\(category)] \(message)\n", stderr)
      #endif
    }
  #endif
}

// NB: We can change this to `#if DEBUG` when we drop support for Swift <5.9
#if RELEASE
#else
  #if canImport(os)
    import Foundation
    import os

    // NB: Xcode runtime warnings offer a much better experience than traditional assertions and
    //     breakpoints, but Apple provides no means of creating custom runtime warnings ourselves.
    //     To work around this, we hook into SwiftUI's runtime issue delivery mechanism, instead.
    //
    // Feedback filed: https://gist.github.com/stephencelis/a8d06383ed6ccde3e5ef5d1b3ad52bbc
    @usableFromInline
    let dso = UncheckedSendable(
      {
        let count = _dyld_image_count()
        for i in 0..<count {
          if let name = _dyld_get_image_name(i) {
            let swiftString = String(cString: name)
            if swiftString.hasSuffix("/SwiftUI") {
              if let header = _dyld_get_image_header(i) {
                return UnsafeMutableRawPointer(mutating: UnsafeRawPointer(header))
              }
            }
          }
        }
        return UnsafeMutableRawPointer(mutating: #dsohandle)
      }())
  #else
    import Foundation

    @usableFromInline
    let formatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd HH:MM:SS.sssZ"
      return formatter
    }()
  #endif
#endif

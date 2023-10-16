import Foundation

@testable import class SwiftAstGenLib.TreeNode

protocol TestUtils {
  func loadJson(file: URL) -> TreeNode?
  func withCode(code: String, testFunction: (URL, URL, URL) throws -> Void) throws
}

extension TestUtils {

  private func createUniqueName() -> String {
    return "SwiftAstGenTests\(UUID().uuidString)"
  }

  private func temporaryFileURL(fileName: String) -> URL? {
    return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(
      fileName, isDirectory: true)
  }

  func loadJson(file: URL) -> TreeNode? {
    let decoder = JSONDecoder()
    guard
      let content = try? String(contentsOf: file, encoding: .utf8),
      let treeNode = try? decoder.decode(TreeNode.self, from: content.data(using: .utf8)!)
    else {
      return nil
    }
    return treeNode
  }

  func withCode(code: String, testFunction: (URL, URL, URL) throws -> Void) throws {
    let srcTmpDir = temporaryFileURL(fileName: createUniqueName())!
    let outTmpDir = srcTmpDir.appendingPathComponent("out", isDirectory: true)
    let srcFile = srcTmpDir.appendingPathComponent("source.swift")
    let jsonFile = outTmpDir.appendingPathComponent("source.swift.json")

    try FileManager.default.createDirectory(
      atPath: srcTmpDir.path,
      withIntermediateDirectories: true,
      attributes: nil
    )
    FileManager.default.createFile(
      atPath: srcFile.path,
      contents: nil,
      attributes: nil
    )
    try code.write(
      to: srcFile,
      atomically: true,
      encoding: String.Encoding.utf8
    )

    try testFunction(srcTmpDir, outTmpDir, jsonFile)
    try FileManager.default.removeItem(at: srcTmpDir)
  }

}

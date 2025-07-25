import CodeGeneration
import Foundation

public class ScalaAstGenerator {

	private let defaultScalaOutFileUrl = URL(fileURLWithPath: "./SwiftNodeSyntax.scala")

	private func baseNode(node: Node) -> String {
		String(describing: node.base.syntaxType)
	}

	private func inheritsFrom(node: Node) -> [String] {
		let base = baseNode(node: node)
		let traits = node.layoutNode?.traits ?? []
		return [base] + traits
	}

	private func dateString() -> String {
		let currentDateTime = Date()
		let formatter = DateFormatter()
		formatter.timeStyle = .long
		formatter.dateStyle = .long
		return formatter.string(from: currentDateTime)
	}

	private func backtickedIfNeeded(name: String) -> String {
		if name == "type" { return "`\(name)`" } else { return name }
	}

	private func header() -> String {
		return """
		// Automatically generated by 'SwiftAstGen --scalaAstOnly'.
		// Do not edit directly!
		// Generated: \(dateString())

		import scala.util.Try
		import ujson.Value
		"""
	}

	public init() throws {
		if FileManager.default.fileExists(atPath: defaultScalaOutFileUrl.path) {
			try FileManager.default.removeItem(at: defaultScalaOutFileUrl)
		}
		_ = FileManager.default.createFile(
			atPath: defaultScalaOutFileUrl.path,
			contents: nil,
			attributes: nil
		)
	}

	public func generate() throws {
		let allBaseNodeNames = Set(SYNTAX_NODES.map(baseNode)).map { "\($0)" }

		let baseNodes = allBaseNodeNames.map {
			"""
			sealed trait \($0) extends SwiftNode
			"""
		}

		let allTraits = TRAITS.map {
			if $0.documentation.isEmpty {
				"sealed trait \($0.traitName)"
			} else {
				"""
				\n\t\(String(describing: $0.documentation).replacingOccurrences(of: "\n", with: "\n\t"))
				\tsealed trait \($0.traitName)
				"""
			}
		}

		let allNodes = NON_BASE_SYNTAX_NODES.map { node in
			let syntaxType = node.kind.syntaxType
			let inherits = inheritsFrom(node: node)
			let inheritsString =
				if inherits.count == 1 {
					"extends \(inherits[0])"
				} else {
					"extends \(inherits[0]) with \(inherits[1...inherits.count-1].joined(separator: " with "))"
				}

			let allChildren = node.layoutNode?.children ?? []
			var childrenString = ""
			if allChildren.count != 0 {
				childrenString =
					allChildren
					.filter { !$0.isUnexpectedNodes }
					.map { child in
						let name = backtickedIfNeeded(name: "\(child.varOrCaseName)")
						let returnTypeAndCast = TypeGenerator.returnTypeAndCast(for: child)
						return
							"\tdef \(name): \(returnTypeAndCast.returnType) = json(\"children\").arr.toList.find(_(\"name\").str == \"\(child.varOrCaseName)\").map(createSwiftNode)\(returnTypeAndCast.cast)"
					}.joined(separator: "\n\t")
			} else {
				let collection = node.collectionNode!
				let returnTypeAndCast = TypeGenerator.returnTypeAndCast(for: collection)
				childrenString =
					"\tdef children: \(returnTypeAndCast.returnType) = json(\"children\").arr.toList.map(createSwiftNode)\(returnTypeAndCast.cast)"
			}

			var documentation = String(describing: node.documentation)
			if documentation.isEmpty {
				documentation = "/// No documentation available."
			} else {
				documentation = documentation.replacingOccurrences(of: "\n", with: "\n\t")
			}

			let childrenDoc =
				node.layoutNode?.grammar ?? node.collectionNode?.grammar ?? "/// no children available"
			let childrenDocString = String(describing: childrenDoc).replacingOccurrences(
				of: "\n", with: "\n\t")

			var containedInDocString = String(describing: node.containedIn)
			containedInDocString = containedInDocString.replacingOccurrences(of: "\n", with: "\n\t")

			let docString = """
				\n\t/**
				\t/// ### Documentation
				\t///
				\t\(documentation)
				\t///
				\t\(childrenDocString)
				\t///
				\t\(containedInDocString.isEmpty ? "/// ### Nowhere contained in" : containedInDocString)
				\t */
				"""
				.replacingOccurrences(of: "///", with: " *")
				.replacingOccurrences(of: "```swift", with: "{{{")
				.replacingOccurrences(of: "```", with: "}}}")

			return """
				\(docString)
				\tcase class \(syntaxType)(json: Value) \(inheritsString) {
					\(childrenString)
				\t}
				"""
		}

		let allToken = Token.allCases.map {
			"""
			case class \($0)(json: Value) extends SwiftToken
			"""
		}

		let out = """
			\(header())

			object SwiftNodeSyntax {

				def createSwiftNode(json: Value): SwiftNode = {
					val nodeType = json("nodeType").str
					val tokenKind = json("tokenKind").str

					if (nodeType.nonEmpty) {
						\(NON_BASE_SYNTAX_NODES.map { node in
							let syntaxType = node.kind.syntaxType
							return "if (nodeType == \"\(syntaxType)\") { return \(syntaxType)(json) }"
						}.joined(separator: "\n\t\t\t"))
						if (nodeType == \"TokenSyntax\") { return TokenSyntax(json) }
						throw new UnsupportedOperationException(s"NodeType '$nodeType' is not a known Swift NodeType!")
					}

					if (tokenKind.nonEmpty) {
						\(Token.allCases.map { "if (tokenKind.startsWith(\"\($0)\")) return { \($0)(json) }" }.joined(separator: "\n\t\t\t"))
						throw new UnsupportedOperationException(s"TokenKind '$tokenKind' is not a known Swift TokenKind!")
					}

					throw new UnsupportedOperationException("Invalid SwiftSyntax json element. 'nodeType' and 'tokenKind' cannot be empty at the same time!")
				}

				sealed trait SwiftNode {
					def json: Value
					def startOffset: Option[Int] = Try(json("range")("startOffset").num.toInt).toOption
					def endOffset: Option[Int] = Try(json("range")("endOffset").num.toInt).toOption
					def startLine: Option[Int] = Try(json("range")("startLine").num.toInt).toOption
					def startColumn: Option[Int] = Try(json("range")("startColumn").num.toInt).toOption
					def endLine: Option[Int] = Try(json("range")("endLine").num.toInt).toOption
					def endColumn: Option[Int] = Try(json("range")("endColumn").num.toInt).toOption
					override def toString: String = this.getClass.getSimpleName.stripSuffix("$")
				}

				sealed trait SwiftToken extends SwiftNode

				// MARK: tokens:
				\(allToken.joined(separator: "\n\t"))

				// MARK: base nodes:
				\(baseNodes.joined(separator: "\n\t"))

				// MARK: marker traits:
				\(allTraits.joined(separator: "\n\t"))

				// MARK: syntax nodes:
				\(allNodes.joined(separator: "\n\t"))

				case class TokenSyntax(json: Value) extends Syntax

			}
			"""

		try out.write(
			to: defaultScalaOutFileUrl,
			atomically: true,
			encoding: String.Encoding.utf8
		)

		print("Generated Scala Swift AST in file: `\(defaultScalaOutFileUrl.path)`")
	}

}

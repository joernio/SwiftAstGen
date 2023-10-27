import Foundation

extension URL {
	func relativePath(from base: URL) -> String? {
		// Ensure that both URLs represent files:
		guard self.isFileURL && base.isFileURL else {
			return nil
		}

		// Remove/replace "." and "..", make paths absolute:
		let destComponents = self.standardized.resolvingSymlinksInPath().pathComponents
		let baseComponents = base.standardized.resolvingSymlinksInPath().pathComponents

		// Find number of common path components:
		var i = 0
		while i < destComponents.count && i < baseComponents.count
			&& destComponents[i] == baseComponents[i]
		{
			i += 1
		}

		// Build relative path:
		var relComponents = Array(repeating: "..", count: baseComponents.count - i)
		relComponents.append(contentsOf: destComponents[i...])
		return relComponents.joined(separator: "/")
	}
}

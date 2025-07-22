import Foundation
import SwiftSoup

let state = try await [Links].load()
let rivals = [4036425, 4102844]

rivals.forEach { id in
	let found = state.flatMap { link in
		link.lists.filter { lst in
			lst.entries.contains(where: { $0.id == id })
		}
	}
	if !found.isEmpty {
		let names = found.map(\.description).joined(separator: "\n")
		print("Found \(id) in:\n\(names)")
	}
}

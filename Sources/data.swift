import Foundation
import SwiftSoup

struct Links: Codable {
	var url: URL
	var lists: [List]
}

struct List: Codable {
	var name: String
	var url: URL
	var entries: [Entry]
}

struct Entry: Codable {
	var id: Int
}

extension Links {

	static func parse(url: URL, data: Data) throws -> Links {
		let html = String(data: data, encoding: .utf8)!
		let document = try SwiftSoup.parse(html)

		return try Links(
			url: url,
			lists: document.select("div.content").select("a").array().map { e in
				let link = try e.attr("href")
				let name = try e.text()
				return List(name: name, url: mkurl(link), entries: [])
			}
		)
	}
}

extension List {

	var description: String {
		name + (url.absoluteString.removingPercentEncoding.map { "(" + $0 + ")" } ?? "")
	}

	mutating func fill(data: Data) throws {
		let html = String(data: data, encoding: .utf8)!
		let document = try SwiftSoup.parse(html)

		entries = try document.select("tr").compactMap { tr in
			let tds = try tr.select("td").array()
			if tds.count > 1, let id = Int(try tds[1].text()) {
				return Entry(id: id)
			} else {
				return nil
			}
		}
	}
}

let session = URLSession(configuration: .default)

func mkurl(_ path: String) -> URL {
	URL(string: "https://sfedu.ru" + path)!
}

func all<A>(_ tasks: [() async -> A]) async -> [A] {
	var results = [] as [A]
	for task in tasks {
		await results.append(task())
	}
	return results
}

extension URLSession {

	func allData(_ urls: [URL]) async -> [Data] {
		await all(urls.map { url in
			{ try! await session.data(from: url).0 }
		})
	}
}

extension UserDefaults {

	var state: [Links] {
		get { data(forKey: "state").flatMap { try? JSONDecoder().decode([Links].self, from: $0) } ?? [] }
		set { try? set(JSONEncoder().encode(newValue), forKey: "state") }
	}
}

extension [Links] {

	static var urls: [URL] {
		let forms = ["Z", "O", "V"]
		let levels = ["51", "62", "65", "68", "72"]
		let cities = ["UC", "TG", "GL", "NS"]
		let finance = ["t", "o", "c", "b", "i", "p"]

		return forms.flatMap { form in
			levels.flatMap { level in
				cities.flatMap { city in
					finance.map { finance in
						mkurl("/abitur/lists?form=\(form)&level=\(level)&finance=\(finance)&city=\(city)")
					}
				}
			}
		}
	}

	static func load(local: Bool = true) async throws -> [Links] {
		let state = UserDefaults.standard.state
		if !state.isEmpty, local { return state }

		let linksURLs = urls
		let linksData = await session.allData(linksURLs)

		let links = try zip(linksURLs, linksData).map { url, data in
			try Links.parse(url: url, data: data)
		}

		let entriesData = await all(links.map { links in
			{
				let listsURLs = links.lists.map(\.url)
				let listsData = await session.allData(listsURLs)
				return (links, listsData)
			}
		})

		let populated = try entriesData.map { links, data in
			var links = links
			links.lists = try zip(links.lists, data).map { list, data in
				var list = list
				try list.fill(data: data)
				return list
			}
			return links
		}
		UserDefaults.standard.state = populated

		return populated
	}
}

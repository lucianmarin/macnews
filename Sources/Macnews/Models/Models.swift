import Foundation

public enum FeedTab: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case hot
    case cold
    case new

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hot: return "Hottest"
        case .cold: return "Coldest"
        case .new: return "Newest"
        }
    }

    public var apiPath: String {
        switch self {
        case .hot: return "/api/hot"
        case .cold: return "/api/cold"
        case .new: return "/api/new"
        }
    }

    public var viewName: String {
        switch self {
        case .hot: return "hottest"
        case .cold: return "coldest"
        case .new: return "newest"
        }
    }
}

public enum NewsFormatter {
    /// Mirrors `shortdate(timestamp)` in `../news/app/filters.py`.
    public static func shortDate(
        timestamp: Double,
        now: Double = Date().timeIntervalSince1970
    ) -> String {
        let totalSeconds = now - timestamp
        let minutes = Int((totalSeconds / 60.0).rounded())
        let hours = Int((totalSeconds / 3600.0).rounded())
        if minutes < 60 {
            return "\(max(0, minutes))m"
        }
        return "\(max(1, hours))h"
    }

    /// Mirrors Jinja2 `truncate(480, False, '...')` in `../news/templates/entry.html`.
    public static func truncateSummary(
        _ text: String,
        length: Int = 480,
        leeway: Int = 5,
        ellipsis: String = "..."
    ) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > length + leeway else {
            return cleaned
        }
        let targetLength = max(0, length - ellipsis.count)
        let prefix = String(cleaned.prefix(targetLength))
        if let lastSpace = prefix.lastIndex(where: { $0.isWhitespace }) {
            let wordAligned = String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !wordAligned.isEmpty {
                return wordAligned + ellipsis
            }
        }
        return prefix + ellipsis
    }

    /// Mirrors `sitename(value)` in `../news/app/filters.py`.
    public static func siteName(from domainOrURL: String) -> String {
        var host = domainOrURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: host), let parsedHost = url.host, !parsedHost.isEmpty {
            host = parsedHost
        }
        if host.lowercased().hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        let parts = host.split(separator: ".").map(String.init)
        guard parts.count >= 2 else {
            return host
        }
        // Handle multi-part public suffixes like .co.uk, .co.jp, .com.au
        let twoPartTLDs: Set<String> = ["co.uk", "org.uk", "ac.uk", "co.jp", "ne.jp", "or.jp", "com.au", "com.br"]
        if parts.count >= 3 {
            let lastTwo = "\(parts[parts.count - 2]).\(parts[parts.count - 1])".lowercased()
            if twoPartTLDs.contains(lastTwo) {
                return parts.dropLast(2).joined(separator: ".")
            }
        }
        return parts.dropLast(1).joined(separator: ".")
    }
}

public struct NewsEntry: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String
    public var url: String
    public var title: String
    public var domain: String
    public var site: String
    public var pub: Double
    public var age: String
    public var author: String
    public var description: String
    public var summary: String
    public var score: Double
    public var degrees: Int

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case title
        case domain
        case site
        case pub
        case age
        case author
        case description
        case summary
        case score
        case degrees
    }

    public init(
        id: String,
        url: String,
        title: String,
        domain: String,
        site: String = "",
        pub: Double,
        age: String? = nil,
        author: String = "",
        description: String = "",
        summary: String? = nil,
        score: Double = 0.0,
        degrees: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.domain = domain
        self.site = site.isEmpty ? NewsFormatter.siteName(from: domain) : site
        self.pub = pub
        self.age = age ?? NewsFormatter.shortDate(timestamp: pub)
        self.author = author
        self.description = description
        self.summary = summary ?? NewsFormatter.truncateSummary(description)
        self.score = score
        self.degrees = degrees ?? Int((score * 1000.0).rounded())
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let url = try container.decode(String.self, forKey: .url)
        let title = try container.decode(String.self, forKey: .title)
        let domain = try container.decodeIfPresent(String.self, forKey: .domain) ?? ""
        let rawSite = try container.decodeIfPresent(String.self, forKey: .site) ?? ""
        let pub = try container.decodeIfPresent(Double.self, forKey: .pub) ?? 0.0
        let decodedAge = try container.decodeIfPresent(String.self, forKey: .age)
        let author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        let description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        let decodedSummary = try container.decodeIfPresent(String.self, forKey: .summary)
        let score = try container.decodeIfPresent(Double.self, forKey: .score) ?? 0.0
        let decodedDegrees = try container.decodeIfPresent(Int.self, forKey: .degrees)

        self.id = id
        self.url = url
        self.title = title
        self.domain = domain
        self.site = rawSite.isEmpty ? NewsFormatter.siteName(from: domain.isEmpty ? url : domain) : rawSite
        self.pub = pub
        self.age = (decodedAge?.isEmpty == false) ? decodedAge! : NewsFormatter.shortDate(timestamp: pub)
        self.author = author
        self.description = description
        self.summary = (decodedSummary?.isEmpty == false) ? decodedSummary! : NewsFormatter.truncateSummary(description)
        self.score = score
        self.degrees = decodedDegrees ?? Int((score * 1000.0).rounded())
    }

    public var siteLabel: String {
        site.isEmpty ? NewsFormatter.siteName(from: domain) : site
    }

    public var ageLabel: String {
        age.hasSuffix("ago") ? age : "\(age) ago"
    }

    public var degreesLabel: String {
        "\(degrees)°"
    }
}

public struct PaginatedNewsResponse: Codable, Equatable, Sendable {
    public let page: Int
    public let pages: Int
    public let view: String
    public let site: String?
    public let entries: [NewsEntry]

    public init(
        page: Int,
        pages: Int,
        view: String = "hottest",
        site: String? = nil,
        entries: [NewsEntry]
    ) {
        self.page = page
        self.pages = pages
        self.view = view
        self.site = site
        self.entries = entries
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        let entries = try container.decodeIfPresent([NewsEntry].self, forKey: .entries) ?? []
        self.entries = entries
        self.pages = try container.decodeIfPresent(Int.self, forKey: .pages) ?? (entries.isEmpty ? 0 : page)
        self.view = try container.decodeIfPresent(String.self, forKey: .view) ?? "hottest"
        self.site = try container.decodeIfPresent(String.self, forKey: .site)
    }

    public var hasNextPage: Bool {
        page < pages && !entries.isEmpty
    }
}

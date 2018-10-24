import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // "It works" page
    router.get { req in
        return try req.view().render("welcome")
    }
    
    // Says hello
    router.get("hello") { req -> Future<View> in
        return try req.view().render("hello")
    }

    router.post("search") { req -> Future<View> in
        guard let token = Environment.get("GITHUB_TOKEN") else { throw Abort(.notFound) }
        let client = try req.make(Client.self)

        return try req.content.decode(SearchQuery.self).flatMap { query in
            client
                .get("https://package.vapor.cloud/packages/search?name=\(query.q)&limit=10", headers: ["Authorization": "Bearer \(token)"])
                .flatMap { resp in
                    return resp.content.get([PackageDescription].self, at: "repositories")
                }.map { description in
                    return SearchResultsContext(packages: description.map { Package(name: String($0.nameWithOwner.split(separator: "/")[1])) })
                }.flatMap { context in
                    return try req.view().render("search_results", context)
            }
        }
    }

    router.get("packages", String.parameter) { req -> Future<View> in
        let packageName = try req.parameters.next(String.self)
        let package = Package(name: packageName)
        return try req.view().render("package", PackageContext(package: package))
    }
}

struct SearchQuery: Content {
//    static var defaultContentType: MediaType {
//        return .formData
//    }

    let q: String
}

struct SearchResultsContext: Content {
    let packages: [Package]
}

struct PackageContext: Content {
    let package: Package
}

struct Package: Content {
    let name: String
}

struct PackageDescription: Codable {
    let nameWithOwner: String
    let description: String?
    let licenseInfo: String?
    let stargazers: Int?

    func print(on context: CommandContext) {
        if let description = self.description {
            context.console.info(nameWithOwner + ": ", newLine: false)
            context.console.print(description)
        } else {
            context.console.info(self.nameWithOwner)
        }

        if let licenseInfo = self.licenseInfo {
            let license = licenseInfo == "NOASSERTION" ? "Unknown" : licenseInfo
            context.console.print("License: " + license)
        }

        if let stars = self.stargazers {
            context.console.print("Stars: " + String(stars))
        }
    }
}

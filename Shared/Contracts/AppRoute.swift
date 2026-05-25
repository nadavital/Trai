//
//  AppRoute.swift
//  Shared
//
//  Canonical app-entry routes shared by app, intents, and widgets.
//

import Foundation

enum AppRoute: Equatable, Codable {
    case logFood
    case logWeight
    case workout(templateID: UUID?, templateName: String?)
    case chat

    nonisolated static let scheme = "trai"
    nonisolated private static let workoutTemplateIDQueryName = "template_id"
    nonisolated private static let workoutTemplateQueryName = "template"

    nonisolated static var appURL: URL {
        URL(string: "\(scheme)://")!
    }

    nonisolated var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme

        switch self {
        case .logFood:
            components.host = "logfood"
        case .logWeight:
            components.host = "logweight"
        case .workout(let templateID, let templateName):
            components.host = "workout"
            var queryItems: [URLQueryItem] = []
            if let templateID {
                queryItems.append(URLQueryItem(name: Self.workoutTemplateIDQueryName, value: templateID.uuidString))
                if let templateName, !templateName.isEmpty {
                    queryItems.append(URLQueryItem(name: Self.workoutTemplateQueryName, value: templateName))
                }
            }
            if !queryItems.isEmpty {
                components.queryItems = queryItems
            }
        case .chat:
            components.host = "chat"
        }

        return components.url ?? Self.appURL
    }

    nonisolated var urlString: String {
        url.absoluteString
    }

    init?(urlString: String) {
        guard let url = URL(string: urlString) else { return nil }
        self.init(url: url)
    }

    init?(url: URL) {
        guard url.scheme?.localizedCaseInsensitiveCompare(Self.scheme) == .orderedSame else {
            return nil
        }

        switch url.host?.lowercased() {
        case "logfood":
            self = .logFood
        case "logweight":
            self = .logWeight
        case "workout":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let templateIDValue = components?.queryItems?
                .first(where: { $0.name == Self.workoutTemplateIDQueryName })?
                .value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let parsedTemplateID = templateIDValue.flatMap(UUID.init(uuidString:))
            if templateIDValue?.isEmpty == false && parsedTemplateID == nil {
                return nil
            }
            if parsedTemplateID == nil,
               components?.queryItems?.contains(where: { $0.name == Self.workoutTemplateQueryName }) == true {
                return nil
            }
            let templateName = parsedTemplateID == nil ? nil : components?.queryItems?
                .first(where: { $0.name == Self.workoutTemplateQueryName })?
                .value
            self = .workout(templateID: parsedTemplateID, templateName: templateName)
        case "chat":
            self = .chat
        default:
            return nil
        }
    }
}

enum PendingAppRouteStore {
    static func setPendingRoute(_ route: AppRoute, defaults: UserDefaults = .standard) {
        defaults.set(route.urlString, forKey: SharedStorageKeys.AppRouting.pendingRoute)
    }

    static func consumePendingRoute(defaults: UserDefaults = .standard) -> AppRoute? {
        if let route = consumePendingRouteValue(defaults: defaults) {
            return route
        }

        if defaults === UserDefaults.standard,
           let appGroupDefaults = UserDefaults(suiteName: SharedStorageKeys.AppGroup.suiteName),
           let route = consumePendingRouteValue(defaults: appGroupDefaults) {
            return route
        }

        // Backwards compatibility for pre-route payload versions.
        if defaults.bool(forKey: SharedStorageKeys.LegacyLaunchIntents.openFoodCamera) {
            defaults.removeObject(forKey: SharedStorageKeys.LegacyLaunchIntents.openFoodCamera)
            return .logFood
        }

        if let workoutName = defaults.string(forKey: SharedStorageKeys.LegacyLaunchIntents.startWorkout) {
            defaults.removeObject(forKey: SharedStorageKeys.LegacyLaunchIntents.startWorkout)
            return workoutName == "custom" ? .workout(templateID: nil, templateName: nil) : nil
        }

        return nil
    }

    private static func consumePendingRouteValue(defaults: UserDefaults) -> AppRoute? {
        guard let routeString = defaults.string(forKey: SharedStorageKeys.AppRouting.pendingRoute) else {
            return nil
        }
        defaults.removeObject(forKey: SharedStorageKeys.AppRouting.pendingRoute)
        return AppRoute(urlString: routeString)
    }
}

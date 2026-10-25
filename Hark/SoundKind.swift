//
//  SoundKind.swift
//  Hark
//

import Foundation

enum Urgency {
    case urgent
    case caution
    case info
}

enum SoundKind: CaseIterable {
    case siren
    case carHorn
    case trainHorn
    case shouting
    case tireScreech
    case bikeBell
    case dogBarking

    var title: String {
        switch self {
        case .siren: return "Siren"
        case .carHorn: return "Car horn"
        case .trainHorn: return "Train horn"
        case .shouting: return "Shouting"
        case .tireScreech: return "Tire screech"
        case .bikeBell: return "Bike bell"
        case .dogBarking: return "Dog barking"
        }
    }

    var urgency: Urgency {
        switch self {
        case .siren, .carHorn, .trainHorn, .tireScreech: return .urgent
        case .shouting: return .caution
        case .bikeBell, .dogBarking: return .info
        }
    }
}

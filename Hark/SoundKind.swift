//
//  SoundKind.swift
//  Hark
//

import Foundation

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
}

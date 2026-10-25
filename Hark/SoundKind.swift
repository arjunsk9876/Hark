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
    case gunshot
    case backingTruck
    case motorcycle
    case thunder
    case dogGrowling
    case rattlesnake
    case skateboard

    var title: String {
        switch self {
        case .siren: return "Siren"
        case .carHorn: return "Car horn"
        case .trainHorn: return "Train horn"
        case .shouting: return "Shouting"
        case .tireScreech: return "Tire screech"
        case .bikeBell: return "Bike bell"
        case .dogBarking: return "Dog barking"
        case .gunshot: return "Gunshot"
        case .backingTruck: return "Truck backing up"
        case .motorcycle: return "Motorcycle"
        case .thunder: return "Thunder"
        case .dogGrowling: return "Dog growling"
        case .rattlesnake: return "Rattlesnake"
        case .skateboard: return "Skateboard"
        }
    }

    var urgency: Urgency {
        switch self {
        case .siren, .carHorn, .trainHorn, .tireScreech, .gunshot: return .urgent
        case .shouting, .backingTruck, .motorcycle, .thunder, .dogGrowling, .rattlesnake: return .caution
        case .bikeBell, .dogBarking, .skateboard: return .info
        }
    }
}

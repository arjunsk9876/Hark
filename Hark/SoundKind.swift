//
//  SoundKind.swift
//  Hark
//

import Foundation

enum SoundGroup: CaseIterable {
    case vehicles
    case alarms
    case people
    case suddenEvents
    case animals
    case weather
    case machinery

    var title: String {
        switch self {
        case .vehicles: return "Vehicles and traffic"
        case .alarms: return "Alarms and warnings"
        case .people: return "People"
        case .suddenEvents: return "Sudden events"
        case .animals: return "Animals"
        case .weather: return "Weather"
        case .machinery: return "Machinery"
        }
    }
}

enum SoundKind: CaseIterable {
    // Vehicles and traffic
    case siren
    case carHorn
    case airHorn
    case trainHorn
    case railroadCrossingBell
    case tireScreech
    case carAlarm
    case backupBeeper
    case motorcycle
    case engineRevving
    case truckOrBus
    case carPassing
    case bikeBell
    case skateboard

    // Alarms and warnings
    case smokeAlarm
    case burglarAlarm
    case civilDefenseSiren
    case whistle

    // People
    case screaming
    case shouting
    case babyCrying

    // Sudden events
    case gunshot
    case explosion
    case fireworks
    case glassBreaking
    case crash

    // Animals
    case dogBarking
    case dogGrowling

    // Weather
    case thunder

    // Machinery
    case jackhammer
    case chainsaw
    case powerTool
    case lawnMower
    case leafBlower
    case construction
    case helicopter

    var title: String {
        switch self {
        case .siren: return "Siren"
        case .carHorn: return "Car horn"
        case .airHorn: return "Truck horn"
        case .trainHorn: return "Train horn"
        case .railroadCrossingBell: return "Railroad crossing"
        case .tireScreech: return "Tire screech"
        case .carAlarm: return "Car alarm"
        case .backupBeeper: return "Backup beeper"
        case .motorcycle: return "Motorcycle"
        case .engineRevving: return "Engine revving"
        case .truckOrBus: return "Truck or bus"
        case .carPassing: return "Car passing"
        case .bikeBell: return "Bike bell"
        case .skateboard: return "Skateboard"
        case .smokeAlarm: return "Fire alarm"
        case .burglarAlarm: return "Burglar alarm"
        case .civilDefenseSiren: return "Warning siren"
        case .whistle: return "Whistle"
        case .screaming: return "Screaming"
        case .shouting: return "Shouting"
        case .babyCrying: return "Baby crying"
        case .gunshot: return "Gunshot"
        case .explosion: return "Explosion"
        case .fireworks: return "Fireworks"
        case .glassBreaking: return "Glass breaking"
        case .crash: return "Crash"
        case .dogBarking: return "Dog barking"
        case .dogGrowling: return "Dog growling"
        case .thunder: return "Thunder"
        case .jackhammer: return "Jackhammer"
        case .chainsaw: return "Chainsaw"
        case .powerTool: return "Power tool"
        case .lawnMower: return "Lawn mower"
        case .leafBlower: return "Leaf blower"
        case .construction: return "Construction"
        case .helicopter: return "Helicopter"
        }
    }

    var group: SoundGroup {
        switch self {
        case .siren, .carHorn, .airHorn, .trainHorn, .railroadCrossingBell, .tireScreech,
             .carAlarm, .backupBeeper, .motorcycle, .engineRevving, .truckOrBus,
             .carPassing, .bikeBell, .skateboard:
            return .vehicles
        case .smokeAlarm, .burglarAlarm, .civilDefenseSiren, .whistle:
            return .alarms
        case .screaming, .shouting, .babyCrying:
            return .people
        case .gunshot, .explosion, .fireworks, .glassBreaking, .crash:
            return .suddenEvents
        case .dogBarking, .dogGrowling:
            return .animals
        case .thunder:
            return .weather
        case .jackhammer, .chainsaw, .powerTool, .lawnMower, .leafBlower, .construction, .helicopter:
            return .machinery
        }
    }

    /// How dangerous the sound usually is, from 0 to 1. This is one input to
    /// the live urgency score. Starting guesses, to be tuned by testing.
    var baseDanger: Double {
        switch self {
        case .siren, .trainHorn, .tireScreech, .civilDefenseSiren, .gunshot, .explosion:
            return 1.0
        case .carHorn, .airHorn, .railroadCrossingBell, .smokeAlarm:
            return 0.9
        case .screaming, .crash:
            return 0.8
        case .backupBeeper:
            return 0.7
        case .motorcycle, .engineRevving, .shouting, .glassBreaking, .dogGrowling, .thunder:
            return 0.6
        case .truckOrBus, .burglarAlarm, .whistle, .fireworks:
            return 0.5
        case .carAlarm, .carPassing, .bikeBell, .chainsaw:
            return 0.4
        case .skateboard, .dogBarking, .jackhammer, .construction, .helicopter:
            return 0.3
        case .babyCrying, .powerTool, .lawnMower, .leafBlower:
            return 0.2
        }
    }

    /// Whether the sound can come toward the user, so "Getting closer" applies.
    var canMove: Bool {
        switch self {
        case .siren, .carHorn, .airHorn, .trainHorn, .backupBeeper, .motorcycle,
             .engineRevving, .truckOrBus, .carPassing, .bikeBell, .skateboard, .helicopter:
            return true
        default:
            return false
        }
    }
}

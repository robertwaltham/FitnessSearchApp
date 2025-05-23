//
//  DataModel.swift
//  FitnessSearch
//
//  Created by Robert Waltham on 2025-05-12.
//
@preconcurrency import SQLite
import Foundation
import CoreML

final class DataModel: Sendable {
    private let db: Connection!
    
    private static let filename = "db.sqlite3"
    
    // TODO: data subset for previews
    init(testing: Bool = false) {
//        if testing {
//            db = DataModel.connectForTesting()
//            createTables()
//        } else {
            FileManager.default.copyFileToDocumentsFolder(nameForFile: "db", extForFile: "sqlite3")
            db = DataModel.connect()
            createTables()
//        }
    }

    fileprivate static func connect() -> Connection {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first!

        do {
            return try Connection("\(path)/\(filename)")
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    fileprivate static func connectForTesting() -> Connection {
        do {
            return try Connection() // in memory
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    fileprivate func createTables() {
        do {
            try Exercise.createTable(db: db)
            try Embeddings.createTable(db: db)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}

extension DataModel {
    func save(exercise: Exercise) {
        do {
            try exercise.save(db: db)
        } catch {
            print(error)
        }
    }
    
    func exercises() -> [Exercise] {
        do {
            return try Exercise.queryAll(db: db)
        } catch {
            print(error)
        }
        return []
    }
    
    func embedding(exerciseName: String) -> Embeddings? {
        do {
            return try Embeddings.load(name: exerciseName, db: db)
        } catch {
            print(error)
        }
        return nil
    }
    
    func save(embeddings: Embeddings) {
        do {
            try embeddings.save(db: db)
        } catch {
            print(error)
        }
    }
}

/*
 CREATE TABLE IF NOT EXISTS "exercises"(
 "exercise" TEXT,
 "short_video" TEXT,
 "long_video" TEXT,
 "difficulty" TEXT,
 "muscle_group" TEXT,
 "primary_muscle" TEXT,
 "secondary_muscle" TEXT,
 "tertiary_muscle" TEXT,
 "primary_equipment" TEXT,
 "primary_item_count" TEXT,
 "secondary_equipment" TEXT,
 "secondary_item_count" TEXT,
 "posture" TEXT,
 "single_or_double_arm" TEXT,
 "continuous_or_alternating_arms" TEXT,
 "grip" TEXT,
 "load_position_end" TEXT,
 "continuous_or_alternating_legs" TEXT,
 "foot_elevation" TEXT,
 "combination_exercises" TEXT,
 "movement_pattern_1" TEXT,
 "movement_pattern_2" TEXT,
 "movement_pattern_3" TEXT,
 "plane_of_motion_1" TEXT,
 "plane_of_motion_2" TEXT,
 "plane_of_motion_3" TEXT,
 "body_region" TEXT,
 "force_type" TEXT,
 "mechanics" TEXT,
 "laterality" TEXT,
 "primary_exercise_classification" TEXT
 );
 */

struct Exercise: Identifiable {
    
    var id: String {
        return name
    }

    var name: String
    fileprivate static var nameExp: SQLite.Expression<String> {
        Expression<String>("exercise")
    }
    
    var muscleGroup: String?
    fileprivate static var muscleGroupExp: SQLite.Expression<String?> {
        Expression<String?>("muscle_group")
    }
    
    var primaryMuscle: String?
    fileprivate static var primaryMuscleExp: SQLite.Expression<String?> {
        Expression<String?>("primary_muscle")
    }
    
    var secondaryMuscle: String?
    fileprivate static var secondaryMuscleExp: SQLite.Expression<String?> {
        Expression<String?>("secondary_muscle")
    }
    
    var tertiaryMuscle: String?
    fileprivate static var tertiaryMuscleExp: SQLite.Expression<String?> {
        Expression<String?>("tertiary_muscle")
    }
    
    var shortVideo: String?
    fileprivate static var shortVideoExp: SQLite.Expression<String?> {
        Expression<String?>("short_video")
    }
    var longVideo: String?
    fileprivate static var longVideoExp: SQLite.Expression<String?> {
        Expression<String?>("long_video")
    }
    var difficulty: String?
    fileprivate static var difficultyExp: SQLite.Expression<String?> {
        Expression<String?>("difficulty")
    }
    var primaryEquipment: String?
    fileprivate static var primaryEquipmentExp: SQLite.Expression<String?> {
        Expression<String?>("primary_equipment")
    }
    var primaryItemCount: String? // TODO: this should be an int
    fileprivate static var primaryItemCountExp: SQLite.Expression<String?> {
        Expression<String?>("primary_item_count")
    }
    var secondaryEquipment: String?
    fileprivate static var secondaryEquipmentExp: SQLite.Expression<String?> {
        Expression<String?>("secondary_equipment")
    }
    var secondaryItemCount: String? // TODO: this should be an int
    fileprivate static var secondaryItemCountExp: SQLite.Expression<String?> {
        Expression<String?>("secondary_item_count")
    }
    var posture: String?
    fileprivate static var postureExp: SQLite.Expression<String?> {
        Expression<String?>("posture")
    }
    var singleOrDoubleArm: String? // TODO: this should be an bool
    fileprivate static var singleOrDoubleArmExp: SQLite.Expression<String?> {
        Expression<String?>("single_or_double_arm")
    }
    var continuousOrAlternatingArms: String? // TODO: this should be an bool
    fileprivate static var continuousOrAlternatingArmsExp: SQLite.Expression<String?> {
        Expression<String?>("continuous_or_alternating_arms")
    }
    var grip: String?
    fileprivate static var gripExp: SQLite.Expression<String?> {
        Expression<String?>("grip")
    }
    var loadPositionEnd: String?
    fileprivate static var loadPositionEndExp: SQLite.Expression<String?> {
        Expression<String?>("load_position_end")
    }
    var continuousOrAlternatingLegs: String?
    fileprivate static var continuousOrAlternatingLegsExp: SQLite.Expression<String?> {
        Expression<String?>("continuous_or_alternating_legs")
    }
    var footElevation: String?
    fileprivate static var footElevationExp: SQLite.Expression<String?> {
        Expression<String?>("foot_elevation")
    }
    var combinationExercises: String?
    fileprivate static var combinationExercisesExp: SQLite.Expression<String?> {
        Expression<String?>("combination_exercises")
    }
    var movementPattern1: String?
    fileprivate static var movementPattern1Exp: SQLite.Expression<String?> {
        Expression<String?>("movement_pattern_1")
    }
    var movementPattern2: String?
    fileprivate static var movementPattern2Exp: SQLite.Expression<String?> {
        Expression<String?>("movement_pattern_2")
    }
    var movementPattern3: String?
    fileprivate static var movementPattern3Exp: SQLite.Expression<String?> {
        Expression<String?>("movement_pattern_3")
    }
    var planeOfMotion1: String?
    fileprivate static var planeOfMotion1Exp: SQLite.Expression<String?> {
        Expression<String?>("plane_of_motion_1")
    }
    var planeOfMotion2: String?
    fileprivate static var planeOfMotion2Exp: SQLite.Expression<String?> {
        Expression<String?>("plane_of_motion_2")
    }
    var planeOfMotion3: String?
    fileprivate static var planeOfMotion3Exp: SQLite.Expression<String?> {
        Expression<String?>("plane_of_motion_3")
    }
    var bodyRegion: String?
    fileprivate static var bodyRegionExp: SQLite.Expression<String?> {
        Expression<String?>("body_region")
    }
    var forceType: String?
    fileprivate static var forceTypeExp: SQLite.Expression<String?> {
        Expression<String?>("force_type")
    }
    var mechanics: String?
    fileprivate static var mechanicsExp: SQLite.Expression<String?> {
        Expression<String?>("mechanics")
    }
    var laterality: String?
    fileprivate static var lateralityExp: SQLite.Expression<String?> {
        Expression<String?>("laterality")
    }
    var primaryExerciseClassification: String?
    fileprivate static var primaryExerciseClassificationExp: SQLite.Expression<String?> {
        Expression<String?>("primary_exercise_classification")
    }
    
    private func _allProperties() -> [String: String] {
        var result = [String: String]()
        for child in Mirror(reflecting: self).children {
            guard let label = child.label else {
                continue
            }
            
            if let strValue = child.value as? String {
                result[label] = strValue
            }
        }
        return result
    }
    
    func allProperties(skipName: Bool = true) -> [Property] {
        return _allProperties()
            .filter { $0.value.count > 0 }
            .map { Property(name: $0.key, value: $0.value) }
            .filter { skipName ? $0.name != "name" : true }
    }
    
    // TODO: empty values should be nil not ""
    func muscleDescription() -> String {
        "\(muscleGroup!) \(primaryMuscle!) \(name)"
    }
    
    func equipmentDescription() -> String {
        "\(primaryEquipment!) \(secondaryEquipment! == "None" ? "" : secondaryEquipment!)"
    }
    
    func nameDescription() -> String {
        "\(name) \(muscleGroup!) \(primaryMuscle!) \(equipmentDescription()) \(difficulty!)"
    }
    
    fileprivate static func table() -> Table {
        return Table("exercises")
    }
    
    fileprivate static func createTable(db: Connection) throws {
        try db.run(
            table().create(ifNotExists: true) { t in
                t.column(nameExp)
                t.column(muscleGroupExp)
                t.column(primaryMuscleExp)
                t.column(secondaryMuscleExp)
                t.column(tertiaryMuscleExp)
                t.column(bodyRegionExp)
                t.column(combinationExercisesExp)
                t.column(continuousOrAlternatingArmsExp)
                t.column(continuousOrAlternatingLegsExp)
                t.column(difficultyExp)
                t.column(footElevationExp)
                t.column(forceTypeExp)
                t.column(gripExp)
                t.column(lateralityExp)
                t.column(loadPositionEndExp)
                t.column(longVideoExp)
                t.column(mechanicsExp)
                t.column(movementPattern2Exp)
                t.column(movementPattern3Exp)
                t.column(movementPattern1Exp)
                t.column(planeOfMotion2Exp)
                t.column(planeOfMotion3Exp)
                t.column(planeOfMotion1Exp)
                t.column(postureExp)
                t.column(primaryEquipmentExp)
                t.column(primaryExerciseClassificationExp)
                t.column(primaryItemCountExp)
                t.column(secondaryEquipmentExp)
                t.column(secondaryItemCountExp)
                t.column(shortVideoExp)
                t.column(singleOrDoubleArmExp)
            }
        )
    }
    
    fileprivate func save(db: Connection) throws {
        try db.run(
            Exercise.table().update(
                Exercise.nameExp <- name,
                Exercise.muscleGroupExp <- muscleGroup,
                Exercise.primaryMuscleExp <- primaryMuscle,
                Exercise.secondaryMuscleExp <- secondaryMuscle,
                Exercise.tertiaryMuscleExp <- tertiaryMuscle,
                Exercise.bodyRegionExp <- bodyRegion,
                Exercise.combinationExercisesExp <- combinationExercises,
                Exercise.continuousOrAlternatingArmsExp <- continuousOrAlternatingArms,
                Exercise.continuousOrAlternatingLegsExp <- continuousOrAlternatingLegs,
                Exercise.difficultyExp <- difficulty,
                Exercise.footElevationExp <- footElevation,
                Exercise.forceTypeExp <- forceType,
                Exercise.gripExp <- grip,
                Exercise.lateralityExp <- laterality,
                Exercise.loadPositionEndExp <- loadPositionEnd,
                Exercise.longVideoExp <- longVideo,
                Exercise.mechanicsExp <- mechanics,
                Exercise.movementPattern2Exp <- movementPattern2,
                Exercise.movementPattern3Exp <- movementPattern3,
                Exercise.movementPattern1Exp <- movementPattern1,
                Exercise.planeOfMotion2Exp <- planeOfMotion2,
                Exercise.planeOfMotion3Exp <- planeOfMotion3,
                Exercise.planeOfMotion1Exp <- planeOfMotion1,
                Exercise.postureExp <- posture,
                Exercise.primaryEquipmentExp <- primaryEquipment,
                Exercise.primaryExerciseClassificationExp <- primaryExerciseClassification,
                Exercise.primaryItemCountExp <- primaryItemCount,
                Exercise.secondaryEquipmentExp <- secondaryEquipment,
                Exercise.secondaryItemCountExp <- secondaryItemCount,
                Exercise.shortVideoExp <- shortVideo,
                Exercise.singleOrDoubleArmExp <- singleOrDoubleArm,

            )
        )
    }
    
    fileprivate static func queryAll(db: Connection) throws -> [Exercise] {
        return try db.prepare(table()).map { row in
            Exercise(name: row[nameExp],
                     muscleGroup: row[muscleGroupExp],
                     primaryMuscle: row[primaryMuscleExp],
                     secondaryMuscle: row[secondaryMuscleExp],
                     tertiaryMuscle: row[tertiaryMuscleExp],
                     shortVideo: row[shortVideoExp],
                     longVideo: row[longVideoExp],
                     difficulty: row[difficultyExp],
                     primaryEquipment: row[primaryEquipmentExp],
                     primaryItemCount: row[primaryItemCountExp],
                     secondaryEquipment: row[secondaryEquipmentExp],
                     secondaryItemCount: row[secondaryItemCountExp],
                     posture: row[postureExp],
                     singleOrDoubleArm: row[singleOrDoubleArmExp],
                     continuousOrAlternatingArms: row[continuousOrAlternatingArmsExp],
                     grip: row[gripExp],
                     loadPositionEnd: row[loadPositionEndExp],
                     continuousOrAlternatingLegs: row[continuousOrAlternatingLegsExp],
                     footElevation: row[footElevationExp],
                     combinationExercises: row[combinationExercisesExp],
                     movementPattern1: row[movementPattern1Exp],
                     movementPattern2: row[movementPattern2Exp],
                     movementPattern3: row[movementPattern3Exp],
                     planeOfMotion1: row[planeOfMotion1Exp],
                     planeOfMotion2: row[planeOfMotion2Exp],
                     planeOfMotion3: row[planeOfMotion3Exp],
                     bodyRegion: row[bodyRegionExp],
                     forceType: row[forceTypeExp],
                     mechanics: row[mechanicsExp],
                     laterality: row[lateralityExp],
                     primaryExerciseClassification: row[primaryExerciseClassificationExp],
            )
        }
    }
}

struct Embeddings {
    
    fileprivate static func table() -> Table {
        return Table("embeddings")
    }
    
    var exerciseName: String
    fileprivate static var exerciseNameExp: SQLite.Expression<String> {
        Expression<String>("exercise_name")
    }
    
    var nameEmbeddings: MLMultiArray
    fileprivate static var nameEmbeddingsExp: SQLite.Expression<MLMultiArray> {
        Expression<MLMultiArray>("exercise_embeddings")
    }
    
    var nameEmbeddingsJina: MLMultiArray
    fileprivate static var nameEmbeddingsJinaExp: SQLite.Expression<MLMultiArray> {
        Expression<MLMultiArray>("exercise_jina_embeddings")
    }
    
    fileprivate static func createTable(db: Connection) throws {
        try db.run(
            table().create(ifNotExists: true) { t in
                t.column(exerciseNameExp, primaryKey: true)
                t.column(nameEmbeddingsExp)
                t.column(nameEmbeddingsJinaExp)
            }
        )
    }
    
    fileprivate func save(db: Connection) throws {
        try db.run(
            Embeddings.table().insert(or: .replace,
                Embeddings.exerciseNameExp <- exerciseName,
                Embeddings.nameEmbeddingsExp <- nameEmbeddings,
                Embeddings.nameEmbeddingsJinaExp <- nameEmbeddingsJina
            )
        )
    }
    
    fileprivate static func load(name: String, db: Connection) throws -> Embeddings? {
        try db.prepare(table().filter(exerciseNameExp == name)).map { row in
            Embeddings(exerciseName: row[exerciseNameExp],
                       nameEmbeddings: row[nameEmbeddingsExp],
                       nameEmbeddingsJina: row[nameEmbeddingsJinaExp]
            )
        }.first
    }
}

extension FileManager {
    func copyFileToDocumentsFolder(nameForFile: String, extForFile: String) {
        let documentsURL = self.urls(for: .documentDirectory, in: .userDomainMask).first
        let destURL = documentsURL!.appendingPathComponent(nameForFile).appendingPathExtension(extForFile)
        guard !fileExists(atPath: destURL.path()) else {
            print("file already exists")
            return
        }
        guard let sourceURL = Bundle.main.url(forResource: nameForFile, withExtension: extForFile) else {
            print("Source File not found.")
            return
        }
        do {
            try self.copyItem(at: sourceURL, to: destURL)
        } catch {
            print("Unable to copy file")
        }
    }
}

extension MLMultiArray: @retroactive Expressible {}
extension MLMultiArray: @retroactive Value {
    public class var declaredDatatype: String {
        return Blob.declaredDatatype
    }
    public class func fromDatatypeValue(_ blobValue: Blob) -> MLMultiArray {
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: MLMultiArray.self, from: Data.fromDatatypeValue(blobValue))!
        } catch {
            fatalError("can't load value")
        }
    }
    public var datatypeValue: Blob {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true).datatypeValue
        } catch {
            fatalError("can't save value")
        }
    }
}

struct Property: Identifiable {
    let name: String
    let value: String
    var id: String{
        name
    }
}

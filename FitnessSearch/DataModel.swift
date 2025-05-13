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
    
    init(testing: Bool = false) {
//        if testing {
//            db = DataModel.connectForTesting()
//            createTables()
//        } else {
            FileManager.default.copyFileToDocumentsFolder(nameForFile: "db", extForFile: "sqlite3")
            db = DataModel.connect()
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
            fatalError(error.localizedDescription)
        }
    }
}

/*
 CREATE TABLE IF NOT EXISTS "exercises"(
 "exercise" TEXT, "short_video" TEXT, "long_video" TEXT, "difficulty" TEXT,
  "muscle_group" TEXT, "primary_muscle" TEXT, "secondary_muscle" TEXT, "tertiary_muscle" TEXT,
  "primary_equipment" TEXT, "primary_item_count" TEXT, "secondary_equipment" TEXT, "secondary_item_count" TEXT,
  "posture" TEXT, "single_or_double_arm" TEXT, "continuous_or_alternating_arms" TEXT, "grip" TEXT,
  "load_position_end" TEXT, "continuous_or_alternating_legs" TEXT, "foot_elevation" TEXT, "combination_exercises" TEXT,
  "movement_pattern_1" TEXT, "movement_pattern_2" TEXT, "movement_pattern_3" TEXT, "plane_of_motion_1" TEXT,
  "plane_of_motion_2" TEXT, "plane_of_motion_3" TEXT, "body_region" TEXT, "force_type" TEXT,
  "mechanics" TEXT, "laterality" TEXT, "primary_exercise_classification" TEXT, embeddings BLOB);
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
    
    var embeddings: MLMultiArray?
    fileprivate static var embeddingsExp: SQLite.Expression<MLMultiArray?> {
        Expression<MLMultiArray?>("embeddings")
    }
    
    var textToEmbed: String {
        return "\(name) \(muscleGroup ?? "") \(primaryMuscle ?? "") \(secondaryMuscle ?? "") \(tertiaryMuscle ?? "")"
    }
    
    fileprivate static func table() -> Table {
        return Table("exercises")
    }
    
    fileprivate static func createTable(db: Connection) throws {
        try db.run(
            table().create(ifNotExists: true) { t in
                t.column(nameExp, primaryKey: true)
                t.column(muscleGroupExp)
                t.column(primaryMuscleExp)
                t.column(secondaryMuscleExp)
                t.column(tertiaryMuscleExp)
                t.column(embeddingsExp)
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
                Exercise.embeddingsExp <- embeddings
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
                     embeddings: row[embeddingsExp])
        }
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

// TODO: FIX doesn't work on loading
extension MLMultiArray: @retroactive Expressible {}
extension MLMultiArray: @retroactive Value {
    public class var declaredDatatype: String {
        return Blob.declaredDatatype
    }
    public class func fromDatatypeValue(_ blobValue: Blob) -> MLMultiArray {
        do {
            return try NSKeyedUnarchiver(forReadingFrom: Data.fromDatatypeValue(blobValue)).decodeObject() as? MLMultiArray ?? MLMultiArray()
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

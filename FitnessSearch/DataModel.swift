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
 "exercise" TEXT, "short_video" TEXT, "long_video" TEXT, "difficulty" TEXT,
  "muscle_group" TEXT, "primary_muscle" TEXT, "secondary_muscle" TEXT, "tertiary_muscle" TEXT,
  "primary_equipment" TEXT, "primary_item_count" TEXT, "secondary_equipment" TEXT, "secondary_item_count" TEXT,
  "posture" TEXT, "single_or_double_arm" TEXT, "continuous_or_alternating_arms" TEXT, "grip" TEXT,
  "load_position_end" TEXT, "continuous_or_alternating_legs" TEXT, "foot_elevation" TEXT, "combination_exercises" TEXT,
  "movement_pattern_1" TEXT, "movement_pattern_2" TEXT, "movement_pattern_3" TEXT, "plane_of_motion_1" TEXT,
  "plane_of_motion_2" TEXT, "plane_of_motion_3" TEXT, "body_region" TEXT, "force_type" TEXT,
  "mechanics" TEXT, "laterality" TEXT, "primary_exercise_classification" TEXT);
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
    
    var textToEmbed: String {
        return "\(name) \(muscleGroup ?? "") \(primaryMuscle ?? "") \(secondaryMuscle ?? "") \(tertiaryMuscle ?? "")"
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
            )
        )
    }
    
    fileprivate static func queryAll(db: Connection) throws -> [Exercise] {
        return try db.prepare(table()).map { row in
            Exercise(name: row[nameExp],
                     muscleGroup: row[muscleGroupExp],
                     primaryMuscle: row[primaryMuscleExp],
                     secondaryMuscle: row[secondaryMuscleExp],
                     tertiaryMuscle: row[tertiaryMuscleExp])
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
    
    fileprivate static func createTable(db: Connection) throws {
        try db.run(
            table().create(ifNotExists: true) { t in
                t.column(exerciseNameExp, primaryKey: true)
                t.column(nameEmbeddingsExp)
            }
        )
    }
    
    fileprivate func save(db: Connection) throws {
        try db.run(
            Embeddings.table().insert(or: .replace,
                Embeddings.exerciseNameExp <- exerciseName,
                Embeddings.nameEmbeddingsExp <- nameEmbeddings
            )
        )
    }
    
    fileprivate static func load(name: String, db: Connection) throws -> Embeddings? {
        try db.prepare(table().filter(exerciseNameExp == name)).map { row in
            Embeddings(exerciseName: row[exerciseNameExp], nameEmbeddings: row[nameEmbeddingsExp])
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

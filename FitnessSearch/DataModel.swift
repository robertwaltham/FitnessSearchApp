//
//  DataModel.swift
//  FitnessSearch
//
//  Created by Robert Waltham on 2025-05-12.
//
@preconcurrency import SQLite
import Foundation

final class DataModel: Sendable {
    private let db: Connection!
    
    init(testing: Bool = false) {
        if testing {
            db = DataModel.connectForTesting()
        } else {
            db = DataModel.connect()
        }
        createTables()
    }

    fileprivate static func connect() -> Connection {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first!

        do {
            return try Connection("\(path)/db.sqlite3")
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
}

struct Exercise {
    var id: String
    fileprivate static var idExp: SQLite.Expression<String> {
        Expression<String>("id")
    }
    var name: String
    fileprivate static var nameExp: SQLite.Expression<String> {
        Expression<String>("name")
    }
    
    fileprivate static func table() -> Table {
        return Table("exercise")
    }
    
    fileprivate static func createTable(db: Connection) throws {
        try db.run(
            table().create(ifNotExists: true) { t in
                t.column(idExp, primaryKey: true)
                t.column(nameExp)
            }
        )
    }
    
    fileprivate func save(db: Connection) throws {
        try db.run(
            Exercise.table().insert(
                Exercise.idExp <- id,
                Exercise.nameExp <- name,
            )
        )
    }
}

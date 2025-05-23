//
//  ExerciseDetailView.swift
//  FitnessSearch
//
//  Created by Robert Waltham on 2025-05-23.
//

import SwiftUI

struct ExerciseDetailView: View {
    var item: Exercise
    
    var body: some View {
        VStack {
            Text(item.name).font(.largeTitle)
            VStack(alignment: .leading) {
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())]) {
                    if !item.muscleGroup!.isEmpty {
                        Text("Muscle Group")
                        Text(item.muscleGroup!)
                    }

                    if !item.primaryMuscle!.isEmpty {
                        Text("Primary Muscle")
                        Text(item.primaryMuscle!)
                    }

                    if !item.secondaryMuscle!.isEmpty {
                        Text("Secondary Muscle")
                        Text(item.secondaryMuscle!)
                    }

                    if !item.tertiaryMuscle!.isEmpty {
                        Text("Tertiary Muscle")
                        Text(item.tertiaryMuscle!)
                    }

                    if !item.difficulty!.isEmpty {
                        Text("Difficulty")
                        Text(item.difficulty!)
                    }

                    if !item.primaryEquipment!.isEmpty && item.primaryEquipment! != "None" {
                        Text("Primary Equipment")
                        if item.primaryItemCount == "1" {
                            Text(item.primaryEquipment!)
                        } else {
                            Text("\(item.primaryEquipment!) (\(item.primaryItemCount!))")
                        }
                    }

                    if !item.secondaryEquipment!.isEmpty && item.secondaryEquipment! != "None" {
                        Text("Secondary Equipment")
                        if item.secondaryItemCount == "1" {
                            Text(item.secondaryEquipment!)
                        } else {
                            Text("\(item.secondaryEquipment!) (\(item.secondaryItemCount!))")
                        }
                    }

                    if !item.posture!.isEmpty {
                        Text("Posture")
                        Text(item.posture!)
                    }

                    if !item.singleOrDoubleArm!.isEmpty {
                        Text("Single Or Double Arm")
                        Text(item.singleOrDoubleArm!)
                    }

                    if !item.continuousOrAlternatingArms!.isEmpty {
                        Text("Continuous Or Alternating Arms")
                        Text(item.continuousOrAlternatingArms!)
                    }

                    if !item.grip!.isEmpty {
                        Text("Grip")
                        Text(item.grip!)
                    }

                    if !item.loadPositionEnd!.isEmpty {
                        Text("Load Position End")
                        Text(item.loadPositionEnd!)
                    }

                    if !item.continuousOrAlternatingLegs!.isEmpty {
                        Text("Continuous Or Alternating Legs")
                        Text(item.continuousOrAlternatingLegs!)
                    }

                    if !item.footElevation!.isEmpty {
                        Text("Foot Elevation")
                        Text(item.footElevation!)
                    }

                    if !item.combinationExercises!.isEmpty {
                        Text("Combination Exercises")
                        Text(item.combinationExercises!)
                    }

                    if !item.movementPattern1!.isEmpty {
                        Text("Movement Pattern")
                        Text(item.movementPattern1!)
                    }

                    if !item.movementPattern2!.isEmpty {
                        Text("")
                        Text(item.movementPattern2!)
                    }

                    if !item.movementPattern3!.isEmpty {
                        Text("")
                        Text(item.movementPattern3!)
                    }

                    if !item.planeOfMotion1!.isEmpty {
                        Text("Plane Of Motion")
                        Text(item.planeOfMotion1!)
                    }

                    if !item.planeOfMotion2!.isEmpty {
                        Text("")
                        Text(item.planeOfMotion2!)
                    }

                    if !item.planeOfMotion3!.isEmpty {
                        Text("")
                        Text(item.planeOfMotion3!)
                    }

                    if !item.bodyRegion!.isEmpty {
                        Text("Body Region")
                        Text(item.bodyRegion!)
                    }

                    if !item.forceType!.isEmpty {
                        Text("Force Type")
                        Text(item.forceType!)
                    }

                    if !item.mechanics!.isEmpty {
                        Text("Mechanics")
                        Text(item.mechanics!)
                    }

                    if !item.laterality!.isEmpty {
                        Text("Laterality")
                        Text(item.laterality!)
                    }

                    if !item.primaryExerciseClassification!.isEmpty {
                        Text("Primary Exercise Classification")
                        Text(item.primaryExerciseClassification!)
                    }
                    
                    if !item.shortVideo!.isEmpty {
                        
                        Link(destination: URL(string: item.shortVideo!)!) {
                            Text("Short Video")
                        }
                    }

                    if !item.longVideo!.isEmpty {
                        Link(destination: URL(string: item.longVideo!)!) {
                            Text("Long Video")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let db = DataModel(testing: true)
    let exercises = db.exercises()
    
    var item = exercises.first
    let binding = Binding {
        item
    } set: { newValue in
       item = newValue
    }
    Color.white
        .sheet(item: binding) { item in
            ExerciseDetailView(item: item)
        }
}

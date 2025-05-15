//
//  ContentView.swift
//  FitnessSearch
//
//  Created by Robert Waltham on 2025-05-12.
//

import SwiftUI
import Observation
import Combine
import CoreML
import SwiftNormalization

struct ContentView: View {
    @State var viewModel: ContentViewModel
    let searchTextPublisher = PassthroughSubject<String, Never>()
    
    init(viewModel: ContentViewModel = ContentViewModel()) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack {
            
            if !viewModel.dbInitalized || !viewModel.classifierInitialized {
                ProgressView()
                    .onAppear {
                        viewModel.loadModels()
                    }
            } else {
                
                HStack {
                    TextField("Query", text: $viewModel.query)
                        .onChange(of: viewModel.query) { oldValue, newValue in
                            searchTextPublisher.send(newValue)
                        }
                        .onReceive(
                            searchTextPublisher
                                .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
                        ) { debouncedSearchText in
                            viewModel.processQuery()
                        }
                    if viewModel.result.isEmpty {
                        Text(viewModel.exercises.count.description)
                    } else {
                        Text(viewModel.result.count.description)
                    }
                }
                .padding()
                .background(Color(white: 0.8))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                
                
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        if viewModel.result.isEmpty {
                            ForEach(viewModel.exercises) { element in
                                HStack{
                                    Text(element.exercise.name)
                                    if let muscleGroup = element.exercise.muscleGroup {
                                        Text(muscleGroup)
                                    }
                                }
                            }
                        } else {
                            ForEach(viewModel.result) { result in
                                HStack {
                                    Text(result.similarity.formatted(.number.precision(.fractionLength(1...2))))
                                    Text(result.exercise.name)
                                    if let muscleGroup = result.exercise.muscleGroup {
                                        Text(muscleGroup)
                                    }
                                }
                            }
                        }
                    }
                }
          
                Spacer()
            }

        }
        .padding()
    }
}

@Observable
final class ContentViewModel: @unchecked Sendable {
    var dataModel: AsyncFactory<DataModel>? = nil
    var classifierModel: AsyncFactory<ClassifierModel>? = nil
    var shaderService: AsyncFactory<ShaderService>? = nil

    var dbInitalized = false
    var classifierInitialized = false
    
    var exercises: [ExerciseContainer] = []
    var result: [ExerciseContainer] = []
    var query: String = ""
    var queryThrottled: String = ""
    
    struct ExerciseContainer: Identifiable {
        let exercise: Exercise
        let similarity: Float
        let embeddings: Embeddings?
        var id: String {
            exercise.id
        }
    }
    
    init(testing: Bool = false) {
        let dataModelBinding = Binding {
            self.dbInitalized
        } set: { value in
            self.dbInitalized = value
        }
        
        let classifierBinding = Binding {
            self.classifierInitialized
        } set: { value in
            self.classifierInitialized = value
        }

        self.dataModel = AsyncFactory(binding: dataModelBinding) {
            DataModel(testing: testing)
        }
        
        self.classifierModel = AsyncFactory(binding: classifierBinding) {
            ClassifierModel()
        }
        
        self.shaderService = AsyncFactory() {
            ShaderService()
        }
        
    }
    
    func testShader() {
        Task {
            guard let service = await self.shaderService?.get() else {
                return
            }
            
            do {
                try service.threadGroupTest()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func processQuery() {
        guard !query.isEmpty else {
            result = []
            return
        }
        
        Task {
            
            // TODO: wait for inputs to be loaded
            guard let service = await self.shaderService?.get() else {
                return
            }
            
            guard let classifierModel = await classifierModel?.get() else {
                return
            }
            
            let clock = ContinuousClock()
            let start = clock.now
            print("Starting Query")

            defer {
                let duration = clock.now - start
                print("Ending Query (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
            }
            
            let input = try classifierModel.embeddings(text: query)
            let result = service.search(input)
            print(result)
        }
        
//        Task {
//            
//            guard let classifierModel = await classifierModel?.get() else {
//                return
//            }
//            
//            let clock = ContinuousClock()
//            let start = clock.now
//            print("Starting Query")
//
//            defer {
//                let duration = clock.now - start
//                print("Ending Query (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
//            }
//            
//            do {
//                let input = try classifierModel.embeddings(text: query)
//                let garbage = try classifierModel.embeddings(text: "aaaaaaaaaa")
//                let diff = try input.subtract(other: garbage)
//                
//                var result = [ExerciseContainer]()
//                for exercise in exercises {
//                    guard let embeddings = exercise.embeddings else {
//                        continue
//                    }
//                    
//                    let similarity = ClassifierModel.cosineSimilarity(diff, embeddings.nameEmbeddings)
//                    
//                    result.append(ExerciseContainer(exercise: exercise.exercise, similarity: similarity, embeddings: nil))
//                }
//                
//                result = result.filter({ element in
//                    element.similarity > 0.1
//                })
//                
//                self.result = Array(result.sorted(by: { a, b in
//                    return a.similarity > b.similarity
//                })[..<min(50, result.count)])
//
//            } catch {
//                print(error.localizedDescription)
//            }
//        }
    }
    
    func loadModels() {
        Task.detached {
            let dataModel = await self.dataModel?.get()
            let classifierModel = await self.classifierModel?.get()
            
            guard let dataModel, let classifierModel else {
                return
            }
                        
            let clock = ContinuousClock()
            let start = clock.now
            print("Starting Classification")
            
            let exercises = dataModel.exercises()
            self.exercises = []
            
            var batchStart = clock.now
            var loaded = 0
            var calculated = 0
            var batch = [ExerciseContainer]()
            for (i, exercise) in exercises.enumerated() {
                if let embeddings = dataModel.embedding(exerciseName: exercise.name) {
                    loaded += 1
                    batch.append(ExerciseContainer(exercise: exercise, similarity: 0, embeddings: embeddings))
                } else {
                    do {
                        let nameEmbedding = try classifierModel.embeddings(text: exercise.name)
                        let embeddings = Embeddings(exerciseName: exercise.name, nameEmbeddings: nameEmbedding)
                        dataModel.save(embeddings: embeddings)
                        batch.append(ExerciseContainer(exercise: exercise, similarity: 0, embeddings: embeddings))
                    } catch {
                        print(error)
                    }
                    calculated += 1
                }
                if i > 0 && i % 10 == 0 {
                    let duration = clock.now - batchStart
                    print("Classified \(i) loaded:\(loaded) calculated:\(calculated) (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
                    batchStart = clock.now
                    loaded = 0
                    calculated = 0
                    self.exercises.append(contentsOf: batch)
                    batch = []
                }
            }
            
            self.exercises.append(contentsOf: batch)
            batch = []
            
            let duration = clock.now - start
            print("Ending (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
            
            batchStart = clock.now
            print("starting shader setup")
            
            guard let service = await self.shaderService?.get() else {
                return
            }
            
            let embeddings = self.exercises.compactMap {$0.embeddings}.map {$0.nameEmbeddings}
            service.createBuffers(embeddingsCount: self.exercises.count)
            service.copyInput(embeddings: embeddings)
            let shaderDuration = clock.now - start
            print("Ending (took \(shaderDuration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
            
        }
    }
}

#Preview {
    ContentView(viewModel: ContentViewModel(testing: true))
}

extension MLMultiArray {
    func printContents() {
        let e1 = self.withUnsafeBufferPointer(ofType: Float.self) { ptr in
            Array(ptr)
        }
        print(e1)
    }
    
    func subtract(other: MLMultiArray) throws -> MLMultiArray {
        
        let e1 = self.withUnsafeBufferPointer(ofType: Float.self) { ptr in
            Array(ptr)
        }
        
        let e2 = other.withUnsafeBufferPointer(ofType: Float.self) { ptr in
            Array(ptr)
        }

        let sub = zip(e1, e2).map { (a, b) in
            a - b
        }
        var normalizer = L1Normalizer<Float>()
        let normalized = normalizer.normalized(sub)
        
        let result = try MLMultiArray(shape: [512], dataType: .float32)
        for (i, e) in normalized.enumerated() {
            result[i] = NSNumber(value: e)
        }
        
        return result
    }
}

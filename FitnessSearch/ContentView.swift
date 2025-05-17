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

struct ContentView: View {
    @State var viewModel: ContentViewModel
    @State var presentedExercise: Exercise?
    
    nonisolated static let cutoff: Float = 0.00
    
    let searchTextPublisher = PassthroughSubject<String, Never>()
    let negativeTextPublisher = PassthroughSubject<String, Never>()

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
                        .disabled(!viewModel.loaded)
                        .onChange(of: viewModel.query) { oldValue, newValue in
                            searchTextPublisher.send(newValue)
                        }
                        .onReceive(
                            searchTextPublisher
                                .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
                        ) { debouncedSearchText in
                            viewModel.processQuery()
                        }
                    
                    TextField("Negative", text: $viewModel.negativeQuery)
                        .disabled(!viewModel.loaded)
                        .onChange(of: viewModel.negativeQuery) { oldValue, newValue in
                            negativeTextPublisher.send(newValue)
                        }
                        .onReceive(
                            negativeTextPublisher
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
                
                if viewModel.loaded {
                    ScrollView {
                        LazyVStack(alignment: .leading) {
                            if viewModel.result.isEmpty {
                                ForEach(viewModel.exercises) { element in
                                    exerciseRow(element.exercise)
                                }
                            } else {
                                ForEach(viewModel.result) { result in
                                    exerciseRow(viewModel.exercises[result.index].exercise, result: result)
                                }
                            }
                        }
                    }
                }

                
                Spacer()
            }
            
        }
        .padding()
        .sheet(item: $presentedExercise) { item in
            VStack {
                Text(item.name).font(.largeTitle)
                VStack(alignment: .leading) {
                    ForEach(item.allProperties()) { property in
                        HStack {
                            Text(property.name)
                            Text(property.value)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func exerciseRow(_ exercise: Exercise, result: ContentViewModel.SearchResult? = nil) -> some View {
        
        HStack{
            Text(exercise.name)
            if let result {
                if result.nameScore > result.muscleScore {
                    Text("name \(result.nameScore.formatted(.number.precision(.fractionLength(1...2))))")
                        .foregroundStyle(.green)
                } else {
                    Text("\(exercise.muscleGroup!) \(result.muscleScore.formatted(.number.precision(.fractionLength(1...2))))")
                        .foregroundStyle(.blue)
                }
            }
        }
        .onTapGesture {
            presentedExercise = exercise
        }
    }
}

@Observable
final class ContentViewModel: @unchecked Sendable {
    var dataModel: AsyncFactory<DataModel>? = nil
    var classifierModel: AsyncFactory<ClassifierModel>? = nil
    var shaderService: AsyncFactory<ShaderService>? = nil
    
    var loaded = false
    
    var dbInitalized = false
    var classifierInitialized = false
    
    var exercises: [ExerciseContainer] = []
    var result: [SearchResult] = []
    var query: String = ""
    var negativeQuery: String = ""
    
    
    /*
     Subtracting the embedding vector for a garbage input seems to improve search results. This may be
     because the search queries for this data often are not well represented in the training set of the
     model and the embedding vectors are in the space of "unknown".
     */
    var garbage: MLMultiArray?
    let garbageInput = "aaaaaaaaa"
    func deGarbage(_ input: MLMultiArray) throws -> MLMultiArray {
        guard let garbage else {
            fatalError("garbage is requred")
        }
        return try input.subtract(other: garbage)
    }
    
    struct ExerciseContainer: Identifiable {
        let exercise: Exercise
        let embeddings: Embeddings?
        var id: String {
            exercise.id
        }
    }
    
    struct SearchResult: Identifiable {
        let index: Int
        var id: Int {
            index
        }
        var nameScore: Float
        var muscleScore: Float
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
    
    // search using compute shader
    func processQuery() {
        
        guard !query.isEmpty else {
            result = []
            return
        }
        
        Task {
            
            guard let service = await self.shaderService?.get() else {
                return
            }
            
            guard service.embeddingsCount != 0 else {
                print("no embeddings")
                return
            }
            
            guard let classifierModel = await classifierModel?.get() else {
                return
            }
            
            let clock = ContinuousClock()
            let start = clock.now
            print("Starting Query \(query)")
            print(classifierModel.tokenizer.tokenize(text: query))
            
            defer {
                let duration = clock.now - start
                print("Ending Query (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
            }
            
            var input = try classifierModel.embeddings(text: query)
            if !negativeQuery.isEmpty {
                print(classifierModel.tokenizer.tokenize(text: negativeQuery))
                let negative = try classifierModel.embeddings(text: negativeQuery)
                input = try input.subtract(other: negative)
            } else {
                input = try deGarbage(input)
            }
            let nameResult = service.search(input)
            let muscleResult = service.search(input, searchName: false)
            self.result = Array(zip(nameResult, muscleResult)
                .enumerated()
                .filter { max($0.element.0, $0.element.1) > ContentView.cutoff }
                .sorted  { max($0.element.0, $0.element.1) > max($1.element.0, $1.element.1) }
                .map({ SearchResult(index: $0.offset, nameScore: $0.element.0, muscleScore: $0.element.1)})
                .prefix(200))
 
        }
    }
    
    // search using cpu
    
    func processQuerySlow() {
        Task {
            
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
            
            do {
                var input = try classifierModel.embeddings(text: query)
                input = try deGarbage(input)
                if !negativeQuery.isEmpty {
                    let negative = try classifierModel.embeddings(text: negativeQuery)
                    input = try input.subtract(other: negative)
                }
                
                var result = [SearchResult]()
                for (i, exercise) in exercises.enumerated() {
                    guard let embeddings = exercise.embeddings else {
                        continue
                    }
                    
                    let nameScore = ClassifierModel.cosineSimilarity(input, embeddings.nameEmbeddings)
                    let muscleScore = ClassifierModel.cosineSimilarity(input, embeddings.muscleEmbeddings)

                    result.append(SearchResult(index: i, nameScore: nameScore, muscleScore: muscleScore))
                }
                
                result = result.filter({ element in
                    max(element.nameScore, element.muscleScore) > ContentView.cutoff
                })
                
                self.result = Array(result.sorted(by: { a, b in
                    return max(a.nameScore, a.muscleScore) > max(a.nameScore, a.muscleScore)
                })[..<min(50, result.count)])
                
            } catch {
                print(error.localizedDescription)
            }
        }
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
                    batch.append(ExerciseContainer(exercise: exercise, embeddings: embeddings))
                } else {
                    do {
                        let nameEmbedding = try classifierModel.embeddings(text: exercise.name)
                        let muscleEmbedding = try classifierModel.embeddings(text: exercise.muscleDescription())
                        let embeddings = Embeddings(exerciseName: exercise.name,
                                                    nameEmbeddings: nameEmbedding,
                                                    muscleEmbeddings: muscleEmbedding
                        )
                        dataModel.save(embeddings: embeddings)
                        batch.append(ExerciseContainer(exercise: exercise, embeddings: embeddings))
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
            
            self.garbage = try classifierModel.embeddings(text: self.garbageInput)
            self.exercises.append(contentsOf: batch)
            batch = []
            
            let duration = clock.now - start
            print("Ending (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
            
            batchStart = clock.now
            print("starting shader setup")
            
            guard let service = await self.shaderService?.get() else {
                return
            }
            
            let names = self.exercises.compactMap {$0.embeddings}.map {$0.nameEmbeddings}
            let muscles = self.exercises.compactMap {$0.embeddings}.map {$0.muscleEmbeddings}
            service.createBuffers(embeddingsCount: self.exercises.count)
            service.copyInput(names: names, muscles: muscles)
            
            let shaderDuration = clock.now - start
            print("Ending (took \(shaderDuration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
            self.loaded = true
        }
    }
}

#Preview {
    ContentView(viewModel: ContentViewModel(testing: true))
}

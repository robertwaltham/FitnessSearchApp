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
    let userInterfaceIdiom: UIUserInterfaceIdiom

    nonisolated static let cutoff: Float = 0.00
    
    let searchTextPublisher = PassthroughSubject<String, Never>()
    let negativeTextPublisher = PassthroughSubject<String, Never>()

    init(viewModel: ContentViewModel = ContentViewModel()) {
        self.viewModel = viewModel
        self.userInterfaceIdiom = UIDevice.current.userInterfaceIdiom
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
                                .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
                        ) { debouncedSearchText in
                            viewModel.processQuery()
                        }
                    Toggle(viewModel.useJinaModel ? "Jina" : "CLIP", isOn: $viewModel.useJinaModel)
                        .frame(maxWidth: 150)

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
            ExerciseDetailView(item: item)
        }
    }
    
    @ViewBuilder
    func exerciseRow(_ exercise: Exercise, result: ContentViewModel.SearchResult? = nil) -> some View {
        
        VStack(alignment: .leading) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                if let result {
                    Text(result.formattedResult(useJinaScore: viewModel.useJinaModel))
                        .foregroundStyle(.yellow)
                }
            }
            
            let font: Font = userInterfaceIdiom == .phone ? .caption : .body
            HStack {
                Text(exercise.muscleGroup!)
                    .foregroundStyle(.purple)
                
                Text(exercise.primaryMuscle!)
                    .foregroundStyle(.blue)
                
                if !exercise.secondaryMuscle!.isEmpty {
                    Text(exercise.secondaryMuscle!)
                        .foregroundStyle(.green)
                }
                
                Text(exercise.primaryEquipment!)
                    .foregroundStyle(.purple)
                
                Text(exercise.difficulty!)
                    .foregroundStyle(.blue)
            }
            .font(font)
        }
        .padding(EdgeInsets(top: 5, leading: 5, bottom: 0, trailing: 0))
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
    
    var useJinaModel = true
    
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
        var nameJinaScore: Float
        var maxScore: Float {
            max(nameScore, nameJinaScore)
        }
        
        func formattedResult(useJinaScore: Bool) -> String {
            if useJinaScore {
                return nameJinaScore.formatted(.number.precision(.fractionLength(1...2)))
            } else {
                return nameScore.formatted(.number.precision(.fractionLength(1...2)))
            }
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
            
            defer {
                let duration = clock.now - start
                print("Ending Query (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
            }
            
            let input = try classifierModel.embeddings(text: query)
            let inputJina = try classifierModel.vector(text: query)

            let nameResult = service.search(input, type: .name)
            let nameJinaResult = service.search(inputJina, type: .nameJina)
            
            self.result = Array((0..<nameResult.count).map({ i in
                SearchResult(index: i, nameScore: nameResult[i], nameJinaScore: nameJinaResult[i])
            })
            .sorted(by: { a, b in
                useJinaModel ? a.nameJinaScore > b.nameJinaScore : a.nameScore > b.nameScore
            })
            .filter({ a in
                a.maxScore > ContentView.cutoff
            })
            .prefix(200))
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
                        let nameEmbedding = try classifierModel.embeddings(text: exercise.nameDescription())
                        let nameJinaEmbedding = try classifierModel.vector(text: exercise.nameDescription())

                        let embeddings = Embeddings(exerciseName: exercise.name,
                                                    nameEmbeddings: nameEmbedding,
                                                    nameEmbeddingsJina: nameJinaEmbedding)
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
            
            let embeddings = self.exercises.compactMap {$0.embeddings}
            let names = embeddings.map {$0.nameEmbeddings}
            let namesJina = embeddings.map {$0.nameEmbeddingsJina}
            
            service.createBuffers(embeddingsCount: self.exercises.count)
            service.copyInput(names: names, namesJina: namesJina)
            
            let shaderDuration = clock.now - batchStart
            print("Ending (took \(shaderDuration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
            self.loaded = true
        }
    }
}

#Preview {
    ContentView(viewModel: ContentViewModel(testing: true))
}

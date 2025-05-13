//
//  ContentView.swift
//  FitnessSearch
//
//  Created by Robert Waltham on 2025-05-12.
//

import SwiftUI
import Observation
import Combine

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
                    Text(viewModel.exercises.count.description)
                }
                .padding()
                .background(Color(white: 0.8))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                
                VStack(alignment: .leading) {
                    if viewModel.result.isEmpty {
                        ForEach(viewModel.exercises[..<min(20, viewModel.exercises.count)]) { exercise in
                            HStack{
                                Text(exercise.name)
                                if let muscleGroup = exercise.muscleGroup {
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

    var dbInitalized = false
    var classifierInitialized = false
    
    var exercises: [Exercise] = []
    var result: [QueryResult] = []
    var query: String = ""
    var queryThrottled: String = ""
    
    struct QueryResult: Identifiable {
        let exercise: Exercise
        let similarity: Float
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
        
    }
    
    func processQuery() {
        guard !query.isEmpty else {
            result = []
            return
        }
        
        Task {
            
            let classifierModel = await classifierModel?.get()
            
            let clock = ContinuousClock()
            let start = clock.now
            print("Starting Query")

            defer {
                let duration = clock.now - start
                print("Ending Query (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
            }
            
            do {
                guard let input = try classifierModel?.embeddings(text: query) else {
                    return
                }
                
                var result = [QueryResult]()
                for exercise in exercises {
                    guard let embeddings = exercise.embeddings else {
                        continue
                    }
                    
                    result.append(QueryResult(exercise: exercise, similarity: ClassifierModel.cosineSimilarity(input, embeddings)))
                }
                
                self.result = Array(result.sorted(by: { a, b in
                    return a.similarity > b.similarity
                })[..<min(20, result.count)])

            } catch {
                print(error.localizedDescription)
            }

        }
    }
    
    func loadModels() {
        Task {
            let dataModel = await dataModel?.get()
            let classifierModel = await classifierModel?.get()
            
            self.exercises = dataModel?.exercises() ?? []
            
            let clock = ContinuousClock()
            let start = clock.now
            print("Starting Classification")
            for i in 0..<exercises.count {
                if self.exercises[i].embeddings == nil {
                    do {
                        let clock = ContinuousClock()
                        let start = clock.now
                        let embeddings = try classifierModel?.embeddings(text: self.exercises[i].textToEmbed)
                        self.exercises[i].embeddings = embeddings
//                        dataModel?.save(exercise: self.exercises[i])
                        let duration = clock.now - start
                        if i % 10 == 0 {
                            print("Classified \(i)/\(exercises.count) (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
                        }
                    } catch {
                        print(error)
                    }
                }
            }
            let duration = clock.now - start
            print("Ending (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
        }
    }
}

#Preview {
    ContentView(viewModel: ContentViewModel(testing: true))
}

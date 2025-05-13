//
//  ContentView.swift
//  FitnessSearch
//
//  Created by Robert Waltham on 2025-05-12.
//

import SwiftUI
import Observation

struct ContentView: View {
    @State var viewModel: ContentViewModel
    
    init(viewModel: ContentViewModel = ContentViewModel()) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack {
            
            if !viewModel.initalized {
                ProgressView()
                    .onAppear {
                        viewModel.loadModels()
                    }
            } else {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            }

        }
        .padding()
    }
}

@Observable
final class ContentViewModel: @unchecked Sendable {
    var dataModel: AsyncFactory<DataModel>? = nil
    var initalized = false
    
    init(testing: Bool = false) {
        let binding = Binding {
            self.initalized
        } set: { value in
            self.initalized = value
        }

        self.dataModel = AsyncFactory(binding: binding) {
            DataModel(testing: testing)
        }
    }
    
    func loadModels() {
        Task {
            _ = await dataModel?.get()
        }
    }
}

#Preview {

    ContentView()
}

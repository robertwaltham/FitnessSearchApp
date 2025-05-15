//
//  MLModel.swift
//  FitnessSearch
//
//  Created by Robert Waltham on 2025-05-12.
//
import CoreML
import SwiftNormalization

final class ClassifierModel: @unchecked Sendable {
    
//    let textEncoder: mobileclip_s0_text
    let textEncoder: mobileclip_blt_text
    let tokenizer: CLIPTokenizer
    
    init() {
        do {
//            try textEncoder = mobileclip_s0_text()
            try textEncoder = mobileclip_blt_text()
            tokenizer = CLIPTokenizer()
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func encode(text: MLMultiArray) throws -> MLMultiArray {
        try textEncoder.prediction(text: text).final_emb_1
    }
    
    func embeddings(text: String) throws -> MLMultiArray {
        
        // Tokenize the text query
        let inputIds = tokenizer.encode_full(text: text)

        // Convert [Int] to MultiArray
        let inputArray = try MLMultiArray(shape: [1, 77], dataType: .int32)
        for (index, element) in inputIds.enumerated() {
            inputArray[index] = NSNumber(value: element)
        }

        // Run the text model on the text query
        return try encode(text: inputArray)

    }
    
    static func cosineSimilarity(_ embedding1: MLMultiArray, _ embedding2: MLMultiArray) -> Float {

        // read the values out of the MLMultiArray in bulk
        let e1 = embedding1.withUnsafeBufferPointer(ofType: Float.self) { ptr in
            Array(ptr)
        }
        let e2 = embedding2.withUnsafeBufferPointer(ofType: Float.self) { ptr in
            Array(ptr)
        }

        // Get the dot product of the two embeddings
        let dotProduct: Float = zip(e1, e2).reduce(0.0) { $0 + $1.0 * $1.1 }

        // Get the magnitudes of the two embeddings
        let magnitude1: Float = sqrt(e1.reduce(0) { $0 + pow($1, 2) })
        let magnitude2: Float = sqrt(e2.reduce(0) { $0 + pow($1, 2) })

        // Get the cosine similarity
        let similarity = dotProduct / (magnitude1 * magnitude2)
        return similarity
    }
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


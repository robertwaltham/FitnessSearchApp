//
//  MLModel.swift
//  FitnessSearch
//
//  Created by Robert Waltham on 2025-05-12.
//
import CoreML
import SwiftNormalization
import Tokenizers
import Hub

final class ClassifierModel: @unchecked Sendable {
    
    // https://huggingface.co/apple/coreml-mobileclip
    let textEncoder: mobileclip_blt_text
    let tokenizer: CLIPTokenizer
    
    // https://huggingface.co/jinaai/jina-embeddings-v2-small-en
    let vectorModel: float32_model
    let vectorTokenizer: any Tokenizer
    let vectorInputTokenCount = 128
    
    init() {
        do {
            try textEncoder = mobileclip_blt_text()
            tokenizer = CLIPTokenizer()
            
            try vectorModel = float32_model()
            guard let config = try ClassifierModel.readConfig(name: "tokenizer_config"),
                    let data = try ClassifierModel.readConfig(name: "tokenizer") else {
                fatalError("no config found")
            }
            vectorTokenizer = try AutoTokenizer.from(tokenizerConfig: config, tokenizerData: data)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    // adapted from
    // https://github.com/couchbaselabs/mobile-testapps/blob/f09f8497c445380009063f7348f5ef54af6bac6d/CBLClient/Apps/CBLTestServer-iOS/CBLTestServer-iOS/Server/VectorSearchRequestHandler.swift#L263
    
    private func tokenize(text: String) throws -> float32_modelInput {
        let tokenized = vectorTokenizer.encode(text: text)
        let empty = Array<Int>(repeating: 0, count: vectorInputTokenCount - tokenized.count)
        let padded = tokenized + empty
        let tokenizedMaskMultiArray = try MLMultiArray(shape: [1, NSNumber(value: vectorInputTokenCount)], dataType: .int32)
        for (i, v) in padded.enumerated() {
            tokenizedMaskMultiArray[i] = NSNumber(value: v)
        }
        
        let attentionMask = padded.map { v in
            v > 0 ? 1 : 0
        }
        let attentionMaskMultiArray = try MLMultiArray(shape: [1, NSNumber(value: vectorInputTokenCount)], dataType: .int32)
        for (i, v) in attentionMask.enumerated() {
            attentionMaskMultiArray[i] = NSNumber(value: v)
        }
        
        return float32_modelInput(input_ids: tokenizedMaskMultiArray, attention_mask: attentionMaskMultiArray)
    }
    
    func vector(text: String) throws -> MLMultiArray {
        let inputs = try tokenize(text: text)
        let prediction = try vectorModel.prediction(input: inputs)
        return prediction.pooler_output
    }
    
    private func encode(text: MLMultiArray) throws -> MLMultiArray {
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
    
    private static func readConfig(name: String) throws -> Config? {
        if let url = Bundle.main.url(forResource: name, withExtension: "json") {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
            if let jsonDict = jsonResult as? [NSString: Any] {
                return Config(jsonDict)
            }
        }
        return nil
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


//
//  ShaderService.swift
//  FitnessSearch
//
//  Created by Robert Waltham on 2025-05-14.

import Compute
import MetalKit
import CoreML

class ShaderService: @unchecked Sendable {
    private let compute: Compute
    private let library: ShaderLibrary
    private let device: MTLDevice
    let embeddingsSize = 512 // mobileclip outputs a vector of 512 floats
    
    private var nameBuffer: MTLBuffer?
    private var nameBufferJina: MTLBuffer?
    
    private var outputBuffer: MTLBuffer?
    private var searchBuffer: MTLBuffer?
    var embeddingsCount = 0
    
    private var pipeline: Compute.Pipeline?
    
    init() {
        do {
            device = MTLCreateSystemDefaultDevice()!
            compute = try Compute(device: device)
            library = ShaderLibrary.bundle(.main)
        } catch {
            fatalError("failed to initialize compute \(error.localizedDescription)")
        }
    }
    
    func threadGroupTest() throws {
        let clock = ContinuousClock()
        let start = clock.now
        print("Starting Shader")
        
        let pipeline = try compute.makePipeline(function: library.threadgroup_test)
        try compute.run(pipeline: pipeline,
                        threadgroupsPerGrid: MTLSize(width: 3, height: 1, depth: 1),
                        threadsPerThreadgroup: MTLSize(width: 3, height: 1, depth: 1))
        
        let duration = clock.now - start
        print("Ending (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
    }
    
    func createBuffers(embeddingsCount: Int) {
        self.embeddingsCount = embeddingsCount
        
        let inputSize = embeddingsCount * embeddingsSize * MemoryLayout<Float>.stride
        guard let inputBuffer = device.makeBuffer(length: inputSize) else {
            fatalError("could not create buffer of size \(inputSize)")
        }
        self.nameBuffer = inputBuffer
        
        guard let inputBuffer = device.makeBuffer(length: inputSize) else {
            fatalError("could not create buffer of size \(inputSize)")
        }
        self.nameBufferJina = inputBuffer
        
        let outputSize = embeddingsCount * MemoryLayout<Float>.stride
        guard let outputBuffer = device.makeBuffer(length: outputSize) else {
            fatalError("could not create buffer of size \(outputSize)")
        }
        self.outputBuffer = outputBuffer
        
        let searchSize = embeddingsSize * MemoryLayout<Float>.stride
        guard let searchBuffer = device.makeBuffer(length: searchSize) else {
            fatalError("could not create buffer of size \(searchSize)")
        }
        self.searchBuffer = searchBuffer
    }
    
    func copyInput(names: [MLMultiArray], namesJina: [MLMultiArray]) {
        
        guard let nameBuffer, let nameBufferJina else {
            fatalError("Buffers must be initalized before use")
        }
        
        guard embeddingsCount == names.count else {
            fatalError("Embedding count must match")
        }
        
        let embSize = MemoryLayout<Float>.stride * embeddingsSize
        
        for (i, e) in names.enumerated() {
            _ = e.withUnsafeBytes { ptr in
                memcpy(nameBuffer.contents() + (i * embSize), ptr.baseAddress, embSize)
            }
        }
        
        for (i, e) in namesJina.enumerated() {
            _ = e.withUnsafeBytes { ptr in
                memcpy(nameBufferJina.contents() + (i * embSize), ptr.baseAddress, embSize)
            }
        }
    }
    
    enum SearchType {
        case name
        case nameJina
    }
    
    func search(_ embedding: MLMultiArray, type: SearchType) -> [Float] {
        do {
            
            if pipeline == nil {
                let function = library.similarity
                self.pipeline = try compute.makePipeline(function: function)
            }
            
            guard var pipeline, let nameBuffer, let nameBufferJina, let outputBuffer, let searchBuffer else {
                fatalError("couldn't create pipeline, or buffers not initalized")
            }
            
            let embSize = MemoryLayout<Float>.stride * embeddingsSize

            _ = embedding.withUnsafeBytes { ptr in
                memcpy(searchBuffer.contents(), ptr.baseAddress, embSize)
            }
            
            switch type {
                
            case .name:
                pipeline.arguments.input = .buffer(nameBuffer)
            case .nameJina:
                pipeline.arguments.input = .buffer(nameBufferJina)
            }

            pipeline.arguments.output = .buffer(outputBuffer)
            pipeline.arguments.search = .buffer(searchBuffer)
            
            let threadExecutionWidth = pipeline.computePipelineState.threadExecutionWidth
            
            try compute.run(pipeline: pipeline,
                            threads: MTLSize(width: embeddingsCount, height: 1, depth: 1),
                            threadsPerThreadgroup: MTLSize(width: threadExecutionWidth, height: 1, depth: 1))
            
            return Array(outputBuffer.contentsBuffer(of: Float.self))
            
        } catch {
            print(error)
        }

        return []
    }
}

// from https://github.com/schwa/Compute/blob/main/Sources/MetalSupportLite/MTLBuffer%2BExtensions.swift#L51
// TODO: this is included in Compute dependency, fix needing to manually copy it in
public extension MTLBuffer {
    func data() -> Data {
        Data(bytes: contents(), count: length)
    }

    /// Update a MTLBuffer's contents using an inout type block
    func with<T, R>(type: T.Type, _ block: (inout T) -> R) -> R {
        let value = contents().bindMemory(to: T.self, capacity: 1)
        return block(&value.pointee)
    }

    func withEx<T, R>(type: T.Type, count: Int, _ block: (UnsafeMutableBufferPointer<T>) -> R) -> R {
        let pointer = contents().bindMemory(to: T.self, capacity: count)
        let buffer = UnsafeMutableBufferPointer(start: pointer, count: count)
        return block(buffer)
    }

    func contentsBuffer() -> UnsafeMutableRawBufferPointer {
        UnsafeMutableRawBufferPointer(start: contents(), count: length)
    }

    func contentsBuffer<T>(of type: T.Type) -> UnsafeMutableBufferPointer<T> {
        contentsBuffer().bindMemory(to: type)
    }
    func labelled(_ label: String) -> MTLBuffer {
        self.label = label
        return self
    }
}

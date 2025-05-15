//
//  ShaderService.swift
//  FitnessSearch
//
//  Created by Robert Waltham on 2025-05-14.

import Compute
import MetalKit

class ShaderService: @unchecked Sendable {
    let compute: Compute
    let library: ShaderLibrary
    
    init() {
        do {
            let device = MTLCreateSystemDefaultDevice()!
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
}

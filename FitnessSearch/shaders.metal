//
//  shaders.metal
//  FitnessSearch
//
//  Created by Robert Waltham on 2025-05-14.
//

#include <metal_stdlib>
#include <metal_logging>

using namespace metal;

const uint thread_position_in_grid [[thread_position_in_grid]];
const uint threadgroup_position_in_grid [[threadgroup_position_in_grid]];
const uint thread_position_in_threadgroup [[thread_position_in_threadgroup]];

const uint threads_per_grid [[threads_per_grid]];
const uint threads_per_threadgroup [[threads_per_threadgroup]];
const uint threadgroups_per_grid [[threadgroups_per_grid]];

using namespace metal;

kernel void threadgroup_test() {
    if (thread_position_in_grid == 0) {
        os_log_default.log_debug("threads_per_grid: %d, threads_per_threadgroup: %d, threadgroups_per_grid: %d", threads_per_grid, threads_per_threadgroup, threadgroups_per_grid);
    }
    os_log_default.log_debug("thread_position_in_grid: %d, thread_position_in_threadgroup: %d, threadgroup_position_in_grid: %d", thread_position_in_grid, thread_position_in_threadgroup, threadgroup_position_in_grid);
}

kernel void similarity (
    device float *input [[buffer (0)]],
    device float *output [[buffer (1)]],
    device float *search [[buffer (2)]]
) {
    uint index = thread_position_in_grid;
    const int vector_size = 512;
    uint input_index = index * vector_size;

    float dot_product = 0;
    float input_magnitude = 0;
    float search_magnitude = 0;
    
    for (int i = 0; i < vector_size; i++) {
        dot_product += search[i] * input[i + input_index];
        input_magnitude += pow(search[i], 2.0);
        search_magnitude += pow(input[i + input_index], 2.0);
    }
    
    input_magnitude = sqrt(input_magnitude);
    search_magnitude = sqrt(search_magnitude);
    
    output[thread_position_in_grid] = dot_product / (input_magnitude * search_magnitude);
}

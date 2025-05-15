//
//  shaders.metal
//  FitnessSearch
//
//  Created by Robert Waltham on 2025-05-14.
//

#include <metal_stdlib>
#include <metal_logging>

const uint thread_position_in_grid [[thread_position_in_grid]];
const uint threadgroup_position_in_grid [[threadgroup_position_in_grid]];
const uint thread_position_in_threadgroup [[thread_position_in_threadgroup]];

const uint threads_per_grid [[threads_per_grid]];
const uint threads_per_threadgroup [[threads_per_threadgroup]];
const uint threadgroups_per_grid [[threadgroups_per_grid]];

using namespace metal;

kernel void threadgroup_test() {
    if (thread_position_in_grid == 0) {
        metal::os_log_default.log_debug("threads_per_grid: %d, threads_per_threadgroup: %d, threadgroups_per_grid: %d", threads_per_grid, threads_per_threadgroup, threadgroups_per_grid);
    }
    metal::os_log_default.log_debug("thread_position_in_grid: %d, thread_position_in_threadgroup: %d, threadgroup_position_in_grid: %d", thread_position_in_grid, thread_position_in_threadgroup, threadgroup_position_in_grid);
}

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include "spirv_msl.hpp"

#include <fstream>
#include <iostream>
#include <vector>

struct Payload
{
    uint64_t values;
    float gain;
};

struct Nested
{
    Payload primary;
    uint64_t aliases[2];
    uint64_t scalar;
    uint64_t vector;
};

int main(int argc, char **argv)
{
    if (argc != 2)
        return 2;

    @autoreleasepool
    {
        std::ifstream input(argv[1], std::ios::binary | std::ios::ate);
        if (!input)
            return 1;
        auto size = input.tellg();
        input.seekg(0, std::ios::beg);
        std::vector<uint32_t> spirv(size / sizeof(uint32_t));
        if (!input.read(reinterpret_cast<char *>(spirv.data()), size))
            return 1;

        spirv_cross::CompilerMSL compiler(std::move(spirv));
        auto options = compiler.get_msl_options();
        options.msl_version = 30000;
        compiler.set_msl_options(options);
        auto source = compiler.compile();

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        NSError *error = nil;
        id<MTLLibrary> library = [device newLibraryWithSource:@(source.c_str()) options:nil error:&error];
        if (!library)
        {
            std::cerr << source << '\n';
            NSLog(@"%@", error);
            return 1;
        }
        id<MTLFunction> function = [library newFunctionWithName:@"main0"];
        id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:function error:&error];
        if (!pipeline)
        {
            NSLog(@"%@", error);
            return 1;
        }

        const float values[] = {2, 3, 5, 7, 11, 13, 15, 21};
        const float scalar = 9;
        const float vector[] = {1, 2, 3, 4};
        id<MTLBuffer> value_buffer = [device newBufferWithBytes:values length:sizeof(values) options:MTLResourceStorageModeShared];
        id<MTLBuffer> scalar_buffer = [device newBufferWithBytes:&scalar length:sizeof(scalar) options:MTLResourceStorageModeShared];
        id<MTLBuffer> vector_buffer = [device newBufferWithBytes:vector length:sizeof(vector) options:MTLResourceStorageModeShared];
        Nested nested = {{value_buffer.gpuAddress, 3},
                         {value_buffer.gpuAddress, value_buffer.gpuAddress + 4 * sizeof(float)},
                         scalar_buffer.gpuAddress, vector_buffer.gpuAddress};
        id<MTLBuffer> nested_buffer = [device newBufferWithBytes:&nested length:sizeof(nested) options:MTLResourceStorageModeShared];
        uint64_t address = nested_buffer.gpuAddress;
        const float expected[] = {6, 3, 15, 9, 10, 17, 19, 23, 29};
        id<MTLBuffer> output = [device newBufferWithLength:sizeof(expected) options:MTLResourceStorageModeShared];
        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLCommandBuffer> command = [queue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [command computeCommandEncoder];
        [encoder setComputePipelineState:pipeline];
        [encoder setBytes:&address length:sizeof(address) atIndex:0];
        [encoder setBuffer:output offset:0 atIndex:1];
        [encoder useResource:nested_buffer usage:MTLResourceUsageRead];
        [encoder useResource:value_buffer usage:MTLResourceUsageRead | MTLResourceUsageWrite];
        [encoder useResource:scalar_buffer usage:MTLResourceUsageRead | MTLResourceUsageWrite];
        [encoder useResource:vector_buffer usage:MTLResourceUsageRead | MTLResourceUsageWrite];
        [encoder dispatchThreads:MTLSizeMake(1, 1, 1) threadsPerThreadgroup:MTLSizeMake(1, 1, 1)];
        [encoder endEncoding];
        [command commit];
        [command waitUntilCompleted];
        if (command.status != MTLCommandBufferStatusCompleted)
        {
            NSLog(@"%@", command.error);
            return 1;
        }

        const float *actual = static_cast<const float *>(output.contents);
        for (size_t index = 0; index < sizeof(expected) / sizeof(expected[0]); ++index)
        {
            if (actual[index] != expected[index])
            {
                std::cerr << "Shader output mismatch at " << index << ": " << actual[index] << '\n';
                return 1;
            }
        }
        // DUMBAI: Host checks prove that copied pointer aliases still write the original buffers.
        if (static_cast<const float *>(value_buffer.contents)[0] != 17 ||
            static_cast<const float *>(value_buffer.contents)[6] != 19 ||
            static_cast<const float *>(scalar_buffer.contents)[0] != 23 ||
            static_cast<const float *>(vector_buffer.contents)[0] != 29)
            return 1;
    }
    std::cout << "logical pointer copies compile and preserve nested, array, scalar and vector aliases\n";
    return 0;
}

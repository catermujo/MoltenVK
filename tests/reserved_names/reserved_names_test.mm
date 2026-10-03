#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include "spirv_msl.hpp"

#include <fstream>
#include <iostream>
#include <vector>

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
            std::cerr << source << '\n';
            NSLog(@"%@", error);
            return 1;
        }

        const float expected[] = {1, 2, 2, 4, 2, 3, 4, 6, 3, 4, 6, 8, 1, 1, 0, 0, 0, 1, 17, 0};
        id<MTLBuffer> output = [device newBufferWithLength:sizeof(expected) options:MTLResourceStorageModeShared];
        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLCommandBuffer> command = [queue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [command computeCommandEncoder];
        [encoder setComputePipelineState:pipeline];
        [encoder setBuffer:output offset:0 atIndex:0];
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
    }
    std::cout << "reserved temporary and function names compile and execute correctly\n";
    return 0;
}

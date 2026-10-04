struct Values {
    float data[4];
};

struct Payload {
    Values* values;
    float gain;
};

struct Nested {
    Payload primary;
    Values* aliases[2];
    float* scalar;
    float4* vector;
};

struct Push {
    Ptr<Nested, Access::Read, AddressSpace::Device, ScalarDataLayout> source;
};

[[vk::binding(0, 0)]] ConstantBuffer<Push, ScalarDataLayout> pushc : register(b0, space0);
[[vk::binding(1, 1)]] RWStructuredBuffer<float, ScalarDataLayout> result : register(u1, space1);

[numthreads(1, 1, 1)]
void main(uint3 id : SV_DispatchThreadID) {
    // DUMBAI: Logical copies must preserve pointer values inside nested structs and arrays.
    Nested local = *pushc.source;
    result[0] = local.primary.values.data[0] * local.primary.gain;
    result[1] = local.aliases[0].data[1];
    result[2] = local.aliases[1].data[2];
    result[3] = *local.scalar;
    result[4] = dot(*local.vector, float4(1));

    // DUMBAI: Writes through copied pointers must reach the original storage, not a copied pointee.
    local.primary.values.data[0] = 17;
    local.aliases[1].data[2] = 19;
    *local.scalar = 23;
    (*local.vector).x = 29;
    result[5] = pushc.source.primary.values.data[0];
    result[6] = pushc.source.aliases[1].data[2];
    result[7] = *pushc.source.scalar;
    result[8] = (*pushc.source.vector).x;
}

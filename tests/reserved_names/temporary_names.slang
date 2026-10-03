RWStructuredBuffer<float2> output;

float2 extent(uint index)
{
    return float2(index + 1, index + 2);
}

float isfinite0(float value)
{
    return value + 17;
}

[numthreads(1, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID)
{
    float2 half = extent(tid.x);
    float2 _half = extent(tid.x + 1);
    float2 kernel = extent(tid.x + 2);
    output[tid.x] = half;
    output[tid.x + 1] = half * 2;
    output[tid.x + 2] = _half;
    output[tid.x + 3] = _half * 2;
    output[tid.x + 4] = kernel;
    output[tid.x + 5] = kernel * 2;
    output[tid.x + 6] = float2(float(isfinite(1.0)), float(isfinite(-1.0)));
    output[tid.x + 7] = float2(float(isfinite(asfloat(0x7f800000))), float(isfinite(asfloat(0xff800000))));
    output[tid.x + 8] = float2(float(isfinite(asfloat(0x7fc00000))), float(isfinite(0.0)));
    output[tid.x + 9] = float2(isfinite0(float(tid.x)), float(isfinite(asfloat(0xffc00000))));
}

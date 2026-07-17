#version 450

layout(triangles, invocations = 1) in;
layout(triangle_strip, max_vertices = 3) out;

layout(location = 0) in vec3 normal[];
layout(location = 0) out vec3 vNormal;

void main() {
    gl_PrimitiveID = gl_PrimitiveIDIn + gl_InvocationID;
    for (int i = 0; i < 3; ++i) {
        gl_Position = gl_in[i].gl_Position;
        vNormal = normal[i];
        EmitVertex();
    }
    EndPrimitive();
}

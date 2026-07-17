#version 450

layout(points) in;
layout(points, max_vertices = 1) out;

layout(location = 0) in vec3 normal[];
layout(location = 0) out vec3 vNormal;

void main() {
    gl_Position = gl_in[0].gl_Position;
    vNormal = normal[0];
    EmitVertex();
    EndPrimitive();
}

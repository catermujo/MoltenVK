#include "spirv_msl.hpp"

#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

using namespace SPIRV_CROSS_NAMESPACE;

static CompilerMSL::Options::PrimitiveTopology parse_topology(const char *name) {
	if (std::string(name) == "points")
		return CompilerMSL::Options::PrimitiveTopology::Points;
	if (std::string(name) == "lines")
		return CompilerMSL::Options::PrimitiveTopology::Lines;
	if (std::string(name) == "triangles")
		return CompilerMSL::Options::PrimitiveTopology::Triangles;
	if (std::string(name) == "triangles-adjacency")
		return CompilerMSL::Options::PrimitiveTopology::TrianglesAdjacency;
	throw std::runtime_error("unknown topology");
}

int main(int argc, char **argv) {
	if (argc != 4) {
		std::cerr << "usage: geometry_msl_test <input.spv> <output.msl> <points|lines|triangles>\n";
		return 2;
	}

	try {
		std::ifstream file(argv[1], std::ios::binary | std::ios::ate);
		if (!file)
			throw std::runtime_error("failed to open SPIR-V input");

		std::streamsize size = file.tellg();
		file.seekg(0, std::ios::beg);
		if (size <= 0 || size % sizeof(uint32_t) != 0)
			throw std::runtime_error("invalid SPIR-V input size");

		std::vector<uint32_t> spirv(size / sizeof(uint32_t));
		if (!file.read(reinterpret_cast<char *>(spirv.data()), size))
			throw std::runtime_error("failed to read SPIR-V input");

		CompilerMSL compiler(std::move(spirv));
		auto options = compiler.get_msl_options();
		options.msl_version = 30000;
		options.for_mesh_pipeline = true;
		options.input_primitive_type = parse_topology(argv[3]);
		compiler.set_msl_options(options);

		MSLShaderInterfaceVariable normal;
		normal.location = 0;
		normal.format = MSL_SHADER_VARIABLE_FORMAT_OTHER;
		normal.vecsize = 3;
		normal.type = SPIRType::Float;
		compiler.add_msl_shader_input(normal);

		MSLShaderInterfaceVariable position;
		position.location = ~0u;
		position.builtin = spv_private::BuiltInPosition;
		position.format = MSL_SHADER_VARIABLE_FORMAT_OTHER;
		position.vecsize = 4;
		position.type = SPIRType::Float;
		compiler.add_msl_shader_input(position);

		std::ofstream output(argv[2]);
		if (!output)
			throw std::runtime_error("failed to open MSL output");
		output << compiler.compile();
		if (!output)
			throw std::runtime_error("failed to write MSL output");
	} catch (const std::exception &error) {
		std::cerr << error.what() << '\n';
		return 1;
	}

	return 0;
}

#include <stdexcept>
#include <iostream>

#include "external/CLI11.hpp"

#include "app.hpp"

/* struct params { */
/*     uint32_t N = 4; */
/*     std::string method = "mis_orig"; */
/*     bool pseudoOffline = false; */
/*     uint32_t Frames = 6; */
/* }; */

int main(int argc, char* argv[]) {
    CLI::App parser{"Wanna-be pathtracer"};

    params_t params;

    parser.add_option("-n,--N", params.N, "Number of samples per pixel");
    parser.add_option("-m,--method", params.method, "Which shader to use");
    parser.add_flag("-c,--capture", params.capture, "Capture screenshot");
    parser.add_flag("-o,--offline", params.pseudoOffline, "Quit after rendering the screenshot");
    parser.add_option("-f,--frames", params.frames, "Number of frames to concatenate");

    try {
        parser.parse(argc, argv);
    } catch (const CLI::ParseError &e) {
        return parser.exit(e);
    }

    App app(params);

    try {
        app.run();
    } catch (const std::exception& e) {
        std::cerr << e.what() << std::endl;
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

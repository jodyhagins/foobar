# Example: set up a CMake C++ project

The request was "set up this directory as a CMake C++ project with a
test". Every step can be written out in advance, so the queue has no
LLM item at all. That is the point of the example: a model is not the
default tool.

    mkdir /tmp/hello && cd /tmp/hello
    cp -R $WORK_RUNNER/examples/cmake-project/queue .work/cmake
    work-runner run .work/cmake
    work-runner status .work/cmake

Requires cmake and a C++ compiler.

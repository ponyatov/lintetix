#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

int main(int argc, char *argv[]);  ///< program entry point
void arg(int argc, char argv[]);   ///< log cmd.line arguments

class Object {
    size_t ref;         ///< ref counter
    Object();           ///< constructor
    virtual ~Object();  ///< virtual destructor
};

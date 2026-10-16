#!/bin/bash
# Compiles the ET 66 shader (needs qt6-shadertools). The .qsb is committed.
cd "$(dirname "$0")" && /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o shaders/et66.frag.qsb shaders/et66.frag

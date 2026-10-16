#!/bin/bash
# Compiles the dial shader. Needs qt6-shadertools. The .qsb is committed, so
# this is only for editing shaders/dial.frag.
cd "$(dirname "$0")" && /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o shaders/dial.frag.qsb shaders/dial.frag

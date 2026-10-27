if grep -q '^ID=ubuntu' /etc/os-release 2>/dev/null; then
  export CARGO_BUILD_JOBS=4
  export NODE_OPTIONS="--max-old-space-size=3072"
  export HSA_OVERRIDE_GFX_VERSION=11.0.0
  export HIP_VISIBLE_DEVICES=0
  export GGML_VK_VISIBLE_DEVICES=0
fi

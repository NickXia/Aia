#!/bin/bash
# Aia 构建脚本：DevEco 捆绑 hvigor + SDK 环境变量（命令行组装参数易丢，固化为脚本）
cd "$(dirname "$0")" || exit 1
export DEVECO_SDK_HOME="D:\\software\\develop\\DevEco Studio\\sdk"
"/d/software/develop/DevEco Studio/tools/node/node.exe" \
  "D:/software/develop/DevEco Studio/tools/hvigor/bin/hvigorw.js" \
  --mode module -p module=entry@default "$@"

#!/bin/bash
# Aia release .app 整包构建：DevEco 捆绑 hvigor + SDK 环境变量（与 build.sh 同思路）
cd "$(dirname "$0")" || exit 1
export DEVECO_SDK_HOME="D:\\software\\develop\\DevEco Studio\\sdk"
"/d/software/develop/DevEco Studio/tools/node/node.exe" \
  "D:/software/develop/DevEco Studio/tools/hvigor/bin/hvigorw.js" \
  --mode project -p product=default -p buildMode=release assembleApp --no-daemon "$@"

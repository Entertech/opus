## Android 构建脚本 build_android.sh

下面的脚本位于仓库根目录，提供了快速生成 Android 平台 libopus 的通用方式：

1. 设置必需环境变量
    ```
    % export OPUS_NDK=/path/to/android/ndk
    ```
   `OPUS_NDK` 必须指向已安装的 Android NDK 根目录。

2. 运行脚本
    ```
    % ./build_android.sh [--abi <abi>] [--platform android-XX] [--version <git标签>]
    ```
   * `--abi`    控制 `DANDROID_ABI`，默认 `arm64-v8a`
   * `--platform` 控制 `DANDROID_PLATFORM`，默认 `android-29`
   * `--version` 指定要构建的 git 版本/标签，默认自动选取最新标签

   未传参数时会构建最新稳定版本的 `arm64-v8a + android-29` 产物。

3. 查看输出

   构建完成后，头文件及 `libopus.so` 将被放到
   `dist/<abi>-<platform>-<version>/` 目录，例如：
    ```
    % ls dist/arm64-v8a-android-29-v1.5.2
    ```
   该目录包含 `include/` 和 `lib/<abi>/libopus.so`，可直接用于集成。
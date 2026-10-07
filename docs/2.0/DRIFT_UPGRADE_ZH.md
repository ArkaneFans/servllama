# Drift 兼容升级

2026-09-30，保持 Flutter 3.35.2 / Dart 3.9.0，将 Drift 从 2.28.2 固定升级到 **2.31.0**。锁文件只更新 Drift，其余依赖不变。

## 版本边界

- Drift 2.31.0 要求 Dart >=3.5.0，依赖 sqlite3 ^2.6.0；当前解析为 sqlite3 2.9.4。
- Drift 2.32.0 / 2.32.1 自身仍声明 Dart >=3.5.0，但依赖 sqlite3 ^3.1.5；后者要求 Dart >=3.9.999，当前 Dart 3.9.0 无法解析。已用当前 Flutter 实际验证 2.32.1 解析失败。
- Drift 2.33.0 起直接要求 Dart >=3.10.0。因此 2.31.0 是包含传递依赖在内兼容当前 SDK 的最后一个稳定版本。
- 保留 sqlite3_flutter_libs 0.5.39，为 sqlite3 2.x 打包 Android 原生库。官方当前安装说明面向 sqlite3 3.x 的构建钩子方案，不能直接套用到此版本。sqlite3_flutter_libs 0.6.0+eol 已停用且要求 Dart >=3.10.0，不进行升级。

继续采用 NativeDatabase.createInBackground 与现有手写 SQL，不增加 drift_flutter 或代码生成依赖。数据库位置、schema 5、Hive 只读导入及完成标记均不变；依赖升级不会触发额外的数据转换。SDK 约束、CI 和全局 Flutter 安装保持原样。准备过程中下载的独立 Flutter 3.38.10 源码未用于构建，也未接入项目。

官方依据：[Drift 版本列表](https://pub.dev/packages/drift/versions)、[Drift 2.31.0](https://pub.dev/packages/drift/versions/2.31.0)、[SQLite 3.1.5](https://pub.dev/packages/sqlite3/versions/3.1.5)、[当前安装指南](https://drift.simonbinder.eu/setup/)。

## 验证与验收

- 当前 SDK 下 pub get 成功；flutter analyze 无问题；全部 669 项测试通过，包括旧库存导入、损坏源回滚、重试和不重复导入。
- Debug APK 构建成功，原生包审计通过：仅 arm64-v8a，保留 libsqlite3.so，16 KiB 对齐与原有 DSP/Crisp 校验通过。
- 实际 APK 版本为 2.0.0-dev.14 / 28，Android Debug 签名验证通过。本次没有安装真机，也没有执行设备覆盖升级验证。
- APK SHA-256：`406ca867a6cec6b6e5211fcc9d22ce76d782e3d6f6d6402090e126476f555e33`。

真机验收沿用 [存储迁移指南](STORAGE_MIGRATION_ZH.md)：覆盖安装后检查旧会话、模型与下载任务；对于已经完成迁移的安装，确认再次启动不会重复导入，也不会恢复已删除记录。模型文件无需重新下载。
